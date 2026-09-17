# Unit: weapons x3 data (WEAPON_DESIGN §5) + InheritanceEffects
# (the "Inheritance -> effective gameplay" bridge, PROGRESSION_DESIGN).
extends Node

const _WS = preload("res://scripts/gameplay/progression/world_state.gd")
const _DATA = preload("res://scripts/gameplay/progression/inheritance_data.gd")
const _WX = preload("res://scripts/gameplay/progression/inheritance_effects.gd")
const _WEAPON = preload("res://scripts/gameplay/combat/weapon_data.gd")


func _load_all() -> Array:
	var dir: String = "res://data/inheritances/"
	var files: PackedStringArray = PackedStringArray([
		"sharp.tres", "flow.tres", "slow_burn.tres", "quiet_step.tres",
		"deep_sight.tres", "gentle_hand.tres", "echo_step.tres",
		"second_chance.tres", "ember.tres", "the_track.tres",
		"the_page.tres", "the_compass.tres", "breaker.tres",
		"paradox.tres", "runner.tres"])
	var out: Array = []
	for f in files:
		out.append(load(dir + f))
	return out


func _grant(ws: _WS, id: StringName, times: int) -> void:
	for i in times:
		ws.add_inheritance(id, 3)


func run(ctx: Variant) -> void:
	# --- The three weapons + first blade load and validate ---
	var blade: _WEAPON = load("res://data/weapons/blade.tres")
	var cannon: _WEAPON = load("res://data/weapons/hand_cannon.tres")
	var staff: _WEAPON = load("res://data/weapons/echo_staff.tres")
	var first: _WEAPON = load("res://data/weapons/first_blade.tres")
	ctx.check(blade != null and blade.validate().size() == 0,
			"weapons: BLADE still valid after the schema extension")
	ctx.check(cannon != null and cannon.validate().size() == 0,
			"weapons: HAND CANNON data is valid")
	ctx.check(staff != null and staff.validate().size() == 0,
			"weapons: ECHO STAFF data is valid")
	ctx.check(first != null and first.validate().size() == 0,
			"weapons: THE FIRST BLADE data is valid (Phase 12 key)")
	ctx.check(cannon.ammo_max == 5 and cannon.ammo_reload_max == 1
			and cannon.special_cooldown == 60.0
			and cannon.special_damage == 120,
			"weapons: cannon 5 ammo / 1 reload / Break 60 s / 120 (data)")
	ctx.check(staff.staff_soothe_duration == 3.0
			and staff.staff_shatter_damage == 40
			and staff.staff_read_range == 8.0,
			"weapons: staff base actions (soothe 3 s, shatter 40, "
					+ "read 8 m)")

	# --- Effects with NO inheritances: base stats, nothing bends ---
	var all: Array = _load_all()
	var fx: _WX = _WX.new(all)
	var ws0: _WS = _WS.new()
	var b0: Dictionary = fx.blade(blade, ws0)
	ctx.check(b0["u3_damage"] == 30.0 and b0["extra_hits"] == 0,
			"effects: no inheritance -> blade base (U3 30, no extra)")
	var c0: Dictionary = fx.cannon(cannon, ws0)
	ctx.check(c0["break_cd"] == 60.0 and c0["noise"] == true,
			"effects: no inheritance -> cannon base (Break 60 s, loud)")
	var s0: Dictionary = fx.staff(staff, ws0)
	ctx.check(s0["read_range"] == 8.0 and s0["soothe_duration"] == 3.0
			and s0["disrupt_count"] == 1,
			"effects: no inheritance -> staff base (read 8, soothe 3)")
	var p0: Dictionary = fx.player(ws0)
	ctx.check(p0["auto_dodge_charges"] == 0 and p0["afterimage_stun"] == 0.0
			and p0["first_hit_mult"] == 1.0 and p0["retreat_bonus"] == 0.0,
			"effects: no inheritance -> player base")
	var w0: Dictionary = fx.world(ws0)
	ctx.check(w0["campfire_heal"] == false and w0["trace_seconds"] == 0.0,
			"effects: no inheritance -> world base")

	# --- SHARP: U3 30 -> 45 -> 55 -> 65 (the levels) ---
	var ws1: _WS = _WS.new()
	ctx.check(ws1.add_inheritance(&"sharp", 3) == 1
			and fx.blade(blade, ws1)["u3_damage"] == 45.0,
			"effects: SHARP level 1 -> U3 45")
	ctx.check(ws1.add_inheritance(&"sharp", 3) == 2
			and fx.blade(blade, ws1)["u3_damage"] == 55.0,
			"effects: SHARP level 2 -> U3 55")
	ctx.check(ws1.add_inheritance(&"sharp", 3) == 3
			and fx.blade(blade, ws1)["u3_damage"] == 65.0,
			"effects: SHARP level 3 -> U3 65")

	# --- FLOW: the fourth strike waits (+20 dmg extra hits) ---
	var ws2: _WS = _WS.new()
	ws2.add_inheritance(&"flow", 3)
	var b2: Dictionary = fx.blade(blade, ws2)
	ctx.check(b2["extra_hits"] == 1 and b2["extra_hit_damage"] == 20.0,
			"effects: FLOW level 1 -> 1 extra strike (20 dmg)")
	ws2.add_inheritance(&"flow", 3)
	ctx.check(fx.blade(blade, ws2)["extra_hits"] == 2,
			"effects: FLOW level 2 -> 2 extra strikes")
	# SHARP + FLOW together: the thrust keeps its upgrade.
	ws2.add_inheritance(&"sharp", 3)
	var b2b: Dictionary = fx.blade(blade, ws2)
	ctx.check(b2b["u3_damage"] == 45.0 and b2b["extra_hits"] == 2,
			"effects: SHARP + FLOW compose (45 + 2 extra)")

	# --- SLOW BURN / QUIET STEP ---
	var ws3: _WS = _WS.new()
	ws3.add_inheritance(&"slow_burn", 3)
	ws3.add_inheritance(&"quiet_step", 3)
	var c3: Dictionary = fx.cannon(cannon, ws3)
	ctx.check(c3["break_cd"] == 40.0 and c3["noise"] == false,
			"effects: SLOW BURN -> Break 40 s; QUIET STEP -> silent")
	# The DATA still says "loud" (the effect level is what decides).
	ctx.check(cannon.noise_on_fire == true,
			"effects: the base data never lies (cannon data = loud)")

	# --- DEEP SIGHT / GENTLE HAND / (post-MVP) BREAKER ---
	var ws4: _WS = _WS.new()
	_grant(ws4, &"deep_sight", 1)
	_grant(ws4, &"gentle_hand", 2)
	_grant(ws4, &"breaker", 1)
	var s4: Dictionary = fx.staff(staff, ws4)
	ctx.check(s4["read_range"] == 12.0,
			"effects: DEEP SIGHT level 1 -> read 12 m")
	ctx.check(s4["soothe_duration"] == 6.0,
			"effects: GENTLE HAND level 2 -> soothe 6 s")
	ctx.check(s4["disrupt_count"] == 2,
			"effects: BREAKER level 1 -> disrupt 2 (post-MVP path works)")

	# --- Player effects ---
	var ws5: _WS = _WS.new()
	_grant(ws5, &"echo_step", 2)
	_grant(ws5, &"second_chance", 1)
	var p5: Dictionary = fx.player(ws5)
	ctx.check(p5["afterimage_stun"] == 0.75,
			"effects: ECHO STEP level 2 -> 0.75 s afterimage stun")
	ctx.check(p5["auto_dodge_charges"] == 1,
			"effects: SECOND CHANCE level 1 -> 1 auto-dodge per run")
	# Post-MVP gates (architecture-ready):
	_grant(ws5, &"paradox", 1)
	_grant(ws5, &"runner", 2)
	var p5b: Dictionary = fx.player(ws5)
	ctx.check(p5b["first_hit_mult"] == 1.4,
			"effects: PARADOX level 1 -> first hit x1.4 (post-MVP)")
	ctx.check(p5b["retreat_bonus"] == 3.0,
			"effects: RUNNER level 2 -> retreat +3 s (post-MVP)")

	# --- World effects ---
	var ws6: _WS = _WS.new()
	_grant(ws6, &"ember", 1)
	_grant(ws6, &"the_track", 1)
	_grant(ws6, &"the_page", 1)
	_grant(ws6, &"the_compass", 1)
	var w6: Dictionary = fx.world(ws6)
	ctx.check(w6["campfire_heal"] == true,
			"effects: EMBER -> the camp fire heals")
	ctx.check(w6["trace_seconds"] == 120.0,
			"effects: THE TRACK -> 120 s of trails")
	ctx.check(w6["instant_reads"] == 1 and w6["hidden_marks"] == 1,
			"effects: THE PAGE / THE COMPASS -> 1 per run each")
