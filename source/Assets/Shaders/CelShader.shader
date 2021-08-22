Shader "Custom/CelShader"
{
    Properties {
        _Color ("Color", Color) = (1,1,1,1)
        _MainTex ("Albedo (RGB)", 2D) = "white" {}
        [Normal] _NormalMap ("Normal Map", 2D) = "bump" {}
        _ShadowSmooth ("Shadow Smoothness", Range(0.0, 1.0)) = 0.02

        // Specular highlight properties. Set specular to zero to turn off the effect.
        // The texture map uses the red channel for the specular value, green for amount
        // and blue for smoothness.
        [Header(Specular Highlight)]
        _Specular ("Specular", Range(0.0, 1.0)) = 0.5
        _SpecularAmount ("Specular Amount", Range(0.0, 1.0)) = 0.5
        _SpecularSmooth ("Specular Smoothness", Range(0.0, 1.0)) = 0.05
        _SpecularMap ("Specular Map", 2D) = "white" {}
        
        // Rim highlight properties. Set rim to zero to turn off the effect. The
        // texture map uses the red channel for the rim value, green for rim amount
        // and blue for smoothness.
        [Header(Rim Highlight)]
        _Rim ("Rim", Range(0.0, 1.0)) = 0.5
        _RimAmount ("Rim Amount", Range(0.0, 1.0)) = 0.2
        _RimSmooth ("Rim Smoothness", Range(0.0, 1.0)) = 0.05
        _RimMap ("Rim Map", 2D) = "white" {}

        // Outline properties. Set thickness to zero to turn it off.
        [Header(Outline)]
        _OutlineThickness ("Outline Thickness", Float) = 2.0
        _OutlineColor ("Outline Color", Color) = (0,0,0,1)

        // Emission properties. These are not affected by light.
        [Header(Emission)]
        [HDR] _Emission ("Emission", Color) = (0,0,0,1)
        _EmissionMap ("Emission Map", 2D) = "white" {}
    }

    SubShader {
        Tags { "RenderType" = "Opaque" }
        LOD 200

        CGPROGRAM
        #pragma surface surf CelShading fullforwardshadows
        #pragma target 3.0

        fixed4 _Color;
        sampler2D _MainTex;
        sampler2D _NormalMap;
        half _ShadowSmooth;

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

        struct Input {
            float2 uv_MainTex;
            float2 uv_NormalMap;
            float2 uv_SpecularMap;
            float2 uv_RimMap;
            float2 uv_EmissionMap;
        };

        struct CelShaderSurfaceOutput {
            fixed3 Albedo;
            fixed Alpha;
            fixed3 Normal;
            half ShadowSmooth;
            half Specular;
            half SpecularAmount;
            half SpecularSmooth;
            half Rim;
            half RimAmount;
            half RimSmooth;
            half3 Emission;
        };
        
        // Custom lighting model for cel shading. Adapted from my Godot code on
        // https://godotshaders.com/shader/complete-toon-shader/
        half4 LightingCelShading (CelShaderSurfaceOutput s, half3 lightDir, half3 viewDir, half attenuation) {
            half litness = smoothstep(0.0, s.ShadowSmooth, saturate(dot(s.Normal, lightDir))) * attenuation;
            half3 diffuse = s.Albedo * litness * _LightColor0;

            // Toonified Blinn-Phon's specular code, with specular amount for glossiness and a
            // smoothstep function to toonify.
            half3 halfVector = normalize(viewDir + lightDir);
            half specIntensity = pow(dot(s.Normal, halfVector), s.SpecularAmount * s.SpecularAmount);
            specIntensity = smoothstep(0.05, 0.05 + s.SpecularSmooth, specIntensity);
            half3 specular = _LightColor0 * s.Specular * specIntensity * litness;

            // Fresnel effect with a smoothstep function to toonify, using normal dot light direction
            // to thin out the rim zone the closer it is to the unlit parts, as done by Roystan in his
            // https://roystan.net/articles/toon-shader cel shading tutorial.
            half rimDot = 1.0 - saturate(dot(s.Normal, viewDir));
            half rimThreshold = pow((1.0 - s.RimAmount), dot(s.Normal, lightDir));
            half rimIntensity = smoothstep(rimThreshold - s.RimSmooth / 2.0, rimThreshold + s.RimSmooth / 2.0, rimDot);
            half3 rim = _LightColor0 * s.Rim * rimIntensity * litness;

            half4 r;
            r.rgb = diffuse + specular + rim;
            r.a = s.Alpha;
            return r;
        }

        // Add instancing support for this shader. You need to check 'Enable Instancing' on materials that use the shader.
        // See https://docs.unity3d.com/Manual/GPUInstancing.html for more information about instancing.
        // #pragma instancing_options assumeuniformscaling
        UNITY_INSTANCING_BUFFER_START(Props)
            // put more per-instance properties here
        UNITY_INSTANCING_BUFFER_END(Props)

        void surf (Input i, inout CelShaderSurfaceOutput o)
        {
            o.Albedo = (tex2D(_MainTex, i.uv_MainTex) * _Color).rgb;
            o.Alpha = (tex2D(_MainTex, i.uv_MainTex) * _Color).a;
            o.Normal = UnpackNormal(tex2D(_NormalMap, i.uv_NormalMap));
            o.ShadowSmooth = _ShadowSmooth;

            // We're toonifying Blinn-Phon's specular component with a smoothstep function, and specular amount is the
            // glossiness value. We're turning a 0 to 1 range value into Blinn-Phon's glossiness range values.
            o.Specular = tex2D(_SpecularMap, i.uv_SpecularMap).r * _Specular;
            o.SpecularAmount = pow(2.0, 8.0 * (1.0 - tex2D(_SpecularMap, i.uv_SpecularMap).g * _SpecularAmount));
            o.SpecularSmooth = tex2D(_SpecularMap, i.uv_SpecularMap).b * _SpecularSmooth;

            o.Rim = tex2D(_RimMap, i.uv_RimMap).r * _Rim;
            o.RimAmount = tex2D(_RimMap, i.uv_RimMap).g * _RimAmount;
            o.RimSmooth = tex2D(_RimMap, i.uv_RimMap).b * _RimSmooth;

            o.Emission = tex2D(_EmissionMap, i.uv_EmissionMap).rgb * _Emission;
        }

        ENDCG

        // Outline pass. Translated from GDQuest's Godot outline shader.
        // Source: https://github.com/GDQuest/godot-shaders/blob/master/godot/Shaders/pixel_perfect_outline3D.shader
        Pass {
            Name "Outline"

            Tags {
                "RenderType" = "Opaque"
                "ForceNoShadowCasting" = "True"
            }
            
            Cull Front
            ZWrite Off

            CGPROGRAM
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
                float4 position : SV_POSITION;
            };

            Interpolators vert (MeshData v) {
                Interpolators o;

                // We convert to clip space to have higher control over thickness, making it according to screen.
                float4 clipPos = UnityObjectToClipPos(v.vertex.xyz);
                float3 clipNormal = UnityObjectToClipPos(v.normal.xyz) - clipPos;

                // We multiply it by thickness over screen size to keep thickness constant over distance.
                clipPos.xy += normalize(clipNormal.xy) / _ScreenParams.xy * clipPos.w * _OutlineThickness * 2.0;
                o.position = clipPos;
                return o;
            }

            fixed4 frag (Interpolators i) : SV_TARGET {
                return _OutlineColor;
            }
            ENDCG
        }
    }
    FallBack "Diffuse"
}
