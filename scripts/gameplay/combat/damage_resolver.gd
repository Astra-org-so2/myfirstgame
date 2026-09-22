# DamageResolver — the single damage application point (ARCHITECTURE
# §3.2). Input: DamageRequest; output: DamageResult + signals.
#
# Targets register their CombatTarget here; nothing else may reduce HP.
# The resolver is scene-composed (NOT an autoload — the fixed autoload
# list, ARCHITECTURE §6): the main scene creates it and hands it to the
# player weapon controller (and, from Phase 5, enemies).
#
# EventBus integration is tolerant (get_node_or_null): unit tests run the
# resolver without the autoload present.
class_name DamageResolver
extends Node

const _CT = preload("res://scripts/gameplay/combat/combat_target.gd")
const _DREQ = preload("res://scripts/gameplay/combat/damage_request.gd")
const _DRES = preload("res://scripts/gameplay/combat/damage_result.gd")

# damage_applied passes a DamageResult; target_killed passes the victim
# node (cross-file script types in signal params are dead in the rig —
# ADR-022).
signal damage_applied
signal target_killed

var _targets: Dictionary = {}  # node -> CombatTarget


func register(node: Node, target: _CT) -> void:
	if node == null or target == null:
		push_error("DamageResolver: register(node, target) with nulls")
		return
	if _targets.has(node):
		push_error("DamageResolver: double register for the same node")
		return
	_targets[node] = target


func unregister(node: Node) -> void:
	_targets.erase(node)


func get_combat_target(node: Node) -> _CT:
	var t: Variant = _targets.get(node, null)
	return t if t != null else null


func get_target_nodes() -> Array:
	return _targets.keys()


func resolve(req: _DREQ) -> _DRES:
	var res: _DRES = _DRES.new()
	res.source = req.source
	res.target = req.target
	res.position = req.position
	res.weapon = req.weapon
	res.flags = req.flags

	var ct: _CT = get_combat_target(req.target)
	if ct == null:
		push_error("DamageResolver: target %s is not registered"
				% _node_name(req.target))
		res.blocked = true
		res.blocked_reason = &"unknown_target"
		return res
	if ct.is_dead():
		res.blocked = true
		res.blocked_reason = &"dead_target"
		return res
	if ct.invulnerable:
		res.blocked = true
		res.blocked_reason = &"invulnerable"
		res.target_hp = ct.hp
		return res

	var amount: float = maxf(0.0, req.amount)
	ct._resolver_apply(amount, req)
	res.applied = amount
	res.target_hp = ct.hp
	if ct.is_dead():
		res.killed = true
		target_killed.emit(req.target)
		_emit_bus_killed(ct)
	damage_applied.emit(res)
	return res


func _emit_bus_killed(ct: _CT) -> void:
	var bus: Node = get_node_or_null("/root/EventBus")
	if bus != null and bus.has_signal("target_killed"):
		var pos: Vector3 = Vector3.ZERO
		if ct.node != null:
			pos = ct.node.global_position
		bus.target_killed.emit(ct.combat_id, pos)


func _node_name(n: Node) -> String:
	return n.name if n != null else "<null>"
