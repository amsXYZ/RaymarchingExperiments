using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

/// <summary>
/// System that takes of efficiently rendering all boolean operations in order.
/// </summary>
[ExecuteInEditMode]
public class BooleanManager : MonoBehaviour {

    // Const values
    private const int OPERATION_LEVELS = 16;

    // TODO: Add support for both cubes and spheres (maybe prisms, cones, etc.)
    [SerializeField, Tooltip("Mesh used for the boolean operations.")]
    private Mesh _mesh;
    [SerializeField, Tooltip("Terrain's heightmap.")]
    private Texture2D _heightmap;
    private Dictionary<int, List<BooleanVolume>> _booleanOperations;
    private Material[] _levelMaterials; // Each operation level has a designated material, so we can maintain the sequentiality of the operations and also use instancing.
    private CommandBuffer _commandBuffer;
    private Camera _camera;

    #region BooleanManagement

    public void AddBoolean(BooleanVolume operation)
    {
        _booleanOperations[operation.operationLevel].Add(operation);
    }

    public void RemoveBoolean(BooleanVolume operation)
    {
        _booleanOperations[operation.operationLevel].Remove(operation);
    }

    #endregion

    #region CommandBufferSetup

    void SetupCommandBuffer()
    {
        // Clear the previously stored operations in the buffer.
        _commandBuffer.Clear();

        // Set the MRTs.
        RenderTargetIdentifier[] mrt = { BuiltinRenderTextureType.GBuffer0, BuiltinRenderTextureType.GBuffer1, BuiltinRenderTextureType.GBuffer2, BuiltinRenderTextureType.GBuffer3 };
        // TODO: Figure out why it cannot find the depth render target.
        _commandBuffer.SetRenderTarget(mrt, BuiltinRenderTextureType.ResolvedDepth);

        // Booleans operations per level.
        for (int i = 0; i < OPERATION_LEVELS; i++)
        {
            Matrix4x4[] instancesPerLevel = new Matrix4x4[_booleanOperations[i].Count];
            if (instancesPerLevel.Length > 0)
            {
                // Get the matrices for each volume instance.
                for (int j = 0; j < instancesPerLevel.Length; j++)
                {
                    instancesPerLevel[j] = _booleanOperations[i][j].transform.localToWorldMatrix;
                }

                // TODO: Figure out how to set individual scales inside of the instancing group.
                // NOTE: It already sets individual values?
                MaterialPropertyBlock materialProperties = new MaterialPropertyBlock();
                materialProperties.SetFloat("_Scale", _booleanOperations[i][0].transform.localScale.x);
                materialProperties.SetFloat("_Color", (i + 1) / OPERATION_LEVELS);

                _commandBuffer.DrawMeshInstanced(_mesh, 0, _levelMaterials[i], 0, instancesPerLevel, instancesPerLevel.Length, materialProperties);
            }
        }
    }

    #endregion

    #region MonoBehaviourFunctions

    private void OnValidate()
    {
        _booleanOperations = new Dictionary<int, List<BooleanVolume>>(OPERATION_LEVELS);
        _levelMaterials = new Material[OPERATION_LEVELS];
        for (int i = 0; i < OPERATION_LEVELS; i++)
        {
            _booleanOperations.Add(i, new List<BooleanVolume>());
            _levelMaterials[i] = new Material(Shader.Find("Hidden/BooleanVolume"));
            _levelMaterials[i].name = "BooleanOps_Level:" + i;
        }

        _camera = FindObjectOfType<Camera>();
        _commandBuffer = new CommandBuffer();
        _commandBuffer.name = "BooleanOps";
        _camera.AddCommandBuffer(CameraEvent.AfterGBuffer, _commandBuffer);

        if(UnityEditor.SceneView.GetAllSceneCameras().Length > 0) UnityEditor.SceneView.GetAllSceneCameras()[0].AddCommandBuffer(CameraEvent.AfterGBuffer, _commandBuffer);
    }

    // TODO: Modify the buffer just when one object transform is modified or a new object is added/removed.
    void Update()
    {
        if (_commandBuffer != null) SetupCommandBuffer();
    }

    #endregion
}
