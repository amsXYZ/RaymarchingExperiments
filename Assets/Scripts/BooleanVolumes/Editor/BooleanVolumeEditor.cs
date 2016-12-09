using UnityEngine;
using UnityEditor;

[CustomEditor(typeof(BooleanVolume)), CanEditMultipleObjects]
public class BooleanVolumeEditor : Editor {

    int previousOperationLevel;
    SerializedProperty operationLevel;
    BooleanManager manager;
    BooleanVolume boolean;

    void OnEnable()
    {
        operationLevel = serializedObject.FindProperty("operationLevel");
        previousOperationLevel = operationLevel.intValue;

        manager = FindObjectOfType<BooleanManager>();
        boolean = serializedObject.targetObject as BooleanVolume;
    }

    public override void OnInspectorGUI()
    {
        // Update the changes on the serialized object.
        serializedObject.Update();

        // Draw the default inspector.
        DrawDefaultInspector();

        // Clamp the negative values of threshold to 0.
        if (operationLevel.intValue != previousOperationLevel)
        {
            boolean.operationLevel = previousOperationLevel;
            manager.RemoveBoolean(boolean);

            boolean.operationLevel = operationLevel.intValue;
            manager.AddBoolean(boolean);
            previousOperationLevel = operationLevel.intValue;
        }

        // Temporary solution for uniform scaling.
        boolean.transform.localScale = new Vector3(boolean.uniformScale, boolean.uniformScale, boolean.uniformScale);

        // Apply the changes.
        serializedObject.ApplyModifiedProperties();
    }
}
