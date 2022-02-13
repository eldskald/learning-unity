Shader "Unlit/FogPlane" {

    Properties {

        _Color ("Color", Color) = (1,1,1,1)
        _MainTex ("Noise Texture", 2D) = "black" {}
        _Strength ("Strength", Range(0, 1)) = 0.3
        _NoiseStrength ("Noise Strength", Range(0, 1)) = 0.8
        _NoiseSpeed ("Noise Speed", Range(0, 1)) = 0.1
    }

    SubShader {

        Tags {
            "RenderType" = "Transparent"
            "Queue" = "Transparent"
        }

        Pass {

            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off

            CGPROGRAM

            #pragma target 3.0

            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float4 screenUV : TEXCOORD1;
            };

            fixed4 _Color;
            half _Strength;
            sampler2D _MainTex;
            half4 _MainTex_ST;
            half _NoiseStrength;
            half _NoiseSpeed;
            sampler2D _CameraDepthTexture;

            v2f vert (appdata v) {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv * _MainTex_ST.xy + _MainTex_ST.zw;
                o.screenUV = ComputeGrabScreenPos(o.pos);
                return o;
            }

            fixed4 frag (v2f i) : SV_TARGET {
                float zDepth = LinearEyeDepth(tex2Dproj(
                    _CameraDepthTexture, UNITY_PROJ_COORD(i.screenUV)));
                float zPos = i.screenUV.w;
                float zDiff = zDepth - zPos;

                float noise = tex2D(_MainTex, i.uv + _Time.y * _NoiseSpeed).x;
                noise *= _NoiseStrength;

                fixed4 col;
                col.rgb = _Color.rgb;
                col.a = saturate(zDiff * _Strength * (1 - noise));
                return col;
            }

            ENDCG
        }
    }
}
