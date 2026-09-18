# PassiveEchoData — the Passive Echo (ghost replay) presentation
# parameters (ECHO_SYSTEM_DESIGN section 1.4):
#   { opacity: 0.5, replay: true, attack: false, speech: 0,
#     fade_dist: 20m, fade_time: 3s, budget: 1/run }
class_name PassiveEchoData
extends Resource

@export var opacity: float = 0.5
# Ghost speed cap (TECHNICAL_DESIGN section 5.3: no artifacts — the
# replay must not teleport across a room in one frame).
@export var max_speed: float = 4.0
# The player outran the replay (dist > fade_dist) -> dissolve.
@export var fade_dist: float = 20.0
# Replay end / outrun: the dissolve length.
@export var fade_time: float = 3.0
# «Footprints» — the walked trail markers along the path.
@export var footprints: int = 10
# The «smoke» tint (gray-blue, desaturated — the echo look; the
# final dissolve/rim shader is the Phase 13 polish pass).
@export var tint: Color = Color(0.62, 0.70, 0.78)
