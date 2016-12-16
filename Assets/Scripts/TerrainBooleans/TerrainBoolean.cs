using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

[ExecuteInEditMode]
public class TerrainBoolean : MonoBehaviour {

    [Tooltip("Boolean volume's uniform scale(Transform scale is disabled).")]
    public int uniformScale = 1;

    public Bounds AABB;

    [SerializeField, Tooltip("Mesh used for the boolean operations.")]
    private Mesh _mesh;

    public Bounds GetBounds()
    {
        Bounds meshBounds = _mesh.bounds;

        Vector3 corner0 = transform.position + meshBounds.extents.x * transform.localScale.x * transform.right - meshBounds.extents.y * transform.localScale.y * transform.up + meshBounds.extents.z * transform.localScale.z * transform.forward;
        Vector3 corner1 = transform.position + meshBounds.extents.x * transform.localScale.x * transform.right - meshBounds.extents.y * transform.localScale.y * transform.up - meshBounds.extents.z * transform.localScale.z * transform.forward;
        Vector3 corner2 = transform.position - meshBounds.extents.x * transform.localScale.x * transform.right - meshBounds.extents.y * transform.localScale.y * transform.up - meshBounds.extents.z * transform.localScale.z * transform.forward;
        Vector3 corner3 = transform.position - meshBounds.extents.x * transform.localScale.x * transform.right - meshBounds.extents.y * transform.localScale.y * transform.up + meshBounds.extents.z * transform.localScale.z * transform.forward;
        Vector3 corner4 = transform.position + meshBounds.extents.x * transform.localScale.x * transform.right + meshBounds.extents.y * transform.localScale.y * transform.up + meshBounds.extents.z * transform.localScale.z * transform.forward;
        Vector3 corner5 = transform.position + meshBounds.extents.x * transform.localScale.x * transform.right + meshBounds.extents.y * transform.localScale.y * transform.up - meshBounds.extents.z * transform.localScale.z * transform.forward;
        Vector3 corner6 = transform.position - meshBounds.extents.x * transform.localScale.x * transform.right + meshBounds.extents.y * transform.localScale.y * transform.up - meshBounds.extents.z * transform.localScale.z * transform.forward;
        Vector3 corner7 = transform.position - meshBounds.extents.x * transform.localScale.x * transform.right + meshBounds.extents.y * transform.localScale.y * transform.up + meshBounds.extents.z * transform.localScale.z * transform.forward;

        Vector3 min = Vector3.Min(corner0, corner1);
        min = Vector3.Min(min, corner2);
        min = Vector3.Min(min, corner3);
        min = Vector3.Min(min, corner4);
        min = Vector3.Min(min, corner5);
        min = Vector3.Min(min, corner6);
        min = Vector3.Min(min, corner7);

        Vector3 max = Vector3.Max(corner0, corner1);
        max = Vector3.Max(max, corner2);
        max = Vector3.Max(max, corner3);
        max = Vector3.Max(max, corner4);
        max = Vector3.Max(max, corner5);
        max = Vector3.Max(max, corner6);
        max = Vector3.Max(max, corner7);

        return new Bounds(transform.position, max - min);
    }

    #region MonoDevelopFunctions

    private void Start()
    {
        AABB = GetBounds();
    }

    private void Update()
    {
        AABB = GetBounds();
    }

    private void OnDrawGizmos()
    {
        Gizmos.color = Color.red;
        Gizmos.DrawWireMesh(_mesh, 0, transform.position, transform.rotation, transform.localScale);
        Gizmos.color = Color.magenta;
        Gizmos.DrawWireCube(AABB.center, AABB.size);
    }

    #endregion
}
