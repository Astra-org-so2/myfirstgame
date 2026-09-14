# SfxLibrary — procedural SFX generation (Phase 4: prototype status).
#
# The roadmap mandates "SFX (процедурные заглушки, prototype-статус)" in
# Phase 4: real, audible placeholder sounds built from math (no assets,
# budget = 0), replaced by final assets in Phase 14 (AudioManager).
# Pure static functions — unit-testable headless, deterministic seed.
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
