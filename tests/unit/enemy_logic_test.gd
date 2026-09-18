# Unit: EnemyLogic — the pure FSM of all 5 archetypes.
#
# Driven with a manual clock (rig contract, ADR-022 item 11). The
# enemy's position is advanced like the controller does (move toward
# the target at data.speed), so the timing is exactly the design's.
extends Node

const _DATA = preload("res://scripts/gameplay/enemies/enemy_data.gd")
const _ATTACK = preload("res://scripts/gameplay/enemies/attack_data.gd")
const _LOGIC = preload("res://scripts/gameplay/enemies/enemy_logic.gd")
const _SENSE = preload("res://scripts/gameplay/enemies/enemy_sense.gd")
const _ST = preload("res://scripts/gameplay/enemies/enemy_state.gd")
const _STYLE = preload("res://scripts/gameplay/memory_stats.gd")

const DT: float = 1.0 / 60.0
const HOME: Vector2 = Vector2.ZERO


func run(ctx: Variant) -> void:
	_hollow(ctx)
	_hollow_leash_retreat(ctx)
	_hurt(ctx)
	_death(ctx)
	_remnant_first_encounter(ctx)
	_remnant_kite(ctx)
	_watcher(ctx)
	_mimic(ctx)
	_forgotten(ctx)


# --- Helpers ---

func _sense(pos: Vector3, seen: bool = true, noise: bool = false,
		eye: bool = false) -> _SENSE:
	var s: _SENSE = _SENSE.new()
	s.player_position = pos
	s.player_seen = seen
	s.player_noise = noise
	s.eye_line = eye
	return s


# One controller-like tick: advance the enemy toward `target` at
# `speed`, then run the logic. Returns the events.
func _step(l: _LOGIC, target: Vector2, speed: float,
		sense: _SENSE, ctx_pos: Vector2) -> Array[String]:
	if target != Vector2.INF:
		var dir: Vector2 = (target - ctx_pos).normalized()
		var d: float = ctx_pos.distance_to(target)
		var step: float = minf(speed * DT, d)
		l.set_position(ctx_pos.x + dir.x * step,
				ctx_pos.y + dir.y * step)
	else:
		l.set_position(ctx_pos.x, ctx_pos.y)
	return l.update(DT, sense, HOME)


func _ticks(l: _LOGIC, n: int, sense: _SENSE) -> Array[String]:
	var all: Array[String] = []
	for i in n:
		all.append_array(l.update(DT, sense, HOME))
	return all


# --- 1. Hollow: chase -> windup -> hit -> recovery -> chase ---

func _hollow(ctx: Variant) -> void:
	var d: _DATA = load("res://data/enemies/hollow_base.tres")
	var l: _LOGIC = _LOGIC.new(d, 1)
	var pos: Vector2 = HOME
	var sense: _SENSE = _sense(Vector3(8, 0, 0))
	var ev: Array[String] = _step(l, Vector2(8, 0), d.speed, sense, pos)
	pos = l.get_pos()
	ctx.check(l.state() == _ST.State.CHASE
			and ev.has(_LOGIC.EV_STATE_CHANGED),
			"enemy_logic: hollow chases on sight")

	# Close in at data.speed until the logic winds up (range 1.8).
	var i: int = 0
	while l.state() != _ST.State.WINDUP and i < 400:
		_step(l, Vector2(8, 0), d.speed, _sense(Vector3(8, 0, 0)), pos)
		pos = l.get_pos()
		i += 1
	ctx.check(l.state() == _ST.State.WINDUP,
			"enemy_logic: hollow winds up at attack range")

	# One full cycle from WINDUP: 30 windup + 9 active + 81 recovery
	# ticks = 120 -> back to CHASE (the data's cd, 2.0 s).
	var all: Array[String] = _ticks(l, 120, _sense(Vector3(8, 0, 0)))
	var hits: int = all.count(_LOGIC.EV_ATTACK_HIT)
	ctx.check(hits == 1,
			"enemy_logic: exactly one attack hit per cycle (got %d)"
					% hits)
	ctx.check(all.size() >= 4,
			"enemy_logic: full cycle produced the transitions")
	# After recovery the enemy chases again (player still in aggro).
	ctx.check(l.state() == _ST.State.CHASE,
			"enemy_logic: hollow returns to chase after recovery")


# --- 2. Hollow: leash + retreat ---

