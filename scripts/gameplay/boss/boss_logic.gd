# BossLogic — THE FIRST's state machine (BOSS_DESIGN §3). Pure logic
# (RefCounted, no scene — the EnemyLogic pattern): the controller
# feeds position/damage, the logic emits events.
#
# States: IDLE (kite/approach) -> TELE_MELEE/ACTIVE_MELEE ->
# TELE_SLAM/ACTIVE_SLAM -> CORE_WINDOW (the seal glows) -> IDLE.
# Special: LOOK (he learned), PARRY (blocks + counter), STUN (he lost
# the rhythm), PHASE_SHIFT (60%), DEATH (K6: the dissolve sequence).
#
# Events (strings; the controller shows them):
#   "attack_melee" / "attack_slam"  — a landed swing (the controller
#        checks the player's range and applies the damage);
#   "core_window_open" / "core_window_close" — the seal is hittable;
# The pattern-memory outcomes are controller-decided (it calls
# enter_look / enter_parry / parry_swing / apply_break_stun on
# its own events) — they are not tick events.
#   "phase2" — the 60% transition (line #6, the arena changes);
#   "death_start" — line #9 + the dissolve (3 s);
#   "death_final" — line #10 (the 2 s of silence);
#   "defeated" — the sequence is over (boss_defeated lands).
class_name BossLogic
extends RefCounted

const _DATA = preload("res://scripts/gameplay/boss/boss_data.gd")
const _SENSE = preload("res://scripts/gameplay/boss/boss_sense.gd")

enum State {
	IDLE,
	TELE_MELEE,
	ACTIVE_MELEE,
	TELE_SLAM,
	ACTIVE_SLAM,
	CORE_WINDOW,
	LOOK,
	PARRY,
	STUN,
	PHASE_SHIFT,
	DEATH_DISSOLVE,
	DEATH_FINAL,
	DEFEATED,
}

const EPS: float = 1e-4
const PHASE_SHIFT_TIME: float = 1.5

var _data: _DATA
var _max_hp: float = 600.0
var _hp: float = 600.0

var state: int = State.IDLE
var _elapsed: float = 0.0

var _melee_cd: float = 0.0
var _melee_since_slam: int = 0
var _slam_cd: float = 0.0
var _core_left: float = 0.0
var _core_open: bool = false
var _parry_left: float = 0.0
var _parry_used: bool = false
var _blade: bool = false
var _phase: int = 1
var _next_slam: bool = false  # test seam (deterministic fights)
var _defeated_emitted: bool = false


func setup(p_data: _DATA) -> void:
	_data = p_data
	_max_hp = float(p_data.health)
	_hp = _max_hp


func hp() -> float:
	return _hp


func phase() -> int:
	return _phase


func is_dead() -> bool:
	return _hp <= 0.0


func is_defeated_done() -> bool:
	return state == State.DEFEATED


func core_window_active() -> bool:
	return _core_open


func parry_active() -> bool:
	return state == State.PARRY and _parry_left > 0.0


func stunned() -> bool:
	return state == State.STUN


func set_blade(held: bool) -> void:
	_blade = held


func force_next_slam(v: bool = true) -> void:
	_next_slam = v


# The controller pushes the resolver's hp after each hit (the logic
# owns the phase/death decisions on the value it is given).
func set_hp(value: float) -> void:
	if state >= State.DEATH_DISSOLVE:
		return
	_hp = maxf(0.0, value)
	# Death BEFORE the phase check (hp 0 is both — he dies, he does
	# not "shift").
	if _hp <= 0.0:
		_enter(State.DEATH_DISSOLVE)
		return
	if _phase == 1 and _hp <= _max_hp * _data.phase2_threshold \
			and state != State.PHASE_SHIFT:
		_enter(State.PHASE_SHIFT)


