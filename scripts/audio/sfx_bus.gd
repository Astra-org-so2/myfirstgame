# SfxBus — a small SFX playback pool for Phase 4 (prototype status).
#
# Final audio architecture (buses Master/Music/SFX/Voice, settings in
# save) arrives with AudioManager in Phase 14; until then this node owns
# a fixed pool of AudioStreamPlayers and the procedural streams from
# SfxLibrary. No bus routing here (default Master) on purpose — one
# fewer system to maintain before Phase 14.
class_name SfxBus
extends Node

const _LIB = preload("res://scripts/audio/sfx_library.gd")

const NAMES: Array[StringName] = [
	&"swing", &"hit", &"riposte", &"hurt",
	# Phase 6: the Hand Cannon's shot + the found-thing "plink".
	&"shot", &"pickup",
]
const POOL_SIZE: int = 3

var trigger_count: int = 0

var _streams: Dictionary = {}  # StringName -> AudioStreamWAV
var _players: Array = []


func _ready() -> void:
	_streams[&"swing"] = _LIB.generate_swing()
	_streams[&"hit"] = _LIB.generate_hit()
	_streams[&"riposte"] = _LIB.generate_riposte()
	_streams[&"hurt"] = _LIB.generate_hurt()
	_streams[&"shot"] = _LIB.generate_shot()
	_streams[&"pickup"] = _LIB.generate_pickup()
	for i in POOL_SIZE:
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.name = "Sfx%d" % i
		add_child(p)
		_players.append(p)


# Plays a named cue on a free pool slot (steals the oldest if none).
# Returns false on an unknown cue (push_error).
func play(name: StringName, volume_db: float = 0.0) -> bool:
	if not _streams.has(name):
		push_error("SfxBus: unknown cue '%s'" % str(name))
		return false
	trigger_count += 1
	var p: AudioStreamPlayer = _find_free()
	p.stream = _streams[name]
	p.volume_db = volume_db
	p.play()
	return true


func is_any_playing() -> bool:
	for p in _players:
		if p.playing:
			return true
	return false


func _find_free() -> AudioStreamPlayer:
	for p in _players:
		if not p.playing:
			return p
	return _players[0]  # all busy: steal the oldest slot
