using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;

public class CelShaderGUI : ShaderGUI {

    private Material target;
    private MaterialEditor editor;
    private MaterialProperty[] properties;

    public override void OnGUI (MaterialEditor editor, MaterialProperty[] properties) {
        this.target = editor.target as Material;
        this.editor = editor;
        this.properties = properties;

        // Main properties of the material. These are albedo, diffuse smoothness,
        // specular highlight, rim highlight, reflections and outline.
        // I'm commenting out all of the smoothnesses because I don't want to set
        // them on a per material basis, I'd rather change the base value on the
        // shader code and change the values on all materials.
        GroupLabel("Main Properties", false);
        
        // Diffuse smoothness.
        // MaterialProperty diffuseSmooth = GetProperty("_DiffuseSmooth");
        // editor.ShaderProperty(
        //     diffuseSmooth, MakeLabel(diffuseSmooth, "Lit area's edge sharpness."));
        // GUILayout.Space(8);

        MaterialProperty color = GetProperty("_Color"); // Albedo.
        MaterialProperty mainTex = GetProperty("_MainTex");
        editor.TexturePropertySingleLine(
            MakeLabel(color, "Albedo color and texture. Tiles and offsets all other " +
            "textures unless otherwise noted."), mainTex, color);
        editor.TextureScaleOffsetProperty(mainTex);

        GUILayout.Space(8); // Specular highlight
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

        GUILayout.Space(8); // Rim highlight
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
        
        GUILayout.Space(8); // Reflections.
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

        GUILayout.Space(8); // Outline.
        MaterialProperty outlineThickness = GetProperty("_OutlineThickness");
        EditorGUI.BeginChangeCheck();
        editor.ShaderProperty(outlineThickness, MakeLabel(outlineThickness));
        if (EditorGUI.EndChangeCheck()) {
            target.SetShaderPassEnabled("Always", outlineThickness.floatValue > 0f);
        }
        MaterialProperty outlineColor = GetProperty("_OutlineColor");
        editor.ShaderProperty(outlineColor, MakeLabel(outlineColor));

        GroupLabel("Additional Maps");
        
        // Emission.
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

        // Normal map.
        MaterialProperty bumpScale = GetProperty("_BumpScale");
        MaterialProperty bumpMap = GetProperty("_BumpMap");
        EditorGUI.BeginChangeCheck();
        editor.TexturePropertySingleLine(
            MakeLabel(bumpMap, "Normal map and scale."),
            bumpMap, bumpScale);
        if (EditorGUI.EndChangeCheck()) {
            SetKeyword("_BUMPMAP_ENABLED", bumpMap.textureValue);
        }

        // Occlusion map.
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

    void GroupLabel (string label, bool addSpace = true) {
        if (addSpace) {
            GUILayout.Space(32);
        }
        GUILayout.Label(label, EditorStyles.boldLabel);
    }
}