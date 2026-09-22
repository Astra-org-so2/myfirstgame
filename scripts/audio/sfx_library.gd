# SfxLibrary — procedural SFX generation (Phase 14: final).
#
# Real, audible sounds built from math (no assets, budget = 0 — the
# same contract as MusicLibrary): combat (swing/hit/riposte/hurt,
# shot/pickup from P4/P6) + the world's voice (P14: door/seal/
# death/note/ui/echo). Pure static functions — unit-testable
# headless, deterministic seed.
class_name SfxLibrary
extends RefCounted

const RATE: int = 22050
# AudioStreamWAV.Format (int: enum consts are not guaranteed in the rig).
const FORMAT_16_BITS: int = 1
const _PEAK: float = 0.9

const SWING_DUR: float = 0.3
const HIT_DUR: float = 0.18
const RIPOSTE_DUR: float = 0.4
const HURT_DUR: float = 0.25
const SHOT_DUR: float = 0.28
const PICKUP_DUR: float = 0.22


static func generate_swing() -> AudioStreamWAV:
	var n: int = int(RATE * SWING_DUR)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	var rnd: RandomNumberGenerator = RandomNumberGenerator.new()
	rnd.seed = 0x51A5  # deterministic (reproducible in tests/exports)
	var y: float = 0.0
	for i in n:
		var t: float = float(i) / float(n)
		var env: float = (1.0 - t) * (1.0 - t)
		var fc: float = 1400.0 - 1000.0 * t  # descending "whoosh"
		var k: float = 1.0 - exp(-6.28318 * fc / float(RATE))
		var x: float = rnd.randf_range(-1.0, 1.0)
		y += (x - y) * k  # one-pole low-pass
		out[i] = y * env * 2.4
	return _to_wav(_normalize(out))


static func generate_hit() -> AudioStreamWAV:
	var n: int = int(RATE * HIT_DUR)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	var rnd: RandomNumberGenerator = RandomNumberGenerator.new()
	rnd.seed = 0x1177
	for i in n:
		var t: float = float(i) / float(n)
		var env: float = (1.0 - t) * (1.0 - t) * (1.0 - t)
		var thud: float = sin(TAU * 70.0 * t) * 0.9
		var crack: float = rnd.randf_range(-1.0, 1.0) * 0.5 * env
		out[i] = thud * env + crack
	return _to_wav(_normalize(out))


static func generate_riposte() -> AudioStreamWAV:
	# Metallic "ping": fundamental + octave, fast decay.
	var n: int = int(RATE * RIPOSTE_DUR)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t: float = float(i) / float(n)
		var env: float = (1.0 - t) * (1.0 - t) * (1.0 - t) * (1.0 - t)
		var f1: float = sin(TAU * 1240.0 * t)
		var f2: float = sin(TAU * 2480.0 * t) * 0.5
		out[i] = (f1 + f2) * env
	return _to_wav(_normalize(out))


static func generate_hurt() -> AudioStreamWAV:
	var n: int = int(RATE * HURT_DUR)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	var rnd: RandomNumberGenerator = RandomNumberGenerator.new()
	rnd.seed = 0x11A7
	for i in n:
		var t: float = float(i) / float(n)
		var env: float = (1.0 - t) * (1.0 - t) * (1.0 - t)
		var low: float = sin(TAU * 55.0 * t)
		var noise: float = rnd.randf_range(-1.0, 1.0) * 0.25
		out[i] = (low + noise) * env
	return _to_wav(_normalize(out))


# Phase 6: the Hand Cannon's shot — a low boom (50 Hz) with a short
# crack on the attack (the "one shot = one decision" feel).
static func generate_shot() -> AudioStreamWAV:
	var n: int = int(RATE * SHOT_DUR)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	var rnd: RandomNumberGenerator = RandomNumberGenerator.new()
	rnd.seed = 0x5EED
	for i in n:
		var t: float = float(i) / float(n)
		var env: float = (1.0 - t) * (1.0 - t)
		var boom: float = sin(TAU * 50.0 * t) * 0.9
		var crack: float = rnd.randf_range(-1.0, 1.0) * 0.6 * (1.0 - t)
		out[i] = (boom + crack) * env
	return _to_wav(_normalize(out))


# Phase 6: a soft "plink" for found things (weapons, the small fire)
# — a short two-note chime, deliberately quiet (the world doesn't
# shout about its gifts).
static func generate_pickup() -> AudioStreamWAV:
	var n: int = int(RATE * PICKUP_DUR)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t: float = float(i) / float(n)
		# First 60%: 660 Hz, last 40%: 990 Hz (a rising "found").
		var f: float = 660.0 if t < 0.6 else 990.0
		var env: float = (1.0 - t) * (1.0 - t)
		out[i] = sin(TAU * f * t) * env
	return _to_wav(_normalize(out))


# --- Phase 14: the world's voice (the full SFX set) -----------------------

const DOOR_DUR: float = 0.5
const SEAL_DUR: float = 0.7
const DEATH_DUR: float = 1.2
const NOTE_DUR: float = 0.3
const UI_DUR: float = 0.08
const ECHO_DUR: float = 0.9


