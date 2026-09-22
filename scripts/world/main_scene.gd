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
# Phase 8 — the run system (TECHNICAL_DESIGN §2/§3, FIRST_30_MINUTES):
const _RUN_MGR = preload("res://scripts/gameplay/run/run_manager.gd")
const _EV = preload("res://scripts/gameplay/run/run_event.gd")
const _FIRST_RUN = preload("res://scripts/world/first_run_director.gd")
const _VAL = preload("res://scripts/gameplay/rooms/layout_validator.gd")
const _FLAG_TABLE = preload("res://scripts/gameplay/progression/world_flag_table.gd")
const _FLAG_TABLE_DATA = preload("res://data/world_flags.tres")
# Phase 9 — Ghost/Echo (TECHNICAL_DESIGN §5, ADR-014):
const _GHOST_DIR = preload("res://scripts/world/ghost_director.gd")
const _ECHO_BUDGET = preload(
		"res://scripts/gameplay/echo/echo_budget_data.gd")
const _PASSIVE_ECHO = preload(
		"res://scripts/gameplay/echo/passive_echo_data.gd")
const _ECHO_BUDGET_DATA = preload("res://data/echo/echo_budget.tres")
const _PASSIVE_ECHO_DATA = preload("res://data/echo/passive_echo.tres")
# Phase 10 — the persistent world (WORLD_STATE_DESIGN, TECH §4):
const _WORLD_DIR = preload("res://scripts/world/world_director.gd")
const _NOTE_PANEL = preload("res://scripts/ui/note_panel.gd")
const _NOTE_STAND = preload("res://scripts/world/note_stand.gd")
const _NOTE_LINES_DATA = preload("res://data/note_lines.tres")
const _STANDS_DATA = preload("res://data/player_note_stands.tres")
const _TRANSFORM_DATA = preload(
		"res://data/world_transform_post_boss.tres")
# Phase 11 — the mystery system (MYSTERY_REVEAL_MAP):
const _MYSTERY_DIR = preload("res://scripts/gameplay/mystery/mystery_director.gd")
const _MYSTERY_STAGES_DATA = preload(
		"res://data/mystery/mystery_stages.tres")
const _MYSTERY_LINES_DATA = preload(
		"res://data/dialogue/npc_mystery_lines.tres")
const _CHILD = preload("res://scripts/world/world_child.gd")
const _CHILD_SPAWNS_DATA = preload("res://data/mystery/child_spawns.tres")
# Phase 12 — THE FIRST (the Undercroft boss, BOSS_DESIGN):
const _BOSS_CTRL = preload("res://scripts/gameplay/boss/boss_controller.gd")
const _BOSS_GATE = preload("res://scripts/gameplay/boss/boss_gate.gd")
const _BOSS_DATA = preload("res://data/boss_the_first.tres")
const _BLADE_DATA = preload("res://data/weapons/first_blade.tres")
# Phase 13 — the quality tiers (TECHNICAL_DESIGN §12, mobile-first):
const _QUALITY_MGR = preload("res://scripts/world/quality_manager.gd")
const _QUALITY_PRESET = preload("res://scripts/world/quality_preset.gd")
const _QUALITY_LOW = preload("res://data/quality/low.tres")
const _QUALITY_MEDIUM = preload("res://data/quality/medium.tres")
const _QUALITY_HIGH = preload("res://data/quality/high.tres")
const _QUALITY_ULTRA = preload("res://data/quality/ultra.tres")
# Phase 14 — the final audio (GDD §7): the buses/music/ambient/
# stinger manager + the settings panel.
const _AUDIO_MGR = preload("res://scripts/audio/audio_manager.gd")
const _SETTINGS = preload("res://scripts/ui/settings_panel.gd")
# Phase 15 — save/load/recovery (TECHNICAL_DESIGN §3).
const _SAVE_MGR = preload("res://scripts/gameplay/save/save_manager.gd")
# Phase 16 — the §7 measurements (debug builds only): the F1 HUD
# and the benchmark file writer.
const _DEBUG_OVERLAY = preload("res://scripts/ui/debug_overlay.gd")
const _PERF_BENCH = preload("res://scripts/dev/perf_benchmark.gd")
const _PALETTE = preload("res://data/visual/palette.tres")
const _TEX_BANK = preload("res://scripts/world/texture_bank.gd")

