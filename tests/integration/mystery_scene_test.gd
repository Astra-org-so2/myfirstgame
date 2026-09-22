# Integration: Phase 11 mystery system (ROADMAP exit: #1-#7 +
# K1-K7 achievable, M2 stages «gather», the 1-stage-per-run rule).
#
# The full MVP route (FIRST_3_RUNS + the RUN 04-05 beats):
#   RUN 1:  K1 (the blade, M1.1) + the trace (M2.1) + the gate seal
#           (A16) -> death;
#   RUN 02: the Passive Echo (M1.2) + the first Remnant (#1, M3.1)
#           + the open gate (B2, M2.2) -> death;
#   RUN 03: a note written, the book (K4, M1.3), the gate footnotes
#           (M4.1), #6 (M3.2: «…I forgot that.»);
#   RUN 04: the Child («It was the third time.» — no stage yet);
#   RUN 05: K5 the lake (M3.3) + the Child «217» (M4.2) + the filled
#           page (M1.4) + the Cartographer's city line (spoken, but
#           M4 stage 3 SHIFTED +1 run — 1 stage/mystery/run);
#   RUN 06: the shifted M4 stage 3 lands (the world is not in a
#           hurry).
#
# Rig contract (ADR-022): the MovementPort mock, the manual clock,
# Input.action_press for held-edge actions.
extends Node

const _MAIN = preload("res://scripts/world/main_scene.gd")
const _PORT = preload("res://scripts/player/movement_port.gd")
const _DREQ = preload("res://scripts/gameplay/combat/damage_request.gd")
const _EV = preload("res://scripts/gameplay/run/run_event.gd")

const DT: float = 1.0 / 60.0

var _main: _MAIN
var _player: Node
var _mock: _PORT
var _ticks: Array = []

# The remnant's facing is deterministic per run — a fixed offset can
# sit behind it, so the encounter walks a few points around it until
# the sight cone catches the player.
const _ENCOUNTER_OFFSETS: Array = [
	Vector3(0.6, 0.0, 0.3),
	Vector3(2.0, 0.0, 0.5),
	Vector3(-2.0, 0.0, 0.5),
	Vector3(0.0, 0.0, 2.0),
	Vector3(0.0, 0.0, -2.0),
	Vector3(2.0, 0.0, 2.0),
	Vector3(-2.0, 0.0, -2.0),
	Vector3(3.0, 0.0, 0.0),
]


func run(ctx: Variant) -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	ctx.check(packed != null, "mystery: main scene loads")
	if packed == null:
		return
	var scene: Node = packed.instantiate()
	_main = scene
	var player_node: Node = scene.find_child("Player", true, false)
	_player = player_node
	_mock = _PORT.new(null,
			_player.data.gravity, _player.data.max_fall_speed)
	_player.set_port(_mock)
	add_child(scene)
	_main.set_physics_process(false)  # the test owns the clock
	_test_run1(ctx)
	_test_death(ctx)
	_test_run2(ctx)
	_test_death(ctx)
	_test_run3(ctx)
	_test_death(ctx)
	_test_run4(ctx)
	_test_death(ctx)
	_test_run5(ctx)
	_test_death(ctx)
	_test_run6_city_shift(ctx)
	_main.queue_free()


func _tick(n: int) -> void:
	for i in n:
		_main._physics_process(DT)
		var zw: Node = _main.zone_world
		if zw != null and is_instance_valid(zw):
			zw._physics_process(DT)
		var fr: Node = _main.first_run
		if fr != null and is_instance_valid(fr):
			fr._physics_process(DT)
		var wd: Node = _main.world_director
		if wd != null and is_instance_valid(wd):
			wd.update(DT)
		for t in _ticks:
			if is_instance_valid(t):
				t._physics_process(DT)


func _walk(pos: Vector3, n: int) -> void:
	_mock.set_position(Vector3(pos.x, 0.0, pos.z))
	_tick(n)


