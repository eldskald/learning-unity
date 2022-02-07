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
	float maxStrength = 5 / _Resistance;
	float minStrength = 1 / _Resistance;
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

float4 WindDisplaceVertex (float4 vertex) {
    float4 worldOrigin = mul(unity_ObjectToWorld, float4(0, 0, 0, 1));
    float windTime = _Time.y * length(_Wind.xyz) + Rand(worldOrigin.xz) * 256;

    float4 r = mul(unity_ObjectToWorld, vertex);
    r.xyz += _Wind.xyz * GetWind(r.y, windTime);
    return mul(unity_WorldToObject, r);
}

#endif