# Integration: the enemy system in the main scene (Phase 5).
#
# Main's auto drive is disabled; the test owns the clock: the player
# ticks through the scene HitStop (the same clock the director runs
# on — the global micro-freeze, ADR-023). The MovementPort mock owns
# the player body (set_port seam, ADR-022).
#
# Covers: spawn table (5 archetypes), staggered update budget,
# Hollow chase + attack, dodge i-frames blocking an enemy attack,
# the unkillable Watcher, the Watcher anchor (eye-line -> <=2/run),
# the Remnant first encounter (speech -> leave), the Forgotten
# wander, the Mimic spawn line, and enemy_killed -> EventBus +
# MemoryStats.
extends Node

const _MAIN = preload("res://scripts/world/main_scene.gd")
const _PLAYER = preload("res://scripts/player/player_controller.gd")
const _PORT = preload("res://scripts/player/movement_port.gd")
const _DATA = preload("res://scripts/gameplay/enemies/enemy_data.gd")
const _LOGIC = preload("res://scripts/gameplay/enemies/enemy_logic.gd")
const _ST = preload("res://scripts/gameplay/enemies/enemy_state.gd")
const _CT = preload("res://scripts/gameplay/combat/combat_target.gd")
const _DREQ = preload("res://scripts/gameplay/combat/damage_request.gd")

const DT: float = 1.0 / 60.0

var _main: _MAIN
var _player: _PLAYER
var _mock: _PORT
var _resolver: Node
var _director: Node
var _tracker: Node

var _killed_bus: Array = []  # [enemy_id, position] from the EventBus


func run(ctx: Variant) -> void:
	_setup_scene(ctx)
	if _director == null:
		return
	_spawn_table(ctx)
	_stagger_budget(ctx)
	_remnant_first_encounter(ctx)
	_hollow_attack(ctx)
	_i_frame_block(ctx)
	_watcher(ctx)
	_misc_behaviors(ctx)
	_kill_and_bus(ctx)


# --- Setup ---

func _setup_scene(ctx: Variant) -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	ctx.check(packed != null, "enemy_scene: main scene loads")
	if packed == null:
		return
	var scene: Node = packed.instantiate()
	_main = scene
	var player_node: Node = scene.find_child("Player", true, false)
	_player = player_node
	_mock = _PORT.new(null, _player.data.gravity,
			_player.data.max_fall_speed)
	_player.set_port(_mock)  # before tree entry (mock seam)
	add_child(scene)
	_main.set_physics_process(false)  # the test owns the clock
	_resolver = _main.resolver
	_director = _main.director
	_tracker = _main.tracker
	ctx.check(_director != null and _tracker != null,
			"enemy_scene: director + tracker composed")
	ctx.check(_director.nav != null
			and _director.nav.node_count() == 17,
			"enemy_scene: the camp nav graph loaded (17 nodes)")
	# EventBus spy (enemy_killed).
	var bus: Node = get_tree().root.get_node_or_null("EventBus")
	ctx.check(bus != null, "enemy_scene: EventBus present")
	if bus != null:
		bus.connect("enemy_killed", _on_enemy_killed)


func _on_enemy_killed(enemy_id: StringName, position: Vector3) -> void:
	_killed_bus.append([enemy_id, position])


# One gameplay frame: the player on the hitstop-scaled clock, then the
# director (the SAME clock — hitstop is global).
func _frame() -> void:
	var d: float = _main.hitstop.update(DT)
	_player._physics_process(d)
	if d > 0.0:
		_director.update(d)
	_director.record_player_position(_mock.get_position())
	_tracker.sync_player_hits(_player.weapon.hits_landed)


# Run frames until `cond`() or the budget. Returns the frame count.
func _run_until(cond: Callable, budget: int) -> int:
	for i in budget:
		_frame()
		if cond.call():
			return i + 1
	return -1


# Always read fresh from the director (a cached dict goes stale when
# an enemy despawns mid-scenario).
func _enemy(id: StringName) -> Node:
	for e in _director.get_alive_enemies():
		if e.data().id == id:
			return e
	return null


func _alive() -> Array:
	return _director.get_alive_enemies()


func _rescan() -> void:
	pass  # kept for the call sites; reads are always fresh now


# --- 1. Spawn table: 5 enemies, one per archetype ---

