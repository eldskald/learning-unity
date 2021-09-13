using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEditor;

public class CelShaderGUI : ShaderGUI {

    private Material target;
    private MaterialEditor editor;
    private MaterialProperty[] properties;

    public override void OnGUI (MaterialEditor editor, MaterialProperty[] properties) {
        this.target = editor.target as Material;
        this.editor = editor;
        this.properties = properties;

        if (target.shader.name == "CelShaded/Transparent") {
            AddRenderMode();
            if (showAlphaCutoff) {
                AddAlphaCutoff();
            }
            LongSpace();
        }

        GroupLabel("Main Properties");

        // Commenting out the smoothness because I won't set them on a per material
        // basis, I would rather set them on the script and have all values on each
        // material change accordingly. Leaving it out makes the GUI cleaner.
        // Leaving it here if I ever change my mind, or if you want to add them.
        // Specular and rim smoothnesses are also commented out.
        
        // AddDiffuseSmooth();
        // ShortSpace();

        AddDiffuseGradient();
        ShortSpace();

        AddAlbedo();
        ShortSpace();
        AddSpecular();
        ShortSpace();
        AddRim();
        ShortSpace();
        AddReflections();
        ShortSpace();
        AddOutline();

        LongSpace();
        GroupLabel("Additional Maps");
        AddEmission();
        AddNormalMap();
        AddHeightMap();
        AddOcclusion();
        AddAnisotropy();
        AddTransmission();

        if (target.shader.name == "CelShaded/Refraction") {
            LongSpace();
            GroupLabel("Refraction");
            AddRefraction();
        }    
    }

    // Helper functions for convenience of writing and reading.
    MaterialProperty GetProperty (string name) {
        return FindProperty(name, properties);
    }

    void SetKeyword (string keyword, bool enable) {
        if (enable) {
            target.EnableKeyword(keyword);
        }
        else {
            target.DisableKeyword(keyword);
        }
    }

    static GUIContent staticLabel = new GUIContent();

    static GUIContent MakeLabel (string text, string tooltip = null) {
        staticLabel.text = text;
        staticLabel.tooltip = tooltip;
        return staticLabel;
    }

    static GUIContent MakeLabel (MaterialProperty property, string tooltip = null) {
        staticLabel.text = property.displayName;
        staticLabel.tooltip = tooltip;
        return staticLabel;
    }

    void ShortSpace () {
        GUILayout.Space(8);
    }

    void LongSpace () {
        GUILayout.Space(16);
    }

    void GroupLabel (string label) {
        GUILayout.Label(label, EditorStyles.boldLabel);
    }

    void RecordAction (string label) {
        editor.RegisterPropertyChangeUndo(label);
    }

    // Stuff that deal and draws rendering settings of the material.
    bool showAlphaCutoff;

    enum RenderMode {
        Fade, Transparent, Cutout
    }

    struct RenderSettings {
        public string shader;
        public RenderQueue queue;
        public string renderType;
        public BlendMode srcBlend, dstBlend;
        public bool zWrite;

        public static RenderSettings[] modes = {
            new RenderSettings() {
                shader = "CelShaded/Transparent",
                queue = RenderQueue.Transparent,
                renderType = "Transparent",
                srcBlend = BlendMode.SrcAlpha,
                dstBlend = BlendMode.OneMinusSrcAlpha,
                zWrite = false
            },
            new RenderSettings() {
                shader = "CelShaded/Transparent",
                queue = RenderQueue.Transparent,
                renderType = "Transparent",
                srcBlend = BlendMode.One,
                dstBlend = BlendMode.OneMinusSrcAlpha,
                zWrite = false
            },
            new RenderSettings() {
                shader = "CelShaded/Transparent",
                queue = RenderQueue.AlphaTest,
                renderType = "TransparentCutout",
                srcBlend = BlendMode.One,
                dstBlend = BlendMode.Zero,
                zWrite = true
            }
        };
    }

    void AddRenderMode () {
        RenderMode mode = RenderMode.Fade;
        showAlphaCutoff = false;
        if (target.IsKeywordEnabled("_RENDERING_FADE")) {
            mode = RenderMode.Fade;
        }
        else if (target.IsKeywordEnabled("_RENDERING_TRANSPARENT")) {
            mode = RenderMode.Transparent;
        }
        else if (target.IsKeywordEnabled("_RENDERING_CUTOUT")) {
            mode = RenderMode.Cutout;
            showAlphaCutoff = true;
        }
        EditorGUI.BeginChangeCheck();
        mode = (RenderMode) EditorGUILayout.EnumPopup(
            MakeLabel("Rendering Mode"), mode);
        if (EditorGUI.EndChangeCheck()) {
            RecordAction("Rendering Mode");
            SetKeyword("_RENDERING_CUTOUT", mode == RenderMode.Cutout);
            SetKeyword("_RENDERING_FADE", mode == RenderMode.Fade);
            SetKeyword("_RENDERING_TRANSPARENT", mode == RenderMode.Transparent);
            RenderSettings settings = RenderSettings.modes[(int)mode];
            foreach (Material m in editor.targets) {
                m.renderQueue = (int)settings.queue;
                m.SetOverrideTag("RenderType", settings.renderType);
                m.SetInt("_SrcBlend", (int)settings.srcBlend);
                m.SetInt("_DstBlend", (int)settings.dstBlend);
                m.SetInt("_ZWrite", settings.zWrite ? 1 : 0);
            }
        }
    }

