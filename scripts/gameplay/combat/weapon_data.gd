# WeaponData — data-driven weapon definition (TECHNICAL_DESIGN §1).
#
# Phase 4 ships BLADE only (WEAPON_DESIGN §1); the schema already covers
# the three archetypes + FIRST BLADE (ranged/staff fields stay unused
# until Phases 6–8/12 — new weapons are data, not code rewrites).
class_name WeaponData
extends Resource

const _HIT = preload("res://scripts/gameplay/combat/weapon_hit.gd")

enum Type { MELEE, RANGED, STAFF }

@export var id: StringName = &""
@export var display_name: String = ""
@export var type: int = Type.MELEE

# Combo: ordered hits (U1..Un), WeaponHit resources (2–3 per
# WEAPON_DESIGN §0, no infinite combos). Plain Array (not a typed
# Array[WeaponHit]): script types cannot be .tres array tags.
@export var hits: Array = []
# Window after a swing ends during which the next swing continues the
# combo (instead of restarting at U1).
@export var combo_window: float = 0.5

# Special (per weapon; BLADE: Riposte, CANNON: Break). window = the
# counter window (Riposte) / unused (Break: 0), cooldown starts on
# activation.
@export var special_name: StringName = &""
@export var special_cooldown: float = 30.0
@export var special_window: float = 0.5
@export var special_stun_duration: float = 1.5
@export_range(0.0, 999.0) var special_damage: int = 15

# --- RANGED (HAND CANNON, WEAPON_DESIGN §2) ---
# Ammo is per-RUN (5/забег, not infinite); reload exists ONCE.
@export_range(0, 99) var ammo_max: int = 0
@export_range(0, 99) var ammo_reload_max: int = 0
@export var reload_time: float = 1.5
@export var fire_range: float = 15.0
@export_range(0.0, 90.0) var spread_deg: float = 3.0
# A fire wakes nearby enemies (the noise). QUIET STEP (Inheritance)
# zeroes this at the EFFECT level (data stays "loud"; the effect
# resolver decides what actually happens — ADR-025).
@export var noise_on_fire: bool = true

# --- STAFF (ECHO STAFF, WEAPON_DESIGN §3) ---
# The staff has NO combo hits: 4 actions with their own CDs. (The
# echo-targeting of Read/Disrupt lands with the Echo system, Phase 9;
# Shatter/Soothe work on combat targets from Phase 6.)
@export var staff_cast_time: float = 1.5
@export var staff_range: float = 10.0
@export var staff_read_range: float = 8.0
@export var staff_read_cd: float = 5.0
@export var staff_disrupt_cd: float = 10.0
@export var staff_soothe_cd: float = 15.0
@export var staff_soothe_duration: float = 3.0
@export var staff_shatter_cd: float = 20.0
@export_range(0.0, 999.0) var staff_shatter_damage: int = 40

# Feel (baseline values; tuned by the Phase 4 feel checklist, Phase 16).
@export var hitstop_hit: float = 0.05
@export var hitstop_kill: float = 0.1

# Prototype content (filled in Phase 13/14): model, VFX scenes, audio
# streams. SFX in Phase 4 is procedural (SfxLibrary) — audio fields below
# stay null by design until final assets exist.
@export var model_scene: PackedScene = null
@export var color_tint: Color = Color.WHITE
@export var swing_audio: AudioStream = null
@export var hit_audio: AudioStream = null


func validate() -> Array[String]:
	var problems: Array[String] = []
	if id == &"":
		problems.append("id must be set")
	if type == Type.MELEE and (hits.size() < 2 or hits.size() > 3):
		problems.append("melee combo must have 2..3 hits (got %d)"
				% hits.size())
	if type == Type.RANGED:
		if hits.size() != 1:
			problems.append("ranged weapon fires one shot (got %d hits)"
					% hits.size())
		if ammo_max < 1:
			problems.append("ranged weapon needs ammo_max >= 1")
		if fire_range <= 0.0:
			problems.append("fire_range must be > 0")
	if type == Type.STAFF:
		if hits.size() != 0:
			problems.append("staff uses actions, not combo hits")
		if staff_cast_time <= 0.0 or staff_range <= 0.0:
			problems.append("staff: cast_time and range must be > 0")
		if staff_read_cd <= 0.0 or staff_disrupt_cd <= 0.0 \
				or staff_soothe_cd <= 0.0 or staff_shatter_cd <= 0.0:
			problems.append("staff: all action CDs must be > 0")
		if staff_shatter_damage < 0 or staff_soothe_duration <= 0.0:
			problems.append("staff: shatter damage >= 0, soothe > 0")
	for i in hits.size():
		var h: _HIT = hits[i]
		if h == null:
			problems.append("hit %d is null" % i)
			continue
		if h.damage <= 0:
			problems.append("hit %d: damage must be > 0" % i)
		if h.windup <= 0.0 or h.active <= 0.0 or h.recovery <= 0.0:
			problems.append("hit %d: all phases must be > 0" % i)
		if h.range <= 0.0:
			problems.append("hit %d: range must be > 0" % i)
		if h.arc <= 0.0 or h.arc > 360.0:
			problems.append("hit %d: arc must be in (0, 360]" % i)
		if h.stamina_cost < 0:
			problems.append("hit %d: stamina_cost must be >= 0" % i)
	if special_name != &"":
		if special_cooldown <= 0.0:
			problems.append("special: cooldown must be > 0")
		if special_window < 0.0:
			problems.append("special: window must be >= 0")
		if special_damage < 0:
			problems.append("special: damage must be >= 0")
	if combo_window <= 0.0:
		problems.append("combo_window must be > 0")
	if hitstop_hit < 0.0 or hitstop_kill < hitstop_hit:
		problems.append("hitstop: expected 0 <= hit < kill")
	return problems
