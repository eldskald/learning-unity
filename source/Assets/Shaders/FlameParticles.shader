// This shader is almost straight copied from MinionsArts at
// https://www.patreon.com/posts/quick-game-art-27093551
//
// I loosely modified it to simplify, give more control to the particles
// component and slightly attempt to toonify it a little bit more and added
// a soft particles option.

Shader "Particles/Flames" {

    Properties {

        [NoScaleOffset] _MainTex ("Mask", 2D) = "white" {}
        _Noise ("Noise", 2D) = "white" {}
        _Speed ("Speed", Range(-10, 10)) = 2
        _Brightness ("Brightness", Range(0, 5)) = 1
        _Density ("Density", Range(0.01, 1)) = 0.25
        _EdgeWidth ("Smoothness", Range(0, 1)) = 0.4
        [Toggle(_SOFT_PARTICLES_ENABLED)]
            _SoftParticles ("Soft Particles", Float) = 1
    }

    SubShader {

        Tags {
            "Queue" = "Transparent"
            "IgnoreProjector" = "True"
            "RenderType" = "Transparent"
            "PreviewType" = "Plane"
        }

        Blend SrcAlpha OneMinusSrcAlpha
        ColorMask RGB
        Cull Off
        Lighting Off
        ZWrite Off
        ZTest Off
            
        Pass {

            CGPROGRAM

            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog
            #pragma shader_feature _SOFT_PARTICLES_ENABLED
 
            #include "UnityCG.cginc"
 
            struct appdata {
                float4 vertex : POSITION;
                float3 uv : TEXCOORD0;
                float4 color : COLOR;
                float4 normal : NORMAL;
            };
 
            struct v2f {
                float3 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 pos : SV_POSITION;
                float4 color: COLOR;
                float3 worldPos : TEXCOORD2;
                float3 worldNormal : TEXCOORD3;

                #if defined(_SOFT_PARTICLES_ENABLED)
                    float4 projPos : TEXCOORD4;
                #endif
            };
 
            sampler2D _MainTex, _Noise;
            float4 _Noise_ST;
            float _Speed, _Brightness, _Density, _EdgeWidth;

            #if defined(_SOFT_PARTICLES_ENABLED)
                sampler2D_float _CameraDepthTexture;
            #endif

            v2f vert (appdata v) {
                v2f o;
                o.worldNormal = mul(unity_ObjectToWorld,v.normal);
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                o.worldPos = mul(unity_ObjectToWorld, v.vertex);
                UNITY_TRANSFER_FOG(o, o.pos);
                o.color = v.color;

                #if defined(_SOFT_PARTICLES_ENABLED)
                    o.projPos = ComputeScreenPos(o.pos);
                    COMPUTE_EYEDEPTH(o.projPos.z);
                #endif

                return o;
            }

            fixed4 frag (v2f i) : SV_TARGET {
                float mask = tex2D(_MainTex, i.uv.xy).x;
                float4 col;

                // First part where we sample noise texture based on world
                // positions for zy and xy planes and blend them together in
                // order to give the effect of view direction to the billboard.
                float3 blendNormal = saturate(pow(i.worldNormal * 1.4, 4));
                i.worldPos.y -= _Time.y * _Speed;
                float xn = tex2D(_Noise, i.worldPos.zy * _Noise_ST.xy);
                float zn = tex2D(_Noise, i.worldPos.xy * _Noise_ST.xy);
                float noise = lerp(zn, xn, blendNormal.x);

                // We diminish the strength of the noise texture on young
                // particles to prevent holes at the flame's source.
                noise = 1 - (1 - noise) * saturate(i.uv.z / _Density);

                // Final color and alpha values.
                col.rgb = i.color.rgb * _Brightness;
                col.a = smoothstep(
                    0.1, 0.1 + _EdgeWidth, noise * mask * i.color.a);
                
                #if defined(_SOFT_PARTICLES_ENABLED)
                    float zDepth = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE_PROJ(
                        _CameraDepthTexture, UNITY_PROJ_COORD(i.projPos)));
                    float zPos = i.projPos.z;
                    col.a *= saturate((zDepth - zPos) * 16);
                #endif

                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }

            ENDCG
        }
    }
}