func _spawn_table(ctx: Variant) -> void:
	var alive: Array = _alive()
	ctx.check(alive.size() == 5,
			"enemy_scene: the demo table spawns 5 enemies (got %d)"
					% alive.size())
	var archetypes: Array = []
	for e in alive:
		archetypes.append(e.data().archetype)
	ctx.check(archetypes.has(_DATA.Archetype.HOLLOW)
			and archetypes.has(_DATA.Archetype.REMNANT)
			and archetypes.has(_DATA.Archetype.WATCHER)
			and archetypes.has(_DATA.Archetype.MIMIC)
			and archetypes.has(_DATA.Archetype.FORGOTTEN),
			"enemy_scene: one of each archetype (5 behaviors)")
	# Every enemy is resolver-registered with its data hp.
	var hollow: Node = _enemy(&"hollow_base")
	var ct: _CT = _resolver.get_combat_target(hollow)
	ctx.check(ct != null and ct.max_hp == 30.0,
			"enemy_scene: hollow registered with hp 30")
	var watcher: Node = _enemy(&"watcher_base")
	var wct: _CT = _resolver.get_combat_target(watcher)
	ctx.check(wct != null and wct.invulnerable,
			"enemy_scene: the watcher is unkillable (invulnerable)")


# --- 2. Staggered update budget (TECHNICAL_DESIGN AI budget) ---

func _stagger_budget(ctx: Variant) -> void:
	var ids: Array = []
	for e in _alive():
		ids.append(e.data().id)
	var prev: Dictionary = {}
	for id in ids:
		prev[id] = _enemy(id).ticks_run
	var first_tick_frames: Dictionary = {}
	var max_per_frame: int = 0
	var total_frames: int = 360  # 6 s at 60 fps
	for f in total_frames:
		_frame()
		var ticking_now: int = 0
		for id in ids:
			var e: Node = _enemy(id)
			if e == null:
				continue
			var n: int = e.ticks_run
			if not first_tick_frames.has(id) and n > 0:
				first_tick_frames[id] = f
			if n != prev[id]:
				ticking_now += 1
				prev[id] = n
		max_per_frame = maxi(max_per_frame, ticking_now)
	# The stagger spreads the first ticks across different frames.
	var distinct: int = first_tick_frames.values().size()
	ctx.check(first_tick_frames.size() == 5 and distinct >= 4,
			"enemy_scene: staggered first ticks (frames %s)"
					% str(first_tick_frames))
	# At 10 Hz for 6 s each enemy ticks ~60 times; the stagger keeps
	# the per-frame stack small (the device budget is 4 ms/run).
	var ok_rate: bool = true
	for id in ids:
		var e: Node = _enemy(id)
		if e == null:
			ok_rate = false
			break
		var ticks: int = e.ticks_run
		if ticks < 52 or ticks > 68:
			ok_rate = false
	ctx.check(ok_rate, "enemy_scene: each enemy runs at ~10 Hz")
	ctx.check(max_per_frame <= 2,
			"enemy_scene: staggered slots never stack > 2 ticks/frame "
					+ "(max %d)" % max_per_frame)


# --- 3. Remnant: the first encounter speaks, then it leaves ---

func _remnant_first_encounter(ctx: Variant) -> void:
	_rescan()
	var remnant: Node = _enemy(&"remnant_mirror")
	if remnant == null:
		ctx.check(false, "enemy_scene: remnant present")
		return
	# Walk toward the remnant from the spawn (it sees at 12 m).
	Input.action_press("move_up")
	# (A box, not a bool: the rig's lambda captures value types BY
	# COPY — a captured bool would not propagate out. ADR-022 item 17.)
	var spoken_box: Array = [false]
	var r: int = _run_until(func() -> bool:
		var e: Node = _enemy(&"remnant_mirror")
		if e == null:
			return true  # it already left
		if e.is_speaking():
			spoken_box[0] = true
			return true
		return e.logic().state() == _ST.State.LEAVE, 420)
	Input.action_release("move_up")
	ctx.check(r > 0 and spoken_box[0],
			"enemy_scene: the remnant speaks on first encounter")
	# It leaves: the speech, then the despawn + the run flag.
	r = _run_until(func() -> bool:
		return _enemy(&"remnant_mirror") == null, 180)
	ctx.check(r > 0, "enemy_scene: the remnant leaves after the speech")
	ctx.check(_director.remnant_met,
			"enemy_scene: the run remembers the meeting (remnant_met)")
	_rescan()


# --- 4. Hollow: chase, windup, and the hit lands on the player ---

