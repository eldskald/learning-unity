// Handles the lighting part. To be included on Forward Base and Forward Add
// passes. Also processes ambient light, reflections, emission, refraction,
// bump maps and all other things.

#if !defined(CEL_SHADED_LIGHTING_INCLUDED) // Include guard check.
#define CEL_SHADED_LIGHTING_INCLUDED

#pragma vertex vert
#pragma fragment frag

#include "UnityPBSLighting.cginc"
#include "AutoLight.cginc"

half _AlphaCutoff;
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
half _Reflectivity;
half _Blurriness;
sampler2D _ReflectionsMap;
fixed4 _Emission;
sampler2D _EmissionMap;
sampler2D _BumpMap;
half _BumpScale;
sampler2D _ParallaxMap;
half _ParallaxScale;
sampler2D _OcclusionMap;
half _OcclusionScale;
sampler2D _AnisoFlowchart;
half _AnisoScale;
fixed4 _Transmission;
sampler2D _TransmissionMap;

#if defined(_REFRACTION_ENABLED)
    sampler2D _RefractionMap;
    half _RefractionScale;
    sampler2D _GrabTexture;
#endif

// Structs for the vertex function. MeshData is the usual appdata, Interpolators is
// the usual v2f.
struct MeshData {
    float4 vertex : POSITION;
    float2 uv : TEXCOORD0;
    float4 normal : NORMAL;
    float4 tangent : TANGENT;
};

struct Interpolators {
    float4 pos : SV_POSITION;
    float2 uv : TEXCOORD0;
    float3 worldPos : TEXCOORD1;
    float3 worldViewDir : TEXCOORD2;
    float3 normal : TEXCOORD3;

    UNITY_SHADOW_COORDS(4)
    UNITY_FOG_COORDS(5)

    #if defined(_BUMPMAP_ENABLED) || defined(_PARALLAX_ENABLED)
        float4 tangent : TEXCOORD6;
        float3 binormal : TEXCOORD7;
    #endif

    #if defined(_REFRACTION_ENABLED)
        float4 screenUV : TEXCOORD8;
    #endif

    #if defined(VERTEXLIGHT_ON)
        float3 vertexLightColor : TEXCOORD9;
    #endif
};

// Vertex lights processor. We can't really toonify these, they'll depend a lot on
// poly count. If you're going for low poly, lights set to vertex might completely
// mess up the toon look so I would advise you not to use them, but I'm including
// their code here just in case you ever need it. They don't do specular or rim
// lighting. Try having high poly counts and a high diffuse smoothness value to
// make these look less jarring if you ever have to use them.
float3 GetVertexLightColor (float3 worldPos, float3 normal) {
    float3 lightPos0 = float3(
        unity_4LightPosX0.x, unity_4LightPosY0.x, unity_4LightPosZ0.x) - worldPos;
    float3 lightPos1 = float3(
        unity_4LightPosX0.y, unity_4LightPosY0.y, unity_4LightPosZ0.y) - worldPos;
    float3 lightPos2 = float3(
        unity_4LightPosX0.z, unity_4LightPosY0.z, unity_4LightPosZ0.z) - worldPos;
    float3 lightPos3 = float3(
        unity_4LightPosX0.w, unity_4LightPosY0.w, unity_4LightPosZ0.w) - worldPos;

    half nDotL0 = dot(normal, normalize(lightPos0)) > 0 ? 1 : 0;
    half nDotL1 = dot(normal, normalize(lightPos1)) > 0 ? 1 : 0;
    half nDotL2 = dot(normal, normalize(lightPos2)) > 0 ? 1 : 0;
    half nDotL3 = dot(normal, normalize(lightPos3)) > 0 ? 1 : 0;

    half attenuation0 = 1 / (1 + dot(lightPos0, lightPos0) * unity_4LightAtten0.x);
    half attenuation1 = 1 / (1 + dot(lightPos1, lightPos1) * unity_4LightAtten0.y);
    half attenuation2 = 1 / (1 + dot(lightPos2, lightPos2) * unity_4LightAtten0.z);
    half attenuation3 = 1 / (1 + dot(lightPos3, lightPos3) * unity_4LightAtten0.w);

    return
        unity_LightColor[0].rgb * nDotL0 * attenuation0 +
        unity_LightColor[1].rgb * nDotL1 * attenuation1 +
        unity_LightColor[2].rgb * nDotL2 * attenuation2 +
        unity_LightColor[3].rgb * nDotL3 * attenuation3;
}

