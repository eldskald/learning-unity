// This shader is from Harry Alisavakis, at
// https://halisavakis.com/my-take-on-shaders-sky-shader/
//
// The only modification is the clouds unwrapping due to an artifact
// caused by the arctangent of zero.

Shader "Skybox/ToonSky" {

    Properties {

        [Header(Sky color)]
        [HDR] _ColorTop ("Color Top", Color) = (1,1,1,1)
        [HDR] _ColorMid ("Color Middle", Color) = (1,1,1,1)
        [HDR] _ColorBot ("Color Bottom", Color) = (1,1,1,1)
        _MidSmooth ("Middle Smoothness", Range(0.0,1.0)) = 1
        _MidOffset ("Middle Offset", Float) = 0
        _TopSmooth ("Top Smoothness", Range(0.0, 1.0)) = 1
        _TopOffset ("Top Offset", Float) = 0

        [Header(Sun)]
        _SunSize ("Sun Size", Range(0.0, 1.0)) = 0.1
        [HDR] _SunColor("Sun Color", Color) = (1,1,1,1)

        [Header(Moon)]
        _MoonSize ("Moon Size", Range(0,1)) = 0
        [HDR] _MoonColor ("Moon Color", Color) = (1,1,1,1)
        _MoonPhase ("Moon Phase", Range(0,1)) = 0
        
        [Header(Stars)]
        _Stars ("Stars", 2D) = "black" {}
        _StarsIntensity ("Stars Intensity", Float) = 0

        [Header(Clouds)]
        [HDR] _CloudsColor ("Clouds Color", Color) = (1,1,1,1)
        _CloudsTex ("Clouds Noise", 2D) = "black" {}
        _CloudsThresh ("Clouds Threshold", Range(0.0, 1.0)) = 0
        _CloudsSmooth ("Clouds Smoothness", Range(0.0, 1.0)) = 0.1
        _SunCloudStr ("Sun Behind Clouds Brightness", Range(0, 1)) = 0
        _PanningSpeedX ("Panning Speed X", Float) = 0
        _PanningSpeedY ("Panning Speed Y", Float) = 0
    }

    SubShader {

        Tags {
            "RenderType" = "Background"
            "Queue" = "Background"
            "PreviewType" = "Quad"
        }

        LOD 100

        Pass {

            CGPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata {
                float4 vertex : POSITION;
                float3 uv : TEXCOORD0; // Skybox requires 3D UVs.
            };

            struct v2f {
                float4 pos : SV_POSITION;
                float3 uv : TEXCOORD0; // Skybox requires 3D UVs.
            };

            fixed4 _ColorBot, _ColorMid, _ColorTop;
            float _MidSmooth, _MidOffset, _TopSmooth, _TopOffset;

            fixed4 _SunColor, _MoonColor;
            float _SunSize, _MoonSize, _MoonPhase;

            sampler2D _Stars;
            float4 _Stars_ST;
            float _StarsIntensity;

            sampler2D _CloudsTex;
            float4 _CloudsTex_ST, _CloudsColor;
            float _CloudsSmooth, _CloudsThresh, _SunCloudStr;
            float _PanningSpeedX, _PanningSpeedY;

            v2f vert (appdata v) {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            fixed4 frag (v2f i) : SV_TARGET {
                fixed4 col;

                // Let's start by painting the sky background color, since
                // everything else is in front, we can just override it.
                half midThreshold = smoothstep(
                    0.0, 0.5 - (1.0 - _MidSmooth) / 2.0, i.uv.y - _MidOffset);
                half topThreshold = smoothstep(
                    0.5, 1.0 - (1.0 - _TopSmooth) / 2.0, i.uv.y - _TopOffset);
                col = lerp(_ColorBot, _ColorMid, midThreshold);
                col = lerp(col, _ColorTop, topThreshold);

                // Deriving UV coordinates of the clouds from skybox UV 3D
                // coordinates and applying its tiling and panning.
                float2 cloudUV = i.uv.xz / i.uv.y;
                // cloudUV.x = atan2(i.uv.x, i.uv.z) / UNITY_TWO_PI;
                // cloudUV.y = asin(i.uv.y) / UNITY_HALF_PI;
                cloudUV = cloudUV * _CloudsTex_ST.xy + _CloudsTex_ST.zw;
                cloudUV += half2(_PanningSpeedX, _PanningSpeedY) * _Time.y;

                // Finding clouds.
                half cloudsThresh = i.uv.y - _CloudsThresh;
                half cloudsTex = tex2D(_CloudsTex, cloudUV).x;
                half clouds = smoothstep(
                    cloudsThresh, cloudsThresh + _CloudsSmooth, cloudsTex);

                // Finding stars.
                half stars = tex2D(_Stars, (i.uv.xz / i.uv.y) * _Stars_ST.xy);
                stars *= _StarsIntensity * saturate(-_WorldSpaceLightPos0.y);
                stars *= smoothstep(0.5, 1.0 , i.uv.y) * (1.0 - clouds);

                // Finding the sun.
                half sunSDF = distance(i.uv.xyz, _WorldSpaceLightPos0);
                half sun = max(
                    clouds * _CloudsColor.a, smoothstep(0, _SunSize, sunSDF));

                // Finding the moon.
                half moonSDF = distance(i.uv.xyz, -_WorldSpaceLightPos0);
                half3 phaseCirc = i.uv.xyz - half3(0.0, 0.0, 0.1) * _MoonPhase;
                half moonPhaseSDF = distance(phaseCirc, -_WorldSpaceLightPos0);
                half moon = step(moonSDF, _MoonSize);
                moon -= step(moonPhaseSDF, _MoonSize);
                moon = saturate(moon * -_WorldSpaceLightPos0.y - clouds);
                
                // Applying shading to the clouds.
                half cThreshSmooth = cloudsThresh + _CloudsSmooth;
                half cloudShading = smoothstep(
                    cloudsThresh, cThreshSmooth + 0.1, cloudsTex);
                cloudShading -= smoothstep(
                    cThreshSmooth + 0.1, cThreshSmooth + 0.4, cloudsTex);
                clouds = lerp(clouds, cloudShading, 0.5);
                clouds *= midThreshold * _CloudsColor.a;

                // Finding the silver lining on the clouds.
                half silverLining = smoothstep(
                    cloudsThresh, cThreshSmooth, cloudsTex);
                silverLining -= smoothstep(
                    cloudsThresh + 0.02, cThreshSmooth + 0.02, cloudsTex);
                silverLining *= smoothstep(_SunSize * 3.0, 0.0, sunSDF);
                silverLining *= _CloudsColor.a;

                // Calculating clouds color based on the presence of the
                // behind them or not.
                half coveredSun = cloudShading * smoothstep(0.3, 0.0, sunSDF);
                coveredSun *= _SunCloudStr;
                fixed4 cloudsCol = lerp(
                    _CloudsColor, _CloudsColor + _SunColor, coveredSun);

                // Finally, painting the bodies detected.
                col = lerp(_SunColor, col, sun);
                col = lerp(col, cloudsCol, clouds);
                col += silverLining * _SunColor;
                col = lerp(col, _MoonColor, moon);
                col += stars;
                return col;
            }

            ENDCG
        }
    }
}
