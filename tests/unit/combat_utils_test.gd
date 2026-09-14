# Unit: combat utilities — HitStop (delta scaler), VfxPool (fixed pool),
# SfxLibrary (procedural WAV generation, deterministic).
extends Node

const _HITSTOP = preload("res://scripts/gameplay/combat/hitstop.gd")
const _VFX = preload("res://scripts/gameplay/combat/vfx_pool.gd")
const _LIB = preload("res://scripts/audio/sfx_library.gd")

const DT: float = 1.0 / 60.0


func run(ctx: Variant) -> void:
	# --- HitStop ---
	var hs: _HITSTOP = _HITSTOP.new()
	ctx.check(not hs.is_frozen(), "hitstop: idle by default")
	var passthrough: float = hs.update(DT)
	ctx.check(absf(passthrough - DT) < 0.0001,
			"hitstop: passthrough when not frozen")
	# 0.09 s = 5.4 ticks: off the tick boundary, so the frozen tick count
	# is exact (0.1 s hits the boundary and float drift blurs it).
	hs.freeze(0.09)
	var zero_ticks: int = 0
	for i in 7:
		if hs.update(DT) == 0.0:
			zero_ticks += 1
	ctx.check(zero_ticks == 6,
			"hitstop: 0.09 s freezes exactly 6 ticks (got %d)" % zero_ticks)
	ctx.check(not hs.is_frozen(), "hitstop: released after expiry")
	ctx.check(absf(hs.update(DT) - DT) < 0.0001,
			"hitstop: passthrough after expiry")
	# Overlapping freezes: max, not additive. 0.01 s < 1 tick: freeze is
	# 1 tick, release at tick 2. If freezes added (0.02 s = 1.2 ticks ->
	# 2 frozen ticks), tick 2 would still be frozen.
	hs.freeze(0.01)
	hs.freeze(0.01)
	ctx.check(hs.update(DT) == 0.0, "hitstop: overlapping, tick 1 frozen")
	ctx.check(hs.update(DT) == DT and not hs.is_frozen(),
			"hitstop: overlapping freezes don't add up")

	# --- VfxPool ---
	var pool: _VFX = _VFX.new()
	add_child(pool)  # _ready fires on tree entry
	ctx.check(pool.active_count() == 0, "vfx: pool idle at start")
	for i in _VFX.POOL_SIZE:
		pool.spawn(Vector3(float(i), 0.0, 0.0), _VFX.KIND_HIT)
	ctx.check(pool.active_count() == _VFX.POOL_SIZE,
			"vfx: pool fills to capacity (%d)" % _VFX.POOL_SIZE)
	var nodes_before: int = pool.get_child_count()
	pool.spawn(Vector3.ZERO, _VFX.KIND_RIPOSTE)  # over capacity
	ctx.check(pool.get_child_count() == nodes_before,
			"vfx: over-capacity spawn reuses (no node growth)")
	ctx.check(pool.spawn_calls == _VFX.POOL_SIZE + 1,
			"vfx: spawn_calls counts every request")
	for i in 18:  # > LIFETIME
		pool._physics_process(DT)
	ctx.check(pool.active_count() == 0,
			"vfx: all effects recycled after lifetime")

	# --- SfxLibrary (procedural WAVs) ---
	_check_stream(ctx, _LIB.generate_swing(), _LIB.SWING_DUR, "swing")
	_check_stream(ctx, _LIB.generate_hit(), _LIB.HIT_DUR, "hit")
	_check_stream(ctx, _LIB.generate_riposte(), _LIB.RIPOSTE_DUR, "riposte")
	_check_stream(ctx, _LIB.generate_hurt(), _LIB.HURT_DUR, "hurt")

	# Determinism: two generations of the same cue are byte-identical.
	var a: AudioStreamWAV = _LIB.generate_hit()
	var b: AudioStreamWAV = _LIB.generate_hit()
	ctx.check(a.data == b.data, "sfx: generation is deterministic")


func _check_stream(ctx: Variant, wav: AudioStreamWAV, dur: float,
	label: String) -> void:
	ctx.check(wav != null, "sfx: %s stream generated" % label)
	if wav == null:
		return
	var expected_bytes: int = int(_LIB.RATE * dur) * 2
	ctx.check(wav.data.size() == expected_bytes,
			"[%s] size = %d samples x 2 (got %d)" % [label,
					int(_LIB.RATE * dur), wav.data.size()])
	ctx.check(wav.mix_rate == _LIB.RATE, "sfx: %s mix rate" % label)
	# Samples: valid int16, non-silent, no clip runaway.
	var peak: int = 0
	var sample_count: int = wav.data.size() / 2
	var step: int = maxi(1, sample_count / 50)
	for i in range(0, sample_count, step):
		var lo: int = wav.data[i * 2]
		var hi: int = wav.data[i * 2 + 1]
		var v: int = lo | (hi << 8)
		if hi & 0x80 != 0:
			v -= 65536
		peak = maxi(peak, absi(v))
	ctx.check(peak > 100,
			"[%s] audible amplitude (peak %d)" % [label, peak])