// Vertex function. We don't change geometry, so it just creates the interpolators
// and passes them on.
Interpolators vert (MeshData v) {
    Interpolators o;
    o.pos = UnityObjectToClipPos(v.vertex);
    o.uv = TRANSFORM_TEX(v.uv, _MainTex);
    o.worldPos = mul(unity_ObjectToWorld, v.vertex);
    o.worldViewDir = normalize(_WorldSpaceCameraPos - o.worldPos);
    o.normal = UnityObjectToWorldNormal(v.normal);
    
    UNITY_TRANSFER_SHADOW(o, o.uv)
    UNITY_TRANSFER_FOG(o, o.pos);

    #if defined(_BUMPMAP_ENABLED) || defined(_PARALLAX_ENABLED)
        o.tangent = float4(UnityObjectToWorldDir(v.tangent.xyz), v.tangent.w);
        o.binormal = cross(o.normal, o.tangent.xyz) *
            o.tangent.w * unity_WorldTransformParams.w;
    #endif

    #if defined(_REFRACTION_ENABLED)
        o.screenUV = ComputeGrabScreenPos(o.pos);
    #endif

    #if defined(VERTEXLIGHT_ON)
        o.vertexLightColor = GetVertexLightColor(o.worldPos, o.normal);
    #endif

    return o;
}

// Helper struct and function to calculate properties of the surface.
// This is mostly applies textures to each property of the material,
// makes reading the fragment shader easier. Could be seen as a surface
// function while the fragment becomes the lighting and GI functions.
struct Surface {
    fixed3 albedo;
    fixed alpha;
    float3 normal;
    half specular;
    half specularAmount;
    half specularSmooth;
    half rim;
    half rimAmount;
    half rimSmooth;

    #if defined(_REFLECTIONS_ENABLED)
        half reflectivity;
        half blurriness;
    #endif

    #if defined(_EMISSION_ENABLED)
        fixed3 emission;
    #endif

    #if defined(_OCCLUSION_ENABLED)
        fixed occlusion;
    #endif

    #if defined(_ANISOTROPY_ENABLED)
        fixed3 anisoFlowchart;
        half anisoScale;
    #endif

    #if defined(_TRANSMISSION_ENABLED)
        fixed3 transmission;
    #endif

    #if defined(_REFRACTION_ENABLED)
        half refraction;
    #endif
};

