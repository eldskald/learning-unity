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
half4 _UVEdgeSizes;

// Buffers that we need.
sampler2D _GrabTexture;
sampler2D _CameraDepthTexture;
float4 _CameraDepthTexture_TexelSize;

// Fragment function.
fixed4 ToonWaterFragment (Interpolators i) {
    float3 _viewDir = normalize(UnityWorldSpaceViewDir(i.worldPos));
    Surface s;
    UNITY_INITIALIZE_OUTPUT(Surface, s);
    s.albedo = _Color.rgb;
    s.specularColor = half3(1, 1, 1) * _Specularity * saturate(_Agitation * 2);
    s.specularAmount = 0.5;
    s.transmission = 1.0;

    // Depth calculations is the base of foam, refraction and depth fog.
    float zDepth = LinearEyeDepth(tex2Dproj(
        _CameraDepthTexture, UNITY_PROJ_COORD(i.screenUV)));
    float zPos = i.screenUV.w;
    float zDiff = zDepth - zPos;

    // Let's start by getting depth based foam. We use zDiff to "detect"
    // intersections with other geometry to paint foam around them.
    half foam = 0;

    // First, let's apply noise.
    #if !defined(_FOAM_DISABLED) || defined(_UV_EDGE_FOAM_ENABLED)
        float2 noisePan = _Time.y * (0.2 + _Agitation * 0.6) / 16;
        half foamNoise = tex2D(_FoamNoiseTex, i.uv + noisePan).x;
        foamNoise += tex2D(_FoamNoiseTex, i.uv - noisePan).x;
        half foamDispl = (foamNoise - 1) * _FoamDisplacement;
    #endif

    // This is the actual intersection detection.
    #if !defined(_FOAM_DISABLED)
        half t = zDiff < 0 ? 1 : (zDiff + foamDispl) * 2;
        foam = 1 - smoothstep(_FoamSize, _FoamSize + _FoamSmooth, t);
    #endif

    // Here, we calculate UV edge foam, if enabled. Instead of using depth
    // to decide where to paint foam, we use UV coordinates and paint it
    // on the edges.
    #if defined(_UV_EDGE_FOAM_ENABLED)
        float2 ogUV = i.uv / _MainTex_ST.xy - _MainTex_ST.zw;
        float left = 1 - smoothstep(0, _UVEdgeSizes.x, ogUV.x);
        left = left + foamDispl;
        left = smoothstep(_FoamSize, _FoamSize + _FoamSmooth, left);
        float right = smoothstep(1 - _UVEdgeSizes.y, 1, ogUV.x);
        right = right + foamDispl;
        right = smoothstep(_FoamSize, _FoamSize + _FoamSmooth, right);
        float top = smoothstep(1 - _UVEdgeSizes.z, 1, ogUV.y);
        top = top + foamDispl;
        top = smoothstep(_FoamSize, _FoamSize + _FoamSmooth, top);
        float bottom = 1 - smoothstep(0, _UVEdgeSizes.w, ogUV.y);
        bottom = bottom + foamDispl;
        bottom = smoothstep(_FoamSize, _FoamSize + _FoamSmooth, bottom);
        foam = max(foam, max(left, max(right, max(top, bottom))));
    #endif

    // Turns off foam on very low agitations on normal foam mode.
    #if defined(_FOAM_NORMAL)
        foam *= saturate(_Agitation * 10 - 0.05);
    #endif

    // Now, we deal with the normal map. We'll pan it twice along two
    // velocities and blend the result in order to agitate the water.
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
    
    // With the normal map, we can calculate reflectivity if using Fresnel.
    // If not, let's calculate it here anyway.
    #if defined(_FRESNEL_EFFECT_ENABLED)
        s.reflectivity = _Reflectivity;
        float cosine = dot(s.normal, _viewDir);
        s.reflectivity += (1 - _Reflectivity) * pow(1 - cosine, 5);
    #else
        s.reflectivity = _Reflectivity * saturate(1 - _Agitation * 1.5);
    #endif

    // In case we're using planar reflections with no background, we need
    // to set reflectivity to zero where the texture's alpha is zero or else
    // it will paint the reflections black. To do this, we end up doing the
    // whole sampling of the probe here.
    #if defined(_PLANAR_REFLECTIONS_ENABLED)
        float2 reflOffset = tanSpaceNormal.xy;
        reflOffset.y *= _CameraDepthTexture_TexelSize.z *
            abs(_CameraDepthTexture_TexelSize.y);
        reflOffset *= 0.2;
        float4 reflUV = i.screenUV + float4(reflOffset, 0, 0);
        half4 reflections = SamplePlanarReflections(reflUV);
        s.reflectivity *= reflections.a;
    #endif

    // Here, we deal with refraction and depth fog. We do a method to offset
    // the screen UVs similar to what we did with planar reflections but we
    // also sample the depth buffer on the offset as well. We need it to
    // correct an artifact where geometry above the water is refracted as well
    // as calculating transparency and depth fog.
    float2 refrOffset = tanSpaceNormal.xy;
    refrOffset.y *=
        _CameraDepthTexture_TexelSize.z * abs(_CameraDepthTexture_TexelSize.y);
    refrOffset *= 0.1 * saturate(zDiff);
    float4 refrUV = i.screenUV + float4(refrOffset, 0, 0);
    half zDepthOffs = LinearEyeDepth(tex2Dproj(
        _CameraDepthTexture, UNITY_PROJ_COORD(refrUV)));
    half zDiffOffs = zDepthOffs - zPos;
    refrUV = zDiffOffs > 0 ? refrUV : i.screenUV;
    s.alpha = _Color.a;

    #if defined(_DEPTH_FOG_ENABLED)
        s.alpha = saturate(zDiffOffs * tan(s.alpha * PI / 2));
    #endif

    // If on specular foam mode, instead of painting foam we turn it into
    // specular reflections. We do it by setting specular amount to 1 where
    // there is foam.
    #if defined(_FOAM_SPECULAR)
        s.specularAmount += 0.5 * foam;
    #endif

    // Diffuse and specular reflections. We separate it into foam colors and
    // non foam colors in order to return a lerp between them.
    UnityLight light = GetLight(i);
    half3 baseCol = 0;
    half3 foamCol = 0;
    baseCol += GetDiffuse(light, s) * (1 - s.reflectivity) * s.alpha;
    baseCol += GetSpecular(light, s, _viewDir);
    foamCol += light.color * _FoamColor.rgb;

    #if defined(UNITY_PASS_FORWARDBASE)

        // Vertex lights implementation.
        #if defined(VERTEXLIGHT_ON)
            UnityLight vLight0 = GetVertexLight0(i);
            baseCol += GetDiffuse(vLight0, s) * (1 - s.reflectivity) * s.alpha;
            baseCol += GetSpecular(vLight0, s, _viewDir);
            foamCol += vLight0.color * _FoamColor.rgb;

            UnityLight vLight1 = GetVertexLight1(i);
            baseCol += GetDiffuse(vLight1, s) * (1 - s.reflectivity) * s.alpha;
            baseCol += GetSpecular(vLight1, s, _viewDir);
            foamCol += vLight1.color * _FoamColor.rgb;

            UnityLight vLight2 = GetVertexLight2(i);
            baseCol += GetDiffuse(vLight2, s) * (1 - s.reflectivity) * s.alpha;
            baseCol += GetSpecular(vLight2, s, _viewDir);
            foamCol += vLight2.color * _FoamColor.rgb;

            UnityLight vLight3 = GetVertexLight3(i);
            baseCol += GetDiffuse(vLight3, s) * (1 - s.reflectivity) * s.alpha;
            baseCol += GetSpecular(vLight3, s, _viewDir);
            foamCol += vLight3.color * _FoamColor.rgb;
        #endif

        // Here we calculate the reflections.
        #if defined(_PLANAR_REFLECTIONS_ENABLED)
            baseCol += s.reflectivity * reflections.rgb;
        #else
            float3 reflexDir = reflect(-_viewDir, s.normal);
            half4 envSample = UNITY_SAMPLE_TEXCUBE(unity_SpecCube0, reflexDir);
            half3 reflections = DecodeHDR(envSample, unity_SpecCube0_HDR);
            baseCol += s.reflectivity * reflections;
        #endif

        // Now we calculate the refractions.
        half3 refractions = tex2Dproj(
            _GrabTexture, UNITY_PROJ_COORD(refrUV)).rgb;
        baseCol += (1 - s.reflectivity) * (1 - s.alpha) * refractions;
        
        // Ambient light.
        half3 ambient = ShadeSH9(float4(s.normal, 1));
        baseCol += ambient * s.albedo * (1 - s.reflectivity) * s.alpha;
        foamCol += ambient * _FoamColor.rgb;
    #endif

    // Now we lerp between baseCol and foamCol for the final color.
    #if defined(_FOAM_SPECULAR)
        return half4(baseCol, 1);
    #else
        return half4(lerp(baseCol, foamCol, foam), 1);
    #endif
}

