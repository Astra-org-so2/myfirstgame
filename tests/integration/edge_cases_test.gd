# Integration: TEST_PLAN §6 edge-cases matrix — the Phase 17 sweep.
#
# One labeled check per matrix row. Rows the MVP has no mechanic for
# are documented as N/A (not faked):
#   - «parallel launch (lock file)» — Android is single-instance; the
#     in-process analogue (two back-to-back saves, no torn state) is
#     tested; kill-mid-write + ENOSPC are P15 (save_manager_test).
#   - «player item drop in the world» — items are found/used, never
#     dropped by the player; the enemy LOOT drop path is tested
#     (cap gate, pickup, full-inventory feedback, dead-player edge).
#   - «modal pause» — no pause menu (8 s run loop); the mobile
#     analogue is app backgrounding (engine auto-pause, delta-driven
#     timers stop) — tested as the backgrounding proxy.
#
# Rig contract (ADR-022): player on the MovementPort mock, manual
# _physics_process ticks, Input.action_press for held-edge actions.
extends Node

const _MAIN = preload("res://scripts/world/main_scene.gd")
const _PLAYER = preload("res://scripts/player/player_controller.gd")
const _PORT = preload("res://scripts/player/movement_port.gd")
const _DREQ = preload("res://scripts/gameplay/combat/damage_request.gd")
const _ENTRY = preload("res://scripts/gameplay/enemies/spawn_entry.gd")
const _TABLE = preload("res://scripts/gameplay/enemies/spawn_table.gd")
const _DIRECTOR = preload("res://scripts/gameplay/enemies/enemy_director.gd")
const _ITEM = preload("res://scripts/gameplay/progression/item_data.gd")
const _REC = preload("res://scripts/gameplay/run/run_record.gd")
const _EV = preload("res://scripts/gameplay/run/run_event.gd")
const _RM = preload("res://scripts/gameplay/run/run_manager.gd")
const _BST = preload("res://scripts/gameplay/boss/boss_logic.gd")
const _AP = preload("res://scripts/gameplay/rooms/area_placement.gd")
const _RP = preload("res://scripts/gameplay/rooms/room_placement.gd")
const _RL = preload("res://scripts/gameplay/rooms/run_layout.gd")

const DT: float = 1.0 / 60.0

var _main: _MAIN
var _player: _PLAYER
var _mock: _PORT
var _died: int = 0


func _tick(n: int) -> void:
	for i in n:
		_main._physics_process(DT)
		var zw: Node = _main.zone_world
		if zw != null and is_instance_valid(zw):
			zw._physics_process(DT)
		if _main.director != null \
				and is_instance_valid(_main.director):
			_main.director._physics_process(DT)
		if _main.boss != null and is_instance_valid(_main.boss):
			_main.boss._physics_process(DT)
		for e in _main.director.get_alive_enemies():
			if e.has_method("_physics_process"):
				e._physics_process(DT)


func _lethal(source: Node) -> void:
	var req: _DREQ = _DREQ.new()
	req.source = source
	req.target = _player
	req.amount = 500.0
	req.type = _DREQ.Type.MELEE
	req.position = _mock.get_position()
	req.knockback_direction = Vector3(1.0, 0.0, 0.0)
	_main.resolver.resolve(req)
	_tick(1)


func _press_death_screen() -> void:
	var screen: Node = _main.get_node_or_null("DeathScreen")
	assert(screen != null)
	screen.press(0)


func _any_enemy(ctx: Variant, label: String) -> Node:
	var enemies: Array = _main.director.get_alive_enemies()
	if enemies.is_empty():
		ctx.check(false, label + ": no living enemy to use as source")
		return null
	return enemies[0]


func _count_drops() -> int:
	var n: int = 0
	for d in _main._drops:
		if d != null and is_instance_valid(d):
			n += 1
	return n


func _count_meshes(root: Node) -> int:
	if root == null:
		return 0
	var n: int = 0
	for c in root.get_children():
		if c is MeshInstance3D:
			n += 1
		n += _count_meshes(c)
	return n


