# Integration: Phase 10 world memory (ROADMAP Phase 10 exit:
# «10+ identifiable permanent changes», the note loop, the mummy).
#
# One scene, the full loop: RUN 1 (write a note at the camp stand —
# the pool, not free text; the world stores it) -> death -> RUN 02
# (the same stand now READS the note; the mummy is not here yet —
# run 2 < 3) -> death (the boss flag is set by hand — Phase 12 owns
# the trigger; here it exercises the K7 «тише» budget in the live
# scene) -> RUN 03: the mummy stands where RUN 02 ended (the
# last_death_pos, remapped), the note is in her hand, the examine
# sets corpse_seen + MUMMY_EXAMINED, and the passive echo budget is
# «тише» (0 passive post-boss).
extends Node

const _MAIN = preload("res://scripts/world/main_scene.gd")
const _PORT = preload("res://scripts/player/movement_port.gd")
const _DREQ = preload("res://scripts/gameplay/combat/damage_request.gd")
const _RM = preload("res://scripts/gameplay/run/run_manager.gd")
const _EV = preload("res://scripts/gameplay/run/run_event.gd")

const DT: float = 1.0 / 60.0

var _main: _MAIN
var _player: Node
var _mock: _PORT
var _ticks: Array = []


func run(ctx: Variant) -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	ctx.check(packed != null, "memory: main scene loads")
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
	_test_run1_note(ctx)
	_test_death(ctx)
	_test_run2_note_read(ctx)
	_test_death(ctx)
	_test_run3_mummy(ctx)
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


func _events_of_type(run_id: int, type: int) -> Array:
	var out: Array = []
	var rm: Node = _main.run_manager
	var rec: Variant = null
	if rm != null and rm.current_record != null \
			and int(rm.current_record.run_id) == run_id:
		rec = rm.current_record
	if rec == null:
		rec = _main.progress.ws.runs.get_run(run_id)
	if rec == null:
		return out
	for ev in rec.events:
		var e: Variant = ev
		if e.type == type:
			out.append(e)
	return out


func _camp_stand_pos() -> Vector3:
	var res: Resource = load("res://data/player_note_stands.tres")
	return res.entry_in_area(&"camp").camp_pos


# --- RUN 1: the note is written (the pool, 1 per stand) -----------------

func _test_run1_note(ctx: Variant) -> void:
	var ws: Variant = _main.progress.ws
	var wd: Node = _main.world_director
	ctx.check(wd != null, "memory: the WorldDirector is composed")
	# The camp stand is placed (a child of CampWorld, the stable hub).
	var stand: Node = wd.current_stand()
	ctx.check(stand != null and stand.stand_id == &"camp",
			"memory: the camp stand is placed in RUN 1")
	if stand == null:
		return
	ctx.check(not stand.has_readable,
			"memory: RUN 1 the stand has no note to read yet")
	# The stand's Interactable is ticked by the test clock.
	_ticks = [stand.find_child("IA_write_camp", true, false)]
	# Approach + interact: the panel opens (the 5-line pool).
	_walk(_camp_stand_pos(), 5)
	_interact()
	var panel: Node = _main.note_panel
	ctx.check(panel != null and panel.is_open(),
			"memory: interacting opens the note panel")
	if panel == null or not panel.is_open():
		return
	# Write line 2 (not free text — a pool index).
	panel.press(2)
	ctx.check(not panel.is_open(), "memory: writing closes the panel")
	ctx.check(ws.note_line(&"camp") == 2,
			"memory: the world stored the note (line 2)")
	ctx.check(int(ws.get_note(&"camp").run_id) == 1,
			"memory: the note remembers its run")
	ctx.check(_main.progress.stats.notes_written == 1,
			"memory: the notes_written stat is counted (Mara trust)")
	var evs: Array = _events_of_type(1, _EV.Type.NOTE_WRITTEN)
	ctx.check(evs.size() == 1 and int(evs[0].data) == 2,
			"memory: the NOTE_WRITTEN event is recorded (line in data)")
	# The stand now holds the note — but it is READABLE NEXT RUN only.
	ctx.check(not stand.has_readable,
			"memory: the fresh note is not readable in the same run")


