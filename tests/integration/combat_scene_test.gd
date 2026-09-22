# Integration: BLADE combat in the main scene (Phase 4).
#
# The player runs on the MovementPort mock (set_port seam); the test owns
# the clock: Main's hitstop drive is disabled and the player is ticked
# manually through the SAME hitstop the scene uses (deterministic,
# ADR-022 items 8/11). The test dummy is a test-only target (ROADMAP
# Phase 4: "test objects in tests/, not in the game").
# Input via Input.action_press/release (rig contract).
extends Node

const _PLAYER = preload("res://scripts/player/player_controller.gd")
const _PORT = preload("res://scripts/player/movement_port.gd")
const _MAIN = preload("res://scripts/world/main_scene.gd")
const _CT = preload("res://scripts/gameplay/combat/combat_target.gd")
const _DREQ = preload("res://scripts/gameplay/combat/damage_request.gd")
const _STATE = preload("res://scripts/player/player_state.gd")
const _DS = preload("res://scripts/ui/death_screen.gd")

const DT: float = 1.0 / 60.0

var _mock: _PORT
var _main: _MAIN
var _player: _PLAYER
var _resolver: Node
var _dummy: Node3D
var _dummy_ct: _CT
var _spawn: Vector3 = Vector3.ZERO


func run(ctx: Variant) -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	ctx.check(packed != null, "combat: main scene loads")
	if packed == null:
		return
	var scene: Node = packed.instantiate()
	ctx.check(scene != null and scene is _MAIN,
			"combat: scene instantiates (MainScene)")
	if scene == null:
		return
	_main = scene
	# The player node exists before tree entry; the scene wiring
	# (resolver/weapon bind) happens in _ready, so it is checked after.
	var player_node: Node = scene.find_child("Player", true, false)
	ctx.check(player_node != null and player_node is _PLAYER,
			"combat: player present")
	_player = player_node
	if _player == null:
		return
	_mock = _PORT.new(null,
			_player.data.gravity, _player.data.max_fall_speed)
	_player.set_port(_mock)  # before tree entry (mock seam)
	add_child(scene)

	# Test owns the clock: disable Main's auto drive.
	_main.set_physics_process(false)
	_resolver = _main.resolver
	ctx.check(_resolver != null, "combat: resolver composed")
	ctx.check(_main.player == _player, "combat: scene wired the player")
	ctx.check(_player.weapon != null
			and _player.weapon.get_logic() != null,
			"combat: weapon bound with logic")

	_spawn = scene.find_child("SpawnPoint", true, false).global_position
	ctx.check(_mock.get_position().distance_to(_spawn) < 0.01,
			"combat: player starts at the spawn point")

	# Test-only dummy: a capsule with its own CombatTarget.
	_dummy = Node3D.new()
	_dummy.name = "TestDummy"
	var body_mi: MeshInstance3D = MeshInstance3D.new()
	var cm: CapsuleMesh = CapsuleMesh.new()
	cm.radius = 0.35
	cm.height = 1.7
	body_mi.mesh = cm
	_dummy.add_child(body_mi)
	_dummy_ct = _CT.new(_dummy, 100.0)
	_dummy_ct.combat_id = &"test_dummy"
	scene.add_child(_dummy)
	# 1.5 m in front of the player (facing is -Z by default).
	_dummy.global_position = _mock.get_position() + Vector3(0.0, 0.0, -1.5)
	_resolver.register(_dummy, _dummy_ct)

	_test_single_hit(ctx)
	_test_full_combo(ctx)
	_test_player_damage(ctx)
	_test_iframes(ctx)
	_test_riposte(ctx)
	_test_death_respawn(ctx)
	_test_stunned_cannot_attack(ctx)


func _reset() -> void:
	_dummy_ct.reset()
	_player.get_combat_target().reset()
	_player.weapon.reset()  # no combo/CD leaks between scenarios
	_mock.set_position(_spawn)


func _tick(n: int) -> void:
	for i in n:
		var d: float = _main.hitstop.update(DT)
		_player._physics_process(d)


