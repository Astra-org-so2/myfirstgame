# Main scene controller (Phase 3: the camp hub; Phase 4: combat wiring).
#
# Composes the camp (CampWorld builds from CampLayout data) with the
# player + touch layer, places the spawn point from data, wires the
# interactable stubs to the player, and (Phase 4) composes the combat
# services: DamageResolver (single damage point), HitStop (global
# micro-freeze clock), VfxPool, SfxBus, HurtVignette (ARCHITECTURE §3.2,
# ADR-023).
#
# HitStop clock: the player's own physics process is disabled here and
# driven with `hitstop.update(delta)` — movement + weapon freeze
# together on impact (the camera keeps running: shake during hitstop is
# intended feel). Tests own the clock manually (ADR-022 item 11).
# Cross-file references use preload-consts (ADR-022).
extends Node3D

const _PLAYER = preload("res://scripts/player/player_controller.gd")
const _TOUCH = preload("res://scripts/ui/touch_controls.gd")
const _CAMP = preload("res://scripts/world/camp_world.gd")
const _LAYOUT = preload("res://scripts/world/camp_layout.gd")
const _RESOLVER = preload("res://scripts/gameplay/combat/damage_resolver.gd")
const _HITSTOP = preload("res://scripts/gameplay/combat/hitstop.gd")
const _VFX = preload("res://scripts/gameplay/combat/vfx_pool.gd")
const _VIG = preload("res://scripts/gameplay/combat/hurt_vignette.gd")
const _SFX = preload("res://scripts/audio/sfx_bus.gd")
const _DREQ = preload("res://scripts/gameplay/combat/damage_request.gd")
const _BLADE = preload("res://data/weapons/blade.tres")
const _DIRECTOR = preload("res://scripts/gameplay/enemies/enemy_director.gd")
const _TRACKER = preload("res://scripts/gameplay/memory_stats_tracker.gd")
const _THR_DATA = preload("res://data/memory_stats_thresholds.tres")
const _NAV_DATA = preload("res://data/world/camp_nav.tres")
const _SPAWN_TABLE = preload("res://data/enemies/camp_spawn_table.tres")
# Phase 6 — Progression (code-built scene layer; ADR-024):
const _PROG_STATE = preload("res://scripts/gameplay/progression/progression_state.gd")
const _LOADOUT = preload("res://scripts/gameplay/combat/weapon_loadout.gd")
const _NPC_NODE = preload("res://scripts/world/npc_node.gd")
const _WEAPON_PICKUP = preload("res://scripts/world/weapon_pickup.gd")
const _CAMP_DROP = preload("res://scripts/world/camp_drop.gd")
const _TOAST = preload("res://scripts/ui/toast.gd")
const _DEATH_SCREEN = preload("res://scripts/ui/death_screen.gd")
const _INVENTORY_PANEL = preload("res://scripts/ui/inventory_panel.gd")
const _ECHO_STEP = preload("res://scripts/gameplay/progression/echo_step.gd")
const _INTERACTABLE = preload("res://scripts/world/interactable.gd")
const _INV_LOGIC = preload("res://scripts/gameplay/progression/inventory_logic.gd")
const _ITEM_DATA = preload("res://scripts/gameplay/progression/item_data.gd")
const _CAMP_ITEM = preload("res://data/items/camp_fire.tres")
const _CANNON_DATA = preload("res://data/weapons/hand_cannon.tres")
const _STAFF_DATA = preload("res://data/weapons/echo_staff.tres")
# Phase 7 — Procedural rooms (the DAG level layer, TECHNICAL_DESIGN §6):
const _ZONE_WORLD = preload("res://scripts/world/zone_world.gd")
const _AREA = preload("res://scripts/gameplay/areas/area_data.gd")
const _ROOM_GEN = preload("res://scripts/gameplay/rooms/run_generator.gd")
const _RUN_LAYOUT = preload("res://scripts/gameplay/rooms/run_layout.gd")
const _AP = preload("res://scripts/gameplay/rooms/area_placement.gd")
const _RP = preload("res://scripts/gameplay/rooms/room_placement.gd")
const _RD = preload("res://scripts/gameplay/rooms/resolved_door.gd")
const _TABLE = preload("res://scripts/gameplay/enemies/spawn_table.gd")
const _ENTRY = preload("res://scripts/gameplay/enemies/spawn_entry.gd")

