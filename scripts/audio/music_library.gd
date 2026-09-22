# MusicLibrary — the soundtrack bank (Phase 14, GDD v2.0 §7).
#
# One melody, «The Wound», in five variations (Normal / Memory /
# Echo / Archivist / Ending) + six ambient layers + one stinger
# (the boss reveal). Generated OFFLINE by tools/utils/gen_audio.py
# (pure stdlib, fixed seed, byte-stable — the same contract as
# gen_textures.py for the P13 textures): the soundtrack is math,
# not assets, budget 0, nothing to license-track.
#
# This script is the RUNTIME BANK: it loads the generated WAVs
# (FileAccess -> AudioStreamWAV, the proven res:// path from P13)
# and hands out streams. No synthesis here — 12 × ~20 s of
# synthesis at runtime would be a wasm startup hitch.
#
# The melody (WORLD_BIBLE §1.1 «the wound»): an 8-beat phrase that
# rises and does not resolve, answered 8 beats lower. 24-beat loop
# (24 s at 60 BPM). The variations change TIMBRE AND TIME, not the
# notes — the player should recognize the melody in every layer:
#   normal    — sparse, muted, close (sine + one soft harmonic);
#   memory    — pale: higher octave, long decay, a quiet reverb tail;
#   echo      — desaturated: a reversed fragment + a tapped echo;
#   archivist — monochrome: pure sine, staccato, a low drone under,
#               a rust-metal accent on the downbeats;
#   ending    — full: two harmonics, a warm pad, the last phrase up.
#
# Levels (baked into the files, gen_audio.py): music/stinger peak
# 0.85, ambients peak 0.35 (the background bed). Bus defaults sit
# on top of that (AudioManager), so the mix stays under the SFX in
# both worlds (rig and device).
class_name MusicLibrary
extends RefCounted

const _MUSIC_PEAK: float = 0.85
const _AMB_PEAK: float = 0.35

# AudioStreamWAV.Format / .LoopMode (int: enum consts are not
# guaranteed in the rig — the same rule as SfxLibrary).
const FORMAT_16_BITS: int = 1
const LOOP_FORWARD: int = 1
const _RATE: int = 11025  # what gen_audio.py writes (no content > 5.5 kHz)

const DIR: String = "res://assets/audio"

# The five variations (MusicDirector.stream_name -> file stem).
const WOUND: Dictionary = {
	"normal": "wound_normal.wav",
	"memory": "wound_memory.wav",
	"echo": "wound_echo.wav",
	"archivist": "wound_archivist.wav",
	"ending": "wound_ending.wav",
}
const STINGER_FILE: String = "stinger.wav"

# The six ambient layers (zone -> file). The wild places share one
# bed, the stone places share one.
const AMBIENT: Dictionary = {
	"camp": "amb_camp.wav",
	"ruined_village": "amb_wild.wav",
	"watchtower": "amb_wild.wav",
	"broken_bridge": "amb_wild.wav",
	"old_shrine": "amb_stone.wav",
	"ancient_gate": "amb_stone.wav",
	"the_mine": "amb_mine.wav",
	"mysterious_lake": "amb_lake.wav",
	"undercroft": "amb_undercroft.wav",
}


# A wound variation (looping, ~24 s). null on a bad name.
static func wound(variation: String) -> AudioStreamWAV:
	var f: String = str(WOUND.get(variation, ""))
	if f == "":
		push_error("MusicLibrary: unknown variation '%s'" % variation)
		return null
	return _load(f, true)


# The zone ambient (looping, 16 s). null on an unknown zone.
static func ambient(zone: StringName) -> AudioStreamWAV:
	var f: String = str(AMBIENT.get(zone, ""))
	if f == "":
		push_error("MusicLibrary: unknown zone '%s'" % str(zone))
		return null
	return _load(f, true)


# The boss-reveal stinger (one-shot, 4 s).
static func stinger() -> AudioStreamWAV:
	return _load(STINGER_FILE, false)


# --- The loader -------------------------------------------------------------

static func _load(file: String, loop: bool) -> AudioStreamWAV:
	var path: String = DIR + "/" + file
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("MusicLibrary: cannot open %s (err %d)"
				% [path, FileAccess.get_open_error()])
		return null
	var raw: PackedByteArray = f.get_buffer(f.get_length())
	f.close()
	# The 44-byte WAV header is stripped: AudioStreamWAV takes the
	# raw PCM (16-bit mono little-endian at _RATE).
	var pcm: PackedByteArray = raw.slice(44)
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.data = pcm
	wav.format = FORMAT_16_BITS
	wav.mix_rate = _RATE
	wav.stereo = false
	if loop:
		wav.loop_mode = LOOP_FORWARD
		wav.loop_end = pcm.size() / 2
	return wav


# --- Stream readers (tests: length, peak, loop flag) -------------------------

static func duration(wav: AudioStreamWAV) -> float:
	return float(wav.data.size() / 2) / float(wav.mix_rate)


static func peak(wav: AudioStreamWAV) -> float:
	var m: float = 0.0
	var d: PackedByteArray = wav.data
	for i in range(0, d.size(), 2):
		var v: int = d[i] | (d[i + 1] << 8)
		if v > 0x7FFF:
			v -= 0x10000
		m = maxf(m, absf(float(v) / 32767.0))
	return m


static func is_looping(wav: AudioStreamWAV) -> bool:
	return wav.loop_mode == LOOP_FORWARD
