# InheritanceEffects — the bridge "Inheritance -> effective gameplay".
#
# An InheritanceData says WHICH stat of WHICH system it bends and to
# what value per level (PROGRESSION_DESIGN: "upgrades change gameplay,
# not +5%"). This resolver reads the WorldState ownership (level 0..3)
# and returns the EFFECTIVE numbers the controllers consume. The base
# data stays untouched (QUIET STEP: the cannon data is still "loud";
# the effect level decides what happens) — so a data diff never lies.
#
# Pure logic, no Node: unit-tested directly (the integration test
# proves the blade/cannon actually change in the scene).
class_name InheritanceEffects
extends RefCounted

const _WS = preload("res://scripts/gameplay/progression/world_state.gd")
const _DATA = preload("res://scripts/gameplay/progression/inheritance_data.gd")
const _WEAPON = preload("res://scripts/gameplay/combat/weapon_data.gd")
const _HIT = preload("res://scripts/gameplay/combat/weapon_hit.gd")

var _by_id: Dictionary = {}


func _init(all: Array) -> void:
	for d in all:
		_by_id[d.id] = d


func level(id: StringName, ws: _WS) -> int:
	return ws.inheritance_level(id)


# --- BLADE (SHARP, FLOW) ---
# u3_damage: the thrust (U3) damage; extra_hits: FLOW's added strikes
# (20 dmg / 1.5 s each, after U3).
func blade(base: _WEAPON, ws: _WS) -> Dictionary:
	var u3: _HIT = base.hits[2] if base.hits.size() > 2 else base.hits[-1]
	var sharp_lv: int = level(&"sharp", ws)
	var sharp_d: _DATA = _by_id.get(&"sharp")
	var u3_damage: float = float(u3.damage)
	if sharp_lv > 0 and sharp_d != null:
		u3_damage = sharp_d.effect_value(sharp_lv)
	var flow_d: _DATA = _by_id.get(&"flow")
	var flow_lv: int = level(&"flow", ws)
	var extra: int = 0
	if flow_lv > 0 and flow_d != null:
		extra = int(flow_d.effect_value(flow_lv))
	return {"u3_damage": u3_damage, "extra_hits": extra,
			"extra_hit_damage": 20.0, "extra_hit_windup": 0.3,
			"extra_hit_active": 0.15, "extra_hit_recovery": 1.05}


# --- CANNON (SLOW BURN, QUIET STEP) ---
func cannon(base: _WEAPON, ws: _WS) -> Dictionary:
	var sb_d: _DATA = _by_id.get(&"slow_burn")
	var sb_lv: int = level(&"slow_burn", ws)
	var break_cd: float = base.special_cooldown
	if sb_lv > 0 and sb_d != null:
		break_cd = sb_d.effect_value(sb_lv)
	var quiet_lv: int = level(&"quiet_step", ws)
	return {"break_cd": break_cd,
			"noise": base.noise_on_fire and quiet_lv == 0}


# --- STAFF (DEEP SIGHT, GENTLE HAND, post-MVP BREAKER) ---
func staff(base: _WEAPON, ws: _WS) -> Dictionary:
	var ds_d: _DATA = _by_id.get(&"deep_sight")
	var ds_lv: int = level(&"deep_sight", ws)
	var read_range: float = base.staff_read_range
	if ds_lv > 0 and ds_d != null:
		read_range = ds_d.effect_value(ds_lv)
	var gh_d: _DATA = _by_id.get(&"gentle_hand")
	var gh_lv: int = level(&"gentle_hand", ws)
	var soothe: float = base.staff_soothe_duration
	if gh_lv > 0 and gh_d != null:
		soothe = gh_d.effect_value(gh_lv)
	var br_d: _DATA = _by_id.get(&"breaker")
	var br_lv: int = level(&"breaker", ws)
	var disrupt: int = 1
	if br_lv > 0 and br_d != null:
		disrupt = int(br_d.effect_value(br_lv))
	return {"read_range": read_range, "soothe_duration": soothe,
			"disrupt_count": disrupt}


# --- PLAYER (ECHO STEP, SECOND CHANCE, post-MVP PARADOX/RUNNER) ---
func player(ws: _WS) -> Dictionary:
	var es_d: _DATA = _by_id.get(&"echo_step")
	var es_lv: int = level(&"echo_step", ws)
	var stun: float = 0.0
	if es_lv > 0 and es_d != null:
		stun = es_d.effect_value(es_lv)
	var sc_d: _DATA = _by_id.get(&"second_chance")
	var sc_lv: int = level(&"second_chance", ws)
	var charges: int = 0
	if sc_lv > 0 and sc_d != null:
		charges = int(sc_d.effect_value(sc_lv))
	var px_d: _DATA = _by_id.get(&"paradox")
	var px_lv: int = level(&"paradox", ws)
	var first_mult: float = 1.0
	if px_lv > 0 and px_d != null:
		first_mult = px_d.effect_value(px_lv)
	var rn_d: _DATA = _by_id.get(&"runner")
	var rn_lv: int = level(&"runner", ws)
	var retreat: float = 0.0
	if rn_lv > 0 and rn_d != null:
		retreat = rn_d.effect_value(rn_lv)
	return {"afterimage_stun": stun, "auto_dodge_charges": charges,
			"first_hit_mult": first_mult, "retreat_bonus": retreat}


# --- WORLD (EMBER, THE TRACK, THE PAGE, THE COMPASS) ---
func world(ws: _WS) -> Dictionary:
	var e: float = 0.0
	var ed: _DATA = _by_id.get(&"ember")
	var el: int = level(&"ember", ws)
	if el > 0 and ed != null:
		e = ed.effect_value(el)
	var tr: float = 0.0
	var td: _DATA = _by_id.get(&"the_track")
	var tl: int = level(&"the_track", ws)
	if tl > 0 and td != null:
		tr = td.effect_value(tl)
	var pg: int = 0
	var pd: _DATA = _by_id.get(&"the_page")
	var pl: int = level(&"the_page", ws)
	if pl > 0 and pd != null:
		pg = int(pd.effect_value(pl))
	var cm: int = 0
	var cd: _DATA = _by_id.get(&"the_compass")
	var cl: int = level(&"the_compass", ws)
	if cl > 0 and cd != null:
		cm = int(cd.effect_value(cl))
	return {"campfire_heal": e > 0.0, "trace_seconds": tr,
			"instant_reads": pg, "hidden_marks": cm}
