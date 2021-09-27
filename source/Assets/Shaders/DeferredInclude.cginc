#if !defined(DEFERRED_INCLUDED)
#define DEFERRED_INCLUDED

#include "CelShaderStructs.cginc"
#include "CelShaderLightHandler.cginc"

#pragma vertex vert
#pragma fragment frag

UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);

sampler2D _LightBuffer;
sampler2D _CameraGBufferTexture0;
sampler2D _CameraGBufferTexture1;
sampler2D _CameraGBufferTexture2;

Interpolators vert (VertexData v) {
    Interpolators o;
    UNITY_INITIALIZE_OUTPUT(Interpolators, o);

    o.pos = UnityObjectToClipPos(v.vertex);
	o.screenUV = ComputeScreenPos(o.pos);
    o.normal = v.normal;
    return o;
}

Surface GetSurface (float2 screenUV) {
    Surface s;
    UNITY_INITIALIZE_OUTPUT(Surface, s);

    s.albedo = tex2D(_CameraGBufferTexture0, screenUV).rgb;
    s.specularColor = tex2D(_CameraGBufferTexture1, screenUV).r;
    s.specularAmount = tex2D(_CameraGBufferTexture1, screenUV).g;
    s.fresnelColor = tex2D(_CameraGBufferTexture1, screenUV).b;
    s.fresnelAmount = tex2D(_CameraGBufferTexture1, screenUV).a;
    s.normal = tex2D(_CameraGBufferTexture2, screenUV).rgb;

    #if defined(_TRANSMISSION_ENABLED)
        s.transmission = tex2D(_CameraGBufferTexture0, screenUV).a;
    #endif

    return s;
}

float4 frag (Interpolators i) : SV_TARGET {
    float2 screenUV = i.screenUV.xy / i.screenUV.w;
    Surface s = GetSurface(screenUV);

    float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, screenUV);
	depth = Linear01Depth(depth);

    float3 rayToFarPlane = i.normal * _ProjectionParams.z / i.normal.z;
    float3 viewPos = rayToFarPlane * depth;
    float3 worldPos = mul(unity_CameraToWorld, float4(viewPos, 1)).xyz;

    return float4(s.albedo, 1);
}

#endif