# --- Death (a real damage source, the run record, the choice) -----------

func _test_death(ctx: Variant) -> void:
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
	ctx.check(killer != null,
			"memory: a camp enemy is alive for death %d" % run_id)
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
	ctx.check(_player.is_dead(), "memory: death %d the player died"
			% run_id)
	ctx.check(rm.state == _RM.State.DEAD,
			"memory: death %d the run manager is DEAD" % run_id)
	var rec: Variant = _main.progress.ws.runs.get_run(run_id)
	ctx.check(rec != null and rec.deaths == 1
			and rec.last_death_pos != Vector3.ZERO,
			"memory: death %d the run record has a death position"
			% run_id)
	# The K7 trigger is the boss (Phase 12); this test sets the flag
	# by hand BEFORE the RUN 03 rebuild to exercise the «тише» world.
	if run_id == 2:
		_main.progress.ws.set_flag(&"boss_defeated")
	var screen: Node = _main.get_node_or_null("DeathScreen")
	ctx.check(screen != null and _player.death_choice_pending,
			"memory: death %d the respawn waits for the choice"
			% run_id)
	if screen == null:
		return
	screen.press(0)
	_tick(5)
	ctx.check(not _player.is_dead(),
			"memory: death %d the respawn happened" % run_id)


# --- RUN 02: the note is readable; the mummy is not yet ------------------

func _test_run2_note_read(ctx: Variant) -> void:
	var ws: Variant = _main.progress.ws
	ctx.check(_main.run_manager.run_id == 2, "memory: RUN 02 begins")
	var stand: Node = _main.world_director.current_stand()
	ctx.check(stand != null and stand.stand_id == &"camp",
			"memory: RUN 02 the camp stand is placed again")
	if stand == null:
		return
	ctx.check(stand.has_readable,
			"memory: RUN 02 the note is readable (written RUN 1)")
	ctx.check(stand.readable_line == "She's in the lake. Don't look too long.",
			"memory: RUN 02 the readable text is the stored line")
	_ticks = [stand.find_child("IA_write_camp", true, false)]
	_walk(_camp_stand_pos(), 5)
	_interact()
	var evs: Array = _events_of_type(2, _EV.Type.ECHO_NOTE_READ)
	ctx.check(evs.size() == 1,
			"memory: RUN 02 reading the note is recorded (first time)")
	# The mummy is NOT in RUN 02 (run_id < 3).
	var mummy: Node = _main.world_director.current_mummy()
	ctx.check(mummy == null, "memory: RUN 02 has no mummy (too early)")


# --- RUN 03: the mummy (the last_death_pos, the note in hand) ------------

