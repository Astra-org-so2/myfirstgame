# WorldTransformData — the post-boss world transformation (K7,
# WORLD_STATE_DESIGN section 6): «мир теплеет» (the world grows
# warmer). Data, not code: the boss (Phase 12) sets the
# `boss_defeated` flag, the world reads this table.
class_name WorldTransformData
extends Resource

@export var fog_factor: float = 0.375  # 0.8 -> 0.3 density (the §6 table)
@export var light_temp: int = 5500  # K (4000K dusk -> 5500K warm)
@export var gate_glow: bool = true  # the gate glows (K7)
@export var city_visible: bool = true  # the silhouette behind the gate
# Echo budget offset (ECHO_SYSTEM_DESIGN section 8: «тише», -2):
# passive -> 0, special -> 0, combat stays (Remnant 1).
@export var echo_passive: int = 0
@export var echo_combat: int = 1
@export var echo_special: int = 0
@export var footprint_permanent: bool = true  # the traces stay forever
@export var npc_calm: bool = true  # the NPC lines change