func _interact() -> void:
	Input.action_press("interact")
	_tick(3)
	Input.action_release("interact")
	_tick(2)


func _ws() -> Variant:
	return _main.progress.ws


func _progress() -> String:
	return _main.mystery.progress_view(_ws())


func _enemy(id: StringName) -> Node:
	for e in _main.director.get_alive_enemies():
		var c: Node = e
		if c.has_method("get_data_id") and c.get_data_id() == id:
			return c
	return null


# Walks the offset ring around the remnant until `want_flag` is set
# (or the remnant is gone). Returns the speech lines seen.
func _encounter_remnant(want_flag: StringName) -> Array:
	var lines: Array = []
	for o in _ENCOUNTER_OFFSETS:
		if _ws().flag(want_flag):
			break
		var e: Node = _enemy(&"remnant_mirror")
		if e == null:
			break
		_walk(e.global_position + o, 3)
		var ticks: int = 0
		while ticks < 300:
			_tick(1)
			ticks += 1
			if _enemy(&"remnant_mirror") == null:
				break
			var ee: Node = _enemy(&"remnant_mirror")
			if ee != null and ee.is_speaking() and ee.speech_text() != "":
				lines.append(ee.speech_text())
			if _ws().flag(want_flag):
				break
	# The sequence plays out: 3 lines x 3 s. The remnant leaves after
	# the first encounter (leave_fade) — follow until it is gone.
	var grace: int = 0
	while grace < 700:
		if _enemy(&"remnant_mirror") == null:
			break
		_tick(1)
		grace += 1
		var ee: Node = _enemy(&"remnant_mirror")
		if ee != null and ee.is_speaking() and ee.speech_text() != "":
			lines.append(ee.speech_text())
	return lines


# --- RUN 1: K1 (M1.1), the trace (M2.1), the gate seal (A16) ------------

func _test_run1(ctx: Variant) -> void:
	var ws: Variant = _ws()
	# K1: the first swing — the blade «in the hand».
	Input.action_press("attack")
	_tick(45)
	Input.action_release("attack")
	_tick(5)
	ctx.check(ws.mystery_stage(1) == 1,
			"mystery: RUN 1 K1 reveals M1 stage 1 (%s)" % _progress())
	# M2.1: the first Hollow leaves a trace (A5).
	var hollow: Node = _enemy(&"hollow_base")
	ctx.check(hollow != null, "mystery: a Hollow is alive in RUN 1")
	if hollow != null:
		var req: _DREQ = _DREQ.new()
		req.source = _player
		req.target = hollow
		req.amount = 99.0
		req.type = _DREQ.Type.MELEE
		req.position = hollow.global_position
		req.knockback_direction = Vector3(1.0, 0.0, 0.0)
		_main.resolver.resolve(req)
		var waited: int = 0
		while waited < 120 and ws.mystery_stage(2) < 1:
			_tick(1)
			waited += 1
	ctx.check(ws.mystery_stage(2) == 1,
			"mystery: RUN 1 the trace reveals M2 stage 1 (%s)"
					% _progress())
	# A16: the gate seal (RUN 1 only) — B2 in RUN 02 needs it.
	_main._enter_level(&"ancient_gate")
	_tick(5)
	ctx.check(ws.flag(&"gate_seal_seen"),
			"mystery: RUN 1 the gate seal is seen (A16)")
	_main._enter_level(&"camp")


# --- Death (a real damage source, the record, the choice) ----------------
# The camp always carries enemies for the session's runs — the death
# comes from a real source there.

