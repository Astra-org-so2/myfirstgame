# WeaponHit — one swing in a weapon's combo (TECHNICAL_DESIGN §1, WeaponData).
#
# Timing is split into windup/active/recovery so the active (hitbox-on)
# window is explicit data, not code. Durations sum to the swing time.
class_name WeaponHit
extends Resource

@export var name: StringName = &""
@export_range(0.0, 999.0) var damage: int = 0
@export var windup: float = 0.25
@export var active: float = 0.15
@export var recovery: float = 0.8
@export var range: float = 2.0  # meters (horizontal)
@export_range(0.0, 360.0) var arc: float = 110.0  # degrees, sector
@export var knockback_force: float = 4.0
@export var knockback_duration: float = 0.3
@export var stamina_cost: int = 10


func duration() -> float:
	return windup + active + recovery