func run(ctx: Variant) -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	ctx.check(packed != null, "edge: main scene loads")
	if packed == null:
		return
	var scene: Node = packed.instantiate()
	_main = scene
	var player_node: Node = scene.find_child("Player", true, false)
	_player = player_node
	if _player == null:
		ctx.check(false, "edge: player present")
		return
	_mock = _PORT.new(null,
			_player.data.gravity, _player.data.max_fall_speed)
	_player.set_port(_mock)
	add_child(scene)
	_main.set_physics_process(false)
	var bus: Node = get_tree().root.get_node_or_null("EventBus")
	bus.player_died.connect(func(_p: Vector3) -> void:
		_died += 1)

	_test_double_death(ctx)
	_test_death_during_dialogue(ctx)
	_test_death_during_boss_phase(ctx)
	_test_death_during_transition(ctx)
	_test_death_after_respawn(ctx)
	_test_saves(ctx)
	_test_inventory(ctx)
	_test_world_edges(ctx)
	_test_ghost_edges(ctx)
	_test_backgrounding(ctx)

	# The other scene tests end the same way (queue_free, no await:
	# the deferred free lands on the next pump).
	_main.queue_free()


# --- Death rows ----------------------------------------------------------

func _test_double_death(ctx: Variant) -> void:
	var killer: Node = _any_enemy(ctx, "double-death")
	if killer == null:
		return
	_lethal(killer)
	ctx.check(_player.is_dead() and _died == 1,
			"death: the first lethal hit kills (exactly once)")
	# The second lethal hit AND a scripted hitstun hit while dead.
	_lethal(killer)
	_player.take_hit(Vector3(1.0, 0.0, 0.0))
	_tick(2)
	ctx.check(_died == 1,
			"death: double-death — no second death event")
	ctx.check(_main.run_manager.state == _RM.State.DEAD,
			"death: the run manager stays DEAD")
	_press_death_screen()
	_tick(5)
	ctx.check(not _player.is_dead(),
			"death: the respawn after the double-death window")
	# A stray request_respawn while alive is a no-op.
	_player.request_respawn()
	_tick(2)
	ctx.check(not _player.is_dead(),
			"death: request_respawn while alive is a no-op")


func _test_death_during_dialogue(ctx: Variant) -> void:
	# A camp NPC line is active (3 s window) when the death comes.
	var npc: Node = null
	for n in _main._npcs:
		if n != null and is_instance_valid(n):
			npc = n
			break
	ctx.check(npc != null, "dialogue: a camp NPC exists")
	if npc == null:
		return
	var ia: Node = npc.get("_ia")
	ctx.check(ia != null, "dialogue: the NPC interactable exists")
	_mock.set_position(npc.global_position + Vector3(1.0, 0.0, 0.0))
	Input.action_press(&"interact")
	for i in 3:
		_tick(1)
		ia._physics_process(DT)  # the rig does not auto-pump the NPC
	Input.action_release(&"interact")
	for i in 3:
		_tick(1)
		ia._physics_process(DT)
	ctx.check(float(npc.get("_line_left")) > 0.0,
			"dialogue: the NPC line is active before the death")
	var killer: Node = _any_enemy(ctx, "dialogue")
	if killer == null:
		return
	_lethal(killer)
	ctx.check(_player.is_dead(),
			"dialogue: the player dies while the line is up")
	# The death screen rides on top; the choice works; the NPC's
	# label keeps its own clock (no crash, no stuck state).
	_press_death_screen()
	_tick(5)
	ctx.check(not _player.is_dead(),
			"dialogue: the respawn works after a mid-line death")
	ctx.check(float(npc.get("_line_left")) <= 3.0,
			"dialogue: the NPC line window is intact")


func _test_death_during_boss_phase(ctx: Variant) -> void:
	_main._enter_level(&"undercroft")
	_tick(5)
	var boss: Node = _main.boss
	ctx.check(boss != null and is_instance_valid(boss),
			"boss: THE FIRST is in the arena")
	if boss == null:
		return
	boss.start_fight()
	_mock.set_position(boss.global_position + Vector3(0.0, 0.0, 1.5))
	_tick(30)
	ctx.check(boss.logic.state != _BST.State.IDLE,
			"boss: the fight is in progress before the death")
	var hp0: float = boss.logic.hp()
	# A lethal hit from the boss (the resolver path is identical for
	# any source; the boss's slam does this in play).
	var req: _DREQ = _DREQ.new()
	req.source = boss
	req.target = _player
	req.amount = 500.0
	req.type = _DREQ.Type.MELEE
	req.position = _mock.get_position()
	_main.resolver.resolve(req)
	_tick(1)
	ctx.check(_player.is_dead(), "boss: the player dies mid-fight")
	_press_death_screen()
	_tick(5)
	ctx.check(not _player.is_dead(), "boss: the respawn works mid-fight")
	ctx.check(is_instance_valid(boss),
			"boss: THE FIRST survived the player's death")
	ctx.check(boss.logic.hp() <= hp0 + 0.01,
			"boss: his fight state is not reset by the death")


