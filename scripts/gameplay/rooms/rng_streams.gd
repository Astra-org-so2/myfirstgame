# RngStreams — the run's deterministic RNG streams (TECHNICAL_DESIGN §6).
#
# Four INDEPENDENT streams from one master seed: RngWorld (layout —
# room variants/connections), RngEncounter (spawns), RngLoot (loot
# rolls), RngEvent (mystery triggers). Independence = changing the
# loot seed never reshuffles the layout (debuggable, A/B-testable).
#
# Derivation: splitmix64 (the engine's own seed-splitting function,
# stable across Godot versions — unlike chained randi()):
#   stream_seed_i = splitmix64(master, i)
#
# Pure RefCounted — unit-testable headless; the scene owns one
# instance per run (RunManager in Phase 8 replaces the scene's
# fixed seed with the run seed — same API).
class_name RngStreams
extends RefCounted

const STREAM_WORLD: int = 0
const STREAM_ENCOUNTER: int = 1
const STREAM_LOOT: int = 2
const STREAM_EVENT: int = 3

# splitmix64 constants (64-bit; written as SIGNED decimals because
# GDScript hex literals cannot exceed INT64_MAX — the bit patterns
# are identical: 0x9E3779B97F4A7C15, 0xFFFFFFFFFFFFFFFF, etc.).
const _GOLDEN: int = -7046029254386353131  # 0x9E3779B97F4A7C15
const _MASK: int = -1  # 0xFFFFFFFFFFFFFFFF
const _M1: int = -4658895280553007687  # 0xBF58476D1CE4E5B9
const _M2: int = -7723592293110705685  # 0x94D049BB133111EB

var world: RandomNumberGenerator
var encounter: RandomNumberGenerator
var loot: RandomNumberGenerator
var event: RandomNumberGenerator


# splitmix64 one step (pure 64-bit, wraps on overflow — the same
# way Godot derives its own per-stream seeds).
static func _splitmix64(state: int) -> Array:
	var z: int = (state + _GOLDEN) & _MASK
	var r: int = (z ^ (z >> 30)) & _MASK
	r = (r * _M1) & _MASK
	r = (r ^ (r >> 27)) & _MASK
	r = (r * _M2) & _MASK
	r = (r ^ (r >> 31)) & _MASK
	return [z, r]


func setup(master_seed: int) -> void:
	var state: int = master_seed & _MASK
	for i in [STREAM_WORLD, STREAM_ENCOUNTER, STREAM_LOOT, STREAM_EVENT]:
		state = int(_splitmix64(state)[0])
		match i:
			STREAM_WORLD:
				world = _make(state)
			STREAM_ENCOUNTER:
				encounter = _make(state)
			STREAM_LOOT:
				loot = _make(state)
			STREAM_EVENT:
				event = _make(state)


static func _make(seed: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed
	return rng