const AREA_FILES := [
	"camp", "ruined_village", "watchtower", "the_mine", "old_shrine",
	"broken_bridge", "mysterious_lake", "ancient_gate", "undercroft",
]

var player: _PLAYER
var resolver: _RESOLVER
var hitstop: _HITSTOP
var vfx: _VFX
var sfx: _SFX
var vignette: _VIG
# Phase 5: the enemy system (director = budget/anchors/spawn rules;
# tracker = MemoryStats from real signals).
var director: _DIRECTOR
var tracker: _TRACKER
# Phase 6: progression (state + logic; the scene owns the composition).
var progress: _PROG_STATE
var loadout: _LOADOUT
var inventory: _INV_LOGIC
var toast: _TOAST
var death_screen: _DEATH_SCREEN
var inventory_panel: _INVENTORY_PANEL
var echo_step: _ECHO_STEP
var _npcs: Array = []
var _drops: Array = []
var _drop_rng: RandomNumberGenerator
var _fired_connected: Array = []
var _staff_connected: Array = []
var _inv_held: bool = false
# Phase 7: the level layer (generated layout + zone visuals + doors).
var zone_world: _ZONE_WORLD
var run_layout: _RUN_LAYOUT
var camp_layer: Node3D
var _zone_weapons: Dictionary = {}  # weapon id -> pickup node


func _ready() -> void:
	var camp: _CAMP = $CampWorld
	var t: Node = $TouchControls
	if camp == null or t == null:
		push_error("Main scene: CampWorld/TouchControls missing")
		return
	player = $Player
	var touch: _TOUCH = t

	# Touch layer -> player (joystick seam + camera zone). ARCHITECTURE §7:
	# player/ never depends on ui/ directly.
	player.set_touch_provider(touch.get_provider())
	touch.set_camera_rig(player.camera_rig)

	# Spawn from camp data (single source of truth: CampLayout).
	var layout: _LAYOUT = camp.layout
	if layout == null:
		push_error("Main scene: CampWorld has no CampLayout")
		return
	var spawn: Node = $SpawnPoint
	spawn.global_position = layout.spawn_pos
	# The player actually starts at the spawn (Phase 3 placed only the
	# marker; the player node sat at the scene origin).
	player.get_port().set_position(layout.spawn_pos)

	# Interactable stubs -> player (prompt + interact edge; content —
	# Phase 4/10/11).
	for ia in camp.interactables:
		ia.set_target(player)

	_setup_combat(layout)
	_setup_enemies()
	_setup_progression(layout, camp)
	_setup_zones()


func _setup_combat(layout: _LAYOUT) -> void:
	# Scene-composed services (NOT autoloads — ARCHITECTURE §6).
	resolver = _RESOLVER.new()
	resolver.name = "DamageResolver"
	add_child(resolver)
	hitstop = _HITSTOP.new()
	vfx = _VFX.new()
	vfx.name = "VfxPool"
	add_child(vfx)
	sfx = _SFX.new()
	sfx.name = "SfxBus"
	add_child(sfx)
	vignette = _VIG.new()
	vignette.name = "HurtVignette"
	add_child(vignette)

	resolver.register(player, player.get_combat_target())
	player.set_respawn_position(layout.spawn_pos)

	if player.weapon != null:
		player.weapon.bind(player, _BLADE, resolver)
		player.weapon.set_sfx(sfx)
		player.weapon.set_camera_rig(player.camera_rig)

	resolver.damage_applied.connect(_on_damage_applied)
	resolver.target_killed.connect(_on_target_killed)

	# The player runs on the hitstop-scaled clock (see class doc).
	player.set_physics_process(false)