func _hollow_leash_retreat(ctx: Variant) -> void:
	var d: _DATA = load("res://data/enemies/hollow_base.tres")
	# Leash: the player is out of the aggro radius (12).
	var l: _LOGIC = _LOGIC.new(d, 2)
	var ev: Array[String] = l.update(DT,
			_sense(Vector3(20, 0, 0)), HOME)
	ctx.check(l.state() == _ST.State.CHASE,
			"enemy_logic: leash test starts in chase")
	ev = _ticks(l, 1, _sense(Vector3(20, 0, 0)))
	ctx.check(l.state() == _ST.State.IDLE,
			"enemy_logic: hollow leashes at aggro radius")

	# Retreat: the player hides just out of sight (11 m), in aggro.
	l = _LOGIC.new(d, 3)
	l.update(DT, _sense(Vector3(8, 0, 0)), HOME)  # -> CHASE
	# Out of sight at 11 m: 5 s (retreat_after) -> RETREAT at tick 300.
	var evs: Array[String] = _ticks(l, 300, _sense(Vector3(11, 0, 0),
			false))
	ctx.check(l.state() == _ST.State.RETREAT
			and evs.has(_LOGIC.EV_STATE_CHANGED),
			"enemy_logic: retreat triggered after 5 s of fleeing")
	evs = _ticks(l, 120, _sense(Vector3(11, 0, 0), false))
	ctx.check(l.state() == _ST.State.IDLE,
			"enemy_logic: retreat ends after 2 s -> IDLE")

	# Hearing: noise within hear_range wakes the idle hollow.
	l = _LOGIC.new(d, 5)
	evs = _ticks(l, 1, _sense(Vector3(15, 0, 0), false, true))
	ctx.check(l.state() == _ST.State.IDLE,
			"enemy_logic: noise beyond hear_range is ignored")
	evs = _ticks(l, 1, _sense(Vector3(4, 0, 0), false, true))
	ctx.check(l.state() == _ST.State.CHASE,
			"enemy_logic: noise within hear_range wakes it")


# --- 3. Hitstun interrupts; committed states don't flinch ---

func _hurt(ctx: Variant) -> void:
	var d: _DATA = load("res://data/enemies/hollow_base.tres")
	var l: _LOGIC = _LOGIC.new(d, 6)
	l.update(DT, _sense(Vector3(8, 0, 0)), HOME)  # -> CHASE
	ctx.check(l.interrupt_hurt(), "enemy_logic: chase is interruptible")
	ctx.check(l.state() == _ST.State.HURT, "enemy_logic: now HURT")
	var evs: Array[String] = _ticks(l, 24, _sense(Vector3(8, 0, 0)))
	ctx.check(l.state() == _ST.State.CHASE
			and evs.has(_LOGIC.EV_STATE_CHANGED),
			"enemy_logic: hitstun (0.4 s) returns to chase")

	# Mid-windup: the flinch resets the telegraph (classic stagger).
	# IDLE -> CHASE (tick 1) -> WINDUP at range (tick 2).
	l = _LOGIC.new(d, 7)
	l.update(DT, _sense(Vector3(1.5, 0, 0)), HOME)
	l.update(DT, _sense(Vector3(1.5, 0, 0)), HOME)
	ctx.check(l.state() == _ST.State.WINDUP,
			"enemy_logic: hurt test in windup")
	ctx.check(l.interrupt_hurt(), "enemy_logic: windup is interruptible")
	evs = _ticks(l, 24, _sense(Vector3(1.5, 0, 0)))
	ctx.check(l.state() == _ST.State.WINDUP,
			"enemy_logic: stagger rewinds the telegraph")

	# Committed: ACTIVE never flinches.
	l = _LOGIC.new(d, 8)
	l.update(DT, _sense(Vector3(1.5, 0, 0)), HOME)  # -> CHASE
	l.update(DT, _sense(Vector3(1.5, 0, 0)), HOME)  # -> WINDUP
	_ticks(l, 30, _sense(Vector3(1.5, 0, 0)))  # -> ACTIVE (30 ticks)
	ctx.check(l.state() == _ST.State.ACTIVE,
			"enemy_logic: committed test in active")
	ctx.check(not l.interrupt_hurt(),
			"enemy_logic: active swing is committed (no flinch)")
	ctx.check(l.state() == _ST.State.ACTIVE,
			"enemy_logic: the committed swing continues")


# --- 4. Death: dissolve time, then the death event (once) ---

