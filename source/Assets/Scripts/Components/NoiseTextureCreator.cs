using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class NoiseTextureCreator : MonoBehaviour {
    public int seed = 0;
    public Vector2Int resolution = new Vector2Int(128, 128);

    [Space(10)]
    public float scale = 1f;
    [Range(1, 9)]
    public int octaves = 4;
    [Range(0f, 1f)]
    public float persistance = 0.5f;
    [Range(0.1f, 4f)]
    public float lacunarity = 2f;
    [Range(1f, 8f)]
    public float power = 1.0f;
    public bool inverted = false;

    [Space(10)]
    public string filePath = "Resources/Textures/Noise/Noise0.png";
    public Texture2D noiseTexture;
}

