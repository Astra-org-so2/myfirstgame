# Unit: Phase 11 mystery system (MYSTERY_REVEAL_MAP section 4-5,
# DIALOGUE_GUIDELINES section 6/7): the stage table (the reveal
# rules as data invariants), the MysteryDirector gate (1 stage/run,
# strict sequence, the flag chain), the mystery_progress persist,
# the dialogue-line table, and the Child spawn rules.
extends Node

const _WS = preload("res://scripts/gameplay/progression/world_state.gd")
const _MD = preload("res://scripts/gameplay/mystery/mystery_director.gd")
const _MS = preload("res://scripts/gameplay/mystery/mystery_stages.gd")
const _DL = preload("res://scripts/gameplay/mystery/dialogue_lines.gd")
const _CS = preload("res://scripts/gameplay/mystery/child_spawns.gd")


func run(ctx: Variant) -> void:
	_test_stage_table(ctx)
	_test_dialogue_table(ctx)
	_test_mystery_progress(ctx)
	_test_gate(ctx)
	_test_child_spawns(ctx)
	_test_ambiguity(ctx)


func _stages() -> Variant:
	return load("res://data/mystery/mystery_stages.tres")


func _test_stage_table(ctx: Variant) -> void:
	var res: Resource = _stages()
	ctx.check(res != null, "mystery: data/mystery/mystery_stages.tres loads")
	if res == null:
		return
	var problems: Array = res.validate()
	ctx.check(problems.is_empty(),
			"mystery: the stage table validates (%s)" % str(problems))
	# MVP coverage (MYSTERY_REVEAL_MAP section 5): M1 stages 1-4,
	# M2/M3/M4 stages 1-3.
	var list: Array = res.of(1)
	ctx.check(list.size() == 4, "mystery: M1 has stages 1-4 (the MVP line)")
	for m in [2, 3, 4]:
		ctx.check((res.of(m) as Array).size() == 3,
				"mystery: M%d has stages 1-3" % m)
	# The main MVP line is M2 (GDD section 11).
	var m2: Array = res.of(2)
	var s3: Variant = (m2[2] as Resource)
	ctx.check(s3.stage_id == &"m2_first" and s3.mystery == 2,
			"mystery: M2 stage 3 = the First (the main line ends there)")


func _test_dialogue_table(ctx: Variant) -> void:
	var res: Resource = load("res://data/dialogue/npc_mystery_lines.tres")
	ctx.check(res != null,
			"dialogue: data/dialogue/npc_mystery_lines.tres loads")
	if res == null:
		return
	var problems: Array = res.validate()
	ctx.check(problems.is_empty(),
			"dialogue: the line table validates (%s)" % str(problems))
	# The 5th NPC (the Child) is NOT in this table: the Child is a
	# roaming entity, not a trust NPC (CHARACTER_BIBLE 5).
	var chars: PackedStringArray = res.known_chars
	ctx.check(chars.has("mara") and chars.has("orren")
			and chars.has("nia") and chars.has("cartographer")
			and not chars.has("child"),
			"dialogue: 4 trust NPCs (+ the Child is separate)")
	# Nia's K4 hint (RUN 03, trust 1, once).
	var ws: Variant = _WS.new()
	ws.set_mystery_stage(1, 0)
	var e: Dictionary = ws.npc_entry(&"nia")
	e.trust = 1
	var ln: Variant = res.for_char(&"nia", ws, 3, {})
	ctx.check(ln != null and ln.id == &"nia_book_hint",
			"dialogue: Nia's K4 hint matches (RUN 03, trust 1)")
	var ln1: Variant = res.for_char(&"nia", ws, 2, {})
	ctx.check(ln1 == null, "dialogue: the hint is not in RUN 02")
	var e0: Dictionary = ws.npc_entry(&"nia")
	e0.trust = 0
	var ln2: Variant = res.for_char(&"nia", ws, 3, {})
	ctx.check(ln2 == null, "dialogue: the hint needs trust 1")


