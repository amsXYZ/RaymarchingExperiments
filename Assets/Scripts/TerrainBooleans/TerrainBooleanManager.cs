using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

[ExecuteInEditMode, RequireComponent(typeof(Terrain))]
public class TerrainBooleanManager : MonoBehaviour {

    // Terrain Info
    private Terrain _terrain;
    private Texture2D _heightmap;

    // Mask mesh
    [SerializeField, Tooltip("Mesh used for the boolean operations.")]
    private Mesh _mesh;

    // Command Buffer
    private Material _booleanMaterial;
    private CommandBuffer _commandBufferMask;
    private Camera _camera;

    // Boolean Operators
    // I'm gonna be using 4 external boolean operators and 4 internal ones for now.
    // Ideally, a quality setting will later allow for more or less of these.
    [Space, Header("Terrain Booleans")]
    public TerrainBoolean _booleanOp0;
    public TerrainBoolean _booleanOp1;
    public TerrainBoolean _booleanOp2;
    public TerrainBoolean _booleanOp3;

    [Space, Header("Internal Booleans")]
    public TerrainBoolean _booleanOpI0;
    public TerrainBoolean _booleanOpI1;
    public TerrainBoolean _booleanOpI2;
    public TerrainBoolean _booleanOpI3;

    private TerrainBoolean[] _booleans;

    private RenderTexture _frontFacesMask;
    public RenderTexture FrontFacesRT
    {
        get { return _frontFacesMask; }
    }
    private RenderTexture _backFacesMask;

    #region CommandBufferSetup

    void RenderVolumes(Mesh mesh, Matrix4x4[] modelMatrices)
    {
        MaterialPropertyBlock materialProperties = new MaterialPropertyBlock();

        Shader.SetGlobalMatrix("IMV", _camera.cameraToWorldMatrix);

        _commandBufferMask.SetRenderTarget(_frontFacesMask, 0, CubemapFace.Unknown, -1);
        _commandBufferMask.ClearRenderTarget(true, true, Color.black, 1);
        _commandBufferMask.DrawMeshInstanced(mesh, 0, _booleanMaterial, 0, modelMatrices);

        _commandBufferMask.SetRenderTarget(_backFacesMask, 0, CubemapFace.Unknown, -1);
        _commandBufferMask.ClearRenderTarget(true, true, Color.black, 1);
        _commandBufferMask.DrawMeshInstanced(mesh, 0, _booleanMaterial, 1, modelMatrices);
    }

    Matrix4x4 inverseModelMatrix(Transform t)
    {
        Vector3 translation = Vector3.zero;
        Quaternion rotation = Quaternion.identity;
        Vector3 scale = Vector3.one;

        translation = t.transform.position;
        rotation = t.transform.rotation;
        scale = t.transform.localScale;

        Matrix4x4 m = Matrix4x4.Inverse(Matrix4x4.TRS(translation, rotation, Vector3.one));

        return m;
    }

    void SetupCommandBuffer()
    {
        // Clear the previously stored operations in the buffer.
        _commandBufferMask.Clear();

        Matrix4x4[] modelMatrices = { _booleanOp0.transform.localToWorldMatrix, _booleanOp1.transform.localToWorldMatrix, _booleanOp2.transform.localToWorldMatrix, _booleanOp3.transform.localToWorldMatrix };
        Matrix4x4[] invModelMatrices = { inverseModelMatrix(_booleanOp0.transform), inverseModelMatrix(_booleanOp1.transform), inverseModelMatrix(_booleanOp2.transform), inverseModelMatrix(_booleanOp3.transform) };
        Vector4[] booleanScales = { _booleanOp0.transform.localScale * 0.5f, _booleanOp1.transform.localScale * 0.5f, _booleanOp2.transform.localScale * 0.5f, _booleanOp3.transform.localScale * 0.5f };

        Shader.SetGlobalMatrixArray("_BooleanModelMatrices", invModelMatrices);
        Shader.SetGlobalVectorArray("_BooleanScales", booleanScales);

        RenderVolumes(_mesh, modelMatrices);
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

        Shader.SetGlobalTexture("_frontFaces", _frontFacesMask);
        Shader.SetGlobalTexture("_backFaces", _backFacesMask);

        _terrain = GetComponent<Terrain>();
        _camera = FindObjectOfType<Camera>();

        float[,] textureData = _terrain.terrainData.GetHeights(0, 0, _terrain.terrainData.heightmapWidth, _terrain.terrainData.heightmapHeight);
        //_terrain.terrainData.GetInterpolatedHeight()

        _heightmap = new Texture2D(_terrain.terrainData.heightmapWidth, _terrain.terrainData.heightmapHeight, TextureFormat.RFloat, false, true);

        for (int i = 0; i < _terrain.terrainData.heightmapHeight; i++)
        {
            for (int j = 0; j < _terrain.terrainData.heightmapWidth; j++)
            {
                float h = textureData[i, j];
                _heightmap.SetPixel(j, i, new Color(h, h, h));
            }
        }

        _heightmap.Apply();

        // Find Booleans
        _booleans = FindObjectsOfType<TerrainBoolean>();
        foreach (TerrainBoolean b in _booleans)
        {
            b.heightmap = _heightmap;
        }

        _booleanMaterial = new Material(Shader.Find("Hidden/TerrainBoolean"));
        _booleanMaterial.name = "TerrainBoolean";

        _commandBufferMask = new CommandBuffer();
        _commandBufferMask.name = "ShellMask";
        _camera.AddCommandBuffer(CameraEvent.BeforeGBuffer, _commandBufferMask);

        // Uncomment this if you're working with the editor.
        if (UnityEditor.SceneView.GetAllSceneCameras().Length > 0) UnityEditor.SceneView.GetAllSceneCameras()[0].AddCommandBuffer(CameraEvent.AfterGBuffer, _commandBufferMask);

        SetupCommandBuffer();
    }

    private void Update()
    {
        if (_commandBufferMask != null) { SetupCommandBuffer(); }
    }

    private void OnPreCull()
    {
        /*Camera.onPreCull += (Camera cam) => {
        cam.};*/
    }

    private void OnDrawGizmos()
    {
        Gizmos.color = Color.green;
        Gizmos.DrawWireCube(transform.position, transform.localScale);
    }

    private void OnApplicationQuit()
    {
        _frontFacesMask.Release();
        _backFacesMask.Release();
    }

    #endregion
}