func _setup_enemies() -> void:
	# MemoryStats: filled from real signals (kills/deaths/dodges/hits;
	# explored + the rest — their phases, Phase 7/8/10).
	tracker = _TRACKER.new()
	tracker.name = "MemoryStatsTracker"
	add_child(tracker)
	tracker.bind_player(player)
	# EnemyDirector: the staggered AI budget, spawn rules, anchors,
	# and the Watcher's run cap (TECHNICAL_DESIGN / ENEMY_DESIGN §7).
	director = _DIRECTOR.new()
	director.name = "EnemyDirector"
	add_child(director)
	director.setup(player, tracker.stats, _THR_DATA, resolver)
	# Aggression profile from the session stats (ENEMY_DESIGN §7).
	director.apply_aggression(
			tracker.stats.aggression_profile(_THR_DATA))
	tracker.sync_player_hits(player.weapon.hits_landed)
	# Phase 7: the level (nav + spawn table) is owned by _enter_level —
	# the camp is the first level, the zones are the rest.
	# Player noise wakes enemies within hear_range (dodge + hits).
	player.connect("dodge_started", _on_player_noise)


# Phase 6: progression composition (all code-built; ADR-024).
# Data: 4 NPCs, 2 weapon pickups (cannon/staff — demo camp positions,
# the production zones arrive with the biomes in Phase 7), the camp
# fire (EMBER), camp-item drops (1/10), the death screen, the
# inventory panel, toasts.
func _setup_progression(layout: _LAYOUT, camp: _CAMP) -> void:
	# Progression state (WorldState + the Phase 6 logic + the data).
	# Seed: the session is a single run (RunManager brings the run
	# seed in Phase 8) — a fixed session seed keeps the death-screen
	# fallback picks reproducible.
	progress = _PROG_STATE.new()
	progress.name = "Progression"
	add_child(progress)
	progress.setup(tracker.stats, 20260915)

	loadout = _LOADOUT.new()
	loadout.name = "WeaponLoadout"
	add_child(loadout)
	loadout.setup(player, resolver, sfx, progress.effects, progress.ws)
	player.loadout = loadout
	loadout.adopt(&"weapon_blade", player.weapon)
	loadout.weapon_changed.connect(_on_weapon_changed)

	inventory = _INV_LOGIC.new()

	toast = _TOAST.new()
	toast.name = "Toast"
	add_child(toast)

	death_screen = _DEATH_SCREEN.new()
	death_screen.name = "DeathScreen"
	add_child(death_screen)
	death_screen.choice_made.connect(_on_death_choice)

	inventory_panel = _INVENTORY_PANEL.new()
	inventory_panel.name = "InventoryPanel"
	add_child(inventory_panel)
	inventory_panel.setup(inventory)
	inventory_panel.slot_used.connect(_on_item_used)

	echo_step = _ECHO_STEP.new()
	echo_step.name = "EchoStep"
	add_child(echo_step)
	echo_step.setup(player, director, progress)

	_drop_rng = RandomNumberGenerator.new()
	_drop_rng.seed = 20260916

	# Phase 7: the camp-only nodes live in CampLayer (hidden with the
	# camp when a zone level is active).
	camp_layer = Node3D.new()
	camp_layer.name = "CampLayer"
	add_child(camp_layer)

	# NPCs (PROGRESSION_DESIGN §3): Mara stays at her camp spot; the
	# other three get camp positions (Phase 10 moves them to the
	# village/brothel/studio zones).
	var npc_positions: Dictionary = {
		"mara": layout.mara_pos,
		"orren": Vector3(2.4, 0.0, -2.4),
		"nia": Vector3(-1.6, 0.0, -2.8),
		"cartographer": Vector3(-3.6, 0.0, 0.6),
	}
	for d in progress.roster.all():
		var pos: Vector3 = npc_positions.get(d.npc_id, Vector3.ZERO)
		var npc: _NPC_NODE = _NPC_NODE.new()
		npc.name = "NPC_" + String(d.npc_id)
		camp_layer.add_child(npc)
		npc.global_position = pos
		# Mara keeps her Phase 3 look (the camp's anchor, reparented:
		# add_child does NOT move a node with a parent).
		var custom: Node = null
		if d.npc_id == &"mara":
			custom = camp.find_child("MaraAnchor", true, false)
			if custom != null:
				var old_parent: Node = custom.get_parent()
				if old_parent != null:
					old_parent.remove_child(custom)
		npc.setup(d, progress, resolver, player, custom)
		_npcs.append(npc)

	# Phase 7: the production weapon pickups are NO LONGER at the
	# camp — they sit in their zones (fixed_loot data, WEAPON_DESIGN
	# §5: cannon in the Mine, staff in the Shrine). _place_weapons
	# builds them on zone entry.

	# The camp fire (EMBER): the camp becomes a healing ground if the
	# Inheritance was chosen; otherwise it's a cold line.
	var campfire: _INTERACTABLE = _INTERACTABLE.new()
	campfire.name = "CampFire"
	campfire.prompt = "The camp fire (E)"
	campfire.interact_radius = 2.5
	camp_layer.add_child(campfire)
	campfire.global_position = layout.bonfire_pos
	campfire.set_target(player)
	campfire.interacted.connect(_on_campfire)

	# Event routing (signals — rig-safe, ADR-022):
	var bus: Node = get_node_or_null("/root/EventBus")
	if bus != null:
		bus.player_died.connect(_on_player_died)
		bus.player_spawned.connect(_on_player_spawned)
		bus.enemy_killed.connect(_on_enemy_killed)
		bus.npc_died.connect(_on_npc_died)
		bus.weapon_found.connect(_on_weapon_found)
	# Initial per-run state (a respawn re-applies it on the bus).
	_apply_per_run_effects()