func _test_death_during_transition(ctx: Variant) -> void:
	# Death the moment a level transition lands (the player is not
	# yet stabilized in the new area).
	_main._enter_level(&"the_mine")
	_mock.set_position(Vector3(1000.0, 0.0, 1000.0))
	var killer: Node = _any_enemy(ctx, "transition")
	if killer == null:
		return
	_lethal(killer)
	ctx.check(_player.is_dead(),
			"transition: death right after the level swap")
	_press_death_screen()
	_tick(5)
	ctx.check(not _player.is_dead(),
			"transition: the respawn works after the swap")
	ctx.check(_main.zone_world != null
			and _main.zone_world.level != null,
			"transition: the level is still built after the round trip")
	ctx.check(_main.director.get_alive_enemies().size() > 0,
			"transition: the enemies survived the round trip")


func _test_death_after_respawn(ctx: Variant) -> void:
	# The §6 «right after the respawn» row: the hit lands the moment
	# the player is alive again — a NEW, accounted death, not a
	# flapping state.
	var killer: Node = _any_enemy(ctx, "after-respawn")
	if killer == null:
		return
	_lethal(killer)
	var died_before: int = _died
	_press_death_screen()
	_tick(5)
	ctx.check(not _player.is_dead(), "after-respawn: the first respawn")
	_lethal(killer)
	_tick(2)
	ctx.check(_player.is_dead() and _died == died_before + 1,
			"after-respawn: the second death is a NEW accounted death")
	_press_death_screen()
	_tick(5)
	ctx.check(not _player.is_dead(),
			"after-respawn: the run recovers (no flapping)")


# --- Save rows -----------------------------------------------------------

func _test_saves(ctx: Variant) -> void:
	var sm: Node = _main.save_manager
	ctx.check(sm != null, "save: the save manager is composed")
	if sm == null:
		return
	var ws: Variant = _main.progress.ws
	var ok1: bool = sm.save(ws.to_dict(), {})
	var ok2: bool = sm.save(ws.to_dict(), {})
	ctx.check(ok1 and ok2,
			"save: two back-to-back saves both succeed — the "
			+ "in-process analogue of the §6 parallel row (Android "
			+ "is single-instance: no lock file needed)")
	var ld: Dictionary = sm.load()
	var w0: Dictionary = ld.get("world", {}) as Dictionary
	ctx.check(ld.get("status", "") == "ok" and w0.size() > 0,
			"save: the file is a valid envelope after the overwrite "
			+ "(status=%s world=%d)"
			% [ld.get("status", ""), w0.size()])
	ctx.check(FileAccess.file_exists(sm.path + ".tmp") == false,
			"save: no .tmp orphan after sequential writes")
	# kill-mid-write + ENOSPC: P15, save_manager_test (the .tmp->
	# rename proof + the quota path) — not re-derived here.


# --- Inventory rows ------------------------------------------------------

