# PlayerMovementLogic — pure, deterministic movement state machine.
#
# No Node, no Input, no physics: takes (delta, input_dir, want_sprint,
# on_ground) and returns the desired horizontal velocity. All timing/stamina/
# i-frame rules live here so they are unit-testable in the headless rig
# (ARCHITECTURE §3.4). PlayerController wires input -> here -> port.
#
# Cross-file references use preload-consts (headless rig has no global
# class_name registry — ADR-022).
class_name PlayerMovementLogic
extends RefCounted

const _DATA = preload("res://scripts/player/player_data.gd")
const _STATE = preload("res://scripts/player/player_state.gd")

var state: int = _STATE.State.IDLE
var stamina: float
var facing: Vector3 = Vector3(0.0, 0.0, -1.0)

var _data: _DATA
var _dodge_elapsed: float = 0.0
var _dodge_cooldown: float = 0.0
var _dodge_dir: Vector3 = Vector3.ZERO
var _hurt_elapsed: float = 0.0
var _knockback: Vector3 = Vector3.ZERO
var _regen_delay: float = 0.0
var _exhausted: bool = false
var _last_velocity: Vector3 = Vector3.ZERO


func _init(data: _DATA) -> void:
	_data = data
	stamina = data.stamina_max


func reset() -> void:
	state = _STATE.State.IDLE
	stamina = _data.stamina_max
	_dodge_elapsed = 0.0
	_dodge_cooldown = 0.0
	_dodge_dir = Vector3.ZERO
	_hurt_elapsed = 0.0
	_knockback = Vector3.ZERO
	_regen_delay = 0.0
	_exhausted = false
	_last_velocity = Vector3.ZERO


# Starts a dodge in `dir` (use facing if dir is ~zero). Returns false when
# blocked (cooldown, hurt, not enough stamina).
func start_dodge(dir: Vector3) -> bool:
	if state == _STATE.State.HURT or _dodge_cooldown > 0.0 \
			or state == _STATE.State.DODGE:
		return false
	if stamina < _data.dodge_stamina_cost:
		return false
	stamina -= _data.dodge_stamina_cost
	_dodge_dir = dir if dir.length() > 0.01 else facing
	_dodge_dir = Vector3(_dodge_dir.x, 0.0, _dodge_dir.z)
	_dodge_dir = _dodge_dir.normalized() if _dodge_dir.length() > 0.01 else facing
	_dodge_elapsed = 0.0
	state = _STATE.State.DODGE
	return true


# I-frames: only inside [dodge_iframe_start, dodge_iframe_end] of the dodge.
func is_invulnerable() -> bool:
	if state != _STATE.State.DODGE:
		return false
	return _dodge_elapsed >= _data.dodge_iframe_start \
			and _dodge_elapsed <= _data.dodge_iframe_end


# Enters hitstun (damage pipeline is Phase 4; this is the state + knockback).
func apply_hurt(direction: Vector3) -> void:
	state = _STATE.State.HURT
	_hurt_elapsed = 0.0
	_dodge_elapsed = 0.0
	_last_velocity = Vector3.ZERO  # no leftover speed after hitstun
	_knockback = Vector3(direction.x, 0.0, direction.z).normalized() \
			* _data.knockback_speed
	_knockback.y = _data.knockback_up


func is_hurt() -> bool:
	return state == _STATE.State.HURT


# One physics tick. Returns the desired velocity:
# - horizontal during IDLE/WALK/RUN/DODGE (y = 0),
# - full 3D (decaying knockback) during HURT.
func update(delta: float, input_dir: Vector3, want_sprint: bool,
		on_ground: bool) -> Vector3:
	# Timers.
	if _dodge_cooldown > 0.0:
		_dodge_cooldown = maxf(0.0, _dodge_cooldown - delta)
	_regen_delay = maxf(0.0, _regen_delay - delta)

	# HURT: no player control, decaying knockback.
	if state == _STATE.State.HURT:
		_hurt_elapsed += delta
		_knockback *= exp(-_data.knockback_decay * delta)
		_knockback.y = maxf(_knockback.y, -_data.max_fall_speed)
		if _hurt_elapsed >= _data.hurt_duration \
				or _knockback.length() < 0.05:
			state = _STATE.State.IDLE
			_knockback = Vector3.ZERO
		return _knockback

	# DODGE: locked direction at fixed speed.
	if state == _STATE.State.DODGE:
		_dodge_elapsed += delta
		if _dodge_elapsed >= _data.dodge_duration:
			_dodge_elapsed = 0.0
			_dodge_cooldown = _data.dodge_cooldown
			_last_velocity = Vector3.ZERO  # no leftover dodge speed
			state = _walk_run_state(input_dir, want_sprint)
		return _dodge_dir * _data.dodge_speed

	# IDLE/WALK/RUN.
	var dir: Vector3 = Vector3(input_dir.x, 0.0, input_dir.z)
	dir = dir.normalized() if dir.length() > 0.01 else Vector3.ZERO
	var moving: bool = dir != Vector3.ZERO

	# Facing (smooth turn toward input direction).
	if moving:
		var t: float = 1.0 - exp(-_data.turn_speed * delta)
		facing = (facing.lerp(dir, t)).normalized()

	# Sprint + stamina.
	var sprinting: bool = moving and want_sprint \
			and stamina > _data.sprint_min and not _exhausted
	if sprinting:
		stamina = maxf(0.0, stamina - _data.sprint_drain_per_sec * delta)
		_regen_delay = _data.stamina_regen_delay
		if stamina <= 0.0:
			_exhausted = true
	if not sprinting:
		if _regen_delay <= 0.0:
			stamina = minf(_data.stamina_max,
					stamina + _data.stamina_regen_per_sec * delta)
		if stamina > _data.sprint_min:
			_exhausted = false

	# Approach target speed (accel when moving, decel when braking).
	var accel: float = _data.ground_accel if on_ground else _data.air_accel
	var decel: float = _data.ground_decel if on_ground else _data.air_decel
	var target_speed: float = 0.0
	if moving:
		target_speed = _data.sprint_speed if sprinting else _data.walk_speed
	var target: Vector3 = dir * target_speed
	var current: Vector3 = _last_velocity
	var max_change: float = (accel if moving else decel) * delta
	if current.distance_to(target) <= max_change:
		_last_velocity = target
	else:
		_last_velocity = current + \
				(target - current).normalized() * max_change

	state = _STATE.State.RUN if sprinting \
			else (_STATE.State.WALK if moving else _STATE.State.IDLE)
	return Vector3(_last_velocity.x, 0.0, _last_velocity.z)


# Seconds of dodge remaining (0 outside DODGE).
func get_dodge_remaining() -> float:
	if state != _STATE.State.DODGE:
		return 0.0
	return maxf(0.0, _data.dodge_duration - _dodge_elapsed)


# Hurt progress 0..1 (for the visual; 0 outside HURT).
func get_hurt_progress() -> float:
	if state != _STATE.State.HURT:
		return 0.0
	return clampf(_hurt_elapsed / _data.hurt_duration, 0.0, 1.0)


func _walk_run_state(input_dir: Vector3, want_sprint: bool) -> int:
	var moving: bool = input_dir.length() > 0.01
	var sprinting: bool = moving and want_sprint \
			and stamina > _data.sprint_min and not _exhausted
	if sprinting:
		return _STATE.State.RUN
	return _STATE.State.WALK if moving else _STATE.State.IDLE
