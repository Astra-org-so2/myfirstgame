# Integration: THE FIRST (Phase 12) in the main scene.
#
# The full scene wiring: the Undercroft content (boss + seal + the 3
# pre-boss notes + the FIRST BLADE), the boss fight (melee, the
# pattern memory -> look, the parry block + counter, the core hit on
# the seal), the phase-2 shift (the Remnant minion + the M2.3 reveal
# signal), the death sequence (K6 -> the flags) and the FIRST BLADE
# take/leave (WEAPON_DESIGN §4.3).
#
# Same rig contract as the other scene tests: the player on the
# MovementPort mock, manual _physics_process ticks, Input.action_press
# for the edge actions (ADR-022). The player FACES -Z by default, so
# "in front of the player" = pos + (0, 0, -d).
extends Node

const _MAIN = preload("res://scripts/world/main_scene.gd")
const _PLAYER = preload("res://scripts/player/player_controller.gd")
const _PORT = preload("res://scripts/player/movement_port.gd")
const _DREQ = preload("res://scripts/gameplay/combat/damage_request.gd")
const _EST = preload("res://scripts/gameplay/enemies/enemy_state.gd")
const _BST = preload("res://scripts/gameplay/boss/boss_logic.gd")

const DT: float = 1.0 / 60.0

var _main: _MAIN
var _player: _PLAYER
var _mock: _PORT
var _ticks: Array = []
var _boss: Node = null
var _minion: Node = null
var _reveals: Array = []
var _defeated_count: int = 0


func run(ctx: Variant) -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	ctx.check(packed != null, "boss: main scene loads")
	if packed == null:
		return
	var scene: Node = packed.instantiate()
	_main = scene
	var player_node: Node = scene.find_child("Player", true, false)
	_player = player_node
	if _player == null:
		ctx.check(false, "boss: player present")
		return
	_mock = _PORT.new(null,
			_player.data.gravity, _player.data.max_fall_speed)
	_player.set_port(_mock)
	add_child(scene)
	_main.set_physics_process(false)

	_test_arena_setup(ctx)
	if _boss == null:
		return
	_test_boss_melee(ctx)
	_test_pattern_learn(ctx)
	_test_parry(ctx)
	_test_core_hit(ctx)
	_test_phase2_and_minion(ctx)
	_test_first_blade(ctx)
	_test_death_sequence(ctx)


func _tick(n: int) -> void:
	for i in n:
		_player._physics_process(DT)
		for t in _ticks:
			if is_instance_valid(t):
				t._physics_process(DT)


func _teleport(pos: Vector3) -> void:
	_mock.set_position(pos)
	_tick(2)


# One blade press (one pattern step: "<weapon>:<hit_index>").
func _press() -> void:
	Input.action_press("attack")
	_tick(1)
	Input.action_release("attack")


# One full 3-hit combo (U1 -> U2 -> U3): three presses, each inside
# the previous hit's combo window (the combo continues only when the
# next press lands within 0.5 s of the recovery end). Each hit is
# one pattern step, so a combo is the sequence [0, 1, 2].
func _swing_combo() -> void:
	_press()
	_tick(80)   # U1 (1.2 s) + 0.13 s into the 0.5 s window
	_press()
	_tick(80)   # U2 (1.2 s) + 0.13 s into the window
	_press()
	_tick(90)   # U3 (1.35 s): the combo ends


# One single hit (U1 only): the pattern step + the core check fire
# on the swing_started of the first hit.
func _swing_u1_only() -> void:
	_press()
	_tick(90)   # the full U1 (windup 0.25 + active 0.15 + recovery)


# --- 1. The Undercroft content ----------------------------------------

