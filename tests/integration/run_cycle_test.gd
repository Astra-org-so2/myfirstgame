# Integration: Phase 8 run cycle (ROADMAP Phase 8 exit criteria).
#
# The full loop in one scene: RUN 1 A-anchors (pillar, first swing,
# first Hollow kill + trace, camp note, the figure, Nia in the village,
# the pyre, the gate seal, the shrine whisper, the lake note, the mine
# note) -> the first death (A19: flags, the run record, the death
# screen) -> the respawn rebuild (≤ 2 s, new derived seed, new layout,
# the "what changed" overlay, the "Again?" line, the trace) -> RUN 02
# (the Undercroft opens, the cannon is offered and picked, the B2
# line, the staff waits, Nia is in the village) -> the run record
# (events present, roundtrip).
#
# Rig contract (ADR-022): the player on the MovementPort mock, the
# production clock ticked manually (main._physics_process + ZoneWorld
# + the interactables), Input.action_press for held-edge actions.
extends Node

const _MAIN = preload("res://scripts/world/main_scene.gd")
const _PLAYER = preload("res://scripts/player/player_controller.gd")
const _PORT = preload("res://scripts/player/movement_port.gd")
const _DREQ = preload("res://scripts/gameplay/combat/damage_request.gd")
const _RM = preload("res://scripts/gameplay/run/run_manager.gd")
const _EV = preload("res://scripts/gameplay/run/run_event.gd")

const DT: float = 1.0 / 60.0

var _main: _MAIN
var _player: _PLAYER
var _mock: _PORT
var _ticks: Array = []
var _beats: Array = []
var _run1_fingerprint: String = ""
var _first_kill_pos: Vector3 = Vector3.INF


func _layout_fingerprint() -> String:
	# The seed-driven part of the layout: per-area chain room order
	# + the enemy spawn positions.
	var s: String = ""
	var rl: Variant = _main.run_layout
	for a in rl.areas:
		for rid in rl.chain_of(a):
			s += "%s:%s|" % [a, rid]
	for sp in rl.spawns:
		s += "@%.1f,%.1f " % [sp.position.x, sp.position.z]
	return s


func run(ctx: Variant) -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	ctx.check(packed != null, "cycle: main scene loads")
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
	var fr: Node = _main.find_child("FirstRunDirector", true, false)
	ctx.check(fr != null, "cycle: FirstRunDirector composed")
	fr.beat_fired.connect(func(b: StringName) -> void:
		_beats.append(b))
	_test_run1_anchors(ctx)
	_test_death_and_respawn(ctx)
	_test_run2_world(ctx)
	_test_run_record(ctx)
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
		for t in _ticks:
			if is_instance_valid(t):
				t._physics_process(DT)


func _interact() -> void:
	Input.action_press("interact")
	_tick(3)
	Input.action_release("interact")
	_tick(3)


func _walk_to(pos: Vector3) -> void:
	_mock.set_position(Vector3(pos.x, 0.0, pos.z + 0.8))
	_tick(3)


# --- RUN 1: the A-anchors ------------------------------------------------

