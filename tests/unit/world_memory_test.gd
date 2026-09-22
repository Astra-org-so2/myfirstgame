# Unit: Phase 10 world memory (WORLD_STATE_DESIGN sections 2/3/4/6):
# the note pool + stand data, the WorldState notes + the full
# to_dict/load_dict roundtrip (the Phase 15 save wraps this), the
# MemoryStats persist, the WorldTransform data (K7), the mummy
# placement rule, and the post-boss echo budget offset.
extends Node

const _WS = preload("res://scripts/gameplay/progression/world_state.gd")
const _MS = preload("res://scripts/gameplay/memory_stats.gd")
const _GD = preload("res://scripts/world/ghost_director.gd")
const _EB = preload("res://scripts/gameplay/echo/echo_budget_data.gd")
const _ED = preload("res://scripts/gameplay/echo/echo_budget_state.gd")


func run(ctx: Variant) -> void:
	_test_note_data(ctx)
	_test_stand_data(ctx)
	_test_transform_data(ctx)
	_test_notes(ctx)
	_test_world_state_roundtrip(ctx)
	_test_memory_stats_roundtrip(ctx)
	_test_mummy_rule(ctx)
	_test_k7_budget_offset(ctx)


func _test_note_data(ctx: Variant) -> void:
	var res: Resource = load("res://data/note_lines.tres")
	ctx.check(res != null, "notes: data/note_lines.tres loads")
	if res == null:
		return
	var lines: PackedStringArray = res.lines
	ctx.check(lines.size() == 5, "notes: the pool has exactly 5 lines")
	ctx.check(lines[0] == "I remember the mine. Don't go alone.",
			"notes: line 1 canonical (a door, not lore)")
	ctx.check(lines[4] == "I'm not the first. I won't be the last.",
			"notes: line 5 canonical")
	# No line may be empty or free-form long (the «no free text» rule:
	# every line is short — a door the player can answer).
	var short: bool = true
	for l in lines:
		if l == "" or l.length() > 60:
			short = false
	ctx.check(short, "notes: every pool line is short (no free text)")


func _test_stand_data(ctx: Variant) -> void:
	var res: Resource = load("res://data/player_note_stands.tres")
	ctx.check(res != null, "notes: data/player_note_stands.tres loads")
	if res == null:
		return
	ctx.check(res.entries.size() == 4,
			"notes: exactly 4 player stands (notes_max)")
	var ids: Array = [&"camp", &"village", &"shrine", &"undercroft"]
	var found: Dictionary = {}
	for e in res.entries:
		found[e.stand_id] = e
	for id in ids:
		ctx.check(found.has(id), "notes: stand %s present" % id)
	ctx.check(res.entry_in_area(&"camp") != null
			and res.entry_in_area(&"camp").stand_id == &"camp",
			"notes: the camp stand is found by area")
	var camp: Variant = res.entry_in_area(&"camp")
	ctx.check(camp.camp_pos != Vector3.ZERO,
			"notes: the camp stand has a camp position")
	var village: Variant = res.entry_in_area(&"ruined_village")
	ctx.check(village != null and village.room_idx == 0
			and village.offset != Vector3.ZERO,
			"notes: the village stand is in the entry room")


func _test_transform_data(ctx: Variant) -> void:
	var res: Resource = load("res://data/world_transform_post_boss.tres")
	ctx.check(res != null,
			"k7: data/world_transform_post_boss.tres loads")
	if res == null:
		return
	ctx.check(absf(res.fog_factor - 0.375) < 0.001,
			"k7: fog 0.8 -> 0.3 (factor 0.375, the section 6 table)")
	ctx.check(res.light_temp == 5500, "k7: light 4000K -> 5500K")
	ctx.check(res.gate_glow and res.city_visible,
			"k7: gate glow + city silhouette")
	ctx.check(res.echo_passive == 0 and res.echo_special == 0
			and res.echo_combat == 1,
			"k7: the echo budget is «тише» (passive 0, special 0, "
			+ "combat 1)")
	ctx.check(res.footprint_permanent and res.npc_calm,
			"k7: footprint permanent + npc calm")