func _test_death(ctx: Variant) -> void:
	_main._enter_level(&"camp")
	_tick(5)
	var rm: Node = _main.run_manager
	var run_id: int = rm.run_id
	var enemies: Array = _main.director.get_alive_enemies()
	var killer: Node = null
	for e in enemies:
		if e.has_method("get_data_id") \
				and e.get_data_id() == &"watcher_base":
			killer = e
			break
	if killer == null and enemies.size() > 0:
		killer = enemies[0]
	ctx.check(killer != null, "mystery: a killer for death %d" % run_id)
	if killer == null:
		return
	var req: _DREQ = _DREQ.new()
	req.source = killer
	req.target = _player
	req.amount = 500.0
	req.type = _DREQ.Type.MELEE
	req.position = _mock.get_position()
	req.knockback_direction = Vector3(1.0, 0.0, 0.0)
	_main.resolver.resolve(req)
	_tick(1)
	ctx.check(_player.is_dead(), "mystery: death %d happened" % run_id)
	var screen: Node = _main.get_node_or_null("DeathScreen")
	ctx.check(screen != null and _player.death_choice_pending,
			"mystery: death %d waits for the choice" % run_id)
	if screen == null:
		return
	screen.press(0)
	_tick(5)
	ctx.check(not _player.is_dead(),
			"mystery: death %d respawned" % run_id)


# --- RUN 02: M1.2 (passive), M3.1 (#1), M2.2 (the gate) -------------------

func _test_run2(ctx: Variant) -> void:
	var ws: Variant = _ws()
	ctx.check(_main.run_manager.run_id == 2, "mystery: RUN 02 begins")
	# M1.2: the Passive Echo walks the player's path (the camp).
	ctx.check(ws.mystery_stage(1) == 2,
			"mystery: RUN 02 the passive echo reveals M1 stage 2 (%s)"
					% _progress())
	# M3.1: the first Remnant speaks (#1).
	var remnant: Node = _enemy(&"remnant_mirror")
	ctx.check(remnant != null, "mystery: RUN 02 the remnant is present")
	if remnant != null:
		_encounter_remnant(&"first_echo_seen")
		ctx.check(ws.flag(&"first_echo_seen")
				and ws.mystery_stage(3) == 1,
				"mystery: RUN 02 #1 reveals M3 stage 1 (%s)"
						% _progress())
		# The Archivist whisper #2 (at the first Echo, once).
		ctx.check(ws.flag(&"he_is_counted_whisper"),
				"mystery: the Archivist whispers «He is kept. He is "
				+ "counted.»")
	# M2.2: the gate opens (B2) — the world «answers».
	_main._enter_level(&"ancient_gate")
	_tick(5)
	ctx.check(ws.mystery_stage(2) == 2,
			"mystery: RUN 02 the open gate reveals M2 stage 2 (%s)"
					% _progress())


# --- RUN 03: the note, K4 (M1.3), M4.1, #6 (M3.2) --------------------------