func _test_run3_mummy(ctx: Variant) -> void:
	var ws: Variant = _main.progress.ws
	ctx.check(_main.run_manager.run_id == 3, "memory: RUN 03 begins")
	# K7: the boss flag (set by hand) -> the passive echo is «тише».
	var g: Node = _main.ghost_director
	ctx.check(g.budget_state.passive_remaining() == 0
			and g.budget_state.special_remaining() == 0,
			"k7: RUN 03 the echo budget is «тише» (0 passive, 0 "
			+ "special)")
	var mummy: Node = _main.world_director.current_mummy()
	ctx.check(mummy != null, "memory: RUN 03 the mummy stands where "
			+ "RUN 02 ended")
	if mummy == null:
		return
	# The position: RUN 02's last_death_pos (the camp is stable — the
	# remap keeps it within the hub).
	var rec2: Variant = ws.runs.get_run(2)
	var expect: Vector3 = rec2.last_death_pos
	var got: Vector3 = mummy.position
	ctx.check(absf(got.x - expect.x) < 1.0
			and absf(got.z - expect.z) < 1.0,
			"memory: the mummy is at RUN 02's death position "
			+ "(%.2f,%.2f vs %.2f,%.2f)" % [got.x, got.z,
					expect.x, expect.z])
	# The note in her hand: the player's LAST written note (RUN 1).
	ctx.check(mummy.has_note,
			"memory: the note is in her hand (the player wrote one)")
	ctx.check(mummy.note_text == "She's in the lake. Don't look too long.",
			"memory: it is the last written note (line 2)")
	# Examine: the line + the flag + the event (once).
	_ticks = [mummy.find_child("IA_mummy", true, false)]
	_walk(got + Vector3(0.0, 0.0, 2.0), 5)
	_interact()
	ctx.check(ws.flag(&"corpse_seen"),
			"memory: the examine sets corpse_seen (the world changed)")
	var evs: Array = _events_of_type(3, _EV.Type.MUMMY_EXAMINED)
	ctx.check(evs.size() == 1,
			"memory: the MUMMY_EXAMINED event is recorded")
	# The flag has a consequence line (the «what changed» overlay).
	var table: Variant = _main.run_manager.flag_lines
	ctx.check(table.has(&"corpse_seen"),
			"memory: corpse_seen has a «what changed» line")
	_test_k7_world(ctx)


# --- K7: the post-boss world (fog, the gate glow, the city, calm) ---

func _test_k7_world(ctx: Variant) -> void:
	var ws: Variant = _main.progress.ws
	# The fog: post-boss the gate fog is the pre-boss one * 0.375.
	var we: Node = _main.get_node("WorldEnvironment")
	var e: Variant = we.environment
	_main._set_fog(&"ancient_gate")
	var d_boss: float = e.fog_density
	ws.set_flag(&"boss_defeated", false)
	_main._set_fog(&"ancient_gate")
	var d_pre: float = e.fog_density
	ws.set_flag(&"boss_defeated")
	ctx.check(d_boss < d_pre and absf(d_boss / d_pre - 0.375) < 0.01,
			"k7: the gate fog is 0.8 -> 0.3 (x0.375) post-boss "
			+ "(%.4f -> %.4f)" % [d_pre, d_boss])
	# The gate glow + the city silhouette are placed in the gate area.
	_main._enter_level(&"ancient_gate")
	var k7: Node = _main.world_director
	ctx.check(k7._k7_nodes.size() == 2,
			"k7: the gate area has the glow + the city silhouette")
	var glow: Node = null
	var city: Node = null
	for n in k7._k7_nodes:
		if n is MeshInstance3D:
			glow = n
		elif n is Node3D:
			city = n
	ctx.check(glow != null and city != null,
			"k7: both K7 visuals exist in the level")
	# The camp stand is gone after leaving the camp (per-level).
	# The stand is strictly per-area (the gate has none). The mummy
	# follows the run-space point: it may also stand in another area
	# whose footprint contains the death point (the same rule as the
	# P9 death markers — spatial consistency).
	ctx.check(k7.current_stand() == null,
			"k7: the stand is per-area (none in the gate)")
	_main._enter_level(&"camp")
	# Back in the camp: the mummy is where RUN 02 ended.
	ctx.check(k7.current_mummy() != null,
			"k7: the camp keeps the mummy (the death point)")
	# npc_calm: the post-boss line replaces the normal dialogue.
	var npc: Node = _main.find_child("NPC_mara", true, false)
	ctx.check(npc != null, "k7: Mara is in the camp")
	if npc == null:
		return
	var ia: Node = npc.find_child("IA_mara", true, false)
	_ticks = [ia]
	_walk(npc.global_position + Vector3(0.0, 0.0, 2.0), 5)
	_interact()
	var data: Node = npc.get_data()
	ctx.check(npc._label.text == data.post_boss_line,
			"k7: Mara speaks the post-boss line (npc_calm): %s"
				% npc._label.text)