func _test_single_hit(ctx: Variant) -> void:
	_reset()
	var sfx_before: int = _main.sfx.trigger_count
	var vfx_before: int = _main.vfx.spawn_calls
	var hits: Array = []
	_resolver.damage_applied.connect(func(r) -> void:
		hits.append(r)
	)
	Input.action_press("attack")
	_tick(20)  # windup 0.25 s + active: the first active tick lands
	Input.action_release("attack")
	# Camera shake: no engine frames run during the test (manual clock),
	# so the amplitude is still un-decayed here — read it directly.
	var shake_after_hit: float = _player.camera_rig.get_shake_amplitude()
	_tick(60)  # recovery ends

	ctx.check(_dummy_ct.hp == 75.0,
			"combat: U1 lands 25 dmg (hp %f)" % _dummy_ct.hp)
	ctx.check(hits.size() == 1,
			"combat: exactly one hit registered (got %d)" % hits.size())
	if hits.size() == 1:
		var r: Variant = hits[0]
		ctx.check(r.applied == 25.0 and r.source == _player
				and r.target == _dummy,
				"combat: damage result carries source/target/amount")
	ctx.check(_main.sfx.trigger_count >= sfx_before + 2,
			"combat: swing + hit cues played ( +%d)"
			% (_main.sfx.trigger_count - sfx_before))
	ctx.check(_main.vfx.spawn_calls > vfx_before,
			"combat: impact VFX spawned")
	ctx.check(shake_after_hit > 0.0,
			"combat: camera shake on hit (amp %f)" % shake_after_hit)


func _test_full_combo(ctx: Variant) -> void:
	_reset()
	var combo_hits: Array = []
	var combo_conn: Callable = func(_r) -> void:
		combo_hits.append(
				_player.weapon.get_logic().hit_index())
	_resolver.damage_applied.connect(combo_conn)
	# Held-edge input needs a tick between release and press (the edge
	# state updates inside the weapon tick). Swing times: U1/U2 = 72
	# ticks (1.2 s), U3 = 90 (1.5 s).
	Input.action_press("attack")
	_tick(10)  # t=10: U1 windup
	Input.action_release("attack")
	_tick(1)   # t=11: edge state clears
	Input.action_press("attack")  # t=12: buffer U2
	_tick(61)  # t=72: U1 ends -> U2 starts
	_tick(10)  # t=82: U2 windup
	Input.action_release("attack")
	_tick(1)   # t=83: edge state clears
	Input.action_press("attack")  # t=84: buffer U3
	_tick(61)  # t=144: U2 ends -> U3 starts
	Input.action_release("attack")
	_tick(92)  # t=236: U3 ends (t=234)
	_resolver.damage_applied.disconnect(combo_conn)
	ctx.check(_dummy_ct.hp == 20.0,
			"combat: full combo U1+U2+U3 = 80 (hp %f, hit indices %s)"
			% [_dummy_ct.hp, str(combo_hits)])


func _test_player_damage(ctx: Variant) -> void:
	_reset()
	var sfx_before: int = _main.sfx.trigger_count
	var req: _DREQ = _DREQ.new()
	req.source = _dummy
	req.target = _player
	req.amount = 10.0
	req.knockback_direction = Vector3(0.0, 0.0, 1.0)  # away from the dummy
	var res: Variant = _resolver.resolve(req)
	ctx.check(not res.blocked and res.applied == 10.0,
			"combat: player takes 10 dmg")
	ctx.check(_player.get_combat_target().hp == 90.0,
			"combat: player hp 100 -> 90")
	ctx.check(_player.get_state() == _STATE.State.HURT,
			"combat: player in hitstun")
	ctx.check(_main.vignette.get_alpha() > 0.0,
			"combat: hurt vignette flashed")
	ctx.check(_main.sfx.trigger_count >= sfx_before + 1,
			"combat: hurt cue played")
	_tick(30)  # hitstun 0.35 s ends
	ctx.check(_player.get_state() == _STATE.State.IDLE,
			"combat: hitstun recovers")


func _test_iframes(ctx: Variant) -> void:
	_reset()
	Input.action_press("dodge")
	_tick(10)  # 0.17 s: inside the i-frame window [0.05, 0.25]
	var req: _DREQ = _DREQ.new()
	req.source = _dummy
	req.target = _player
	req.amount = 10.0
	req.knockback_direction = Vector3(0.0, 0.0, 1.0)
	var res: Variant = _resolver.resolve(req)
	ctx.check(res.blocked and res.blocked_reason == &"invulnerable",
			"combat: i-frames block the hit")
	ctx.check(_player.get_combat_target().hp == 100.0,
			"combat: no hp loss during i-frames")
	Input.action_release("dodge")
	_tick(60)  # dodge + cooldown over


