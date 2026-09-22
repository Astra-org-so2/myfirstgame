# TouchJoystick — virtual analog stick (left-bottom quadrant, ADR-021).
# Emits a continuous Vector2 (x = right, y = up, length 0..1) via
# get_joystick_vector(); the player reads it through JoystickProvider.
class_name TouchJoystick
extends Control

const BASE_COLOR := Color(1.0, 1.0, 1.0, 0.10)
const BASE_EDGE := Color(1.0, 1.0, 1.0, 0.35)
const KNOB_COLOR := Color(1.0, 1.0, 1.0, 0.30)

var _active_index: int = -1
var _origin: Vector2 = Vector2.ZERO
var _radius: float = 1.0
var _knob: Vector2 = Vector2.ZERO
var _vector: Vector2 = Vector2.ZERO
# The player-facing seam (duck-typed: ui/ must not depend on utilities/
# types in the headless rig — ADR-022). Push-based, because cross-script
# Callable.call() crashes the rig.
var _provider: Variant = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Godot 4: Control receives GUI input through the `gui_input`
	# signal (the documented path) — the `_input_event` override
	# targeted a virtual that Control does not have (dead wiring).
	gui_input.connect(_on_gui_input)


func set_provider(provider: Variant) -> void:
	_provider = provider


func _process(_delta: float) -> void:
	# Push every frame: the player reads the seam in _physics_process.
	if _provider != null and _provider.has_method("set_vector"):
		_provider.set_vector(_vector)


func set_placement(center: Vector2, radius_px: float) -> void:
	_origin = center
	_radius = radius_px
	position = center - Vector2(radius_px, radius_px)
	size = Vector2(radius_px * 2.0, radius_px * 2.0)
	queue_redraw()


func get_joystick_vector() -> Vector2:
	return _vector


func _draw() -> void:
	var c: Vector2 = size * 0.5
	draw_circle(c, _radius, BASE_COLOR)
	draw_arc(c, _radius, 0.0, TAU, 48, BASE_EDGE, 2.0)
	draw_circle(c + _knob, _radius * 0.45, KNOB_COLOR)


func _on_gui_input(event: InputEvent) -> void:
	# Note: the gui_input signal delivers positions in LOCAL coordinates.
	if event is InputEventScreenTouch:
		var t: InputEventScreenTouch = event
		if t.pressed:
			if t.position.length() <= _radius * 1.5:
				_active_index = t.index
				_update_knob(t.position)
		elif t.index == _active_index:
			_active_index = -1
			_vector = Vector2.ZERO
			_knob = Vector2.ZERO
			queue_redraw()
	elif event is InputEventScreenDrag:
		var d: InputEventScreenDrag = event
		if d.index == _active_index:
			_update_knob(d.position)


func _update_knob(local_pos: Vector2) -> void:
	var local: Vector2 = (local_pos - size * 0.5).limit_length(_radius)
	_knob = local
	# y is flipped: screen-down is negative for the movement vector.
	_vector = Vector2(local.x, -local.y) / _radius
	queue_redraw()
