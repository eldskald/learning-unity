// Outline pass. Translated from GDQuest's Godot outline shader on:
// https://github.com/GDQuest/godot-shaders/blob/master/godot/Shaders/pixel_perfect_outline3D.shader

#if !defined(CEL_SHADER_OUTLINE_INCLUDED) // Include guard check.
#define CEL_SHADER_OUTLINE_INCLUDED

#pragma vertex vert
#pragma fragment frag

#include "UnityCG.cginc"

fixed4 _OutlineColor;
float _OutlineThickness;

struct MeshData {
    float4 vertex : POSITION;
    float4 normal : NORMAL;
};

struct Interpolators {
    float4 pos : SV_POSITION;
    UNITY_FOG_COORDS(0)
};

Interpolators vert (MeshData v) {
    Interpolators o;

    // We convert to clip space to have higher control over thickness, making
    // it according to screen.
    float4 clipPos = UnityObjectToClipPos(v.vertex.xyz);
    float3 clipNormal = UnityObjectToClipPos(v.normal.xyz) - clipPos;

    // We multiply it by thickness over screen size to keep thickness constant
    // over distance.
    clipPos.xy += normalize(clipNormal.xy) / _ScreenParams.xy
        * clipPos.w * _OutlineThickness * 2;
    o.pos = clipPos;

    // Pass on fog information.
    UNITY_TRANSFER_FOG(o, o.pos);

    return o;
}

fixed4 frag (Interpolators i) : SV_TARGET {
    fixed4 col = _OutlineColor;
    UNITY_APPLY_FOG(i.fogCoord, col);
    return col;
}

#endif