# The session seed (RUN 1's layout is the canonical one the A-beats
# were designed against; run N>1 = derived — RunManager.derive_seed).
const SESSION_SEED: int = 20260917
# A1: the 2 s black fade at the start (FIRST_30_MINUTES).
const A1_FADE_SECONDS: float = 2.0
# The "what changed" overlay window (WORLD_STATE_DESIGN §9.2: 3 s).
const CHANGED_WINDOW_SECONDS: float = 3.0

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
# Phase 10: the stand the NotePanel writes to ("" = panel closed).
var _pending_stand: StringName = &""
# Phase 7: the level layer (generated layout + zone visuals + doors).
var zone_world: _ZONE_WORLD
var run_layout: _RUN_LAYOUT
var camp_layer: Node3D
var _zone_weapons: Dictionary = {}  # weapon id -> pickup node
# Phase 8: the run system (run lifecycle + the scripted A-beats).
var run_manager: _RUN_MGR
var first_run: _FIRST_RUN
var ghost_director: _GHOST_DIR
var world_director: _WORLD_DIR
var note_panel: _NOTE_PANEL
var mystery: _MYSTERY_DIR
var quality: _QUALITY_MGR = null
var debug_overlay: _DEBUG_OVERLAY = null
var perf_bench: _PERF_BENCH = null
var _f1_prev: bool = false
var _f6_prev: bool = false
# Phase 14: the audio (the buses + the music/ambient voices) and
# the settings panel (F9, debug builds).
var audio: _AUDIO_MGR = null
var settings_panel: _SETTINGS = null
# Phase 15: the save system (the load must land BEFORE the run
# system reads the world: run 1 vs run N).
var save_manager: _SAVE_MGR = null
var _saved_settings: Dictionary = {}
var _first_camp_done: bool = false
var _isolated_save: bool = false
# Test seam (set BEFORE add_child): the save path the scene must
# use (the death->save->reload test shares one file between two
# scene instances; the auto-isolation below then stays off).
var save_path_override: String = ""
var _f9_prev: bool = false
var _boss_in_fight: bool = false
var textures: _TEX_BANK = null
var palette: Variant = _PALETTE
var _f8_prev: bool = false
var boss_gate: _BOSS_GATE = _BOSS_GATE.new()
var boss: _BOSS_CTRL = null
var _mine_deep_timer: float = 0.0
var _current_area: StringName = &"camp"
var _child: Node = null
var run_generator: _ROOM_GEN
var _area_pool: Dictionary = {}
var _last_player_attacker: Node = null
# Phase 8 (A11): Nia's home is the village (CHARACTER_BIBLE §4) — she
# rides in the village level; the holding keeps her (state included)
# while other levels are up.
var _village_npc: Node = null
var _npc_holding: Node3D = null
var _a1_left: float = 0.0
var _a1_rect: ColorRect = null
var _changed_layer: CanvasLayer = null
var _changed_label: Label = null
var _changed_left: float = 0.0


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
	# Phase 14: the audio manager first (its SFX bus must exist when
	# the pool's _ready routes the players).
	audio = _AUDIO_MGR.new()
	audio.name = "AudioManager"
	add_child(audio)
	sfx = _SFX.new()
	sfx.name = "SfxBus"
	add_child(sfx)
	settings_panel = _SETTINGS.new()
	settings_panel.name = "SettingsPanel"
	add_child(settings_panel)
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
	# Phase 15: the recovery matrix (TECHNICAL_DESIGN §3). The
	# restored world must be in place BEFORE run_manager.init_session
	# (the run count is a world fact).
	save_manager = _SAVE_MGR.new()
	save_manager.name = "SaveManager"
	# Test seam: under the harness the main scene is a CHILD of
	# the runner (current_scene != self) — every integration scene
	# gets an ISOLATED save (a fresh game, no bleed between the
	# suites). A test that needs a specific path sets it before
	# add_child (the scene then leaves it alone). In the game
	# main.tscn IS the current scene: the real user://save.
	if save_path_override != "":
		save_manager.path = save_path_override
	elif get_tree().current_scene != self:
		save_manager.path = "user://save_test/headless_%d.json" \
				% Time.get_ticks_msec()
		_isolated_save = true
	add_child(save_manager)
	save_manager.register_migrations()
	var ld: Dictionary = save_manager.load()
	var status: String = str(ld.status)
	_saved_settings = ld.settings
	var world_d: Dictionary = ld.world
	if not world_d.is_empty():
		progress.ws.load_dict(world_d)
	# The player should hear about a recovery, never about the
	# silent first boot.
	if status == "recovered_bak":
		toast.show_text("The world remembers. (save restored)", 3.5)
	elif status == "fresh" and save_manager != null:
		toast.show_text("The world started over. (save was lost)", 3.5)
	elif status == "newer":
		toast.show_text("A newer save was kept. (new world)", 3.5)

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
	# Phase 13: the texture set (ASSET_GUIDE §7) — composed BEFORE
	# the cast is built (the NPCs/child/boss need the bank at setup).
	textures = _TEX_BANK.new()
	textures.name = "TextureBank"
	add_child(textures)
	textures.load_all()
	director.textures = textures
	var _vis: Node = player.get_node_or_null("Visual")
	if _vis != null and _vis.has_method("set_textures"):
		_vis.set_textures(textures)
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
		npc.textures = textures
		if d.npc_id == &"nia":
			# A11: Nia is in the village, not the camp (the first-30-
			# minutes script meets her there). She joins the village
			# level on entry; the holding keeps her meanwhile.
			_npc_holding = Node3D.new()
			_npc_holding.name = "NpcHolding"
			_npc_holding.visible = false
			add_child(_npc_holding)
			_npc_holding.add_child(npc)
			_village_npc = npc
		else:
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
	_area_pool.clear()
	for f in AREA_FILES:
		var res: Resource = load("res://data/areas/%s.tres" % f)
		if res == null:
			push_error("Main scene: area data missing: " + f)
			return
		_area_pool[(res as _AREA).id] = res
	run_generator = _ROOM_GEN.new()
	run_generator.set_pool(_area_pool)
	# Phase 8: the run system owns the layout seed (run 1 = the session
	# seed, run N>1 = derived — the layout changes on every run).
	run_manager = _RUN_MGR.new()
	run_manager.name = "RunManager"
	add_child(run_manager)
	var table: _FLAG_TABLE = _FLAG_TABLE_DATA
	run_manager.flag_lines = table.lines()
	run_manager.init_session(SESSION_SEED, progress.ws)
	run_manager.changed_lines_ready.connect(_on_changed_lines)
	run_layout = run_generator.generate(run_manager.run_seed,
			progress.ws.flags)
	_check_layout(run_layout, "session start")
	zone_world = _ZONE_WORLD.new()
	zone_world.name = "ZoneWorld"
	add_child(zone_world)
	zone_world.setup(run_layout)
	zone_world.set_player(player)
	zone_world.door_crossed.connect(_on_door_crossed)
	zone_world.level_freed.connect(_on_level_freed)
	# Phase 13: the quality tier (medium = the mid-range base,
	# §12; the reference device is a Snapdragon 7-class Android).
	quality = _QUALITY_MGR.new()
	quality.name = "QualityManager"
	add_child(quality)
	quality.setup(_QUALITY_MEDIUM, $WorldEnvironment.environment,
			$Sun, get_viewport())
	zone_world.set_light_budget(quality.light_budget())
	# Phase 15: the saved settings (quality + audio) land now —
	# both systems exist.
	_apply_saved_settings()
	# Phase 16: the measurement tools (debug builds only — F1 HUD,
	# F6 benchmark file). They observe the scene, never change it.
	debug_overlay = _DEBUG_OVERLAY.new()
	debug_overlay.name = "DebugOverlay"
	add_child(debug_overlay)
	debug_overlay.setup(self)
	perf_bench = _PERF_BENCH.new()
	perf_bench.name = "PerfBenchmark"
	add_child(perf_bench)
	perf_bench.finished.connect(_on_perf_bench_finished)
	# Phase 13: the world surfaces (the cast got the bank earlier).
	zone_world.textures = textures
	$CampWorld.set_textures(textures)
	# The scripted first-30-minutes beats (event-driven, A1–A19).
	# Phase 11: the reveal gate (the mystery stages, 1 stage/run).
	# BEFORE first_run: the beats pass the director to the setup.
	mystery = _MYSTERY_DIR.new()
	mystery.setup(_MYSTERY_STAGES_DATA)
	mystery.reset_run()

	first_run = _FIRST_RUN.new()
	first_run.name = "FirstRunDirector"
	add_child(first_run)
	first_run.setup(self, zone_world, player, progress.ws, run_manager,
			mystery)
	var bus2: Node = get_node_or_null("/root/EventBus")
	run_manager.bind(bus2, player, resolver)
	for n in _npcs:
		if is_instance_valid(n) and n.has_signal("talked"):
			n.talked.connect(run_manager.record_npc_talked)
	# Phase 11: the mystery-line layer (data/dialogue) + the run id.
	for n in _npcs:
		if is_instance_valid(n) and n.has_method("set_mystery_wiring"):
			n.set_mystery_wiring(_MYSTERY_LINES_DATA, run_manager.run_id)
			if n.has_signal("mystery_line_spoken"):
				n.mystery_line_spoken.connect(_on_mystery_line_spoken)
	# Phase 9: the echo system (ADR-014 budget). The EnemyDirector
	# queries the per-run combat budget and the world-state flags
	# (the remnant gate: no echoes before the first death).
	ghost_director = _GHOST_DIR.new()
	ghost_director.name = "GhostDirector"
	add_child(ghost_director)
	ghost_director.setup(_ECHO_BUDGET_DATA, _PASSIVE_ECHO_DATA, player)
	director.set_budget(ghost_director.budget_state)
	director.set_world_state(progress.ws)
	ghost_director.prepare_run(run_manager.run_id, progress.ws,
			null, null, run_layout)
	# Phase 10: the persistent world (stands, mummy, K7 visuals).
	world_director = _WORLD_DIR.new()
	world_director.name = "WorldDirector"
	add_child(world_director)
	world_director.setup(progress.ws, _NOTE_LINES_DATA, _STANDS_DATA,
			_TRANSFORM_DATA, $CampWorld, player)
	world_director.prepare_run(run_manager.run_id, null, null,
			run_layout)
	note_panel = _NOTE_PANEL.new()
	note_panel.name = "NotePanel"
	add_child(note_panel)
	note_panel.written.connect(_on_note_written)
	first_run.on_run_started(run_manager.run_id)
	_enter_level(&"camp")
	# A1: the 2 s black fade, no menu (FIRST_30_MINUTES).
	_a1_left = A1_FADE_SECONDS
	_build_a1_fade()


