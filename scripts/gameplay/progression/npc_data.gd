# NpcData — one NPC of the five (PROGRESSION_DESIGN §4, CHARACTER_BIBLE).
#
# The trust system is the gate for the NPC-gated Inheritances:
#   trust 0: "stranger" (1 line, gives nothing);
#   trust 1: "knows you" — 2 interactions + 1 scripted help →
#            the NPC-gated Inheritance enters the death-screen pool;
#   trust 2: "trusts you" — trust 1 + 2 more interactions + an
#            NPC-specific memory_stat (dialogue/epilogue depth,
#            epilogue itself is post-MVP).
# The Child is NOT in this data (invulnerable by design, a separate
# entity — CHARACTER_BIBLE §5).
class_name NpcData
extends Resource

@export var npc_id: StringName = &""
@export var display_name: String = ""
@export var visual_color: Color = Color(0.7, 0.6, 0.5)
@export_group("Trust")
# Interactions needed for trust 1 (PROGRESSION_DESIGN §4: 2).
@export var trust_1_interactions: int = 2
# Interactions needed for trust 2 (2 more, counted from zero).
@export var trust_2_interactions: int = 4
# The scripted "help" (1 action; data id, content per CHARACTER_BIBLE).
@export var help_action: String = ""
# Trust 2 requires the NPC-specific memory_stat above the threshold.
@export var trust_2_stat: StringName = &""
@export var trust_2_threshold: float = 0.0
@export_group("Gift (NPC-gated Inheritance)")
@export var gift_id: StringName = &""
# One line per trust level (0, 1, 2) — dry, no exposition.
@export var dialogue_0: String = ""
@export var dialogue_1: String = ""
@export var dialogue_2: String = ""
@export_group("Death (the permanent price)")
@export var death_flag: StringName = &""
@export var death_consequence: String = ""


func dialogue_for(trust: int) -> String:
	match trust:
		0:
			return dialogue_0
		1:
			return dialogue_1
		_:
			return dialogue_2


func validate() -> Array[String]:
	var problems: Array[String] = []
	if npc_id == &"":
		problems.append("npc_id must be set")
	if trust_1_interactions < 1 or trust_2_interactions < trust_1_interactions:
		problems.append("trust thresholds must be 1 <= t1 <= t2")
	if dialogue_0 == "" or dialogue_1 == "" or dialogue_2 == "":
		problems.append("one dialogue line per trust level is required")
	return problems