func _test_arena_setup(ctx: Variant) -> void:
	var o: Vector3 = _arena_origin()
	_main._enter_level(&"undercroft")
	_ticks = [_main.boss] if _main.boss != null else []
	_boss = _main.boss
	ctx.check(_boss != null and is_instance_valid(_boss),
			"boss: THE FIRST spawns in the Undercroft")
	ctx.check(_main.zone_world.level.find_child("ArenaSeal", true,
			false) != null,
			"boss: the arena seal (the core) is placed")
	for i in 3:
		ctx.check(_main.zone_world.level.find_child(
				"NoteStand_first_%d" % i, true, false) != null,
				"boss: pre-boss note %d of The First is placed" % i)
	ctx.check(_main.zone_world.level.find_child(
			"WeaponPickup_first_blade", true, false) != null,
			"boss: the FIRST BLADE waits in the arena")
	_boss.stage_reveal.connect(func(s: StringName) -> void:
		_reveals.append(s))
	_boss.defeated.connect(func() -> void:
		_defeated_count += 1)
	# Phase 14: the reveal (the stinger over the monochrome arena).
	ctx.check(_main.audio != null,
			"boss: the audio manager is composed")
	ctx.check(_main.audio.current_zone() == &"undercroft",
			"boss: the undercroft bed is on")
	ctx.check(_main.audio.is_stinger_playing(),
			"boss: the reveal stinger plays")
	ctx.check(_main.audio.current_variation()
			== _main.audio._DIR.Variation.ARCHIVIST,
			"boss: the arena plays the ARCHIVIST variation")
	# The boss stands on the seal (the arena's event spot).
	ctx.check(absf(_boss.global_position.x - (o.x + 0.0)) < 0.01
			and absf(_boss.global_position.z - (o.z - 3.0)) < 0.01,
			"boss: the boss holds the seal")
	ctx.check(_boss.logic.state == _BST.State.IDLE,
			"boss: the fight starts IDLE")
	ctx.check(String(_boss._label.text).contains("You came back"),
			"boss: the entry line (CHARACTER_BIBLE §8 #1)")
	# The arena door is sealed at RUN 1 (the boss gate, §2.1).
	var mine_ap: Variant = _main.run_layout.get_area(&"the_mine")
	var conn: Node = null
	for c in mine_ap.area.connections:
		if c.to == &"undercroft":
			conn = c
	var fwd: Node = mine_ap.rooms.back().door(conn.door)
	ctx.check(fwd != null and fwd.is_sealed(),
			"boss: RUN 1 the Undercroft edge is sealed (the boss gate)")


func _arena_origin() -> Vector3:
	var a: Variant = _main.run_layout.get_area(&"undercroft")
	return a.rooms[0].origin


# --- 2. His melee -------------------------------------------------------

func _test_boss_melee(ctx: Variant) -> void:
	_player.combat.hp = 100.0  # the fight deals ~80 total
	var o: Vector3 = _arena_origin()
	# 2.2 m from the seal (the boss's home), in front of the player's
	# default facing (-Z): the boss stands at the seal, the player
	# faces him.
	_teleport(Vector3(o.x, 0.0, o.z - 3.0 + 2.2))
	var hp0: float = _player.combat.hp
	_tick(80)  # windup 0.5 + active 0.15 -> the hit
	ctx.check(_player.combat.hp < hp0,
			"boss: his melee lands (telegraph 0.5 s, 20 dmg)")
	ctx.check(hp0 - _player.combat.hp >= 20.0,
			"boss: the melee deals his melee damage (20)")


# --- 3. The pattern memory (the learn) ----------------------------------

func _test_pattern_learn(ctx: Variant) -> void:
	_player.combat.hp = 100.0  # the fight deals ~80 total
	var o: Vector3 = _arena_origin()
	# Far from the seal (he does not attack away from the arena
	# center) but reachable: he chases, the player keeps swinging.
	_teleport(Vector3(o.x + 7.0, 0.0, o.z + 7.0))
	_tick(60)  # let him walk in from the seal
	_swing_combo()
	_swing_combo()
	_swing_combo()  # the third repetition completes the learn
	var learned: bool = _boss._pm.learned.size() == 3
	ctx.check(learned,
			"boss: three full combos = a learned sequence (length 3)")
	if not learned:
		return
	# LEARNED landed on the combo's last step; the boss took the
	# "look" (0.3 s) + line #4.
	_tick(10)
	ctx.check(String(_boss._label.text).contains("hundred times"),
			"boss: the learn line (CHARACTER_BIBLE §8 #4)")


# --- 4. The parry (block + counter) --------------------------------------

