using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

[ExecuteInEditMode]
public class TerrainBoolean : MonoBehaviour {

    // Description:
    // - After GBuffer (how to distinguish between terrain and other elements?)
    // - Create TextureArrays containing the maps (height, splat, detail...) corresponding the bounds.
    //   - The bounds are gonna be cubes by now
    //   - The textures are gonna be power of two
    // - Clean buffers inside the bounds
    // - Raymarch using that volume inside the area given by the cube.
    //   - March first to the bounds of the cube.
    //   - Once you're inside the bounding cube, march the terrain.

    // What if you have objects behind?
    // What if the cube is as big as the whole screen? (you're not optimizing anything)

    public TerrainData terrainData;
    public Transform terrainTransform;
    public Texture heightmap;
    [Tooltip("Boolean volume's uniform scale(Transform scale is disabled).")]
    public int uniformScale = 1;

    [SerializeField, Tooltip("Mesh used for the boolean operations.")]
    private Mesh _mesh;
    private Material _booleanMaterial;
    private CommandBuffer _commandBuffer;
    private Camera _camera;

    #region CommandBufferSetup

    void SetupCommandBuffer()
    {
        // Clear the previously stored operations in the buffer.
        _commandBuffer.Clear();

        // Set the MRTs.
        RenderTargetIdentifier[] mrt = { BuiltinRenderTextureType.GBuffer0, BuiltinRenderTextureType.GBuffer1, BuiltinRenderTextureType.GBuffer2, BuiltinRenderTextureType.GBuffer3 };
        // TODO: Figure out why it cannot find the depth render target.
        _commandBuffer.SetRenderTarget(mrt, BuiltinRenderTextureType.ResolvedDepth);

        MaterialPropertyBlock materialProperties = new MaterialPropertyBlock();
        materialProperties.SetFloat("_Scale", transform.localScale.x);

        _commandBuffer.DrawMesh(_mesh, transform.localToWorldMatrix, _booleanMaterial, 0, 0, materialProperties);
    }

    #endregion

    #region MonoDevelopFunctions

    private void OnValidate()
    {
        _camera = FindObjectOfType<Camera>();
        _booleanMaterial = new Material(Shader.Find("Hidden/TerrainBoolean"));
        _booleanMaterial.name = "TerrainBoolean";
        _booleanMaterial.SetTexture("_Heightmap", heightmap);

        _commandBuffer = new CommandBuffer();
        _commandBuffer.name = "TerrainBooleanOps";
        _camera.AddCommandBuffer(CameraEvent.AfterGBuffer, _commandBuffer);

        if (UnityEditor.SceneView.GetAllSceneCameras().Length > 0) UnityEditor.SceneView.GetAllSceneCameras()[0].AddCommandBuffer(CameraEvent.AfterGBuffer, _commandBuffer);
    }

    private void Update()
    {
        if (_commandBuffer != null) SetupCommandBuffer();
    }

    private void OnDrawGizmos()
    {
        Gizmos.color = Color.red;
        Gizmos.DrawWireSphere(transform.position, transform.localScale.x / 2);
        Gizmos.color = Color.magenta;
        Gizmos.DrawWireCube(transform.position, transform.localScale);
    }

    #endregion
}
