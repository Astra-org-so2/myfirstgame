# AudioManager — the final audio architecture (Phase 14, GDD §7).
#
# Three buses (Music / SFX / Ambient on Master), a crossfading music
# voice (two players A/B), a looping ambient voice (per zone), a
# one-shot stinger (the boss reveal), and the settings (per-bus
# levels + mute) the P15 save will persist.
#
# The music content is MusicLibrary's bank (generated offline —
# ADR-033), the variation choice is MusicDirector's pure priority
# chain; this node only owns PLAYBACK and the buses. The scene
# (main) feeds it the facts it already knows: the zone, the boss,
# the Echo, the world memory. No audio state lives here that the
# scene does not own.
class_name AudioManager
extends Node

const _LIB = preload("res://scripts/audio/music_library.gd")
const _DIR = preload("res://scripts/audio/music_director.gd")

const BUS_MUSIC: String = "Music"
const BUS_SFX: String = "SFX"
const BUS_AMBIENT: String = "Ambient"
# Bus defaults (dB below Master): the music sits on top, the SFX
# just under it, the ambients are the bed.
const BUS_DEFAULT_DB: Dictionary = {
	BUS_MUSIC: 0.0,
	BUS_SFX: -3.0,
	BUS_AMBIENT: -9.0,
}
const _MUTE_DB: float = -80.0
const _SILENT_DB: float = -80.0

# Settings (0..1 linear; P15 persists this in the save).
var master: float = 1.0
var music_level: float = 1.0
var sfx_level: float = 1.0
var ambient_level: float = 1.0
var muted: bool = false

var _music_a: AudioStreamPlayer = null
var _music_b: AudioStreamPlayer = null
var _ambient: AudioStreamPlayer = null
var _stinger: AudioStreamPlayer = null
var _streams: Dictionary = {}  # cache: String -> AudioStreamWAV

var _current_variation: int = -1
var _fade_from: AudioStreamPlayer = null
var _fade_to: AudioStreamPlayer = null
var _fade_t: float = 0.0
var _fade_dur: float = 1.0

var _zone: StringName = &""


func _ready() -> void:
	_ensure_buses()
	_create_players()
	apply_settings()


func _process(delta: float) -> void:
	_step_fade(delta)


# --- Music ------------------------------------------------------------------

# The variation currently playing (-1 before the first set).
func current_variation() -> int:
	return _current_variation


# Switch the variation with a crossfade (the scene calls this
# through update_music; direct calls are for tests/the stinger).
func set_variation(variation: int, fade: float = _DIR.CROSSFADE_SECONDS) -> void:
	if variation < 0 or variation > _DIR.Variation.ENDING:
		push_error("AudioManager: bad variation %d" % variation)
		return
	if _current_variation == variation:
		return
	var stream: AudioStreamWAV = _wound(variation)
	if stream == null:
		return
	var to: AudioStreamPlayer
	var from: AudioStreamPlayer
	if _music_a == null or _music_a.stream == null:
		# The first variation: no fade, just start.
		to = _music_a
		from = null
	else:
		from = _active_music()
		to = _other(from)
	to.stream = stream
	to.play()
	to.volume_db = _SILENT_DB
	if from == null:
		to.volume_db = 0.0
		_current_variation = variation
		return
	_fade_from = from
	_fade_to = to
	_fade_t = 0.0
	_fade_dur = maxf(0.05, fade)
	_current_variation = variation


# The scene-facing entry: pick the variation from the world facts
# and switch if needed (re-picking the same fact is free).
func update_music(area_id: StringName, boss_active: bool,
		boss_defeated: bool, echo_active: bool) -> void:
	var target: int = _DIR.pick(area_id, boss_active, boss_defeated,
			echo_active)
	if _DIR.needs_switch(_current_variation, target):
		set_variation(target)


# --- Ambient ------------------------------------------------------------------

# The zone bed (crossfaded swap). Unknown zones keep the current bed.
func set_zone(zone: StringName) -> void:
	if zone == _zone:
		return
	var stream: AudioStreamWAV = _LIB.ambient(zone)
	if stream == null:
		return
	_zone = zone
	_ambient.stream = stream
	if not _ambient.playing:
		_ambient.volume_db = _SILENT_DB
		_ambient.play()
		_ambient.volume_db = 0.0


func current_zone() -> StringName:
	return _zone


# --- The stinger ---------------------------------------------------------------