# ---------------------------------------------------------------------------
# Phase 7 — the level layer (TECHNICAL_DESIGN §6).
#
# The run layout is generated ONCE per session (fixed session seed —
# RunManager brings the run seed in Phase 8, same API). The camp is
# level 1 (CampWorld visuals); a zone door crossing switches the
# level: the director re-loads the level's nav + spawn table, the
# zone visuals are built from the placement, the production weapon
# pickups appear in their rooms (fixed_loot).
# ---------------------------------------------------------------------------

const CAMP_FOG_DENSITY: float = 0.02  # main.tscn Environment value
const CAMP_FOG_COLOR: Color = Color(0.32, 0.34, 0.38)
const WEAPON_LINES: Dictionary = {
	&"weapon_cannon": "It's heavy. Use it once. — E.",
	&"weapon_staff": "It sees what you left. Use it gently. — E.",
}


func _setup_zones() -> void:
	var pool: Dictionary = {}
	for f in AREA_FILES:
		var res: Resource = load("res://data/areas/%s.tres" % f)
		if res == null:
			push_error("Main scene: area data missing: " + f)
			return
		pool[(res as _AREA).id] = res
	var gen: _ROOM_GEN = _ROOM_GEN.new()
	gen.set_pool(pool)
	run_layout = gen.generate(20260917, progress.ws.flags)
	zone_world = _ZONE_WORLD.new()
	zone_world.name = "ZoneWorld"
	add_child(zone_world)
	zone_world.setup(run_layout)
	zone_world.set_player(player)
	zone_world.door_crossed.connect(_on_door_crossed)
	_enter_level(&"camp")


# Switch the gameplay level: visuals + nav + spawns + fog + weapons.
func _enter_level(area_id: StringName) -> void:
	if zone_world == null:
		return
	if tracker != null:
		tracker.explore_zone(area_id)
	var is_camp: bool = area_id == &"camp"
	$CampWorld.visible = is_camp
	if camp_layer != null:
		camp_layer.visible = is_camp
	director.clear()
	zone_world.enter(area_id)
	if is_camp:
		director.load_nav(_NAV_DATA)
		director.start(_SPAWN_TABLE)
	else:
		if zone_world.nav != null:
			director.load_nav(zone_world.nav)
		var table: _TABLE = _TABLE.new()
		table.entries = _table_for_area(area_id)
		director.start(table)
	_place_weapons(area_id)
	_set_fog(area_id)


