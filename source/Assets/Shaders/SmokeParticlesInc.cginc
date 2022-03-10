#if !defined(SMOKE_PARTICLES_INC_INCLUDED)
#define SMOKE_PARTICLES_INC_INCLUDED

#include "CelShaderLightHandler.cginc"

struct appdata {
    float4 vertex : POSITION;
    float3 uv : TEXCOORD0;
    float2 uv1 : TEXCOORD1;
    float4 color : COLOR;
    float4 normal : NORMAL;
    float4 tangent : TANGENT;
};

struct v2f {
    float3 uv : TEXCOORD0;
    float4 pos : SV_POSITION;
    float4 color : COLOR;
    float3 worldPos : TEXCOORD1;
    float3 worldOrigin : TEXCOORD2;
    float3 worldNormal : TEXCOORD3;
    float3 worldTangent : TEXCOORD4;
    float4 projPos : TEXCOORD5;

    UNITY_SHADOW_COORDS(6)
    UNITY_FOG_COORDS(7)

    #if defined(VERTEXLIGHT_ON)
        float4x4 vertexLightColor : TEXCOORD8;
        float4x4 vertexLightPos : TEXCOORD12;
    #endif
};

sampler2D _MainTex, _NoiseA, _NoiseB;
float4 _NoiseA_ST, _NoiseB_ST;
half _SpeedXA, _SpeedYA, _SpeedXB, _SpeedYB;
half _Softness, _FadeIn, _FadeOut, _NearFade, _FarFade;

sampler2D_float _CameraDepthTexture;

v2f SmokeVertex (appdata v) {
    v2f o;
    UNITY_INITIALIZE_OUTPUT(v2f, o);

    o.worldPos = mul(unity_ObjectToWorld, v.vertex);
    o.worldOrigin = mul(unity_ObjectToWorld, float4(0, 0, 0, 1));
    o.worldNormal = mul(unity_ObjectToWorld, v.normal);
    o.worldTangent = normalize(UnityObjectToWorldDir(v.tangent.xyz));
    o.pos = UnityObjectToClipPos(v.vertex);
    o.uv = v.uv;
    o.color = v.color;
    o.projPos = ComputeScreenPos(o.pos);
    COMPUTE_EYEDEPTH(o.projPos.z);

    UNITY_TRANSFER_SHADOW(o, v.uv1)
    UNITY_TRANSFER_FOG(o, o.pos);

    #if defined(VERTEXLIGHT_ON)
        Set4VertexLights(o);
    #endif

    return o;
}

fixed4 SmokeFragment (v2f i) {
    float mask = tex2D(_MainTex, i.uv.xy).x;
    float4 col;

    // Noise pans on both Y and X directions. The X direction in this case
    // is the unit vector perpendicular to the normal and the Y axis. Of
    // course, this is assuming billboard mode quad shaped particles.
    float3 yDir = float3(0, 1, 0);
    float3 xDir = normalize(i.worldTangent);
    float blend = saturate(pow(i.worldNormal * 1.4, 4)).x;

    // Noise A
    float3 noiseAPos = i.worldPos;
    noiseAPos -= _Time.y * (_SpeedXA * xDir + _SpeedYA * yDir);
    float xa = tex2D(_NoiseA, noiseAPos.zy * _NoiseA_ST.xy).x;
    float za = tex2D(_NoiseA, noiseAPos.xy * _NoiseA_ST.xy).x;
    float noiseA = lerp(za, xa, blend);

    // Noise B
    float3 noiseBPos = i.worldPos;
    noiseBPos -= _Time.y * (_SpeedXB * xDir + _SpeedYB * yDir);
    float xb = tex2D(_NoiseB, noiseBPos.zy * _NoiseB_ST.xy).x;
    float zb = tex2D(_NoiseB, noiseBPos.xy * _NoiseB_ST.xy).x;
    float noiseB = lerp(zb, xb, blend);

    // Final color and alpha values. We need lighting this time.
    Interpolators inter;
    UNITY_INITIALIZE_OUTPUT(Interpolators, inter);
    inter.worldPos = i.worldPos;
    #if defined(VERTEXLIGHT_ON)
        inter.vertexLightColor = i.vertexLightColor;
        inter.vertexLightPos = i.vertexLightPos;
    #endif

    UnityLight light = GetLight(inter);
    col.rgb = light.color * i.color.rgb;
    col.a = mask * noiseA * noiseB * i.color.a;
    col.a *= smoothstep(0, _FadeIn, i.uv.z);
    col.a *= 1 - smoothstep(_FadeOut, 1, i.uv.z);

    // Soft particles fading.
    float zDepth = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE_PROJ(
        _CameraDepthTexture, UNITY_PROJ_COORD(i.projPos)));
    float zPos = i.projPos.z;
    col.a *= saturate((zDepth - zPos) / (0.01 + _Softness * 10));

    // Camera distance fading.
    col.a *= smoothstep(_NearFade / 2, _NearFade, zPos);
    col.a *= 1 - smoothstep(_FarFade, _FarFade + _NearFade, zPos);

    #if defined(UNITY_PASS_FORWARDBASE)

        // Vertex lights.
        #if defined(VERTEXLIGHT_ON)
            UnityLight vLight0 = GetVertexLight0(inter);
            col.rgb += vLight0.color * i.color.rgb;

            UnityLight vLight1 = GetVertexLight1(inter);
            col.rgb += vLight1.color * i.color.rgb;

            UnityLight vLight2 = GetVertexLight2(inter);
            col.rgb += vLight2.color * i.color.rgb;

            UnityLight vLight3 = GetVertexLight3(inter);
            col.rgb += vLight3.color * i.color.rgb;
        #endif

        // Ambient light.
        col.rgb += ShadeSH9(float4(i.worldNormal, 1)) * i.color.rgb;
    #endif

    return col;
}

#endif