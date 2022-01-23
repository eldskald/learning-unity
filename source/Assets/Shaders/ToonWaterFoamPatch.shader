Shader "VFX/ToonWaterFoamPatch" {

    Properties {

        _Color ("Foam Color", Color) = (1,1,1,1)
        _FoamSmooth ("Foam Smoothness", Range(0, 1)) = 0.1
        _FoamSize ("Foam Size", Range(0, 1)) = 0.5
        _FoamDisplacement ("Foam Displacement", Range(0, 1)) = 0.3
        _Agitation ("Agitation", Range(0, 1)) = 0.3
        _MainTex ("Foam Noise Texture", 2D) = "black" {}
    }

    SubShader {

        Tags {
            "RenderType" = "AlphaTest"
            "Queue" = "AlphaTest"
        }

        Pass {

            Tags { "LightMode" = "ForwardBase" }

            // Blend SrcAlpha OneMinusSrcAlpha
            Blend One Zero
            ZWrite On

            CGPROGRAM

            #pragma target 3.0

            #pragma multi_compile _ SHADOWS_SCREEN
            #pragma multi_compile _ VERTEXLIGHT_ON
            #pragma multi_compile_fog

            #define _TRANSMISSION_ENABLED

            #pragma vertex vert
            #pragma fragment frag

            #include "ToonWaterFoamPatchLighting.cginc"
            
            Interpolators vert (VertexData v) {
                Interpolators o = CelShadedVertex(v);
                return o;
            }

            float4 frag (Interpolators i) : SV_TARGET {
                float4 col = FoamPatchFragment(i);
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

            #define _TRANSMISSION_ENABLED

            #pragma vertex vert
            #pragma fragment frag

            #include "ToonWaterFoamPatchLighting.cginc"
            
            Interpolators vert (VertexData v) {
                Interpolators o = CelShadedVertex(v);
                return o;
            }

            float4 frag (Interpolators i) : SV_TARGET {
                float4 col = FoamPatchFragment(i);
                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }

            ENDCG
        }
    }
}
