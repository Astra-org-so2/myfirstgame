# DamageRequest — input to DamageResolver (ARCHITECTURE §3.2).
#
# A request is data only; the resolver is the single place where damage
# is applied (no ad-hoc "target.take_damage(...)" anywhere else).
# Plain RefCounted so it is constructible/testable in the headless rig.
class_name DamageRequest
extends RefCounted

enum Type { MELEE, RANGED, STAFF, SPECIAL }

# Flag: apply a stun on the target (duration from stun_duration).
const FLAG_STUN: int = 1
# Flag: this hit is a riposte counter (used for feel/SFX routing).
const FLAG_RIPOSTE: int = 2

var source: Node = null  # the attacker node (null = environment)
var target: Node = null  # the victim node (must be resolver-registered)
var amount: float = 0.0
var type: int = Type.MELEE
var position: Vector3 = Vector3.ZERO  # effect position (VFX anchor)
# Knockback direction: attacker -> target (horizontal), already normalized
# by the sender. Magnitude semantics are target-side (player knockback
# data / enemy data).
var knockback_direction: Vector3 = Vector3.ZERO
var weapon: Resource = null  # WeaponData, nullable
var flags: int = 0
var stun_duration: float = 0.0
