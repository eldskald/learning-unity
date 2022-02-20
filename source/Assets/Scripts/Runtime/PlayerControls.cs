using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[RequireComponent(typeof(CharacterController))]
public class PlayerControls : MonoBehaviour {

    // Inpsector tags and public variables.
    [Header("Mouse Controls")]
    [Range(30f, 300f)] public float sensitivity = 150f;
    [Range(0f, 90f)] public float maxYAngle = 80f;
    [Range(0f, 90f)] public float minYAngle = 80f;

    [Header("Movement Controls")]
    [MinAttribute(0f)] public float speed = 0f;
    [MinAttribute(0f)] public float jumpHeight = 0f;
    [MinAttribute(0f)] public float gravity = 0f;

    // Private variables to assist the functions.
    private Camera _playerCam;
    private CharacterController _controller;
    private Vector3 _velocity;



    // Start and FixedUpdate functions that run the component.
    private void Start () {
        Cursor.lockState = CursorLockMode.Locked;
        _controller = GetComponent<CharacterController>();
        _playerCam = GetComponentInChildren<Camera>();
    }

    private void FixedUpdate () {

        // Deal with the camera and mouse controls.
        if (Cursor.lockState == CursorLockMode.Locked) {
            LookAround();
        }
        if (Input.GetMouseButtonDown(0)) {
            LockUnlockMouse();
        }

        // Deal with movement.
        _velocity = _controller.velocity;
        MoveAround();
        Gravity();
        Jumping();
        _controller.Move(_velocity * Time.fixedDeltaTime);
    }



    // Mouse controls methods.
    private void LockUnlockMouse () {
        if (Cursor.lockState == CursorLockMode.Locked) {
            Cursor.lockState = CursorLockMode.None;
        }
        else {
            Cursor.lockState = CursorLockMode.Locked;
        }
    }

    private void LookAround () {

        // Basic check and error logging first.
        if (_playerCam == null) {
            Debug.Log("Camera not found!");
            Debug.Log("Add a child with a Camera component to the player!");
            LockUnlockMouse();
            return;
        }

        // Look up and down.
        float rotY = _playerCam.transform.localEulerAngles.x;
        rotY -= rotY > 180 ? 360 : 0;
        rotY -= Input.GetAxis("Mouse Y") * sensitivity * Time.fixedDeltaTime;
        rotY = Mathf.Clamp(rotY, -minYAngle, maxYAngle);
        _playerCam.transform.localRotation = Quaternion.Euler(rotY, 0f, 0f);

        // Look left and right.
        float rotX = transform.eulerAngles.y;
        rotX += Input.GetAxis("Mouse X") * sensitivity * Time.fixedDeltaTime;
        transform.eulerAngles = new Vector3(0f, rotX, 0f);
    }



    // Movement controls methods.
    private void MoveAround () {
        Vector3 move = new Vector3(
            Input.GetAxisRaw("Horizontal"), 0f, Input.GetAxisRaw("Vertical"));
        move = move.normalized * speed;
        move = move.x * transform.right + move.z * transform.forward;

        _velocity.x = move.x;
        _velocity.z = move.z;
    }

    private void Gravity () {
        _velocity -= Vector3.up * gravity * Time.fixedDeltaTime;
    }

    private void Jumping () {
        if (_controller.isGrounded && Input.GetKeyDown(KeyCode.Space)) {
            _velocity.y = Mathf.Sqrt( 2f * jumpHeight * gravity);
        }
    }
}
