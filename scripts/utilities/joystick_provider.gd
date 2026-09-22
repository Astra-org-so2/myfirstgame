# JoystickProvider — seam between UI (virtual joystick) and gameplay
# (player movement). player/ depends on this small utilities class, never
# on ui/ directly (ARCHITECTURE §7).
#
# Push-based by design: the joystick pushes its vector here every frame
# and the player reads it. (Not pull-by-Callable: the headless wasm rig
# crashes on cross-script Callable.call() — ADR-022.)
class_name JoystickProvider
extends RefCounted

var _vector: Vector2 = Vector2.ZERO


func set_vector(v: Vector2) -> void:
	_vector = v


# Continuous movement vector: x = right(+), y = up(+), length in 0..1.
func get_joystick_vector() -> Vector2:
	return _vector


func reset() -> void:
	_vector = Vector2.ZERO
