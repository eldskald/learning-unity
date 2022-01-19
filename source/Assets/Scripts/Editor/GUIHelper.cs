using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEditor;

public static class GUIHelper {
    
    // Short functions for making GUIContent instances.
    public static GUIContent staticLabel = new GUIContent();

    public static GUIContent MakeLabel (string text, string tooltip = null) {
        staticLabel.text = text;
        staticLabel.tooltip = tooltip;
        return staticLabel;
    }

    public static GUIContent MakeLabel (
        MaterialProperty property, string tooltip = null
    ) {
        staticLabel.text = property.displayName;
        staticLabel.tooltip = tooltip;
        return staticLabel;
    }

    public static void GroupLabel (string label) {
        GUILayout.Label(label, EditorStyles.boldLabel);
    }

    public static void ShortSpace () {
        GUILayout.Space(8);
    }

    public static void LongSpace () {
        GUILayout.Space(16);
    }

}