// // Fragment function.
// float4 ToonWaterFragment (Interpolators i) {
//     float4 col = float4(0, 0, 0, 1);

//     float3 _viewDir = normalize(UnityWorldSpaceViewDir(i.worldPos));
//     Surface s;
//     UNITY_INITIALIZE_OUTPUT(Surface, s);
//     s.albedo = _Color.rgb;
//     s.specularColor = half3(1, 1, 1) * _Specularity * saturate(_Agitation * 2);
//     s.specularAmount = 0.5;
//     s.transmission = 1.0;

//     // In this bit, we take the depth of the background, the depth of the
//     // water surface and take the difference to calculate how deep is the
//     // background, so we can color the water accordingly, the deeper it is,
//     // the less transparent it should be. We also use it to detect where the
//     // foam should be, if the difference is too small, we must be near an
//     // intersecting geometry and thus there should be foam.
//     float zDepth = LinearEyeDepth(tex2Dproj(
//         _CameraDepthTexture, UNITY_PROJ_COORD(i.screenUV)));
//     float zPos = i.screenUV.w;
//     float zDiff = zDepth - zPos;

//     // Here, we calculate foam based on depth. We store it on the foam
//     // variable. It is equal to 1 if it has foam on the current pixel, 0 if
//     // it has not and anything in between for smoothing the transition.
//     // This is detecting edges calculations, we add foam colors at the end.
//     half foam = 0;

