using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class WindSwayMPB : MonoBehaviour {
    
    public Vector3 wind;
    [MinAttribute(0.01f)] public float resistance = 10.0f;
    [MinAttribute(0.01f)] public float interval = 3.5f;
    public float heightOffset = 0.0f;
    public Texture swayCurve;
    public float swayIntensity = 1.0f;
    public float swayFrequency = 1.0f;

    private MaterialPropertyBlock _mpb;

    void OnValidate () {
        if (_mpb == null) {
            _mpb = new MaterialPropertyBlock();
        }

        _mpb.SetVector("_Wind", new Vector4(wind.x, wind.y, wind.z, 1f));
        _mpb.SetFloat("_Resistance", resistance);
        _mpb.SetFloat("_Interval", interval);
        _mpb.SetFloat("_HeightOffset", heightOffset);
        _mpb.SetTexture("_VarCurve", swayCurve);
        _mpb.SetFloat("_VarIntensity", swayIntensity);
        _mpb.SetFloat("_VarFrequency", swayFrequency);

        MeshRenderer[] meshRenderers = GetComponentsInChildren<MeshRenderer>();
        foreach (MeshRenderer renderer in meshRenderers) {
            renderer.SetPropertyBlock(_mpb);
        }
    }


}
