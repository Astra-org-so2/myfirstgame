# BossData — THE FIRST's stats (BOSS_DESIGN §3.1, data-driven:
# "no core rewrites" — a new boss = a .tres).
#
# A separate resource (NOT EnemyData): the boss has TWO attacks
# (melee + slam), the pattern-memory parameters and the core
# ("the seal") — EnemyData's single-attack schema doesn't fit.
class_name BossData
extends Resource

const _ATTACK = preload("res://scripts/gameplay/enemies/attack_data.gd")

@export var id: StringName = &""
@export var display_name: String = ""

# --- Vitals (Q-B1: 5-8 min, "boss = act end") ---
@export_range(1, 9999) var health: int = 600
@export var speed: float = 2.2  # phase 1 (85% player, the design value)
@export var speed_phase2: float = 2.33  # 90% player
# Phase 2 starts at this fraction of max hp (0.6 = 60%).
@export_range(0.0, 1.0) var phase2_threshold: float = 0.6

# --- Attacks (telegraphs 0.4-0.8 s, GDD §6.2 fairness) ---
@export var melee: _ATTACK
@export var slam: _ATTACK

# --- The core ("the seal", BOSS_DESIGN §3.3) ---
# The window after a slam; FIRST BLADE extends it.
@export var core_window: float = 2.0  # s (base)
@export var core_window_blade: float = 4.0  # s (FIRST BLADE)
@export_range(0, 999) var core_damage: int = 50  # with FIRST BLADE
@export_range(0, 999) var core_damage_plain: int = 30  # without it
# The glow that opens the window (fairness: the core is not hidden).
@export var core_glow_time: float = 0.5

# --- Pattern memory (BOSS_DESIGN §3.2, GDD §6.10) ---
# Learn a 3-step sequence repeated `pattern_memory` times -> parry
# the next occurrence; `break_steps` "not his" steps -> lose rhythm.
@export_range(2, 10) var pattern_length: int = 3
@export_range(2, 10) var pattern_threshold: int = 3
@export_range(0.0, 5.0) var parry_window: float = 0.4  # s
@export_range(0, 999) var parry_damage: int = 25  # the counter
@export_range(1, 10) var break_steps: int = 3
@export_range(0.0, 10.0) var break_stun: float = 1.5  # s, vulnerable
# The "head look" signal when he has learned (0.3 s) + the line
# (30 s cooldown).
@export var look_time: float = 0.3
@export var learn_line_cooldown: float = 30.0
# Phase 2: the memory is sharpened (threshold 2, BOSS_DESIGN §3.4).
@export_range(2, 10) var pattern_threshold_phase2: int = 2

# --- The Remnant minion (phase 2, BOSS_DESIGN §3.4) ---
# "Your best run" (ECHO_SYSTEM_DESIGN §3): a mirror, not an enemy —
# it LEAVES (fades) at minion_fade_pct, it is not killed.
@export_range(1, 999) var minion_health: int = 80
@export_range(0, 999) var minion_damage: int = 15
@export_range(1.0, 99.0) var minion_fade_pct: float = 50.0
@export var minion_id: StringName = &"remnant_mirror"

# --- Death sequence (K6 -> K7, BOSS_DESIGN §4) ---
@export var dissolve_time: float = 3.0
@export var final_line_delay: float = 2.0  # the 2 s of silence


func validate() -> Array[String]:
	var problems: Array[String] = []
	if id == &"":
		problems.append("boss: id is empty")
	if health < 10:
		problems.append("boss: health too low to be a fight")
	if phase2_threshold <= 0.0 or phase2_threshold >= 1.0:
		problems.append("boss: phase2_threshold must be in (0, 1)")
	if melee == null or slam == null:
		problems.append("boss: melee/slam attack data missing")
	if pattern_length < 2 or pattern_threshold < 2:
		problems.append("boss: pattern memory below the design floor")
	if core_window_blade < core_window:
		problems.append("boss: the blade must EXTEND the core window")
	if core_damage < core_damage_plain:
		problems.append("boss: the blade must DEAL MORE core damage")
	if minion_fade_pct <= 0.0 or minion_fade_pct >= 100.0:
		problems.append("boss: minion_fade_pct out of range")
	return problems
