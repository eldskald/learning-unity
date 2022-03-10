Shader "VFX/ToonWater" {

    Properties {

        // Main properties.
        _Color ("Color", Color) = (1,1,1,1)
        _Reflectivity ("Reflectivity", Range(0, 1)) = 0.5
        _Agitation ("Agitation", Range(0, 1)) = 0.3
        _Specularity ("Specularity", Range(0, 1)) = 0.5

        // Foam properties.
        _FoamColor ("Foam Color", Color) = (1,1,1,1)
        _FoamSmooth ("Foam Smoothness", Range(0, 1)) = 0.1
        _FoamSize ("Foam Size", Range(0, 1)) = 0.4
        _FoamDisplacement ("Foam Displacement", Range(0, 1)) = 0.6
        [NoScaleOffset] _FoamNoiseTex ("Foam Noise Texture", 2D) = "black" {}
        _FoamNoiseTilings ("Noise Texture Tiling", Vector) = (1,1,0,0)

        // Surface properties. The velocity is a 4D vector containing
        // two 2D velocities in order, the same for the tilings.
        [NoScaleOffset] _HeightMap ("Height Map", 2D) = "black" {}
        [NoScaleOffset] [Normal] _NormalMap ("Normal Map", 2D) = "bump" {}
        _SurfPanVel ("Surface Panning Speeds", Vector) = (1,0,0,1)
        _SurfTilings ("Surface Tilings", Vector) = (1,1,1,1)

        // Customizing options.
        [ToggleOff(_DEPTH_FOG_ENABLED)]
            _NoDepthFog ("No Depth Fog", Float) = 0
        [KeywordEnum(Normal, Fixed, Specular, Disabled)]
            _Foam ("Foam Mode", Float) = 0
        [Toggle(_FRESNEL_EFFECT_ENABLED)]
            _FresnelEffect ("Fresnel Effect", Float) = 0
        [Toggle(_PLANAR_REFLECTIONS_ENABLED)]
            _PlanarReflections ("Planar Reflections", Float) = 0
        [KeywordEnum(One, Two, Three, Four)]
            _PRID ("Planar Refl. ID", Float) = 0
        [Toggle(_UV_EDGE_FOAM_ENABLED)]
            _UVEdgeFoam ("UV Edge Foam", Float) = 0
        _UVEdgeSizes ("UV Edge Sizes", Vector) = (0.1,0,0,0)
    }

    SubShader {

        Tags {
            "RenderType" = "Transparent"
            "Queue" = "Transparent"
        }

        GrabPass {}

        Pass {
            
            Tags { "LightMode" = "ForwardBase" }

            Blend One Zero
            ZWrite Off

            CGPROGRAM

            #pragma target 3.0

            #pragma multi_compile _ SHADOWS_SCREEN
            #pragma multi_compile _ VERTEXLIGHT_ON
            #pragma multi_compile_fog

            #pragma multi_compile _ _DEPTH_FOG_ENABLED
            #pragma multi_compile _ _FRESNEL_EFFECT_ENABLED
            #pragma multi_compile _ _PLANAR_REFLECTIONS_ENABLED
            #pragma multi_compile _FOAM_NORMAL _FOAM_FIXED _FOAM_SPECULAR _FOAM_DISABLED
            #pragma multi_compile _PRID_ONE _PRID_TWO _PRID_THREE _PRID_FOUR
            #pragma multi_compile _ _UV_EDGE_FOAM_ENABLED

            #pragma vertex vert
            #pragma fragment frag

            // For the included files to have the correct definitions.
            #define _BUMPMAP_ENABLED
            #define _TRANSMISSION_ENABLED
            #define _REFLECTIONS_ENABLED
            #define _SCREEN_UV_INCLUDED

            #include "ToonWaterInc.cginc"
            
            Interpolators vert (VertexData v) {
                Interpolators o = BasicVertex(v);

                #if defined(VERTEXLIGHT_ON)
                    Set4VertexLights(o);
                #endif
                
                return o;
            }

            float4 frag (Interpolators i) : SV_TARGET {
                Renormalize(i);
                float4 col = ToonWaterFragment(i);
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
            
            #pragma multi_compile _ _DEPTH_FOG_ENABLED
            #pragma multi_compile _ _FRESNEL_EFFECT_ENABLED
            #pragma multi_compile _FOAM_NORMAL _FOAM_FIXED _FOAM_SPECULAR _FOAM_DISABLED
            #pragma multi_compile _ _UV_EDGE_FOAM_ENABLED

            #pragma vertex vert
            #pragma fragment frag

            // For the included files to have the correct definitions.
            #define _BUMPMAP_ENABLED
            #define _TRANSMISSION_ENABLED
            #define _REFLECTIONS_ENABLED
            #define _SCREEN_UV_INCLUDED
            
            #include "ToonWaterInc.cginc"
            
            Interpolators vert (VertexData v) {
                Interpolators o = BasicVertex(v);

                #if defined(VERTEXLIGHT_ON)
                    Set4VertexLights(o);
                #endif

                return o;
            }

            float4 frag (Interpolators i) : SV_TARGET {
                Renormalize(i);
                float4 col = ToonWaterFragment(i);
                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }

            ENDCG
        }

        // Next are the outline passes.
        Pass {
            Tags { "LightMode" = "Always" }

            ZWrite On
            ColorMask 0
        }

        Pass {
            Tags { "LightMode" = "Always" }
            
            Cull Front
            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite On

            CGPROGRAM

            #pragma target 3.0
            #pragma multi_compile_fog

            #include "CelShaderOutline.cginc"

            #pragma vertex vert
            #pragma fragment frag

            Interpolators vert (MeshData v) {
                Interpolators o = OutlineVertex(v);
                return o;
            }

            float4 frag (Interpolators i) : SV_TARGET {
                float4 col = OutlineFragment(i);
                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }

            ENDCG
        }

        // Shadow caster, working exactly like the one on the base cel shader.
        // With dither shadows it works okay, but you can turn off shadows
        // manually on the mesh in order to brighten the underwater scenery.
        Pass {
            Tags { "LightMode" = "ShadowCaster" }

            CGPROGRAM

            #pragma target 3.0

            #pragma multi_compile_shadowcaster

            #include "ShadowCaster.cginc"

            #pragma vertex vert
            #pragma fragment frag

            VertexInterpolators vert (MeshData v) {
                return ShadowCasterVertex(v);
            }

            float4 frag (Interpolators i) : SV_TARGET {
                return ShadowCasterFragment(i);
            }

            ENDCG
        }
    }

    CustomEditor "ToonWaterGUI"
}
