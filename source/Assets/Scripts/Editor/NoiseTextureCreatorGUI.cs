using System.Collections;
using System.Collections.Generic;
using System.IO;
using UnityEngine;
using UnityEditor;
using OpenSimplexNoise;

[CustomEditor (typeof(NoiseTextureCreator))]
public class NoiseTextureCreatorGUI : Editor {

    Texture2D UpdateTexture (NoiseTextureCreator creator) {

        // First, we use the seed given by the user to generate the seeds
        // for each octave. We use another open simplex in order for the
        // same seeds to generate the same textures every time.
        System.Random pseudoRNG = new System.Random(creator.seed);
        OpenSimplex2S[] noiseGen = new OpenSimplex2S[creator.octaves];
        for (int i = 0; i < creator.octaves; i++) {
            noiseGen[i] = new OpenSimplex2S(pseudoRNG.Next(-100000, 100000));
        }

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
                    double noise = noiseGen[k].Noise4D(nx, ny, nz, nw);
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

                // This math is to apply power.
                if (value < 0.5f) {
                    value = creator.power * Mathf.Pow(value, creator.power);
                }
                else {
                    value = 1f - creator.power * Mathf.Pow(
                        1f - value, creator.power);
                }

                // This is in case inverted is toggled.
                value = creator.inverted ? 1f - value : value;

                tex.SetPixel(i, j, new Color(value, value, value, 1.0f));
            }
        }

        tex.Apply();
        return tex;
    }

    public override void OnInspectorGUI () {
        NoiseTextureCreator creator = target as NoiseTextureCreator;

        GUILayout.Label("Noise Texture Creator", EditorStyles.boldLabel);

        if (!creator.noiseTexture) {
            creator.noiseTexture = UpdateTexture(creator);
        }
        EditorGUI.DrawPreviewTexture(
            new Rect(16, 32, 192, 192), creator.noiseTexture);
        GUILayout.Space(224);

        EditorGUI.BeginChangeCheck();
        creator.seed = EditorGUILayout.IntField(
            "Seed", creator.seed);
        creator.resolution = EditorGUILayout.Vector2IntField(
            "Resolution", creator.resolution);
        creator.filePath = EditorGUILayout.TextField(
            "File Path", creator.filePath);

        GUIHelper.LongSpace();

        creator.scale = EditorGUILayout.FloatField(
            "Scale", creator.scale);
        creator.octaves = EditorGUILayout.IntSlider(
            "Octaves", creator.octaves, 1, 9);
        creator.persistance = EditorGUILayout.Slider(
            "Persistance", creator.persistance, 0, 1);
        creator.lacunarity = EditorGUILayout.Slider(
            "Lacunarity", creator.lacunarity, 0.1f, 4.0f);
        creator.power = EditorGUILayout.Slider(
            "Power", creator.power, 1f, 4f);
        creator.inverted = EditorGUILayout.Toggle(
            "Inverted", creator.inverted);
        if (EditorGUI.EndChangeCheck()) {
            creator.noiseTexture = UpdateTexture(creator);
        }

        
        GUILayout.Space(32);

        if (GUILayout.Button("Save Texture")) {
            byte[] data = creator.noiseTexture.EncodeToPNG();
            File.WriteAllBytes(string.Format("{0}/{1}",
                Application.dataPath, creator.filePath), data);
        }
    }
}
