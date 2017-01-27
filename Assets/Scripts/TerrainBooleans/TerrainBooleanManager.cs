using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

[ExecuteInEditMode, RequireComponent(typeof(Camera))]
public class TerrainBooleanManager : MonoBehaviour {

    private enum BooleanType { SPHERE, CAPSULE, CYLINDER, CUBE }
    private enum BooleanCount { LOW = 4, MEDIUM = 8, HIGH = 16 }
    private enum DebugType { FRONT, BACK }

    [SerializeField]
    private BooleanType _booleanType = BooleanType.SPHERE;
    [SerializeField]
    private BooleanCount _booleanCount = BooleanCount.LOW;

    [SerializeField]
    private Texture2D _heightmap;

    [Space, SerializeField]
    private bool _debug = false;
    [SerializeField, Range(0, 3)]
    private uint _debugSlice = 0;
    [SerializeField]
    private DebugType _debugMode = DebugType.BACK;

    private CommandBuffer _volumeCB;
    private Material _booleanMaterial;
    private Material _debugMaterial;

    // TODO: Better Boolean Support (Distance-sorted culling groups)
    private TerrainBoolean[] _booleans;

    private CullingGroup _booleansVisibility;

    private RenderTexture _frontFacesMask;
    private RenderTexture _backFacesMask;

    private Light _mainLight;
    private CommandBuffer _volumeCBLight;
    private RenderTexture _frontFacesMaskLight;
    private RenderTexture _backFacesMaskLight;

    #region InternalFunctions

    void SetupCommandBuffer()
    {
        _volumeCB.Clear();
        _volumeCBLight.Clear();

        Matrix4x4[] modelMatrices = new Matrix4x4[(int)_booleanCount];
        Matrix4x4[] invModelMatrices = new Matrix4x4[(int)_booleanCount];
        Vector4[] booleanScales = new Vector4[(int)_booleanCount];

        for (int i = 0; i < _booleans.Length; i++)
        {
            modelMatrices[i] = _booleans[i].transform.localToWorldMatrix;
            invModelMatrices[i] = inverseModelMatrix(_booleans[i].transform);
            booleanScales[i] = _booleans[i].transform.localScale * 0.5f;
        }

        Shader.SetGlobalMatrixArray("_BooleanModelMatrices", invModelMatrices);
        Shader.SetGlobalVectorArray("_BooleanScales", booleanScales);

        Mesh booleanMesh;
        GameObject tempGO = GameObject.CreatePrimitive((PrimitiveType)_booleanType);
        booleanMesh = tempGO.GetComponent<MeshFilter>().sharedMesh;
        DestroyImmediate(tempGO);

        RenderVolumes(booleanMesh, modelMatrices);
    }

    Matrix4x4 inverseModelMatrix(Transform t)
    {
        Vector3 translation = t.transform.position;
        Quaternion rotation = t.transform.rotation;
        Vector3 scale = Vector3.one;

        return Matrix4x4.Inverse(Matrix4x4.TRS(translation, rotation, Vector3.one));
    }

    void RenderVolumes(Mesh mesh, Matrix4x4[] modelMatrices)
    {
        _volumeCB.DisableShaderKeyword("LIGHT_BOOLEANS");
        _volumeCB.EnableShaderKeyword("CAMERA_BOOLEANS");
        _volumeCB.SetRenderTarget(_frontFacesMask, 0, CubemapFace.Unknown, -1);
        _volumeCB.ClearRenderTarget(true, true, Color.black, 1);
        _volumeCB.DrawMeshInstanced(mesh, 0, _booleanMaterial, 0, modelMatrices);

        _volumeCB.SetRenderTarget(_backFacesMask, 0, CubemapFace.Unknown, -1);
        _volumeCB.ClearRenderTarget(true, true, Color.black, 1);
        _volumeCB.DrawMeshInstanced(mesh, 0, _booleanMaterial, 1, modelMatrices);

        _volumeCBLight.DisableShaderKeyword("CAMERA_BOOLEANS");
        _volumeCBLight.EnableShaderKeyword("LIGHT_BOOLEANS");
        _volumeCBLight.SetRenderTarget(_frontFacesMaskLight, 0, CubemapFace.Unknown, -1);
        _volumeCBLight.ClearRenderTarget(true, true, Color.black, 1);
        _volumeCBLight.DrawMeshInstanced(mesh, 0, _booleanMaterial, 2, modelMatrices);

        _volumeCBLight.SetRenderTarget(_backFacesMaskLight, 0, CubemapFace.Unknown, -1);
        _volumeCBLight.ClearRenderTarget(true, true, Color.black, 1);
        _volumeCBLight.DrawMeshInstanced(mesh, 0, _booleanMaterial, 1, modelMatrices);
    }

