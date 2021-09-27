#if !defined(CEL_SHADER_LIGHT_HANDLER_INCLUDED)
#define CEL_SHADER_LIGHT_HANDLER_INCLUDED

#include "UnityPBSLighting.cginc"
#include "AutoLight.cginc"
#include "CelShaderStructs.cginc"

static const float SPECULAR_SMOOTHNESS = 0.05;
static const float FRESNEL_SMOOTHNESS = 0.05;
static const float DIFFUSE_SMOOTHNESS = 0.05;



///////////////////////////////////////////////////////////////////////////////
// Light handler functions. They get data from light sources and translate   //
// them for the fragment function to use.                                    //
///////////////////////////////////////////////////////////////////////////////

UnityLight GetLight (Interpolators i) {
    UnityLight light;

    #if defined(POINT) || defined(POINT_COOKIE) || defined(SPOT)
        light.dir = normalize(_WorldSpaceLightPos0.xyz - i.worldPos);
    #else
        light.dir = _WorldSpaceLightPos0.xyz;
    #endif

    UNITY_LIGHT_ATTENUATION(attenuation, i, i.worldPos);
    light.color = _LightColor0.rgb * attenuation;
    return light;
}

void Set4VertexLights (inout Interpolators i) {
    #if defined(VERTEXLIGHT_ON)
        float3 lightPos0 = float3(
            unity_4LightPosX0.x, unity_4LightPosY0.x, unity_4LightPosZ0.x);
        lightPos0 -= i.worldPos;
        i.vertexLightColor._m03 = 1 /
            (1 + dot(lightPos0, lightPos0) * unity_4LightAtten0.x);
        i.vertexLightColor._m00_m01_m02 = unity_LightColor[0].rgb;
        i.vertexLightPos._m00_m01_m02 = lightPos0;

        float3 lightPos1 = float3(
            unity_4LightPosX0.y, unity_4LightPosY0.y, unity_4LightPosZ0.y);
        lightPos1 -= i.worldPos;
        i.vertexLightColor._m13 = 1 /
            (1 + dot(lightPos1, lightPos1) * unity_4LightAtten0.y);
        i.vertexLightColor._m10_m11_m12 = unity_LightColor[1].rgb;
        i.vertexLightPos._m10_m11_m12 = lightPos1;

        float3 lightPos2 = float3(
            unity_4LightPosX0.z, unity_4LightPosY0.z, unity_4LightPosZ0.z);
        lightPos2 -= i.worldPos;
        i.vertexLightColor._m23 = 1 /
            (1 + dot(lightPos2, lightPos2) * unity_4LightAtten0.z);
        i.vertexLightColor._m20_m21_m22 = unity_LightColor[2].rgb;
        i.vertexLightPos._m20_m21_m22 = lightPos2;

        float3 lightPos3 = float3(
            unity_4LightPosX0.w, unity_4LightPosY0.w, unity_4LightPosZ0.w);
        lightPos3 -= i.worldPos;
        i.vertexLightColor._m33 = 1 /
            (1 + dot(lightPos3, lightPos3) * unity_4LightAtten0.w);
        i.vertexLightColor._m30_m31_m32 = unity_LightColor[3].rgb;
        i.vertexLightPos._m30_m31_m32 = lightPos3;
    #endif
}

// Read from diffuse gradient. Used on diffuse, specular and rim.
half DiffuseCurve (UnityLight light, Surface s, sampler2D grad) {
    return tex2D(grad, dot(s.normal, light.dir)).x;
}

// For when you don't want to read from a diffuse gradient, this function
// uses a smoothstep function with the DIFFUSE_SMOOTHNESS constant instead.
// The other functions will have two versions for both of these cases too.
half DiffuseCurve (UnityLight l, Surface s) {
    return smoothstep(0, DIFFUSE_SMOOTHNESS, dot(s.normal, l.dir));
}

// Diffuse light. Directly from my Godot version at
// https://godotshaders.com/shader/complete-toon-shader/
half3 GetDiffuse (UnityLight light, Surface s, sampler2D grad) {
    float value = DiffuseCurve(light, s, grad);

    #if defined(_TRANSMISSION_ENABLED)
        value = value + (1 - value) * s.transmission;
    #endif

    return s.albedo * light.color * value;
}

half3 GetDiffuse (UnityLight light, Surface s) {
    float value = DiffuseCurve(light, s);

    #if defined(_TRANSMISSION_ENABLED)
        value = value + (1 - value) * s.transmission;
    #endif

    return s.albedo * light.color * value;
}

// Specular blob. Also directly from my Godot shader, but the basis is from
// Roystan's https://roystan.net/articles/toon-shader and the anisotropy is
// from https://wiki.unity3d.com/index.php/Anisotropic_Highlight_Shader by
// James O'Hare. It's basically a toonified Blinn-Phong algorithm.
half SpecularValue (UnityLight light, Surface s, float3 viewDir) {
    float3 h = normalize(viewDir + light.dir);
    half glossiness = pow(2, 8 * (1 - s.specularAmount));
    half spec = dot(s.normal, h);

    #if defined(_ANISOTROPY_ENABLED)
        half anisoDot = dot(normalize(s.normal + s.anisoFlowchart), h);
        half aniso = max(0, sin(radians(anisoDot) * 180));
        spec = lerp(spec, aniso, s.anisoScale);
    #endif

    half r = pow(spec, glossiness * glossiness);
    r = smoothstep(0.05, 0.05 + SPECULAR_SMOOTHNESS, r);
    return r;
}

half3 GetSpecular (UnityLight l, Surface s, float3 viewDir, sampler2D grad) {
    half value = SpecularValue(l, s, viewDir);
    return l.color * s.specularColor * value * DiffuseCurve(l, s, grad);
}

half3 GetSpecular (UnityLight l, Surface s, float3 viewDir) {
    half value = SpecularValue(l, s, viewDir);
    return l.color * s.specularColor * value * DiffuseCurve(l, s);
}

// Fresnel effect. From my Godot shader, and the original is also from
// Roystan's https://roystan.net/articles/toon-shader tutorial.
half FresnelValue (UnityLight light, Surface s, float3 viewDir) {
    half vDotN = dot(viewDir, s.normal);
    half lDotN = dot(light.dir, s.normal);
    half threshold = pow((1 - s.fresnelAmount), lDotN);
    half r = smoothstep(
        threshold - FRESNEL_SMOOTHNESS / 2,
        threshold + FRESNEL_SMOOTHNESS / 2,
        1 - vDotN);
    return r;
}

half3 GetFresnel (UnityLight l, Surface s, float3 viewDir, sampler2D grad) {
    half value = FresnelValue (l, s, viewDir);
    return l.color * s.fresnelColor * value * DiffuseCurve(l, s, grad);
}

half3 GetFresnel (UnityLight l, Surface s, float3 viewDir) {
    half value = FresnelValue (l, s, viewDir);
    return l.color * s.fresnelColor * value * DiffuseCurve(l, s);
}

///////////////////////////////////////////////////////////////////////////////

#endif