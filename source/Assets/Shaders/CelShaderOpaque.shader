Shader "CelShaded/Opaque" {

    Properties {

        // Helper properties for the rendering modes.
        _Cutoff ("Alpha Cutoff", Range(0, 1)) = 0.5
        [HideInInspector] _SrcBlend ("_SrcBlend", Float) = 1
        [HideInInspector] _DstBlend ("_DstBlend", Float) = 0
        [HideInInspector] _ZWrite ("_ZWrite", Float) = 1

        // Albedo. The albedo texture is the only one with tiling and offset.
        // Since other textures are usually aligned with it, all textures will
        // use this tiling and offset unless otherwise noted.
        _Color ("Albedo", Color) = (1,1,1,1)
        _MainTex ("Albedo Texture", 2D) = "white" {}

        // Diffuse curve, used to toonify and create shade bands, or even
        // un-toonify as well. I go into more detail on how to use it on my
        // video at https://youtu.be/Y3tT_-GTXKg where I explain each feature
        // in detail. I would say this texture is the most important one.
        [NoScaleOffset] _DiffuseGradient ("Diffuse Gradient", 2D) = "white" {}

        // Specular highlight properties. Set specular to zero to turn off the
        // effect. The texture map uses the red channel for the specular value,
        // green for amount and blue for smoothness.
        _Specular ("Specular", Range(0, 1)) = 0.5
        _SpecularAmount ("Specular Amount", Range(0, 1)) = 0.5
        _SpecularSmooth ("Specular Smoothness", Range(0, 1)) = 0.05
        [NoScaleOffset] _SpecularMap ("Specular Map", 2D) = "white" {}
        
        // Rim highlight properties. Set rim to zero to turn off the effect.
        // The texture map uses the red channel for the rim value, green for
        // rim amount and blue for smoothness.
        _Rim ("Rim", Range(0, 1)) = 0.5
        _RimAmount ("Rim Amount", Range(0, 1)) = 0.2
        _RimSmooth ("Rim Smoothness", Range(0, 1)) = 0.05
        [NoScaleOffset] _RimMap ("Rim Map", 2D) = "white" {}

        // Reflections properties. A reflectivity of zero means only ambient
        // light is added, while a reflectivity of one means only reflections
        // are added. Blurriness is how blurry the reflections are. If you want
        // to make perfect mirrors, keep albedo and emisson black, and put
        // specular and rim to zero. The texture map uses the red channel for
        // reflectivity and the green channel for blurriness. Oh, and don't
        // forget to add reflection probes on the scene as well. Keep in mind
        // they are an imperfect approximation, so if you want a perfect and
        // flat mirror, there are better methods of doing so.
        _Reflectivity ("Reflectivity", Range(0, 1)) = 0
        _Blurriness ("Blurriness", Range(0, 1)) = 0
        [NoScaleOffset] _ReflectionsMap ("Reflections Map", 2D) = "white" {}

        // Outline properties.
        _OutlineThickness ("Outline Thickness", Float) = 3
        _OutlineColor ("Outline Color", Color) = (0,0,0,1)

        // Emission properties.
        [HDR] _Emission ("Emission", Color) = (0,0,0,1)
        [NoScaleOffset] _EmissionMap ("Emission Map", 2D) = "white" {}

        // Normal map properties.
        [NoScaleOffset] [Normal] _BumpMap ("Normal Map", 2D) = "bump" {}
        _BumpScale ("Bump Scale", Float) = 1

        // Height map properties. Don't forget that this is a cel shader,
        // which is supposed to minimize details. Given how lighting is mostly
        // uniform throughout the surface, you might not see a lot of changes
        // from using detailed height maps, I'm leaving it in just in case.
        [NoScaleOffset] _ParallaxMap ("Height Map", 2D) = "black" {}
        _ParallaxScale ("Offset Scale", Range(0, 1)) = 0.5

        // Occlusion properties. Again, don't forget that this is a cel shader.
        // An occlusion map from a traditional photo-realistic texture might
        // not look ideal. It will work and do it's thing, but a 2D cartoon
        // style doesn't look like that. Use maps with more defined zones, like
        // the ones created by this shader's diffuse, with either white or
        // black zones, not much grey. For exemple, you can use it to darken
        // the interior of a barrel. But eh, it's your game, who am I to tell
        // you how it should look like? Just my opinion on how to maximize
        // this shader in particular.
        [NoScaleOffset] _OcclusionMap ("Occlusion Map", 2D) = "white" {}
        _OcclusionScale ("Occlusion Scale", Range(0, 1)) = 1

        // Anisotropy properties.
        [NoScaleOffset] [Normal]
            _AnisoFlowchart ("Anisotropy Flowchart", 2D) = "bump" {}
        _AnisoScale ("Anisotropy Scale", Range(0, 1)) = 0.5

        // Translucency properties. This is a very basic type of subsurface
        // scattering, very lightweight and works really well with cel shading.
        // This effect is called transmission in Godot.
        _Transmission ("Translucency", Color) = (0,0,0,1)
        _TransmissionMap ("Translucency Map", 2D) = "white" {}

        // Refraction properties. We are using the grab pass here, so don't
        // put a lot of these on the screen, it is very GPU intensive. You
        // can create a lighter version by naming the grab pass, which in
        // return, refractive materials won't show up behind one another.
        // Since we can't disable the grab pass on a shader with code, we must
        // have a different shader for just this effect.
        [NoScaleOffset] _RefractionMap ("Refraction Map", 2D) = "white" {}
        _RefractionScale ("Refraction Scale", Range(-16, 16)) = 0
    }

    SubShader {

        // Forward base pass. This one is called for the main light source and
        // processes it. Since there is only one main light, it also processes
        // ambient light, reflections, emission and other things that have to
        // be processed only once.
        Pass {
            Tags { "LightMode" = "ForwardBase" }

            CGPROGRAM

            #pragma target 3.0

            #pragma multi_compile _ SHADOWS_SCREEN
            #pragma multi_compile _ LIGHTMAP_ON VERTEXLIGHT_ON
            #pragma multi_compile_fog

            #pragma shader_feature _REFLECTIONS_ENABLED
            #pragma shader_feature _EMISSION_ENABLED
            #pragma shader_feature _BUMPMAP_ENABLED
            #pragma shader_feature _PARALLAX_ENABLED
            #pragma shader_feature _OCCLUSION_ENABLED
            #pragma shader_feature _ANISOTROPY_ENABLED
            #pragma shader_feature _TRANSMISSION_ENABLED

            #include "CelShadedLighting.cginc"

            ENDCG
        }

        // Forward add pass. Called once for every additional light source on
        // the scene and processes each. We set it to additive blend mode in
        // order for it to add to the previous passes, as they render on top
        // of each other.
        Pass {
            Tags { "LightMode" = "ForwardAdd" }
            
            Blend One One
            ZWrite Off

            CGPROGRAM

            #pragma target 3.0

            #pragma multi_compile_fwdadd_fullshadows
            #pragma multi_compile_fog

            #pragma shader_feature _BUMPMAP_ENABLED
            #pragma shader_feature _PARALLAX_ENABLED
            #pragma shader_feature _ANISOTROPY_ENABLED
            #pragma shader_feature _TRANSMISSION_ENABLED
            
            #include "CelShadedLighting.cginc"

            ENDCG
        }

        // Outline pass. We're using the spatial approach instead of the post
        // processing one in order for the outlines to show up on reflections,
        // refractions and other possible things.
        Pass {
            Tags { "LightMode" = "Always" }
            
            Cull Front
            ZWrite On

            CGPROGRAM

            #pragma target 3.0
            #pragma multi_compile_fog

            #include "CelShaderOutline.cginc"

            ENDCG
        }

        // Unity's built-in shadow caster pass. If you want to understand it,
        // Catlike's https://catlikecoding.com/unity/tutorials/rendering/
        // tutorial goes in depth on how shadows are rendered. Unity's own
        // documentation also explains how to quickly implement shadows
        // without going into detail on how they work on this page here:
        // https://docs.unity3d.com/Manual/SL-VertexFragmentShaderExamples.html.
        UsePass "Legacy Shaders/VertexLit/SHADOWCASTER"
    }

    // Assigning our custom GUI for this shader.
    CustomEditor "CelShaderGUI"
}
