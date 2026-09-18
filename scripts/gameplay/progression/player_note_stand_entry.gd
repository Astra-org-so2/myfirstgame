# PlayerNoteStandEntry — one of the 4 player note stands
# (WORLD_STATE_DESIGN section 4): stand_id, the area it lives in,
# the room + offset (zones) or the camp position (the camp is stable,
# handcrafted — it is placed in CampWorld, not in the level).
class_name PlayerNoteStandEntry
extends Resource

@export var stand_id: StringName = &""
@export var area_id: StringName = &""
@export var room_idx: int = 0
@export var offset: Vector3 = Vector3.ZERO
@export var camp_pos: Vector3 = Vector3.ZERO
