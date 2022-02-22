using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

public class FPSCounter : MonoBehaviour {

    [MinAttribute(0f)] public float updateTime = 0.5f;

    private Text _text;
    private float _time;

    void Start () {
        _text = GetComponent<Text>();
        _time = 0f;
    }

    void Update () {
        _time += Time.deltaTime;
        if (_time >= updateTime) {
            _time = 0f;
            int fps = (int)(1f / Time.unscaledDeltaTime);
            fps = Mathf.Clamp(fps, 0, 999);
            _text.text = "FPS: " + fps.ToString();
        }
    }
}
