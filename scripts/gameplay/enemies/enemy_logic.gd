# EnemyLogic — pure, deterministic enemy state machine (the combat
# twin of PlayerMovementLogic / WeaponLogic: no Node, no Input, no
# physics — the EnemyController feeds sense + home + position and
# executes the events it returns).
#
# 5 archetypes, one machine (ENEMY_DESIGN §0): common core
# (IDLE/CHASE/WINDUP/ACTIVE/RECOVERY/HURT/DEATH) + archetype states
# (OBSERVING/FOLLOW/VANISH — Watcher; WANDER — Forgotten; RETREAT —
# Hollow; SPEAK/LEAVE — Remnant first encounter). All timing comes
# from EnemyData.
#
# Determinism: wandering/speech picks use an internal seeded RNG
# (unit tests are reproducible).
class_name EnemyLogic
extends RefCounted

const _DATA = preload("res://scripts/gameplay/enemies/enemy_data.gd")
const _SENSE = preload("res://scripts/gameplay/enemies/enemy_sense.gd")
const _ST = preload("res://scripts/gameplay/enemies/enemy_state.gd")
const _STYLE = preload("res://scripts/gameplay/memory_stats.gd")

const EV_STATE_CHANGED := "state_changed"
const EV_ATTACK_HIT := "attack_hit"
const EV_SPEECH := "speech"
const EV_ANCHOR := "anchor"
const EV_LEAVE := "leave"
const EV_TELEPORT := "teleport"
const EV_DEATH := "death"

# FP tolerance for accumulated-tick boundaries (the Phase 4 hitstop
# lesson: repeated += of 1/60 never lands exactly on the design value).
const EPS: float = 1e-4

const RETREAT_RETURN_TIME: float = 2.0  # RETREAT -> IDLE
const SPEAK_TIME: float = 0.8
const VANISH_TIME: float = 1.0
const WHISPER_INTERVAL: float = 8.0  # Forgotten: between whispers
# Remnant (ranged style) kiting band: backs off below KITE_FAR,
# strikes if the player breaks inside KITE_INNER.
const KITE_FAR: float = 6.0
const KITE_INNER: float = 2.5

var _data: _DATA
var _state: int = _ST.State.IDLE
var _elapsed: float = 0.0  # time in the current state
var _hurt_from: int = _ST.State.IDLE
var _retreat_time: float = 0.0
var _soothe_time: float = 0.0
var _death_done: bool = false
var _whisper_timer: float = WHISPER_INTERVAL
var _whisper_pool_index: int = 0
var _wander_target: Vector2 = Vector2.ZERO
var _home: Vector2 = Vector2.ZERO
var _pos_x: float = 0.0
var _pos_z: float = 0.0
var _player_phase_time: float = 0.0
var _prev_player_phase: int = -1

# Set at spawn (director/builder):
var first_encounter: bool = false   # Remnant: speaks and leaves
var _speech_idx: int = 0
var anchors_created: int = 0        # Watcher: run-wide count (director)

var last_speech: String = ""
var anchor_position: Vector3 = Vector3.ZERO

var _rng: RandomNumberGenerator


func _init(data: _DATA, seed: int = 0) -> void:
	_data = data
	_rng = RandomNumberGenerator.new()
	_rng.seed = seed


func state() -> int:
	return _state


# Time in the current state (the controller's dissolve fade).
func state_elapsed() -> float:
	return _elapsed


func is_dead() -> bool:
	return _state == _ST.State.DEATH


# The controller syncs its position (the pure logic has none of its
# own — wandering/leash math needs it).
func set_position(x: float, z: float) -> void:
	_pos_x = x
	_pos_z = z


func get_pos() -> Vector2:
	return Vector2(_pos_x, _pos_z)