# The layout spawns of one area (copies from the generator).
func _table_for_area(area_id: StringName) -> Array:
	var out: Array = []
	for e in run_layout.spawns:
		var entry: _ENTRY = e
		if entry.area == area_id:
			out.append(entry)
	return out


# Walk-through door crossing (ZoneWorld): a door to ANOTHER area
# switches the level and drops the player at the destination door;
# same-area doors are just walking (the whole area is built at once).
# Two target forms: an AREA entry (zone gates, the boss's forward
# doors) and a cross-area ROOM (the boss arena's entry doors point
# back at the source's last room).
func _on_door_crossed(area_id: StringName, room_id: StringName,
		anchor: StringName) -> void:
	var rp: _RP = run_layout.find_room(area_id, room_id)
	if rp == null:
		return
	var rd: _RD = rp.door(anchor)
	if rd == null:
		return
	var target: StringName
	var t_rp: _RP
	var td: _RD
	if rd.to_room != &"":
		target = rd.to_room_area if rd.to_room_area != &"" else area_id
		var t_area: _AP = run_layout.get_area(target)
		if t_area == null:
			push_error("Main scene: door target area missing: "
					+ String(target))
			return
		t_rp = t_area.find(rd.to_room)
		if t_rp == null:
			push_error("Main scene: door target room missing: "
					+ String(rd.to_room))
			return
		td = t_rp.door(rd.to_anchor)
	else:
		target = rd.to_area
		var t_area2: _AP = run_layout.get_area(target)
		if t_area2 == null:
			push_error("Main scene: door target area missing: "
					+ String(target))
			return
		t_rp = t_area2.rooms[0]
		td = t_rp.door(rd.to_anchor)
	if target == area_id:
		return  # walking within this level (no switch)
	if td == null:
		push_error("Main scene: door target anchor missing: "
				+ String(rd.to_anchor))
		return
	_enter_level(target)
	player.get_port().set_position(t_rp.origin + td.local_pos)


# Production weapon pickups (fixed_loot data, WEAPON_DESIGN §5): the
# cannon in the Mine, the staff in the Shrine — permanent per
# world-state (a found weapon does not reappear).
func _place_weapons(area_id: StringName) -> void:
	for id in _zone_weapons:
		var n: Node = _zone_weapons[id]
		if n != null and is_instance_valid(n) \
				and n.get_parent() == null:
			_zone_weapons.erase(id)
	var a: _AP = run_layout.get_area(area_id)
	if a == null:
		return
	for r in a.rooms:
		var rp: _RP = r
		var wid: StringName = rp.room.fixed_loot
		if wid == &"" or rp.room.loot_spots.size() < 1:
			continue
		if progress.ws.is_weapon_found(wid):
			continue
		var data: Resource
		var line: String
		if wid == &"weapon_cannon":
			data = _CANNON_DATA
			line = WEAPON_LINES[wid]
		elif wid == &"weapon_staff":
			data = _STAFF_DATA
			line = WEAPON_LINES[wid]
		else:
			push_error("Main scene: unknown fixed_loot weapon: "
					+ String(wid))
			continue
		var short: String = String(wid).replace("weapon_", "")
		var pickup: _WEAPON_PICKUP = _WEAPON_PICKUP.new()
		pickup.name = "WeaponPickup_" + short
		zone_world.level.add_child(pickup)
		pickup.position = rp.origin + rp.room.loot_spots[0]
		pickup.setup(data, progress, loadout, player, line)
		_zone_weapons[wid] = pickup


