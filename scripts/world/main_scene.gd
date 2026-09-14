# Main scene (temporary Phase 2 entry: hub stub + player + touch controls).
#
# Phase 3 replaces it with the AreaHub/room system (the wiring pattern
# stays: a scene-root controller composes its parts).
# Cross-file references use preload-consts (ADR-022).
extends Node3D

const _PLAYER = preload("res://scripts/player/player_controller.gd")
const _TOUCH = preload("res://scripts/ui/touch_controls.gd")


func _ready() -> void:
	var p: Node = $Player
	var t: Node = $TouchControls
	if p == null or t == null:
		push_error("Main scene: Player and/or TouchControls missing")
		return
	var player: _PLAYER = p
	var touch: _TOUCH = t
	# Touch layer -> player (joystick via the JoystickProvider seam;
	# camera zone -> the player's camera rig). ARCHITECTURE §7: player/
	# never depends on ui/ directly.
	player.set_touch_provider(touch.get_provider())
	touch.set_camera_rig(player.camera_rig)
