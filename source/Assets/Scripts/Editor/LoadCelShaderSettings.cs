using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;

public class LoadCelShaderSettings {

    [InitializeOnLoadMethod]
    static void Manager () {

        // We delay it a bit so that when you launch Unity, the editor has
        // enough time to do the imports before running so it can load the
        // texture, otherwise it fails to do so on launch.
        if (!UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode) {
            UnityEditor.EditorApplication.delayCall +=
                CelShaderSettings.LoadSettings;
        }
        else {
            CelShaderSettings.LoadSettings();
        }
    }
}