# Layout integrity (the P7 validator): a broken layout must not reach
# the player (no-fake rule — the session falls back to a re-validated
# layout on the same seed).
func _check_layout(layout_res: _RUN_LAYOUT, where: String) -> void:
	var problems: Array = _VAL.validate(layout_res, progress.ws.flags,
			_area_pool)
	if not problems.is_empty():
		push_error("Main scene: layout invalid at %s: %s"
				% [where, str(problems)])


# Switch the gameplay level: visuals + nav + spawns + fog + weapons.
func _enter_level(area_id: StringName) -> void:
	if zone_world == null:
		return
	_current_area = area_id
	if tracker != null:
		tracker.explore_zone(area_id)
	var is_camp: bool = area_id == &"camp"
	$CampWorld.visible = is_camp
	if camp_layer != null:
		camp_layer.visible = is_camp
	director.clear()
	zone_world.enter(area_id)
	# AFTER enter(): the scripted props (figure, notes, the pyre) are
	# placed in the level that now exists — before it, they landed in
	# the level being freed and died with it.
	if first_run != null:
		first_run.on_level_entered(area_id)
	if ghost_director != null:
		ghost_director.on_level_entered(area_id, zone_world.level)
	if world_director != null:
		world_director.on_level_entered(area_id, zone_world.level)
		_wire_world_objects()
	# P12: the mine's first traces (RUN 05+, the deep level) — the
	# level rebuilds per entry, so the world prop is re-placed on
	# every entry from RUN 05 (the flag lands when the player
	# actually reaches the deep rooms — _check_mine_deep).
	if area_id == &"the_mine" and first_run != null \
			and run_manager.run_id >= 5:
		_place_first_traces()
	# P12: the Undercroft (pre-boss notes + the FIRST BLADE + the boss).
	if area_id == &"undercroft":
		_set_up_undercroft()
	# Phase 11 (M1 stage 2): the Passive Echo walks the player's path
	# (the reveal lands when the ghost is actually in this level).
	if ghost_director != null and ghost_director.has_active_ghost():
		mystery.reveal(&"m1_passive", progress.ws, run_manager.run_id)
		# Phase 14: the Echo walks with you (its voice + the variation).
		sfx.play(&"echo")
	_place_child(area_id)
	# Phase 14: the audio follows the world (the zone bed + music).
	_update_audio()
	# Phase 15: the safe hub is the auto-save point (the session
	# start is not — nothing to save yet).
	if area_id == &"camp":
		if _first_camp_done:
			_do_save("hub")
		_first_camp_done = true
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
	_place_village_npc(area_id)


