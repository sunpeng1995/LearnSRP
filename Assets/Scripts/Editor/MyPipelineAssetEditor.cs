using UnityEditor;
using UnityEditor.Experimental.Rendering;
using UnityEngine;

[CustomEditor(typeof(MyPipelineAsset))]
public class MyPipelineAssetEditor : Editor
{
    SerializedProperty shadowCascades;
    SerializedProperty twoCascadeSplit;
    SerializedProperty fourCascadeSplit;

    private void OnEnable()
    {
        shadowCascades = serializedObject.FindProperty("shadowCascades");
        twoCascadeSplit = serializedObject.FindProperty("twoCascadeSplit");
        fourCascadeSplit = serializedObject.FindProperty("fourCascadeSplit");
    }

    public override void OnInspectorGUI()
    {
        DrawDefaultInspector();

        switch (shadowCascades.enumValueIndex)
        {
            case 0: return;
            case 1:
                CoreEditorUtils.DrawCascadeSplitGUI<float>(ref twoCascadeSplit);
                break;
            case 2:
                CoreEditorUtils.DrawCascadeSplitGUI<Vector3>(ref fourCascadeSplit);
                break;
        }
        serializedObject.ApplyModifiedProperties();
    }
}
