# Unit: WorldState + InheritanceManager + NpcTrust (PROGRESSION_DESIGN).
#
# Covers: the MVP pool (12 = 8 basic + 4 NPC-gated), the NPC gate as a
# PERMANENT price (dead NPC -> Inheritance never in the pool again),
# the behavior gate architecture (RUNNER: fled > 10, data-disabled for
# MVP), the 3-card offer (2 new + repeat, repeat max 2), the permanent
# choice (level 1..3), and the trust 0-1-2 rules (2 interactions +
# help, then 4 + the NPC-specific memory stat).
extends Node

const _WS = preload("res://scripts/gameplay/progression/world_state.gd")
const _DATA = preload("res://scripts/gameplay/progression/inheritance_data.gd")
const _MGR = preload("res://scripts/gameplay/progression/inheritance_manager.gd")
const _NPC_DATA = preload("res://scripts/gameplay/progression/npc_data.gd")
const _TRUST = preload("res://scripts/gameplay/progression/npc_trust.gd")
const _ROSTER = preload("res://scripts/gameplay/progression/npc_roster.gd")
const _STYLE = preload("res://scripts/gameplay/memory_stats.gd")


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
		var d: _DATA = load(dir + f)
		out.append(d)
	return out


func _rng(seed: int) -> RandomNumberGenerator:
	var r: RandomNumberGenerator = RandomNumberGenerator.new()
	r.seed = seed
	return r


