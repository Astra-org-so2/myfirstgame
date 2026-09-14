# PlayerController — the player's root controller (Phase 2).
#
# Composition (ARCHITECTURE §8: one root controller + part-nodes):
# - PlayerMovementLogic: pure state machine (tested headless);
# - MovementPort: the physics seam — engine mode in game, mock mode in
#   headless tests (ADR-002/ADR-022);
# - CameraRig: orbit camera (child scene);
# - PlaceholderVisualAnim: ADR-005 prototype visual (Phase 13: rig).
#
# Player knows nothing about CharacterBody3D physics directly (§3.4).
# Cross-file references use preload-consts (headless rig has no global
# class_name registry — ADR-022).
class_name PlayerController
extends CharacterBody3D

const _DATA = preload("res://scripts/player/player_data.gd")
const _STATE = preload("res://scripts/player/player_state.gd")
const _LOGIC = preload("res://scripts/player/player_movement_logic.gd")
const _PORT = preload("res://scripts/player/movement_port.gd")
const _VISUAL = preload("res://scripts/player/placeholder_visual_anim.gd")
const _JOY = preload("res://scripts/utilities/joystick_provider.gd")
const _CAM_RIG = preload("res://scripts/player/camera_rig.gd")

signal state_changed(new_state: int)
signal dodge_started()
signal dodge_ended()
signal stamina_changed(value: float, max_value: float)

var data: _DATA
var camera_rig: _CAM_RIG

var _logic: _LOGIC
var _port: _PORT
var _visual: _VISUAL
var _joy: _JOY
var _prev_state: int = _STATE.State.IDLE
var _last_stamina_emit: float = -1.0
# Dodge edge state (pressed this tick vs last tick; see _physics_process).
var _dodge_held: bool = false


func _ready() -> void:
	if data == null:
		data = load("res://data/player/player_data.tres")
	if data == null:
		push_error("PlayerController: PlayerData missing (data/player/player_data.tres)")
		return
	var problems: Array[String] = data.validate()
	if not problems.is_empty():
		push_error("PlayerController: invalid PlayerData: " + ", ".join(problems))
	if camera_rig == null:
		camera_rig = $CameraRig
	_logic = _LOGIC.new(data)
	if _port == null:
		_port = _PORT.new(self, data.gravity, data.max_fall_speed)
	_visual = $Visual


func _physics_process(delta: float) -> void:
	_port.apply_gravity(delta)

	# Dodge input (edge-triggered). Held-edge (pressed this tick, not on the
	# previous one) instead of is_action_just_pressed: identical semantics in
	# the engine, plus it survives frames skipped over the press and works in
	# the headless rig, whose just-pressed state is only cleared by real
	# frame boundaries (ADR-022).
	var dodge_pressed: bool = Input.is_action_pressed("dodge")
	if dodge_pressed and not _dodge_held:
		var dir: Vector3 = _world_input_dir()
		if dir == Vector3.ZERO:
			dir = _logic.facing
		if _logic.start_dodge(dir):
			dodge_started.emit()
	_dodge_held = dodge_pressed

	var desired: Vector3 = _logic.update(
			delta, _world_input_dir(),
			Input.is_action_pressed("sprint"), _port.is_on_ground())

	var velocity: Vector3
	if _logic.is_hurt():
		velocity = desired  # logic owns the full velocity (knockback)
	else:
		velocity = Vector3(desired.x, _port.get_velocity().y, desired.z)
	_port.move(velocity)
	_port.integrate(delta)

	# State + visual.
	var state: int = _logic.state
	if state != _prev_state:
		if _prev_state == _STATE.State.DODGE:
			dodge_ended.emit()
		_prev_state = state
		state_changed.emit(state)
	var progress: float = 0.0
	if state == _STATE.State.DODGE:
		progress = clampf(
				1.0 - _logic.get_dodge_remaining() / data.dodge_duration, 0.0, 1.0)
	elif state == _STATE.State.HURT:
		progress = _logic.get_hurt_progress()
	_visual.update(state, delta, progress, progress)

	# Per-frame signals are a mobile budget leak (ADR-021): emit only on
	# meaningful change.
	if absf(_logic.stamina - _last_stamina_emit) > 0.5:
		_last_stamina_emit = _logic.stamina
		stamina_changed.emit(_logic.stamina, data.stamina_max)


# --- Input ---

func _read_input_2d() -> Vector2:
	# Argument order: (negative_x, positive_x, negative_y, positive_y).
	var v: Vector2 = Input.get_vector(
			"move_left", "move_right", "move_down", "move_up")
	if _joy != null:
		var tv: Vector2 = _joy.get_joystick_vector()
		if tv.length() > 0.1:
			v = tv
	return v


func _world_input_dir() -> Vector3:
	var v: Vector2 = _read_input_2d()
	if v.length() < 0.01 or camera_rig == null:
		return Vector3.ZERO
	return camera_rig.input_to_world(v)


# --- Composition / test seams ---

func set_port(port: _PORT) -> void:
	_port = port


func get_port() -> _PORT:
	return _port


func set_touch_provider(provider: _JOY) -> void:
	_joy = provider


# --- Public API (used by combat/run systems from Phase 4+) ---

func take_hit(direction: Vector3) -> void:
	# Phase 2: state + knockback only (damage/HP — Phase 4, DamageResolver).
	if _logic.state != _STATE.State.HURT:
		_logic.apply_hurt(direction)


func is_invulnerable() -> bool:
	return _logic.is_invulnerable()


func get_state() -> int:
	return _logic.state


func get_stamina() -> float:
	return _logic.stamina


# Respawn (Phase 2 integration target; RunManager drives it from Phase 8).
func respawn(pos: Vector3) -> void:
	_port.set_position(pos)
	_port.move(Vector3.ZERO)
	_logic.reset()
	_prev_state = _STATE.State.IDLE
	_dodge_held = false
	state_changed.emit(_logic.state)
