// This shader is almost straight copied from MinionsArts at
// https://www.patreon.com/posts/quick-game-art-27093551
//
// I took the basic idea and turned into smoke, pretty much. Can be used
// to make fog, dust, steam and all sorts of environmental VFX. It also
// has obligatory soft particles.

Shader "Particles/Smoke" {

    Properties {

        [NoScaleOffset] _MainTex ("Mask", 2D) = "white" {}
        _NoiseA ("Noise A", 2D) = "white" {}
        _NoiseB ("Noise B", 2D) = "white" {}
        _SpeedXA ("Noise A Speed X", Range(-10, 10)) = 0
        _SpeedYA ("Noise A Speed Y", Range(-10, 10)) = 0
        _SpeedXB ("Noise B Speed X", Range(-10, 10)) = 0
        _SpeedYB ("Noise B Speed Y", Range(-10, 10)) = 0
        _Softness ("Softness", Range(0, 1)) = 0.5
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
        ZTest Off

        Pass {

            Tags { "LightMode" = "ForwardBase" }

            Blend SrcAlpha OneMinusSrcAlpha

            CGPROGRAM

            #pragma target 3.0

            #pragma multi_compile _ SHADOWS_SCREEN
            #pragma multi_compile _ VERTEXLIGHT_ON
            #pragma multi_compile_fog

            #pragma vertex vert
            #pragma fragment frag

            #include "SmokeParticlesInc.cginc"

            v2f vert (appdata v) {
                v2f o = SmokeVertex(v);
                return o;
            }

            fixed4 frag (v2f i) : SV_TARGET {
                fixed4 col = SmokeFragment(i);
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

            #include "SmokeParticlesInc.cginc"

            v2f vert (appdata v) {
                v2f o = SmokeVertex(v);
                return o;
            }

            fixed4 frag (v2f i) : SV_TARGET {
                fixed4 col = SmokeFragment(i);
                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }

            ENDCG
        }
    }
}