# Phase 11: a mystery line was spoken — the stage reveal (M4.3:
# the Cartographer's city line sets the Veyra B stage).
func _on_mystery_line_spoken(line_id: StringName) -> void:
	if line_id == &"carto_city":
		mystery.reveal(&"m4_city", progress.ws, run_manager.run_id)


# Phase 11: the Child (scripted appearances, the run window is data).
func _place_child(area_id: StringName) -> void:
	_free_child()
	var sp: Variant = _CHILD_SPAWNS_DATA.for_run(run_manager.run_id,
			progress.ws, progress.stats)
	if sp == null or sp.zone != area_id:
		return
	var child: _CHILD = _CHILD.new()
	child.name = "TheChild"
	child.encounter_lines = sp.lines
	child.textures = textures
	child.setup(player)
	# The data position is an offset from the zone's entry room origin
	# (level-local, like the village NPCs).
	var a: Variant = run_layout.get_area(sp.zone)
	var off: Vector3 = sp.pos
	if a != null and a.rooms.size() > 0:
		var rp: Variant = a.rooms[0]
		off = Vector3(rp.origin.x + sp.pos.x, 0.0, rp.origin.z + sp.pos.z)
	child.position = off
	child.spoke.connect(_on_child_spoke)
	child.hit_attempted.connect(_on_child_hit)
	zone_world.level.add_child(child)
	_child = child


func _on_child_spoke(line_index: int) -> void:
	# M4 stage 2 (M4.2): the child counts the player.
	if line_index == 0:
		mystery.reveal(&"m4_child", progress.ws, run_manager.run_id)


func _on_child_hit() -> void:
	# The soft penalty (CHARACTER_BIBLE 5): the world «takes» the
	# child — no more appearances (the spawn table's skip_flag).
	progress.stats.child_hit += 1
	progress.ws.set_flag(&"child_hit")
	toast.show_text("The child is gone.", 2.5)


func _free_child() -> void:
	if is_instance_valid(_child):
		_child.queue_free()
	_child = null


# Phase 11: the Archivist whisper #5 (a killed NPC).
func _on_npc_died_whisper(_npc_id: StringName, _pos: Vector3) -> void:
	toast.show_text("Remembered. Kept. Always.", 4.0)


# Phase 10: the level's persistent objects get their behavior
# (the WorldDirector builds them; the scene owns the WorldState
# writes + the NotePanel — the director stays a builder).
func _wire_world_objects() -> void:
	var st: Node = world_director.current_stand()
	if st != null and st.has_signal("write_requested"):
		st.write_requested.connect(_on_write_requested)
		st.note_read.connect(_on_player_note_read)
	var mu: Node = world_director.current_mummy()
	if mu != null and mu.has_signal("examined"):
		mu.examined.connect(_on_mummy_examined)


func _on_write_requested(stand_id: StringName) -> void:
	_pending_stand = stand_id
	note_panel.show_pool(_NOTE_LINES_DATA.lines,
			progress.ws.note_line(stand_id))


func _on_player_note_read(stand_id: StringName, first_time: bool) -> void:
	sfx.play(&"note")
	if first_time:
		run_manager.record_event(_EV.Type.ECHO_NOTE_READ, 0,
				position_of_player(), 0, 0)


func _on_note_written(line_id: int) -> void:
	if _pending_stand == &"":
		return
	var ws: Variant = progress.ws
	if ws.write_note(_pending_stand, line_id, run_manager.run_id,
				run_manager.time_ms()):
		progress.stats.notes_written += 1
		run_manager.record_event(_EV.Type.NOTE_WRITTEN, 0,
				position_of_player(), 0, 0, line_id)
		toast.show_text("The note is saved.", 2.5)
		var st: Node = world_director.current_stand()
		if st != null and st.stand_id == _pending_stand:
			st.refresh("", false)  # readable from the next run
	_pending_stand = &""


func _on_mummy_examined(_stand: Node) -> void:
	var ws: Variant = progress.ws
	if not ws.flag(&"corpse_seen"):
		ws.set_flag(&"corpse_seen")
	run_manager.record_event(_EV.Type.MUMMY_EXAMINED, 0,
			position_of_player(), 0, 0)