func _test_parry(ctx: Variant) -> void:
	_player.combat.hp = 100.0  # the fight deals ~80 total
	# The player keeps the boss in his band (1.8 m — inside the blade
	# range 2.0, inside his counter range 2.8) but far from the seal,
	# so he never attacks: the parry window is clean.
	var bp: Vector3 = _boss.global_position
	_teleport(Vector3(bp.x, 0.0, bp.z + 1.8))
	_tick(90)  # the boss settles in the band
	var bhp0: float = _boss.logic.hp()
	var php0: float = _player.combat.hp
	# The learned sequence repeated: U1, U2 walk it, U3 completes it
	# -> PARRY_TRIGGER on U3's swing_started.
	_press()
	_tick(80)
	_press()
	_tick(80)
	_press()
	var triggered: bool = false
	for i in 120:
		_player._physics_process(DT)
		for t in _ticks:
			if is_instance_valid(t):
				t._physics_process(DT)
		if _boss.logic.state == _BST.State.PARRY:
			triggered = true
			break
	if not triggered:
		_tick(120)
	ctx.check(triggered,
			"boss: the repeated sequence triggers his parry")
	if not triggered:
		return
	# The window: the target is sealed (a direct hit is BLOCKED).
	var req: _DREQ = _DREQ.new()
	req.source = _player
	req.target = _boss
	req.amount = 10.0
	req.type = _DREQ.Type.MELEE
	req.position = _boss.global_position
	var res: Variant = _main.resolver.resolve(req)
	ctx.check(res.blocked, "boss: the parry window blocks your hits")
	_tick(60)
	# The counter: his melee range, the parry damage — and his melee
	# did NOT come (the player is far from the seal).
	ctx.check(absf(php0 - _player.combat.hp - 25.0) < 0.01,
			"boss: the parry counter deals 25")
	ctx.check(_boss.logic.hp() < bhp0,
			"boss: the combo's first hits still land (the parry "
			+ "blocks the repeat, not the fight)")


# --- 5. The core (the seal) ----------------------------------------------

func _test_core_hit(ctx: Variant) -> void:
	_player.combat.hp = 100.0  # the fight deals ~80 total
	var o: Vector3 = _arena_origin()
	var seal: Vector3 = Vector3(o.x, 0.0, o.z - 3.0)
	# Draw him back to the arena while the player is out of his
	# attack range (he defends the seal, not the corridors).
	_teleport(Vector3(o.x + 7.0, 0.0, o.z + 7.0))
	for i in 900:
		_tick(1)
		var bd: float = _boss.global_position.distance_to(
				_player.get_body_position())
		if _boss.logic.state == _BST.State.IDLE and bd <= 2.3:
			break
	# 2.5 m from the seal: inside the blade's core reach (range 2.0
	# + 0.5) but OUTSIDE its normal swing reach (2.0).
	_teleport(Vector3(seal.x, 0.0, seal.z + 2.5))
	for i in 600:
		_tick(1)
		if _boss.logic.state == _BST.State.IDLE \
				and _boss.logic._slam_cd <= 0.0:
			break
	_boss.logic.force_next_slam(true)
	for i in 240:
		_tick(1)
		if _boss.logic.core_window_active():
			break
	var in_window: bool = _boss.logic.core_window_active()
	ctx.check(in_window,
			"boss: the core window opens after the slam (2 s)")
	if not in_window:
		return
	var bhp0: float = _boss.logic.hp()
	_swing_u1_only()
	ctx.check(absf(bhp0 - _boss.logic.hp() - 30.0) < 0.01,
			"boss: the core hit deals 30 (plain weapon, the seal)")
	ctx.check(String(_boss._label.text).contains("you felt that"),
			"boss: the core line (CHARACTER_BIBLE §8 #8)")
	ctx.check(not _boss.logic.core_window_active(),
			"boss: the core window is one-shot per slam")


# --- 6. Phase 2 (the Remnant minion + M2.3) -------------------------------

func _test_phase2_and_minion(ctx: Variant) -> void:
	_player.combat.hp = 100.0  # the fight deals ~80 total
	_boss.logic.set_hp(300.0)  # 50% < the 60% threshold
	_tick(120)  # the shift (1.5 s)
	ctx.check(_boss.logic.phase() == 2,
			"boss: the phase-2 shift at 60%")
	ctx.check(String(_boss._label.text).contains("She keeps us all"),
			"boss: the phase-2 line (CHARACTER_BIBLE §8 #6 = M2.3)")
	ctx.check(_reveals.size() == 1
			and _reveals[0] == &"m2_first",
			"boss: the M2.3 stage reveal is wired (signal)")
	# The reveal is GATED by the run (RUN 05+, MYSTERY_REVEAL_MAP):
	# the scene is RUN 1 — the flag must NOT have landed yet.
	ctx.check(not _main.progress.ws.flag(&"the_first_seen"),
			"boss: the M2.3 stage waits for its run (RUN 05+)")
	_minion = _main.zone_world.level.find_child("BossMinion",
			true, false)
	ctx.check(_minion != null,
			"boss: the Remnant of the best run joins (phase 2)")
	if _minion != null:
		_ticks.append(_minion)
		var md: Resource = _minion.data()
		ctx.check(int(md.health) == 80,
				"boss: the minion has the boss data's health (80)")
		ctx.check(float(md.attack.damage) == 15.0,
				"boss: the minion deals the boss data's damage (15)")
		# Half hp -> it LEAVES (not a kill, BOSS_DESIGN §3.4).
		var req: _DREQ = _DREQ.new()
		req.source = _player
		req.target = _minion
		req.amount = 45.0
		req.type = _DREQ.Type.MELEE
		req.position = _minion.global_position
		_main.resolver.resolve(req)
		_tick(30)
		ctx.check(_minion.logic().state() == _EST.State.LEAVE,
				"boss: at half hp the minion leaves (no kill record)")


