# PlayerNoteStandsData — the 4 writable note stands (camp, village,
# shrine, undercroft; WORLD_STATE_DESIGN section 4, notes_max = 4,
# 1 note per stand, «перезапись» replaces). Data-driven placement.
class_name PlayerNoteStandsData
extends Resource

const _ENTRY = preload("res://scripts/gameplay/progression/player_note_stand_entry.gd")

@export var entries: Array = []  # Array[PlayerNoteStandEntry]


func entry_for(stand_id: StringName) -> _ENTRY:
	for e in entries:
		var en: _ENTRY = e
		if en.stand_id == stand_id:
			return en
	return null


func entry_in_area(area_id: StringName) -> _ENTRY:
	for e in entries:
		var en: _ENTRY = e
		if en.area_id == area_id:
			return en
	return null