func _death(ctx: Variant) -> void:
	var d: _DATA = load("res://data/enemies/hollow_base.tres")
	var l: _LOGIC = _LOGIC.new(d, 9)
	l.die()
	ctx.check(l.is_dead(), "enemy_logic: die() enters DEATH")
	var evs: Array[String] = _ticks(l, 17, _sense(Vector3(8, 0, 0)))
	ctx.check(not evs.has(_LOGIC.EV_DEATH),
			"enemy_logic: no death event before the dissolve")
	evs = _ticks(l, 2, _sense(Vector3(8, 0, 0)))
	ctx.check(evs.count(_LOGIC.EV_DEATH) == 1,
			"enemy_logic: death event at 0.3 s (dissolve)")
	evs = _ticks(l, 60, _sense(Vector3(8, 0, 0)))
	ctx.check(evs.count(_LOGIC.EV_DEATH) == 0,
			"enemy_logic: the death event fires exactly once")

	# The Forgotten dissolves 10x slower (3 s).
	var f: _DATA = load("res://data/enemies/forgotten_wanderer.tres")
	l = _LOGIC.new(f, 10)
	l.die()
	evs = _ticks(l, 179, _sense(Vector3(50, 0, 0)))
	ctx.check(not evs.has(_LOGIC.EV_DEATH),
			"enemy_logic: forgotten still dissolving at 3 s - 1 tick")
	evs = _ticks(l, 1, _sense(Vector3(50, 0, 0)))
	ctx.check(evs.has(_LOGIC.EV_DEATH),
			"enemy_logic: forgotten death at 3 s")


# --- 5. Remnant: first encounter speaks and leaves ---

func _remnant_first_encounter(ctx: Variant) -> void:
	var d: _DATA = load("res://data/enemies/remnant_mirror.tres")
	var l: _LOGIC = _LOGIC.new(d, 11)
	l.first_encounter = true
	var evs: Array[String] = _ticks(l, 1, _sense(Vector3(8, 0, 0)))
	ctx.check(l.state() == _ST.State.SPEAK,
			"enemy_logic: remnant speaks on first encounter")
	ctx.check(l.last_speech == d.first_encounter_lines[0],
			"enemy_logic: first line is the canonical one: %s"
					% l.last_speech)
	# The full sequence (#1): line 1 holds 0.8 s, then line 2.
	evs = _ticks(l, 48, _sense(Vector3(8, 0, 0)))
	ctx.check(l.state() == _ST.State.SPEAK
			and l.last_speech == d.first_encounter_lines[1],
			"enemy_logic: the second line follows (0.8 s later): %s"
					% l.last_speech)
	evs = _ticks(l, 48, _sense(Vector3(8, 0, 0)))
	ctx.check(l.state() == _ST.State.LEAVE,
			"enemy_logic: remnant leaves after the full sequence")
	evs = _ticks(l, 60, _sense(Vector3(8, 0, 0)))
	ctx.check(evs.has(_LOGIC.EV_LEAVE),
			"enemy_logic: leave event despawns the remnant (1 s)")

	# Not a first encounter: it FIGHTS (chase), not speech.
	l = _LOGIC.new(d, 12)
	l.first_encounter = false
	evs = _ticks(l, 1, _sense(Vector3(8, 0, 0)))
	ctx.check(l.state() == _ST.State.CHASE,
			"enemy_logic: returning player -> remnant fights")


# --- 6. Remnant (ranged style): the kiting band ---

func _remnant_kite(ctx: Variant) -> void:
	var d: _DATA = (load("res://data/enemies/remnant_mirror.tres")
			as _DATA).duplicate(true)
	d.mirror_style = _STYLE.STYLE_RANGED
	var l: _LOGIC = _LOGIC.new(d, 13)
	l.update(DT, _sense(Vector3(8, 0, 0)), HOME)  # -> CHASE
	ctx.check(l.state() == _ST.State.CHASE,
			"enemy_logic: kite test in chase")
	# Inside the far band (6 m), outside the inner (2.5): holds.
	var evs: Array[String] = _ticks(l, 60, _sense(Vector3(5, 0, 0)))
	ctx.check(l.state() == _ST.State.CHASE,
			"enemy_logic: kiting remnant holds the band (no lunge)")
	# The player breaks inside: it strikes.
	evs = _ticks(l, 1, _sense(Vector3(2.0, 0, 0)))
	ctx.check(l.state() == _ST.State.WINDUP,
			"enemy_logic: kiting remnant strikes inside 2.5 m")


# --- 7. Watcher: observe -> anchor (<=2/run), follow -> vanish ---