func _test_mystery_progress(ctx: Variant) -> void:
	var ws: Variant = _WS.new()
	ctx.check(ws.mystery_stage(1) == 0,
			"progress: fresh world = stage 0 everywhere")
	ws.set_mystery_stage(1, 1)
	ws.set_mystery_stage(1, 3)
	ws.set_mystery_stage(1, 2)  # rewind must be a no-op
	ctx.check(ws.mystery_stage(1) == 3,
			"progress: forward only (no rewind, no early reveal)")
	# The persist roundtrip (the Phase 15 save wraps this).
	var d: Dictionary = ws.to_dict()
	var ws2: Variant = _WS.new()
	ws2.load_dict(d)
	ctx.check(ws2.mystery_stage(1) == 3
			and ws2.mystery_stage(2) == 0,
			"progress: the mystery_progress survives the roundtrip")
	# Corrupt defense: out-of-range clamps, negatives drop.
	var bad: Dictionary = ws2.to_dict()
	bad.mystery_progress[1] = 99
	bad.mystery_progress[2] = -1
	var ws3: Variant = _WS.new()
	ws3.load_dict(bad)
	ctx.check(ws3.mystery_stage(1) == 4 and ws3.mystery_stage(2) == 0,
			"progress: bad values clamp (max stage 4, no negatives)")


func _test_gate(ctx: Variant) -> void:
	var stages: Variant = _stages()
	var ws: Variant = _WS.new()
	var md: Variant = _MD.new()
	md.setup(stages)
	md.reset_run()
	# RUN 1: M1 stage 1 (K1) and M2 stage 1 (the trace) are allowed
	# (no flag_req), the rest is not (run_min / sequence).
	ctx.check(md.can_reveal(&"m1_k1", ws, 1),
			"gate: K1 is possible in RUN 1")
	ctx.check(md.can_reveal(&"m2_trace", ws, 1),
			"gate: the trace is possible in RUN 1")
	ctx.check(not md.can_reveal(&"m3_first_echo", ws, 1),
			"gate: the first echo is not in RUN 1 (run_min)")
	ctx.check(not md.can_reveal(&"m1_book", ws, 1),
			"gate: the book is not in RUN 1 (sequence + run_min)")
	# Reveal M1 stage 1 -> M1 stage 2 needs its flag + RUN 2 + the
	# sequence (progress 1).
	ctx.check(md.reveal(&"m1_k1", ws, 1), "gate: K1 reveals")
	ctx.check(ws.flag(&"blade_found")
			and ws.mystery_stage(1) == 1,
			"gate: the reveal lands the flag + the progress")
	ctx.check(not md.can_reveal(&"m1_passive", ws, 1),
			"gate: 1 stage/run (M1 advanced already)")
	md.reset_run()
	ctx.check(not md.can_reveal(&"m1_passive", ws, 1),
			"gate: RUN 1 is still too early for M1 stage 2 (run_min)")
	md.reset_run()
	# RUN 2: the passive echo (M1.2) + the first echo (M3.1).
	ctx.check(md.can_reveal(&"m1_passive", ws, 2),
			"gate: the passive echo is possible in RUN 2")
	ctx.check(md.can_reveal(&"m3_first_echo", ws, 2),
			"gate: the first echo is possible in RUN 2")
	md.reveal(&"m1_passive", ws, 2)
	md.reveal(&"m3_first_echo", ws, 2)
	ctx.check(ws.flag(&"passive_echo_seen")
			and ws.flag(&"first_echo_seen"),
			"gate: both reveals land their flags")
	ctx.check(ws.mystery_stage(1) == 2 and ws.mystery_stage(3) == 1,
			"gate: the progress tracks the mysteries")
	# RUN 3: M1 stage 3 (the book) needs the chain flag.
	md.reset_run()
	ctx.check(md.can_reveal(&"m1_book", ws, 3),
			"gate: the book is possible in RUN 03 (the chain holds)")
	# M3 stage 2 needs the M3 stage 1 flag (the no-early-reveal chain).
	var ws_nochain: Variant = _WS.new()
	var md2: Variant = _MD.new()
	md2.setup(stages)
	ctx.check(not md2.can_reveal(&"m3_note", ws_nochain, 3),
			"gate: M3 stage 2 without M3 stage 1 = no early reveal")
	ws_nochain.set_mystery_stage(3, 1)  # progress says 1, but the flag
	ctx.check(not md2.can_reveal(&"m3_note", ws_nochain, 3),
			"gate: the flag chain is the gate (progress alone is not)")
	# M4.3 (RUN 05) needs the M4.2 flag even at RUN 06.
	ws.set_mystery_stage(4, 2)
	ctx.check(not md.can_reveal(&"m4_city", ws, 6),
			"gate: M4 stage 3 without the M4.2 flag = no early reveal")
	ws.set_flag(&"child_number_seen")
	ctx.check(md.can_reveal(&"m4_city", ws, 6),
			"gate: the chain complete -> M4 stage 3 is possible")
	# The M2 chain to the boss (M2.3 is data-ready for Phase 12).
	ws.set_flag(&"first_hollow_killed")
	ws.set_mystery_stage(2, 1)
	md.reset_run()
	ctx.check(md.can_reveal(&"m2_gate", ws, 2),
			"gate: the gate stage follows the trace (the chain)")
	md.reveal(&"m2_gate", ws, 2)
	ctx.check(ws.flag(&"run_02_door_open"),
			"gate: the gate reveal opens the door (the flag)")
	md.reset_run()
	ctx.check(not md.can_reveal(&"m2_first", ws, 4),
			"gate: the boss stage is not in RUN 04 (run_min 5)")
	ctx.check(md.can_reveal(&"m2_first", ws, 5),
			"gate: the boss stage is possible at RUN 05 (M2 chain)")


