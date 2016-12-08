using UnityEngine;
using UnityEditor;

[CustomEditor(typeof(BooleanVolume)), CanEditMultipleObjects]
public class BooleanVolumeEditor : Editor {

    int previousOperationLevel;
    SerializedProperty operationLevel;

    void OnEnable()
    {
        operationLevel = serializedObject.FindProperty("operationLevel");
        previousOperationLevel = operationLevel.intValue;
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
            BooleanManager manager = FindObjectOfType<BooleanManager>();
            BooleanVolume boolean = serializedObject.targetObject as BooleanVolume;

            boolean.operationLevel = previousOperationLevel;
            manager.RemoveBoolean(boolean);

            boolean.operationLevel = operationLevel.intValue;
            manager.AddBoolean(boolean);
            previousOperationLevel = operationLevel.intValue;
        }

        // Apply the changes.
        serializedObject.ApplyModifiedProperties();
    }
}
