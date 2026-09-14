# WeaponLogic — pure, deterministic melee-combo + special state machine
# (the combat twin of PlayerMovementLogic: no Node, no Input, no physics).
#
# The owning WeaponController feeds (delta) via update() and reads the
# phase/getters. All timing comes from WeaponData, so retuning or adding
# weapons (cannon/staff archetypes, Phases 6–8) is data work.
#
# Combo model (WEAPON_DESIGN §0/§1.3): a press starts/continues a swing.
# - press during a swing: buffered, the next hit starts when the current
#   one ends;
# - press while idle within `combo_window` after a swing: continues the
#   combo (U1 -> U2 -> U3);
# - press after the window: restarts at U1.
# The special (BLADE: Riposte) cancels a recovery, opens a counter
# window; cooldown starts on activation.
class_name WeaponLogic
extends RefCounted

const _DATA = preload("res://scripts/gameplay/combat/weapon_data.gd")
const _HIT = preload("res://scripts/gameplay/combat/weapon_hit.gd")

enum Phase { IDLE, WINDUP, ACTIVE, RECOVERY, RIPOSTE }

const EV_HIT_STARTED := "hit_started"
const EV_HIT_ENDED := "hit_ended"
const EV_RIPOSTE_STARTED := "riposte_started"
const EV_RIPOSTE_MISSED := "riposte_missed"

var _data: _DATA
var _phase: int = Phase.IDLE
var _hit_index: int = 0
var _phase_elapsed: float = 0.0
var _buffered: bool = false
var _combo_index: int = -1  # last performed hit (-1 = none)
var _combo_window_left: float = 0.0
var _riposte_cd: float = 0.0
var _riposte_window_elapsed: float = 0.0


func _init(data: _DATA) -> void:
	_data = data


# Full state reset (player respawn: no combo/CD leaks across deaths).
func reset() -> void:
	_phase = Phase.IDLE
	_hit_index = 0
	_phase_elapsed = 0.0
	_buffered = false
	_combo_index = -1
	_combo_window_left = 0.0
	_riposte_cd = 0.0
	_riposte_window_elapsed = 0.0


# request_attack returns: -1 rejected, 0 buffered (no new swing),
# 1 a new swing started.
func request_attack() -> int:
	if _phase == Phase.RIPOSTE:
		return -1
	if _phase == Phase.IDLE:
		if _data.hits.is_empty():
			return -1
		start_hit(_next_combo_index())
		return 1
	_buffered = true
	return 0


# request_special (BLADE: Riposte). Allowed from IDLE or RECOVERY.
func request_special() -> bool:
	if _riposte_cd > 0.0 or _data.special_name == &"":
		return false
	if _phase != Phase.IDLE and _phase != Phase.RECOVERY:
		return false
	_phase = Phase.RIPOSTE
	_phase_elapsed = 0.0
	_riposte_window_reset()
	_riposte_cd_start()
	_buffered = false
	return true


# Controller confirms a successful counter (damage landed in the window).
func end_riposte() -> void:
	if _phase == Phase.RIPOSTE:
		_phase = Phase.IDLE
		_riposte_window_reset()


# Abort the in-progress swing (controller: not enough stamina at swing
# start). Combo resets.
func cancel_hit() -> void:
	if _phase == Phase.WINDUP or _phase == Phase.ACTIVE:
		_phase = Phase.IDLE
		_phase_elapsed = 0.0
		_buffered = false
		_combo_index = -1
		_combo_window_left = 0.0


func update(delta: float) -> Array[String]:
	var events: Array[String] = []
	if _riposte_cd > 0.0:
		_riposte_cd_tick(delta)
	match _phase:
		Phase.IDLE:
			_combo_window_left = maxf(0.0, _combo_window_left - delta)
		Phase.WINDUP:
			_phase_elapsed += delta
			if _phase_elapsed >= _current_hit().windup:
				_phase = Phase.ACTIVE
				_phase_elapsed = 0.0
		Phase.ACTIVE:
			_phase_elapsed += delta
			if _phase_elapsed >= _current_hit().active:
				_phase = Phase.RECOVERY
				_phase_elapsed = 0.0
		Phase.RECOVERY:
			_phase_elapsed += delta
			if _phase_elapsed >= _current_hit().recovery:
				events.append(EV_HIT_ENDED)
				_phase = Phase.IDLE
				_phase_elapsed = 0.0
				var next: int = _hit_index + 1
				if _buffered and next < _data.hits.size():
					_buffered = false
					start_hit(next)
					events.append(EV_HIT_STARTED)
				elif _hit_index >= _data.hits.size() - 1:
					# Combo finished: no continuation.
					_combo_index = -1
					_combo_window_left = 0.0
				else:
					_combo_window_left = _data.combo_window
		Phase.RIPOSTE:
			_phase_elapsed += delta
			if _phase_elapsed >= _data.special_window:
				_phase = Phase.IDLE
				_riposte_window_reset()
				events.append(EV_RIPOSTE_MISSED)
	return events


# --- Getters (controller/tests) ---

func phase() -> int:
	return _phase


func hit_index() -> int:
	return _hit_index


# The hit currently in windup/active/recovery (null otherwise).
func current_hit() -> _HIT:
	if _phase == Phase.WINDUP or _phase == Phase.ACTIVE \
			or _phase == Phase.RECOVERY:
		return _data.hits[_hit_index]
	return null


func is_active() -> bool:
	return _phase == Phase.ACTIVE


func is_in_riposte_window() -> bool:
	return _phase == Phase.RIPOSTE


func riposte_cd_remaining() -> float:
	return _riposte_cd


# Stamina cost of the swing a fresh request would start (0 if a press
# would only buffer).
func pending_stamina_cost() -> int:
	if _phase != Phase.IDLE:
		return 0
	var idx: int = _next_combo_index()
	return _data.hits[idx].stamina_cost


# --- Internals ---

func start_hit(index: int) -> void:
	_hit_index = index
	_combo_index = index
	_phase = Phase.WINDUP
	_phase_elapsed = 0.0


func _next_combo_index() -> int:
	if _combo_index >= 0 and _combo_index + 1 < _data.hits.size() \
			and _combo_window_left > 0.0:
		return _combo_index + 1
	return 0


func _current_hit() -> _HIT:
	return _data.hits[_hit_index]


func _riposte_window_reset() -> void:
	_riposte_window_elapsed = 0.0


func _riposte_cd_start() -> void:
	_riposte_cd = _data.special_cooldown


func _riposte_cd_tick(delta: float) -> void:
	_riposte_cd = maxf(0.0, _riposte_cd - delta)
