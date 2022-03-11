#if !defined(SMOKE_PARTICLES_INC_INCLUDED)
#define SMOKE_PARTICLES_INC_INCLUDED

#include "CelShaderLightHandler.cginc"

struct appdata {
    float4 vertex : POSITION;
    float4 uv : TEXCOORD0;
    float4 uv1 : TEXCOORD1;
    float4 color : COLOR;
    float4 normal : NORMAL;
};

struct v2f {
    float2 uv : TEXCOORD0; 
    float4 pos : SV_POSITION;
    float4 color : COLOR;
    float3 worldPos : TEXCOORD1;
    float3 normal : TEXCOORD2;
    float4 projPos : TEXCOORD3;
    float age : TEXCOORD4;
    float2 size : TEXCOORD5;
    float2 random : TEXCOORD6;

    UNITY_FOG_COORDS(7)

    #if defined(VERTEXLIGHT_ON)
        float4x4 vertexLightColor : TEXCOORD8;
        float4x4 vertexLightPos : TEXCOORD12;
    #endif
};

sampler2D _MainTex, _Noise;
float4 _Noise_ST;
half _SpeedX, _SpeedY, _Softness, _FadeIn, _FadeOut, _NearFade, _FarFade;

sampler2D_float _CameraDepthTexture;

v2f FogVertex (appdata v) {
    v2f o;
    UNITY_INITIALIZE_OUTPUT(v2f, o);

    o.worldPos = mul(unity_ObjectToWorld, v.vertex);
    o.pos = UnityObjectToClipPos(v.vertex);
    o.uv = v.uv.xy;
    o.color = v.color;
    o.age = v.uv.z;
    o.random = float2(v.uv.w, v.uv1.x);
    o.size = v.uv1.zw;
    o.normal = mul(unity_ObjectToWorld, v.normal);
    o.projPos = ComputeScreenPos(o.pos);
    COMPUTE_EYEDEPTH(o.projPos.z);
    UNITY_TRANSFER_FOG(o, o.pos);

    #if defined(VERTEXLIGHT_ON)
        Set4VertexLights(o);
    #endif

    return o;
}

fixed4 FogFragment (v2f i) {
    float mask = tex2D(_MainTex, i.uv).x;
    float4 col;

    // Noise pans on both Y and X directions. Not taking into account
    // the angle at which we are looking the particles from this time.
    float2 noiseUV = (i.uv + i.random) * _Noise_ST.xy * i.size;
    noiseUV += _Time.y * float2(_SpeedX, _SpeedY);
    float noise = tex2D(_Noise, noiseUV).x;


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
    col.a = mask * noise * i.color.a;
    col.a *= smoothstep(0, _FadeIn, i.age);
    col.a *= 1 - smoothstep(_FadeOut, 1, i.age);

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
        col.rgb += ShadeSH9(float4(i.normal, 1)) * i.color.rgb;
    #endif

    return col;
}

#endif