# Per-area fog (the area's data drives the shared environment).
func _set_fog(area_id: StringName) -> void:
	var we: WorldEnvironment = $WorldEnvironment
	var e: Environment = we.environment
	if area_id == &"camp":
		e.fog_density = CAMP_FOG_DENSITY
		e.fog_light_color = CAMP_FOG_COLOR
		return
	var a: _AP = run_layout.get_area(area_id)
	if a == null:
		return
	e.fog_density = 0.01 + a.area.fog_density * 0.025
	e.fog_light_color = a.area.light_color


func _on_weapon_found(_id: StringName, _pos: Vector3) -> void:
	# A found thing "plinks" (procedural cue, prototype status).
	if sfx != null:
		sfx.play(&"pickup")


# SECOND CHANCE (per run): lethal hits are caught this many times.
func _apply_per_run_effects() -> void:
	if player == null or progress == null:
		return
	var p: Dictionary = progress.effects.player(progress.ws)
	player.combat.guard_charges = int(p["auto_dodge_charges"])
	echo_step.reset_run()


func _on_player_spawned(_pos: Vector3) -> void:
	_apply_per_run_effects()
	# A respawn is back at the camp (Phase 7): re-enter the camp
	# level if the death happened in a zone.
	if zone_world != null and not zone_world.is_camp():
		_enter_level(&"camp")


func _on_player_died(_pos: Vector3) -> void:
	var offers: Array = progress.roll_death_offers()
	if offers.is_empty():
		# The pool is never empty by data (12 basic), but the scene
		# must not die on a data bug: respawn without the screen.
		player.death_choice_pending = false
		player.request_respawn()
		return
	var levels: Array = []
	for d in offers:
		levels.append(progress.ws.inheritance_level(d.id) + 1)
	player.death_choice_pending = true
	death_screen.show_offers(offers, levels,
			tracker.stats.deaths * 7919 + 13)


func _on_death_choice(data: Resource) -> void:
	progress.resolve_death_choice(data)
	player.death_choice_pending = false
	toast.show_text("The world keeps what you choose.")
	player.request_respawn()


func _on_npc_died(npc_id: StringName, _pos: Vector3) -> void:
	# The verdict line is on the NPC's own label (3 s); the roster
	# toast keeps the loss visible if the player walks away.
	toast.show_text("The world forgot " + String(npc_id) + ".")


func _on_campfire(_ia: Node) -> void:
	var w: Dictionary = progress.effects.world(progress.ws)
	if w["campfire_heal"]:
		player.heal(player.data.health_max)
		toast.show_text("The fire heals.")
	else:
		toast.show_text("The fire is cold.")


func _on_item_used(_index: int, item: _ITEM_DATA) -> void:
	var healed: float = player.heal(float(item.heal_amount))
	if healed > 0.0:
		toast.show_text("You light the small fire.")
	else:
		toast.show_text("There is nothing to heal.")


# Camp item drop (PROGRESSION_DESIGN §4: 3 per run, 1/10 chance).
func _on_enemy_killed(_enemy_id: StringName, pos: Vector3) -> void:
	if inventory.count(_CAMP_ITEM.id) >= int(_CAMP_ITEM.max_per_run):
		return
	if _drop_rng.randf() >= 0.1:
		return
	var drop: _CAMP_DROP = _CAMP_DROP.new()
	drop.name = "CampDrop"
	(camp_layer if camp_layer != null else self).add_child(drop)
	drop.global_position = Vector3(pos.x, 0.0, pos.z)
	drop.setup(_CAMP_ITEM, self)
	drop.interacted.connect(func(_ia: Node) -> void:
		if inventory.add(_CAMP_ITEM):
			toast.show_text("You take the small fire.")
			if sfx != null:
				sfx.play(&"pickup")
		else:
			toast.show_text("No room in the bag."))
	_drops.append(drop)


# The equipped weapon changed (pickup or the switch key): route its
# signals (cannon noise wakes enemies; the staff's effects show).
func _on_weapon_changed(_id: StringName) -> void:
	var c: Node = loadout.current()
	if c == null:
		return
	if _fired_connected.has(c) or not c.has_method("get_data"):
		return
	var data: Resource = c.get_data()
	if data == null:
		return
	if data.type == 1:  # RANGED (WeaponData.Type): loud shots are noise.
		_fired_connected.append(c)
		c.fired.connect(_on_cannon_fired)
	elif data.type == 2 and not _staff_connected.has(c):  # STAFF
		_staff_connected.append(c)
		c.marked.connect(_on_staff_marked)
		c.disrupted.connect(_on_staff_disrupted)


