using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class WindSwayMPB : MonoBehaviour {
    
    public Vector3 wind;
    [MinAttribute(0.01f)] public float resistance;
    [MinAttribute(0.01f)] public float interval;
    public float heightOffset;
    public Texture swayCurve;
    public float swayIntensity;
    public float swayFrequency;

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