# The combat scenarios need a quiet arena: drop the Mimic (it would
# keep attacking the player and muddy the hp assertions).
func _clear_noncombat(ctx: Variant) -> void:
	for id in [&"mimic_combo", &"mimic_dodge", &"mimic_range"]:
		var e: Node = _enemy(id)
		if e == null:
			continue
		var ct: _CT = _resolver.get_combat_target(e)
		var req: _DREQ = _DREQ.new()
		req.source = _player
		req.target = e
		req.amount = 999.0
		req.type = _DREQ.Type.MELEE
		req.position = e.global_position
		_resolver.resolve(req)
	_rescan()


func _hollow_attack(ctx: Variant) -> void:
	_rescan()
	_clear_noncombat(ctx)
	var hollow: Node = _enemy(&"hollow_base")
	if hollow == null:
		ctx.check(false, "enemy_scene: hollow present")
		return
	# 4 m in front of the hollow, inside its HEAR radius: the noise
	# aggro is facing-independent (the hollow's initial facing is a
	# test-environment detail; in-game it aggroes on sight while it
	# patrols).
	var hp: Vector3 = hollow.global_position
	_mock.set_position(hp + Vector3(4.0, 0.0, 0.0))
	_face_toward(hollow.global_position)
	_director.mark_player_noise()  # the player's swing noise
	var player_ct: _CT = _player.get_combat_target()
	var hp_before: float = player_ct.hp
	# Chase -> windup -> active: the hit lands (15 dmg from the data).
	var r: int = _run_until(func() -> bool:
		var e: Node = _enemy(&"hollow_base")
		return e != null and e.logic().state() == _ST.State.RECOVERY,
				600)
	ctx.check(r > 0, "enemy_scene: the hollow closed and attacked")
	ctx.check(player_ct.hp < hp_before - 10.0,
			"enemy_scene: the player took the hollow's hit (%.0f -> %.0f)"
					% [hp_before, player_ct.hp])


# --- 5. Dodge i-frames: the enemy's active frame is blocked ---

func _i_frame_block(ctx: Variant) -> void:
	_rescan()
	var hollow: Node = _enemy(&"hollow_base")
	if hollow == null:
		ctx.check(false, "enemy_scene: hollow present for the i-frame test")
		return
	var hp: Vector3 = hollow.global_position
	_mock.set_position(hp + Vector3(8.0, 0.0, 0.0))
	_face_toward(hollow.global_position)
	var player_ct: _CT = _player.get_combat_target()
	var hp_before: float = player_ct.hp
	# No leftover hitstun from the previous scenario.
	_run_until(func() -> bool:
		return _player.can_act(), 240)
	# The enemy's attack lands through the DamageResolver (the
	# controller's sector sample — ADR-023); the i-frame block is
	# resolver-side. So: dodge the player (i-frames 0.05..0.25 s) and
	# deliver the enemy's exact attack with the SAME resolve path.
	var enemy_req: _DREQ = _DREQ.new()
	enemy_req.source = hollow
	enemy_req.target = _player
	enemy_req.amount = float(hollow.data().attack.damage)
	enemy_req.type = _DREQ.Type.MELEE
	enemy_req.position = _mock.get_position()

	Input.action_press("dodge")
	for i in 4:  # tick 4: inside the i-frame window
		_frame()
	var res: Variant = _resolver.resolve(enemy_req)
	ctx.check(_player.is_invulnerable(),
			"enemy_scene: the player is inside the dodge i-frames")
	ctx.check(res.blocked and res.blocked_reason == &"invulnerable",
			"enemy_scene: the enemy attack is blocked by i-frames")
	ctx.check(absf(player_ct.hp - hp_before) < 0.01,
			"enemy_scene: blocked hit deals no damage")
	Input.action_release("dodge")
	# After the i-frames expire, the same hit lands.
	_run_until(func() -> bool:
		return not _player.is_invulnerable() and _player.can_act(),
				120)
	var hp_before_hit2: float = player_ct.hp
	res = _resolver.resolve(enemy_req)
	ctx.check(not res.blocked and res.applied ==
			float(hollow.data().attack.damage),
			"enemy_scene: the same hit lands outside the i-frames")
	ctx.check(absf(player_ct.hp - (hp_before_hit2 - float(
			hollow.data().attack.damage))) < 0.01,
			"enemy_scene: the player took the enemy's damage")


# --- 6. Watcher: unkillable, the anchor on the 2 s eye-line ---