func _test_riposte(ctx: Variant) -> void:
	_reset()
	var sfx_before: int = _main.sfx.trigger_count
	var vfx_before: int = _main.vfx.spawn_calls
	Input.action_press("special")
	_tick(6)  # 0.1 s: inside the 0.5 s counter window
	var req: _DREQ = _DREQ.new()
	req.source = _dummy
	req.target = _player
	req.amount = 10.0
	req.knockback_direction = Vector3(0.0, 0.0, 1.0)
	var res: Variant = _resolver.resolve(req)
	Input.action_release("special")
	_tick(30)

	ctx.check(not res.blocked and res.applied == 10.0,
			"combat: riposte does not negate the hit (player still hurt)")
	ctx.check(_dummy_ct.is_stunned(), "combat: attacker stunned 1.5 s")
	ctx.check(_dummy_ct.hp == 85.0,
			"combat: counter dealt 15 dmg (hp %f)" % _dummy_ct.hp)
	ctx.check(_player.weapon.get_logic().riposte_cd_remaining() > 29.0,
			"combat: riposte cooldown running (30 s)")
	ctx.check(_main.sfx.trigger_count >= sfx_before + 2,
			"combat: parry + hurt cues played")
	ctx.check(_main.vfx.spawn_calls > vfx_before,
			"combat: counter VFX spawned")


func _test_death_respawn(ctx: Variant) -> void:
	_reset()
	_mock.set_position(Vector3(3.0, 0.0, -2.0))  # away from spawn
	var bus: Node = get_tree().root.get_node_or_null("EventBus")
	ctx.check(bus != null, "combat: EventBus autoload present")
	var died: Array = []
	var spawned: Array = []
	bus.player_died.connect(func(p: Vector3) -> void: died.append(p))
	bus.player_spawned.connect(func(p: Vector3) -> void: spawned.append(p))

	var req: _DREQ = _DREQ.new()
	req.source = _dummy
	req.target = _player
	req.amount = 500.0
	req.knockback_direction = Vector3(0.0, 0.0, 1.0)
	_resolver.resolve(req)
	ctx.check(_player.is_dead(), "combat: player dead at 0 hp")
	ctx.check(died.size() == 1,
			"combat: EventBus.player_died emitted once")
	# Phase 6: death pauses the respawn until the 1-of-3 choice (the
	# death screen). The test makes the pick through the public API —
	# the same path a finger tap takes (gui_input -> press()).
	var screen: _DS = _main.get_node_or_null("DeathScreen")
	ctx.check(screen != null, "combat: death screen composed")
	if screen != null:
		ctx.check(_player.death_choice_pending,
				"combat: respawn waits for the choice")
		var owned_before: Array = _main.progress.ws.owned_inheritances()
		screen.press(0)
		var owned_after: Array = _main.progress.ws.owned_inheritances()
		ctx.check(owned_after.size() == owned_before.size() + 1,
				"combat: the pick is PERMANENT (owned %d -> %d)"
				% [owned_before.size(), owned_after.size()])
		ctx.check(not _player.death_choice_pending,
				"combat: the choice unblocks the respawn")
	_tick(150)  # respawn on the next tick + margin
	ctx.check(not _player.is_dead(), "combat: player respawned")
	ctx.check(_player.get_combat_target().hp == 100.0,
			"combat: hp restored on respawn")
	ctx.check(spawned.size() == 1,
			"combat: EventBus.player_spawned emitted once")
	var pos: Vector3 = _mock.get_position()
	ctx.check(pos.distance_to(_spawn) < 0.01,
			"combat: respawn at the spawn position (got %s)" % str(pos))


func _test_stunned_cannot_attack(ctx: Variant) -> void:
	_reset()
	_player.get_combat_target().apply_stun(1.0)
	ctx.check(not _player.can_act(), "combat: stunned = cannot act")
	Input.action_press("attack")
	_tick(90)  # a full swing's worth
	Input.action_release("attack")
	ctx.check(_dummy_ct.hp == 100.0,
			"combat: stunned player deals no damage")