# The controller calls when the resolver lands damage (not blocked).
# Returns true when the interrupt was accepted.
func interrupt_hurt() -> bool:
	if _state == _ST.State.DEATH or _state == _ST.State.HURT:
		return false
	if _state == _ST.State.ACTIVE or _state == _ST.State.VANISH:
		return false  # committed: the swing/teleport lands
	_hurt_from = _state
	if _state == _ST.State.SOOTHED:
		_hurt_from = _ST.State.IDLE  # damage breaks the sleep for good
	_enter(_ST.State.HURT)
	return true


# The controller calls when hp reaches 0 (uncancellable).
func die() -> void:
	if _state == _ST.State.DEATH:
		return
	_enter(_ST.State.DEATH)


func last_whisper() -> String:
	var pool: PackedStringArray = _data.whisper_pool
	return "" if pool.is_empty() else pool[0]


func _enter(s: int) -> void:
	_state = s
	_elapsed = 0.0
	if s == _ST.State.WANDER:
		_pick_wander_target(_home)
	elif s == _ST.State.SPEAK:
		_speech_idx = 0
		last_speech = _data.first_encounter_lines[0]


# Echo Staff Soothe (Phase 6): the enemy "sleeps" for `duration` — no
# combat, no movement. Damage wakes it (interrupt_hurt), the timer
# wakes it to IDLE (its senses re-aggro naturally).
func apply_soothe(duration: float) -> bool:
	if _state == _ST.State.DEATH or _state == _ST.State.HURT:
		return false
	_soothe_time = maxf(0.0, duration)
	if _state == _ST.State.SOOTHED:
		_elapsed = 0.0  # refresh the sleep
		return true
	_enter(_ST.State.SOOTHED)
	return true


# One tick. `home` = the spawn point (xz). Returns the event list.
func update(delta: float, sense: _SENSE, home: Vector2) -> Array[String]:
	var events: Array[String] = []
	_home = home
	_track_player_phase(sense, delta)
	_elapsed += delta

	match _state:
		_ST.State.DEATH:
			if _elapsed >= _data.dissolve_time - EPS and not _death_done:
				_death_done = true
				events.append(EV_DEATH)
		_ST.State.HURT:
			if _elapsed >= _data.hitstun - EPS:
				_enter(_hurt_from)
				events.append(EV_STATE_CHANGED)
		_ST.State.SOOTHED:
			# The staff's sleep: no combat, no senses — the timer ends
			# it (wake to IDLE: re-aggro is up to the senses again).
			if _elapsed >= _soothe_time - EPS:
				_enter(_ST.State.IDLE)
				events.append(EV_STATE_CHANGED)
		_ST.State.IDLE:
			_idle(sense, events)
		_ST.State.CHASE:
			_chase(sense, delta, events)
		_ST.State.WANDER:
			_wander(sense, delta, events)
		_ST.State.WINDUP:
			if _elapsed >= _data.attack.windup - EPS:
				_enter(_ST.State.ACTIVE)
				events.append(EV_STATE_CHANGED)
		_ST.State.ACTIVE:
			if _elapsed <= delta:
				events.append(EV_ATTACK_HIT)
			if _elapsed >= _data.attack.active - EPS:
				_enter(_ST.State.RECOVERY)
				events.append(EV_STATE_CHANGED)
		_ST.State.RECOVERY:
			if _elapsed >= _data.attack.recovery - EPS:
				_after_attack(sense, events)
		_ST.State.RETREAT:
			if _elapsed >= RETREAT_RETURN_TIME - EPS:
				_enter(_ST.State.IDLE)
				events.append(EV_STATE_CHANGED)
		_ST.State.OBSERVING:
			if not sense.eye_line:
				_enter(_ST.State.IDLE)
				events.append(EV_STATE_CHANGED)
			elif _elapsed >= _data.observe_time - EPS:
				anchor_position = sense.player_position
				if _data.archetype == _DATA.Archetype.WATCHER \
						and anchors_created < _data.anchors_per_run:
					anchors_created += 1
					events.append(EV_ANCHOR)
				_enter(_ST.State.IDLE)
				events.append(EV_STATE_CHANGED)
		_ST.State.FOLLOW:
			if sense.eye_line:
				_enter(_ST.State.OBSERVING)  # the look overrides the follow
				events.append(EV_STATE_CHANGED)
			elif _dist(sense) > _data.follow_range:
				_enter(_ST.State.VANISH)
				events.append(EV_STATE_CHANGED)
		_ST.State.VANISH:
			if _elapsed >= VANISH_TIME - EPS:
				events.append(EV_TELEPORT)  # the controller repositions
				_enter(_ST.State.IDLE)
				events.append(EV_STATE_CHANGED)
		_ST.State.SPEAK:
			# The full sequence, canonical order (#1): each line holds
			# SPEAK_TIME, then the next; the last line hands to LEAVE.
			var lines: PackedStringArray = _data.first_encounter_lines
			if _elapsed >= SPEAK_TIME - EPS:
				if _speech_idx + 1 < lines.size():
					_speech_idx += 1
					last_speech = lines[_speech_idx]
					_elapsed = 0.0
					events.append(EV_SPEECH)  # controller shows line N+1
				else:
					_enter(_ST.State.LEAVE)
					events.append(EV_STATE_CHANGED)
			elif _elapsed <= delta + EPS:
				events.append(EV_SPEECH)  # the first line
		_ST.State.LEAVE:
			if _elapsed >= _leave_time() - EPS:
				events.append(EV_LEAVE)  # the controller despawns
	return events


