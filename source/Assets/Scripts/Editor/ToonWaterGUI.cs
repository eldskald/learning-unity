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
        AddFoamNoiseTilings();
        GUIHelper.LongSpace();

        GUIHelper.GroupLabel("Normal Map Properties");
        AddNormalMap();
        AddHeightMap();
        AddSurfacePanning();
        AddSurfaceTilings();
        GUIHelper.LongSpace();

        GUIHelper.GroupLabel("Additional Customization");
        AddNoDepthFog();
        AddFoamMode();
        AddFresnelEffect();
        AddPlanarReflections();
        AddUVEdgeFoam();
    }

    // Main properties.
    private void AddColor () {
        MaterialProperty prop = FindProperty("_Color", _properties);
        _editor.ShaderProperty(prop, GUIHelper.MakeLabel(prop));
    }

    private void AddReflectivity () {
        MaterialProperty prop = FindProperty("_Reflectivity", _properties);
        _editor.ShaderProperty(prop, GUIHelper.MakeLabel(prop));
    }

    private void AddAgitation () {
        MaterialProperty prop = FindProperty("_Agitation", _properties);
        _editor.ShaderProperty(prop, GUIHelper.MakeLabel(prop));
    }

    private void AddSpecularity () {
        MaterialProperty prop = FindProperty("_Specularity", _properties);
        _editor.ShaderProperty(prop, GUIHelper.MakeLabel(prop));
    }

    private void AddTilingAndOffset () {
        MaterialProperty prop = FindProperty("_MainTex", _properties);
        _editor.TextureScaleOffsetProperty(prop);
    }

    // Foam properties.
    private void AddFoamColor () {
        MaterialProperty prop = FindProperty("_FoamColor", _properties);
        _editor.ShaderProperty(prop, GUIHelper.MakeLabel(prop));
    }

    private void AddFoamSmoothness () {
        MaterialProperty prop = FindProperty("_FoamSmooth", _properties);
        _editor.ShaderProperty(prop, GUIHelper.MakeLabel(prop));
    }

    private void AddFoamSize () {
        MaterialProperty prop = FindProperty("_FoamSize", _properties);
        _editor.ShaderProperty(prop, GUIHelper.MakeLabel(prop));
    }

    private void AddFoamDisplacement () {
        MaterialProperty prop = FindProperty("_FoamDisplacement", _properties);
        _editor.ShaderProperty(prop, GUIHelper.MakeLabel(prop));
    }

    private void AddFoamNoiseTexture () {
        MaterialProperty prop = FindProperty("_FoamNoiseTex", _properties);
        _editor.TexturePropertySingleLine(GUIHelper.MakeLabel(prop), prop);
    }

    private void AddFoamNoiseTilings () {
        MaterialProperty prop = FindProperty("_FoamNoiseTilings", _properties);
        Vector2 vec = new Vector2(prop.vectorValue.x, prop.vectorValue.y);
        EditorGUI.BeginChangeCheck();
        vec = EditorGUILayout.Vector2Field("Noise Tiling", vec);
        if (EditorGUI.EndChangeCheck()) {
            _target.SetVector(
                "_FoamNoiseTilings", new Vector4(vec.x, vec.y, 0f, 0f));
        }
    }

    // Normal map properties.
    private void AddNormalMap () {
        MaterialProperty prop = FindProperty("_NormalMap", _properties);
        _editor.TexturePropertySingleLine(GUIHelper.MakeLabel(prop), prop);
    }

    private void AddHeightMap () {
        MaterialProperty prop = FindProperty("_HeightMap", _properties);
        _editor.TexturePropertySingleLine(GUIHelper.MakeLabel(prop), prop);
    }

    private void AddSurfacePanning () {
        MaterialProperty prop = FindProperty("_SurfPanVel", _properties);
        Vector2 velA = new Vector2(prop.vectorValue.x, prop.vectorValue.y);
        Vector2 velB = new Vector2(prop.vectorValue.z, prop.vectorValue.w);
        EditorGUI.BeginChangeCheck();
        velA = EditorGUILayout.Vector2Field("Panning Velocity A", velA);
        velB = EditorGUILayout.Vector2Field("Panning Velocity B", velB);
        if (EditorGUI.EndChangeCheck()) {
            _target.SetVector(
                "_SurfPanVel", new Vector4(velA.x, velA.y, velB.x, velB.y));
        }
    }

    private void AddSurfaceTilings () {
        MaterialProperty prop = FindProperty("_SurfTilings", _properties);
        Vector2 vecA = new Vector2(prop.vectorValue.x, prop.vectorValue.y);
        Vector2 vecB = new Vector2(prop.vectorValue.z, prop.vectorValue.w);
        EditorGUI.BeginChangeCheck();
        vecA = EditorGUILayout.Vector2Field("Normal Tiling A", vecA);
        vecB = EditorGUILayout.Vector2Field("Normal Tiling B", vecB);
        if (EditorGUI.EndChangeCheck()) {
            _target.SetVector(
                "_SurfTilings", new Vector4(vecA.x, vecA.y, vecB.x, vecB.y));
        }
    }

    // Additional properties.
    private void AddNoDepthFog () {
        MaterialProperty prop = FindProperty("_NoDepthFog", _properties);
        _editor.ShaderProperty(prop, GUIHelper.MakeLabel(prop));
    }

    private void AddFoamMode () {
        MaterialProperty prop = FindProperty("_Foam", _properties);
        _editor.ShaderProperty(prop, GUIHelper.MakeLabel(prop));
    }

    private void AddFresnelEffect () {
        MaterialProperty prop = FindProperty("_FresnelEffect", _properties);
        _editor.ShaderProperty(prop, GUIHelper.MakeLabel(prop));
    }

    private void AddPlanarReflections () {
        MaterialProperty prop = FindProperty(
            "_PlanarReflections", _properties);
        _editor.ShaderProperty(prop, GUIHelper.MakeLabel(prop));
        if (_target.IsKeywordEnabled("_PLANAR_REFLECTIONS_ENABLED")) {
            prop = FindProperty("_PRID", _properties);
            _editor.ShaderProperty(prop, GUIHelper.MakeLabel(prop));
        }
    }
    
    private void AddUVEdgeFoam () {
        MaterialProperty prop = FindProperty("_UVEdgeFoam", _properties);
        _editor.ShaderProperty(prop, GUIHelper.MakeLabel(prop));
        if (_target.IsKeywordEnabled("_UV_EDGE_FOAM_ENABLED")) {
            prop = FindProperty("_UVEdgeSizes", _properties);
            Vector2 lr = new Vector2(prop.vectorValue.x, prop.vectorValue.y);
            Vector2 tb = new Vector2(prop.vectorValue.z, prop.vectorValue.w);
            EditorGUI.BeginChangeCheck();
            lr = EditorGUILayout.Vector2Field("Left/Right", lr);
            tb = EditorGUILayout.Vector2Field("Top/Bottom", tb);
            if (EditorGUI.EndChangeCheck()) {
                _target.SetVector(
                    "_UVEdgeSizes", new Vector4(lr.x, lr.y, tb.x, tb.y));
            }
        }
    }
}
