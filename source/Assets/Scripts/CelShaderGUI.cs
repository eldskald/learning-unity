using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEditor;

public class CelShaderGUI : ShaderGUI {

    private Material target;
    private MaterialEditor editor;
    private MaterialProperty[] properties;

    public override void OnGUI (
        MaterialEditor editor, MaterialProperty[] properties
    ) {
        this.target = editor.target as Material;
        this.editor = editor;
        this.properties = properties;

        AddRenderMode();
        if (showShadowsMode) {
            AddShadowsMode();
        }
        if (showAlphaCutoff) {
            AddAlphaCutoff();
        }
        if (target.shader.name == "CelShaded/Refraction") {
            AddRefraction();
        }    
        LongSpace();

        GroupLabel("Main Properties");
        AddAlbedo();
        AddSpecular();
        AddFresnel();
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
        ShortSpace();
        AddTilingAndOffset();
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

    static GUIContent MakeLabel (
        MaterialProperty property, string tooltip = null
    ) {
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
    bool showShadowsMode;

    enum RenderMode {
        Opaque, Cutout, Fade, Transparent, Refraction
    }

    struct RenderSettings {
        public string shader;
        public RenderQueue queue;
        public string renderType;
        public BlendMode srcBlend, dstBlend;
        public bool zWrite;

        public static RenderSettings[] modes = {
            new RenderSettings() {
                shader = "CelShaded/Opaque",
                queue = RenderQueue.Geometry,
                renderType = "Opaque",
                srcBlend = BlendMode.One,
                dstBlend = BlendMode.Zero,
                zWrite = true
            },
            new RenderSettings() {
                shader = "CelShaded/Transparent",
                queue = RenderQueue.AlphaTest,
                renderType = "TransparentCutout",
                srcBlend = BlendMode.One,
                dstBlend = BlendMode.Zero,
                zWrite = true
            },
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
                shader = "CelShaded/Refraction",
                queue = RenderQueue.Transparent,
                renderType = "Transparent",
                srcBlend = BlendMode.One,
                dstBlend = BlendMode.Zero,
                zWrite = false
            }
        };
    }

    void AddRenderMode () {
        RenderMode mode = RenderMode.Opaque;
        showAlphaCutoff = false;
        showShadowsMode = true;
        if (target.shader == Shader.Find("CelShaded/Opaque")) {
            mode = RenderMode.Opaque;
            showShadowsMode = false;
        }
        else if (target.IsKeywordEnabled("_RENDERING_CUTOUT")) {
            mode = RenderMode.Cutout;
            showAlphaCutoff = true;
        }
        else if (target.IsKeywordEnabled("_RENDERING_FADE")) {
            mode = RenderMode.Fade;
        }
        else if (target.IsKeywordEnabled("_RENDERING_TRANSPARENT")) {
            mode = RenderMode.Transparent;
        }
        else if (target.shader == Shader.Find("CelShaded/Refraction")) {
            mode = RenderMode.Refraction;
        }
        EditorGUI.BeginChangeCheck();
        mode = (RenderMode) EditorGUILayout.EnumPopup(
            MakeLabel("Rendering Mode"), mode);
        if (EditorGUI.EndChangeCheck()) {
            RecordAction("Rendering Mode");
            SetKeyword("_RENDERING_CUTOUT", mode == RenderMode.Cutout);
            SetKeyword("_RENDERING_FADE", mode == RenderMode.Fade);
            SetKeyword("_RENDERING_TRANSPARENT",
                mode == RenderMode.Transparent);
            RenderSettings settings = RenderSettings.modes[(int)mode];
            foreach (Material m in editor.targets) {
                m.shader = Shader.Find(settings.shader);
                m.renderQueue = (int)settings.queue;
                m.SetOverrideTag("RenderType", settings.renderType);
                m.SetInt("_SrcBlend", (int)settings.srcBlend);
                m.SetInt("_DstBlend", (int)settings.dstBlend);
                m.SetInt("_ZWrite", settings.zWrite ? 1 : 0);
            }
        }
    }

    enum ShadowsMode {
        Dither, Cutout
    }

    void AddShadowsMode () {
        ShadowsMode mode = ShadowsMode.Dither;
        if (target.IsKeywordEnabled("_CUTOUT_SHADOWS")) {
            mode = ShadowsMode.Cutout;
            showAlphaCutoff = true;
        }
        CheckShadowsMode(mode);
        EditorGUI.BeginChangeCheck();
        mode = (ShadowsMode) EditorGUILayout.EnumPopup(
            MakeLabel("Shadows Mode"), mode);
        if (EditorGUI.EndChangeCheck()) {
            RecordAction("Shadows Mode");
            CheckShadowsMode(mode);
        }
    }

    void AddAlphaCutoff () {
        MaterialProperty cutoff = GetProperty("_Cutoff");
        EditorGUI.indentLevel += 2;
        editor.ShaderProperty(cutoff, MakeLabel(cutoff));
        EditorGUI.indentLevel -= 2;
    }

    // Functions that draw each of the property sets. Also for convenience,
    // makes it easier to read each one when they're in separate blocks than
    // in a wall of text written on OnGUI().
    void AddAlbedo () {
        MaterialProperty color = GetProperty("_Color");
        MaterialProperty mainTex = GetProperty("_MainTex");
        editor.TexturePropertySingleLine(
            MakeLabel(color, "Albedo color and texture."), mainTex, color);
    }

    void AddTilingAndOffset () {
        MaterialProperty mainTex = GetProperty("_MainTex");
        editor.TextureScaleOffsetProperty(mainTex);
    }

    void AddSpecular () {
        MaterialProperty specColor = GetProperty("_SpecularColor");
        MaterialProperty specAmount = GetProperty("_SpecularAmount");
        MaterialProperty specTex = GetProperty("_SpecularTex");
        editor.TexturePropertySingleLine(
            MakeLabel("Specular Blob", "Specular color and amount. " +
            "RGB is color, A is amount. Set to black to turn off."),
            specTex, specColor, specAmount);
    }

    void AddFresnel () {
        MaterialProperty fresColor = GetProperty("_FresnelColor");
        MaterialProperty fresAmount = GetProperty("_FresnelAmount");
        MaterialProperty fresTex = GetProperty("_FresnelTex");
        editor.TexturePropertySingleLine(
            MakeLabel("Fresnel Effect", "Fresnel color and amount. " +
            "RGB is color, A is amount. Set to black to turn off."),
            fresTex, fresColor, fresAmount);
    }

    void AddReflections () {
        MaterialProperty reflectivity = GetProperty("_Reflectivity");
        MaterialProperty blurriness = GetProperty("_Blurriness");
        MaterialProperty reflMap = GetProperty("_ReflectionsMap");
        EditorGUI.BeginChangeCheck();
        editor.TexturePropertySingleLine(
            MakeLabel("Reflections", "Reflections map. R and first " +
            "slider are reflectivity, G and second are blurriness."),
            reflMap, reflectivity, blurriness);
        if (EditorGUI.EndChangeCheck()) {
            SetKeyword("_REFLECTIONS_ENABLED", reflectivity.floatValue > 0f);
        }
    }

    void AddOutline () {
        CheckOutline();
        MaterialProperty outlineThickness = GetProperty("_OutlineThickness");
        EditorGUI.BeginChangeCheck();
        editor.ShaderProperty(outlineThickness, MakeLabel(outlineThickness));
        if (EditorGUI.EndChangeCheck()) {
            CheckOutline();
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
                emission.colorValue != Color.black ||
                emissionMap.textureValue);
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
            MakeLabel(transmission, "Translucency map and value. " +
            "Don't forget to disable shadow casting on objects " +
            "with this property."), transmissionMap, transmission);
        if (EditorGUI.EndChangeCheck()) {
            bool enable = transmission.floatValue > 0f ||
                transmissionMap.textureValue;
            SetKeyword("_TRANSMISSION_ENABLED", enable);
        }
    }

    void AddRefraction () {
        MaterialProperty refraction = GetProperty("_RefractionScale");
        MaterialProperty refractionMap = GetProperty("_RefractionMap");
        editor.TexturePropertySingleLine(
            MakeLabel("Refraction", "Refraction map and scale. " +
            "Albedo's alpha controls transparency amount."),
            refractionMap, refraction);
    }

    // Last helper functions, to set up some keywords and passes when
    // the shader changes.
    void CheckShadowsMode (ShadowsMode mode) {
        SetKeyword("_DITHER_SHADOWS", mode == ShadowsMode.Dither);
        SetKeyword("_CUTOUT_SHADOWS", mode == ShadowsMode.Cutout);
    }

    void CheckOutline () {
        MaterialProperty outlineThickness = GetProperty("_OutlineThickness");
        if (target.shader.name != "CelShaded/Refraction") {
            target.SetShaderPassEnabled(
                "Always", outlineThickness.floatValue > 0f);
        }
        else {    // Deactivating all "Always" passes includes GrabPass.
            target.SetShaderPassEnabled("Always", true);
        }
    }
}
