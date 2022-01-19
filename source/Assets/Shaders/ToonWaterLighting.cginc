#if !defined(TOON_WATER_LIGHTING_INCLUDED)
#define TOON_WATER_LIGHTING_INCLUDED

#include "CelShadedLighting.cginc"
#include "PlanarReflections.cginc"

#define PI 3.14159265358979323846

// _Color, _MainTex and _Reflectivity already defined in the
// included file.
half _Agitation;
half _Specularity;
fixed4 _FoamColor;
half _FoamSmooth;
half _FoamSize;
half _FoamDisplacement;
sampler2D _FoamNoiseTex;
sampler2D _NormalMap;
half4 _NormalPanVel;

// Buffers that we need.
sampler2D _UnderwaterTexture;
sampler2D _CameraDepthTexture;
float4 _CameraDepthTexture_TexelSize;

// Fragment function.
float4 ToonWaterFragment (Interpolators i) {
    float4 col = float4(0, 0, 0, 1);

    float3 viewDir = normalize(UnityWorldSpaceViewDir(i.worldPos));
    Surface s;
    UNITY_INITIALIZE_OUTPUT(Surface, s);
    s.albedo = _Color.rgb;
    s.specularColor = half3(1, 1, 1) * _Specularity * saturate(_Agitation * 2);
    s.specularAmount = 0.5;
    s.transmission = 1.0;

    // In this bit, we take the depth of the background, the depth of the
    // water surface and take the difference to calculate how deep is the
    // background, so we can color the water accordingly, the deeper it is,
    // the less transparent it should be. We also use it to detect where the
    // foam should be, if the difference is too small, we must be near an
    // intersecting geometry and thus there should be foam.
    float zDepth = LinearEyeDepth(tex2Dproj(
        _CameraDepthTexture, UNITY_PROJ_COORD(i.screenUV)));
    float zPos = i.screenUV.w;
    float zDiff = zDepth - zPos;

    // Here, we calculate foam based on depth. We store it on the foam
    // variable. It is equal to 1 if it has foam on the current pixel, 0 if
    // it has not and anything in between for smoothing the transition.
    // This is detecting edges calculations, we add foam colors at the end.
    half foam = 0;
    #if !defined(_FOAM_DISABLED)
        float2 noisePan = _Time.y * (0.2 + _Agitation * 0.6) / 16;
        half foamNoise = tex2D(_FoamNoiseTex, i.uv + noisePan).x;
        foamNoise += tex2D(_FoamNoiseTex, i.uv - noisePan).x;
        foamNoise /= 2;
        half foamDispl = (foamNoise * 2 - 1) * _FoamDisplacement;
        half t = zDiff < 0 ? 1 : (zDiff + foamDispl) * 8;
        foam = 1 - smoothstep(_FoamSize, _FoamSize + _FoamSmooth, t / 5);

        #if defined(_FOAM_NORMAL)
            foam *= saturate(_Agitation * 10 - 0.05);
        #endif
    #endif

    // Now, we deal with the normal map. We'll pan it twice along two
    // velocities and blend the result in order to agitate the water. We also
    // use the normals to calculate refractions.
    float2 uvA = i.uv + _NormalPanVel.xy * _Time.y * _Agitation;
    float2 uvB = i.uv + _NormalPanVel.zw * _Time.y * _Agitation;
    half scale = saturate(_Agitation * 1.5);
    float3 normalA = UnpackNormal(tex2D(_NormalMap, uvA));
    float3 normalB = UnpackNormal(tex2D(_NormalMap, uvB));
    float3 nMean = (normalA + normalB) / 2;
    float3 tanSpaceNormal = normalize(lerp(float3(0, 0, 1), nMean, scale));
    s.normal = normalize(
        tanSpaceNormal.x * i.tangent +
        tanSpaceNormal.y * i.binormal +
        tanSpaceNormal.z * i.normal);

    // With the normal map, we can calculate specular and reflectivity.
    // We'll also calculate the water color, since we're dealing with light.
    #if defined(_FRESNEL_EFFECT_ENABLED)
        s.reflectivity = _Reflectivity;
        float cosine = dot(s.normal, viewDir);
        s.reflectivity += (1 - _Reflectivity) * pow(1 - cosine, 5);
    #else
        s.reflectivity = _Reflectivity * saturate(1 - _Agitation * 1.5);
    #endif

    // We have to calculate depth here in order to determine how to calculate
    // diffuse light with alpha. We will also reuse these numbers later on the
    // refractions code.
    float2 refrOffset = tanSpaceNormal.xy;
    refrOffset.y *=
        _CameraDepthTexture_TexelSize.z * abs(_CameraDepthTexture_TexelSize.y);
    refrOffset *= 0.1 * saturate(zDiff);
    float4 refrUV = i.screenUV + float4(refrOffset.xy, 0, 0);
    half zDepthOffs = LinearEyeDepth(tex2Dproj(
        _CameraDepthTexture, UNITY_PROJ_COORD(refrUV)));
    half zDiffOffs = zDepthOffs - zPos;
    refrUV = zDiffOffs > 0 ? refrUV : i.screenUV;
    s.alpha = _Color.a;

    #if defined(_DEPTH_FOG_ENABLED)
        s.alpha = saturate(zDiffOffs * tan(s.alpha * PI / 2));
    #endif

    #if !defined(_FOAM_SPECULAR)
        s.alpha = lerp(s.alpha, _FoamColor.a, foam);
        s.reflectivity *= (1 - foam);
    #endif

    UnityLight light = GetLight(i);
    col.rgb += GetDiffuse(light, s) * (1 - s.reflectivity) * s.alpha;
    half3 specular = GetSpecular(light, s, viewDir);

    // In case we're on specular foam mode, we need to calculate the specular
    // color to paint foam later.
    #if defined(_FOAM_SPECULAR)
        half3 specColor = light.color * s.specularColor;
    #endif

    #if defined(UNITY_PASS_FORWARDBASE)
    
        // Vertex lights implementation.
        #if defined(VERTEXLIGHT_ON)
            UnityLight vLight0 = GetVertexLight0(i);
            col.rgb += GetDiffuse(vLight0, s) * (1 - s.reflectivity) * s.alpha;
            specular += GetSpecular(vLight0, s, viewDir);

            UnityLight vLight1 = GetVertexLight1(i);
            col.rgb += GetDiffuse(vLight1, s) * (1 - s.reflectivity) * s.alpha;
            specular += GetSpecular(vLight1, s, viewDir);

            UnityLight vLight2 = GetVertexLight2(i);
            col.rgb += GetDiffuse(vLight2, s) * (1 - s.reflectivity) * s.alpha;
            specular += GetSpecular(vLight2, s, viewDir);

            UnityLight vLight3 = GetVertexLight3(i);
            col.rgb += GetDiffuse(vLight3, s) * (1 - s.reflectivity) * s.alpha;
            specular += GetSpecular(vLight3, s, viewDir);
            
            #if defined(_FOAM_SPECULAR)
                specColor += vLight0.color * s.specularColor;
                specColor += vLight1.color * s.specularColor;
                specColor += vLight2.color * s.specularColor;
                specColor += vLight3.color * s.specularColor;
            #endif
        #endif
    #endif

    // Now we can finally add foam colors. We have to separate them from
    // specular reflections if we want the foam to truly have no specular in
    // it. We also need specular light color to properly do specular foam mode.
    #if defined(_FOAM_SPECULAR)
        col.rgb += specColor * foam / 2; // No idea why but I have to halve it
    #else
        col.rgb = lerp(col.rgb, _FoamColor.rgb * s.alpha, foam);
    #endif
    col.rgb += specular * (1 - foam);

    // For last, we add ambient light, refractions and reflections.
    #if defined(UNITY_PASS_FORWARDBASE)

        // Here we calculate the reflections.
        #if defined(_PLANAR_REFLECTIONS_ENABLED)
            float3 viewNormalDiff = mul(
                UNITY_MATRIX_V, float4(s.normal - i.normal, 1));
            float2 reflOffset = viewNormalDiff * float2(0.05, 0.5);
            reflOffset.y *= _CameraDepthTexture_TexelSize.z *
                abs(_CameraDepthTexture_TexelSize.y);
            float4 reflUV = i.screenUV;
            half3 reflections = SamplePlanarReflections(reflUV).rgb;
            col.rgb += s.reflectivity * reflections;
        #else
            float3 reflexDir = reflect(-viewDir, s.normal);
            half4 envSample = UNITY_SAMPLE_TEXCUBE(unity_SpecCube0, reflexDir);
            half3 reflections = DecodeHDR(envSample, unity_SpecCube0_HDR);
            col.rgb += s.reflectivity * reflections;
        #endif

        // Now we calculate the refractions.
        half3 refractions = tex2Dproj(
            _UnderwaterTexture, UNITY_PROJ_COORD(refrUV)).rgb;
        col.rgb += (1 - s.reflectivity) * (1 - s.alpha) * refractions;
        
        // Ambient light.
        half3 ambient = ShadeSH9(float4(s.normal, 1)) * s.albedo;
        col.rgb += (1 - s.reflectivity) * s.alpha * ambient;
    #endif

    return col;
}

#endif