Surface GetSurface(Interpolators i) {
    Surface s;
    float2 uv = i.uv;

    // Just like I did in the Godot version, I took the built in algorithm used
    // by the engine for parallax. Unity's ParallaxOffset function is available
    // on UnityCG.cginc and you can see it if you want, it's a much simpler version
    // than Godot's deep parallax algorithm. I tried translating Godot's code but
    // the compiler complained about the while loop, saying it wouldn't finish in
    // a timely manner, so we're stuck with Unity's much simpler (yet useful) one.
    // Catlike Coding has a very good tutorial with a different method as well, you
    // can check it at https://catlikecoding.com/unity/tutorials/rendering/part-20/
    #if defined(_PARALLAX_ENABLED)
        float3 tangentViewDir = normalize(float3(
            dot(i.worldViewDir, normalize(i.tangent.xyz)),
            dot(i.worldViewDir, normalize(i.binormal)),
            dot(i.worldViewDir, normalize(i.normal))));
        half height = tex2D(_ParallaxMap, uv).r;
        uv += ParallaxOffset(height, _ParallaxScale / 12.5, tangentViewDir);
    #endif

    s.albedo = _Color.rgb * tex2D(_MainTex, uv).rgb;
    s.alpha = _Color.a * tex2D(_MainTex, uv).a;

    #if defined(_RENDERING_TRANSPARENT) || defined(_REFRACTION_ENABLED)
        s.albedo *= s.alpha;
    #endif

    s.specular = _Specular * tex2D(_SpecularMap, uv).r;
    s.specularAmount = _SpecularAmount * tex2D(_SpecularMap, uv).g;
    s.specularSmooth = _SpecularSmooth * tex2D(_SpecularMap, uv).b;
    s.rim = _Rim * tex2D(_RimMap, uv).r;
    s.rimAmount = _RimAmount * tex2D(_RimMap, uv).g;
    s.rimSmooth = _RimSmooth * tex2D(_RimMap, uv).b;

    #if defined(_REFLECTIONS_ENABLED)
        s.reflectivity = _Reflectivity * tex2D(_ReflectionsMap, uv).r;
        s.blurriness = _Blurriness * tex2D(_ReflectionsMap, uv).g;
    #endif

    #if defined(_EMISSION_ENABLED)
        s.emission = _Emission.rgb * tex2D(_EmissionMap, uv).rgb;
    #endif

    #if defined(_BUMPMAP_ENABLED)
        fixed3 tangentNormal = UnpackScaleNormal(
            tex2D(_BumpMap, uv), _BumpScale);
        s.normal = normalize(
            tangentNormal.x * normalize(i.tangent.xyz) +
            tangentNormal.y * normalize(i.binormal) +
            tangentNormal.z * normalize(i.normal));
    #else
        s.normal = normalize(i.normal);
    #endif

    #if defined(_OCCLUSION_ENABLED)
        s.occlusion = _OcclusionScale * tex2D(_OcclusionMap, uv).r;
    #endif

    #if defined(_ANISOTROPY_ENABLED)
        s.anisoFlowchart = UnpackNormal(tex2D(_AnisoFlowchart, uv));
        s.anisoScale = tex2D(_AnisoFlowchart, uv).a * _AnisoScale;
    #endif

    #if defined(_TRANSMISSION_ENABLED)
        s.transmission = _Transmission.rgb * tex2D(_TransmissionMap, uv).rgb;
    #endif

    #if defined(_REFRACTION_ENABLED)
        s.refraction = _RefractionScale * tex2D(_RefractionMap, uv);
    #endif

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

    UNITY_LIGHT_ATTENUATION(attenuation, i, i.worldViewDir);
    light.attenuation = attenuation;
    light.color = _LightColor0.rgb;
    return light;
}