func _test_run3(ctx: Variant) -> void:
	var ws: Variant = _ws()
	ctx.check(_main.run_manager.run_id == 3, "mystery: RUN 03 begins")
	# The note first (#6 needs it): the camp stand, the pool.
	var stand: Node = _main.world_director.current_stand()
	ctx.check(stand != null, "mystery: the camp stand is placed")
	if stand != null:
		_ticks = [stand.find_child("IA_write_camp", true, false)]
		var res: Resource = load("res://data/player_note_stands.tres")
		_walk(res.entry_in_area(&"camp").camp_pos, 5)
		_interact()
		_main.note_panel.press(0)
		ctx.check(ws.note_line(&"camp") == 0,
				"mystery: the note is written (#6 needs it)")
		# #6: the Remnant reads the note (M3 stage 2, the third line).
		var lines: Array = _encounter_remnant(&"echo_decision_seen")
		ctx.check(ws.flag(&"echo_decision_seen")
				and ws.mystery_stage(3) == 2,
				"mystery: RUN 03 #6 reveals M3 stage 2 (%s)"
						% _progress())
		ctx.check(lines.has("\u2026I forgot that."),
				"mystery: RUN 03 the note line is in the sequence (%s)"
						% str(lines))
	# K4 (M1.3): Nia's trust 1 (the trust logic is unit-tested; the
	# scene state is set directly) + the book in the village.
	var e: Dictionary = ws.npc_entry(&"nia")
	e.trust = 1
	_main._enter_level(&"ruined_village")
	_tick(10)
	var book: Node = _main.zone_world.level.find_child("NiaBook",
			true, false)
	ctx.check(book != null, "mystery: RUN 03 the book stands by Nia")
	if book != null:
		_ticks = [book.find_child("IA_Book", true, false)]
		_walk(book.global_position + Vector3(0.0, 0.0, 1.5), 5)
		_interact()
		var lbl: Node = book.get("_label")
		ctx.check(lbl != null and lbl.visible
				and lbl.text.begins_with("Eli. Profession:"),
				"mystery: RUN 03 K4 the page is actually shown")
		ctx.check(ws.flag(&"nia_name_seen")
				and ws.mystery_stage(1) == 3,
				"mystery: RUN 03 K4 reveals M1 stage 3 (%s)"
						% _progress())
	# M4.1: the gate footnotes (the three «previous versions»).
	_main._enter_level(&"ancient_gate")
	_tick(10)
	var gate_note: Node = _main.zone_world.level.find_child(
			"NoteStand_gate_footnotes", true, false)
	ctx.check(gate_note != null,
			"mystery: the gate footnotes stand on entry")
	if gate_note != null:
		_ticks = [gate_note.find_child("IA_note_gate_footnotes",
				true, false)]
		_walk(gate_note.global_position + Vector3(0.0, 0.0, 1.5), 5)
		_interact()
		_tick(60)  # the 3-line sequence plays
		ctx.check(ws.flag(&"gate_notes_seen")
				and ws.mystery_stage(4) == 1,
				"mystery: RUN 03 the footnotes reveal M4 stage 1 (%s)"
						% _progress())
	# The «evenly» check (MYSTERY_REVEAL_MAP: 3 runs = the stages land
	# across the mysteries, not bunched).
	_main._enter_level(&"camp")
	ctx.check(ws.mystery_stage(1) == 3 and ws.mystery_stage(2) == 2
			and ws.mystery_stage(3) == 2 and ws.mystery_stage(4) == 1,
			"mystery: end of RUN 03 = M1:3 M2:2 M3:2 M4:1 (%s)"
					% _progress())


# --- RUN 04: the Child (the line, not the stage yet) ----------------------

func _test_run4(ctx: Variant) -> void:
	var ws: Variant = _ws()
	ctx.check(_main.run_manager.run_id == 4, "mystery: RUN 04 begins")
	ctx.check(_main.progress.stats.deaths >= 3,
			"mystery: the third death is counted")
	_main._enter_level(&"ruined_village")
	_tick(10)
	var child: Node = _main.zone_world.level.find_child("TheChild",
			true, false)
	ctx.check(child != null, "mystery: RUN 04 the Child is in the village")
	if child == null:
		return
	_ticks = [child.find_child("IA_Child", true, false)]
	_walk(child.global_position + Vector3(0.0, 0.0, 1.5), 5)
	_interact()
	ctx.check(ws.mystery_stage(4) == 1,
			"mystery: RUN 04 the Child line is not a stage "
			+ "(run_min 5) (%s)" % _progress())


# --- RUN 05: K5 (M3.3), the Child «217» (M4.2), the filled page (M1.4) ----

