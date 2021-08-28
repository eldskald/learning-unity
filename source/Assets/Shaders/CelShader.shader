Shader "Custom/CelShader" {

    Properties {
        // Albedo. The albedo texture is the only one with tiling and offset.
        // Since other textures are usually aligned with it, all textures will
        // use this tiling and offset unless otherwise noted.
        _Color ("Albedo", Color) = (1,1,1,1)
        _MainTex ("Albedo Texture", 2D) = "white" {}

        // Smoothness of the transition between the lit and non-lit areas. The
        // closer to zero it is, the sharper the transition will be. A value of
        // one will resemble traditional lighting.
        _DiffuseSmooth ("Diffuse Smoothness", Range(0, 1)) = 0.02

        // Specular highlight properties. Set specular to zero to turn off the
        // effect. The texture map uses the red channel for the specular value,
        // green for amount and blue for smoothness.
        [Header(Specular Highlight)]
        _Specular ("Specular", Range(0, 1)) = 0.5
        _SpecularAmount ("Specular Amount", Range(0, 1)) = 0.5
        _SpecularSmooth ("Specular Smoothness", Range(0, 1)) = 0.05
        [NoScaleOffset] _SpecularMap ("Specular Map", 2D) = "white" {}
        
        // Rim highlight properties. Set rim to zero to turn off the effect.
        // The texture map uses the red channel for the rim value, green for
        // rim amount and blue for smoothness.
        [Header(Rim Highlight)]
        _Rim ("Rim", Range(0, 1)) = 0.5
        _RimAmount ("Rim Amount", Range(0, 1)) = 0.2
        _RimSmooth ("Rim Smoothness", Range(0, 1)) = 0.05
        [NoScaleOffset] _RimMap ("Rim Map", 2D) = "white" {}

        // Outline properties. Set thickness to zero to turn it off.
        [Header(Outline)]
        _OutlineThickness ("Outline Thickness", Float) = 2
        _OutlineColor ("Outline Color", Color) = (0,0,0,1)

        // Emission properties. Keep it at black to turn off the effect.
        [Header(Emission)]
        [HDR] _Emission ("Emission", Color) = (0,0,0,1)
        [NoScaleOffset] _EmissionMap ("Emission Map", 2D) = "white" {}

        // Reflections properties. A reflectivity of zero means only ambient
        // light is added, while a reflectivity of one means only reflections
        // are added. Blurriness is how blurry the reflections are. If you want
        // to make perfect mirrors, keep albedo and emisson black, and put
        // specular and rim to zero. The reflections map uses the red channel for
        // reflectivity and the green channel for blurriness. Oh, and don't forget
        // to add reflection probes on the scene as well. Keep in mind they are
        // an imperfect approximation, so if you want a perfect and flat mirror,
        // there are better methods of doing so.
        [Header(Reflections)]
        _Reflectivity ("Reflectivity", Range(0, 1)) = 0
        _Blurriness ("Blurriness", Range(0, 1)) = 0
        [NoScaleOffset] _ReflectionsMap ("Reflectivity Map", 2D) = "white" {}
    }

    SubShader {
        
        // Forward base pass. This one is called for the main light source on the
        // fragment and processes it. Since there is only one main light, it also
        // processes ambient light, reflections, emission and other things that
        // have to be processed only once.
        Pass {
            Tags { "LightMode" = "ForwardBase" }

            CGPROGRAM

            #pragma target 3.0

            #define FORWARD_BASE_PASS // Define to be read by the include file.

            #include "CelShadedLighting.cginc"

            ENDCG
        }

        // Forward add pass. Called once for every additional light source on the
        // fragment and processes it. We set it to additive blend mode in order
        // for it to add to the previous passes.
        Pass {
            Tags { "LightMode" = "ForwardAdd" }
            
            Blend One One
            ZWrite Off

            CGPROGRAM

            #pragma target 3.0
            #pragma multi_compile_fwdadd
            
            #include "CelShadedLighting.cginc"

            ENDCG
        }

        // Outline pass. We're using the spatial approach instead of the post
        // processing one in order for the outlines to show up on reflections,
        // refractions and other possible things.
        Pass {
            Tags { "ForceNoShadowCasting" = "True" }
            
            Cull Front
            ZWrite Off

            CGPROGRAM

            #pragma target 3.0

            #include "CelShaderOutline.cginc"

            ENDCG
        }
    }
}