    void AddAlphaCutoff () {
        MaterialProperty cutoff = GetProperty("_Cutoff");
        EditorGUI.indentLevel += 2;
        editor.ShaderProperty(cutoff, MakeLabel(cutoff));
        EditorGUI.indentLevel -= 2;
    }

    // Functions that draw each of the property sets. Also for convenience, makes it
    // easier to read each one when they're in separate blocks than in a wall of text
    // written on OnGUI().
    void AddDiffuseSmooth () {
        MaterialProperty diffuseSmooth = GetProperty("_DiffuseSmooth");
        editor.ShaderProperty(
            diffuseSmooth, MakeLabel(diffuseSmooth, "Lit area's edge sharpness."));
    }

    Gradient diffuseGradient = new Gradient();

    void AddDiffuseGradient () {
        MaterialProperty diffuseTexture = GetProperty("_DiffuseGradient");
        EditorGUI.BeginChangeCheck();
        diffuseGradient = EditorGUILayout.GradientField(
            MakeLabel(diffuseTexture, "Diffuse gradient texture."), diffuseGradient);
        if (EditorGUI.EndChangeCheck()) {
            Texture2D tex = new Texture2D(256, 1);
            tex.wrapMode = TextureWrapMode.Clamp;
            for (int i = 0; i < 256; i++) {
                tex.SetPixel(i, 0, diffuseGradient.Evaluate(i / (float) 256));
            }
            tex.Apply();
            target.SetTexture(diffuseTexture.name, tex);
        }
    }

    void AddAlbedo () {
        MaterialProperty color = GetProperty("_Color");
        MaterialProperty mainTex = GetProperty("_MainTex");
        editor.TexturePropertySingleLine(
            MakeLabel(color, "Albedo color and texture. Tiles and offsets all " +
            "other textures unless otherwise noted."), mainTex, color);
        editor.TextureScaleOffsetProperty(mainTex);
    }

    void AddSpecular () {
        MaterialProperty spec = GetProperty("_Specular");
        editor.ShaderProperty(
            spec, MakeLabel(spec, "Specular blob strength. Set to 0 to turn off."));
        MaterialProperty specAmount = GetProperty("_SpecularAmount");
        editor.ShaderProperty(
            specAmount, MakeLabel(specAmount, "Specular blob size."));
        // MaterialProperty specSmooth = GetProperty("_SpecularSmooth");
        // editor.ShaderProperty(
        //     specSmooth, MakeLabel(specSmooth, "Specular blob's edge sharpness."));
        MaterialProperty specMap = GetProperty("_SpecularMap");
        editor.TexturePropertySingleLine(
            MakeLabel(specMap, "Specular map. Red is specular strength, green is " +
            "specular amount and red is specular smoothness."), specMap);
    }

    void AddRim () {
        MaterialProperty rim = GetProperty("_Rim");
        editor.ShaderProperty(
            rim, MakeLabel(rim, "Rim reflection strength. Set to 0 to turn off."));
        MaterialProperty rimAmount = GetProperty("_RimAmount");
        editor.ShaderProperty(
            rimAmount, MakeLabel(rimAmount, "Rim reflection size."));    
        // MaterialProperty rimSmooth = GetProperty("_RimSmooth");
        // editor.ShaderProperty(
        //     rimSmooth, MakeLabel(rimSmooth, "Rim reflection's edge sharpness."));
        MaterialProperty rimMap = GetProperty("_RimMap");
        editor.TexturePropertySingleLine(
            MakeLabel(rimMap, "Rim map. Red is rim strength, green is rim amount " +
            "and red is rim smoothness."), rimMap);
    }

    void AddReflections () {
        MaterialProperty reflectivity = GetProperty("_Reflectivity");
        EditorGUI.BeginChangeCheck();
        editor.ShaderProperty(reflectivity, MakeLabel(reflectivity));
        if (EditorGUI.EndChangeCheck()) {
            SetKeyword("_REFLECTIONS_ENABLED", reflectivity.floatValue > 0f);
        }
        MaterialProperty blurriness = GetProperty("_Blurriness");
        editor.ShaderProperty(blurriness, MakeLabel(blurriness));
        MaterialProperty reflMap = GetProperty("_ReflectionsMap");
        editor.TexturePropertySingleLine(
            MakeLabel(reflMap, "Reflections map. Red is reflectivity and green " +
            "is blurriness. Don't forget to set up reflection probes to reflect" +
            "other meshes beside the skybox."), reflMap);
    }

