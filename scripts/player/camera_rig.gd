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
# Phase 13 polish: the portrait aspect (16:9 -> 20:9) narrows the
# view; the base FOV widens on tall screens (mobile-first, ADR-021).
const PORTRAIT_FOV: float = 68.0
const PORTRAIT_RATIO: float = 20.0 / 9.0
const LANDSCAPE_RATIO: float = 16.0 / 9.0
# The sprint kick: a few degrees while running, damped (feel, not
# distortion — the mobile reference keeps the motion subtle).
const SPRINT_FOV: float = 6.0
const SPRINT_DAMP: float = 6.0  # 1/s
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

# The sprint kick state (the player sets the run flag each frame).
var _sprinting: bool = false
var _sprint_fov: float = 0.0

# Impact shake (Phase 4 feel): impulse adds amplitude, exponential decay.
var _shake_amp: float = 0.0
var _shake_time: float = 0.0
const SHAKE_DECAY: float = 8.0  # 1/s
const SHAKE_MAX: float = 0.5


func add_shake(impulse: float) -> void:
	if impulse > 0.0:
		_shake_amp = minf(_shake_amp + impulse, SHAKE_MAX)


func get_shake_amplitude() -> float:
	return _shake_amp


func _ready() -> void:
	_cam = $Camera3D
	_ray = $CameraRay
	_snap_to_desired()


# --- Pure math (unit-tested) ---

# Orbit offset from the head anchor, given yaw/pitch/distance.
static func compute_offset(yaw_a: float, pitch_a: float, dist: float) -> Vector3:
	var horiz: float = cos(pitch_a) * dist
	return Vector3(sin(yaw_a) * horiz, sin(pitch_a) * dist, cos(yaw_a) * horiz)


# The aspect-aware base FOV: 60 degrees at 16:9, up to PORTRAIT_FOV
# at 20:9 (linear between; clamped outside the range).
static func compute_base_fov(aspect: float) -> float:
	if aspect <= LANDSCAPE_RATIO:
		return BASE_FOV
	if aspect >= PORTRAIT_RATIO:
		return PORTRAIT_FOV
	var t: float = (aspect - LANDSCAPE_RATIO) / (PORTRAIT_RATIO
			- LANDSCAPE_RATIO)
	return lerpf(BASE_FOV, PORTRAIT_FOV, t)


# Camera FOV that compensates when collision shortens the distance
# (keeps the frustum width at the player ~constant). `base_fov` is
# the aspect-aware value (see compute_base_fov).
static func compute_fov(base_dist: float, actual_dist: float,
		base_fov: float = BASE_FOV) -> float:
	var d: float = maxf(actual_dist, MIN_DIST)
	if d >= base_dist - 0.001:
		return base_fov
	var half: float = tan(deg_to_rad(base_fov) * 0.5)
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


# The player tells the rig when it is sprinting (the kick follows,
# damped, so the motion reads as "momentum", not a zoom jump).
func set_sprinting(on: bool) -> void:
	_sprinting = on


func _update_camera(delta: float) -> void:
	var head_local: Vector3 = Vector3(0.0, HEAD_HEIGHT, 0.0)
	var desired: Vector3 = head_local + compute_offset(yaw, pitch, base_distance)
	# The sprint kick: approach the target exponentially (symmetric).
	var sprint_target: float = SPRINT_FOV if _sprinting else 0.0
	_sprint_fov = lerpf(_sprint_fov, sprint_target,
			1.0 - exp(-SPRINT_DAMP * delta))

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
	if _shake_amp > 0.0005:
		_shake_time += delta
		cam_target += Vector3(
				cos(_shake_time * 47.0), sin(_shake_time * 53.0),
				cos(_shake_time * 41.0)) * _shake_amp
		_shake_amp *= exp(-SHAKE_DECAY * delta)
	if not _initialized:
		_cam.position = cam_target
		_initialized = true
	else:
		var t: float = 1.0 - exp(-SMOOTHING * delta)
		_cam.position = _cam.position.lerp(cam_target, t)
	_cam.look_at(global_position + Vector3(0.0, HEAD_HEIGHT, 0.0))
	var aspect: float = get_viewport().get_visible_rect().size.x / \
			maxf(get_viewport().get_visible_rect().size.y, 1.0)
	_cam.fov = compute_fov(base_distance, dist,
			compute_base_fov(aspect)) + _sprint_fov


func _snap_to_desired() -> void:
	var head_local: Vector3 = Vector3(0.0, HEAD_HEIGHT, 0.0)
	_cam.position = head_local + compute_offset(yaw, pitch, base_distance)
	_initialized = true


func get_head_global() -> Vector3:
	return global_position + Vector3(0.0, HEAD_HEIGHT, 0.0)
