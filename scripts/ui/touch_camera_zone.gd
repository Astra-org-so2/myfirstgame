# TouchCameraZone — drag area (right side) that orbits the camera.
# Forwards screen-drag deltas to a CameraRig (the only camera it knows).
class_name TouchCameraZone
extends Control

var _active_index: int = -1
# CameraRig, held as Variant (duck-typed `orbit`): ui/ must not depend on
# player/ (ARCHITECTURE §7), and the headless rig has no cross-file class
# registry (ADR-022). Named `orbit` (not `rotate`) because a script method
# shadowing a built-in Node3D method crashes cross-script calls (ADR-022).
var _rig: Variant = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE


func set_rig(rig: Variant) -> void:
	_rig = rig


func _draw() -> void:
	# Faint marker so the zone is discoverable on a new device.
	var c: Vector2 = size * 0.5
	draw_arc(c, minf(size.x, size.y) * 0.08, 0.0, TAU, 32,
			Color(1.0, 1.0, 1.0, 0.10), 2.0)


func _input_event(event: InputEvent) -> void:
	# Positions arrive in LOCAL coordinates; use the drag delta for the
	# orbit (absolute position is irrelevant for a relative camera drag).
	if event is InputEventScreenTouch:
		var t: InputEventScreenTouch = event
		if t.pressed:
			_active_index = t.index
		elif t.index == _active_index:
			_active_index = -1
	elif event is InputEventScreenDrag:
		var d: InputEventScreenDrag = event
		if d.index == _active_index and _rig != null and _rig.has_method("orbit"):
			_rig.orbit(d.relative)
