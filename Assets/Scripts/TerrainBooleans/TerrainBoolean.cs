using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

[ExecuteInEditMode, RequireComponent(typeof(MeshFilter), typeof(MeshRenderer))]
public class TerrainBoolean : MonoBehaviour {

    [Tooltip("Boolean volume's uniform scale(Transform scale is disabled).")]
    public int uniformScale = 1;

    [SerializeField, Tooltip("Mesh used for the boolean operations.")]
    private Mesh _mesh;
    [SerializeField, Tooltip("Material used for the boolean operations.")]
    private Material _mat;
    private MeshFilter _meshFilter;
    private MeshRenderer _meshRenderer;
    private Camera _camera;
    [SerializeField, Tooltip("Terrain that will be affected by this boolean.")]
    private Terrain _terrain;
    public Texture heightmap;

    #region MonoDevelopFunctions

    private void Start()
    {
        _meshFilter = GetComponent<MeshFilter>();
        _meshFilter.mesh = _mesh;
        _meshRenderer = GetComponent<MeshRenderer>();
        _meshRenderer.sharedMaterial = _mat;

        _camera = FindObjectOfType<Camera>();

        _mat.SetTexture("_Heightmap", heightmap);
        _mat.SetVector("_TerrainPosition", _terrain.transform.position);
        _mat.SetVector("_TerrainSize", _terrain.terrainData.size);
    }

    private void Update()
    {
        //_mat.SetVector("_CameraForward", _camera.transform.forward);
    }

    private void OnDrawGizmos()
    {
        Gizmos.color = Color.red;
        Gizmos.DrawWireMesh(_mesh, 0, transform.position, transform.rotation, transform.localScale);
    }

    #endregion
}
