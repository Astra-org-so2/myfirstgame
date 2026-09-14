# CombatTarget — the combat state of one entity (HP, invulnerability,
# stun). Plain RefCounted owned by the entity's controller; the entity
# pushes state it owns (invulnerability from dodge i-frames) and ticks
# this object each frame (stun decay).
#
# Only DamageResolver may reduce HP (ARCHITECTURE §3.2). No cross-script
# Callables are stored here (the headless rig crashes on cross-script
# Callable.call() — ADR-022): the owner reads signals instead.
class_name CombatTarget
extends RefCounted

const _DREQ = preload("res://scripts/gameplay/combat/damage_request.gd")

# Untyped parameters on purpose: cross-file class_name types are dead in
# the headless rig (ADR-022). `damaged` passes a DamageRequest.
signal damaged
signal killed()

var node: Node = null  # the owning node (position/id source)
var combat_id: StringName = &""
var max_hp: float = 100.0
var hp: float = 100.0
# Set by the owner each tick (e.g. player dodge i-frames).
var invulnerable: bool = false

var _stun_remaining: float = 0.0
var _dead: bool = false


func _init(p_node: Node, p_max_hp: float) -> void:
	node = p_node
	max_hp = p_max_hp
	hp = p_max_hp


func is_dead() -> bool:
	return _dead


func is_stunned() -> bool:
	return _stun_remaining > 0.0


func get_stun_remaining() -> float:
	return _stun_remaining


# One entity tick (owner calls): stun decay.
func update(delta: float) -> void:
	if _stun_remaining > 0.0:
		_stun_remaining = maxf(0.0, _stun_remaining - delta)


func apply_stun(duration: float) -> void:
	if duration > 0.0 and not _dead:
		_stun_remaining = maxf(_stun_remaining, duration)


# Resolver-only entry point (kept private by convention).
func _resolver_apply(amount: float, req: _DREQ) -> void:
	if _dead:
		return
	hp = maxf(0.0, hp - amount)
	if req.flags & _DREQ.FLAG_STUN and req.stun_duration > 0.0:
		_stun_remaining = maxf(_stun_remaining, req.stun_duration)
	damaged.emit(req)
	if hp <= 0.0 and not _dead:
		_dead = true
		killed.emit()


# Full reset (respawn).
func reset() -> void:
	hp = max_hp
	_stun_remaining = 0.0
	_dead = false
	invulnerable = false