//     #if !defined(_FOAM_DISABLED) || defined(_UV_EDGE_FOAM_ENABLED)
//         float2 noisePan = _Time.y * (0.2 + _Agitation * 0.6) / 16;
//         half foamNoise = tex2D(_FoamNoiseTex, i.uv + noisePan).x;
//         foamNoise += tex2D(_FoamNoiseTex, i.uv - noisePan).x;
//         foamNoise /= 2; // foamNoise is the average between two samples.
//         half foamDispl = (foamNoise * 2 - 1) * _FoamDisplacement;
//     #endif
    
//     #if !defined(_FOAM_DISABLED)
//         half t = zDiff < 0 ? 1 : (zDiff + foamDispl) * 2;
//         foam = 1 - smoothstep(_FoamSize, _FoamSize + _FoamSmooth, t);
//     #endif

//     // This is edge foam. Instead of using depth, we use UV coordinates
//     // to detect how close to the edges of the UV coordinates we are.
//     // Good for running water, waterfalls or anything else you feel like.
//     #if defined(_UV_EDGE_FOAM_ENABLED)
//         float2 ogUV = i.uv / _MainTex_ST.xy - _MainTex_ST.zw;
//         float left = 1 - smoothstep(0, _UVEdgeSizes.x, ogUV.x);
//         left = left + foamDispl;
//         left = smoothstep(_FoamSize, _FoamSize + _FoamSmooth, left);
//         float right = smoothstep(1 - _UVEdgeSizes.y, 1, ogUV.x);
//         right = right + foamDispl;
//         right = smoothstep(_FoamSize, _FoamSize + _FoamSmooth, right);
//         float top = smoothstep(1 - _UVEdgeSizes.z, 1, ogUV.y);
//         top = top + foamDispl;
//         top = smoothstep(_FoamSize, _FoamSize + _FoamSmooth, top);
//         float bottom = 1 - smoothstep(0, _UVEdgeSizes.w, ogUV.y);
//         bottom = bottom + foamDispl;
//         bottom = smoothstep(_FoamSize, _FoamSize + _FoamSmooth, bottom);
//         foam = max(foam, max(left, max(right, max(top, bottom))));
//     #endif

//     #if defined(_FOAM_NORMAL)
//         foam *= saturate(_Agitation * 10 - 0.05);
//     #endif

//     // Now, we deal with the normal map. We'll pan it twice along two
//     // velocities and blend the result in order to agitate the water.
//     float2 uvA = i.uv + _NormalPanVel.xy * _Time.y * _Agitation;
//     float2 uvB = i.uv + _NormalPanVel.zw * _Time.y * _Agitation;
//     half scale = saturate(_Agitation * 1.5);
//     float3 normalA = UnpackNormal(tex2D(_NormalMap, uvA));
//     float3 normalB = UnpackNormal(tex2D(_NormalMap, uvB));
//     float3 nMean = (normalA + normalB) / 2;
//     float3 tanSpaceNormal = normalize(lerp(float3(0, 0, 1), nMean, scale));
//     s.normal = normalize(
//         tanSpaceNormal.x * i.tangent +
//         tanSpaceNormal.y * i.binormal +
//         tanSpaceNormal.z * i.normal);

//     // With the normal map, we can calculate reflectivity if using Fresnel.
//     // If not, let's calculate it here anyway.
//     #if defined(_FRESNEL_EFFECT_ENABLED)
//         s.reflectivity = _Reflectivity;
//         float cosine = dot(s.normal, _viewDir);
//         s.reflectivity += (1 - _Reflectivity) * pow(1 - cosine, 5);
//     #else
//         s.reflectivity = _Reflectivity * saturate(1 - _Agitation * 1.5);
//     #endif

//     #if !defined(_FOAM_SPECULAR)
//         s.reflectivity *= (1 - foam);
//     #endif

