# MusicDirector — which variation of «The Wound» is playing NOW.
#
# Pure RefCounted (ADR-023 pattern): the scene feeds it the world
# facts it already knows (the zone, the boss, the Echo, the world
# memory) and it answers with a variation id. No scene, no time —
# unit-testable headless.
#
# The mapping (GDD v2.0 §7 + WORLD_BIBLE §1.1 sound layers):
#   ENDING    — the boss is gone AND the player is in the Undercroft
#               (the final scene: the door is open, the fog thins);
#   ARCHIVIST — the boss fight (the Undercroft, the monochrome arena
#               — THE FIRST is the player's own archive, GDD §8);
#   ECHO      — a Passive Echo walks with the player (the reversed
#               fragments variation);
#   MEMORY    — the world remembers (post-boss, anywhere: the gate
#               glows, the city stands — P11 world memory);
#   NORMAL    — everything else.
class_name MusicDirector
extends RefCounted

enum Variation {
	NORMAL,
	MEMORY,
	ECHO,
	ARCHIVIST,
	ENDING,
}

const CROSSFADE_SECONDS: float = 1.5

const VARIATION_NAMES: Array[String] = [
	"normal", "memory", "echo", "archivist", "ending",
]


# The priority chain (highest first). Each rung is a fact the scene
# already owns — no new state in the audio layer.
static func pick(area_id: StringName, boss_active: bool,
		boss_defeated: bool, echo_active: bool) -> int:
	if boss_defeated and area_id == &"undercroft":
		return Variation.ENDING
	if boss_active:
		return Variation.ARCHIVIST
	if echo_active:
		return Variation.ECHO
	if boss_defeated:
		return Variation.MEMORY
	return Variation.NORMAL


# The stream the variation maps to (the scene preloads these into
# the AudioManager once).
static func stream_name(variation: int) -> StringName:
	return StringName(VARIATION_NAMES[variation])


# A switch is needed only when the target differs from the current
# variation (re-picking the same fact every frame must be free).
static func needs_switch(current: int, target: int) -> bool:
	return current != target
