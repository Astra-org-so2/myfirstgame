# Main scene controller (Phase 3: the camp hub).
#
# Composes the camp (CampWorld builds from CampLayout data) with the
# player + touch layer, places the spawn point from data, and wires the
# interactable stubs to the player. Phase 3 replaces the Phase 1/2 hub
# stub; the wiring pattern stays (a scene-root controller composes parts).
# Cross-file references use preload-consts (ADR-022).
extends Node3D

const _PLAYER = preload("res://scripts/player/player_controller.gd")
const _TOUCH = preload("res://scripts/ui/touch_controls.gd")
const _CAMP = preload("res://scripts/world/camp_world.gd")
const _LAYOUT = preload("res://scripts/world/camp_layout.gd")


func _ready() -> void:
	var camp: _CAMP = $CampWorld
	var p: Node = $Player
	var t: Node = $TouchControls
	if camp == null or p == null or t == null:
		push_error("Main scene: CampWorld/Player/TouchControls missing")
		return
	var player: _PLAYER = p
	var touch: _TOUCH = t

	# Touch layer -> player (joystick seam + camera zone). ARCHITECTURE §7:
	# player/ never depends on ui/ directly.
	player.set_touch_provider(touch.get_provider())
	touch.set_camera_rig(player.camera_rig)

	# Spawn from camp data (single source of truth: CampLayout).
	var layout: _LAYOUT = camp.layout
	if layout == null:
		push_error("Main scene: CampWorld has no CampLayout")
		return
	var spawn: Node = $SpawnPoint
	spawn.global_position = layout.spawn_pos

	# Interactable stubs -> player (prompt + interact edge; content —
	# Phase 4/10/11).
	for ia in camp.interactables:
		ia.set_target(player)
