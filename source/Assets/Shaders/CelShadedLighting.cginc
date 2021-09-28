#if !defined(CEL_SHADED_LIGHTING_INCLUDED)
#define CEL_SHADED_LIGHTING_INCLUDED

#pragma vertex vert
#pragma fragment frag

#include "CelShaderStructs.cginc"
#include "CelShaderLightHandler.cginc"

half _Cutoff;
fixed4 _Color;
sampler2D _MainTex;
float4 _MainTex_ST;
sampler2D _DiffuseGradient;
fixed4 _SpecularColor;
half _SpecularAmount;
sampler2D _SpecularTex;
fixed4 _FresnelColor;
half _FresnelAmount;
sampler2D _FresnelTex;
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
half _Transmission;
sampler2D _TransmissionMap;
sampler2D _RefractionMap;
half _RefractionScale;
sampler2D _GrabTexture;



///////////////////////////////////////////////////////////////////////////////
// Vertex function. We don't change geometry, so we just calculate the       //
// usual interpolation stuff.                                                //
///////////////////////////////////////////////////////////////////////////////

Interpolators vert (VertexData v) {
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
        o.lightmapUV = v.uv1 * unity_LightmapST.xy + unity_LightmapST.zw;
    #endif

    return o;
}

///////////////////////////////////////////////////////////////////////////////



///////////////////////////////////////////////////////////////////////////////
// Surface function. Works a little bit like a surface type shader, setting  //
// all the data from the material properties to be used by fragment.         //
///////////////////////////////////////////////////////////////////////////////

Surface GetSurface(Interpolators i) {
    Surface s;
    UNITY_INITIALIZE_OUTPUT(Surface, s);

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

    s.specularColor = _SpecularColor * tex2D(_SpecularTex, uv).rgb;
    s.specularAmount = _SpecularAmount * tex2D(_SpecularTex, uv).a;
    s.fresnelColor = _FresnelColor * tex2D(_FresnelTex, uv).rgb;
    s.fresnelAmount = _FresnelAmount * tex2D(_FresnelTex, uv).a;

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
        s.transmission = _Transmission * tex2D(_TransmissionMap, uv).r;
    #endif

    #if defined(_REFRACTION_ENABLED)
        s.refraction = _RefractionScale * tex2D(_RefractionMap, uv) / 10;
    #endif

    return s;
}

///////////////////////////////////////////////////////////////////////////////



///////////////////////////////////////////////////////////////////////////////
// Fragment. This is basically the light function from my Godot version at   //
// https://godotshaders.com/shader/complete-toon-shader/ adapted to Unity,   //
// with the inclusion of ambient light, emission, reflections and etc.       //
///////////////////////////////////////////////////////////////////////////////

FragOutput frag (Interpolators i) {
    FragOutput o;
    UNITY_INITIALIZE_OUTPUT(FragOutput, o);

    Surface s = GetSurface(i);
    UnityLight light = GetLight(i);

    #if defined(_RENDERING_CUTOUT)
        clip(s.alpha - _Cutoff);
    #endif

    half3 diffuse = GetDiffuse(light, s);
    half3 specular = GetSpecular(light, s, i.worldViewDir);
    half3 fresnel = GetFresnel(light, s, i.worldViewDir);
    half4 col;
    col.rgb = diffuse + specular + fresnel;
    col.a = s.alpha;

    // Checking to see if this is the base pass in order to add emission and
    // sample the environment data to add to the final color. I made that by
    // following this https://catlikecoding.com/unity/tutorials/rendering/
    // tutorial by Catlike Coding.
    #if defined(UNITY_PASS_FORWARDBASE) || defined(DEFERRED_PASS)
        half3 additional = 0;
        half3 ambient = 0;

        // This is a somewhat non traditional way of implementing vertex
        // lighting. Instead of calculating the colors on the vertexes, we
        // just interpolate the light data there and calculate the color per
        // fragment in order to toonify them. Heavier than traditional vertex
        // lights, but still lighter than normal per fragment light.
        #if defined(VERTEXLIGHT_ON)
            UnityLight vertexLight0;
            vertexLight0.color = i.vertexLightColor._m00_m01_m02;
            vertexLight0.dir = normalize(i.vertexLightPos._m00_m01_m02);
            vertexLight0.attenuation = i.vertexLightColor._m03;

            UnityLight vertexLight1;
            vertexLight1.color = i.vertexLightColor._m10_m11_m12;
            vertexLight1.dir = normalize(i.vertexLightPos._m10_m11_m12);
            vertexLight1.attenuation = i.vertexLightColor._m13;

            UnityLight vertexLight2;
            vertexLight2.color = i.vertexLightColor._m20_m21_m22;
            vertexLight2.dir = normalize(i.vertexLightPos._m20_m21_m22);
            vertexLight2.attenuation = i.vertexLightColor._m23;

            UnityLight vertexLight3;
            vertexLight3.color = i.vertexLightColor._m30_m31_m32;
            vertexLight3.dir = normalize(i.vertexLightPos._m30_m31_m32);
            vertexLight3.attenuation = i.vertexLightColor._m33;

            additional += GetDiffuse(vertexLight0, s);
            additional += GetDiffuse(vertexLight1, s);
            additional += GetDiffuse(vertexLight2, s);
            additional += GetDiffuse(vertexLight3, s);

            additional += GetSpecular(vertexLight0, s, i.worldViewDir);
            additional += GetSpecular(vertexLight1, s, i.worldViewDir);
            additional += GetSpecular(vertexLight2, s, i.worldViewDir);
            additional += GetSpecular(vertexLight3, s, i.worldViewDir);

            additional += GetRim(vertexLight0, s, i.worldViewDir);
            additional += GetRim(vertexLight1, s, i.worldViewDir);
            additional += GetRim(vertexLight2, s, i.worldViewDir);
            additional += GetRim(vertexLight3, s, i.worldViewDir);
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
            additional += reflex * s.reflectivity;
        #endif

        #if defined(_EMISSION_ENABLED)
            additional += + s.emission;
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
            additional += (1 - s.alpha) *
                tex2Dproj(_GrabTexture, i.screenUV + offset).rgb;
        #endif

        additional += ambient;
        col.rgb += additional;
    #endif

    // Apply fog. We're using Unity's built in fog tool. If you want to learn
    // how Unity does it or how fog itself works, check Catlike Coding's
    // https://catlikecoding.com/unity/tutorials/rendering/part-14/ tutorial
    // on fog, it's really in depth and worth a read.
    UNITY_APPLY_FOG(i.fogCoord, col);

    // Filling the G-Buffers for deferred mode. We can't pass both specular
    // and fresnel colors at the same time, and we also need to pass amounts
    // too, so instead we only pass the red channels of both colors and assume
    // they're grayscale. We pass the amounts on the remaining channels of the
    // second buffer, normally used to pass the specular color.
    #if defined(DEFERRED_PASS)
        o.gBuffer0 = float4(s.albedo, 1);
        o.gBuffer1 = float4(
            s.specularColor.r, s.specularAmount,
            s.fresnelColor.r, s.fresnelAmount);
        o.gBuffer2 = float4(s.normal, 1);
        o.gBuffer3 = float4(additional, 1);

        #if defined(_TRANSMISSION_ENABLED)
            o.gBuffer0.a = s.transmission.r;
        #endif
    #else
        o.color = col;
    #endif

    return o;
}

///////////////////////////////////////////////////////////////////////////////

#endif