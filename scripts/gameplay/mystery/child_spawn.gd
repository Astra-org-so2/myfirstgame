# ChildSpawn — one scripted Child appearance (CHARACTER_BIBLE 5:
# «roaming = 2-3 scripted positions per RUN (not random)» — MVP:
# 1 per run window; the window is the data).
class_name ChildSpawn
extends Resource

@export var run_min: int = 4
@export var run_max: int = 6  # the appearance window (1 per run)
@export var zone: StringName = &"ruined_village"
@export var pos: Vector3 = Vector3.ZERO  # level-local (room 0 origin +)
# One fact per encounter (the lines, encounter order).
@export var lines: PackedStringArray = PackedStringArray()
# A requirement (e.g. deaths >= 3 for the RUN 04 line).
@export var min_deaths: int = 0