func _test_run1_anchors(ctx: Variant) -> void:
	var rm: Node = _main.run_manager
	ctx.check(rm != null and rm.run_id == 1, "cycle: the session starts RUN 1")
	ctx.check(rm.run_seed == 20260917,
			"cycle: RUN 1 uses the canonical session-seed layout")

	# A2 — the pillar.
	var ia_pillar: Node = _main.find_child("IA_Pillar", true, false)
	ctx.check(ia_pillar != null, "cycle: the camp pillar is an interactable")
	var layout: Node = _main.find_child("CampWorld", true, false).layout
	_ticks = [ia_pillar]
	_walk_to(layout.pillar_pos)
	_interact()
	ctx.check(_main.progress.ws.flag(&"pillar_seen"),
			"cycle: A2 the pillar beat sets pillar_seen")
	ctx.check(_beats.has(&"a2_pillar"), "cycle: A2 beat fired")

	# A3 — the first swing (the blade is adopted at the start).
	Input.action_press("attack")
	_tick(45)  # windup 0.5 s + active margin, at 60 Hz
	Input.action_release("attack")
	_tick(5)
	ctx.check(_main.progress.ws.flag(&"blade_found"),
			"cycle: A3 the first swing sets blade_found")
	ctx.check(_beats.has(&"a3_first_swing"), "cycle: A3 beat fired")

	# A5 — the first Hollow kill (the trace stays in the world).
	var hollow: Node = null
	for e in _main.director.get_alive_enemies():
		if e.has_method("get_data_id") and e.get_data_id() == &"hollow_base":
			hollow = e
			break
	ctx.check(hollow != null, "cycle: a Hollow is alive in the camp")
	if hollow != null:
		var req: _DREQ = _DREQ.new()
		req.source = _player
		req.target = hollow
		req.amount = 99.0
		req.type = _DREQ.Type.MELEE
		req.position = hollow.global_position
		req.knockback_direction = Vector3(1.0, 0.0, 0.0)
		_first_kill_pos = hollow.global_position
		_main.resolver.resolve(req)
		var waited: int = 0
		while waited < 120 and not _main.progress.ws.flag(
				&"first_hollow_killed"):
			_tick(1)
			waited += 1
		ctx.check(_main.progress.ws.flag(&"first_hollow_killed"),
				"cycle: A5 the first kill sets first_hollow_killed")
		ctx.check(_beats.has(&"a5_first_kill"), "cycle: A5 beat fired")
		var stored: Variant = _main.progress.ws.get_flag(
				&"first_kill_pos", null)
		ctx.check(typeof(stored) == TYPE_VECTOR3,
				"cycle: the trace position is stored (pos3 data)")

	# A7 — the camp note (#2, own handwriting).
	var ia_note: Node = _main.find_child("IA_NoteStand", true, false)
	_ticks = [ia_note]
	_walk_to(layout.note_stand_pos)
	_interact()
	ctx.check(_beats.has(&"a7_camp_note"), "cycle: A7 the camp note beat")

	# A10 — the figure on the first zone entry (village gate).
	var zw: Node = _main.zone_world
	var camp_ap: Variant = _main.run_layout.get_area(&"camp")
	var vgate: Node = camp_ap.rooms[0].door(&"gate_ruined_village")
	ctx.check(vgate != null, "cycle: the camp has the village gate")
	_ticks = []
	zw._cooldown = 0.0
	_mock.set_position(vgate.local_pos)
	zw._physics_process(DT)
	ctx.check(zw.current == &"ruined_village",
			"cycle: the village gate crossing enters the Village")
	var figure: Node = zw.find_child("EliFigure", true, false)
	ctx.check(figure != null, "cycle: A10 the figure appears")
	ctx.check(_main.progress.ws.flag(&"figure_seen"),
			"cycle: A10 the figure sets figure_seen")
	ctx.check(_beats.has(&"a10_figure"), "cycle: A10 beat fired")

	# A11 — Nia is in the village (not the camp).
	var nia: Node = _main.find_child("NPC_nia", true, false)
	ctx.check(nia != null and nia.get_parent() == zw.level,
			"cycle: A11 Nia lives in the village level")
	if nia != null:
		var ia_nia: Node = nia.find_child("IA_nia", true, false)
		_ticks = [ia_nia]
		_walk_to(nia.global_position)
		_interact()
		ctx.check(nia.current_line() == "You already asked me that.",
				"cycle: A11 Nia's line is the canonical one")

	# A12 — the pyre (the ash of one hut of five).
	var v_ap: Variant = _main.run_layout.get_area(&"ruined_village")
	var v_rooms: Array = v_ap.rooms
	var base: Node = v_rooms[1] if v_rooms.size() >= 2 else v_rooms[0]
	var pyre: Vector3 = Vector3(base.origin.x, 0.0, base.origin.z) \
			+ Vector3(2.5, 0.0, 2.5)
	_ticks = []
	_mock.set_position(Vector3(pyre.x, 0.0, pyre.z + 1.0))
	_tick(5)
	ctx.check(_main.progress.ws.flag(&"village_pyre_seen"),
			"cycle: A12 seeing the pyre sets village_pyre_seen")
	ctx.check(_beats.has(&"a12_pyre"), "cycle: A12 beat fired")

	# A16 — the gate (sealed in RUN 1) + A15 the shrine + A17 the lake
	# + A14 the mine (note, not weapon) — production entries.
	_main._enter_level(&"ancient_gate")
	ctx.check(_main.progress.ws.flag(&"gate_seal_seen"),
			"cycle: A16 the gate engraving sets gate_seal_seen")
	ctx.check(_beats.has(&"a16_gate"), "cycle: A16 beat fired")
	ctx.check(_main.find_child("NoteStand_gate_footnotes",
			true, false) != null,
			"cycle: A16 the three footnotes stand at the base")
	_main._enter_level(&"old_shrine")
	ctx.check(_main.progress.ws.flag(&"shrine_echo_seen"),
			"cycle: A15 the whisper sets shrine_echo_seen")
	ctx.check(_beats.has(&"a15_shrine"), "cycle: A15 beat fired")
	_main._enter_level(&"mysterious_lake")
	var lake_note: Node = _main.find_child("NoteStand_lake_note",
			true, false)
	ctx.check(lake_note != null, "cycle: A17 the lake note stands by the shore")
	if lake_note != null:
		var ia_lake: Node = lake_note.find_child(
				"IA_note_lake_note", true, false)
		_ticks = [ia_lake]
		_walk_to(lake_note.global_position)
		_interact()
		ctx.check(_main.progress.ws.flag(&"lake_note_read"),
				"cycle: A17 reading the lake note sets lake_note_read")
	_main._enter_level(&"the_mine")
	var mine_note: Node = _main.find_child(
			"NoteStand_box_note_weapon_cannon", true, false)
	ctx.check(mine_note != null, "cycle: A14 the mine box carries the note")
	_ticks = []
	_main._enter_level(&"camp")
	ctx.check(zw.is_camp(), "cycle: back at the camp")

	# The RUN 1 layout fingerprint (the rebuild must change it).
	_run1_fingerprint = _layout_fingerprint()