# --- 7. The FIRST BLADE (take) -------------------------------------------

func _test_first_blade(ctx: Variant) -> void:
	_player.combat.hp = 100.0  # the fight deals ~80 total
	var o: Vector3 = _arena_origin()
	var pickup: Node = _main.zone_world.level.find_child(
			"WeaponPickup_first_blade", true, false)
	ctx.check(pickup != null, "blade: the pickup is still waiting")
	if pickup == null:
		return
	# Stand 1 m in front of the pickup (the player faces -Z).
	_teleport(Vector3(pickup.global_position.x, 0.0,
			pickup.global_position.z + 1.0))
	var ia: Node = pickup.find_child("IA_pickup_weapon_first_blade",
			true, false)
	_ticks.append(ia)
	Input.action_press("interact")
	_tick(10)
	Input.action_release("interact")
	_tick(10)
	_ticks.erase(ia)
	ctx.check(_main.loadout.has(&"weapon_first_blade"),
			"blade: the FIRST BLADE entered the loadout")
	ctx.check(_main.progress.ws.is_weapon_found(&"weapon_first_blade"),
			"blade: the find is permanent (world state)")
	ctx.check(_main.progress.ws.flag(&"first_blade_taken"),
			"blade: the first_blade_taken flag (the world choice)")
	ctx.check(String(_boss._label.text).contains("that was mine"),
			"blade: his line on it (CHARACTER_BIBLE §8 #5)")
	ctx.check(_main.director.respects_first_blade(),
			"blade: the Echoes respect the First Blade (no first hit)")


# --- 8. The death sequence (K6) -------------------------------------------

func _test_death_sequence(ctx: Variant) -> void:
	_player.combat.hp = 100.0  # the fight deals ~80 total
	var req: _DREQ = _DREQ.new()
	req.source = _player
	req.target = _boss
	req.amount = 1000.0
	req.type = _DREQ.Type.MELEE
	req.position = _boss.global_position
	_main.resolver.resolve(req)
	_tick(60)
	ctx.check(_boss.logic.state == _BST.State.DEATH_DISSOLVE,
			"boss: the death dissolve begins (K6)")
	ctx.check(String(_boss._label.text).contains("don't make me proud"),
			"boss: the death line (CHARACTER_BIBLE §8 #9)")
	_tick(200)  # the dissolve (3 s)
	ctx.check(_boss.logic.state == _BST.State.DEATH_FINAL,
			"boss: the final line (K6's seed)")
	ctx.check(String(_boss._label.text).contains("let them go"),
			"boss: the final line (CHARACTER_BIBLE §8 #10)")
	_tick(160)  # the final line's window (2 s)
	ctx.check(_boss.logic.state == _BST.State.DEFEATED,
			"boss: THE FIRST is defeated")
	ctx.check(_defeated_count == 1,
			"boss: the defeated signal fired exactly once")
	ctx.check(_main.progress.ws.flag(&"boss_defeated"),
			"boss: the boss_defeated flag (K7 + the door)")
	# Phase 14: the seal + the final scene (the Ending, the door).
	ctx.check(_main.audio.current_variation()
			== _main.audio._DIR.Variation.ENDING,
			"boss: the final scene plays the ENDING variation")
	# The gate rule (BOSS_DESIGN §2.1): the deep mine + 3 deaths +
	# the first traces -> the door opens (in the test scene the
	# world facts are the ones the fight required to be met).
	_main.progress.ws.set_flag(&"mine_level_3_explored")
	_main.progress.ws.set_flag(&"first_traces_seen")
	ctx.check(_main.boss_gate.should_open(_main.progress.ws, 3),
			"boss: the gate rule opens the Undercroft door")
	# And the door is one-shot: the flag, once set, stays set.
	_main.progress.ws.set_flag(&"boss_door_open")
	ctx.check(_main.boss_gate.should_open(_main.progress.ws, 0),
			"boss: once open, always open (the world remembers)")