static func generate_door() -> AudioStreamWAV:
	# The heavy door: a low creak-sweep (120 -> 70 Hz) + a thud at the end.
	var n: int = int(RATE * DOOR_DUR)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t: float = float(i) / float(n)
		var f: float = lerpf(120.0, 70.0, t)
		var creak: float = sin(TAU * f * float(i) / float(RATE))
		var grind: float = (1.0 if fmod(float(i), 41.0) < 3.0 else -1.0) * 0.08
		var env: float = minf(1.0, t * 8.0) * minf(1.0, (1.0 - t) * 3.0)
		var thud: float = 0.0
		var tail: float = 1.0 - t
		if tail < 0.12:
			thud = sin(TAU * 55.0 * tail / 0.12 * 0.12) * (tail / 0.12) * 0.8
		out[i] = (creak * 0.7 + grind) * env + thud
	return _to_wav(_normalize(out))


static func generate_seal() -> AudioStreamWAV:
	# The seal breaks: a rising 45 -> 90 Hz swell, the 900 Hz "crack"
	# at 60%, then the ring.
	var n: int = int(RATE * SEAL_DUR)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t: float = float(i) / float(n)
		var s: float = 0.0
		var f: float = lerpf(45.0, 90.0, t)
		s += sin(TAU * f * float(i) / float(RATE)) * t * t * 0.6
		if t >= 0.6 and t < 0.75:
			var dt: float = (t - 0.6) / 0.15
			s += sin(TAU * 900.0 * dt) * (1.0 - dt) * 0.7
		if t >= 0.6:
			var dt: float = t - 0.6
			s += (sin(TAU * 237.5 * dt) * 0.4
					+ sin(TAU * 475.0 * dt) * 0.25) * exp(-5.0 * dt) * 0.5
		out[i] = s
	return _to_wav(_normalize(out))


static func generate_death() -> AudioStreamWAV:
	# The fall: a 200 -> 40 Hz drop (the body going down) + the low
	# hit + a reversed whisper tail (the "Again?" is a text line —
	# the sound is the body, not a voice).
	var n: int = int(RATE * DEATH_DUR)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	var rnd: RandomNumberGenerator = RandomNumberGenerator.new()
	rnd.seed = 0xD347
	for i in n:
		var t: float = float(i) / float(n)
		var s: float = 0.0
		var f: float = lerpf(200.0, 40.0, minf(1.0, t * 2.0))
		s += sin(TAU * f * float(i) / float(RATE)) * exp(-3.0 * t) * 0.7
		if t >= 0.45 and t < 0.6:
			var dt: float = (t - 0.45) / 0.15
			s += sin(TAU * 48.0 * dt) * (1.0 - dt) * 0.9
		# The reversed whisper: noise that ATTACKS from silence.
		if t > 0.5:
			var dt: float = (t - 0.5) / 0.5
			var k: float = 1.0 - exp(-6.28318 * 350.0 / float(RATE))
			var w: float = rnd.randf_range(-1.0, 1.0)
			s += w * dt * dt * 0.18
		out[i] = s
	return _to_wav(_normalize(out))


static func generate_note() -> AudioStreamWAV:
	# The paper: a short soft "swish" (high noise, fast decay) +
	# one 1.1 kHz page-edge ping.
	var n: int = int(RATE * NOTE_DUR)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	var rnd: RandomNumberGenerator = RandomNumberGenerator.new()
	rnd.seed = 0x5704
	var y: float = 0.0
	for i in n:
		var t: float = float(i) / float(n)
		var env: float = (1.0 - t) * (1.0 - t)
		var k: float = 1.0 - exp(-6.28318 * 2400.0 / float(RATE))
		y += (rnd.randf_range(-1.0, 1.0) - y) * k
		var ping: float = sin(TAU * 1100.0 * float(i) / float(RATE)) 				* exp(-30.0 * t) * 0.25
		out[i] = y * env * 1.6 + ping
	return _to_wav(_normalize(out))


static func generate_ui() -> AudioStreamWAV:
	# The interface: a short soft tick (600 Hz, 80 ms).
	var n: int = int(RATE * UI_DUR)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t: float = float(i) / float(n)
		var env: float = (1.0 - t) * (1.0 - t)
		out[i] = sin(TAU * 600.0 * t) * env * 0.7
	return _to_wav(_normalize(out))


static func generate_echo() -> AudioStreamWAV:
	# The Echo presence: a reversed voice-like murmur (filtered
	# noise, band 300-600 Hz, swells from silence and back) — the
	# "other you" without a voice.
	var n: int = int(RATE * ECHO_DUR)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	var rnd: RandomNumberGenerator = RandomNumberGenerator.new()
	rnd.seed = 0xE4A0
	var y: float = 0.0
	for i in n:
		var t: float = float(i) / float(n)
		# Swell in, swell out (the reversed shape).
		var env: float = sin(PI * t)
		env *= env
		var k: float = 1.0 - exp(-6.28318 * 450.0 / float(RATE))
		var x: float = rnd.randf_range(-1.0, 1.0)
		y += (x - y) * k
		out[i] = y * env * 2.2
	return _to_wav(_normalize(out))


# --- Internals ---

static func _normalize(samples: PackedFloat32Array) -> PackedFloat32Array:
	var peak: float = 0.0
	for i in samples.size():
		peak = maxf(peak, absf(samples[i]))
	if peak > 0.0001:
		var g: float = _PEAK / peak
		for i in samples.size():
			samples[i] *= g
	return samples


static func _to_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		var v: int = int(clampf(samples[i], -1.0, 1.0) * 32767.0)
		bytes[i * 2] = v & 0xFF
		bytes[i * 2 + 1] = (v >> 8) & 0xFF
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.data = bytes
	wav.format = FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	return wav
