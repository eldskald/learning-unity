#if !defined(SHADOW_CASTER_INCLUDED)
#define SHADOW_CASTER_INCLUDED

#pragma vertex vert
#pragma fragment frag

#include "UnityCG.cginc"

half _Cutoff;
half _ShadowStrength;
fixed4 _Color;
sampler2D _MainTex;
float4 _MainTex_ST;
sampler3D _DitherMaskLOD;

struct MeshData {
    float4 vertex : POSITION;
    float3 normal : NORMAL;
    float2 uv : TEXCOORD0;
};

struct VertexInterpolators {
    float4 pos : SV_POSITION;
    float2 uv : TEXCOORD0;

    #if defined(SHADOWS_CUBE)
        float3 lightVec : TEXCOORD1;
    #endif
};

struct Interpolators {
    #if defined(_DITHER_SHADOWS)
        UNITY_VPOS_TYPE vpos : VPOS;
    #else
        float4 pos : SV_POSITION;
    #endif

    float2 uv : TEXCOORD0;

    #if defined(SHADOWS_CUBE)
        float3 lightVec : TEXCOORD1;
    #endif
};

VertexInterpolators vert (MeshData v) {
    VertexInterpolators o;
    o.uv = TRANSFORM_TEX(v.uv, _MainTex);

    #if defined(SHADOWS_CUBE)
        o.pos = UnityObjectToClipPos(v.vertex);
        o.lightVec = mul(unity_ObjectToWorld, v.vertex).xyz -
            _LightPositionRange.xyz;
    #else
        o.pos = UnityClipSpaceShadowCasterPos(v.vertex.xyz, v.normal);
        o.pos = UnityApplyLinearShadowBias(o.pos);
    #endif

    return o;
}

float4 frag (Interpolators i) : SV_TARGET {
    half alpha = _Color.a * tex2D(_MainTex, i.uv).a;

    #if defined(_CUTOUT_SHADOWS)
        clip(alpha - _Cutoff);
    #endif

    #if defined(_DITHER_SHADOWS)
        half dither = tex3D(
            _DitherMaskLOD, float3(i.vpos.xy * 0.25, _ShadowStrength * 0.9375)).a;
        clip(dither - 0.5);
    #endif

    #if defined(SHADOWS_CUBE)
        float depth = length(i.lightVec) + unity_LightShadowBias.x;
        depth *= _LightPositionRange.w;
        return UnityEncodeCubeShadowDepth(depth);
    #else
        return 0;
    #endif
}

#endif