//     // In case we're using planar reflections with no background, we need
//     // to set reflectivity to zero where the alpha value is zero or else it
//     // will paint the reflections black. To do this, we end up doing the
//     // whole sampling of the probe here.
//     #if defined(_PLANAR_REFLECTIONS_ENABLED)
//         float2 reflOffset = tanSpaceNormal.xy;
//         reflOffset.y *= _CameraDepthTexture_TexelSize.z *
//             abs(_CameraDepthTexture_TexelSize.y);
//         reflOffset *= 0.2;
//         float4 reflUV = i.screenUV + float4(reflOffset, 0, 0);
//         half4 reflections = SamplePlanarReflections(reflUV);
//         s.reflectivity *= reflections.a;
//     #endif

//     // We have to calculate depth here in order to determine how to calculate
//     // diffuse light with alpha. We will also reuse these numbers later on the
//     // refractions code.
//     float2 refrOffset = tanSpaceNormal.xy;
//     refrOffset.y *=
//         _CameraDepthTexture_TexelSize.z * abs(_CameraDepthTexture_TexelSize.y);
//     refrOffset *= 0.1 * saturate(zDiff);
//     float4 refrUV = i.screenUV + float4(refrOffset, 0, 0);
//     half zDepthOffs = LinearEyeDepth(tex2Dproj(
//         _CameraDepthTexture, UNITY_PROJ_COORD(refrUV)));
//     half zDiffOffs = zDepthOffs - zPos;
//     refrUV = zDiffOffs > 0 ? refrUV : i.screenUV;
//     s.alpha = _Color.a;

//     #if defined(_DEPTH_FOG_ENABLED)
//         s.alpha = saturate(zDiffOffs * tan(s.alpha * PI / 2));
//     #endif

//     UnityLight light = GetLight(i);
//     col.rgb += GetDiffuse(light, s) * (1 - s.reflectivity) * s.alpha;
//     half3 specular = GetSpecular(light, s, _viewDir);

//     #if defined(UNITY_PASS_FORWARDBASE)
    
//         // Vertex lights implementation.
//         #if defined(VERTEXLIGHT_ON)
//             UnityLight vLight0 = GetVertexLight0(i);
//             col.rgb += GetDiffuse(vLight0, s) * (1 - s.reflectivity) * s.alpha;
//             specular += GetSpecular(vLight0, s, _viewDir);

//             UnityLight vLight1 = GetVertexLight1(i);
//             col.rgb += GetDiffuse(vLight1, s) * (1 - s.reflectivity) * s.alpha;
//             specular += GetSpecular(vLight1, s, _viewDir);

//             UnityLight vLight2 = GetVertexLight2(i);
//             col.rgb += GetDiffuse(vLight2, s) * (1 - s.reflectivity) * s.alpha;
//             specular += GetSpecular(vLight2, s, _viewDir);

//             UnityLight vLight3 = GetVertexLight3(i);
//             col.rgb += GetDiffuse(vLight3, s) * (1 - s.reflectivity) * s.alpha;
//             specular += GetSpecular(vLight3, s, _viewDir);
            
//             #if defined(_FOAM_SPECULAR)
//                 specColor += vLight0.color * s.specularColor;
//                 specColor += vLight1.color * s.specularColor;
//                 specColor += vLight2.color * s.specularColor;
//                 specColor += vLight3.color * s.specularColor;
//             #endif
//         #endif
//     #endif

//     // For last, we add ambient light, refractions and reflections.
//     #if defined(UNITY_PASS_FORWARDBASE)

//         // Here we calculate the reflections. Remember that planar reflections
//         // were mostly taken care of already.
//         #if defined(_PLANAR_REFLECTIONS_ENABLED)
//             col.rgb += s.reflectivity * reflections.rgb;
//         #else
//             float3 reflexDir = reflect(-_viewDir, s.normal);
//             half4 envSample = UNITY_SAMPLE_TEXCUBE(unity_SpecCube0, reflexDir);
//             half3 reflections = DecodeHDR(envSample, unity_SpecCube0_HDR);
//             col.rgb += s.reflectivity * reflections;
//         #endif

//         // Now we calculate the refractions.
//         half3 refractions = tex2Dproj(
//             _GrabTexture, UNITY_PROJ_COORD(refrUV)).rgb;
//         col.rgb += (1 - s.reflectivity) * (1 - s.alpha) * refractions;
        
//         // Ambient light.
//         half3 ambient = ShadeSH9(float4(s.normal, 1)) * s.albedo;
//         col.rgb += (1 - s.reflectivity) * s.alpha * ambient;
//     #endif

//     // Now we can finally add foam colors.
//     #if defined(_FOAM_SPECULAR)
//         col.rgb += specColor * foam;
//     #else
//         col.rgb = lerp(col.rgb, _FoamColor.rgb, foam);
//     #endif
//     col.rgb += specular * (1 - foam);

//     return col;
// }

#endif