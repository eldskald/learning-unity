// Handles the lighting part. To be included on Forward Base and Forward Add
// passes. Also processes ambient light, reflections, emission, refraction,
// bump maps and all other things.

#if !defined(CEL_SHADED_LIGHTING_INCLUDED) // Include guard check.
#define CEL_SHADED_LIGHTING_INCLUDED

#pragma vertex vert
#pragma fragment frag

#include "AutoLight.cginc"
#include "UnityPBSLighting.cginc"

fixed4 _Color;
sampler2D _MainTex;
float4 _MainTex_ST;
half _DiffuseSmooth;
half _Specular;
half _SpecularAmount;
half _SpecularSmooth;
sampler2D _SpecularMap;
half _Rim;
half _RimAmount;
half _RimSmooth;
sampler2D _RimMap;
fixed4 _Emission;
sampler2D _EmissionMap;
half _Reflectivity;
half _Blurriness;
sampler2D _ReflectionsMap;

// Vertex function and associated structs. We don't change geometry, so the
// vertex function just creates the interpolators and passes them on.
struct MeshData {
    float4 vertex : POSITION;
    float2 uv : TEXCOORD0;
    float4 normal : NORMAL;
};

struct Interpolators {
    float4 vertex : SV_POSITION;
    float2 uv : TEXCOORD0;
    float3 normal : TEXCOORD1;
    float3 worldPos : TEXCOORD2;
    float3 worldViewDir : TEXCOORD3;
};

Interpolators vert (MeshData v) {
    Interpolators o;
    o.vertex = UnityObjectToClipPos(v.vertex);
    o.uv = TRANSFORM_TEX(v.uv, _MainTex);
    o.normal = UnityObjectToWorldNormal(v.normal);
    o.worldPos = mul(unity_ObjectToWorld, v.vertex);
    o.worldViewDir = normalize(_WorldSpaceCameraPos - o.worldPos);
    return o;
}

// Helper struct and function to calculate properties of the surface.
// This is mostly applies textures to each property of the material,
// makes reading the fragment shader easier. Could be seen as a surface
// function while the fragment becomes the lighting and GI functions.
struct Surface {
    fixed3 albedo;
    fixed alpha;
    half specular;
    half specularAmount;
    half specularSmooth;
    half rim;
    half rimAmount;
    half rimSmooth;
    fixed3 emission;
    half reflectivity;
    half blurriness;
};

Surface GetSurface(Interpolators i) {
    Surface s;
    s.albedo = _Color.rgb * tex2D(_MainTex, i.uv).rgb;
    s.alpha = _Color.a * tex2D(_MainTex, i.uv).a;
    s.specular = _Specular * tex2D(_SpecularMap, i.uv).r;
    s.specularAmount = _SpecularAmount * tex2D(_SpecularMap, i.uv).g;
    s.specularSmooth = _SpecularSmooth * tex2D(_SpecularMap, i.uv).b;
    s.rim = _Rim * tex2D(_RimMap, i.uv).r;
    s.rimAmount = _RimAmount * tex2D(_RimMap, i.uv).g;
    s.rimSmooth = _RimSmooth * tex2D(_RimMap, i.uv).b;
    s.emission = _Emission.rgb * tex2D(_EmissionMap, i.uv).rgb;
    s.reflectivity = _Reflectivity * tex2D(_ReflectionsMap, i.uv).r;
    s.blurriness = _Blurriness * tex2D(_ReflectionsMap, i.uv).g;
    return s;
}

// Helper struct and function to get properties of the current light
// to be used on the fragment function to properly light the mesh.
struct LightData {
    float3 dir;
    fixed3 color;
    half attenuation;
};

LightData GetLight (Interpolators i) {
    LightData light;

    #if defined(POINT) || defined(POINT_COOKIE) || defined(SPOT)
        light.dir = normalize(_WorldSpaceLightPos0.xyz - i.worldPos);
    #else
        light.dir = _WorldSpaceLightPos0.xyz;
    #endif
    
    UNITY_LIGHT_ATTENUATION(atten, 0, i.worldPos);
    light.attenuation = atten;
    light.color = _LightColor0.rgb;
    return light;
}

// Fragment function. This is basically the lighting function, adapted from
// my Godot code on https://godotshaders.com/shader/complete-toon-shader/ with
// some very few changes in order to better translate it to Unity.
half4 frag (Interpolators i) : SV_TARGET {
    i.normal = normalize(i.normal);
    Surface s = GetSurface(i);
    LightData light = GetLight(i);
    half lightDotNormal = DotClamped(i.normal, light.dir);

    // Calculating diffuse. We use a smoothstep function to toonify the transition
    // between lit and unlit zones using the diffuse smoothness property.
    half litness = smoothstep(0, _DiffuseSmooth, lightDotNormal) * light.attenuation;
    half3 diffuse = s.albedo * light.color * litness;

    // Specular blob. Toonified Blinn-Phon's specular code, with specular amount
    // for glossiness and a smoothstep function to toonify. We do this math to
    // get glossiness to make changing specular blob size from the inspector smoother.
    // Most of the method is from Roystan's https://roystan.net/articles/toon-shader
    // toon shader tutorial.
    half3 halfVector = normalize(i.worldViewDir + light.dir);
    half glossiness = pow(2, 8 * (1 - s.specularAmount));
    half specIntensity = pow(dot(i.normal, halfVector), glossiness * glossiness);
    specIntensity = smoothstep(0.05, 0.05 + s.specularSmooth, specIntensity);
    half3 specular = light.color * s.specular * specIntensity * litness;

    // Fresnel effect with a smoothstep function to toonify, using normal dot light
    // to thin out the rim zone the closer it is to the unlit parts, as done by
    // Roystan in his https://roystan.net/articles/toon-shader toon shader tutorial.
    half viewDotNormal = 1 - DotClamped(i.worldViewDir, i.normal);
    half rimThreshold = pow((1 - s.rimAmount), lightDotNormal);
    half rimIntensity = smoothstep(
        rimThreshold - s.rimSmooth / 2,
        rimThreshold + s.rimSmooth / 2,
        viewDotNormal);
    half3 rim = light.color * s.rim * rimIntensity * litness;

    // Final fragment color.
    half4 col;
    col.rgb = diffuse + specular + rim;
    col.a = s.alpha;

    // Checking to see if this is the base pass in order to add emission and
    // sample the environment data to add to the final color. Most of that code
    // was made by following https://catlikecoding.com/unity/tutorials/rendering/
    // rendering tutorial by Catlike Coding.
    #if defined(FORWARD_BASE_PASS)
        col.rgb += + s.emission;

        half3 ambient = ShadeSH9(float4(i.normal, 1));
        col.rgb += ambient * s.albedo * (1 - s.reflectivity);

        float3 reflexDir = reflect(-i.worldViewDir, i.normal);
        half roughness = 1.7 * s.blurriness + 0.7 * s.blurriness * s.blurriness;
        half4 envSample = UNITY_SAMPLE_TEXCUBE_LOD(
            unity_SpecCube0, reflexDir, roughness * UNITY_SPECCUBE_LOD_STEPS);
        half3 reflex = DecodeHDR(envSample, unity_SpecCube0_HDR);
        col.rgb += reflex * s.reflectivity;
    #endif

    return col;
}

#endif