func run(ctx: Variant) -> void:
	var all: Array = _load_all()
	ctx.check(all.size() == 15, "inheritance: 15 Inheritances in data")
	var ok_data: bool = true
	for d in all:
		if d.validate().size() > 0:
			ok_data = false
			ctx.check(false, "inheritance: %s invalid: %s"
					% [d.id, str(d.validate())])
	ctx.check(ok_data, "inheritance: all 15 pass validate()")

	# --- WorldState basics ---
	var ws: _WS = _WS.new()
	ws.set_flag(&"blade_found")
	ctx.check(ws.get_flag(&"blade_found") == true,
			"world: flag set/read")
	ctx.check(ws.get_flag(&"nope") == false,
			"world: missing flag -> default")
	ws.set_weapon_found(&"cannon")
	ctx.check(ws.is_weapon_found(&"cannon")
			and not ws.is_weapon_found(&"staff"),
			"world: weapon found is permanent + per-weapon")
	var e: Dictionary = ws.npc_entry(&"mara")
	ctx.check(e.alive and e.trust == 0,
			"world: npc entry defaults (alive, trust 0)")
	ws.kill_npc(&"mara")
	ctx.check(not ws.is_npc_alive(&"mara") and ws.npc_entry(&"mara").trust == 0,
			"world: npc death resets trust (the price)")

	# --- The MVP pool: 12 (8 basic + 4 NPC-gated, all trusted) ---
	var ws2: _WS = _WS.new()
	for nid in [&"mara", &"orren", &"nia", &"cartographer"]:
		var entry: Dictionary = ws2.npc_entry(nid)
		entry.trust = 1
	var mgr: _MGR = _MGR.new()
	var stats: _STYLE = _STYLE.new()
	var pool: Array = mgr.get_pool(ws2, stats, all)
	ctx.check(pool.size() == 12,
			"inheritance: MVP pool = 12 (got %d)" % pool.size())
	var has_ember: bool = false
	for d in pool:
		if d.id == &"ember":
			has_ember = true
	ctx.check(has_ember, "inheritance: trusted Mara's EMBER is in the pool")

	# --- NPC gate: trust 0 -> NOT in the pool ---
	var ws3: _WS = _WS.new()
	var pool3: Array = mgr.get_pool(ws3, stats, all)
	ctx.check(pool3.size() == 8,
			"inheritance: no trust yet -> only the 8 basic (got %d)"
					% pool3.size())
	for d in pool3:
		ctx.check(d.layer == _DATA.Layer.BASIC,
				"inheritance: untrusted NPC-gated stays out (%s)" % d.id)
		break

	# --- NPC death = PERMANENT: kill Mara -> EMBER never returns ---
	var ws4: _WS = _WS.new()
	for nid in [&"mara", &"orren", &"nia", &"cartographer"]:
		ws4.npc_entry(nid).trust = 1
	ws4.kill_npc(&"mara")  # trust was 1, but death resets the price
	var pool4: Array = mgr.get_pool(ws4, stats, all)
	var ember_back: bool = false
	for d in pool4:
		if d.id == &"ember":
			ember_back = true
	ctx.check(pool4.size() == 11 and not ember_back,
			"inheritance: dead NPC -> gift gone forever (pool 11)")

	# --- Behavior gate architecture (RUNNER: fled > 10) ---
	var runner: _DATA = null
	for d in all:
		if d.id == &"runner":
			runner = d
	ctx.check(runner != null and not runner.in_mvp_pool,
			"inheritance: RUNNER is data-disabled for the MVP pool")
	ctx.check(not mgr.behavior_passed(stats, runner),
			"inheritance: RUNNER gate closed at fled=0")
	stats.fled = 10
	ctx.check(not mgr.behavior_passed(stats, runner),
			"inheritance: RUNNER gate closed at fled=10 (needs >10)")
	stats.fled = 11
	ctx.check(mgr.behavior_passed(stats, runner),
			"inheritance: RUNNER gate opens at fled=11")
	# Enable it by data (a new Inheritance / pool change = data, not code):
	var runner_on: _DATA = runner.duplicate()
	runner_on.in_mvp_pool = true
	var pool5: Array = mgr.get_pool(ws2, stats, all + [runner_on])
	var runner_in: bool = false
	for d in pool5:
		if d.id == &"runner":
			runner_in = true
	ctx.check(runner_in and pool5.size() == 13,
			"inheritance: enabled RUNNER enters the pool (13)")

	# --- The offer: 2 new + 1 repeat ---
	var ws5: _WS = _WS.new()
	for nid in [&"mara", &"orren", &"nia", &"cartographer"]:
		ws5.npc_entry(nid).trust = 1
	ws5.add_inheritance(&"sharp", _MGR.MAX_LEVEL)  # 1 owned (repeat-able)
	var offer: Array = mgr.roll_offer(ws5, stats, all, _rng(7))
	ctx.check(offer.size() == 3,
			"inheritance: the offer is 3 cards (got %d)" % offer.size())
	var new_in_offer: int = 0
	var repeats_in_offer: int = 0
	for d in offer:
		if ws5.is_inheritance_owned(d.id):
			repeats_in_offer += 1
		else:
			new_in_offer += 1
	ctx.check(new_in_offer == 2 and repeats_in_offer == 1,
			"inheritance: offer = 2 new + 1 repeat (%d/%d)"
					% [new_in_offer, repeats_in_offer])

	# --- The repeat cap: level 3 is not a repeat candidate ---
	var ws6: _WS = _WS.new()
	for i in _MGR.MAX_LEVEL:
		ws6.add_inheritance(&"sharp", _MGR.MAX_LEVEL)
	var offer6: Array = mgr.roll_offer(ws6, stats, all, _rng(7))
	var maxed_in: bool = false
	for d in offer6:
		if d.id == &"sharp":
			maxed_in = true
	ctx.check(not maxed_in,
			"inheritance: a maxed (level 3) Inheritance is not offered again")

	# --- Determinism: same seed -> same offer ---
	var o_a: Array = mgr.roll_offer(ws5, stats, all, _rng(42))
	var o_b: Array = mgr.roll_offer(ws5, stats, all, _rng(42))
	var same: bool = o_a.size() == o_b.size()
	for i in o_a.size():
		if o_a[i].id != o_b[i].id:
			same = false
	ctx.check(same, "inheritance: the same seed rolls the same offer")

	# --- The choice is PERMANENT, levels 1..3 ---
	var ws7: _WS = _WS.new()
	var sharp: _DATA = null
	for d in all:
		if d.id == &"sharp":
			sharp = d
	ctx.check(mgr.apply_choice(ws7, sharp) == 1,
			"inheritance: first choice -> level 1")
	ctx.check(mgr.apply_choice(ws7, sharp) == 2,
			"inheritance: repeat -> level 2")
	ctx.check(mgr.apply_choice(ws7, sharp) == 3,
			"inheritance: repeat -> level 3")
	ctx.check(mgr.apply_choice(ws7, sharp) == 3,
			"inheritance: level 3 is the cap")
	ws7.kill_npc(&"mara")  # unrelated here; permanence check:
	ctx.check(ws7.inheritance_level(&"sharp") == 3
			and ws7.owned_inheritances().size() == 1,
			"inheritance: ownership is permanent (survives anything)")

	# --- Trust 0-1-2 (PROGRESSION_DESIGN §4) ---
	var roster: _ROSTER = load("res://data/npcs/npc_state.tres")
	ctx.check(roster != null and roster.all().size() == 4,
			"trust: the roster loads 4 NPCs")
	var mara_d: _NPC_DATA = roster.npc(&"mara")
	ctx.check(mara_d != null and mara_d.validate().size() == 0,
			"trust: Mara's data is valid")
	var trust: _TRUST = _TRUST.new()
	# A FRESH state (ws7's Mara was killed above — trust 0 is "no").
	var ws9: _WS = _WS.new()
	var me: Dictionary = ws9.npc_entry(&"mara")
	var mstats: _STYLE = _STYLE.new()
	ctx.check(trust.trust_level(me, mara_d, mstats) == 0,
			"trust: starts at 0")
	var lvl: int = trust.interact(me, mara_d, mstats)
	ctx.check(lvl == 0, "trust: 1 interaction, no help -> 0")
	lvl = trust.interact(me, mara_d, mstats)
	ctx.check(lvl == 0, "trust: 2 interactions, no help -> still 0")
	lvl = trust.complete_help(me, mara_d, mstats)
	ctx.check(lvl == 1, "trust: 2 interactions + the help -> 1")
	# Trust 2: 4 interactions + Mara's stat (notes_written > 2).
	mstats.notes_written = 2
	lvl = trust.interact(me, mara_d, mstats)  # 3
	ctx.check(trust.trust_level(me, mara_d, mstats) == 1,
			"trust: 3 interactions -> still 1")
	lvl = trust.interact(me, mara_d, mstats)  # 4
	ctx.check(trust.trust_level(me, mara_d, mstats) == 1,
			"trust: 4 interactions, notes=2 (needs >2) -> still 1")
	mstats.notes_written = 3
	ctx.check(trust.trust_level(me, mara_d, mstats) == 2,
			"trust: 4 interactions + notes_written=3 -> 2")
	# Death: trust resets, "no".
	trust.kill(me)
	ctx.check(trust.trust_level(me, mara_d, mstats) == 0,
			"trust: a dead NPC trusts nobody")

	# --- The gift line: trust 1 opens the gate (pool check end-to-end) ---
	var ws8: _WS = _WS.new()
	var me8: Dictionary = ws8.npc_entry(&"mara")
	var roster_mara: _NPC_DATA = roster.npc(&"mara")
	trust.interact(me8, roster_mara, mstats)
	trust.interact(me8, roster_mara, mstats)
	trust.complete_help(me8, roster_mara, mstats)
	var pool8: Array = mgr.get_pool(ws8, mstats, all)
	var ember8: bool = false
	for d in pool8:
		if d.id == &"ember":
			ember8 = true
	ctx.check(ember8 and pool8.size() == 9,
			"trust: trust 1 puts EMBER in the pool (9 total)")