// Fragment function. This is basically the lighting function, adapted from
// my Godot code on https://godotshaders.com/shader/complete-toon-shader/ with
// some very few changes in order to better translate it to Unity.
half4 frag (Interpolators i) : SV_TARGET {
    Surface s = GetSurface(i);

    #if defined(_RENDERING_CUTOUT)
        clip(s.alpha - _AlphaCutoff);
    #endif

    LightData light = GetLight(i);
    half lightDotNormal = DotClamped(s.normal, light.dir);

    // Calculating diffuse. We use a smoothstep function to toonify the transition
    // between lit and unlit zones using the diffuse smoothness property. The
    // transmission code is directly from my Godot's version of this shader at
    // https://godotshaders.com/shader/complete-toon-shader/ which is basically some
    // math on the dot product to make the light reach the back of the objects. Don't
    // forget to disable shadows cast by the object, or else it will shade it's own
    // back with its shadow and ruin the effect.
    half litness = smoothstep(0, _DiffuseSmooth, lightDotNormal) * light.attenuation;
    half3 diffuse = s.albedo * light.color * litness;
    #if defined(_TRANSMISSION_ENABLED)
        diffuse += s.albedo * light.color * s.transmission * (light.attenuation - litness);
    #endif

    // Specular blob. Toonified Blinn-Phon's specular code, with specular amount
    // for glossiness and a smoothstep function to toonify. We do this math to
    // get glossiness to make changing specular blob size from the inspector smoother.
    // Most of the method is from Roystan's https://roystan.net/articles/toon-shader
    // toon shader tutorial. The anisotropic specular code is from this tutorial from
    // https://wiki.unity3d.com/index.php/Anisotropic_Highlight_Shader by James O'Hare.
    half3 halfVector = normalize(i.worldViewDir + light.dir);
    half glossiness = pow(2, 8 * (1 - s.specularAmount));
    half spec = dot(s.normal, halfVector);
    #if defined(_ANISOTROPY_ENABLED)
        half anisoDot = dot(normalize(s.normal + s.anisoFlowchart), halfVector);
        half aniso = max(0, sin(radians(anisoDot) * 180));
        spec = lerp(spec, aniso, s.anisoScale);
    #endif
    half specIntensity = pow(spec, glossiness * glossiness);
    specIntensity = smoothstep(0.05, 0.05 + s.specularSmooth, specIntensity);
    half3 specular = light.color * s.specular * specIntensity * litness;

    // Fresnel effect with a smoothstep function to toonify, using normal dot light
    // to thin out the rim zone the closer it is to the unlit parts, as done by
    // Roystan in his https://roystan.net/articles/toon-shader toon shader tutorial.
    half viewDotNormal = 1 - DotClamped(i.worldViewDir, s.normal);
    half rimThreshold = pow((1 - s.rimAmount), lightDotNormal);
    half rimIntensity = smoothstep(
        rimThreshold - s.rimSmooth / 2,
        rimThreshold + s.rimSmooth / 2,
        viewDotNormal);
    half3 rim = light.color * s.rim * rimIntensity * litness;

    // Final color incluenced by scene lights.
    half4 col;
    col.rgb = diffuse + specular + rim;
    col.a = 1;

    #if defined(_RENDERING_FADE) || defined(_RENDERING_TRANSPARENT)
        col.a = s.alpha;
    #endif

    // Checking to see if this is the base pass in order to add emission and
    // sample the environment data to add to the final color. Most of that code
    // was made by following https://catlikecoding.com/unity/tutorials/rendering/
    // rendering tutorial by Catlike Coding.
    #if defined(UNITY_PASS_FORWARDBASE)
        half3 ambient = ShadeSH9(float4(s.normal, 1)) * s.albedo;

        #if defined(_REFLECTIONS_ENABLED)
            float3 reflexDir = reflect(-i.worldViewDir, s.normal);
            half roughness = 1.7 * s.blurriness + 0.7 * s.blurriness * s.blurriness;
            half4 envSample = UNITY_SAMPLE_TEXCUBE_LOD(
                unity_SpecCube0, reflexDir, roughness * UNITY_SPECCUBE_LOD_STEPS);
            half3 reflex = DecodeHDR(envSample, unity_SpecCube0_HDR);
            col.rgb += reflex * s.reflectivity;
            ambient *= (1 - s.reflectivity);
        #endif

        #if defined(_EMISSION_ENABLED)
            col.rgb += + s.emission;
        #endif

        #if defined(_OCCLUSION_ENABLED)
            ambient *= s.occlusion;
        #endif

        #if defined(_REFRACTION_ENABLED)
            float3 viewNormal = mul(unity_WorldToObject, float4(s.normal, 0));
            viewNormal = normalize(mul(UNITY_MATRIX_MV, float4(viewNormal, 0)));
            float4 offset = float4(-s.refraction * viewNormal.xy, 0, 0);
            col.rgb += (1 - s.alpha) * tex2Dproj(_GrabTexture, i.screenUV + offset).rgb;
        #endif

        #if defined(VERTEXLIGHT_ON)
            col.rgb += i.vertexLightColor * s.albedo;
        #endif

        col.rgb += ambient;
    #endif

    // Apply fog. We're using Unity's built in fog tool. If you want to learn more
    // about how Unity does it or just about how fog works and what it is overall,
    // Catlike Coding's https://catlikecoding.com/unity/tutorials/rendering/part-14/
    // tutorial on fog is really in depth and worth a read.
    UNITY_APPLY_FOG(i.fogCoord, col);

    return col;
}

#endif