# Projectile — the Hand Cannon's shot (WEAPON_DESIGN §2).
#
# Kinematic (no physics server — the headless rig has none, ADR-002):
# it steps along its direction and samples registered combat targets
# by distance. Deterministic under manual ticks (ADR-022). The damage
# flows through the DamageResolver exactly like a melee hit — one
# damage point (ARCHITECTURE §3.2).
class_name Projectile
extends Node3D

const STEP_RADIUS: float = 0.6  # meters (target body approximation)


var direction: Vector3 = Vector3.FORWARD
var speed: float = 40.0
var range_left: float = 15.0
var _damage: float = 0.0
var _source: Node = null
var _resolver: Node = null
var _alive: bool = false

signal impact(target: Node)
signal expired


# origin/dir: the muzzle and the fired direction. The projectile is
# parented by the caller (scene root / the weapon) and updated there
# (`update(delta)`) or via _physics_process in the engine.
func launch(origin: Vector3, dir: Vector3, p_speed: float, p_range: float,
		dmg: float, source: Node, resolver: Node) -> void:
	direction = dir.normalized()
	speed = p_speed
	range_left = p_range
	_damage = dmg
	_source = source
	_resolver = resolver
	global_position = origin
	_alive = true


func is_alive() -> bool:
	return _alive


# One step. Returns true while in flight.
func update(delta: float) -> bool:
	if not _alive:
		return false
	var step_len: float = speed * delta
	# Sub-step the hit sample so a fast shot can't tunnel a target.
	var steps: int = maxi(1, ceili(step_len / (STEP_RADIUS * 0.5)))
	var per: float = step_len / float(steps)
	for i in steps:
		global_position += direction * per
		range_left -= per
		if _hit_something():
			return false
		if range_left <= 0.0:
			_finish(false)
			return false
	return true


func _hit_something() -> bool:
	if _resolver == null:
		return false
	var nodes: Array = _resolver.get_target_nodes()
	for n in nodes:
		if n == null or not is_instance_valid(n) or n == _source:
			continue
		var ct: Variant = _resolver.get_combat_target(n)
		if ct == null or ct.is_dead():
			continue
		var pos: Vector3 = n.global_position
		if pos.distance_to(global_position) < STEP_RADIUS:
			_apply(ct, n)
			_finish(true)
			return true
	return false


func _apply(ct: Variant, target_node: Node) -> void:
	var req: Variant = preload(
			"res://scripts/gameplay/combat/damage_request.gd").new()
	req.source = _source
	req.target = target_node
	req.amount = _damage
	req.type = req.Type.RANGED
	req.position = global_position
	req.knockback_direction = direction
	_resolver.resolve(req)
	impact.emit(target_node)


func _finish(hit: bool) -> void:
	_alive = false
	if not hit:
		expired.emit()
	queue_free()


func _physics_process(delta: float) -> void:
	if not update(delta):
		set_physics_process(false)