func _on_cannon_fired(_origin: Vector3, loud: bool) -> void:
	if loud and director != null:
		director.mark_player_noise()


func _on_staff_marked(positions: PackedVector3Array) -> void:
	for p in positions:
		_spawn_dust(p)


func _on_staff_disrupted(count: int) -> void:
	if count > 0:
		toast.show_text("The echo shatters.")


# A small ground dust (code mesh; ADR-024): the staff's shatter and
# the ECHO STEP afterimage land something to look at.
func _spawn_dust(pos: Vector3) -> void:
	var dust: Node3D = Node3D.new()
	dust.name = "Dust"
	var mi: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = 0.7
	cm.bottom_radius = 0.5
	cm.height = 0.08
	mi.mesh = cm
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.7, 0.5, 0.5)
	mi.material_override = mat
	dust.add_child(mi)
	dust.position = Vector3(pos.x, 0.05, pos.z)
	add_child(dust)
	get_tree().create_timer(0.6).timeout.connect(func() -> void:
		if is_instance_valid(dust):
			dust.queue_free())


# Hitstop clock: one place where gameplay time is scaled (ADR-023).
# The enemies run on the SAME scaled clock — hitstop is a global
# micro-freeze (the camera keeps running, as in Phase 4).
func _physics_process(delta: float) -> void:
	if player == null or hitstop == null:
		return
	var d: float = hitstop.update(delta)
	player._physics_process(d)
	if director != null:
		director.update(d)
		director.record_player_position(player.get_body_position())
		tracker.sync_player_hits(player.weapon.hits_landed)
	# Phase 6: the inventory panel toggles on the `inventory` action
	# (I key / BAG touch button) — a hold-edge, like the dodge.
	var inv: bool = Input.is_action_pressed("inventory")
	if inv and not _inv_held:
		inventory_panel.toggle()
	_inv_held = inv


func _on_player_noise() -> void:
	if director != null:
		director.mark_player_noise()


# --- Combat feel routing (single wiring point) ---

func _on_damage_applied(res: Variant) -> void:
	# Offensive (player swung): hitstop + hit VFX/SFX + camera shake.
	if res.source == player:
		# A landed swing is NOISE — enemies within hear_range wake
		# (ENEMY_DESIGN §0.3).
		if director != null:
			director.mark_player_noise()
		var weapon: Resource = res.weapon
		if weapon != null:
			var freeze: float = weapon.hitstop_hit
			if res.killed:
				freeze = weapon.hitstop_kill
			hitstop.freeze(freeze)
		if res.flags & _DREQ.FLAG_RIPOSTE:
			vfx.spawn(res.position, _VFX.KIND_RIPOSTE)
			sfx.play(&"riposte")
		else:
			vfx.spawn(res.position, _VFX.KIND_HIT)
			sfx.play(&"hit")
		player.camera_rig.add_shake(
				0.12 if res.killed else 0.08)
	# Defensive (player hit): hitstop + vignette + hurt SFX + shake.
	if res.target == player and not res.blocked:
		hitstop.freeze(0.05)
		vignette.flash(0.9 if res.killed else 0.5)
		sfx.play(&"hurt")
		player.camera_rig.add_shake(0.15)


func _on_target_killed(_victim: Node) -> void:
	# Longer micro-freeze on kills (offensive juice; the death flow —
	# RunManager, Phase 8).
	if resolver == null:
		return
	# A kill by the player is an offensive hit: res.killed already froze
	# with the weapon's hitstop_kill. Kills of OTHER targets (dummy in
	# tests, enemies Phase 5) get the same feel here.
	hitstop.freeze(0.1)
