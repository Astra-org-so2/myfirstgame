# AttackData — one enemy attack (TECHNICAL_DESIGN §1).
# windup = the readable telegraph (0.4–0.8 s melee, GDD §6.2).
class_name AttackData
extends Resource

@export var windup: float = 0.5
@export var active: float = 0.15
@export var recovery: float = 0.8
@export_range(0.0, 999.0) var damage: int = 15
@export var knockback_force: float = 3.0
@export var knockback_duration: float = 0.3
@export var range: float = 1.8  # meters (horizontal)
@export_range(0.0, 360.0) var arc: float = 100.0  # degrees
# How loud the attack is (noise radius for enemy hearing; the player's
# own noise uses the same field semantics).
@export var noise_radius: float = 6.0


func duration() -> float:
	return windup + active + recovery
