using System;
using System.Collections;
using System.Collections.Generic;
using UnityEditor;
using UnityEngine;

[ExecuteInEditMode]
public class BooleanVolume : MonoBehaviour {
    // 16 levels of boolean operations seem decent by now... We'll have to test this.
    [Range(0,15), Tooltip("Level in which this boolean operation will be performed (0 = first, 15 = last).")]
    public int operationLevel = 0;

    void Start()
    {
        FindObjectOfType<BooleanManager>().AddBoolean(this);
    }

    void OnDrawGizmos()
    {
        Gizmos.color = Color.white;
        Gizmos.DrawWireCube(transform.position, transform.localScale);
    }
}
