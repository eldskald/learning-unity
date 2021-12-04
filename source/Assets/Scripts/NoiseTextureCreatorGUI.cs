using System.Collections;
using System.Collections.Generic;
using System.IO;
using UnityEngine;
using UnityEditor;
using OpenSimplexNoise;

[CustomEditor (typeof(NoiseTextureCreator))]
public class NoiseTextureCreatorGUI : Editor {

    Texture2D UpdateTexture (NoiseTextureCreator creator) {
        OpenSimplex2S noiseGen = new OpenSimplex2S(creator.seed);

        // We start the code by filling a 2D array with the sample values
        // stored in each pixel. We do this because we need all the values
        // first in order to normalize them, making the lowest pixel black
        // and the highest pixel white.
        float[,] sampleValues = new float[
            creator.resolution.x, creator.resolution.y];
        float maxValue = 0.0f;
        float minValue = 10.0f;

        for (int i = 0; i < creator.resolution.x; i++) {
            for (int j = 0; j < creator.resolution.y; j++) {
                float sample = 0.0f;
                float amplitude = 1.0f;
                float frequency = 1.0f;

                for (int k = 0; k < creator.octaves; k++) {
                    float iAngle = i * 2.0f * Mathf.PI / creator.resolution.x;
                    float jAngle = j * 2.0f * Mathf.PI / creator.resolution.y;
                    double nx = creator.scale * Mathf.Sin(iAngle) / frequency;
                    double ny = creator.scale * Mathf.Cos(iAngle) / frequency;
                    double nz = creator.scale * Mathf.Sin(jAngle) / frequency;
                    double nw = creator.scale * Mathf.Cos(jAngle) / frequency;
                    double noise = noiseGen.Noise4D(nx, ny, nz, nw);
                    sample += (float)noise * amplitude;

                    amplitude *= creator.persistance;
                    frequency *= creator.lacunarity;
                }

                if (sample > maxValue) {
                    maxValue = sample;
                }
                if (sample < minValue) {
                    minValue = sample;
                }
                sampleValues[i, j] = sample;
            }
        }

        // After filling ou the 2D array and capturing its minimum and maximum
        // values, we can fill out the final texture to be returned.
        Texture2D tex = new Texture2D(
            creator.resolution.x, creator.resolution.y);
        tex.wrapMode = TextureWrapMode.Repeat;

        for (int i = 0; i < creator.resolution.x; i++) {
            for (int j = 0; j < creator.resolution.y; j++) {
                float value = Mathf.InverseLerp(
                    minValue, maxValue, sampleValues[i, j]);
                tex.SetPixel(i, j, new Color(value, value, value, 1.0f));
            }
        }

        tex.Apply();
        return tex;
    }

    public override void OnInspectorGUI () {
        NoiseTextureCreator creator = target as NoiseTextureCreator;

        GUILayout.Label("Noise Texture Creator", EditorStyles.boldLabel);
        GUILayout.Space(16);
        DrawDefaultInspector();
        GUILayout.Space(16);

        if (GUILayout.Button("Save")) {
            Texture2D tex = UpdateTexture(creator);
            byte[] data = tex.EncodeToPNG();
            File.WriteAllBytes(string.Format("{0}/{1}",
                Application.dataPath, creator.filePath), data);
        }
    }
}