    private void ReadHeightmapFromTerrain()
    {
        Terrain terrain = FindObjectOfType<Terrain>();
        float[,] textureData = terrain.terrainData.GetHeights(0, 0, terrain.terrainData.heightmapWidth, terrain.terrainData.heightmapHeight);
        //terrain.terrainData.GetInterpolatedHeight()

        _heightmap = new Texture2D(terrain.terrainData.heightmapWidth, terrain.terrainData.heightmapHeight, TextureFormat.RFloat, false, true);
        _heightmap.name = "High-Precision Heightmap";

        for (int i = 0; i < terrain.terrainData.heightmapHeight; i++)
        {
            for (int j = 0; j < terrain.terrainData.heightmapWidth; j++)
            {
                float h = textureData[i, j];
                _heightmap.SetPixel(j, i, new Color(h, h, h));
            }
        }

        _heightmap.Apply();
    }

    #endregion

    #region MonoDevelopFunctions

    private void Start()
    {
        _frontFacesMask = new RenderTexture(Screen.width, Screen.height, 24, RenderTextureFormat.Depth, RenderTextureReadWrite.Linear)
        {
            dimension = TextureDimension.Tex2DArray,
            volumeDepth = 4,
            useMipMap = false,
            filterMode = FilterMode.Point,
        };
        _frontFacesMask.Create();
        _backFacesMask = Object.Instantiate(_frontFacesMask);

        _frontFacesMaskLight = new RenderTexture(4096, 4096, 24, RenderTextureFormat.Depth, RenderTextureReadWrite.Linear)
        {
            dimension = TextureDimension.Tex2DArray,
            volumeDepth = 4,
            useMipMap = false,
            filterMode = FilterMode.Point,
        };
        _frontFacesMaskLight.Create();
        _backFacesMaskLight = Object.Instantiate(_frontFacesMaskLight);

        Shader.SetGlobalTexture("_frontFaces", _frontFacesMask);
        Shader.SetGlobalTexture("_backFaces", _backFacesMask);
        Shader.SetGlobalTexture("_frontFacesLight", _frontFacesMaskLight);
        Shader.SetGlobalTexture("_backFacesLight", _backFacesMaskLight);

        if (!_heightmap) ReadHeightmapFromTerrain();

        // Find Booleans
        _booleans = FindObjectsOfType<TerrainBoolean>();
        foreach (TerrainBoolean b in _booleans)
        {
            b.heightmap = _heightmap;
        }

        /*CullingGroup _booleansVisibility = new CullingGroup();
        BoundingSphere[] spheres = new BoundingSphere[(int)_booleanCount];
        for (int i = 0; i < _booleans.Length; i++)
        {
            spheres[i] = _booleans[i].Bounds;
        }
        _booleansVisibility.SetBoundingSphereCount(_booleans.Length);*/

        _booleanMaterial = new Material(Shader.Find("Hidden/BooleanVolumes"));
        _debugMaterial = new Material(Shader.Find("Hidden/RTArrayDebug"));

        _volumeCB = new CommandBuffer();
        _volumeCB.name = "Volume Mask";

        Camera.onPreCull += (Camera cam) => {
            //_booleansVisibility.targetCamera = cam;
            if (cam.actualRenderingPath == RenderingPath.DeferredShading)
            {
                cam.RemoveCommandBuffer(CameraEvent.BeforeGBuffer, _volumeCB);
                cam.AddCommandBuffer(CameraEvent.BeforeGBuffer, _volumeCB);
            }
            else if (cam.actualRenderingPath == RenderingPath.Forward)
            {
                cam.RemoveCommandBuffer(CameraEvent.BeforeForwardOpaque, _volumeCB);
                cam.AddCommandBuffer(CameraEvent.BeforeForwardOpaque, _volumeCB);
            }
        };

        _volumeCBLight = new CommandBuffer();
        _volumeCBLight.name = "Volume Mask Shadows";

        _mainLight = FindObjectOfType<Light>();
        _mainLight.AddCommandBuffer(LightEvent.BeforeShadowMapPass, _volumeCBLight);

        // TODO: Proper Shadows
        /*FindObjectOfType<Light>().RemoveCommandBuffer(LightEvent.BeforeShadowMap, _volumeCB);
        FindObjectOfType<Light>().AddCommandBuffer(LightEvent.BeforeShadowMap, _volumeCB);*/

        SetupCommandBuffer();
    }

    private void Update()
    {
        SetupCommandBuffer();
    }

    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        if (_debug)
        {
            _debugMaterial.SetInt("_Slice", (int)_debugSlice);
            if (_debugMode == DebugType.BACK) Graphics.Blit(_backFacesMask, destination, _debugMaterial);
            else Graphics.Blit(_frontFacesMask, destination, _debugMaterial);
        }
        else Graphics.Blit(source, destination);
    }

    private void OnApplicationQuit()
    {
        _frontFacesMask.Release();
        _backFacesMask.Release();
        _frontFacesMaskLight.Release();
        _backFacesMaskLight.Release();
        //if (_booleansVisibility != null) { _booleansVisibility.Dispose(); _booleansVisibility = null; }
    }

    #endregion
}
