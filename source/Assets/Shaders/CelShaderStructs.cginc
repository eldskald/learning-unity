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
    float3 normal : NORMAL;
    float4 tangent : TANGENT;
};

struct Interpolators {
    float4 pos : SV_POSITION;
    float2 uv : TEXCOORD0;
    float3 worldPos : TEXCOORD1;
    float3 normal : TEXCOORD2;

    UNITY_SHADOW_COORDS(3)
    UNITY_FOG_COORDS(4)

    #if defined(_BUMPMAP_ENABLED) || defined(_PARALLAX_ENABLED)
        float3 tangent : TEXCOORD5;
        float3 binormal : TEXCOORD6;
    #endif

    #if defined(DEFERRED_LIGHT_PASS) || defined(_SCREEN_UV_INCLUDED)
        float4 screenUV : TEXCOORD7;
    #endif

    #if defined(LIGHTMAP_ON) || ADDITIONAL_MASKED_DIRECTIONAL_SHADOWS
        float2 lightmapUV : TEXCOORD8;
    #endif

    #if defined(VERTEXLIGHT_ON)
        float4x4 vertexLightColor : TEXCOORD8;
        float4x4 vertexLightPos : TEXCOORD12;
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
};

// This auxiliary function is here to keep interpolated unit vectors with
// unit length. Call at the beginning of every fragment function, or don't if
// you want to see how it looks. It is also less GPU intense by a little bit.
void Renormalize(inout Interpolators i) {
    i.normal = normalize(i.normal);

    #if defined(_BUMPMAP_ENABLED) || defined(_PARALLAX_ENABLED)
        i.tangent = normalize(i.tangent);
        i.binormal = normalize(i.binormal);
    #endif
}

///////////////////////////////////////////////////////////////////////////////



///////////////////////////////////////////////////////////////////////////////
// Basic vertex function that doesn't change geometry, when you just want    //
// to pass on the interpolators to fragment. Can also be used to initiate    //
// the interpolators and then modify them.                                   //
///////////////////////////////////////////////////////////////////////////////

Interpolators BasicVertex (VertexData v) {
    Interpolators o;
    UNITY_INITIALIZE_OUTPUT(Interpolators, o);

    o.pos = UnityObjectToClipPos(v.vertex);
    o.uv = v.uv;
    o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
    o.normal = normalize(UnityObjectToWorldNormal(v.normal));
    
    UNITY_TRANSFER_SHADOW(o, v.uv1)
    UNITY_TRANSFER_FOG(o, o.pos);

    #if defined(_BUMPMAP_ENABLED) || defined(_PARALLAX_ENABLED)
        o.tangent = normalize(UnityObjectToWorldDir(v.tangent.xyz));
        o.binormal = normalize(cross(o.normal, o.tangent.xyz)) *
            v.tangent.w * unity_WorldTransformParams.w;
    #endif

    #if defined(_SCREEN_UV_INCLUDED)
        o.screenUV = ComputeGrabScreenPos(o.pos);
    #endif

    #if defined(VERTEXLIGHT_ON)
        Set4VertexLights(o);
    #endif

    #if defined(LIGHTMAP_ON) || ADDITIONAL_MASKED_DIRECTIONAL_SHADOWS
        o.lightmapUV = v.uv1 * unity_LightmapST.xy + unity_LightmapST.zw;
    #endif

    return o;
}

///////////////////////////////////////////////////////////////////////////////

#endif