#if !defined(WIND_SWAY_INCLUDED)
#define WIND_SWAY_INCLUDED

#include "UnityCG.cginc"

half4 _Wind;
half _Resistance;
half _Interval;
half _HeightOffset;
sampler2D _VarCurve;
half _VarIntensity;
half _VarFrequency;

// Known RNG method from the Book of Shaders (https://thebookofshaders.com/10/)
float Rand(float2 seed) {
	return frac(sin(dot(seed, float2(12.9898, 78.233))) * 43758.5453123);
}

// Wind function from godotshaders, slightly modified.
float GetWind(float height, float time) {
	float maxStrength = length(_Wind.xy) * 5 / _Resistance;
	float minStrength = length(_Wind.xy) / _Resistance;
	float diff = pow(maxStrength - minStrength, 2.0);
    float strength = minStrength + diff + sin(time / _Interval) * diff;
    strength = max(strength, minStrength);
    strength = min(strength, maxStrength);

    float4 texUV = float4(frac(time * _VarFrequency), 0, 0, 0);
    float varSample = tex2Dlod(_VarCurve, texUV).r;
    float var = (varSample * 2 - 1) * _VarIntensity;

    float deform = (1 + sin(time) + var) * strength;
    float heightScale = max(0.0, height - _HeightOffset);
    return deform * heightScale;
}

// Vertex displacing function.
float4 WindDisplaceVertex(float4 vertex) {
    float4 worldOrigin = mul(unity_ObjectToWorld, float4(0, 0, 0, 1));
    float windTime = _Time.y * length(_Wind) + Rand(worldOrigin.xz) * 256;
    float2 localWind = mul(
        unity_WorldToObject, float4(_Wind.x, 0, _Wind.y, 0)).xz;
    float4 r = vertex;
    r.xz += localWind * GetWind(vertex.y, windTime);
    return r;
}

#endif