func _test_inventory(ctx: Variant) -> void:
	var inv: Variant = _main.inventory
	var item: _ITEM = _main._CAMP_ITEM
	ctx.check(inv != null and item != null,
			"inventory: the logic + the camp item exist")
	if inv == null:
		return
	# Duplicates: the per-run cap is enforced by the logic itself.
	inv.clear()
	var added: int = 0
	for i in 6:
		if inv.add(item) >= 0:
			added += 1
	ctx.check(inv.count(item.id) == 3 and added == 3,
			"inventory: duplicate items stop at the per-run cap")
	ctx.check(inv.add(item) == -1,
			"inventory: the over-cap add is rejected (no hidden overflow)")
	# Full inventory: all 12 slots taken (9 of a distinct id + 3 of
	# the capped one). duplicate() — the rig's Resource.new() is not
	# a reliable constructor (P17 probe).
	var other: _ITEM = item.duplicate()
	other.id = &"qa_other"
	other.display_name = "QA other"
	other.max_per_run = 99
	for i in 9:
		inv.add(other)
	ctx.check(inv.count(item.id) == 3 and inv.occupied() == 12,
			"inventory: the 12-slot inventory fills to the brim")
	ctx.check(inv.add(other) == -1 and inv.add(item) == -1,
			"inventory: the full inventory rejects both adds")
	# The loot-drop gate: at the cap, a kill drops nothing.
	inv.clear()
	for i in 3:
		inv.add(item)
	var drops_before: int = _count_drops()
	_main._on_enemy_killed(&"watcher_base", _mock.get_position())
	ctx.check(_count_drops() == drops_before,
			"inventory: at the per-run cap a kill drops no loot")
	# Below the cap + a forced lucky roll (a scratch RNG for the
	# search — the check must not consume a draw from the scene's
	# own generator): the drop spawns and is picked up.
	inv.clear()
	var scratch: RandomNumberGenerator = RandomNumberGenerator.new()
	var seed: int = 0
	while seed < 10000 and true:
		scratch.seed = seed
		if scratch.randf() < 0.1:
			break
		seed += 1
	ctx.check(seed < 10000, "inventory: a lucky drop roll exists")
	_main._drop_rng.seed = seed  # its NEXT draw is the lucky one
	_main._on_enemy_killed(&"watcher_base", _mock.get_position())
	var drop: Node = null
	for n in _main._drops:
		if n != null and is_instance_valid(n):
			drop = n
			break
	ctx.check(drop != null, "inventory: below the cap the loot drops")
	if drop == null:
		return
	# The bag is filled around the pickup: 11 of the other item,
	# then the camp fire takes the LAST free slot.
	for i in 11:
		inv.add(other)
	var dia: Node = drop.get("interactable")
	_mock.set_position(drop.global_position + Vector3(1.0, 0.0, 0.0))
	Input.action_press(&"interact")
	for i in 2:
		_tick(1)
		if dia != null:
			dia._physics_process(DT)  # the rig does not auto-pump it
	Input.action_release(&"interact")
	_tick(1)
	ctx.check(inv.count(item.id) == 1 and inv.occupied() == 12,
			"inventory: the pickup takes the last free slot "
			+ "(the drop is pickable — P17 fixed the dead "
			+ "interacted signal + the scene-root target)")
	# The second drop finds the bag FULL: 11 other + 1 camp fire.
	# The rejection must be player-visible (§6: «отказ + feedback»).
	_main._drop_rng.seed = seed
	_main._on_enemy_killed(&"watcher_base", _mock.get_position())
	var drop2: Node = null
	for n in _main._drops:
		if n != null and is_instance_valid(n) and n != drop:
			drop2 = n
			break
	if drop2 != null:
		var dia2: Node = drop2.get("interactable")
		_mock.set_position(drop2.global_position + Vector3(1.0, 0.0, 0.0))
		Input.action_press(&"interact")
		for i in 2:
			_tick(1)
			if dia2 != null:
				dia2._physics_process(DT)
		Input.action_release(&"interact")
		_tick(1)
		ctx.check(inv.count(item.id) == 1
				and String(_main.toast._label.text)
						.contains("No room in the bag."),
				"inventory: the full-inventory pickup is rejected "
				+ "with the player-visible feedback")
	# The dead-player edge: a present drop, a dead player, an
	# interact — no crash, the state is coherent afterwards.
	var killer: Node = _any_enemy(ctx, "dead-drop")
	if killer != null:
		_lethal(killer)
		if drop2 != null and is_instance_valid(drop2):
			var dia3: Node = drop2.get("interactable")
			_mock.set_position(drop2.global_position
					+ Vector3(1.0, 0.0, 0.0))
			Input.action_press(&"interact")
			for i in 2:
				_tick(1)
				if dia3 != null:
					dia3._physics_process(DT)
			Input.action_release(&"interact")
		ctx.check(_player.is_dead() and _main.zone_world != null,
				"inventory: dead player + present drop = coherent "
				+ "state (no crash)")
		_press_death_screen()
		_tick(5)
	# Player-side item drops: no such mechanic in the MVP (items are
	# found/used, never dropped) — the §6 row is N/A by design.

