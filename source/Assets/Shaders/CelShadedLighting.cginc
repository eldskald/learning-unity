#if !defined(CEL_SHADED_LIGHTING_INCLUDED)
#define CEL_SHADED_LIGHTING_INCLUDED

#pragma vertex vert
#pragma fragment frag

#include "UnityPBSLighting.cginc"
#include "AutoLight.cginc"

half _Cutoff;
fixed4 _Color;
sampler2D _MainTex;
float4 _MainTex_ST;
half _DiffuseSmooth;
sampler2D _DiffuseGradient;
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
sampler2D _RefractionMap;
half _RefractionScale;
sampler2D _GrabTexture;



///////////////////////////////////////////////////////////////////////////////
// Structs for the vertex and fragment functions. MeshData is the usual      //
// appdata and Interpolators is the usual v2f.                               //
///////////////////////////////////////////////////////////////////////////////

struct MeshData {
    float4 vertex : POSITION;
    float2 uv : TEXCOORD0;
    float2 uv1 : TEXCOORD1;
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

    #if defined(LIGHTMAP_ON)
        float2 lightmapUV : TEXCOORD9;
    #endif

    #if defined(VERTEXLIGHT_ON)
        float4x4 vertexLightColor : TEXCOORD9;
        float4x4 vertexLightPos : TEXCOORD13;
    #endif
};

///////////////////////////////////////////////////////////////////////////////



///////////////////////////////////////////////////////////////////////////////
// Surface function. Works a little bit like a surface type shader, setting  //
// all the data from the material properties to be used by fragment.         //
///////////////////////////////////////////////////////////////////////////////

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

    // Just like I did in the Godot version, I took the built-in algorithm in
    // the engine for parallax. Unity's ParallaxOffset function is available
    // on UnityCG.cginc and you can see it if you want, it's a simpler version
    // than Godot's deep parallax algorithm. I tried translating Godot's code
    // but the compiler complained about the while loop, saying it wouldn't 
    // finish in a timely manner, so we're stuck with Unity's built-in one.
    // Catlike Coding has a very good tutorial with a different method as well
    // at https://catlikecoding.com/unity/tutorials/rendering/part-20/.
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

///////////////////////////////////////////////////////////////////////////////



///////////////////////////////////////////////////////////////////////////////
// Light handler functions. They get data from light sources and translate   //
// them for the fragment function to use.                                    //
///////////////////////////////////////////////////////////////////////////////

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

    UNITY_LIGHT_ATTENUATION(attenuation, i, i.worldPos);
    light.attenuation = attenuation;
    light.color = _LightColor0.rgb;
    return light;
}

void Set4VertexLights (inout Interpolators i) {
    #if defined(VERTEXLIGHT_ON)
        float3 lightPos0 = float3(
            unity_4LightPosX0.x, unity_4LightPosY0.x, unity_4LightPosZ0.x);
        lightPos0 -= i.worldPos;
        i.vertexLightColor._m03 = 1 /
            (1 + dot(lightPos0, lightPos0) * unity_4LightAtten0.x);
        i.vertexLightColor._m00_m01_m02 = unity_LightColor[0].rgb;
        i.vertexLightPos._m00_m01_m02 = lightPos0;

        float3 lightPos1 = float3(
            unity_4LightPosX0.y, unity_4LightPosY0.y, unity_4LightPosZ0.y);
        lightPos1 -= i.worldPos;
        i.vertexLightColor._m13 = 1 /
            (1 + dot(lightPos1, lightPos1) * unity_4LightAtten0.y);
        i.vertexLightColor._m10_m11_m12 = unity_LightColor[1].rgb;
        i.vertexLightPos._m10_m11_m12 = lightPos1;

        float3 lightPos2 = float3(
            unity_4LightPosX0.z, unity_4LightPosY0.z, unity_4LightPosZ0.z);
        lightPos2 -= i.worldPos;
        i.vertexLightColor._m23 = 1 /
            (1 + dot(lightPos2, lightPos2) * unity_4LightAtten0.z);
        i.vertexLightColor._m20_m21_m22 = unity_LightColor[2].rgb;
        i.vertexLightPos._m20_m21_m22 = lightPos2;

        float3 lightPos3 = float3(
            unity_4LightPosX0.w, unity_4LightPosY0.w, unity_4LightPosZ0.w);
        lightPos3 -= i.worldPos;
        i.vertexLightColor._m33 = 1 /
            (1 + dot(lightPos3, lightPos3) * unity_4LightAtten0.w);
        i.vertexLightColor._m30_m31_m32 = unity_LightColor[3].rgb;
        i.vertexLightPos._m30_m31_m32 = lightPos3;
    #endif
}