func position_of_player() -> Vector3:
	return player.get_body_position()


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
	# P12: the Undercroft door is sealed until The First falls
	# (the door is the boss itself, BOSS_DESIGN §6; one-shot).
	if target == &"undercroft" and not progress.ws.flag(
				&"boss_defeated"):
		toast.show_text("The door is closed. (stone)", 2.5)
		return
	_enter_level(target)
	player.get_port().set_position(t_rp.origin + td.local_pos)
	# Phase 14: the heavy door (the cross that changes the zone).
	sfx.play(&"door")


# P12 (BOSS_DESIGN §2.1): the deep mine (the 3rd room of the mine
# chain and below) — two world facts land here: the exploration
# flag (any run) and the first traces (RUN 05+, once seen).
# F8 (debug builds only): Low -> Medium -> High -> Low. The toast
# is the QA handle for the §12 budgets on device.
func _debug_quality_cycle() -> void:
	if not OS.is_debug_build():
		return
	var pressed: bool = Input.is_action_just_pressed("debug_f8")
	if pressed and not _f8_prev and quality != null:
		var next: _QUALITY_PRESET
		match quality.preset.id:
			&"low":
				next = _QUALITY_MEDIUM
			&"medium":
				next = _QUALITY_HIGH
			&"high":
				next = _QUALITY_ULTRA
			_:
				next = _QUALITY_LOW
		quality.set_preset(next)
		zone_world.set_light_budget(quality.light_budget())
		toast.show_text("Quality: " + next.display_name, 1.5)
	_f8_prev = pressed


# F1 (debug builds only): the performance HUD (TEST_PLAN §7).
func _debug_overlay_toggle() -> void:
	if not OS.is_debug_build():
		return
	var pressed: bool = Input.is_action_just_pressed("debug_f1")
	if pressed and not _f1_prev and debug_overlay != null:
		debug_overlay.visible = not debug_overlay.visible
	_f1_prev = pressed


# F6 (debug builds only): a 10 s benchmark of the current area ->
# user://perf_<area>.txt (the `--benchmark` file, adb pull ->
# PERF_REPORT.md).
func _debug_benchmark() -> void:
	if not OS.is_debug_build():
		return
	var pressed: bool = Input.is_action_just_pressed("debug_f6")
	if pressed and not _f6_prev and perf_bench != null:
		if perf_bench._scope == null:
			perf_bench.start(self, String(_current_area), 10.0)
			toast.show_text("Benchmark: 10 s (%s)" % str(_current_area),
					2.0)
	_f6_prev = pressed


func _on_perf_bench_finished(stats: Dictionary) -> void:
	toast.show_text("Benchmark done: user://perf_%s.txt"
			% str(stats.get("label", "")), 3.0)


# Phase 15 — the save seams (TECHNICAL_DESIGN §3). The triggers:
# the death choice (a permanent fact), the safe hub (camp), and
# the window close. The auto-saves are quiet; only the choice
# says something.
func _do_save(reason: String) -> void:
	if save_manager == null or progress == null:
		return
	var st: Dictionary = {}
	if quality != null:
		st["quality"] = quality.preset.id
	if audio != null:
		st["audio"] = audio.get_settings()
	var ok: bool = save_manager.save(progress.ws.to_dict(), st)
	if ok and reason == "choice":
		toast.show_text("The world remembers.", 2.0)


func _apply_saved_settings() -> void:
	if _saved_settings.is_empty():
		return
	var q: StringName = StringName(
			str(_saved_settings.get("quality", "")))
	if not q.is_empty() and quality != null and q != quality.preset.id:
		var preset: _QUALITY_PRESET
		match q:
			&"low":
				preset = _QUALITY_LOW
			&"high":
				preset = _QUALITY_HIGH
			_:
				preset = _QUALITY_MEDIUM
		quality.set_preset(preset)
		if zone_world != null:
			zone_world.set_light_budget(quality.light_budget())
	var a: Dictionary = _saved_settings.get("audio", {})
	if not a.is_empty() and audio != null:
		audio.settings_from_dict(a)
	_saved_settings = {}


# Phase 14 — the audio seams. The scene owns the facts; the manager
# owns the playback (ADR-033).
func _update_audio() -> void:
	if audio == null:
		return
	audio.set_zone(_current_area)
	_update_audio_music()


func _update_audio_music() -> void:
	if audio == null:
		return
	var ghost: bool = ghost_director != null \
			and ghost_director.has_active_ghost()
	audio.update_music(_current_area, _boss_in_fight,
			progress.ws.flag(&"boss_defeated"), ghost)


# F9 (debug builds only): the audio settings panel.
func _debug_settings() -> void:
	if not OS.is_debug_build():
		return
	var pressed: bool = Input.is_action_just_pressed("debug_f9")
	if pressed and not _f9_prev and settings_panel != null:
		if settings_panel.visible:
			settings_panel.close()
		else:
			sfx.play(&"ui")
			settings_panel.show_panel(audio)
	_f9_prev = pressed


func _check_mine_deep(delta: float) -> void:
	if player == null or not is_instance_valid(player) \
			or _current_area != &"the_mine":
		return
	_mine_deep_timer += delta
	if _mine_deep_timer < 0.5:
		return
	_mine_deep_timer = 0.0
	var a: _AP = run_layout.get_area(&"the_mine")
	if a == null or a.rooms.size() <= int(_BOSS_GATE.MINE_DEEP_INDEX):
		return
	var p: Vector3 = player.global_position
	for i in a.rooms.size():
		var rp: _RP = a.rooms[i]
		var half: Vector2 = rp.room.size * 0.5 + Vector2(1.0, 1.0)
		if absf(p.x - rp.origin.x) <= half.x \
				and absf(p.z - rp.origin.z) <= half.y:
			if i >= int(_BOSS_GATE.MINE_DEEP_INDEX):
				_on_mine_deep()
			return


