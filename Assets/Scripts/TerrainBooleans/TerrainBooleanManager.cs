using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

[ExecuteInEditMode]
public class TerrainBooleanManager : MonoBehaviour {

    // Terrain Info
    public Terrain terrain;
    public Texture heightmap;

    // Mask mesh
    [SerializeField, Tooltip("Mesh used for the boolean operations.")]
    private Mesh _mesh;

    // Command Buffer
    private Material _booleanMaterial;
    private CommandBuffer _commandBuffer;
    private CommandBuffer _commandBufferMask;
    private Camera _camera;

    // Boolean Operators
    public TerrainBoolean _booleanOp0;
    public TerrainBoolean _booleanOp1;
    public TerrainBoolean _booleanOp2;
    public TerrainBoolean _booleanOp3;

    private void ResizeBoundingBox()
    {
        Vector3 min = Vector3.Min(_booleanOp0.AABB.min, _booleanOp1.AABB.min);
        min = Vector3.Min(min, _booleanOp2.AABB.min);
        min = Vector3.Min(min, _booleanOp3.AABB.min);

        Vector3 max = Vector3.Max(_booleanOp0.AABB.max, _booleanOp1.AABB.max);
        max = Vector3.Max(max, _booleanOp2.AABB.max);
        max = Vector3.Max(max, _booleanOp3.AABB.max);

        //transform.localScale = max - min;
        //transform.localPosition = min + transform.localScale / 2;

        transform.localScale = _booleanOp0.transform.localScale;
        transform.rotation = _booleanOp0.transform.rotation;
        transform.position = _booleanOp0.transform.position;
    }

    #region CommandBufferSetup

    void SetupCommandBuffer()
    {
        // Clear the previously stored operations in the buffer.
        _commandBuffer.Clear();
        _commandBufferMask.Clear();

        MaterialPropertyBlock materialProperties = new MaterialPropertyBlock();

        materialProperties.SetFloat("_MeshScale", transform.localScale.x);
        materialProperties.SetVector("_MeshScaleInternal", transform.localScale / transform.localScale.x * 0.5f);

        materialProperties.SetVector("_BooleanScales", new Vector4(_booleanOp0.transform.localScale.x, _booleanOp1.transform.localScale.x, _booleanOp2.transform.localScale.x, _booleanOp3.transform.localScale.x));
        Matrix4x4[] modelMatrices = { _booleanOp0.transform.worldToLocalMatrix, _booleanOp1.transform.worldToLocalMatrix, _booleanOp2.transform.worldToLocalMatrix, _booleanOp3.transform.worldToLocalMatrix };
        materialProperties.SetMatrixArray("_BooleanModelMatrices", modelMatrices);

        int fronMaskID = Shader.PropertyToID("_DepthFront");
        _commandBufferMask.GetTemporaryRT(fronMaskID, Screen.width, Screen.height, 32, FilterMode.Point, RenderTextureFormat.Depth, RenderTextureReadWrite.Linear);
        _commandBufferMask.SetRenderTarget(fronMaskID);
        _commandBufferMask.ClearRenderTarget(true, true, Color.black);
        _commandBufferMask.DrawMesh(_mesh, transform.localToWorldMatrix, _booleanMaterial, 0, 1, materialProperties);
        _commandBufferMask.ReleaseTemporaryRT(fronMaskID);

        int backMaskID = Shader.PropertyToID("_DepthBack");
        _commandBufferMask.GetTemporaryRT(backMaskID, Screen.width, Screen.height, 32, FilterMode.Point, RenderTextureFormat.Depth, RenderTextureReadWrite.Linear);
        _commandBufferMask.SetRenderTarget(backMaskID);
        _commandBufferMask.ClearRenderTarget(true, true, Color.black);
        _commandBufferMask.DrawMesh(_mesh, transform.localToWorldMatrix, _booleanMaterial, 0, 2, materialProperties);
        _commandBufferMask.ReleaseTemporaryRT(backMaskID);

        // Set the MRTs.
        RenderTargetIdentifier[] mrt = { BuiltinRenderTextureType.GBuffer0, BuiltinRenderTextureType.GBuffer1, BuiltinRenderTextureType.GBuffer2, BuiltinRenderTextureType.GBuffer3 };
        _commandBuffer.SetRenderTarget(mrt, BuiltinRenderTextureType.Depth); // TODO: Figure out a way of pointing to the correct depth texture.

        _commandBuffer.DrawMesh(_mesh, transform.localToWorldMatrix, _booleanMaterial, 0, 0, materialProperties);
    }

    #endregion

    #region MonoDevelopFunctions

    private void Start()
    {
        _camera = FindObjectOfType<Camera>();

        if (Application.isEditor)
        {
            _booleanMaterial = new Material(Shader.Find("Hidden/TerrainBoolean"));
            _booleanMaterial.name = "TerrainBoolean";
            _booleanMaterial.SetTexture("_Heightmap", heightmap);
            _booleanMaterial.SetVector("_TerrainPosition", terrain.transform.position);
            _booleanMaterial.SetVector("_TerrainSize", terrain.terrainData.size);
        }

        _commandBufferMask = new CommandBuffer();
        _commandBufferMask.name = "ShellMask";
        _camera.AddCommandBuffer(CameraEvent.AfterGBuffer, _commandBufferMask);

        _commandBuffer = new CommandBuffer();
        _commandBuffer.name = "TerrainBooleanOps";
        _camera.AddCommandBuffer(CameraEvent.AfterGBuffer, _commandBuffer);

        // Uncomment this if you're working with the editor.
        //if (UnityEditor.SceneView.GetAllSceneCameras().Length > 0) UnityEditor.SceneView.GetAllSceneCameras()[0].AddCommandBuffer(CameraEvent.AfterGBuffer, _commandBuffer);
        //if (UnityEditor.SceneView.GetAllSceneCameras().Length > 0) UnityEditor.SceneView.GetAllSceneCameras()[0].AddCommandBuffer(CameraEvent.AfterGBuffer, _commandBufferMask);

        SetupCommandBuffer();
    }

    private void Update()
    {
        ResizeBoundingBox();

        if (Application.isEditor)
        {
            _booleanMaterial = new Material(Shader.Find("Hidden/TerrainBoolean"));
            _booleanMaterial.name = "TerrainBoolean";
            _booleanMaterial.SetTexture("_Heightmap", heightmap);
            _booleanMaterial.SetVector("_TerrainPosition", terrain.transform.position);
            _booleanMaterial.SetVector("_TerrainSize", terrain.terrainData.size);
        }

        if (_commandBuffer != null && _commandBufferMask != null) { SetupCommandBuffer(); }
    }

    private void OnDrawGizmos()
    {
        Gizmos.color = Color.green;
        Gizmos.DrawWireCube(transform.position, transform.localScale);
    }

    #endregion
}