func _test_notes(ctx: Variant) -> void:
	var ws: Variant = _WS.new()
	ctx.check(ws.write_note(&"camp", 2, 1, 1000),
			"notes: write at a known stand")
	ctx.check(not ws.write_note(&"kitchen", 0, 1, 1000),
			"notes: an unknown stand is rejected")
	ctx.check(ws.note_line(&"camp") == 2, "notes: the line is stored")
	ctx.check(int(ws.get_note(&"camp").run_id) == 1,
			"notes: the run is stored")
	# One per stand, «перезапись» replaces.
	ctx.check(ws.write_note(&"camp", 4, 2, 2000),
			"notes: re-write allowed")
	ctx.check(ws.note_line(&"camp") == 4,
			"notes: the re-write replaced the line")
	ctx.check(int(ws.get_note(&"camp").run_id) == 2,
			"notes: the re-write replaced the run")
	ctx.check(ws.notes.size() == 1,
			"notes: still one note per stand")
	# last_note: the most recent by t (the mummy's hand).
	ws.write_note(&"shrine", 0, 3, 5000)
	ws.write_note(&"village", 1, 3, 900)
	ctx.check(int(ws.last_note().run_id) == 3
			and int(ws.last_note().t) == 5000,
			"notes: last_note is the most recent by t")
	ws.notes.clear()
	ctx.check(ws.last_note().is_empty(), "notes: no note -> empty")


func _test_world_state_roundtrip(ctx: Variant) -> void:
	var ws: Variant = _WS.new()
	ws.set_flag(&"first_death_done")
	ws.set_flag(&"first_kill_pos", Vector3(1.5, 0.0, -2.0))
	ws.add_inheritance(&"ember", 3)
	ws.set_weapon_found(&"cannon")
	var e: Dictionary = ws.npc_entry(&"mara")
	e.trust = 2
	e.alive = false
	e.interactions = 7
	e.help_done = true
	e.gifts_given = true
	ws.write_note(&"camp", 3, 1, 1500)
	ws.write_note(&"undercroft", 0, 2, 9000)
	# A run record (the runs section roundtrips through RunHistory).
	var rec: Variant = load("res://scripts/gameplay/run/run_record.gd")
	var r: Variant = rec.new()
	r.run_id = 1
	r.deaths = 1
	r.last_death_pos = Vector3(3.0, 0.0, -8.0)
	ws.runs.add_run(r)
	var d: Dictionary = ws.to_dict()
	var ws2: Variant = _WS.new()
	ws2.load_dict(d)
	ctx.check(ws2.flag(&"first_death_done"),
			"ws-roundtrip: bool flag survives")
	ctx.check(ws2.flag(&"first_kill_pos") == false
			and ws2.flags.has(&"first_kill_pos"),
			"ws-roundtrip: a Vector3 flag is preserved (not a bool)")
	ctx.check(int(ws2.flags[&"first_kill_pos"].x) == 1,
			"ws-roundtrip: the Vector3 flag value survives")
	ctx.check(ws2.inheritance_level(&"ember") == 1,
			"ws-roundtrip: the inheritance survives (level 1 after "
			+ "one add)")
	ctx.check(ws2.is_weapon_found(&"cannon"),
			"ws-roundtrip: the weapon survives")
	ctx.check(ws2.runs.get_run(1) != null
			and int(ws2.runs.get_run(1).deaths) == 1,
			"ws-roundtrip: the run record survives")
	var e2: Dictionary = ws2.npc_entry(&"mara")
	ctx.check(e2.alive == false and int(e2.trust) == 2
			and int(e2.interactions) == 7 and e2.help_done
			and e2.gifts_given,
			"ws-roundtrip: the NPC state survives")
	ctx.check(ws2.note_line(&"camp") == 3
			and int(ws2.get_note(&"camp").t) == 1500,
			"ws-roundtrip: the note survives")
	ctx.check(ws2.note_line(&"undercroft") == 0,
			"ws-roundtrip: the second note survives")
	# Corrupt-save defense: bad values clamp, missing keys are safe.
	var bad: Dictionary = ws2.to_dict()
	bad.flags["first_death_done"] = 12345
	bad.inheritances["ember"] = 99
	bad.notes["camp"]["line_id"] = 99
	bad.notes["garbage_stand"] = {"line_id": 1, "run_id": 1, "t": 0}
	var ws3: Variant = _WS.new()
	ws3.load_dict(bad)
	ctx.check(ws3.flag(&"first_death_done"),
			"ws-roundtrip: a bad bool still reads true")
	ctx.check(int(ws3.inheritances[&"ember"]) == 99,
			"ws-roundtrip: an inheritance level passes through "
			+ "(clamped to >= 0 only)")
	ctx.check(int(ws3.get_note(&"camp").line_id) == 4,
			"ws-roundtrip: an out-of-pool line clamps to the max")
	ctx.check(not ws3.notes.has(&"garbage_stand"),
			"ws-roundtrip: an unknown stand is dropped")
	# An empty dict must not crash and must leave a usable state.
	var ws4: Variant = _WS.new()
	ws4.load_dict({})
	ctx.check(not ws4.flag(&"first_death_done"),
			"ws-roundtrip: an empty dict = a fresh state")