func _on_mine_deep() -> void:
	if not progress.ws.flag(&"mine_level_3_explored"):
		progress.ws.set_flag(&"mine_level_3_explored")
	# RUN 05+: the deep level carries the big footprints and his
	# lantern — reaching it (in RUN 05+) is seeing them.
	if run_manager.run_id >= 5 and not progress.ws.flag(
				&"first_traces_seen"):
		progress.ws.set_flag(&"first_traces_seen")
		toast.show_text("...the footprints are bigger than mine.", 3.5)


# The mine's deep-level prop (BOSS_DESIGN §2.1: «большие следы» +
# «его фонарь»): placed in the deepest room on every mine entry from
# RUN 05 (the level rebuilds per entry — the world remembers).
func _place_first_traces() -> void:
	var a: _AP = run_layout.get_area(&"the_mine")
	if a == null or a.rooms.size() < 2:
		return
	var rp: _RP = a.rooms.back()
	var spot: Vector3 = Vector3.ZERO
	if rp.room.event_spots.size() > 0:
		spot = rp.room.event_spots[0]
	elif rp.room.loot_spots.size() > 0:
		spot = rp.room.loot_spots[0]
	first_run.place_first_traces(rp.origin + spot)


# P12 (BOSS_DESIGN §2.2-4): the Undercroft content — the 3 pre-boss
# notes of The First, the FIRST BLADE take/leave, the boss.
func _set_up_undercroft() -> void:
	var a: _AP = run_layout.get_area(&"undercroft")
	if a == null or zone_world.level == null:
		return
	var rp: _RP = a.rooms[0]
	var o: Vector3 = rp.origin
	# The 3 notes (pre-boss read; CHARACTER_BIBLE §8 #2/#3 live here
	# for the players who read before they fight).
	var notes: Array = [
		["I was you. I was everyone. That's the trick. That's the trap."],
		["You'll fight like me. Of course. I taught you, in a way."],
		["Every time you reach the end, you restart everything. "
		 + "I'm sorry. I was, too. \u2014 The First"],
	]
	for i in notes.size():
		var stand: _NOTE_STAND = _NOTE_STAND.new()
		stand.name = "NoteStand_first_%d" % i
		stand.lines = PackedStringArray(notes[i])
		stand.flag_id = &""
		stand.beat = "undercroft_first_%d" % i
		stand.position = o + Vector3(-4.0 + i * 4.0, 0.0, 6.0)
		stand.setup(player)
		zone_world.level.add_child(stand)
	# The FIRST BLADE (WEAPON_DESIGN §4.3): take or leave it — the
	# choice is world-state (the boss comments either way).
	if not progress.ws.is_weapon_found(&"weapon_first_blade"):
		var pickup: _WEAPON_PICKUP = _WEAPON_PICKUP.new()
		pickup.name = "WeaponPickup_first_blade"
		pickup.position = o + (rp.room.loot_spots[0]
				if rp.room.loot_spots.size() > 0
				else Vector3(6.0, 0.0, 6.0))
		pickup.setup(_BLADE_DATA, progress, loadout, player,
				"It is still warm.")
		zone_world.level.add_child(pickup)
	# The boss (unless already defeated — the arena then holds the
	# aftermath: the notes, the stand, the open seal).
	if not progress.ws.flag(&"boss_defeated"):
		boss = _BOSS_CTRL.new()
		boss.name = "BossTheFirst"
		boss.textures = textures
		zone_world.level.add_child(boss)
		boss.global_position = o + Vector3(0.0, 0.0, -3.0)
		boss.setup(_BOSS_DATA, player, resolver, progress.ws,
				loadout, director, o, Vector3(0.0, 0.0, -3.0))
		boss.defeated.connect(_on_boss_defeated)
		boss.stage_reveal.connect(_on_boss_stage_reveal)
		loadout.weapon_changed.connect(boss._on_weapon_changed)
		if progress.ws.is_weapon_found(&"weapon_first_blade"):
			progress.ws.set_flag(&"first_blade_taken")
			boss.blade_taken_changed(true)
		# Phase 14: the reveal (the stinger over the monochrome arena).
		_boss_in_fight = true
		if audio != null:
			audio.play_stinger()
		boss.start_fight()
		_update_audio_music()


func _on_boss_defeated() -> void:
	# K6: the door opens (the flag the generator + the sealed door
	# read); K7 (the gate glow, the thinner fog) is flag-driven on
	# the gate's next entry (the world remembers, P10).
	progress.ws.set_flag(&"boss_defeated")
	# Phase 14: the seal breaks; the final scene is the Undercroft.
	_boss_in_fight = false
	sfx.play(&"seal")
	_update_audio_music()
	toast.show_text("The door is open.", 3.0)
	toast.show_text("The fog thins.", 3.5)