func _watcher(ctx: Variant) -> void:
	var d: _DATA = load("res://data/enemies/watcher_base.tres")
	var l: _LOGIC = _LOGIC.new(d, 14)
	# Mutual eye-line for observe_time (2 s) -> anchor.
	var evs: Array[String] = _ticks(l, 1, _sense(
			Vector3(6, 0, 0), false, false, true))
	ctx.check(l.state() == _ST.State.OBSERVING,
			"enemy_logic: watcher enters OBSERVING on eye-line")
	# Eye-line breaks mid-observation: no anchor.
	evs = _ticks(l, 60, _sense(Vector3(6, 0, 0), false, false, true))
	evs = _ticks(l, 1, _sense(Vector3(6, 0, 0), false, false, false))
	ctx.check(l.state() == _ST.State.IDLE,
			"enemy_logic: broken eye-line cancels observation")
	ctx.check(l.anchors_created == 0,
			"enemy_logic: no anchor when the look is broken")
	# Full observation: anchor #1.
	l = _LOGIC.new(d, 15)
	l.anchors_created = 0
	evs = _ticks(l, 1, _sense(Vector3(6, 0, 0), false, false, true))
	evs = _ticks(l, 120, _sense(Vector3(6, 0, 0), false, false, true))
	ctx.check(l.anchors_created == 1,
			"enemy_logic: anchor created after 2 s of eye-line")
	ctx.check(Vector3(6, 0, 0).distance_to(l.anchor_position) < 0.01,
			"enemy_logic: the anchor stores the player position")
	# Anchor #2, then the run cap (2) holds.
	evs = _ticks(l, 1, _sense(Vector3(6, 0, 0), false, false, true))
	evs = _ticks(l, 120, _sense(Vector3(6, 0, 0), false, false, true))
	ctx.check(l.anchors_created == 2, "enemy_logic: second anchor")
	evs = _ticks(l, 1, _sense(Vector3(6, 0, 0), false, false, true))
	var before: int = l.anchors_created
	evs = _ticks(l, 120, _sense(Vector3(6, 0, 0), false, false, true))
	ctx.check(l.anchors_created == before,
			"enemy_logic: the <=2/run cap holds")

	# Follow, then vanish + teleport when the player leaves the range.
	l = _LOGIC.new(d, 16)
	evs = _ticks(l, 1, _sense(Vector3(8, 0, 0)))
	ctx.check(l.state() == _ST.State.FOLLOW,
			"enemy_logic: watcher follows inside follow range")
	evs = _ticks(l, 1, _sense(Vector3(13, 0, 0)))
	ctx.check(l.state() == _ST.State.VANISH,
			"enemy_logic: player beyond 12 m -> VANISH")
	evs = _ticks(l, 60, _sense(Vector3(13, 0, 0)))
	ctx.check(evs.has(_LOGIC.EV_TELEPORT),
			"enemy_logic: vanish teleports after 1 s")
	ctx.check(l.state() == _ST.State.IDLE,
			"enemy_logic: watcher re-idles after teleport")
	# The watcher never attacks: no WINDUP reachable (dmg = 0 data).
	ctx.check(l.state() != _ST.State.WINDUP,
			"enemy_logic: watcher does not attack in MVP")


# --- 8. Mimic: punish patterns per mirror style ---

