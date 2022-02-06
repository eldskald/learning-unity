#if !defined(WATER_RIPPLE_LIGHTING_INCLUDED)
#define WATER_RIPPLE_LIGHTING_INCLUDED

#include "CelShaderLightHandler.cginc"

struct appdata {
    float4 vertex : POSITION;
    float3 normal : NORMAL;
    fixed4 color : COLOR;
    float3 uv : TEXCOORD0;
    float2 uv1 : TEXCOORD1;
};

struct v2f {
    float3 uv : TEXCOORD0;
    float4 pos : SV_POSITION;
    fixed4 color : COLOR;
    float3 worldPos : TEXCOORD1;
    float3 normal : TEXCOORD2;

    UNITY_SHADOW_COORDS(3)
    UNITY_FOG_COORDS(4)

    #if defined(VERTEXLIGHT_ON)
        float4x4 vertexLightColor : TEXCOORD8;
        float4x4 vertexLightPos : TEXCOORD12;
    #endif
};

half _FadeStart;
half _Width;

v2f WaterRippleVertex (appdata v) {
    v2f o;
    UNITY_INITIALIZE_OUTPUT(v2f, o)

    o.pos = UnityObjectToClipPos(v.vertex);
    o.uv = v.uv;
    o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
    o.normal = normalize(UnityObjectToWorldNormal(v.normal));
    o.color = v.color;

    UNITY_TRANSFER_SHADOW(o, v.uv1)
    UNITY_TRANSFER_FOG(o, o.pos);

    #if defined(VERTEXLIGHT_ON)
        Set4VertexLights(o);
    #endif

    return o;
}

fixed4 WaterRippleFragment (v2f i) {
    fixed4 col = float4(0, 0, 0, 1);

    float r = length(i.uv.xy - 0.5) * 2;
    float outer = i.uv.z;
    float inner = i.uv.z - _Width * (1 - smoothstep(_FadeStart, 1.0, i.uv.z));
    half check = r > inner && r < outer ? 1.0 : 0.0;
    clip(check - 0.5);

    Interpolators inter;
    UNITY_INITIALIZE_OUTPUT(Interpolators, inter);
    inter.worldPos = i.worldPos;
    #if defined(VERTEXLIGHT_ON)
        inter.vertexLightColor = i.vertexLightColor;
        inter.vertexLightPos = i.vertexLightPos;
    #endif

    UnityLight light = GetLight(inter);
    col.rgb += light.color * i.color.rgb;

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