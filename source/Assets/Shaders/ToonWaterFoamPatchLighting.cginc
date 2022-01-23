#if !defined(FOAM_PATCH_LIGHTING_INCLUDED)
#define FOAM_PATCH_LIGHTING_INCLUDED

#include "CelShadedLighting.cginc"

#define PI 3.14159265358979323846

half _FoamSmooth;
half _FoamSize;
half _FoamDisplacement;
half _Agitation;

fixed4 FoamPatchFragment (Interpolators i) {
    fixed4 col = float4(0, 0, 0, 1);

    float2 noisePan = _Time.y * (0.2 + _Agitation * 0.6) / 8;
    half foamNoise = tex2D(_MainTex, i.uv + noisePan).x;
    foamNoise += tex2D(_MainTex, i.uv - noisePan).x;
    half foamDispl = (foamNoise - 1) * _FoamDisplacement;
    float2 ogUV = i.uv / _MainTex_ST.xy - _MainTex_ST.zw;
    float t = saturate(length(ogUV - 0.5) * 2 + foamDispl);
    float foam = 1 - smoothstep(_FoamSize, _FoamSize + _FoamSmooth, t);
    clip(foam - 0.5);

    UnityLight light = GetLight(i);
    col.rgb += light.color * _Color.rgb;

    #if defined(UNITY_PASS_FORWARDBASE)

        // Vertex lights.
        #if defined(VERTEXLIGHT_ON)
            UnityLight vLight0 = GetVertexLight0(i);
            col.rgb += vLight0.color * _Color.rgb;

            UnityLight vLight1 = GetVertexLight1(i);
            col.rgb += vLight1.color * _Color.rgb;

            UnityLight vLight2 = GetVertexLight2(i);
            col.rgb += vLight2.color * _Color.rgb;

            UnityLight vLight3 = GetVertexLight3(i);
            col.rgb += vLight3.color * _Color.rgb;
        #endif

        // Ambient light.
        col.rgb += ShadeSH9(float4(i.normal, 1)) * _Color.rgb;
    #endif

    return col;
}

#endif