func _mimic(ctx: Variant) -> void:
	# Combo-mirror: punish the player's 2nd+ swing telegraph.
	var mc: _DATA = load("res://data/enemies/mimic_combo.tres")
	var l: _LOGIC = _LOGIC.new(mc, 17)
	l.update(DT, _sense(Vector3(8, 0, 0)), HOME)  # -> CHASE
	l.set_position(0.0, 0.0)
	var s: _SENSE = _sense(Vector3(1.5, 0, 0))
	s.player_weapon_phase = 1  # WeaponLogic.WINDUP
	s.player_combo_index = 0
	ctx.check(not l.punish_due(s),
			"enemy_logic: mimic waits for the 2nd swing (combo 0)")
	s.player_combo_index = 1
	ctx.check(l.punish_due(s),
			"enemy_logic: mimic interrupts the combo (2nd swing)")
	s.player_weapon_phase = 2  # ACTIVE: the window closed
	ctx.check(not l.punish_due(s),
			"enemy_logic: no punish outside the telegraph window")

	# Dodge-mirror: punish the over-dodge.
	var md: _DATA = load("res://data/enemies/mimic_dodge.tres")
	l = _LOGIC.new(md, 18)
	l.update(DT, _sense(Vector3(8, 0, 0)), HOME)
	l.set_position(0.0, 0.0)
	s = _sense(Vector3(1.5, 0, 0))
	s.player_dodging = false
	ctx.check(not l.punish_due(s),
			"enemy_logic: dodge-mirror idle when the player stands")
	s.player_dodging = true
	ctx.check(l.punish_due(s),
			"enemy_logic: dodge-mirror punishes the over-dodge")
	s = _sense(Vector3(5, 0, 0))
	s.player_dodging = true
	ctx.check(not l.punish_due(s),
			"enemy_logic: dodge punish only within reach")

	# Range-mirror: speed pressure, no counter punish.
	var mr: _DATA = load("res://data/enemies/mimic_range.tres")
	l = _LOGIC.new(mr, 19)
	l.update(DT, _sense(Vector3(8, 0, 0)), HOME)
	l.set_position(0.0, 0.0)
	ctx.check(absf(l.speed_pressure() - 1.2) < 0.001,
			"enemy_logic: range-mirror pressures at 1.2x")
	s = _sense(Vector3(1.5, 0, 0))
	s.player_weapon_phase = 1
	s.player_combo_index = 2
	ctx.check(not l.punish_due(s),
			"enemy_logic: range-mirror kites, it does not counter")

	# The dodge-mirror is evasive while the player telegraphs.
	l = _LOGIC.new(md, 20)
	l.update(DT, _sense(Vector3(8, 0, 0)), HOME)
	ctx.check(l.is_evasive(), "enemy_logic: dodge-mirror is evasive")
	l = _LOGIC.new(mc, 21)
	l.update(DT, _sense(Vector3(8, 0, 0)), HOME)
	ctx.check(not l.is_evasive(),
			"enemy_logic: combo-mirror is not evasive")


# --- 9. Forgotten: wander + the slow lunge; the guard stands ---

func _forgotten(ctx: Variant) -> void:
	var f: _DATA = load("res://data/enemies/forgotten_wanderer.tres")
	var l: _LOGIC = _LOGIC.new(f, 22)
	var evs: Array[String] = _ticks(l, 1, _sense(Vector3(50, 0, 0)))
	ctx.check(l.state() == _ST.State.WANDER,
			"enemy_logic: forgotten wanderer wanders")
	# The player wanders close (sight 5 m): the slow lunge (1 s).
	l.set_position(0.0, 0.0)
	evs = _ticks(l, 1, _sense(Vector3(4, 0, 0)))
	ctx.check(l.state() == _ST.State.WINDUP,
			"enemy_logic: forgotten lunges at 4 m")
	evs = _ticks(l, 60, _sense(Vector3(4, 0, 0)))
	ctx.check(l.state() == _ST.State.ACTIVE,
			"enemy_logic: the slow swing lands after 1 s telegraph")
	evs = _ticks(l, 9, _sense(Vector3(4, 0, 0)))
	ctx.check(l.state() == _ST.State.RECOVERY,
			"enemy_logic: forgotten recovery after the swing")
	evs = _ticks(l, 111, _sense(Vector3(50, 0, 0)))
	ctx.check(l.state() == _ST.State.WANDER,
			"enemy_logic: the forgotten wanders on after 3 s cd")

	# Whisper: the history line on the 8 s interval.
	l = _LOGIC.new(f, 23)
	_ticks(l, 1, _sense(Vector3(50, 0, 0)))  # -> WANDER
	evs = _ticks(l, 480, _sense(Vector3(50, 0, 0)))
	ctx.check(evs.has(_LOGIC.EV_SPEECH),
			"enemy_logic: forgotten whispers on the 8 s interval")
	ctx.check(l.last_speech in f.whisper_pool,
			"enemy_logic: whisper comes from the pool: %s"
					% l.last_speech)

	# The guard: no wander — it stands and strikes from stillness.
	var g: _DATA = load("res://data/enemies/forgotten_guard.tres")
	l = _LOGIC.new(g, 24)
	evs = _ticks(l, 1, _sense(Vector3(4, 0, 0)))
	ctx.check(l.state() == _ST.State.WINDUP,
			"enemy_logic: the guard strikes from stillness")
	evs = _ticks(l, 48, _sense(Vector3(4, 0, 0)))
	ctx.check(l.state() == _ST.State.ACTIVE,
			"enemy_logic: the guard telegraphs 0.8 s")


# --- Internals ---

func _find(arr: Array[String], needle: String) -> int:
	for i in range(arr.size()):
		if arr[i] == needle:
			return i
	return -1