    void AddOutline () {
        MaterialProperty outlineThickness = GetProperty("_OutlineThickness");
        EditorGUI.BeginChangeCheck();
        editor.ShaderProperty(outlineThickness, MakeLabel(outlineThickness));

        // Deactivating all "Always" passes also deactivates GrabPass, refracting objects
        // without outlines are still rendering their geometry three times. If you plan
        // on having those, make a separate shader file without the outline passes.
        if (EditorGUI.EndChangeCheck() && target.shader.name != "CelShaded/Refraction") {
            target.SetShaderPassEnabled("Always", outlineThickness.floatValue > 0f);
        }
        MaterialProperty outlineColor = GetProperty("_OutlineColor");
        editor.ShaderProperty(outlineColor, MakeLabel(outlineColor));
    }

    void AddEmission () {
        MaterialProperty emission = GetProperty("_Emission");
        MaterialProperty emissionMap = GetProperty("_EmissionMap");
        EditorGUI.BeginChangeCheck();
        editor.TexturePropertySingleLine(
            MakeLabel(emission, "Emission map and color."),
            emissionMap, emission);
        if (EditorGUI.EndChangeCheck()) {
            SetKeyword("_EMISSION_ENABLED",
                emission.colorValue != Color.black || emissionMap.textureValue);
        }
    }

    void AddNormalMap () {
        MaterialProperty bumpScale = GetProperty("_BumpScale");
        MaterialProperty bumpMap = GetProperty("_BumpMap");
        EditorGUI.BeginChangeCheck();
        editor.TexturePropertySingleLine(
            MakeLabel(bumpMap, "Normal map and scale."),
            bumpMap, bumpScale);
        if (EditorGUI.EndChangeCheck()) {
            SetKeyword("_BUMPMAP_ENABLED", bumpMap.textureValue);
        }
    }

    void AddHeightMap () {
        MaterialProperty parallaxScale = GetProperty("_ParallaxScale");
        MaterialProperty parallaxMap = GetProperty("_ParallaxMap");
        EditorGUI.BeginChangeCheck();
        editor.TexturePropertySingleLine(
            MakeLabel(parallaxMap, "Height map and scale."),
            parallaxMap, parallaxScale);
        if (EditorGUI.EndChangeCheck()) {
            SetKeyword("_PARALLAX_ENABLED", parallaxMap.textureValue);
        }
    }

    void AddOcclusion () {
        MaterialProperty occlusionScale = GetProperty("_OcclusionScale");
        MaterialProperty occlusionMap = GetProperty("_OcclusionMap");
        EditorGUI.BeginChangeCheck();
        editor.TexturePropertySingleLine(
            MakeLabel(occlusionMap, "Occlusion map and scale."),
            occlusionMap, occlusionScale);
        if (EditorGUI.EndChangeCheck()) {
            SetKeyword("_OCCLUSION_ENABLED", occlusionMap.textureValue);
        }
    }

    void AddAnisotropy () {
        MaterialProperty anisoScale = GetProperty("_AnisoScale");
        MaterialProperty anisoFlowchart = GetProperty("_AnisoFlowchart");
        EditorGUI.BeginChangeCheck();
        editor.TexturePropertySingleLine(
            MakeLabel(anisoFlowchart, "Anisotropic flowchart and scale."),
            anisoFlowchart, anisoScale);
        if (EditorGUI.EndChangeCheck()) {
            SetKeyword("_ANISOTROPY_ENABLED", anisoFlowchart.textureValue);
        }
    }

    void AddTransmission () {
        MaterialProperty transmission = GetProperty("_Transmission");
        MaterialProperty transmissionMap = GetProperty("_TransmissionMap");
        EditorGUI.BeginChangeCheck();
        editor.TexturePropertySingleLine(
            MakeLabel(transmission, "Translucency map and color. Don't forget to " +
            "disable shadow casting on objects with this property."),
            transmissionMap, transmission);
        if (EditorGUI.EndChangeCheck()) {
            bool enable = transmission.colorValue != Color.black ||
                transmissionMap.textureValue;
            SetKeyword("_TRANSMISSION_ENABLED", enable);

            // Transmission only makes sense if you disable shadow casting.
            target.SetShaderPassEnabled("ShadowCaster", !enable);
        }
    }

    void AddRefraction () {
        MaterialProperty refraction = GetProperty("_RefractionScale");
        MaterialProperty refractionMap = GetProperty("_RefractionMap");
        editor.TexturePropertySingleLine(
            MakeLabel("Refraction", "Refraction map and scale. Albedo's alpha " +
            "controls transparency amount."), refractionMap, refraction);
    }
}


