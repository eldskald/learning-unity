using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEditor;

public class CelShaderGUI : ShaderGUI {

    private Material _target;
    private MaterialEditor _editor;
    private MaterialProperty[] _properties;

    public override void OnGUI (
        MaterialEditor editor, MaterialProperty[] properties
    ) {
        this._target = editor.target as Material;
        this._editor = editor;
        this._properties = properties;

        AddRenderMode();
        if (_showShadowsMode) {
            AddShadowsMode();
        }
        if (_showAlphaCutoff) {
            AddAlphaCutoff();
        }
        if (_showShadowStrength) {
            AddShadowStrength();
        }
        GUIHelper.LongSpace();

        GUIHelper.GroupLabel("Main Properties");
        AddAlbedo();
        AddSpecular();
        AddFresnel();
        AddReflections();
        GUIHelper.ShortSpace();
        AddOutline();
        GUIHelper.LongSpace();
        
        GUIHelper.GroupLabel("Additional Maps");
        AddEmission();
        AddNormalMap();
        AddHeightMap();
        AddOcclusion();
        AddAnisotropy();
        AddTransmission();
        GUIHelper.ShortSpace();
        AddTilingAndOffset();
    }

    // Helper functions for convenience of writing and reading.
    MaterialProperty GetProperty (string name) {
        return FindProperty(name, _properties);
    }

    void SetKeyword (string keyword, bool enable) {
        if (enable) {
            _target.EnableKeyword(keyword);
        }
        else {
            _target.DisableKeyword(keyword);
        }
    }

    void RecordAction (string label) {
        _editor.RegisterPropertyChangeUndo(label);
    }

    // Stuff that deal and draws rendering settings of the material.
    private bool _showAlphaCutoff;
    private bool _showShadowStrength;
    private bool _showShadowsMode;

