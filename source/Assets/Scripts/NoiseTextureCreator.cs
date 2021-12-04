using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class NoiseTextureCreator : MonoBehaviour {
    public Vector2Int resolution = new Vector2Int(128, 128);
    public float scale = 1.0f;
    public int seed = 0;

    [Range(1, 9)]
    public int octaves = 4;

    [Range(0.0f, 1.0f)]
    public float persistance = 0.5f;

    [Range(0.1f, 4.0f)]
    public float lacunarity = 2.0f;

    public string filePath = "Resources/Textures/Noise/Noise0.png";
}

