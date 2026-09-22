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

# The scene (main) connects here: it owns the capacity/cap decision
# and the player-visible feedback. (P17: the signal was promised by
# the docstring but never declared — the scene's connection was
# dead, the camp item was unpickable; the target was the scene
# root, which has no get_body_position, so the prompt could not
# show either.)
signal interacted(interactable: Node3D)


func setup(p_item: _ITEM_DATA, p_player: Node) -> void:
	item = p_item
	_build_visual()
	# Interactable reads prompt/radius in _ready — set BEFORE add_child.
	# The target is the PLAYER (the distance poll calls its
	# get_body_position).
	interactable = _INTERACTABLE.new()
	interactable.name = "Interact"
	interactable.prompt = tr("A small fire (E)")
	interactable.interact_radius = 2.2
	add_child(interactable)
	interactable.set_target(p_player)
	interactable.interacted.connect(_on_interactable_interacted)


func _on_interactable_interacted(ia: Node3D) -> void:
	interacted.emit(ia)


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
