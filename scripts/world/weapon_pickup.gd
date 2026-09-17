# WeaponPickup — a scripted weapon find (WEAPON_DESIGN §0/§6, Phase 6).
#
# Weapons are FOUND, not dropped or bought: 1 location, 1 time,
# forever (WORLD_STATE: weapon_X_found). The node is a small plinth
# + a capsule in the weapon's tint + its name; the Interactable
# pattern opens it. On the first (E): the weapon enters the WorldState
# (permanent), the player's loadout, and the note line (the "#2 —
# your own note" mystery seed, WEAPON_DESIGN §2.4/§3.4).
#
# Phase 6 demo placement: the camp (the cannon by the table, the
# staff by the note stand). Their PRODUCTION locations are the Mine
# level 1 and the Old Shrine (Phase 7 rooms) — only the positions in
# the scene change, not this system.
class_name WeaponPickup
extends Node3D

const _DATA = preload("res://scripts/gameplay/combat/weapon_data.gd")
const _STATE = preload("res://scripts/gameplay/progression/progression_state.gd")
const _INTERACTABLE = preload("res://scripts/world/interactable.gd")
const _LOADOUT = preload("res://scripts/gameplay/combat/weapon_loadout.gd")

var _weapon: _DATA
var _note_line: String = ""
var _state: _STATE
var _loadout: _LOADOUT
var _player: Node = null
var _ia: _INTERACTABLE
var _label: Label3D
var _taken: bool = false


func setup(weapon: _DATA, state: _STATE, loadout: _LOADOUT,
		player: Node, note_line: String = "") -> void:
	_weapon = weapon
	_state = state
	_loadout = loadout
	_player = player
	_note_line = note_line
	_taken = state.ws.is_weapon_found(weapon.id)
	_build_visual()
	_ia = _INTERACTABLE.new()
	_ia.name = "IA_pickup_" + String(weapon.id)
	_ia.prompt = _prompt()
	_ia.interact_radius = 2.2
	add_child(_ia)
	_ia.set_target(player)
	_ia.interacted.connect(_on_interacted)


func _prompt() -> String:
	if _taken:
		return "It's already yours."
	return "Take the %s (E)" % _weapon.display_name


func _build_visual() -> void:
	var plinth: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(0.5, 0.4, 0.5)
	plinth.mesh = bm
	plinth.position = Vector3(0.0, 0.2, 0.0)
	var pm: StandardMaterial3D = StandardMaterial3D.new()
	pm.albedo_color = Color(0.35, 0.33, 0.3)
	plinth.material_override = pm
	add_child(plinth)
	var body_mi: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = 0.12
	cm.bottom_radius = 0.12
	cm.height = 0.8
	body_mi.mesh = cm
	body_mi.position = Vector3(0.0, 0.8, 0.0)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = _weapon.color_tint
	body_mi.material_override = mat
	add_child(body_mi)
	_label = Label3D.new()
	_label.text = _weapon.display_name
	_label.position = Vector3(0.0, 1.8, 0.0)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.outline_size = 4
	_label.modulate = Color(0.95, 0.92, 0.8, 0.95)
	add_child(_label)


func _on_interacted(_ia_node: Node) -> void:
	if _taken:
		_flash("It's already yours.")
		return
	_taken = true
	# Permanent (WORLD_STATE): found once, forever.
	_state.ws.set_weapon_found(_weapon.id)
	_state.ws.set_flag(weapon_flag_id())
	# Into the loadout (the controller is created + bound there).
	_loadout.add_weapon(_weapon)
	_label.text = ""
	var bus: Node = get_tree().root.get_node_or_null("EventBus")
	if bus != null and bus.has_signal("weapon_found"):
		bus.weapon_found.emit(_weapon.id, global_position)
	if _note_line != "":
		_flash(_note_line)


# weapon_cannon -> cannon_found (WORLD_STATE_DESIGN §2 naming).
func weapon_flag_id() -> StringName:
	var short: String = String(_weapon.id).replace("weapon_", "")
	return StringName(short + "_found")


func _flash(text: String) -> void:
	_label.text = text