# Data-driven: the first-encounter remnant dissolves for leave_fade
# (ECHO_SYSTEM_DESIGN §3.2); everything else uses the 1 s default.
func _leave_time() -> float:
	return maxf(_data.leave_fade if _data.first_encounter_leaves
			else 1.0, 0.1)


# --- Archetype behaviors ---

func _idle(sense: _SENSE, events: Array[String]) -> void:
	match _data.archetype:
		_DATA.Archetype.WATCHER:
			if sense.eye_line:
				_enter(_ST.State.OBSERVING)
				events.append(EV_STATE_CHANGED)
			elif _dist(sense) <= _data.follow_range:
				_enter(_ST.State.FOLLOW)
				events.append(EV_STATE_CHANGED)
		_DATA.Archetype.FORGOTTEN:
			if _data.wander_radius > 0.0:
				_enter(_ST.State.WANDER)  # the wanderer lives in WANDER
				events.append(EV_STATE_CHANGED)
			elif _seen_or_heard(sense):
				_enter(_ST.State.WINDUP)  # the guard attacks still
				events.append(EV_STATE_CHANGED)
		_:
			if _seen_or_heard(sense):
				if _data.archetype == _DATA.Archetype.REMNANT \
						and first_encounter:
					_enter(_ST.State.SPEAK)
				else:
					_enter(_ST.State.CHASE)
				events.append(EV_STATE_CHANGED)


func _chase(sense: _SENSE, delta: float, events: Array[String]) -> void:
	var d: float = _dist(sense)
	# Remnant (ranged style): kite — hold the distance band; only
	# strikes if the player breaks inside it.
	if _data.archetype == _DATA.Archetype.REMNANT \
			and _data.mirror_style == _STYLE.STYLE_RANGED:
		if d <= KITE_INNER:
			_enter(_ST.State.WINDUP)
			events.append(EV_STATE_CHANGED)
			return
		if d <= KITE_FAR:
			return  # stand; the controller backs off to the band
	if d <= _data.attack.range:
		_enter(_ST.State.WINDUP)
		events.append(EV_STATE_CHANGED)
		return
	if d > _data.aggro_radius:
		_enter(_ST.State.IDLE)  # leash
		events.append(EV_STATE_CHANGED)
		return
	if _data.archetype == _DATA.Archetype.HOLLOW:
		# The player fled: out of sight for retreat_after s -> RETREAT.
		if d > _data.sight_range:
			_retreat_time += delta
		else:
			_retreat_time = 0.0
		if _retreat_time >= _data.retreat_after - EPS:
			_enter(_ST.State.RETREAT)
			events.append(EV_STATE_CHANGED)
	# Otherwise: the controller steers to the player (default).