# --- A19: the first death -> the respawn rebuild -------------------------

func _test_death_and_respawn(ctx: Variant) -> void:
	var rm: Node = _main.run_manager
	var ws: Variant = _main.progress.ws
	# A living camp enemy (the death comes from a real source).
	var enemies: Array = _main.director.get_alive_enemies()
	var killer: Node = null
	for e in enemies:
		if e.has_method("get_data_id") \
				and e.get_data_id() == &"watcher_base":
			killer = e
			break
	if killer == null and enemies.size() > 0:
		killer = enemies[0]
	ctx.check(killer != null, "cycle: a camp enemy is alive for the death")
	# The death position comes from the bus (knockback may move the
	# body — the record must store where the death ACTUALLY is).
	var death_pos: Vector3 = Vector3.ZERO
	var got_death: Array = []
	var bus: Node = get_tree().root.get_node_or_null("EventBus")
	bus.player_died.connect(func(p: Vector3) -> void:
		got_death.append(p))
	var req: _DREQ = _DREQ.new()
	req.source = killer
	req.target = _player
	req.amount = 500.0
	req.type = _DREQ.Type.MELEE
	req.position = _mock.get_position()
	req.knockback_direction = Vector3(1.0, 0.0, 0.0)
	_main.resolver.resolve(req)
	_tick(1)
	ctx.check(_player.is_dead(), "cycle: A19 the player died")
	if got_death.size() > 0:
		death_pos = got_death[0]
	ctx.check(rm.state == _RM.State.DEAD, "cycle: the run manager is DEAD")

	# A19: the first death opens the world (flags) and stores the run.
	ctx.check(ws.flag(&"run_02_door_open"),
			"cycle: A19 run_02_door_open set on the first death")
	ctx.check(ws.flag(&"first_death_done"),
			"cycle: A19 first_death_done set")
	ctx.check(ws.flag(&"cannon_found") and ws.flag(&"staff_found"),
			"cycle: A14/A15 the weapons wait from RUN 02 (flags)")
	ctx.check(ws.flag(&"kettle_washed"), "cycle: B1 the kettle is washed")
	var rec: Variant = ws.runs.latest()
	ctx.check(rec != null and rec.run_id == 1 and rec.deaths == 1,
			"cycle: the finished run is stored in world_state.runs")
	ctx.check(rec != null and got_death.size() > 0
			and rec.last_death_pos == death_pos,
			"cycle: last_death_pos stored (the mummy's seed, RUN 03)")

	# The death screen (P6) makes the 1-of-3 choice.
	var screen: Node = _main.get_node_or_null("DeathScreen")
	ctx.check(screen != null and _player.death_choice_pending,
			"cycle: the respawn waits for the 1-of-3 choice")
	if screen == null:
		return
	screen.press(0)
	ctx.check(not _player.death_choice_pending,
			"cycle: the choice unblocks the respawn")

	# The rebuild budget (TECHNICAL_DESIGN §12): death -> new run ≤ 2 s.
	var t0: int = Time.get_ticks_msec()
	_tick(2)
	var t1: int = Time.get_ticks_msec()
	ctx.check(not _player.is_dead(), "cycle: the player respawned")
	ctx.check(t1 - t0 < 2000,
			"cycle: the death->respawn rebuild is under 2 s (%d ms)"
			% (t1 - t0))

	# RUN 02: a new run, a new layout, back at the camp.
	ctx.check(rm.run_id == 2 and rm.state == _RM.State.PLAYING,
			"cycle: the respawn began RUN 02")
	ctx.check(rm.run_seed != 20260917 and rm.run_seed != 0,
			"cycle: RUN 02 uses a derived (different) layout seed")
	ctx.check(_main.zone_world.is_camp(),
			"cycle: the respawn is at the camp")
	var fp2: String = _layout_fingerprint()
	ctx.check(fp2 != _run1_fingerprint,
			"cycle: the layout changed on the respawn (new seed)")
	# The sealed edge is open now (A16 -> B2): the Mine's forward door
	# resolves to the Undercroft.
	var mine_ap: Variant = _main.run_layout.get_area(&"the_mine")
	var conn: Node = null
	for c in mine_ap.area.connections:
		if c.to == &"undercroft":
			conn = c
	var fwd: Node = mine_ap.rooms.back().door(conn.door)
	ctx.check(fwd != null and not fwd.is_sealed()
			and fwd.to_area == &"undercroft",
			"cycle: RUN 02 the Undercroft edge is open")

	# "What changed" (WORLD_STATE_DESIGN §9.2): the lines at the
	# respawn — door + weapons + kettle, ≤ 5, no numbers.
	var label: Node = _main._changed_label
	ctx.check(label != null and label.text != "",
			"cycle: the 'what changed' overlay is shown")
	if label != null:
		var text: String = label.text
		ctx.check(text.contains("The door past the gate has opened."),
				"cycle: the changed lines include the door")
		ctx.check(text.contains("The cannon waits in the mine."),
				"cycle: the changed lines include the cannon")
		var line_count: int = text.split("\n").size()
		ctx.check(line_count <= 5,
				"cycle: the changed lines are ≤ 5 (%d)" % line_count)
	# A19: the "Again?" line, once.
	ctx.check(_main.toast.current_text() == "Again?",
			"cycle: A19 the 'Again?' line shows at the respawn")
	# A5: the trace of the first kill is in the camp.
	var trace: Node = _main.find_child("A5_Trace", true, false)
	ctx.check(trace != null, "cycle: A5 the kill trace appears in RUN 02")
	if trace != null and typeof(_first_kill_pos) == TYPE_VECTOR3:
		ctx.check(trace.global_position.distance_to(_first_kill_pos) < 0.1,
				"cycle: the trace is where the first Hollow fell")
	# B1: Mara's return line is armed for her first talk of the run.
	var mara: Node = _main.find_child("NPC_mara", true, false)
	ctx.check(mara != null and not mara._return_line_used,
			"cycle: B1 Mara's return line is unused (once per run)")


