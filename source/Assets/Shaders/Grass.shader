Shader "VFX/Grass" {

    Properties {

        _Color ("Albedo", Color) = (1,1,1,1)
        _Wind ("Wind", Vector) = (1,0,0,0)
        _Resistance ("Resistance", Float) = 1
        _Interval ("Interval", Float) = 3.5
        _HeightOffset ("HeightOffset", Float) = 0
        _VarCurve ("Sway Curve", 2D) = "white" {}
        _VarIntensity ("Sway Intensity", Float) = 1
        _VarFrequency ("Sway Frequency", Float) = 1
    }

    SubShader {

        Tags { "RenderType" = "Opaque" }
        LOD 100

        Pass {

            Tags { "LightMode" = "ForwardBase" }

            CGPROGRAM

            #pragma target 3.0

            #pragma multi_compile _ SHADOWS_SCREEN
            #pragma multi_compile _ VERTEXLIGHT_ON
            #pragma multi_compile_fog

            #include "CelShadedLighting.cginc"
            #include "WindSway.cginc"

            #pragma vertex vert
            #pragma fragment frag

            Interpolators vert (VertexData v) {
                v.vertex = WindDisplaceVertex(v.vertex);
                return BasicVertex(v);
            }

            fixed4 frag (Interpolators i) : SV_TARGET {
                fixed4 col = float4(0, 0, 0, 1);

                UnityLight light = GetLight(i);
                col.rgb += light.color * _Color.rgb;
                col.rgb += ShadeSH9(float4(i.normal, 1)) * _Color.rgb;

                #if defined(VERTEXLIGHT_ON)
                    UnityLight vLight0 = GetVertexLight0(i);
                    col.rgb += vLight0.color * _Color.rgb;

                    UnityLight vLight1 = GetVertexLight1(i);
                    col.rgb += vLight1.color * _Color.rgb;

                    UnityLight vLight2 = GetVertexLight2(i);
                    col.rgb += vLight2.color * _Color.rgb;

                    UnityLight vLight3 = GetVertexLight3(i);
                    col.rgb += vLight3.color * _Color.rgb;
                #endif

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

            #include "CelShadedLighting.cginc"
            #include "WindSway.cginc"

            #pragma vertex vert
            #pragma fragment frag

            Interpolators vert (VertexData v) {
                v.vertex = WindDisplaceVertex(v.vertex);
                return BasicVertex(v);
            }

            fixed4 frag (Interpolators i) : SV_TARGET {
                fixed4 col = float4(0, 0, 0, 1);

                UnityLight light = GetLight(i);
                col.rgb += light.color * _Color.rgb;

                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }

            ENDCG
        }

        Pass {

            Tags { "LightMode" = "Always" }
            
            Cull Front
            ZWrite On

            CGPROGRAM

            #pragma target 3.0

            #pragma multi_compile_fog

            #include "CelShaderOutline.cginc"
            #include "WindSway.cginc"

            #pragma vertex vert
            #pragma fragment frag

            Interpolators vert (MeshData v) {
                v.vertex = WindDisplaceVertex(v.vertex);
                return OutlineVertex(v);
            }

            float4 frag (Interpolators i) : SV_TARGET {
                float4 col = OutlineFragment(i);
                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }

            ENDCG
        }

        Pass {
            Tags { "LightMode" = "ShadowCaster" }

            CGPROGRAM

            #pragma target 3.0

            #pragma multi_compile_shadowcaster

            #include "ShadowCaster.cginc"
            #include "WindSway.cginc"

            #pragma vertex vert
            #pragma fragment frag

            VertexInterpolators vert (MeshData v) {
                v.vertex = WindDisplaceVertex(v.vertex);
                return ShadowCasterVertex(v);
            }

            float4 frag (Interpolators i) : SV_TARGET {
                return ShadowCasterFragment(i);
            }

            ENDCG
        }
    }
}
