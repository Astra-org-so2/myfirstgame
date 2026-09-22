# Integration: the Phase 6 progression cycle in the main scene.
#
# The ROADMAP-required scripted pickup (a weapon is FOUND, permanent,
# enters the loadout) + the NPC trust flow (talk -> help -> trust 1,
# the NPC-gated Inheritance enters the pool, the death REMOVES it
# forever) + the EMBER camp fire + the camp item (inventory -> tap ->
# heal). Same rig contract as the other scene tests: the player on the
# MovementPort mock, manual _physics_process ticks, Input.action_press
# for the held-edge actions (ADR-022).
extends Node

const _MAIN = preload("res://scripts/world/main_scene.gd")
const _PLAYER = preload("res://scripts/player/player_controller.gd")
const _PORT = preload("res://scripts/player/movement_port.gd")
const _NPC = preload("res://scripts/world/npc_node.gd")
const _PICKUP = preload("res://scripts/world/weapon_pickup.gd")
const _IA = preload("res://scripts/world/interactable.gd")
const _DREQ = preload("res://scripts/gameplay/combat/damage_request.gd")
const _CAMP_ITEM = preload("res://data/items/camp_fire.tres")

const DT: float = 1.0 / 60.0

var _main: _MAIN
var _player: _PLAYER
var _mock: _PORT
var _ticks: Array = []  # nodes to tick each frame (the scene's clocks)


func run(ctx: Variant) -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	ctx.check(packed != null, "progression: main scene loads")
	if packed == null:
		return
	var scene: Node = packed.instantiate()
	ctx.check(scene != null and scene is _MAIN,
			"progression: scene instantiates")
	if scene == null:
		return
	_main = scene
	var player_node: Node = scene.find_child("Player", true, false)
	_player = player_node
	if _player == null:
		ctx.check(false, "progression: player present")
		return
	_mock = _PORT.new(null,
			_player.data.gravity, _player.data.max_fall_speed)
	_player.set_port(_mock)  # before tree entry (mock seam)
	add_child(scene)
	_main.set_physics_process(false)  # the test owns the clock

	# --- Composition ---
	ctx.check(_main.progress != null, "progression: state composed")
	ctx.check(_main.loadout != null \
			and _main.loadout.has(&"weapon_blade"),
			"progression: the blade is adopted in the loadout")
	ctx.check(_main.inventory != null, "progression: inventory composed")
	ctx.check(_main.death_screen != null, "progression: death screen")
	ctx.check(_main.inventory_panel != null, "progression: bag panel")
	ctx.check(_main.toast != null, "progression: toast")
	ctx.check(_main.echo_step != null, "progression: echo step")
	for id in [&"mara", &"orren", &"nia", &"cartographer"]:
		var n: Node = scene.find_child("NPC_" + String(id), true, false)
		ctx.check(n != null, "progression: NPC_%s placed" % id)
	ctx.check(scene.find_child("CampFire", true, false) != null,
			"progression: the camp fire is an interactable")
	# Phase 7: the production weapons are NO LONGER at the camp — the
	# layout data carries them (fixed_loot: cannon -> Mine, staff ->
	# Shrine, WEAPON_DESIGN §5); _test_weapon_pickup enters the Mine.
	ctx.check(scene.find_child("WeaponPickup_cannon", true, false) == null
			and scene.find_child("WeaponPickup_staff", true, false) == null,
			"progression: no demo pickups at the camp (Phase 7)")
	_test_zone_transition(ctx)
	_test_weapon_pickup(ctx)
	_test_npc_trust_and_death(ctx)
	_test_campfire(ctx)
	_test_camp_item(ctx)


func _tick(n: int) -> void:
	for i in n:
		_player._physics_process(DT)
		for t in _ticks:
			if is_instance_valid(t):
				t._physics_process(DT)


func _interact_once() -> void:
	Input.action_press("interact")
	_tick(2)
	Input.action_release("interact")
	_tick(2)


func _damage_player(amount: float) -> void:
	var req: _DREQ = _DREQ.new()
	req.source = _player
	req.target = _player
	req.amount = amount
	req.type = _DREQ.Type.MELEE
	req.position = _mock.get_position()
	req.knockback_direction = Vector3(0.0, 0.0, 1.0)
	_main.resolver.resolve(req)


