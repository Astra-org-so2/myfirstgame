# Interactable — a world object the player can act on (E).
#
# Phase 3 scope (stub, honest): approach -> floating prompt, interact edge
# -> `interacted` signal + a brief "look" pulse. The effect content
# (dialogue, note UI, camera zoom) lands with its own system (Phase 4/10/11).
#
# Detection is distance polling in _physics_process (not Area3D): works in
# the headless rig (no physics server — ADR-002) and is deterministic under
# manual ticks. Held-edge (pressed this tick, not last) instead of
# is_action_just_pressed (ADR-022).
class_name Interactable
extends Node3D

const INTERACT_ACTION: StringName = &"interact"
const PULSE_SECONDS: float = 0.5

var prompt: String = ""
# Player (duck-typed `get_body_position()`: world position from the
# movement port — node position in engine mode, mock position in the rig).
var target: Variant = null
var interact_radius: float = 2.4

signal interacted(interactable: Node3D)

var _label: Label3D
var _held: bool = false
var _pulse_left: float = 0.0
var _base_scale: Vector3 = Vector3.ONE


func _ready() -> void:
	_base_scale = scale
	_label = Label3D.new()
	_label.text = prompt
	_label.position = Vector3(0.0, 2.3, 0.0)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.outline_size = 4
	_label.modulate = Color(1.0, 1.0, 1.0, 0.9)
	_label.visible = false
	add_child(_label)


func set_target(t: Variant) -> void:
	target = t


func is_prompt_visible() -> bool:
	return _label != null and _label.visible


func get_target() -> Variant:
	return target


func _physics_process(delta: float) -> void:
	# Pulse decay (frame-independent: driven by delta).
	if _pulse_left > 0.0:
		_pulse_left = maxf(0.0, _pulse_left - delta)
		var k: float = _pulse_left / PULSE_SECONDS
		scale = _base_scale * (1.0 + 0.06 * k)
	else:
		scale = _base_scale

	if target == null or _label == null:
		return
	var near: bool = target.get_body_position().distance_to(
			global_position) < interact_radius
	_label.visible = near

	var pressed: bool = Input.is_action_pressed(INTERACT_ACTION)
	if near and pressed and not _held:
		_pulse_left = PULSE_SECONDS
		interacted.emit(self)
	_held = pressed
