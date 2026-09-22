# DamageResult — output of DamageResolver (ARCHITECTURE §3.2).
class_name DamageResult
extends RefCounted

var applied: float = 0.0
var blocked: bool = false
# "none" | "invulnerable" | "unknown_target" | "dead_target"
var blocked_reason: StringName = &"none"
var killed: bool = false
var source: Node = null
var target: Node = null
var position: Vector3 = Vector3.ZERO
var weapon: Resource = null
var flags: int = 0
var target_hp: float = 0.0
