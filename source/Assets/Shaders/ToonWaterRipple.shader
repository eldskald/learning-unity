Shader "Particles/ToonWaterRipple" {

    Properties {
        
        _FadeStart ("Fade Start", Range(0, 1)) = 0.9
        _Width ("Width", Range(0.01, 0.3)) = 0.1
    }

    SubShader {

        Tags {
            "RenderType" = "AlphaTest"
            "Queue" = "AlphaTest"
        }

        Pass {

            Tags { "LightMode" = "ForwardBase" }

            Blend One Zero
            ZWrite On

            CGPROGRAM

            #pragma target 3.0

            #pragma multi_compile _ SHADOWS_SCREEN
            #pragma multi_compile _ VERTEXLIGHT_ON
            #pragma multi_compile_fog

            #pragma vertex vert
            #pragma fragment frag

            #include "ToonWaterRippleLighting.cginc"

            v2f vert (appdata v) {
                v2f o = WaterRippleVertex(v);
                return o;
            }

            fixed4 frag (v2f i) : SV_TARGET {
                fixed4 col = WaterRippleFragment(i);
                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }

            ENDCG
        }

        Pass {

            Tags { "LightMode" = "ForwardAdd" }

            Blend One One
            ZWrite Off

            CGPROGRAM

            #pragma target 3.0

            #pragma multi_compile_fwdadd_fullshadows
            #pragma multi_compile_fog

            #pragma vertex vert
            #pragma fragment frag

            #include "ToonWaterRippleLighting.cginc"

            v2f vert (appdata v) {
                v2f o = WaterRippleVertex(v);
                return o;
            }

            fixed4 frag (v2f i) : SV_TARGET {
                fixed4 col = WaterRippleFragment(i);
                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }

            ENDCG
        }
    }
}
