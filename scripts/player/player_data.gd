# Player tuning data (data-driven, ADR: gameplay data in Resources).
#
# Phase 2 defaults: no canonical movement numbers exist in the design docs
# (GDD §6.1 lists the actions only). These are the Phase 2 baseline values —
# tuned later by the feel checklist (Phase 4 feel pass + device QA, Phase 16).
class_name PlayerData
extends Resource

# --- Speeds (m/s) ---
@export var walk_speed: float = 4.0
@export var sprint_speed: float = 6.5
@export var dodge_speed: float = 9.0

# --- Acceleration / deceleration (m/s^2) ---
@export var ground_accel: float = 40.0
@export var ground_decel: float = 50.0
@export var air_accel: float = 15.0
@export var air_decel: float = 10.0
@export var turn_speed: float = 12.0  # rad/s, character faces input direction

# --- Gravity / fall ---
@export var gravity: float = 24.0
@export var max_fall_speed: float = 20.0

# --- Health (Phase 4: combat; baseline value, tuned by the feel/perf
#     checklists) ---
@export var health_max: int = 100

# --- Stamina ---
@export var stamina_max: float = 100.0
@export var sprint_drain_per_sec: float = 25.0
@export var sprint_min: float = 15.0  # below this: cannot START sprint
@export var stamina_regen_per_sec: float = 18.0
@export var stamina_regen_delay: float = 0.8  # after last use

# --- Dodge (i-frames) ---
@export var dodge_duration: float = 0.35
@export var dodge_iframe_start: float = 0.05  # seconds into the dodge
@export var dodge_iframe_end: float = 0.25
@export var dodge_cooldown: float = 0.4  # after the dodge ends
@export var dodge_stamina_cost: float = 20.0

# --- Hurt (hitstun; damage itself is Phase 4) ---
@export var hurt_duration: float = 0.35
@export var knockback_speed: float = 5.0
@export var knockback_up: float = 3.0
@export var knockback_decay: float = 6.0  # 1/s exponential


func validate() -> Array[String]:
	# Sanity invariants (tests call this; violations = design errors).
	var problems: Array[String] = []
	if walk_speed <= 0.0 or sprint_speed <= walk_speed or dodge_speed <= sprint_speed:
		problems.append("speeds: expected 0 < walk < sprint < dodge")
	if dodge_iframe_start < 0.0 or dodge_iframe_end <= dodge_iframe_start \
			or dodge_iframe_end >= dodge_duration:
		problems.append("dodge: expected 0 <= iframe_start < iframe_end < duration")
	if sprint_min <= 0.0 or sprint_min >= stamina_max:
		problems.append("stamina: expected 0 < sprint_min < max")
	if dodge_stamina_cost <= 0.0 or dodge_stamina_cost > stamina_max:
		problems.append("dodge cost must be in (0, stamina_max]")
	if sprint_drain_per_sec <= 0.0:
		problems.append("sprint drain must be > 0")
	if gravity <= 0.0:
		problems.append("gravity must be > 0")
	if health_max <= 0:
		problems.append("health_max must be > 0")
	return problems