func _watcher(ctx: Variant) -> void:
	_rescan()
	var watcher: Node = _enemy(&"watcher_base")
	if watcher == null:
		ctx.check(false, "enemy_scene: watcher present")
		return
	var wct: _CT = _resolver.get_combat_target(watcher)
	# A full player hit: blocked, hp untouched.
	var req: _DREQ = _DREQ.new()
	req.source = _player
	req.target = watcher
	req.amount = 999.0
	req.type = _DREQ.Type.MELEE
	req.position = watcher.global_position
	var res: Variant = _resolver.resolve(req)
	ctx.check(res.blocked and wct.hp == 999.0,
			"enemy_scene: the watcher cannot be killed (hit blocked, "
					+ "hp 999)")
	# The eye-line: 6 m away, facing it for >= 2 s -> the anchor.
	var wp: Vector3 = watcher.global_position
	_mock.set_position(wp + Vector3(0.0, 0.0, 6.0))
	_face_toward(watcher.global_position)
	var anchors_before: int = _director.anchors.size()
	var r: int = _run_until(func() -> bool:
		return _director.anchors.size() > anchors_before, 240)
	ctx.check(r > 0,
			"enemy_scene: 2 s of eye-line created a memory anchor")
	var a: Variant = _director.anchors[_director.anchors.size() - 1]
	var dist_to_player: float = a.position.distance_to(
			_mock.get_position())
	ctx.check(dist_to_player < 1.0,
			"enemy_scene: the anchor stores the player position")


# --- 7. Mimic spawn line + Forgotten wander ---

func _misc_behaviors(ctx: Variant) -> void:
	_rescan()
	var mimic: Node = _enemy(&"mimic_combo")
	if mimic != null:
		# The speech bubble is visible right after spawn (3 s window):
		# re-check via a fresh spawn line read.
		ctx.check(mimic.data().spawn_line == "I know how you do it.",
				"enemy_scene: the mimic carries its spawn line (data)")
	var forgotten: Node = _enemy(&"forgotten_wanderer")
	if forgotten != null:
		var r: int = _run_until(func() -> bool:
			return forgotten.logic().state() == _ST.State.WANDER, 120)
		ctx.check(r > 0, "enemy_scene: the forgotten wanderer wanders")
	# The Forgotten guard data stands still (unit-level: wander 0).
	var guard: _DATA = load("res://data/enemies/forgotten_guard.tres")
	ctx.check(guard.wander_radius == 0.0,
			"enemy_scene: the guard variant stands (no wander)")


# --- 8. Kill: enemy_killed -> EventBus -> MemoryStats ---

func _kill_and_bus(ctx: Variant) -> void:
	_rescan()
	var hollow: Node = _enemy(&"hollow_base")
	if hollow == null:
		ctx.check(false, "enemy_scene: hollow present for the kill test")
		return
	var hct: _CT = _resolver.get_combat_target(hollow)
	var kills_before: int = _tracker.stats.kills
	var req: _DREQ = _DREQ.new()
	req.source = _player
	req.target = hollow
	req.amount = 999.0
	req.type = _DREQ.Type.MELEE
	req.position = hollow.global_position
	var res: Variant = _resolver.resolve(req)
	ctx.check(res.killed, "enemy_scene: the hollow dies to the hit")
	# Dissolve (0.3 s) -> the director reaps it + the bus. (The Mimic
	# died earlier in this run — count from the bus baseline.)
	var bus_before: int = _killed_bus.size()
	var r: int = _run_until(func() -> bool:
		return _killed_bus.size() > bus_before, 120)
	ctx.check(r > 0, "enemy_scene: enemy_killed reached the EventBus")
	if r > 0:
		ctx.check(_killed_bus[bus_before][0] == &"hollow_base",
				"enemy_scene: the bus carries the hollow's id")
	ctx.check(_tracker.stats.kills == kills_before + 1,
			"enemy_scene: MemoryStats counts the kill (%d -> %d)"
					% [kills_before, _tracker.stats.kills])
	_rescan()
	ctx.check(_enemy(&"hollow_base") == null,
			"enemy_scene: the dissolved hollow is despawned")


# --- Helpers ---

# Turn the player's facing exactly at `target` (walk a moment to make
# the logic own the facing, then fix it — the eye-line and the attack
# arc both read the player's facing).
func _face_toward(target: Vector3) -> void:
	var dir: Vector3 = target - _mock.get_position()
	dir.y = 0.0
	if dir.length() < 0.01:
		return
	dir = dir.normalized()
	if absf(dir.x) > absf(dir.z):
		Input.action_press("move_right" if dir.x > 0.0
				else "move_left")
	else:
		Input.action_press("move_down" if dir.z > 0.0
				else "move_up")
	for i in 6:
		_frame()
	for a in ["move_up", "move_down", "move_left", "move_right"]:
		Input.action_release(a)
	# The test owns the facing exactly (no drift in the mock).
	_player._logic.facing = dir
