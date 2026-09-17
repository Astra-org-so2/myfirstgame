# Unit: WeaponData (blade) — data loads and matches WEAPON_DESIGN §1,
# validate() rejects broken data. Cross-file refs via preload-consts
# (ADR-022).
extends Node

const _DATA = preload("res://scripts/gameplay/combat/weapon_data.gd")
const _HIT = preload("res://scripts/gameplay/combat/weapon_hit.gd")

const EPS: float = 0.001


func run(ctx: Variant) -> void:
	var res: Resource = load("res://data/weapons/blade.tres")
	ctx.check(res != null and res is _DATA, "weapon_data: blade.tres loads")
	if res == null:
		return
	var w: _DATA = res

	# 1. Schema invariants.
	var problems: Array[String] = w.validate()
	ctx.check(problems.is_empty(),
			"weapon_data: blade passes validate() (%s)"
			% ("; ".join(problems) if not problems.is_empty() else "ok"))
	ctx.check(w.id == &"weapon_blade", "weapon_data: id is weapon_blade")
	ctx.check(w.type == _DATA.Type.MELEE, "weapon_data: type is melee")
	ctx.check(w.hits.size() == 3, "weapon_data: 3-hit combo (got %d)"
			% w.hits.size())

	# 2. Design numbers (WEAPON_DESIGN §1.2/§1.3: 25/25/30, 1.2/1.2/1.5 s).
	var expected_damage: Array[int] = [25, 25, 30]
	var expected_time: Array[float] = [1.2, 1.2, 1.5]
	for i in w.hits.size():
		var h: _HIT = w.hits[i]
		ctx.check(h != null and h.damage == expected_damage[i],
				"weapon_data: hit %d damage = %d" % [i, expected_damage[i]])
		ctx.check(h != null and absf(h.duration() - expected_time[i]) < EPS,
				"weapon_data: hit %d duration = %.2f s"
				% [i, expected_time[i]])
	var h1: _HIT = w.hits[0]
	var h3: _HIT = w.hits[2]
	ctx.check(absf(h1.range - 2.0) < EPS and absf(h1.arc - 110.0) < EPS,
			"weapon_data: U1 range 2.0 m / arc 110 deg")
	ctx.check(absf(h3.range - 2.6) < EPS,
			"weapon_data: U3 thrust range 2.6 m (longer)")
	ctx.check(h1.stamina_cost == 10, "weapon_data: 10 stamina per swing")

	# 3. Special: Riposte (0.5 s window, 30 s CD, stun 1.5 s, 15 dmg).
	ctx.check(w.special_name == &"riposte", "weapon_data: special is Riposte")
	ctx.check(absf(w.special_cooldown - 30.0) < EPS,
			"weapon_data: riposte cooldown 30 s")
	ctx.check(absf(w.special_window - 0.5) < EPS,
			"weapon_data: riposte window 0.5 s")
	ctx.check(absf(w.special_stun_duration - 1.5) < EPS,
			"weapon_data: riposte stun 1.5 s")
	ctx.check(w.special_damage == 15, "weapon_data: riposte 15 dmg")
	ctx.check(absf(w.combo_window - 0.5) < EPS,
			"weapon_data: combo window 0.5 s")

	# 4. Negative paths: validate() rejects broken data.
	var empty: _DATA = _DATA.new()
	ctx.check(not empty.validate().is_empty(),
			"weapon_data: empty weapon rejected")

	var one_hit: _DATA = _copy(w)
	one_hit.hits = [w.hits[0]]
	ctx.check(not one_hit.validate().is_empty(),
			"weapon_data: single-hit combo rejected")

	var bad_arc: _DATA = _copy(w)
	var hits_bad_arc: Array = [w.hits[0], w.hits[1], _clone_hit(w.hits[2])]
	hits_bad_arc[2].arc = 400.0
	bad_arc.hits = hits_bad_arc
	ctx.check(not bad_arc.validate().is_empty(),
			"weapon_data: arc > 360 rejected")

	# Phase 6: a ZERO window is valid for burst specials (cannon
	# Break); only a NEGATIVE window is malformed.
	var neg_window: _DATA = _copy(w)
	neg_window.special_window = -1.0
	ctx.check(not neg_window.validate().is_empty(),
			"weapon_data: negative special window rejected")
	var burst_window: _DATA = _copy(w)
	burst_window.special_window = 0.0
	ctx.check(burst_window.validate().is_empty(),
			"weapon_data: zero window allowed (burst special, cannon "
					+ "Break)")

	var zero_combo: _DATA = _copy(w)
	zero_combo.combo_window = 0.0
	ctx.check(not zero_combo.validate().is_empty(),
			"weapon_data: zero combo window rejected")

	var bad_hitstop: _DATA = _copy(w)
	bad_hitstop.hitstop_kill = 0.0
	ctx.check(not bad_hitstop.validate().is_empty(),
			"weapon_data: kill hitstop < hit hitstop rejected")


func _clone_hit(src: _HIT) -> _HIT:
	var h: _HIT = _HIT.new()
	h.name = src.name
	h.damage = src.damage
	h.windup = src.windup
	h.active = src.active
	h.recovery = src.recovery
	h.range = src.range
	h.arc = src.arc
	h.knockback_force = src.knockback_force
	h.knockback_duration = src.knockback_duration
	h.stamina_cost = src.stamina_cost
	return h


func _copy(src: _DATA) -> _DATA:
	var d: _DATA = _DATA.new()
	d.id = src.id
	d.display_name = src.display_name
	d.type = src.type
	d.hits = src.hits
	d.combo_window = src.combo_window
	d.special_name = src.special_name
	d.special_cooldown = src.special_cooldown
	d.special_window = src.special_window
	d.special_stun_duration = src.special_stun_duration
	d.special_damage = src.special_damage
	d.hitstop_hit = src.hitstop_hit
	d.hitstop_kill = src.hitstop_kill
	return d
