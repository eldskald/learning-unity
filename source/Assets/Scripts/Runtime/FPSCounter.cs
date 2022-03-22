using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

public class FPSCounter : MonoBehaviour {

    [MinAttribute(0f)] public float updateTime = 0.5f;

    private Text _text;
    private float _time;
    private float _totalFrames;
    private float _frameCounter;

    void Start () {
        _text = GetComponent<Text>();
        _time = 0f;
    }

    void Update () {
        _time += Time.deltaTime;
        _totalFrames += Time.unscaledDeltaTime;
        _frameCounter += 1f;
        if (_time >= updateTime) {
            int fps = (int)(_frameCounter / _totalFrames);
            fps = Mathf.Clamp(fps, 0, 999);
            _text.text = "FPS: " + fps.ToString();
            _time = 0f;
            _totalFrames = 0f;
            _frameCounter = 0f;
        }

        if (Input.GetKeyDown(KeyCode.H)) {
            Canvas counter = GetComponentInParent<Canvas>();
            counter.enabled = !counter.enabled;
        }
    }
}
