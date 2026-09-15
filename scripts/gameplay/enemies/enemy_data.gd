# EnemyData — data-driven enemy definition (TECHNICAL_DESIGN §1).
#
# 5 archetypes × 11 variants (ENEMY_DESIGN §6). Common fields +
# archetype fields (Watcher: observe/vanish/anchors; Mimic: punish
# table; Forgotten: whisper pool; Remnant: first-encounter speech;
# Hollow: memory window / retreat). New enemy = .tres, no code.
class_name EnemyData
extends Resource

const _ATTACK = preload("res://scripts/gameplay/enemies/attack_data.gd")
const _STYLE = preload("res://scripts/gameplay/memory_stats.gd")

enum Archetype { HOLLOW, REMNANT, WATCHER, MIMIC, FORGOTTEN }

@export var id: StringName = &""
@export var display_name: String = ""
@export var archetype: int = Archetype.HOLLOW
@export var variant: StringName = &"base"

# --- Vitals ---
@export_range(1, 9999) var health: int = 30
# MVP Watcher: cannot die (design: "not his to kill"); hp clamps at 1.
@export var unkillable: bool = false
@export var speed: float = 1.8  # m/s (ENEMY_DESIGN §1.6 baseline)
@export var sight_range: float = 10.0  # m
@export var fov: float = 120.0  # degrees
@export var hear_range: float = 5.0  # m (muted for explorer profile)
@export var aggro_radius: float = 10.0  # m (leash: returns to spawn beyond)

@export var attack: _ATTACK

# --- AI budget (TECHNICAL_DESIGN; measured on device, Phase 16) ---
@export var update_hz: float = 10.0
@export var path_update_hz: float = 5.0
@export var hitstun: float = 0.4

# --- Hollow ---
@export var memory_window: float = 10.0  # s of player path remembered
@export var retreat_after: float = 5.0  # s of player fleeing -> RETREAT
@export var leaves_footprint: bool = true  # visible next run (WORLD_STATE)

# --- Watcher (verb: observation -> memory anchor) ---
@export var observe_time: float = 2.0  # s of mutual eye-line
@export var follow_speed_mult: float = 0.4
@export var follow_range: float = 12.0  # m: follows while inside
@export var vanish_distance: float = 10.0  # m: teleport away at this range
@export var anchors_per_run: int = 2

# --- Mimic (mirror of dominant_style; punish patterns) ---
# Which style this variant mirrors (MemoryStats.STYLE_*; 0 = none).
@export var mirror_style: int = 0
@export var punish_dodge: float = 0.8  # evasive-dodge chance vs dodge-heavy
@export var punish_range: float = 1.2  # speed multiplier vs ranged-heavy
@export var punish_melee: float = 0.6  # combo interrupt vs melee-heavy
@export var punish_window: float = 0.5  # s counter window

# --- Remnant (combat Echo, built from run data — ADR-004/011) ---
@export var first_encounter_lines: PackedStringArray = [
		"You're early.", "You usually take longer.",
	]
@export var first_encounter_leaves: bool = true
@export var note_on_death: bool = true

# --- Forgotten (corrupted Echo; whispers the player's history) ---
@export var wander_radius: float = 15.0  # 0 = guard variant (no wander)
@export var whisper_pool: PackedStringArray = ["...where...?"]
@export var fragment_on_death: bool = true

# --- Speech / Death ---
# Spoken at spawn (Mimic: «I know how you do it.»; Forgotten: «…where…?»).
@export var spawn_line: String = ""
@export var dissolve_time: float = 0.3  # Forgotten: 3.0


func validate() -> Array[String]:
	var problems: Array[String] = []
	if id == &"":
		problems.append("id must be set")
	if health <= 0:
		problems.append("health must be > 0")
	if speed < 0.0:
		problems.append("speed must be >= 0")
	if sight_range <= 0.0 or fov <= 0.0 or fov > 360.0:
		problems.append("sight: range > 0, fov in (0, 360]")
	if hear_range < 0.0:
		problems.append("hear_range must be >= 0")
	if aggro_radius <= 0.0:
		problems.append("aggro_radius must be > 0")
	if attack == null:
		problems.append("attack data is required")
	else:
		if attack.windup < 0.3:
			# Readability floor (GDD §6.2: telegraphs 0.4–0.8 s melee;
			# Forgotten's 1.0 s is the slow-lane, 0.3 is the hard floor).
			problems.append("attack telegraph must be >= 0.3 s (readability)")
		if attack.damage < 0 or attack.range <= 0.0:
			problems.append("attack: damage >= 0, range > 0")
	if update_hz <= 0.0 or path_update_hz > update_hz:
		problems.append("ai budget: 0 < path_hz <= update_hz")
	if hitstun <= 0.0:
		problems.append("hitstun must be > 0")
	# Per-archetype invariants (ENEMY_DESIGN §6).
	match archetype:
		Archetype.WATCHER:
			if not unkillable:
				problems.append("watcher: must be unkillable in MVP")
			if attack != null and attack.damage > 0:
				problems.append("watcher: does not attack in MVP (dmg = 0)")
			if anchors_per_run < 1:
				problems.append("watcher: anchors_per_run >= 1")
		Archetype.MIMIC:
			if mirror_style != _STYLE.STYLE_MELEE \
					and mirror_style != _STYLE.STYLE_RANGED \
					and mirror_style != _STYLE.STYLE_DODGE:
				problems.append("mimic: mirror_style must be set "
						+ "(melee/ranged/dodge — 3 variants, §4.4)")
			if punish_dodge <= 0.0 or punish_range <= 1.0 \
					or punish_melee <= 0.0 or punish_window <= 0.0:
				problems.append("mimic: punish table must be fully set")
		Archetype.FORGOTTEN:
			if whisper_pool.is_empty():
				problems.append("forgotten: whisper pool must not be empty")
			if wander_radius < 0.0:
				problems.append("forgotten: wander_radius >= 0")
	return problems
