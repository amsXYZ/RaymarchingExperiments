using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

[ExecuteInEditMode, RequireComponent(typeof(Terrain))]
public class TerrainBooleanManager : MonoBehaviour {

    // Terrain Info
    private Terrain _terrain;
    public Texture heightmap;

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

    #region CommandBufferSetup

    void RenderVolume(Mesh mesh, Matrix4x4 modelMatrix, int id)
    {
        MaterialPropertyBlock materialProperties = new MaterialPropertyBlock();
        Vector3 meshScale = Vector3.one;
        switch (id)
        {
            default:
                break;
            case 0:
                meshScale = _booleanOp0.transform.localScale;
                break;
            case 1:
                meshScale = _booleanOp1.transform.localScale;
                break;
            case 2:
                meshScale = _booleanOp2.transform.localScale;
                break;
            case 3:
                meshScale = _booleanOp3.transform.localScale;
                break;
        }

        materialProperties.SetFloat("_MeshScale", meshScale.x);
        materialProperties.SetVector("_MeshScaleInternal", meshScale / meshScale.x * 0.5f);

        int fronMaskID = Shader.PropertyToID("_DepthFront_" + id);
        _commandBufferMask.GetTemporaryRT(fronMaskID, Screen.width, Screen.height, 32, FilterMode.Point, RenderTextureFormat.Depth, RenderTextureReadWrite.Linear);
        _commandBufferMask.SetRenderTarget(fronMaskID);
        _commandBufferMask.ClearRenderTarget(true, true, Color.black);
        _commandBufferMask.DrawMesh(mesh, modelMatrix, _booleanMaterial, 0, 1, materialProperties);
        _commandBufferMask.ReleaseTemporaryRT(fronMaskID);

        int backMaskID = Shader.PropertyToID("_DepthBack_" + id);
        _commandBufferMask.GetTemporaryRT(backMaskID, Screen.width, Screen.height, 32, FilterMode.Point, RenderTextureFormat.Depth, RenderTextureReadWrite.Linear);
        _commandBufferMask.SetRenderTarget(backMaskID);
        _commandBufferMask.ClearRenderTarget(true, true, Color.black);
        _commandBufferMask.DrawMesh(mesh, modelMatrix, _booleanMaterial, 0, 2);
        _commandBufferMask.ReleaseTemporaryRT(backMaskID);
    }

    void SetupCommandBuffer()
    {
        // Clear the previously stored operations in the buffer.
        _commandBufferMask.Clear();

        Matrix4x4[] invModelMatrices = { _booleanOp0.transform.worldToLocalMatrix, _booleanOp1.transform.worldToLocalMatrix, _booleanOp2.transform.worldToLocalMatrix, _booleanOp3.transform.worldToLocalMatrix };
        Matrix4x4[] modelMatrices = { _booleanOp0.transform.localToWorldMatrix, _booleanOp1.transform.localToWorldMatrix, _booleanOp2.transform.localToWorldMatrix, _booleanOp3.transform.localToWorldMatrix };

        Shader.SetGlobalVector("_BooleanScales", new Vector4(_booleanOp0.uniformScale, _booleanOp1.uniformScale, _booleanOp2.uniformScale, _booleanOp3.uniformScale));
        Shader.SetGlobalMatrixArray("_BooleanModelMatrices", invModelMatrices);
        Shader.SetGlobalVector("_CameraForward", _camera.transform.forward);

        RenderVolume(_mesh, modelMatrices[0], 0);
        RenderVolume(_mesh, modelMatrices[1], 1);
        RenderVolume(_mesh, modelMatrices[2], 2);
        RenderVolume(_mesh, modelMatrices[3], 3);
    }

    #endregion

    #region MonoDevelopFunctions

    private void Start()
    {
        _terrain = GetComponent<Terrain>();
        _camera = FindObjectOfType<Camera>();

        // Find Booleans
        _booleans = FindObjectsOfType<TerrainBoolean>();

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

        _terrain.materialTemplate.SetVector("_CameraForward", _camera.transform.forward);
    }

    private void OnDrawGizmos()
    {
        Gizmos.color = Color.green;
        Gizmos.DrawWireCube(transform.position, transform.localScale);
    }

    #endregion
}
