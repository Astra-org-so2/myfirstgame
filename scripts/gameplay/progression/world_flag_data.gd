# WorldFlagData — one world flag's visible consequence (WORLD_STATE_DESIGN
# §2/§9.2: "1 flag = 1 visible consequence").
#
# The registry (data/world_flags.tres) maps flag_id → consequence_text.
# The "what changed" UI reads these at respawn / major trigger: one line
# per newly-set flag, ≤ 5 lines, no numbers, skippable.
class_name WorldFlagData
extends Resource

@export var flag_id: StringName = &""
# One visible consequence (English MVP; no numbers — GDD §7/§13).
@export var consequence_text: String = ""
# The design-doc beat that sets the flag (A/B anchor or system) —
# documentation field, not logic.
@export var set_by: String = ""


func validate() -> Array[String]:
	var problems: Array[String] = []
	if flag_id == &"":
		problems.append("flag_id must be set")
	if consequence_text == "":
		problems.append("consequence_text is required (1 flag = 1 line)")
	return problems