func _wander(sense: _SENSE, delta: float, events: Array[String]) -> void:
	var d: float = _dist(sense)
	if d <= _data.sight_range:
		_enter(_ST.State.WINDUP)  # the Forgotten lunges at 5 m
		events.append(EV_STATE_CHANGED)
		return
	_whisper_timer -= delta
	if _whisper_timer <= EPS:
		_whisper_timer = WHISPER_INTERVAL
		var pool: PackedStringArray = _data.whisper_pool
		if not pool.is_empty():
			last_speech = pool[_whisper_pool_index % pool.size()]
			_whisper_pool_index += 1
			events.append(EV_SPEECH)
	if _wander_pos().distance_to(_wander_target) < 0.5:
		_pick_wander_target(_home)


func _after_attack(sense: _SENSE, events: Array[String]) -> void:
	if _data.archetype == _DATA.Archetype.FORGOTTEN:
		_enter(_ST.State.WANDER if _data.wander_radius > 0.0
				else _ST.State.IDLE)
	else:
		_enter(_ST.State.CHASE if _dist(sense) <= _data.aggro_radius
				else _ST.State.IDLE)
	events.append(EV_STATE_CHANGED)


func _seen_or_heard(sense: _SENSE) -> bool:
	if sense.player_seen:
		return true
	return sense.player_noise and _dist(sense) <= _data.hear_range


# --- Mimic punish helpers (the controller consults these) ---

# dodge-heavy: the Mimic is in CHASE — the controller steers it
# perpendicular to the player's facing while the player winds up.
func is_evasive() -> bool:
	return _data.archetype == _DATA.Archetype.MIMIC \
			and _data.mirror_style == _STYLE.STYLE_DODGE \
			and _state == _ST.State.CHASE


# The punish moment: melee-heavy — the player telegraphs a 2nd+ swing;
# dodge-heavy — the player over-dodges. Both: within reach.
func punish_due(sense: _SENSE) -> bool:
	if _data.archetype != _DATA.Archetype.MIMIC \
			or _state != _ST.State.CHASE:
		return false
	if _dist(sense) > _data.attack.range + 0.5:
		return false
	if _data.mirror_style == _STYLE.STYLE_MELEE:
		return sense.player_weapon_phase == 1 \
				and sense.player_combo_index >= 1
	if _data.mirror_style == _STYLE.STYLE_DODGE:
		return sense.player_dodging
	return false


# ranged-heavy: closes distance faster (data: close_distance 1.2).
func speed_pressure() -> float:
	if _data.archetype == _DATA.Archetype.MIMIC \
			and _data.mirror_style == _STYLE.STYLE_RANGED:
		return _data.punish_range
	return 1.0


# --- Internals ---

func _dist(sense: _SENSE) -> float:
	var p: Vector2 = Vector2(sense.player_position.x, sense.player_position.z)
	return Vector2(_pos_x, _pos_z).distance_to(p)


func _wander_pos() -> Vector2:
	return Vector2(_pos_x, _pos_z)


# The controller's WANDER steering target (xz).
func wander_target() -> Vector2:
	return _wander_target


func _pick_wander_target(h: Vector2) -> void:
	var a: float = _rng.randf() * TAU
	var r: float = _rng.randf_range(0.3, 1.0) * _data.wander_radius
	_wander_target = h + Vector2(cos(a), sin(a)) * r


func _track_player_phase(sense: _SENSE, delta: float) -> void:
	if sense.player_weapon_phase == _prev_player_phase:
		_player_phase_time += delta
	else:
		_player_phase_time = 0.0
		_prev_player_phase = sense.player_weapon_phase


func player_phase_time() -> float:
	return _player_phase_time