    enum RenderMode {
        Opaque, Cutout, Fade, Transparent
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
            }
        };
    }

    void AddRenderMode () {
        RenderMode mode = RenderMode.Opaque;
        _showAlphaCutoff = false;
        _showShadowStrength = false;
        _showShadowsMode = true;
        if (_target.shader == Shader.Find("CelShaded/Opaque")) {
            mode = RenderMode.Opaque;
            _showShadowsMode = false;
        }
        else if (_target.IsKeywordEnabled("_RENDERING_CUTOUT")) {
            mode = RenderMode.Cutout;
            _showAlphaCutoff = true;
        }
        else if (_target.IsKeywordEnabled("_RENDERING_FADE")) {
            mode = RenderMode.Fade;
        }
        else if (_target.IsKeywordEnabled("_RENDERING_TRANSPARENT")) {
            mode = RenderMode.Transparent;
        }
        EditorGUI.BeginChangeCheck();
        mode = (RenderMode) EditorGUILayout.EnumPopup(
            GUIHelper.MakeLabel("Rendering Mode"), mode);
        if (EditorGUI.EndChangeCheck()) {
            RecordAction("Rendering Mode");
            SetKeyword("_RENDERING_CUTOUT", mode == RenderMode.Cutout);
            SetKeyword("_RENDERING_FADE", mode == RenderMode.Fade);
            SetKeyword("_RENDERING_TRANSPARENT",
                mode == RenderMode.Transparent);
            RenderSettings settings = RenderSettings.modes[(int)mode];
            foreach (Material m in _editor.targets) {
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
        _showShadowStrength = true;
        if (_target.IsKeywordEnabled("_CUTOUT_SHADOWS")) {
            mode = ShadowsMode.Cutout;
            _showAlphaCutoff = true;
            _showShadowStrength = false;
        }
        CheckShadowsMode(mode);
        EditorGUI.BeginChangeCheck();
        mode = (ShadowsMode) EditorGUILayout.EnumPopup(
            GUIHelper.MakeLabel("Shadows Mode"), mode);
        if (EditorGUI.EndChangeCheck()) {
            RecordAction("Shadows Mode");
            CheckShadowsMode(mode);
        }
    }

    void AddAlphaCutoff () {
        MaterialProperty cutoff = GetProperty("_Cutoff");
        EditorGUI.indentLevel += 2;
        _editor.ShaderProperty(cutoff, GUIHelper.MakeLabel(cutoff));
        EditorGUI.indentLevel -= 2;
    }

    void AddShadowStrength () {
        MaterialProperty shadowStr = GetProperty("_ShadowStrength");
        EditorGUI.indentLevel += 2;
        _editor.ShaderProperty(shadowStr, GUIHelper.MakeLabel(shadowStr));
        EditorGUI.indentLevel -= 2;
    }

    // Functions that draw each of the property sets. Also for convenience,
    // makes it easier to read each one when they're in separate blocks than
    // in a wall of text written on OnGUI().
    void AddAlbedo () {
        MaterialProperty color = GetProperty("_Color");
        MaterialProperty mainTex = GetProperty("_MainTex");
        _editor.TexturePropertySingleLine(
            GUIHelper.MakeLabel(color, "Albedo color and texture."),
            mainTex, color);
    }

    void AddTilingAndOffset () {
        MaterialProperty mainTex = GetProperty("_MainTex");
        _editor.TextureScaleOffsetProperty(mainTex);
    }

    void AddSpecular () {
        MaterialProperty specColor = GetProperty("_SpecularColor");
        MaterialProperty specAmount = GetProperty("_SpecularAmount");
        MaterialProperty specTex = GetProperty("_SpecularTex");
        _editor.TexturePropertySingleLine(
            GUIHelper.MakeLabel(
                "Specular Blob", "Specular color and amount. " +
                "RGB is color, A is amount. Set to black to turn off."),
            specTex, specColor, specAmount);
    }

    void AddFresnel () {
        MaterialProperty fresColor = GetProperty("_FresnelColor");
        MaterialProperty fresAmount = GetProperty("_FresnelAmount");
        MaterialProperty fresTex = GetProperty("_FresnelTex");
        _editor.TexturePropertySingleLine(
            GUIHelper.MakeLabel(
                "Fresnel Effect", "Fresnel color and amount. " +
                "RGB is color, A is amount. Set to black to turn off."),
            fresTex, fresColor, fresAmount);
    }

    void AddReflections () {
        MaterialProperty reflectivity = GetProperty("_Reflectivity");
        MaterialProperty blurriness = GetProperty("_Blurriness");
        MaterialProperty reflMap = GetProperty("_ReflectionsMap");
        EditorGUI.BeginChangeCheck();
        _editor.TexturePropertySingleLine(
            GUIHelper.MakeLabel(
                "Reflections", "Reflections map. R and first " +
                "slider are reflectivity, G and second are blurriness."),
            reflMap, reflectivity, blurriness);
        if (EditorGUI.EndChangeCheck()) {
            SetKeyword("_REFLECTIONS_ENABLED", reflectivity.floatValue > 0f);
        }
    }

    void AddOutline () {
        MaterialProperty toggleValue = GetProperty("_OutlineDisable");
        bool toggle = toggleValue.floatValue == 1f;
        toggle = EditorGUILayout.ToggleLeft(
            GUIHelper.MakeLabel(toggleValue), toggle);
        _target.SetFloat("_OutlineDisable", toggle ? 1f : 0f);
        _target.SetShaderPassEnabled("Always", !toggle);
    }

    void AddEmission () {
        MaterialProperty emission = GetProperty("_Emission");
        MaterialProperty emissionMap = GetProperty("_EmissionMap");
        EditorGUI.BeginChangeCheck();
        _editor.TexturePropertySingleLine(
            GUIHelper.MakeLabel(emission, "Emission map and color."),
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
        _editor.TexturePropertySingleLine(
            GUIHelper.MakeLabel(bumpMap, "Normal map and scale."),
            bumpMap, bumpScale);
        if (EditorGUI.EndChangeCheck()) {
            SetKeyword("_BUMPMAP_ENABLED", bumpMap.textureValue);
        }
    }

    void AddHeightMap () {
        MaterialProperty parallaxScale = GetProperty("_ParallaxScale");
        MaterialProperty parallaxMap = GetProperty("_ParallaxMap");
        EditorGUI.BeginChangeCheck();
        _editor.TexturePropertySingleLine(
            GUIHelper.MakeLabel(parallaxMap, "Height map and scale."),
            parallaxMap, parallaxScale);
        if (EditorGUI.EndChangeCheck()) {
            SetKeyword("_PARALLAX_ENABLED", parallaxMap.textureValue);
        }
    }

    void AddOcclusion () {
        MaterialProperty occlusionScale = GetProperty("_OcclusionScale");
        MaterialProperty occlusionMap = GetProperty("_OcclusionMap");
        EditorGUI.BeginChangeCheck();
        _editor.TexturePropertySingleLine(
            GUIHelper.MakeLabel(occlusionMap, "Occlusion map and scale."),
            occlusionMap, occlusionScale);
        if (EditorGUI.EndChangeCheck()) {
            SetKeyword("_OCCLUSION_ENABLED", occlusionMap.textureValue);
        }
    }

    void AddAnisotropy () {
        MaterialProperty anisoScale = GetProperty("_AnisoScale");
        MaterialProperty anisoFlowchart = GetProperty("_AnisoFlowchart");
        EditorGUI.BeginChangeCheck();
        _editor.TexturePropertySingleLine(
            GUIHelper.MakeLabel(
                anisoFlowchart, "Anisotropic flowchart and scale."),
            anisoFlowchart, anisoScale);
        if (EditorGUI.EndChangeCheck()) {
            SetKeyword("_ANISOTROPY_ENABLED", anisoFlowchart.textureValue);
        }
    }

    void AddTransmission () {
        MaterialProperty transmission = GetProperty("_Transmission");
        MaterialProperty transmissionMap = GetProperty("_TransmissionMap");
        EditorGUI.BeginChangeCheck();
        _editor.TexturePropertySingleLine(
            GUIHelper.MakeLabel(
                transmission, "Translucency map and value. " +
                "Don't forget to disable shadow casting on objects " +
                "with this property."),
            transmissionMap, transmission);
        if (EditorGUI.EndChangeCheck()) {
            bool enable = transmission.floatValue > 0f ||
                transmissionMap.textureValue;
            SetKeyword("_TRANSMISSION_ENABLED", enable);
        }
    }

    // Last helper functions, to set up some keywords and passes when
    // the shader changes.
    void CheckShadowsMode (ShadowsMode mode) {
        SetKeyword("_DITHER_SHADOWS", mode == ShadowsMode.Dither);
        SetKeyword("_CUTOUT_SHADOWS", mode == ShadowsMode.Cutout);
    }
}
