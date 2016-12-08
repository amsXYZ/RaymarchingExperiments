using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

/// <summary>
/// System that takes of efficiently rendering all boolean operations in order.
/// </summary>
[ExecuteInEditMode]
#if UNITY_5_4_OR_NEWER
[ImageEffectAllowedInSceneView]
#endif
public class BooleanManager : MonoBehaviour {

    // Const values
    private const int OPERATION_LEVELS = 16;

    // TODO: Add support for both cubes and spheres (maybe prisms, cones, etc.)
    [SerializeField, Tooltip("Mesh used for the boolean operations.")]
    private Mesh _mesh;
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

    public struct Ray
    {
        public Vector3 Corner;
        public Vector3 Right;
        public Vector3 Up;
    }
    public static void GetRay(Camera cam, out Ray ray)
    {
        var t = cam.transform;

        var fov = Mathf.Tan(cam.fieldOfView * 0.5f * Mathf.Deg2Rad);

        var forward = t.forward;
        var right = t.right * fov * cam.aspect;
        var up = t.up * fov;

        ray.Corner = forward - right - up;
        ray.Right = right * 2f;
        ray.Up = up * 2f;
    }

    void SetupCommandBuffer()
    {
        // Clear the previously stored operations in the buffer.
        _commandBuffer.Clear();

        // Ray creation.
        Ray cameraRay;
        GetRay(_camera, out cameraRay);
        _commandBuffer.SetGlobalVector("sdf_Corner", cameraRay.Corner);
        _commandBuffer.SetGlobalVector("sdf_Right", cameraRay.Right);
        _commandBuffer.SetGlobalVector("sdf_Up", cameraRay.Up);

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

                // TODO: Add support for Material Property Blocks. They should also affect the grouping of the booleans, as you can just set one per instancing level.
                _commandBuffer.DrawMeshInstanced(_mesh, 0, _levelMaterials[i], 0, instancesPerLevel, instancesPerLevel.Length);
            }
        }
    }
    #endregion

    #region MonoBehaviourFunctions
    // Before any booleans are introduced in the system, setup the dictionary and materials used by every boolean on each level of operations.
    void Awake()
    {
        _booleanOperations = new Dictionary<int, List<BooleanVolume>>(OPERATION_LEVELS);
        _levelMaterials = new Material[OPERATION_LEVELS];
        for (int i = 0; i < OPERATION_LEVELS; i++)
        {
            _booleanOperations.Add(i, new List<BooleanVolume>());
            _levelMaterials[i] = new Material(Shader.Find("Hidden/BooleanVolume"));
            _levelMaterials[i].name = "BooleanOps_Level:" + i;
        }
    }

    // After all the boolean operations are plugged into our system, we can create our command buffer.
    // (SceneView.lastActiveSceneView is not initalized in Awake, that's why I do it here).
    void Start()
    {
        _camera = FindObjectOfType<Camera>();
        _commandBuffer = new CommandBuffer();
        _commandBuffer.name = "BooleanOps";
        _camera.AddCommandBuffer(CameraEvent.AfterGBuffer, _commandBuffer);

        // TODO: Fix scene view
        /*if (Application.isEditor)
        {
            UnityEditor.SceneView.lastActiveSceneView.camera.AddCommandBuffer(CameraEvent.AfterGBuffer, _commandBuffer);
        }*/
    }

    // TODO: Modify the buffer just when one object transform is modified or a new object is added/removed.
    void Update()
    {
        if (_commandBuffer != null) SetupCommandBuffer();
    }
    #endregion
}
