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
	director.load_nav(_NAV_DATA)
	# Aggression profile from the session stats (ENEMY_DESIGN §7).
	director.apply_aggression(
			tracker.stats.aggression_profile(_THR_DATA))
	tracker.sync_player_hits(player.weapon.hits_landed)
	director.start(_SPAWN_TABLE)
	# Player noise wakes enemies within hear_range (dodge + hits).
	player.connect("dodge_started", _on_player_noise)


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
