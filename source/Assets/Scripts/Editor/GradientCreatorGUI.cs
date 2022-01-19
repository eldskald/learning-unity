using System.Collections;
using System.Collections.Generic;
using System.IO;
using UnityEngine;
using UnityEditor;

[CustomEditor (typeof(GradientCreator))]
public class GradientCreatorGUI : Editor {

    public override void OnInspectorGUI () {
        GradientCreator creator = target as GradientCreator;

        GUILayout.Label("Gradient Creator", EditorStyles.boldLabel);
        GUILayout.Space(16);

        creator.gradient = EditorGUILayout.GradientField(
            "Gradient", creator.gradient);
        creator.resolution = EditorGUILayout.IntField(
            "Resolution", creator.resolution);
        creator.filePath = EditorGUILayout.TextField(
            "File Path", creator.filePath);
        GUILayout.Space(16);

        if (GUILayout.Button("Save")) {
            Texture2D tex = new Texture2D(creator.resolution, 1);
            tex.wrapMode = TextureWrapMode.Clamp;
            for (int i = 0; i < creator.resolution; i++) {
                tex.SetPixel(i, 0, creator.gradient.Evaluate(
                    i / (float)creator.resolution));
            }
            tex.Apply();
            byte[] data = tex.EncodeToPNG();
            File.WriteAllBytes(string.Format("{0}/{1}",
                Application.dataPath, creator.filePath), data);
        }
    }
}