# One tick. `home` = the arena center (the seal's position): the
# logic does not move — the controller steers; the logic only decides
# states and attacks.
func tick(delta: float, sense: _SENSE, home: Vector2) -> Array:
	var events: Array = []
	_elapsed += delta
	_melee_cd = maxf(0.0, _melee_cd - delta)
	_slam_cd = maxf(0.0, _slam_cd - delta)
	if _core_open:
		_core_left -= delta
		if _core_left <= 0.0:
			_core_open = false
			events.append("core_window_close")

	match state:
		State.IDLE:
			_try_attack(sense, home, events)
		State.TELE_MELEE:
			if _elapsed >= _data.melee.windup - EPS:
				_enter(State.ACTIVE_MELEE)
				events.append("state_changed")
				events.append("attack_melee")
		State.ACTIVE_MELEE:
			if _elapsed >= _data.melee.active - EPS:
				_enter(State.IDLE)
				events.append("state_changed")
		State.TELE_SLAM:
			if _elapsed >= _data.slam.windup - EPS:
				_enter(State.ACTIVE_SLAM)
				events.append("state_changed")
				events.append("attack_slam")
		State.ACTIVE_SLAM:
			if _elapsed >= _data.slam.active - EPS:
				# The core window opens AFTER the slam (BOSS_DESIGN
				# §3.3): the seal glows, the arena waits.
				_open_core_window(events)
				events.append("state_changed")
		State.CORE_WINDOW:
			if _core_left <= 0.0:
				_enter(State.IDLE)
				events.append("state_changed")
		State.LOOK:
			if _elapsed >= _data.look_time - EPS:
				_enter(State.IDLE)
				events.append("state_changed")
		State.PARRY:
			_parry_left -= delta
			if _parry_left <= 0.0:
				_enter(State.IDLE)
				events.append("state_changed")
		State.STUN:
			if _elapsed >= _data.break_stun - EPS:
				_enter(State.IDLE)
				events.append("state_changed")
		State.PHASE_SHIFT:
			if _elapsed >= PHASE_SHIFT_TIME - EPS:
				_phase = 2
				_enter(State.IDLE)
				events.append("state_changed")
		State.DEATH_DISSOLVE:
			if _elapsed >= _data.dissolve_time - EPS:
				_enter(State.DEATH_FINAL)
				events.append("death_final")
		State.DEATH_FINAL:
			if _elapsed >= _data.final_line_delay - EPS:
				_enter(State.DEFEATED)
				events.append("defeated")
	# The controller reads the public state for steering/visuals.
	state = state
	return events


func _enter(s: int) -> void:
	state = s
	_elapsed = 0.0
	match s:
		State.TELE_MELEE:
			_melee_cd = _data.melee.windup + _data.melee.active \
					+ _data.melee.recovery
			# The cd floor (the design value).
			_melee_cd = maxf(_melee_cd, 1.2)
		State.TELE_SLAM:
			_slam_cd = _data.slam.windup + _data.slam.active \
					+ _data.slam.recovery
			_slam_cd = maxf(_slam_cd, 4.0)
		State.PHASE_SHIFT:
			pass
		State.PARRY:
			_parry_left = _data.parry_window
			_parry_used = false


func _try_attack(sense: _SENSE, home: Vector2, events: Array) -> void:
	if not sense.player_present:
		return
	var d: float = sense.player_pos.distance_to(home)
	# The boss fights from the arena: he approaches to the melee band
	# (the controller does the walking; the logic only decides WHEN).
	# Deterministic mix (no RNG state): three melees, then the slam
	# when its cd is ready (the cd paces it at ~4 s).
	var want_slam: bool = _next_slam or _melee_since_slam >= 3
	if want_slam and _slam_cd <= 0.0 and d <= _data.slam.range:
		_next_slam = false
		_melee_since_slam = 0
		_enter(State.TELE_SLAM)
		events.append("state_changed")
		return
	if _melee_cd <= 0.0 and d <= _data.melee.range:
		_melee_since_slam += 1
		_enter(State.TELE_MELEE)
		events.append("state_changed")


func _open_core_window(events: Array) -> void:
	_core_open = true
	_core_left = _data.core_window_blade if _blade else _data.core_window
	_enter(State.CORE_WINDOW)
	events.append("core_window_open")


# A player swing that lands on the seal DURING the window. Returns
# true if it was a core hit (the controller applies the damage).
func core_hit() -> bool:
	if not _core_open:
		return false
	_core_open = false
	_enter(State.IDLE)
	return true


# The pattern memory learned a sequence: the 0.3 s "look" (the
# signal he has it).
func enter_look() -> void:
	if state != State.IDLE:
		return
	_enter(State.LOOK)


# The parry arms (pattern completed again): the next player swing
# inside the window is blocked (the controller sets invulnerable) +
# his counter.
func enter_parry() -> void:
	if state != State.IDLE:
		return
	_enter(State.PARRY)


# The player swung during the parry window (once). The counter
# fires; the BLOCK holds for the whole window — the triggering
# swing's active phase is still in flight (windup after the
# swing_started), and the window is the readable "he blocked".
func parry_swing() -> bool:
	if state != State.PARRY or _parry_used or _parry_left <= 0.0:
		return false
	_parry_used = true
	return true


# Three "not his" steps: he loses the rhythm (vulnerable stun).
func apply_break_stun() -> void:
	if state == State.DEATH_DISSOLVE or state == State.DEATH_FINAL \
			or state == State.DEFEATED:
		return
	_enter(State.STUN)
