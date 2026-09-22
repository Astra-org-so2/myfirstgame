# WorldFlagTable — the flag registry (data/world_flags.tres):
# flag_id → consequence_text for the "what changed" UI
# (WORLD_STATE_DESIGN §2/§9.2).
class_name WorldFlagTable
extends Resource

const _FLAG = preload("res://scripts/gameplay/progression/world_flag_data.gd")

@export var flags: Array = []  # Array[WorldFlagData]


func line_for(flag_id: StringName) -> String:
	for f in flags:
		var fd: _FLAG = f
		if fd != null and fd.flag_id == flag_id:
			return fd.consequence_text
	return ""


# The flag → line dictionary (RunManager.changed_lines consumes it).
func lines() -> Dictionary:
	var out := {}
	for f in flags:
		var fd: _FLAG = f
		if fd != null:
			out[fd.flag_id] = fd.consequence_text
	return out


func validate() -> Array[String]:
	var problems: Array[String] = []
	if flags.is_empty():
		problems.append("the flag table is empty")
	var seen := {}
	for f in flags:
		var fd: _FLAG = f
		if fd == null:
			problems.append("null flag entry")
			continue
		if seen.has(fd.flag_id):
			problems.append("duplicate flag: %s" % fd.flag_id)
		seen[fd.flag_id] = true
		problems.append_array(fd.validate())
	return problems
