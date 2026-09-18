# GhostKeyframe — one point of the replay path (GhostTimeline).
class_name GhostKeyframe
extends RefCounted

var t: float = 0.0  # seconds, timeline-local (run time - run start)
var pos: Vector3 = Vector3.ZERO  # new-layout space (remapped)
var ry: float = 0.0  # degrees
var action: int = -1  # the RunEvent type at this moment
