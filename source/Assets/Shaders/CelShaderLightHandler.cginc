#if !defined(CEL_SHADER_LIGHT_HANDLER_INCLUDED)
#define CEL_SHADER_LIGHT_HANDLER_INCLUDED

#include "UnityPBSLighting.cginc"
#include "AutoLight.cginc"
#include "CelShaderStructs.cginc"

// Global variables, set by the Cel Shader Settings tool. The diffuse
// texture is a gradient used to toonify and create shade bands, or even
// un-toonify as well. I go into more detail on how to use it on my
// video at https://youtu.be/Y3tT_-GTXKg where I explain each feature
// in detail. I would say this texture is the most important one.
sampler2D _DiffuseTexture;
float _SpecularSmooth;
float _FresnelSmooth;



///////////////////////////////////////////////////////////////////////////////
// Light handler functions. They get data from light sources and translate   //
// them for the fragment function to use.                                    //
///////////////////////////////////////////////////////////////////////////////

// FadeShadows(), GetLight() and Set4VertexLights() functions handle light
// information. All done by following Catlike Coding's rendering tutorial.
float FadeShadows (Interpolators i, float attenuation) {
	#if HANDLE_SHADOWS_BLENDING_IN_GI || ADDITIONAL_MASKED_DIRECTIONAL_SHADOWS
        #if ADDITIONAL_MASKED_DIRECTIONAL_SHADOWS
			attenuation = SHADOW_ATTENUATION(i);
		#endif
		float viewZ =
			dot(_WorldSpaceCameraPos - i.worldPos, UNITY_MATRIX_V[2].xyz);
		float shadowFadeDistance =
			UnityComputeShadowFadeDistance(i.worldPos, viewZ);
		float shadowFade = UnityComputeShadowFade(shadowFadeDistance);
        float bakedAttenuation =
			UnitySampleBakedOcclusion(i.lightmapUV, i.worldPos);
        attenuation = UnityMixRealtimeAndBakedShadows(
			attenuation, bakedAttenuation, shadowFade);
	#endif
	return attenuation;
}

UnityLight GetLight (Interpolators i) {
    UnityLight light;

    #if defined(POINT) || defined(POINT_COOKIE) || defined(SPOT)
        light.dir = normalize(_WorldSpaceLightPos0.xyz - i.worldPos);
    #else
        light.dir = _WorldSpaceLightPos0.xyz;
    #endif

    UNITY_LIGHT_ATTENUATION(attenuation, i, i.worldPos);
    attenuation = FadeShadows(i, attenuation);
    light.color = _LightColor0.rgb * attenuation;

    // This is to remove fall off from point and spot lights.
    #if defined(POINT) || defined(POINT_COOKIE) || defined(SPOT)
        float3 lightVec = _WorldSpaceLightPos0.xyz - i.worldPos;
        light.color *= 1 + dot(lightVec, lightVec);
    #endif

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

UnityLight GetVertexLight0 (Interpolators i) {
    UnityLight vertexLight0;

    #if defined(VERTEXLIGHT_ON)
        vertexLight0.color = i.vertexLightColor._m00_m01_m02;
        vertexLight0.color *= i.vertexLightColor._m03;
        vertexLight0.dir = normalize(i.vertexLightPos._m00_m01_m02);
    #endif

    return vertexLight0;
}

UnityLight GetVertexLight1 (Interpolators i) {
    UnityLight vertexLight1;

    #if defined(VERTEXLIGHT_ON)
        vertexLight1.color = i.vertexLightColor._m10_m11_m12;
        vertexLight1.color *= i.vertexLightColor._m13;
        vertexLight1.dir = normalize(i.vertexLightPos._m10_m11_m12);
    #endif

    return vertexLight1;
}

UnityLight GetVertexLight2 (Interpolators i) {
    UnityLight vertexLight2;

    #if defined(VERTEXLIGHT_ON)
        vertexLight2.color = i.vertexLightColor._m20_m21_m22;
        vertexLight2.color *= i.vertexLightColor._m23;
        vertexLight2.dir = normalize(i.vertexLightPos._m20_m21_m22);
    #endif

    return vertexLight2;
}

UnityLight GetVertexLight3 (Interpolators i) {
    UnityLight vertexLight3;

    #if defined(VERTEXLIGHT_ON)
        vertexLight3.color = i.vertexLightColor._m30_m31_m32;
        vertexLight3.color *= i.vertexLightColor._m33;
        vertexLight3.dir = normalize(i.vertexLightPos._m30_m31_m32);
    #endif

    return vertexLight3;
}

// Read from diffuse gradient. Used on diffuse, specular and rim.
half DiffuseCurve (UnityLight light, Surface s) {
    return tex2D(_DiffuseTexture, dot(s.normal, light.dir)).x;
}

// Diffuse light. Directly from my Godot version at
// https://godotshaders.com/shader/complete-toon-shader/
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
half3 GetSpecular (UnityLight light, Surface s, float3 viewDir) {
    float3 h = normalize(viewDir + light.dir);
    half glossiness = pow(2, 8 * (1 - s.specularAmount));
    half spec = dot(s.normal, h);

    #if defined(_ANISOTROPY_ENABLED)
        half anisoDot = dot(normalize(s.normal + s.anisoFlowchart), h);
        half aniso = max(0, sin(radians(anisoDot) * 180));
        spec = lerp(spec, aniso, s.anisoScale);
    #endif

    half r = pow(spec, glossiness * glossiness);
    r = smoothstep(0.05, 0.05 + _SpecularSmooth, r);
    return light.color * s.specularColor * r * DiffuseCurve(light, s);
}

// Fresnel effect. From my Godot shader, and the original is also from
// Roystan's https://roystan.net/articles/toon-shader tutorial.
half3 GetFresnel (UnityLight light, Surface s, float3 viewDir) {
    half vDotN = dot(viewDir, s.normal);
    half lDotN = dot(light.dir, s.normal);
    half threshold = pow((1 - s.fresnelAmount), lDotN);
    half r = smoothstep(
        threshold - _FresnelSmooth / 2,
        threshold + _FresnelSmooth / 2,
        1 - vDotN);
    return light.color * s.fresnelColor * r * DiffuseCurve(light, s);
}

///////////////////////////////////////////////////////////////////////////////

#endif