# --- RUN 02: the open world ------------------------------------------------

func _test_run2_world(ctx: Variant) -> void:
	# The cannon is offered now (A14, RUN 02+).
	_main._enter_level(&"the_mine")
	var pickup: Node = _main.find_child("WeaponPickup_cannon",
			true, false)
	ctx.check(pickup != null, "cycle: RUN 02 the cannon waits in the Mine")
	if pickup == null:
		return
	ctx.check(_main.find_child("NoteStand_box_note_weapon_cannon",
			true, false) == null,
			"cycle: RUN 02 the box note is gone (the weapon is there)")
	var ia: Node = pickup.find_child("IA_pickup_weapon_cannon",
			true, false)
	_ticks = [ia]
	_walk_to(pickup.global_position)
	_interact()
	ctx.check(_main.loadout.has(&"weapon_cannon"),
			"cycle: RUN 02 the cannon entered the loadout")
	ctx.check(_main.progress.ws.is_weapon_found(&"weapon_cannon"),
			"cycle: the find is permanent (world state)")
	# The Undercroft leg (the RUN 02 part of the P7 seam).
	var zw: Node = _main.zone_world
	var mine_ap: Variant = _main.run_layout.get_area(&"the_mine")
	var conn: Node = null
	for c in mine_ap.area.connections:
		if c.to == &"undercroft":
			conn = c
	var last_rp: Node = mine_ap.rooms.back()
	var fwd: Node = last_rp.door(conn.door)
	_ticks = []
	zw._cooldown = 0.0
	_mock.set_position(last_rp.origin + fwd.local_pos)
	zw._physics_process(DT)
	ctx.check(zw.current == &"undercroft",
			"cycle: RUN 02 the forward door enters the Undercroft")
	var boss_ap: Variant = _main.run_layout.get_area(&"undercroft")
	var home: Node = boss_ap.rooms[0].door(&"entry_mine")
	ctx.check(home != null, "cycle: the arena has the entry_mine door")
	zw._cooldown = 0.0
	_mock.set_position(boss_ap.rooms[0].origin + home.local_pos)
	zw._physics_process(DT)
	ctx.check(zw.current == &"the_mine",
			"cycle: the entry_mine door returns to the Mine")
	# B2: the gate — the first open-gate sighting after the seal.
	_main._enter_level(&"ancient_gate")
	ctx.check(_beats.has(&"b2_gate_open"),
			"cycle: B2 'That wasn't there.' fires once")
	# The staff waits in the Shrine (A15, RUN 02+).
	_main._enter_level(&"old_shrine")
	ctx.check(_main.find_child("WeaponPickup_staff", true, false) != null,
			"cycle: RUN 02 the staff waits at the Shrine")
	# Nia is still in her village (the rebuild kept her).
	_main._enter_level(&"ruined_village")
	var nia: Node = _main.find_child("NPC_nia", true, false)
	ctx.check(nia != null and nia.get_parent() == zw.level,
			"cycle: Nia re-joined the village level after the rebuild")
	_main._enter_level(&"camp")