# --- World rows ----------------------------------------------------------

func _test_world_edges(ctx: Variant) -> void:
	# W1: an enemy spawn outside the map (non-finite position) —
	# the data net (validate) + the runtime guard (director skip).
	var edata: Variant = null
	for e in _main.director.get_alive_enemies():
		if e != null and e.has_method("data"):
			edata = e.data()
			break
	ctx.check(edata != null, "world: an enemy data exists for the row")
	if edata == null:
		return
	var bad: _ENTRY = _ENTRY.new()
	bad.enemy = edata  # Variant -> typed: the rig data is EnemyData
	bad.position = Vector3(NAN, 0.0, 0.0)
	var probs: Array = bad.validate()
	ctx.check(probs.size() > 0,
			"world: a non-finite spawn position fails validate()")
	var table: _TABLE = _TABLE.new()
	table.entries = [bad]
	var dir: _DIRECTOR = _DIRECTOR.new()
	dir.name = "EdgeDirector"
	add_child(dir)
	dir.setup(_player, _main.tracker.stats, _main._THR_DATA,
			_main.resolver)
	dir.start(table)
	ctx.check(dir.get_alive_enemies().is_empty(),
			"world: the broken spawn is skipped (no off-map enemy)")
	dir.queue_free()
	await get_tree().process_frame

	# W2: missing asset — the texture bank is null: rooms fall back
	# to flat-color geometry (no crash, meshes present).
	var saved_bank: Node = _main.textures
	_main.textures = null
	_main._enter_level(&"the_mine")
	_tick(3)
	var meshes: int = _count_meshes(_main.zone_world.level)
	ctx.check(meshes > 0,
			"world: rooms build without the texture bank "
			+ "(flat-color fallback, %d meshes)" % meshes)
	_main.textures = saved_bank
	_main._enter_level(&"the_mine")
	_tick(2)

	# W3: invalid world state (a hand-corrupted save) — the load
	# matrix lands on a documented outcome (quarantine the bad file,
	# recover the .bak or start fresh), never a crash.
	var sm: Node = _main.save_manager
	var path: String = sm.path
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_string("not a save at all }{")
	f.close()
	var ld: Dictionary = sm.load()
	var status: String = String(ld.get("status", ""))
	ctx.check(status == "recovered_bak" or status == "fresh"
			or status == "ok",
			"world: the corrupted save lands on a documented "
			+ "outcome (got: %s)" % status)
	var quarantined: bool = false
	var da: DirAccess = DirAccess.open("user://save_test")
	if da != null:
		for fname in da.get_files():
			if fname.contains(".corrupt"):
				quarantined = true
	ctx.check(quarantined or status == "ok",
			"world: the bad file is quarantined (.corrupt_*) "
			+ "or never corrupt at all")
	ctx.check(FileAccess.file_exists(path + ".tmp") == false,
			"world: no .tmp orphan around the corrupted save")


# --- Ghost rows ----------------------------------------------------------