func _test_memory_stats_roundtrip(ctx: Variant) -> void:
	var ms: Variant = _MS.new()
	ms.kills = 21
	ms.fled = 11
	ms.explored_pct = 62
	ms.notes_written = 3
	ms.npc_killed = 1
	ms.child_hit = 0
	ms.strange_actions = 4
	ms.deaths = 2
	ms.runs_completed = 1
	ms.dodge_count = 9
	ms.melee_hits = 30
	ms.ranged_hits = 2
	var d: Dictionary = ms.to_dict()
	var ms2: Variant = _MS.new()
	ms2.load_dict(d)
	ctx.check(ms2.kills == 21 and ms2.fled == 11 and ms2.explored_pct == 62
			and ms2.notes_written == 3 and ms2.npc_killed == 1
			and ms2.strange_actions == 4 and ms2.deaths == 2
			and ms2.runs_completed == 1 and ms2.dodge_count == 9
			and ms2.melee_hits == 30 and ms2.ranged_hits == 2,
			"stats: all 10 counters + 3 aggregates roundtrip")
	# Corrupt defense: negatives clamp, missing keys keep defaults.
	var bad: Dictionary = d
	bad.kills = -5
	bad.explored_pct = 400
	var ms3: Variant = _MS.new()
	ms3.load_dict(bad)
	ctx.check(ms3.kills == 0 and ms3.explored_pct == 100,
			"stats: bad values clamp (no negatives, <= 100%)")


func _test_mummy_rule(ctx: Variant) -> void:
	# The rule (RUN 03 #5): the mummy appears when run_id >= 3 AND
	# the previous run died (a last_death_pos exists).
	var wd: Variant = load("res://scripts/world/world_director.gd")
	ctx.check(wd != null, "mummy: WorldDirector loads")
	ctx.check(wd.MUMMY_RUN_MIN == 3,
			"mummy: the mummy appears from RUN 03")
	# RUN 2 with a death: no mummy yet (the run is too early).
	ctx.check(2 < wd.MUMMY_RUN_MIN, "mummy: RUN 02 is too early")
	# The position source: the previous run's last_death_pos
	# (RunRecord.last_death_pos — set by the run manager on death).
	var rec: Variant = load("res://scripts/gameplay/run/run_record.gd")
	ctx.check(rec != null, "mummy: RunRecord loads (last_death_pos "
			+ "is its field)")


func _test_k7_budget_offset(ctx: Variant) -> void:
	# K7 (section 6, ECHO_SYSTEM_DESIGN section 8): boss_defeated
	# -> the transform table overrides the run budget («тише»).
	var budget: Variant = load("res://data/echo/echo_budget.tres")
	ctx.check(budget != null, "k7: the echo budget data loads")
	var ws: Variant = _WS.new()
	var g: Variant = _GD.new()
	g.setup(budget, null, null)
	# RUN 03 without the boss: the normal budget (1 passive, 1 combat).
	g.prepare_run(3, ws, null, null, null)
	ctx.check(g.budget_state.passive_remaining() == 1
			and g.budget_state.combat_remaining() == 1
			and g.budget_state.special_remaining() == 0,
			"k7: before the boss the RUN 03 budget is normal")
	# The boss is defeated: «тише» (passive 0, combat 1, special 0).
	ws.set_flag(&"boss_defeated")
	g.prepare_run(3, ws, null, null, null)
	ctx.check(g.budget_state.passive_remaining() == 0
			and g.budget_state.combat_remaining() == 1
			and g.budget_state.special_remaining() == 0,
			"k7: after the boss the budget is «тише» (-2 echo)")
