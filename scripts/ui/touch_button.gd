# TouchButton — a round touch button that drives a single InputMap action
# (press/release). Binds the SAME actions as keyboard/gamepad (ARCHITECTURE
# §10): the touch layer is UI, not a parallel input system.
class_name TouchButton
extends Control

const BASE_COLOR := Color(1.0, 1.0, 1.0, 0.12)
const BASE_EDGE := Color(1.0, 1.0, 1.0, 0.40)
const PRESSED_COLOR := Color(1.0, 1.0, 1.0, 0.30)
const LABEL_COLOR := Color(1.0, 1.0, 1.0, 0.85)

var action: StringName = &""
var _label_text: String = ""
var _active_index: int = -1
var _radius: float = 1.0
var _pressed: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE


func set_placement(center: Vector2, radius_px: float, label: String) -> void:
	_radius = radius_px
	_label_text = label
	position = center - Vector2(radius_px, radius_px)
	size = Vector2(radius_px * 2.0, radius_px * 2.0)
	queue_redraw()


func _draw() -> void:
	var c: Vector2 = size * 0.5
	draw_circle(c, _radius, PRESSED_COLOR if _pressed else BASE_COLOR)
	draw_arc(c, _radius, 0.0, TAU, 48, BASE_EDGE, 2.0)
	if _label_text != "":
		var font: Font = ThemeDB.fallback_font
		var font_size: int = int(maxf(10.0, _radius * 0.5))
		var w: float = font.get_string_size(_label_text, HORIZONTAL_ALIGNMENT_CENTER, -1.0, font_size).x
		draw_string(font, Vector2(c.x - w * 0.5, c.y + font_size * 0.35),
				_label_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, LABEL_COLOR)


func _input_event(event: InputEvent) -> void:
	# Positions arrive in LOCAL coordinates.
	if event is InputEventScreenTouch:
		var t: InputEventScreenTouch = event
		if t.pressed and t.position.length() <= _radius * 1.3:
			_active_index = t.index
			_set_pressed(true)
		elif t.index == _active_index:
			_active_index = -1
			_set_pressed(false)
	elif event is InputEventScreenDrag:
		var d: InputEventScreenDrag = event
		if d.index == _active_index:
			# Release if the finger drifts well outside the button.
			if d.position.length() > _radius * 1.6:
				_active_index = -1
				_set_pressed(false)


func _set_pressed(pressed: bool) -> void:
	if _pressed == pressed:
		return
	_pressed = pressed
	if action != &"":
		if pressed:
			Input.action_press(action)
		else:
			Input.action_release(action)
	queue_redraw()
