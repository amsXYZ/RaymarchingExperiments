using UnityEngine;
using UnityEditor;

[CustomEditor(typeof(TerrainBoolean)), CanEditMultipleObjects]
public class TerrainBooleanEditor : Editor
{
    TerrainBoolean target;

    void OnEnable()
    {
        target = serializedObject.targetObject as TerrainBoolean;
    }

    public override void OnInspectorGUI()
    {
        // Update the changes on the serialized object.
        serializedObject.Update();

        // Draw the default inspector.
        DrawDefaultInspector();

        // Temporary solution for uniform scaling.
        //target.transform.localScale = new Vector3(target.uniformScale, target.uniformScale, target.uniformScale);

        // Apply the changes.
        serializedObject.ApplyModifiedProperties();
    }
}
