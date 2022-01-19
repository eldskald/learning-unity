using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;

public class LoadCelShaderSettings {

    // This script runs each time the project loads, it is updated and
    // when you run the game. It sets those constants to the shader
    // settings. Change them manually.
    const string TEXTURE_PATH = "Textures/Gradients/DiffuseGradient";
    const float SPECULAR_SMOOTHNESS = 0.05f;
    const float FRESNEL_SMOOTHNESS = 0.05f;
    static Color OUTLINE_COLOR = Color.black;
    const float OUTLINE_THICKNESS = 3.0f;

    [InitializeOnLoadMethod]
    static void Manager () {

        // We delay it a bit so that when you launch Unity, the editor has
        // enough time to do the imports before running so it can load the
        // texture, otherwise it fails to do so on launch.
        if (!UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode) {
            UnityEditor.EditorApplication.delayCall += LoadSettings;
        }
        else {
            LoadSettings();
        }
    }

    static void LoadSettings () {
        Texture diffGrad = Resources.Load<Texture>(TEXTURE_PATH);
        Shader.SetGlobalTexture("_DiffuseTexture", diffGrad);
        Shader.SetGlobalFloat("_SpecularSmooth", SPECULAR_SMOOTHNESS);
        Shader.SetGlobalFloat("_FresnelSmooth", FRESNEL_SMOOTHNESS);
        Shader.SetGlobalVector("_OutlineColor", OUTLINE_COLOR);
        Shader.SetGlobalFloat("_OutlineThickness", OUTLINE_THICKNESS);
    }
}