# The boss reveal: a one-shot over the music.
func play_stinger() -> void:
	var stream: AudioStreamWAV = _LIB.stinger()
	if stream == null:
		return
	_stinger.stream = stream
	_stinger.volume_db = 0.0
	_stinger.play()


func is_stinger_playing() -> bool:
	return _stinger.playing


# --- Settings -------------------------------------------------------------------

# 0..1 linear -> bus dB (0 = the -80 floor, never true infinity).
static func level_to_db(level: float) -> float:
	if level <= 0.001:
		return _MUTE_DB
	# 20*log10 via natural log (the Math singleton is not in the rig).
	return 20.0 * log(level) / 2.302585092994046


# (Re)apply the settings to the buses. Idempotent.
func apply_settings() -> void:
	var m: float = 0.0 if muted else master
	for bus in [BUS_MUSIC, BUS_SFX, BUS_AMBIENT]:
		var idx: int = AudioServer.get_bus_index(bus)
		if idx < 0:
			continue
		var base: float = float(BUS_DEFAULT_DB[bus])
		var level: float
		match bus:
			BUS_MUSIC:
				level = music_level
			BUS_SFX:
				level = sfx_level
			BUS_AMBIENT:
				level = ambient_level
		var db: float
		if m <= 0.001:
			db = _MUTE_DB
		else:
			db = base + level_to_db(level) + level_to_db(m)
		AudioServer.set_bus_volume_db(idx, db)


# The settings as a plain dict (P15 saves this; tests read this).
func get_settings() -> Dictionary:
	return {
		"master": master,
		"music": music_level,
		"sfx": sfx_level,
		"ambient": ambient_level,
		"muted": muted,
	}


func settings_from_dict(d: Dictionary) -> void:
	if d == null:
		return
	master = clampf(float(d.get("master", 1.0)), 0.0, 1.0)
	music_level = clampf(float(d.get("music", 1.0)), 0.0, 1.0)
	sfx_level = clampf(float(d.get("sfx", 1.0)), 0.0, 1.0)
	ambient_level = clampf(float(d.get("ambient", 1.0)), 0.0, 1.0)
	muted = bool(d.get("muted", false))
	apply_settings()


# --- Internals ------------------------------------------------------------------

func _ensure_buses() -> void:
	for name in [BUS_MUSIC, BUS_SFX, BUS_AMBIENT]:
		if AudioServer.get_bus_index(name) < 0:
			AudioServer.add_bus(AudioServer.get_bus_count())
			var idx: int = AudioServer.get_bus_count() - 1
			AudioServer.set_bus_name(idx, name)
			AudioServer.set_bus_send(idx, "Master")


func _create_players() -> void:
	_music_a = _make_player("MusicA", BUS_MUSIC)
	_music_b = _make_player("MusicB", BUS_MUSIC)
	_ambient = _make_player("Ambient", BUS_AMBIENT)
	_stinger = _make_player("Stinger", BUS_MUSIC)


func _make_player(name: String, bus: String) -> AudioStreamPlayer:
	var p: AudioStreamPlayer = AudioStreamPlayer.new()
	p.name = name
	p.bus = bus
	add_child(p)
	return p


func _active_music() -> AudioStreamPlayer:
	if _fade_to != null and _fade_t < _fade_dur:
		return _fade_to
	if _music_a != null and _music_a.playing:
		return _music_a
	return _music_b


func _other(p: AudioStreamPlayer) -> AudioStreamPlayer:
	return _music_b if p == _music_a else _music_a


func _step_fade(delta: float) -> void:
	if _fade_from == null or _fade_to == null:
		return
	_fade_t += delta / _fade_dur
	var k: float = clampf(_fade_t, 0.0, 1.0)
	# Linear-volume fade (dB = 20log10 of the level).
	_fade_from.volume_db = _SILENT_DB if k >= 1.0 else level_to_db(1.0 - k)
	_fade_to.volume_db = _SILENT_DB if k <= 0.0 else level_to_db(k)
	if _fade_t >= 1.0:
		_fade_from.stop()
		_fade_from = null
		_fade_to = null


func _wound(variation: int) -> AudioStreamWAV:
	var name: String = _DIR.VARIATION_NAMES[variation]
	if _streams.has("wound_" + name):
		return _streams["wound_" + name]
	var w: AudioStreamWAV = _LIB.wound(name)
	if w != null:
		_streams["wound_" + name] = w
	return w
