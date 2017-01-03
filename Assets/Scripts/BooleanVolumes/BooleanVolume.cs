using UnityEngine;

[ExecuteInEditMode]
public class BooleanVolume : MonoBehaviour {
    // 16 levels of boolean operations seem decent by now... We'll have to test this.
    [Range(0,15), Tooltip("Level in which this boolean operation will be performed (0 = first, 15 = last).")]
    public int operationLevel = 0;
    [Tooltip("Boolean volume's uniform scale(Transform scale is disabled).")]
    public int uniformScale = 1;

    private void Start()
    {
        FindObjectOfType<BooleanManager>().AddBoolean(this);
    }

    private void OnDrawGizmos()
    {
        Gizmos.color = Color.blue;
        Gizmos.DrawWireSphere(transform.position, transform.localScale.x / 2);
        Gizmos.color = Color.cyan;
        Gizmos.DrawWireCube(transform.position, transform.localScale);
    }
}
