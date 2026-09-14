# CameraRig — third-person orbit camera (child of the player).
#
# Inputs (same actions/axes for every device, ADR-021):
# - touch: TouchCameraZone forwards drag deltas -> rotate();
# - gamepad: right stick (analog) + camera_* d-pad actions (fine tune);
# - mouse: MMB drag (RMB is reserved for ranged_attack — no conflict).
#
# The pure math (offset/FOV/input mapping) is exposed as plain functions so
# it is unit-testable headless (no physics/render needed).
class_name CameraRig
extends Node3D

const BASE_FOV: float = 60.0
const HEAD_HEIGHT: float = 1.4
# JoyAxis enum members are not registered in the headless wasm rig
# (ADR-022): use the raw axis indices (2 = right X, 3 = right Y).
const AXIS_RIGHT_X: int = 2
const AXIS_RIGHT_Y: int = 3
const MIN_DIST: float = 0.75
const MOUSE_SENS: float = 0.0024
const STICK_TURN_SPEED: float = 2.6  # rad/s at full deflection
const STICK_DEADZONE: float = 0.2
const DPAD_TURN_SPEED: float = 1.6  # rad/s
const SMOOTHING: float = 10.0  # 1/s

@export var base_distance: float = 4.5
@export var pitch_min: float = -0.6
@export var pitch_max: float = 0.42

var yaw: float = 0.0
var pitch: float = 0.0

var _cam: Camera3D
var _ray: RayCast3D
var _initialized: bool = false
var _mouse_dragging: bool = false


func _ready() -> void:
	_cam = $Camera3D
	_ray = $CameraRay
	_snap_to_desired()


# --- Pure math (unit-tested) ---

# Orbit offset from the head anchor, given yaw/pitch/distance.
static func compute_offset(yaw_a: float, pitch_a: float, dist: float) -> Vector3:
	var horiz: float = cos(pitch_a) * dist
	return Vector3(sin(yaw_a) * horiz, sin(pitch_a) * dist, cos(yaw_a) * horiz)


# Camera FOV that compensates when collision shortens the distance
# (keeps the frustum width at the player ~constant).
static func compute_fov(base_dist: float, actual_dist: float) -> float:
	var d: float = maxf(actual_dist, MIN_DIST)
	if d >= base_dist - 0.001:
		return BASE_FOV
	var half: float = tan(deg_to_rad(BASE_FOV) * 0.5)
	return rad_to_deg(2.0 * atan(half * base_dist / d))


# Screen input vector (x = right, y = up) -> world movement direction.
func input_to_world(v: Vector2) -> Vector3:
	var d: Vector3 = move_dir_for_yaw(yaw) * v.y + right_dir_for_yaw(yaw) * v.x
	return d.normalized() if d.length() > 0.01 else Vector3.ZERO


static func move_dir_for_yaw(yaw_a: float) -> Vector3:
	return Vector3(-sin(yaw_a), 0.0, -cos(yaw_a))


static func right_dir_for_yaw(yaw_a: float) -> Vector3:
	return Vector3(cos(yaw_a), 0.0, -sin(yaw_a))


# --- Camera input ---

# Relative drag (pixels): +x = drag right = orbit right (yaw -= dx*sens).
func orbit(screen_delta: Vector2) -> void:
	yaw -= screen_delta.x * MOUSE_SENS
	pitch -= screen_delta.y * MOUSE_SENS
	pitch = clampf(pitch, pitch_min, pitch_max)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var m: InputEventMouseButton = event
		if m.button_index == MOUSE_BUTTON_MIDDLE:
			_mouse_dragging = m.pressed
	elif event is InputEventMouseMotion and _mouse_dragging:
		var mm: InputEventMouseMotion = event
		orbit(mm.relative)


func _physics_process(delta: float) -> void:
	# Gamepad: right stick (analog) + d-pad (camera_* actions).
	var stick: Vector2 = Vector2(
			Input.get_joy_axis(0, AXIS_RIGHT_X),
			Input.get_joy_axis(0, AXIS_RIGHT_Y))
	if stick.length() > STICK_DEADZONE:
		var deflection: float = clampf(stick.length(), STICK_DEADZONE, 1.0)
		yaw -= stick.x / maxf(stick.length(), 0.001) * STICK_TURN_SPEED \
				* deflection * delta
		pitch -= stick.y / maxf(stick.length(), 0.001) * STICK_TURN_SPEED \
				* deflection * delta
	if Input.is_action_pressed("camera_left"):
		yaw += DPAD_TURN_SPEED * delta
	if Input.is_action_pressed("camera_right"):
		yaw -= DPAD_TURN_SPEED * delta
	if Input.is_action_pressed("camera_up"):
		pitch = minf(pitch + DPAD_TURN_SPEED * delta, pitch_max)
	if Input.is_action_pressed("camera_down"):
		pitch = maxf(pitch - DPAD_TURN_SPEED * delta, pitch_min)

	_update_camera(delta)


func _update_camera(delta: float) -> void:
	var head_local: Vector3 = Vector3(0.0, HEAD_HEIGHT, 0.0)
	var desired: Vector3 = head_local + compute_offset(yaw, pitch, base_distance)

	# Wall collision: cast head -> desired, shorten on hit. The ray node is
	# placed at the head anchor; Godot 4 casts node-origin -> target_position
	# (relative to the node).
	var dist: float = base_distance
	_ray.target_position = compute_offset(yaw, pitch, base_distance)
	_ray.force_raycast_update()
	if _ray.is_colliding():
		var local_hit: Vector3 = to_local(_ray.get_collision_point())
		dist = maxf(local_hit.distance_to(head_local) - 0.25, MIN_DIST)
		desired = head_local + (desired - head_local).normalized() * dist

	var cam_target: Vector3 = desired
	if not _initialized:
		_cam.position = cam_target
		_initialized = true
	else:
		var t: float = 1.0 - exp(-SMOOTHING * delta)
		_cam.position = _cam.position.lerp(cam_target, t)
	_cam.look_at(global_position + Vector3(0.0, HEAD_HEIGHT, 0.0))
	_cam.fov = compute_fov(base_distance, dist)


func _snap_to_desired() -> void:
	var head_local: Vector3 = Vector3(0.0, HEAD_HEIGHT, 0.0)
	_cam.position = head_local + compute_offset(yaw, pitch, base_distance)
	_initialized = true


func get_head_global() -> Vector3:
	return global_position + Vector3(0.0, HEAD_HEIGHT, 0.0)
