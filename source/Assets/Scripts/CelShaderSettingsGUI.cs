using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;

[CustomEditor (typeof(CelShaderSettings))]
[CanEditMultipleObjects]
public class CelShaderSettingsGUI : Editor {

    SerializedProperty diffuseGrad;
    SerializedProperty specSmooth;
    SerializedProperty fresSmooth;

    private void OnEnable() {
        diffuseGrad = serializedObject.FindProperty("diffuseGradient");
        specSmooth = serializedObject.FindProperty("specularSmoothness");
        fresSmooth = serializedObject.FindProperty("fresnelSmoothness");
    }

    public override void OnInspectorGUI () {
        CelShaderSettings settings = target as CelShaderSettings;

        GUILayout.Label("Cel Shader Settings", EditorStyles.boldLabel);
        GUILayout.Space(16);

        EditorGUI.BeginChangeCheck();
        EditorGUILayout.PropertyField(
            diffuseGrad, new GUIContent("Diffuse Gradient"));
        EditorGUILayout.PropertyField(
            specSmooth, new GUIContent("Specular Smoothness"));
        EditorGUILayout.PropertyField(
            fresSmooth, new GUIContent("Fresnel Smoothness"));
        serializedObject.ApplyModifiedProperties();
        if (EditorGUI.EndChangeCheck()) {
            Texture texture = diffuseGrad.objectReferenceValue as Texture;
            Shader.SetGlobalTexture("_DiffuseTexture", texture);
            Shader.SetGlobalFloat("_SpecularSmooth", specSmooth.floatValue);
            Shader.SetGlobalFloat("_FresnelSmooth", fresSmooth.floatValue);
        }
        

    }
}
