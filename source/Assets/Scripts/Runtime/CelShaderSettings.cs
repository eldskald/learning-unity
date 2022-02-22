using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public static class CelShaderSettings {

    const string TEXTURE_PATH = "Textures/Gradients/DiffuseGradient";
    const float SPECULAR_SMOOTHNESS = 0.05f;
    const float FRESNEL_SMOOTHNESS = 0.05f;
    const float OUTLINE_THICKNESS = 2.0f;
    private static Color OUTLINE_COLOR = Color.black;
    
    public static void LoadSettings () {
        Texture diffGrad = Resources.Load<Texture>(TEXTURE_PATH);
        Shader.SetGlobalTexture("_DiffuseTexture", diffGrad);
        Shader.SetGlobalFloat("_SpecularSmooth", SPECULAR_SMOOTHNESS);
        Shader.SetGlobalFloat("_FresnelSmooth", FRESNEL_SMOOTHNESS);
        Shader.SetGlobalVector("_OutlineColor", OUTLINE_COLOR);
        Shader.SetGlobalFloat("_OutlineThickness", OUTLINE_THICKNESS);
    }
}
