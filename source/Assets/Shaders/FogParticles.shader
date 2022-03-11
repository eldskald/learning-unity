// This shader is almost straight copied from MinionsArts at
// https://www.patreon.com/posts/quick-game-art-27093551
//
// I took the basic idea and turned into smoke, pretty much. Can be used
// to make fog, dust, steam and all sorts of environmental VFX. It also
// has obligatory soft particles.

Shader "Particles/Fog" {

    Properties {

        [NoScaleOffset] _MainTex ("Mask", 2D) = "white" {}
        _Noise ("Noise", 2D) = "white" {}
        _SpeedX ("Noise Speed X", Range(-10, 10)) = 0
        _SpeedY ("Noise Speed Y", Range(-10, 10)) = 0
        _Softness ("Softness", Range(0, 1)) = 0.1
        _FadeIn ("Fade In", Range(0, 1)) = 0.1
        _FadeOut ("Fade Out", Range(0, 1)) = 0.9
        _NearFade ("Near Fade", Float) = 1
        _FarFade ("Far Fade", Float) = 100
    }

    SubShader {

        Tags {
            "Queue" = "Transparent"
            "IgnoreProjector" = "True"
            "RenderType" = "Transparent"
            "PreviewType" = "Plane"
        }

        ColorMask RGB
        Cull Off
        ZWrite Off

        Pass {

            Tags { "LightMode" = "ForwardBase" }

            Blend SrcAlpha OneMinusSrcAlpha

            CGPROGRAM

            #pragma target 3.0

            #pragma multi_compile _ VERTEXLIGHT_ON
            #pragma multi_compile_fog

            #pragma vertex vert
            #pragma fragment frag

            #include "FogParticlesInc.cginc"

            v2f vert (appdata v) {
                v2f o = FogVertex(v);

                #if defined(VERTEXLIGHT_ON)
                    Set4VertexLights(o);
                #endif

                return o;
            }

            fixed4 frag (v2f i) : SV_TARGET {
                fixed4 col = FogFragment(i);
                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }

            ENDCG
        }

        Pass {

            Tags { "LightMode" = "ForwardAdd" }

            Blend SrcAlpha One

            CGPROGRAM

            #pragma target 3.0

            #pragma multi_compile_fwdadd_fullshadows
            #pragma multi_compile_fog

            #pragma vertex vert
            #pragma fragment frag

            #include "FogParticlesInc.cginc"

            v2f vert (appdata v) {
                v2f o = FogVertex(v);

                #if defined(VERTEXLIGHT_ON)
                    Set4VertexLights(o);
                #endif

                return o;
            }

            fixed4 frag (v2f i) : SV_TARGET {
                fixed4 col = FogFragment(i);
                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }

            ENDCG
        }
    }
}