# --- the run record (TECHNICAL_DESIGN §2/§3) -------------------------------

func _test_run_record(ctx: Variant) -> void:
	var ws: Variant = _main.progress.ws
	var rm: Node = _main.run_manager
	# RUN 1 record: the events of the scripted first run.
	var r1: Variant = ws.runs.get_run(1)
	ctx.check(r1 != null, "record: RUN 1 is in the history")
	if r1 == null:
		return
	var types: Dictionary = {}
	for ev in r1.events:
		types[ev.type] = true
	ctx.check(types.has(_EV.Type.PLAYER_DIED),
			"record: RUN 1 has PLAYER_DIED")
	ctx.check(types.has(_EV.Type.ENEMY_KILLED),
			"record: RUN 1 has ENEMY_KILLED (the first Hollow)")
	ctx.check(types.has(_EV.Type.ATTACK),
			"record: RUN 1 has ATTACK (the first swing)")
	ctx.check(types.has(_EV.Type.ENTER_ROOM),
			"record: RUN 1 has ENTER_ROOM (the zone entries)")
	ctx.check(types.has(_EV.Type.NPC_TALKED),
			"record: RUN 1 has NPC_TALKED (Nia)")
	ctx.check(types.has(_EV.Type.EVENT_COMPLETED),
			"record: RUN 1 has EVENT_COMPLETED (the A-anchors)")
	ctx.check(types.has(_EV.Type.NOTE_WRITTEN),
			"record: RUN 1 has NOTE_WRITTEN (the notes)")
	ctx.check(r1.kills >= 1, "record: RUN 1 summary counts the kill")
	var last_ev: Variant = r1.events.back()
	ctx.check(last_ev.type == _EV.Type.PLAYER_DIED,
			"record: PLAYER_DIED closes the RUN 1 log")
	# RUN 2 record: the new run is being recorded (spawn event first).
	var r2: Variant = rm.current_record
	ctx.check(r2 != null and r2.run_id == 2,
			"record: the current run is RUN 02")
	ctx.check(r2.events.size() >= 1
			and r2.events[0].type == _EV.Type.PLAYER_SPAWNED,
			"record: RUN 02 starts with PLAYER_SPAWNED")
	# The section roundtrips (the save format, P15 consumes it).
	var hist: Variant = _main.progress.ws.runs
	var ok: bool = hist.load_json(hist.to_json())
	ctx.check(ok, "record: the runs section roundtrips via JSON")
	# And the cannon pickup of RUN 02 is recorded as an ITEM_PICKED
	# (the event bus bridge).
	var picked: bool = false
	for ev in r2.events:
		if ev.type == _EV.Type.ITEM_PICKED:
			picked = true
	ctx.check(picked, "record: RUN 02 recorded the cannon pickup")

