# Integration: the touch layer's INPUT WIRING (regression guard).
#
# Phase 6 found a P0: TouchButton/TouchJoystick/TouchCameraZone
# overrode `_input_event` — a CollisionObject virtual that Control
# does NOT have in Godot 4 (the Control path is the `gui_input`
# signal / `_gui_input`). On a real device the buttons/joystick
# would have been dead. The rig cannot generate real touch events
# (headless), so the test emits the `gui_input` signal directly on
# the real scene scripts and asserts the action/behavior — that is
# exactly the wiring the regression broke.
#
# Cross-file references via preload-consts (ADR-022).
extends Node

const _BTN = preload("res://scripts/ui/touch_button.gd")
const _JOY = preload("res://scripts/ui/touch_joystick.gd")
const _CAM = preload("res://scripts/ui/touch_camera_zone.gd")

class _MockRig extends Node:
	var calls: int = 0
	var last: Vector2 = Vector2.ZERO

	func orbit(d: Vector2) -> void:
		calls += 1
		last = d


func _touch(index: int, local_pos: Vector2, pressed: bool) -> InputEventScreenTouch:
	var e: InputEventScreenTouch = InputEventScreenTouch.new()
	e.index = index
	e.position = local_pos
	e.pressed = pressed
	return e


func _drag(index: int, local_pos: Vector2, rel: Vector2) -> InputEventScreenDrag:
	var e: InputEventScreenDrag = InputEventScreenDrag.new()
	e.index = index
	e.position = local_pos
	e.relative = rel
	return e


func run(ctx: Variant) -> void:
	var root: Node = Node3D.new()
	add_child(root)

	# --- TouchButton: a touch inside the radius drives the action ---
	var btn: _BTN = _BTN.new()
	root.add_child(btn)
	btn.action = &"interact"
	btn.set_placement(Vector2(100.0, 100.0), 40.0, "E")
	btn.gui_input.emit(_touch(7, Vector2(20.0, 0.0), true))
	ctx.check(Input.is_action_pressed("interact"),
			"touch_button: gui_input touch press drives the action")
	btn.gui_input.emit(_touch(7, Vector2(20.0, 0.0), false))
	ctx.check(not Input.is_action_pressed("interact"),
			"touch_button: touch release releases the action")
	# A touch far outside the 1.3r hit radius is ignored.
	btn.gui_input.emit(_touch(8, Vector2(300.0, 0.0), true))
	ctx.check(not Input.is_action_pressed("interact"),
			"touch_button: a far touch is ignored")
	root.remove_child(btn)
	btn.queue_free()

	# --- TouchJoystick: a drag produces the movement vector ---
	var joy: _JOY = _JOY.new()
	root.add_child(joy)
	joy.set_placement(Vector2(200.0, 200.0), 60.0)
	joy.gui_input.emit(_touch(3, Vector2.ZERO, true))
	# Local coords: the joystick center is (60, 60); push the knob to
	# the right edge.
	joy.gui_input.emit(_drag(3, Vector2(120.0, 60.0), Vector2(30.0, 0.0)))
	var v: Vector2 = joy.get_joystick_vector()
	ctx.check(v.x > 0.5 and absf(v.y) < 0.05,
			"touch_joystick: gui_input drag produces a right vector (%.2f, %.2f)"
			% [v.x, v.y])
	joy.gui_input.emit(_touch(3, Vector2.ZERO, false))
	ctx.check(joy.get_joystick_vector() == Vector2.ZERO,
			"touch_joystick: release resets the vector")
	root.remove_child(joy)
	joy.queue_free()

	# --- TouchCameraZone: a drag forwards to the camera rig ---
	var cam: _CAM = _CAM.new()
	root.add_child(cam)
	cam.size = Vector2(200.0, 200.0)
	var rig: _MockRig = _MockRig.new()
	root.add_child(rig)
	cam.set_rig(rig)
	cam.gui_input.emit(_touch(5, Vector2(10.0, 10.0), true))
	cam.gui_input.emit(_drag(5, Vector2(40.0, 10.0), Vector2(30.0, 0.0)))
	ctx.check(rig.calls >= 1 and rig.last == Vector2(30.0, 0.0),
			"touch_camera_zone: gui_input drag orbits the rig")
	cam.gui_input.emit(_touch(5, Vector2(40.0, 10.0), false))
	root.remove_child(cam)
	cam.queue_free()
	root.remove_child(rig)
	rig.queue_free()
	root.queue_free()