# Phase 7: the walk-through door trigger (the camp gate -> the zone,
# the camp_exit door -> back). The trigger logic is driven manually
# (the cooldown is a real-time guard against double switches).
func _test_zone_transition(ctx: Variant) -> void:
	var zw: Node = _main.zone_world
	if zw == null or _main.run_layout == null:
		ctx.check(false, "zones: the level layer is composed")
		return
	zw.enter(&"camp")
	ctx.check(zw.is_camp(), "zones: the session starts at the camp")
	# The mine gate door (the layout's camp room).
	var camp_ap = _main.run_layout.get_area(&"camp")
	var camp_rp = camp_ap.rooms[0]
	var gate = camp_rp.door(&"gate_the_mine")
	ctx.check(gate != null, "zones: the camp layout resolves the mine gate")
	if gate == null:
		return
	var camp_nodes: int = _main.director.nav_node_count()
	zw._cooldown = 0.0
	_mock.set_position(gate.local_pos)
	zw._physics_process(DT)
	ctx.check(zw.current == &"the_mine",
			"zones: crossing the mine gate enters the Mine")
	# The level nav was re-loaded: the director's graph is no longer
	# the camp's handcrafted ring (the Mine's chain has its own
	# nodes). Phase 8: the Mine's forward door to the Undercroft is
	# SEALED in RUN 1 (A16), so the radius alone no longer distinguishes
	# the levels — the node set does.
	ctx.check(_main.director.nav_node_count() != camp_nodes,
			"zones: the director re-loaded the level nav")
	# Back: the Mine's entry room, its camp_exit door.
	var mine_ap = _main.run_layout.get_area(&"the_mine")
	var mine_rp = mine_ap.rooms[0]
	var back = mine_rp.door(&"camp_exit")
	ctx.check(back != null, "zones: the Mine entry has the camp_exit door")
	if back == null:
		return
	zw._cooldown = 0.0
	_mock.set_position(mine_rp.origin + back.local_pos)
	zw._physics_process(DT)
	ctx.check(zw.is_camp(),
			"zones: the camp_exit door returns to the camp")

	# Phase 8 (A16): in RUN 1 the Undercroft edge is SEALED
	# (run_02_door_open is set on the first death). The door data says
	# so (is_sealed) — the RUN 02 leg is tested in run_cycle_test.
	zw._cooldown = 0.0
	_mock.set_position(gate.local_pos)
	zw._physics_process(DT)
	ctx.check(zw.current == &"the_mine", "zones: back in the Mine")
	var last_rp = mine_ap.rooms.back()
	# The forward edge is data (the Mine's single connection: door_b
	# -> undercroft). In RUN 1 the generator leaves it SEALED
	# (condition run_02_door_open unset) — sealed doors keep their
	# anchor but no destination, so the door is found by anchor.
	var conn: Node = null
	for c in mine_ap.area.connections:
		if c.to == &"undercroft":
			conn = c
	ctx.check(conn != null,
			"zones: the Mine's undercroft edge exists in the data")
	if conn == null:
		return
	var fwd = last_rp.door(conn.door)
	ctx.check(fwd != null and fwd.is_sealed(),
			"zones: the Mine's Undercroft door is sealed in RUN 1 (A16)")
	if fwd == null:
		return
	# Crossing the sealed door must NOT switch the level (walk-through
	# is skipped for sealed doors — the player stays in the Mine).
	zw._cooldown = 0.0
	_mock.set_position(last_rp.origin + fwd.local_pos)
	zw._physics_process(DT)
	ctx.check(zw.current == &"the_mine",
			"zones: the sealed door does not open (RUN 1)")
	# memory_stats: the one visited zone = 1/8 → int(12.5) = 12
	# (the Undercroft is sealed in RUN 1 — its leg is the run_cycle
	# test's RUN 02 assertion).
	ctx.check(_main.tracker.stats.explored_pct == 12,
			"zones: explored_pct = 12 after the Mine (RUN 1)")
	# And home to the camp (the test flow ends camp-side).
	_main._enter_level(&"camp")


func _fixed_loot_of(ap) -> StringName:
	for r in ap.rooms:
		var rp = r
		if rp.room.fixed_loot != &"":
			return rp.room.fixed_loot
	return &""


func _test_weapon_pickup(ctx: Variant) -> void:
	# The data first: the cannon is the Mine's fixed find (the staff
	# — the Shrine's).
	var mine_ap = _main.run_layout.get_area(&"the_mine")
	var shrine_ap = _main.run_layout.get_area(&"old_shrine")
	ctx.check(_fixed_loot_of(mine_ap) == &"weapon_cannon",
			"pickup: the Mine carries the HAND CANNON (data)")
	ctx.check(_fixed_loot_of(shrine_ap) == &"weapon_staff",
			"pickup: the Shrine carries the ECHO STAFF (data)")
	# Phase 8 (A14): RUN 1 the box carries the NOTE, not the weapon
	# ("the world gives the weapon after the first death"). The RUN 02
	# pickup itself is the run_cycle_test's assertion.
	_main._enter_level(&"the_mine")
	ctx.check(_main.find_child("WeaponPickup_cannon", true, false) == null,
			"pickup: the cannon is NOT offered in RUN 1 (A14)")
	var note: Node = _main.find_child("NoteStand_box_note_weapon_cannon",
			true, false)
	ctx.check(note != null,
			"pickup: the box carries E.'s note stand in RUN 1")
	if note == null:
		_main._enter_level(&"camp")
		return
	var ia: _IA = note.find_child("IA_note_box_note_weapon_cannon",
			true, false)
	_ticks = [ia]
	var p: Vector3 = note.global_position
	_mock.set_position(Vector3(p.x, 0.0, p.z + 0.8))
	_tick(3)
	ctx.check(ia.is_prompt_visible(), "pickup: the note prompt shows near")
	_interact_once()
	ctx.check(bool(_main.progress.ws.flag(&"mine_note_read")),
			"pickup: reading the box note sets mine_note_read")
	ctx.check(not _main.loadout.has(&"weapon_cannon"),
			"pickup: the loadout still has no cannon in RUN 1")
	# Back to camp (the rest of the flow is camp-side).
	_main._enter_level(&"camp")


