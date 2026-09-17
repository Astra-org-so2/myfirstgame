# WeaponLoadout — the found weapons + the equipped one (Phase 6).
#
# Weapons are FOUND, never dropped or bought (WEAPON_DESIGN §0/§6):
# WorldState.weapons is the permanent record; the loadout owns the
# live controllers and which one the player is holding. The blade is
# ADOPTED (the Phase 4 WeaponController the player already has — its
# `player.weapon` reference stays valid for the existing wiring);
# the cannon/staff controllers are created on pickup.
#
# Only the EQUIPPED controller is updated (the others hold their CDs
# but cost nothing — the AI budget rule applies to the player too).
# Switching: the `weapon_switch` action cycles in find order.
class_name WeaponLoadout
extends Node

const _DATA = preload("res://scripts/gameplay/combat/weapon_data.gd")
const _BLADE = preload("res://scripts/gameplay/combat/weapon_controller.gd")
const _CANNON = preload("res://scripts/gameplay/combat/ranged_weapon_controller.gd")
const _STAFF = preload("res://scripts/gameplay/combat/staff_controller.gd")
const _FX = preload("res://scripts/gameplay/progression/inheritance_effects.gd")
const _WS = preload("res://scripts/gameplay/progression/world_state.gd")

signal weapon_changed(weapon_id: StringName)

var _player: Node = null
var _resolver: Node = null
var _sfx: Node = null
var _effects: _FX = null
var _ws: _WS = null
var _cam_rig: Node = null
var _projectile_root: Node = null

var _weapons: Dictionary = {}  # weapon data id -> controller
var _order: Array = []
var _equipped: StringName = &""
var _switch_held: bool = false


func setup(player: Node, resolver: Node, sfx: Node,
		effects: _FX, ws: _WS) -> void:
	_player = player
	_resolver = resolver
	_sfx = sfx
	_effects = effects
	_ws = ws
	_cam_rig = player.camera_rig
	_projectile_root = player.get_parent()


# The blade: the player's Phase 4 controller, already bound.
func adopt(weapon_id: StringName, controller: Node) -> void:
	if _weapons.has(weapon_id):
		return
	_weapons[weapon_id] = controller
	_order.append(weapon_id)
	if _equipped == &"":
		_equipped = weapon_id


# A found weapon (cannon/staff/first blade): create + bind its
# controller. Returns the controller.
func add_weapon(data: _DATA) -> Node:
	if _weapons.has(data.id):
		return _weapons[data.id]
	var ctrl: Node
	if data.type == _DATA.Type.MELEE:
		ctrl = _BLADE.new()
		ctrl.bind(_player, data, _resolver)
	elif data.type == _DATA.Type.RANGED:
		ctrl = _CANNON.new()
		ctrl.bind(_player, data, _resolver, _effects, _ws)
		ctrl.set_projectile_root(_projectile_root)
	else:
		ctrl = _STAFF.new()
		ctrl.bind(_player, data, _resolver, _effects, _ws)
	ctrl.name = "Weapon_" + String(data.id)
	add_child(ctrl)
	ctrl.set_sfx(_sfx)
	if ctrl.has_method("set_camera_rig"):
		ctrl.set_camera_rig(_cam_rig)
	_weapons[data.id] = ctrl
	_order.append(data.id)
	weapon_changed.emit(data.id)
	return ctrl


func has(weapon_id: StringName) -> bool:
	return _weapons.has(weapon_id)


# How many weapons are in the loadout (tests + the scene).
func count() -> int:
	return _order.size()


func get(weapon_id: StringName) -> Node:
	return _weapons.get(weapon_id, null)


func get_data(weapon_id: StringName) -> _DATA:
	var c: Node = get(weapon_id)
	if c == null:
		return null
	return c.get_data()


func equipped() -> StringName:
	return _equipped


func current() -> Node:
	return _weapons.get(_equipped, null)


func equip(weapon_id: StringName) -> bool:
	if not _weapons.has(weapon_id):
		return false
	_equipped = weapon_id
	weapon_changed.emit(weapon_id)
	return true


# The `weapon_switch` edge: cycle in find order (blade -> cannon ->
# staff -> blade...).
func try_switch() -> bool:
	if _order.size() <= 1:
		return false
	var i: int = _order.find(_equipped)
	var next: StringName = _order[(i + 1) % _order.size()]
	return equip(next)


# The ONE input edge read per tick (held-edge, ADR-022).
func update_switch_input() -> void:
	var pressed: bool = Input.is_action_pressed("weapon_switch")
	if pressed and not _switch_held:
		try_switch()
	_switch_held = pressed


# Only the equipped controller advances (the others wait free).
func update_active(delta: float) -> void:
	var c: Node = current()
	if c != null and c.has_method("update"):
		c.update(delta)


# Per-RUN reset (respawn): ammo/CDs/charges back to the run start,
# the effective Inheritance stats re-read (a death-screen choice may
# have changed them), equipped = the first weapon (the blade).
func reset_all() -> void:
	for id in _weapons:
		var c: Node = _weapons[id]
		if c.has_method("reset"):
			c.reset()
	if _order.size() > 0:
		_equipped = _order[0]
		weapon_changed.emit(_equipped)