func _on_boss_stage_reveal(stage_id: StringName) -> void:
	# M2.3 (MYSTERY_REVEAL_MAP): the phase-2 line lands the stage.
	mystery.reveal(stage_id, progress.ws, run_manager.run_id)


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
		# Phase 8 (A14/A15): the world gives the weapon only AFTER the
		# first death — in RUN 1 the box carries the NOTE, not the
		# weapon (the cannon_found/staff_found flags are set on the
		# first death = "available from RUN 02").
		var available: bool = progress.ws.flag(
				&"cannon_found" if wid == &"weapon_cannon"
				else &"staff_found")
		if not available:
			if first_run != null and WEAPON_LINES.has(wid):
				first_run.place_gated_weapon_note(area_id, wid,
						rp.origin + rp.room.loot_spots[0],
						String(WEAPON_LINES[wid]))
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
	if progress != null and progress.ws.flag(_WORLD_DIR.BOSS_FLAG):
		# K7: post-boss the world «grows warmer» — the fog clears.
		e.fog_density *= _TRANSFORM_DATA.fog_factor
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
	# A respawn after a death begins the NEXT run (Phase 8): new
	# derived seed → new layout (the undercroft edges open, the
	# weapons wait). Rebuild budget (TECHNICAL_DESIGN §12): ≤ 2 s —
	# the generate + level swap is a few ms of pure work.
	if run_manager != null and run_manager.state == _RUN_MGR.State.DEAD:
		_begin_new_run()
	_apply_per_run_effects()
	# A respawn is back at the camp (Phase 7): re-enter the camp
	# level if the death happened in a zone.
	if zone_world != null and not zone_world.is_camp():
		_enter_level(&"camp")


# Death → new run (TECHNICAL_DESIGN §12, WORLD_STATE_DESIGN §1):
# run N+1 with a derived seed, the layout regenerated against the
# current world state, back at the camp.
func _begin_new_run() -> void:
	var old_layout: Variant = run_layout
	var prev_record: Variant = progress.ws.runs.get_run(
			run_manager.run_id)
	var seed: int = run_manager.begin_next_run()
	# The boss door (P12, ADR-019: a window, not a timer): the gate
	# rule is compound (mine level 3 + deaths + the first traces),
	# the result is ONE flag — evaluate it BEFORE the generator
	# reads progress.ws.flags (the door condition is data-driven).
	progress.ws.set_flag(&"boss_door_open", boss_gate.should_open(
			progress.ws, run_manager.run_id - 1))
	run_layout = run_generator.generate(seed, progress.ws.flags)
	_check_layout(run_layout, "run %d rebuild" % run_manager.run_id)
	zone_world.setup(run_layout)  # frees the old level, new one
	_zone_weapons.clear()
	director.clear()
	for n in _npcs:
		if is_instance_valid(n) and n.has_method("reset_run_lines"):
			n.reset_run_lines()
	# Phase 9: the echoes of the new run (the passive replay of the
	# run that just ended; the combat slot «where the player was»).
	if ghost_director != null:
		ghost_director.prepare_run(run_manager.run_id, progress.ws,
				prev_record, old_layout, run_layout)
		if ghost_director.combat_spawn_pos() != Vector3.ZERO:
			director.spawn_overrides[ghost_director.remnant_id] = \
					ghost_director.combat_spawn_pos()
	world_director.prepare_run(run_manager.run_id, prev_record,
			old_layout, run_layout)
	# Phase 11: the new run's reveal allowance + the NPC run ids.
	if mystery != null:
		mystery.reset_run()
	for n in _npcs:
		if is_instance_valid(n) and n.has_method("set_mystery_wiring"):
			n.set_mystery_wiring(_MYSTERY_LINES_DATA, run_manager.run_id)
	_free_child()
	_enter_level(&"camp")
	var port: Variant = player.get_port()
	if port != null:
		port.set_position($CampWorld.layout.spawn_pos)
	if first_run != null:
		first_run.on_run_started(run_manager.run_id)


func _on_player_died(_pos: Vector3) -> void:
	# Phase 14: the fall (the body, not a voice — "Again?" is text).
	sfx.play(&"death")
	# Phase 8 (A19): the run ends. The run system gets the death
	# (record + flags + the run record) BEFORE the death screen, so
	# the "what changed" lines are ready when the respawn comes.
	if run_manager != null:
		if progress != null:
			# RUN 02 availability (A14/A15/B1): the weapons wait from
			# the second run, the kettle is washed. Set BEFORE the
			# run system snapshots the "what changed" lines.
			progress.ws.set_flag(&"cannon_found")
			progress.ws.set_flag(&"staff_found")
			progress.ws.set_flag(&"kettle_washed")
		run_manager.on_player_died(_pos, _death_cause())
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


# The death cause for the run record (the last enemy that hurt the
# player — the data id's prefix: hollow_*/mimic_*/watcher_*/...).
func _death_cause() -> StringName:
	var a: Node = _last_player_attacker
	if a == null or not is_instance_valid(a):
		return &"unknown"
	var id: StringName = &"unknown"
	if a.has_method("get_data_id"):
		id = a.get_data_id()
	var s: String = String(id)
	var cut: int = s.find("_")
	return StringName(s.substr(0, cut if cut > 0 else s.length()))


func _on_death_choice(data: Resource) -> void:
	progress.resolve_death_choice(data)
	# Phase 15: the choice is permanent — it is saved now.
	_do_save("choice")
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
	drop.setup(_CAMP_ITEM, player)
	drop.interacted.connect(func(_ia: Node) -> void:
		# The add result in a variable first (the branch must not
		# hide the call: the rig's JS bridge mis-compiled
		# `if add():` in P17 — same code, native-safe either way).
		var res: int = inventory.add(_CAMP_ITEM)
		if res >= 0:
			toast.show_text("You take the small fire.")
			if sfx != null:
				sfx.play(&"pickup")
		else:
			toast.show_text("No room in the bag."))
	_drops.append(drop)