// Diffuse light. Directly from my Godot version at
// https://godotshaders.com/shader/complete-toon-shader/
half3 GetDiffuse (LightData light, Surface s) {
    float3 r = tex2D(_DiffuseGradient, DotClamped(s.normal, light.dir)).xxx;

    #if defined(_TRANSMISSION_ENABLED)
        r = r + (1 - r) * s.transmission;
    #endif

    return s.albedo * light.color * light.attenuation * r;
}

// Specular blob. Also directly from my Godot shader, but a the basis is
// from Roystan's https://roystan.net/articles/toon-shader and the anisotropy
// is from https://wiki.unity3d.com/index.php/Anisotropic_Highlight_Shader by
// James O'Hare. It's basically a toonified Blinn-Phong algorithm.
half3 GetSpecular (LightData light, Surface s, float3 viewDir) {
    float3 h = normalize(viewDir + light.dir);
    half glossiness = pow(2, 8 * (1 - s.specularAmount));
    half spec = dot(s.normal, h);

    #if defined(_ANISOTROPY_ENABLED)
        half anisoDot = dot(normalize(s.normal + s.anisoFlowchart), h);
        half aniso = max(0, sin(radians(anisoDot) * 180));
        spec = lerp(spec, aniso, s.anisoScale);
    #endif

    half r = pow(spec, glossiness * glossiness);
    r = smoothstep(0.05, 0.05 + s.specularSmooth, r);
    return light.color * s.specular * r * light.attenuation;
}

// Fresnel effect. From my Godot shader too, and the original is also from
// Roystan's https://roystan.net/articles/toon-shader tutorial.
half3 GetRim (LightData light, Surface s, float3 viewDir) {
    half viewDotNormal = 1 - DotClamped(viewDir, s.normal);
    half lightDotNormal = DotClamped(light.dir, s.normal);
    half rimThreshold = pow((1 - s.rimAmount), lightDotNormal);
    half rimIntensity = smoothstep(
        rimThreshold - s.rimSmooth / 2,
        rimThreshold + s.rimSmooth / 2,
        viewDotNormal);
    return light.color * s.rim * rimIntensity * light.attenuation;
}

///////////////////////////////////////////////////////////////////////////////



///////////////////////////////////////////////////////////////////////////////
// Vertex function.                                                          //
///////////////////////////////////////////////////////////////////////////////

Interpolators vert (MeshData v) {
    Interpolators o;
    UNITY_INITIALIZE_OUTPUT(Interpolators, o);

    o.pos = UnityObjectToClipPos(v.vertex);
    o.uv = TRANSFORM_TEX(v.uv, _MainTex);
    o.worldPos = mul(unity_ObjectToWorld, v.vertex);
    o.worldViewDir = normalize(_WorldSpaceCameraPos - o.worldPos);
    o.normal = UnityObjectToWorldNormal(v.normal);
    
    UNITY_TRANSFER_SHADOW(o, v.uv1)
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
        Set4VertexLights(o);
    #endif

    #if defined(LIGHTMAP_ON)
        i.lightmapUV = v.uv1 * unity_LightmapST.xy + unity_LightmapST.zw;
    #endif

    return o;
}

///////////////////////////////////////////////////////////////////////////////



///////////////////////////////////////////////////////////////////////////////
// Fragment. This is basically the light function from my Godot version at   //
// https://godotshaders.com/shader/complete-toon-shader/ adapted to Unity,   //
// with the inclusion of ambient light, emission, reflections and etc.       //
///////////////////////////////////////////////////////////////////////////////