func _test_child_spawns(ctx: Variant) -> void:
	var res: Resource = load("res://data/mystery/child_spawns.tres")
	ctx.check(res != null, "child: data/mystery/child_spawns.tres loads")
	if res == null:
		return
	var ws: Variant = _WS.new()
	var ms: Variant = load("res://scripts/gameplay/memory_stats.gd")
	var stats: Variant = ms.new()
	stats.deaths = 3
	ctx.check(res.for_run(3, ws, stats) == null,
			"child: RUN 03 is too early (the window is RUN 04+)")
	var sp4: Variant = res.for_run(4, ws, stats)
	ctx.check(sp4 != null and sp4.run_min == 4,
			"child: RUN 04 appears (deaths >= 3)")
	stats.deaths = 1
	ctx.check(res.for_run(4, ws, stats) == null,
			"child: RUN 04 needs the third death (min_deaths)")
	stats.deaths = 3
	var sp5: Variant = res.for_run(5, ws, stats)
	ctx.check(sp5 != null and sp5.lines.size() == 2,
			"child: RUN 05 carries the two facts (217 + the stayed)")
	# The soft penalty: child_hit -> the world «takes» the child.
	ws.set_flag(&"child_hit")
	ctx.check(res.for_run(5, ws, stats) == null,
			"child: the child_hit flag hides the child (soft penalty)")
	ws.set_flag(&"child_hit", false)
	ctx.check(res.for_run(6, ws, stats) == null,
			"child: RUN 06 is outside the window")


func _test_ambiguity(ctx: Variant) -> void:
	# The ambiguity budget (MYSTERY_REVEAL_MAP section 4, rule 5):
	# the MVP table carries DOORS, not answers — the twist reveals
	# (Act II, post-MVP) are NOT in the MVP data.
	var stages: Variant = _stages()
	var clean: bool = true
	for s in stages.stages:
		var st: Variant = s
		var t: String = st.line.to_lowercase()
		for banned in ["they were real", "they stayed because",
				"i never forget", "that's my kindness",
				"you are a copy", "it's just a memory"]:
			if t.contains(banned):
				clean = false
	ctx.check(clean, "ambiguity: no MVP line answers a twist (seeds only)")
	# Every spoken stage line fits its budget (validate() checks this
	# too — here the rule is spelled out).
	var within: bool = true
	for s in stages.stages:
		var st: Variant = s
		if st.line != "" and st.max_words < 5:
			within = false
	ctx.check(within, "ambiguity: the budgets are sane (>= 5 words)")