# The equipped weapon changed (pickup or the switch key): route its
# signals (cannon noise wakes enemies; the staff's effects show).
func _on_weapon_changed(_id: StringName) -> void:
	# P12: the FIRST BLADE taken (WEAPON_DESIGN §4.3) — the flag the
	# boss's comments and the remnants' respect read.
	if String(_id) == "weapon_first_blade":
		progress.ws.set_flag(&"first_blade_taken")
		if boss != null and is_instance_valid(boss):
			boss.blade_taken_changed(true)
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
	# Phase 8: the run clock (deciseconds, frozen when not PLAYING).
	if run_manager != null:
		run_manager.advance_time(d)
	player._physics_process(d)
	if director != null:
		director.update(d)
		director.record_player_position(player.get_body_position())
		tracker.sync_player_hits(player.weapon.hits_landed)
	if ghost_director != null:
		ghost_director.update(d)
	if world_director != null:
		world_director.update(d)
	# Phase 6: the inventory panel toggles on the `inventory` action
	# (I key / BAG touch button) — a hold-edge, like the dodge.
	var inv: bool = Input.is_action_pressed("inventory")
	if inv and not _inv_held:
		inventory_panel.toggle()
	_inv_held = inv


# A11: Nia lives in the village level (her home zone — CHARACTER_BIBLE
# §4). She is added on village entry and moved to the holding when the
# level is freed (her trust/state lives in world_state, the node is
# reused — no re-creation).
func _place_village_npc(area_id: StringName) -> void:
	if _village_npc == null or _npc_holding == null:
		return
	if area_id == &"ruined_village" and zone_world != null \
			and zone_world.layout != null:
		var a: Variant = zone_world.layout.get_area(&"ruined_village")
		if a == null or a.rooms.is_empty():
			return
		var rp: Variant = a.rooms[0]
		if _village_npc.get_parent() != zone_world.level:
			_npc_holding.remove_child(_village_npc)
			zone_world.level.add_child(_village_npc)
		_village_npc.global_position = Vector3(
				rp.origin.x + 2.5, 0.0, rp.origin.z + 2.0)


func _on_level_freed() -> void:
	if _village_npc != null and _npc_holding != null \
			and _village_npc.get_parent() != _npc_holding \
			and is_instance_valid(_village_npc):
		# reparent (add_child refuses a node that has a parent).
		_village_npc.reparent(_npc_holding)


# ---------------------------------------------------------------------------
# Phase 8 — UI beats: A1 (the 2 s black fade) and the "what changed"
# overlay (WORLD_STATE_DESIGN §9.2: ≤ 5 lines, 3 s, skippable).
# ---------------------------------------------------------------------------

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		# Phase 15: the last auto-save (TECHNICAL_DESIGN §3.5).
		_do_save("close")


func _exit_tree() -> void:
	# The isolated test save is disposable (the scene's lifetime).
	if _isolated_save and save_manager != null:
		for suffix in ["", ".bak", ".tmp"]:
			DirAccess.remove_absolute(save_manager.path + suffix)
		_isolated_save = false


func _process(delta: float) -> void:
	_check_mine_deep(delta)
	_debug_quality_cycle()
	_debug_settings()
	_debug_overlay_toggle()
	_debug_benchmark()
	if _a1_rect != null and _a1_left > 0.0:
		_a1_left -= delta
		var k: float = clampf(1.0 - _a1_left / A1_FADE_SECONDS, 0.0, 1.0)
		_a1_rect.color.a = 1.0 - k
		if _a1_left <= 0.0:
			var r: ColorRect = _a1_rect
			_a1_rect = null
			r.queue_free()
	# "What changed": the 3 s window, then a short fade; a press
	# (interact, held-edge) skips it.
	if _changed_left > 0.0 and _changed_label != null:
		var skip: bool = Input.is_action_pressed("interact")
		if skip and not _changed_held:
			_changed_left = 0.15  # a quick fade, not an instant cut
		_changed_left -= delta
		if _changed_left <= 0.0:
			_changed_label.modulate.a = 0.0
	_changed_held = Input.is_action_pressed("interact")


func _build_a1_fade() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "A1Fade"
	layer.layer = 40
	add_child(layer)
	_a1_rect = ColorRect.new()
	_a1_rect.color = Color(0.0, 0.0, 0.0, 1.0)
	_a1_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Fixed oversized rect (headless-safe: no viewport layout needed —
	# ADR-002; on device it covers any aspect ratio).
	_a1_rect.position = Vector2.ZERO
	_a1_rect.size = Vector2(4000.0, 4000.0)
	layer.add_child(_a1_rect)


func _on_changed_lines(lines: Array) -> void:
	if lines.is_empty():
		return
	if _changed_layer == null:
		_changed_layer = CanvasLayer.new()
		_changed_layer.name = "ChangedLines"
		_changed_layer.layer = 30
		add_child(_changed_layer)
		_changed_label = Label.new()
		_changed_label.text = ""
		_changed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_changed_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_changed_label.add_theme_font_size_override("font_size", 18)
		_changed_label.add_theme_color_override("font_color",
				Color(0.85, 0.88, 0.92, 1.0))
		_changed_label.add_theme_color_override("font_shadow_color",
				Color(0.0, 0.0, 0.0, 0.9))
		_changed_label.position = Vector2(0.0, 140.0)
		_changed_label.size = Vector2(4000.0, 140.0)
		_changed_label.modulate.a = 0.0
		_changed_layer.add_child(_changed_label)
	_changed_label.text = "\n".join(lines)
	_changed_label.modulate.a = 0.95
	_changed_left = CHANGED_WINDOW_SECONDS


var _changed_held: bool = false


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
		_last_player_attacker = res.source
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
