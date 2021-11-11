#if !defined(CEL_SHADER_STRUCTS_INCLUDED)
#define CEL_SHADER_STRUCTS_INCLUDED

#include "UnityPBSLighting.cginc"
#include "AutoLight.cginc"



///////////////////////////////////////////////////////////////////////////////
// Structs for the vertex, fragment, surface and light handler functions.    //
// Keeping data in structs make it easier to call functions with multiple    //
// input data, especially when they are multiple functions with the same     //
// variables as input data.                                                  //
///////////////////////////////////////////////////////////////////////////////

struct VertexData {
    float4 vertex : POSITION;
    float2 uv : TEXCOORD0;
    float2 uv1 : TEXCOORD1;
    float4 normal : NORMAL;
    float4 tangent : TANGENT;
};

struct Interpolators {
    float4 pos : SV_POSITION;
    float2 uv : TEXCOORD0;
    float3 worldPos : TEXCOORD1;
    float3 worldViewDir : TEXCOORD2;
    float3 normal : TEXCOORD3;

    UNITY_SHADOW_COORDS(4)
    UNITY_FOG_COORDS(5)

    #if defined(_BUMPMAP_ENABLED) || defined(_PARALLAX_ENABLED)
        float4 tangent : TEXCOORD6;
        float3 binormal : TEXCOORD7;
    #endif

    #if defined(_REFRACTION_ENABLED) || defined(DEFERRED_LIGHT_PASS)
        float4 screenUV : TEXCOORD8;
    #endif

    #if defined(LIGHTMAP_ON) || ADDITIONAL_MASKED_DIRECTIONAL_SHADOWS
        float2 lightmapUV : TEXCOORD9;
    #endif

    #if defined(VERTEXLIGHT_ON)
        float4x4 vertexLightColor : TEXCOORD9;
        float4x4 vertexLightPos : TEXCOORD13;
    #endif
};

struct Surface {
    fixed3 albedo;
    fixed alpha;
    float3 normal;
    fixed3 specularColor;
    half specularAmount;
    fixed3 fresnelColor;
    half fresnelAmount;

    #if defined(_REFLECTIONS_ENABLED)
        half reflectivity;
        half blurriness;
    #endif

    #if defined(_EMISSION_ENABLED)
        fixed3 emission;
    #endif

    #if defined(_OCCLUSION_ENABLED)
        fixed occlusion;
    #endif

    #if defined(_ANISOTROPY_ENABLED)
        fixed3 anisoFlowchart;
        half anisoScale;
    #endif

    #if defined(_TRANSMISSION_ENABLED)
        half transmission;
    #endif

    #if defined(_REFRACTION_ENABLED)
        half refraction;
    #endif
};

///////////////////////////////////////////////////////////////////////////////

#endif