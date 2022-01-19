using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEditor;

public class ToonWaterGUI : ShaderGUI {

    private Material _target;
    private MaterialEditor _editor;
    private MaterialProperty[] _properties;

    public override void OnGUI (
        MaterialEditor editor, MaterialProperty[] properties
    ) {
        this._target = editor.target as Material;
        this._editor = editor;
        this._properties = properties;

        GUIHelper.GroupLabel("Main Properties");
        AddColor();
        AddReflectivity();
        AddAgitation();
        AddSpecularity();
        GUIHelper.LongSpace();

        GUIHelper.GroupLabel("Foam Properties");
        AddFoamColor();
        AddFoamSmoothness();
        AddFoamSize();
        AddFoamDisplacement();
        AddFoamNoiseTexture();
        GUIHelper.LongSpace();

        GUIHelper.GroupLabel("Normal Map Properties");
        AddNormalMap();
        AddPanningVelocities();
        GUIHelper.LongSpace();

        GUIHelper.GroupLabel("Additional Customization");
        AddNoDepthFog();
        AddFoamMode();
        AddFresnelEffect();
        AddPlanarReflections();
        GUIHelper.ShortSpace();
        AddTilingAndOffset();
    }

    // Main properties.
    void AddColor () {
        MaterialProperty prop = FindProperty("_Color", _properties);
        _editor.ShaderProperty(prop, GUIHelper.MakeLabel(prop));
    }

    void AddReflectivity () {
        MaterialProperty prop = FindProperty("_Reflectivity", _properties);
        _editor.ShaderProperty(prop, GUIHelper.MakeLabel(prop));
    }

    void AddAgitation () {
        MaterialProperty prop = FindProperty("_Agitation", _properties);
        _editor.ShaderProperty(prop, GUIHelper.MakeLabel(prop));
    }

    void AddSpecularity () {
        MaterialProperty prop = FindProperty("_Specularity", _properties);
        _editor.ShaderProperty(prop, GUIHelper.MakeLabel(prop));
    }

    void AddTilingAndOffset () {
        MaterialProperty prop = FindProperty("_MainTex", _properties);
        _editor.TextureScaleOffsetProperty(prop);
    }

    // Foam properties.
    void AddFoamColor () {
        MaterialProperty prop = FindProperty("_FoamColor", _properties);
        _editor.ShaderProperty(prop, GUIHelper.MakeLabel(prop));
    }

    void AddFoamSmoothness () {
        MaterialProperty prop = FindProperty("_FoamSmooth", _properties);
        _editor.ShaderProperty(prop, GUIHelper.MakeLabel(prop));
    }

    void AddFoamSize () {
        MaterialProperty prop = FindProperty("_FoamSize", _properties);
        _editor.ShaderProperty(prop, GUIHelper.MakeLabel(prop));
    }

    void AddFoamDisplacement () {
        MaterialProperty prop = FindProperty("_FoamDisplacement", _properties);
        _editor.ShaderProperty(prop, GUIHelper.MakeLabel(prop));
    }

    void AddFoamNoiseTexture () {
        MaterialProperty prop = FindProperty("_FoamNoiseTex", _properties);
        _editor.TexturePropertySingleLine(GUIHelper.MakeLabel(prop), prop);
    }

    // Normal map properties.
    void AddNormalMap () {
        MaterialProperty prop = FindProperty("_NormalMap", _properties);
        _editor.TexturePropertySingleLine(GUIHelper.MakeLabel(prop), prop);
    }

    void AddPanningVelocities () {
        MaterialProperty prop = FindProperty("_NormalPanVel", _properties);
        Vector2 velA = new Vector2(prop.vectorValue.x, prop.vectorValue.y);
        Vector2 velB = new Vector2(prop.vectorValue.z, prop.vectorValue.w);
        EditorGUI.BeginChangeCheck();
        velA = EditorGUILayout.Vector2Field("Panning Velocity A", velA);
        velB = EditorGUILayout.Vector2Field("Panning Velocity B", velB);
        if (EditorGUI.EndChangeCheck()) {
            _target.SetVector(
                "_NormalPanVel", new Vector4(velA.x, velA.y, velB.x, velB.y));
        }
    }

    void AddNoDepthFog () {
        MaterialProperty prop = FindProperty("_NoDepthFog", _properties);
        _editor.ShaderProperty(prop, GUIHelper.MakeLabel(prop));
    }

    void AddFoamMode () {
        MaterialProperty prop = FindProperty("_Foam", _properties);
        _editor.ShaderProperty(prop, GUIHelper.MakeLabel(prop));
    }

    void AddFresnelEffect () {
        MaterialProperty prop = FindProperty("_FresnelEffect", _properties);
        _editor.ShaderProperty(prop, GUIHelper.MakeLabel(prop));
    }

    void AddPlanarReflections () {
        MaterialProperty prop = FindProperty(
            "_PlanarReflections", _properties);
        _editor.ShaderProperty(prop, GUIHelper.MakeLabel(prop));
        if (_target.IsKeywordEnabled("_PLANAR_REFLECTIONS_ENABLED")) {
            prop = FindProperty("_PRID", _properties);
            _editor.ShaderProperty(prop, GUIHelper.MakeLabel(prop));
        }
    }
}