func _test_run5(ctx: Variant) -> void:
	var ws: Variant = _ws()
	ctx.check(_main.run_manager.run_id == 5, "mystery: RUN 05 begins")
	# K5: the lake reflection (the Archivist, 2 s, once).
	_main._enter_level(&"mysterious_lake")
	_tick(10)
	ctx.check(ws.flag(&"lake_reflection_seen")
			and ws.mystery_stage(3) == 3,
			"mystery: RUN 05 K5 reveals M3 stage 3 (%s)" % _progress())
	# M4.2: the Child counts the player («217»).
	_main._enter_level(&"ruined_village")
	_tick(10)
	var child: Node = _main.zone_world.level.find_child("TheChild",
			true, false)
	ctx.check(child != null, "mystery: RUN 05 the Child is back")
	if child != null:
		_ticks = [child.find_child("IA_Child", true, false)]
		_walk(child.global_position + Vector3(0.0, 0.0, 1.5), 5)
		_interact()
		ctx.check(ws.flag(&"child_number_seen")
				and ws.mystery_stage(4) == 2,
				"mystery: RUN 05 «217» reveals M4 stage 2 (%s)"
						% _progress())
	# M1.4: the page is filled (the world «writes» it).
	var book: Node = _main.zone_world.level.find_child("NiaBook",
			true, false)
	ctx.check(book != null, "mystery: RUN 05 the book is still there")
	if book != null:
		_ticks = [book.find_child("IA_Book", true, false)]
		_walk(book.global_position + Vector3(0.0, 0.0, 1.5), 5)
		_interact()
		var lbl2: Node = book.get("_label")
		ctx.check(lbl2 != null and lbl2.visible
				and lbl2.text.contains("the one who forgets"),
				"mystery: RUN 05 the filled page is shown")
		ctx.check(ws.flag(&"nia_page_filled")
				and ws.mystery_stage(1) == 4,
				"mystery: RUN 05 the filled page reveals M1 stage 4 "
				+ "(%s)" % _progress())
	# M4.3: the Cartographer's city line — but M4 already advanced
	# this run (the Child): the 1-stage-per-run rule holds M4 stage 3
	# (the world is not in a hurry). The trust flow is real: 2 talks
	# (trust 0), the scripted help (trust 1), then the mystery line.
	_main._enter_level(&"camp")
	_tick(5)
	var e: Dictionary = ws.npc_entry(&"cartographer")
	var carto: Node = _main.find_child("NPC_cartographer", true, false)
	ctx.check(carto != null, "mystery: the Cartographer is in the camp")
	if carto != null:
		_ticks = [carto.find_child("IA_cartographer", true, false)]
		_walk(carto.global_position + Vector3(0.0, 0.0, 1.5), 5)
		for i in 3:  # talk 1, talk 2, the help
			_interact()
			_tick(40)
		ctx.check(int(e.trust) == 1,
				"mystery: the Cartographer's trust is 1 (the help)")
		_interact()  # talk 4: the mystery line
		ctx.check(ws.flag(&"veyra_city_told")
				and carto.current_line().contains("city"),
				"mystery: the city line is spoken (RUN 05) (%s)"
						% carto.current_line())
		ctx.check(ws.mystery_stage(4) == 2,
				"mystery: M4 stage 3 is SHIFTED (1 stage/run) (%s)"
						% _progress())


# --- RUN 06: the shifted stage lands --------------------------------------

func _test_run6_city_shift(ctx: Variant) -> void:
	var ws: Variant = _ws()
	ctx.check(_main.run_manager.run_id == 6, "mystery: RUN 06 begins")
	# The Cartographer says it again (repeat: he is obsessed) — the
	# allowance is open, the stage lands.
	var carto: Node = _main.find_child("NPC_cartographer", true, false)
	ctx.check(carto != null, "mystery: RUN 06 the Cartographer is there")
	if carto == null:
		return
	_ticks = [carto.find_child("IA_cartographer", true, false)]
	_walk(carto.global_position + Vector3(0.0, 0.0, 1.5), 5)
	_interact()
	ctx.check(ws.flag(&"veyra_b_seen")
			and carto.current_line().contains("city")
			and ws.mystery_stage(4) == 3,
			"mystery: RUN 06 the shifted M4 stage 3 lands (%s)"
					% _progress())
	# The MVP end state: M1 4/4, M2 2/3 (the boss = Phase 12), M3 3/3,
	# M4 3/3.
	ctx.check(ws.mystery_stage(1) == 4 and ws.mystery_stage(2) == 2
			and ws.mystery_stage(3) == 3 and ws.mystery_stage(4) == 3,
			"mystery: MVP end state M1:4 M2:2 M3:3 M4:3 (%s)"
					% _progress())
