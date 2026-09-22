# ObstacleBox — one interior obstacle of a room (room-local AABB).
#
# The headless rig has no physics server (ADR-002): the spawn probe
# (TECHNICAL_DESIGN §6) is GEOMETRIC against these boxes, and the
# scene builds the same boxes as the room's collision/volume mesh.
# One Resource per box (the proven .tres array form, ADR-022 item 23).
class_name ObstacleBox
extends Resource

@export var position: Vector3 = Vector3.ZERO  # center
@export var size: Vector3 = Vector3(1.0, 1.0, 1.0)  # full dims


func contains_point(p: Vector3) -> bool:
	return p.x >= position.x - size.x * 0.5 \
			and p.x <= position.x + size.x * 0.5 \
			and p.y >= position.y - size.y * 0.5 \
			and p.y <= position.y + size.y * 0.5 \
			and p.z >= position.z - size.z * 0.5 \
			and p.z <= position.z + size.z * 0.5
