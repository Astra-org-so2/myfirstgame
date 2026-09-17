# CampDrop — a "small camp fire" the world left at an enemy's death
# spot (PROGRESSION_DESIGN §4: 3 костра per run, 1/10 drop chance).
#
# One kindling on the ground (code mesh + Interactable; ADR-024).
# Interacting (E / the interact button) emits `interacted` — the scene
# decides whether the bag took it (capacity/cap) and what the player
# sees. Code-built: a 30 cm log with a warm tint (the visual pass owns
# the upgrade, no asset needed now).
extends Node3D

const _INTERACTABLE = preload("res://scripts/world/interactable.gd")
const _ITEM_DATA = preload("res://scripts/gameplay/progression/item_data.gd")

var item: _ITEM_DATA
var interactable: _INTERACTABLE


func setup(p_item: _ITEM_DATA, scene_root: Node) -> void:
	item = p_item
	_build_visual()
	# Interactable reads prompt/radius in _ready — set BEFORE add_child.
	interactable = _INTERACTABLE.new()
	interactable.name = "Interact"
	interactable.prompt = "A small fire (E)"
	interactable.interact_radius = 2.2
	add_child(interactable)
	interactable.set_target(scene_root)


func _build_visual() -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Log"
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = 0.07
	cm.bottom_radius = 0.09
	cm.height = 0.34
	mi.mesh = cm
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.3, 0.18)
	mi.material_override = mat
	mi.rotation_degrees = Vector3(90.0, 0.0, 35.0)
	mi.position = Vector3(0.0, 0.08, 0.0)
	add_child(mi)
