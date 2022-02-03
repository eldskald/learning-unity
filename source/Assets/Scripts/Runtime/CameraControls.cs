using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class CameraControls : MonoBehaviour {
    
    [Range(0f, 1f)] public float sensitivity = 0.5f;
    [Range(0.1f, 10f)] public float speed = 2f;

    private void Start () {
        Cursor.lockState = CursorLockMode.Locked;
    }

    private void Update () {
        if (Cursor.lockState == CursorLockMode.Locked) {
            LookAround();
        }
        
        if (Input.GetMouseButtonDown(0)) {
            CatchOrReleaseMouse();
        }

        if (Input.GetKeyDown(KeyCode.Escape)) {
            Screen.fullScreen = !Screen.fullScreen;
        }

        MoveAround();
    }

    private void CatchOrReleaseMouse () {
        if (Cursor.lockState == CursorLockMode.Locked) {
            Cursor.lockState = CursorLockMode.None;
        }
        else {
            Cursor.lockState = CursorLockMode.Locked;
        }
    }

    private void LookAround () {
        float rotX = transform.eulerAngles.y;
        float rotY = transform.eulerAngles.x;
        if (rotY > 180) {
            rotY -= 360;
        }
        rotX += Input.GetAxis("Mouse X") * (1f + sensitivity * 9f);
        rotY -= Input.GetAxis("Mouse Y") * (1f + sensitivity * 9f);
        rotY = Mathf.Clamp(rotY, -80f, 80f);
        transform.eulerAngles = new Vector3(rotY, rotX, 0f);
    }

    private void MoveAround () {
        Vector3 forward = new Vector3(
            transform.forward.x, 0f, transform.forward.z);
        Vector3 right = new Vector3(transform.right.x, 0f, transform.right.z);
        Vector3.OrthoNormalize(ref forward, ref right);

        Vector2 dirInput = new Vector2(
            Input.GetAxis("Horizontal"), Input.GetAxis("Vertical"));
        transform.position += 0.01f * speed * forward * dirInput.normalized.y;
        transform.position += 0.01f * speed * right * dirInput.normalized.x;
    }
}
