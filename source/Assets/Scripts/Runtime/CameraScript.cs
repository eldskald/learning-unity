using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class CameraScript : MonoBehaviour {

    private int cameraMode;
    private Camera cam;

    void Start () {
        cam = GetComponent<Camera>();
        cameraMode = 0;
        RecalcNearClipPlane();
    }

    void Update () {
        if (Input.GetButtonDown("Submit")) {
            cameraMode = (cameraMode + 1) % 5;
            RecalcNearClipPlane();
        }
    }

    // IT WOOOOOOOOOOOOOOOOOOORKS!!!!!!! IT WOOOOOOOOOOORKS!!!!
    void RecalcNearClipPlane () {
        Vector3 normal = Vector3.forward;
        Vector3 point = new Vector3(0f, 0f, 0f);

        Matrix4x4 viewMatrix = cam.worldToCameraMatrix;
        normal = viewMatrix.MultiplyVector(normal).normalized;
        point = viewMatrix.MultiplyPoint(point);
        Vector4 plane = new Vector4(
            normal.x,
            normal.y,
            normal.z,
            -Vector3.Dot(normal, point));
        cam.projectionMatrix = cam.CalculateObliqueMatrix(plane);
    }
}