func _test_npc_trust_and_death(ctx: Variant) -> void:
	var npc: _NPC = _main.find_child("NPC_mara", true, false)
	if npc == null:
		return
	var ia: _IA = npc.find_child("IA_mara", true, false)
	_ticks = [ia]
	var p: Vector3 = npc.global_position
	_mock.set_position(Vector3(p.x, 0.0, p.z + 0.8))
	_tick(3)

	# 2 talks (trust 1 needs the help too) + the scripted help = trust 1.
	ctx.check(npc.get_trust() == 0, "trust: mara starts at 0")
	_interact_once()
	_interact_once()
	ctx.check(npc.get_trust() == 0,
			"trust: 2 talks alone do not grant trust 1 (the help is in)")
	_interact_once()  # the help opens (interactions >= 2, not done yet)
	ctx.check(npc.get_trust() == 1, "trust: mara reached 1 after the help")

	# Trust 1 opens the pool: her gift (EMBER) is offerable now.
	var pool: Array = _main.progress.manager.get_pool(
			_main.progress.ws, _main.progress.stats,
			_main.progress.all_inheritances)
	var has_ember: bool = false
	for d in pool:
		if d.id == &"ember":
			has_ember = true
	ctx.check(has_ember, "trust: EMBER entered the pool at trust 1")

	# The PERMANENT price: the NPC is killable; killing her resets
	# trust and removes the gift from the pool FOREVER.
	var req: _DREQ = _DREQ.new()
	req.source = _player
	req.target = npc
	req.amount = 60.0
	req.type = _DREQ.Type.MELEE
	req.position = npc.global_position
	req.knockback_direction = Vector3(0.0, 0.0, -1.0)
	_main.resolver.resolve(req)
	ctx.check(npc.is_dead(), "death: mara died (50 hp)")
	var data: Resource = npc.get_data()
	ctx.check(bool(_main.progress.ws.get_flag(data.death_flag)),
			"death: the death flag is set (world state)")
	var e: Dictionary = _main.progress.ws.npc_entry(&"mara")
	ctx.check(_main.progress.trust.trust_level(e, data,
			_main.progress.stats) == 0,
			"death: trust reset to 0")
	pool = _main.progress.manager.get_pool(
			_main.progress.ws, _main.progress.stats,
			_main.progress.all_inheritances)
	has_ember = false
	for d in pool:
		if d.id == &"ember":
			has_ember = true
	ctx.check(not has_ember,
			"death: EMBER is out of the pool FOREVER")

	# The dead NPC still answers (the verdict line, not the dialogue).
	_ticks = [ia]
	_interact_once()
	ctx.check(true, "death: talking to a dead NPC does not crash")


func _test_campfire(ctx: Variant) -> void:
	var fire: _IA = _main.find_child("CampFire", true, false)
	if fire == null:
		return
	_ticks = [fire]
	var p: Vector3 = fire.global_position
	_mock.set_position(Vector3(p.x, 0.0, p.z + 0.8))
	_tick(3)

	# Without EMBER: the fire is a cold line, no heal.
	_damage_player(40.0)
	var hp_burned: float = _player.get_combat_target().hp
	_interact_once()
	ctx.check(_player.get_combat_target().hp == hp_burned,
			"campfire: without EMBER the fire is cold (no heal)")

	# With EMBER (granted directly — the death screen path is the
	# combat_scene test's): the camp becomes a healing ground.
	_main.progress.ws.add_inheritance(&"ember", 1)
	var w: Dictionary = _main.progress.effects.world(_main.progress.ws)
	ctx.check(bool(w["campfire_heal"]),
			"campfire: EMBER makes the fire heal (effects data)")
	_interact_once()
	ctx.check(_player.get_combat_target().hp
			== _player.get_combat_target().max_hp,
			"campfire: the fire heals to full")


func _test_camp_item(ctx: Variant) -> void:
	_damage_player(40.0)
	var hp_burned: float = _player.get_combat_target().hp
	ctx.check(hp_burned < _player.get_combat_target().max_hp,
			"camp_item: the player is hurt")
	var slot: int = _main.inventory.add(_CAMP_ITEM)
	ctx.check(slot >= 0, "camp_item: the bag took the small fire")
	_main.inventory_panel.toggle()
	ctx.check(_main.inventory_panel.is_open(), "camp_item: the bag opens")
	_main.inventory_panel.tap(slot)
	ctx.check(_player.get_combat_target().hp > hp_burned,
			"camp_item: tapping the slot heals (%.0f -> %.0f)"
			% [hp_burned, _player.get_combat_target().hp])
	ctx.check(_main.inventory.count(_CAMP_ITEM.id) == 0,
			"camp_item: the item was consumed")