half4 frag (Interpolators i) : SV_TARGET {
    Surface s = GetSurface(i);
    LightData light = GetLight(i);

    #if defined(_RENDERING_CUTOUT)
        clip(s.alpha - _Cutoff);
    #endif

    half3 diffuse = GetDiffuse(light, s);
    half3 specular = GetSpecular(light, s, i.worldViewDir);
    half3 rim = GetRim(light, s, i.worldViewDir);
    half4 col;
    col.rgb = diffuse + specular + rim;
    col.a = 1;

    #if defined(_RENDERING_FADE) || defined(_RENDERING_TRANSPARENT)
        col.a = s.alpha;
    #endif

    // Checking to see if this is the base pass in order to add emission and
    // sample the environment data to add to the final color. I made that by
    // following this https://catlikecoding.com/unity/tutorials/rendering/
    // tutorial by Catlike Coding.
    #if defined(UNITY_PASS_FORWARDBASE)
        half3 ambient = 0;

        // This is a somewhat non traditional way of implementing vertex
        // lighting. Instead of calculating the colors on the vertexes, we
        // just interpolate the light data there and calculate the color per
        // fragment in order to toonify them. Heavier than traditional vertex
        // lights, but still lighter than normal per fragment light.
        #if defined(VERTEXLIGHT_ON)
            LightData vertexLight0;
            vertexLight0.color = i.vertexLightColor._m00_m01_m02;
            vertexLight0.dir = normalize(i.vertexLightPos._m00_m01_m02);
            vertexLight0.attenuation = i.vertexLightColor._m03;

            LightData vertexLight1;
            vertexLight1.color = i.vertexLightColor._m10_m11_m12;
            vertexLight1.dir = normalize(i.vertexLightPos._m10_m11_m12);
            vertexLight1.attenuation = i.vertexLightColor._m13;

            LightData vertexLight2;
            vertexLight2.color = i.vertexLightColor._m20_m21_m22;
            vertexLight2.dir = normalize(i.vertexLightPos._m20_m21_m22);
            vertexLight2.attenuation = i.vertexLightColor._m23;

            LightData vertexLight3;
            vertexLight3.color = i.vertexLightColor._m30_m31_m32;
            vertexLight3.dir = normalize(i.vertexLightPos._m30_m31_m32);
            vertexLight3.attenuation = i.vertexLightColor._m33;

            col.rgb += GetDiffuse(vertexLight0, s);
            col.rgb += GetDiffuse(vertexLight1, s);
            col.rgb += GetDiffuse(vertexLight2, s);
            col.rgb += GetDiffuse(vertexLight3, s);

            col.rgb += GetSpecular(vertexLight0, s, i.worldViewDir);
            col.rgb += GetSpecular(vertexLight1, s, i.worldViewDir);
            col.rgb += GetSpecular(vertexLight2, s, i.worldViewDir);
            col.rgb += GetSpecular(vertexLight3, s, i.worldViewDir);

            col.rgb += GetRim(vertexLight0, s, i.worldViewDir);
            col.rgb += GetRim(vertexLight1, s, i.worldViewDir);
            col.rgb += GetRim(vertexLight2, s, i.worldViewDir);
            col.rgb += GetRim(vertexLight3, s, i.worldViewDir);
        #endif

        #if defined(LIGHTMAP_ON)
            ambient = DecodeLightmap(
                UNITY_SAMPLE_TEX2D(unity_Lightmap, i.lightmapUV));
        #else
            ambient = ShadeSH9(float4(s.normal, 1)) * s.albedo;
        #endif

        #if defined(_REFLECTIONS_ENABLED)
            float3 reflexDir = reflect(-i.worldViewDir, s.normal);
            half roughness = 1.7 * s.blurriness +
                0.7 * s.blurriness * s.blurriness;
            half4 envSample = UNITY_SAMPLE_TEXCUBE_LOD(
                unity_SpecCube0, reflexDir,
                roughness * UNITY_SPECCUBE_LOD_STEPS);
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

        // Refraction code directly from Godot's base shader on my Godot code
        // at https://godotshaders.com/shader/complete-toon-shader/. Unity's
        // GrabPass makes it refract more things, but at the cost of GPU.
        #if defined(_REFRACTION_ENABLED)
            float3 viewN = mul(unity_WorldToObject, float4(s.normal, 0));
            viewN = normalize(mul(UNITY_MATRIX_MV, float4(viewN, 0)));
            float4 offset = float4(-s.refraction * viewN.xy, 0, 0);
            col.rgb += (1 - s.alpha) *
                tex2Dproj(_GrabTexture, i.screenUV + offset).rgb;
        #endif

        col.rgb += ambient;
    #endif

    // Apply fog. We're using Unity's built in fog tool. If you want to learn
    // how Unity does it or how fog itself works, check Catlike Coding's
    // https://catlikecoding.com/unity/tutorials/rendering/part-14/ tutorial
    // on fog, it's really in depth and worth a read.
    UNITY_APPLY_FOG(i.fogCoord, col);

    return col;
}

#endif