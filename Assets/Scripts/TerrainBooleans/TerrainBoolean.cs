using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

[ExecuteInEditMode, RequireComponent(typeof(MeshFilter), typeof(MeshRenderer))]
public class TerrainBoolean : MonoBehaviour {

    private enum BooleanType { SPHERE, CAPSULE, CYLINDER, CUBE }

    [SerializeField]
    private BooleanType _booleanType = BooleanType.SPHERE;
    [SerializeField, Tooltip("Terrain that will be affected by this boolean.")]
    private Terrain _terrain;
    public Texture heightmap;

    private MeshFilter _meshFilter;
    private MeshRenderer _meshRenderer;

    private BoundingSphere _bounds;
    public BoundingSphere Bounds
    {
        get { return _bounds; }
    }

    #region MonoDevelopFunctions

    private void Start()
    {
        _meshFilter = GetComponent<MeshFilter>();
        _meshRenderer = GetComponent<MeshRenderer>();

        _meshRenderer.sharedMaterial.SetTexture("_Heightmap", heightmap);
        _meshRenderer.sharedMaterial.SetVector("_TerrainPosition", _terrain.transform.position);
        _meshRenderer.sharedMaterial.SetVector("_TerrainSize", _terrain.terrainData.size);
    }

    private void Update()
    {
        // Create an event for this.
        GameObject tempGO = GameObject.CreatePrimitive((PrimitiveType)_booleanType);
        Mesh mesh = tempGO.GetComponent<MeshFilter>().sharedMesh;
        DestroyImmediate(tempGO);
        _meshFilter.mesh = mesh;

        _bounds.position = transform.position;
        float boundingRadius = 0;
        switch (_booleanType)
        {
            case BooleanType.SPHERE:
                boundingRadius = Mathf.Max(Mathf.Abs(transform.localScale.x), Mathf.Abs(transform.localScale.y), Mathf.Abs(transform.localScale.z)) / 2;
                break;
            case BooleanType.CAPSULE:
            case BooleanType.CYLINDER:
                boundingRadius = Mathf.Max(Mathf.Abs(transform.localScale.x) / 2, Mathf.Abs(transform.localScale.z)) / 2;
                boundingRadius = Mathf.Sqrt(Mathf.Pow(boundingRadius, 2) + Mathf.Pow(Mathf.Abs(transform.localScale.y), 2));
                break;
            case BooleanType.CUBE:
                boundingRadius = Mathf.Sqrt(Mathf.Pow(Mathf.Abs(transform.localScale.x) / 2, 2) + Mathf.Pow(Mathf.Abs(transform.localScale.z) / 2, 2));
                boundingRadius = Mathf.Sqrt(Mathf.Pow(boundingRadius, 2) + Mathf.Pow(Mathf.Abs(transform.localScale.y) / 2, 2));
                break;
        }
        _bounds.radius = boundingRadius;
    }

    private void OnDrawGizmos()
    {
        Gizmos.color = Color.cyan;
        Gizmos.DrawWireSphere(_bounds.position, _bounds.radius);
    }

    #endregion
}
