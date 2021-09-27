Shader "CelShaded/Transparent" {

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

        // Specular blob properties. Set color to black to turn off the
        // effect. The texture is like an albedo texture for specular color,
        // using the alpha channel for the amount value.
        _SpecularColor ("Specular Color", Color) = (0.5, 0.5, 0.5, 1)
        _SpecularAmount ("Specular Amount", Range(0, 1)) = 0.5
        [NoScaleOffset] _SpecularTex ("Specular Texture", 2D) = "white" {}
        
        // Fresnel effect properties. Set color to zero to turn off the
        // effect. The texture is like an albedo texture for Fresnel color,
        // using the alpha channel for the amount value.
        _FresnelColor ("Fresnel Color", Color) = (0.5, 0.5, 0.5, 1)
        _FresnelAmount ("Fresnel Amount", Range(0, 1)) = 0.2
        [NoScaleOffset] _FresnelTex ("Fresnel Texture", 2D) = "white" {}

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
        _Transmission ("Translucency", Range(0, 1)) = 0
        _TransmissionMap ("Translucency Map", 2D) = "white" {}

        // Refraction properties. We are using the grab pass here, so don't
        // put a lot of these on the screen, it is very GPU intensive. You
        // can create a lighter version by naming the grab pass, which in
        // return, refractive materials won't show up behind one another.
        // Since we can't disable the grab pass on a shader with code, we must
        // have a different shader for just this effect.
        [NoScaleOffset] _RefractionMap ("Refraction Map", 2D) = "white" {}
        _RefractionScale ("Refraction Scale", Range(-1, 1)) = 0.5
    }

    SubShader {
        
        // Forward base pass. This one is called for the main light source and
        // processes it. Since there is only one main light, it also processes
        // ambient light, reflections, emission and other things that have to
        // be processed only once.
        Pass {
            Tags { "LightMode" = "ForwardBase" }

            Blend [_SrcBlend] [_DstBlend]
            ZWrite [_ZWrite]

            CGPROGRAM

            #pragma target 3.0

            #pragma multi_compile _ SHADOWS_SCREEN
            #pragma multi_compile _ LIGHTMAP_ON VERTEXLIGHT_ON
            #pragma multi_compile_fog

            #pragma shader_feature _ _RENDERING_CUTOUT _RENDERING_FADE _RENDERING_TRANSPARENT

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
            
            Blend [_SrcBlend] One
            ZWrite Off

            CGPROGRAM

            #pragma target 3.0

            #pragma multi_compile_fwdadd_fullshadows
            #pragma multi_compile_fog

            #pragma shader_feature _ _RENDERING_CUTOUT _RENDERING_FADE _RENDERING_TRANSPARENT

            #pragma shader_feature _BUMPMAP_ENABLED
            #pragma shader_feature _PARALLAX_ENABLED
            #pragma shader_feature _ANISOTROPY_ENABLED
            #pragma shader_feature _TRANSMISSION_ENABLED
            
            #include "CelShadedLighting.cginc"

            ENDCG
        }

        // Deferred pass. Cel shading is usually at its best with just a few
        // lights on the scene, but just for completeness sake and in case we
        // need it, it's here.
        Pass {
            Tags { "LightMode" = "Deferred" }

            CGPROGRAM

            #pragma target 3.0
		    #pragma exclude_renderers nomrt

            #pragma multi_compile_fog

            #pragma shader_feature _ _RENDERING_CUTOUT _RENDERING_FADE _RENDERING_TRANSPARENT

            #pragma shader_feature _REFLECTIONS_ENABLED
            #pragma shader_feature _EMISSION_ENABLED
            #pragma shader_feature _BUMPMAP_ENABLED
            #pragma shader_feature _PARALLAX_ENABLED
            #pragma shader_feature _OCCLUSION_ENABLED
            #pragma shader_feature _ANISOTROPY_ENABLED
            #pragma shader_feature _TRANSMISSION_ENABLED

            #define DEFERRED_PASS

            #include "CelShadedLighting.cginc"

            ENDCG
        }

        // ZWrite pass. On transparent rendering modes, it blocks the
        // outline mesh from rendering in front of the actual geometry.
        // We can't have total control of which passes to turn on and off on
        // the GUI script, so we are forced to have this pass on opaque mode
        // or to make two different shader scripts, one for opaque without
        // this pass and one for the rest with it.
        Pass {
            Tags { "LightMode" = "Always" }

            ZWrite On
            ColorMask 0
        }

        // Outline pass. We're using the spatial approach instead of the post
        // processing one in order for the outlines to show up on reflections,
        // refractions and other possible things.
        Pass {
            Tags { "LightMode" = "Always" }
            
            Cull Front
            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite On

            CGPROGRAM

            #pragma target 3.0
            #pragma multi_compile_fog

            #include "CelShaderOutline.cginc"

            ENDCG
        }

        // Shadow caster pass. This pass renders to the shadow map textures.
        // Unity has its built-in shadow caster, but I did a custom one in
        // order to include semi transparent shadows. All done by following
        // Catlike's https://catlikecoding.com/unity/tutorials/rendering/
        // tutorials on shadows and semi transparent shadows.
        Pass {
            Tags { "LightMode" = "ShadowCaster" }

            CGPROGRAM

            #pragma target 3.0

            #pragma multi_compile_shadowcaster

            #pragma shader_feature _ _DITHER_SHADOWS _CUTOUT_SHADOWS

            #include "ShadowCaster.cginc"

            ENDCG
        }
    }

    // Assigning our custom GUI for this shader.
    CustomEditor "CelShaderGUI"
}