func _test_ghost_edges(ctx: Variant) -> void:
	var gd: Node = _main.ghost_director
	var rm: Node = _main.run_manager
	var ws: Variant = _main.progress.ws
	var rl: Variant = _main.run_layout
	ctx.check(gd != null, "ghost: the director is composed")
	if gd == null:
		return
	# G1: ghost without a log (null record) — graceful, no ghost.
	gd.prepare_run(rm.run_id + 1, ws, null, rl, rl)
	ctx.check(not gd.has_passive(),
			"ghost: a null run record gives no ghost (graceful)")
	# G2: a record below the replay minimum (1 event) — the same
	# graceful path (the director requires >= 2 events).
	var tiny: _REC = _REC.new()
	tiny.run_id = rm.run_id + 1
	tiny.events = [_ev_at_first_room(rl)]
	gd.prepare_run(rm.run_id + 2, ws, tiny, rl, rl)
	ctx.check(not gd.has_passive(),
			"ghost: a one-event record gives no ghost (graceful)")
	# G3: the layout mismatch — the OLD layout's rooms are gone from
	# the new one; the remap must land somewhere finite, not crash.
	var old: _RL = _RL.new()
	var ap_old: _AP = _AP.new()
	var rp: _RP = _RP.new()
	rp.room = load("res://data/rooms/camp_room.tres")
	rp.origin = Vector3(-50.0, 0.0, 0.0)
	ap_old.rooms.append(rp)
	old.areas = {&"the_mine": ap_old}
	var rec: _REC = _REC.new()
	rec.run_id = rm.run_id + 3
	rec.events = [_ev_at_pos(Vector3(-49.0, 0.0, 1.0)),
			_ev_at_pos(Vector3(-48.0, 0.0, 2.0))]
	gd.prepare_run(rm.run_id + 4, ws, rec, old, rl)
	ctx.check(gd.has_passive(),
			"ghost: the layout-mismatch record still replays")
	var tl: Node = gd.get("_timeline")
	if tl != null:
		var p: Vector3 = tl.sample(0.5)
		ctx.check(p.is_finite(),
				"ghost: the remapped position is finite "
				+ "(the missing-room fallback)")
	# G4: the passive ghost of a finished run with enough events.
	var full_rec: _REC = null
	for r in ws.runs.full:
		if r != null and (r.events as Array).size() >= 2:
			full_rec = r
			break
	if full_rec == null:
		full_rec = _REC.new()
		full_rec.run_id = rm.run_id + 5
		full_rec.events = [_ev_at_first_room(rl),
				_ev_at_first_room(rl)]
	gd.prepare_run(full_rec.run_id + 1, ws, full_rec, rl, rl)
	ctx.check(gd.has_passive(),
			"ghost: the last finished run becomes the passive ghost")


func _ev_at_first_room(rl: Variant) -> Variant:
	var ev: _EV = _EV.new()
	ev.type = _EV.Type.ENTER_ROOM
	var o: Vector3 = Vector3.ZERO
	for a in rl.areas:
		var ap: Variant = rl.areas[a]
		if (ap.rooms as Array).size() > 0:
			o = (ap.rooms as Array)[0].origin
			break
	ev.x = int(o.x * 100.0)
	ev.z = int(o.z * 100.0)
	return ev


func _ev_at_pos(p: Vector3) -> Variant:
	var ev: _EV = _EV.new()
	ev.type = _EV.Type.ENTER_ROOM
	ev.x = int(p.x * 100.0)
	ev.y = int(p.y * 100.0)
	ev.z = int(p.z * 100.0)
	return ev


# --- The mobile pause analogue: app backgrounding ------------------------

func _test_backgrounding(ctx: Variant) -> void:
	# Godot on Android auto-pauses the WHOLE main loop when the app
	# is backgrounded; game logic is delta-driven, so a backgrounded
	# interval must advance nothing. The rig proxy: PROCESS_MODE_
	# DISABLED on the scene root = every node in the subtree stops
	# (exactly what the engine does), then ~0.5 s of real time pass
	# with the engine still pumping frames (nothing in the subtree
	# processes them), then resume.
	var rm: Node = _main.run_manager
	# A live, playing run is the precondition (the clock only runs
	# in PLAYING).
	ctx.check(rm.state == _RM.State.PLAYING,
			"background: precondition — the run is PLAYING")
	var prev_mode: int = _main.process_mode
	_main.process_mode = Node.PROCESS_MODE_DISABLED
	var t0: int = rm.time_decis()
	await get_tree().create_timer(0.5).timeout
	var t1: int = rm.time_decis()
	_main.process_mode = prev_mode
	ctx.check(t1 == t0,
			"background: nothing advances while the subtree is "
			+ "backgrounded (the engine keeps pumping frames, the "
			+ "scene processes none)")
	_tick(30)
	var t2: int = rm.time_decis()
	# 30 ticks at 60 Hz = 0.5 s = 5 deciseconds — exactly, not
	# «approximately» (the clock is delta-driven, no drift allowed).
	ctx.check(t2 == t1 + 5,
			"background: after resume the clock advances by exactly "
			+ "the 30 ticks (no jump, no lost time)")
	var enemies: Array = _main.director.get_alive_enemies()
	ctx.check(enemies.size() > 0,
			"background: the enemies are coherent after the resume")
