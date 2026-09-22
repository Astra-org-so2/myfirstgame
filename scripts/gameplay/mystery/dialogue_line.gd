# DialogueLine — one NPC mystery line (DIALOGUE_GUIDELINES section 6,
# the DIALOGUE_DATA schema — the MVP subset: no tree/node — the MVP
# nodes are one-shot lines, not dialogue trees). Evaluated by the
# NpcNode on talk; the FIRST matching line (table order = priority)
# wins. One-shot per session (the line is used up) unless `repeat`.
class_name DialogueLine
extends Resource

@export var id: StringName = &""
@export var char: StringName = &""  # the npc_id it belongs to
@export var text: String = ""
@export var trust_req: int = 0
@export var run_req: int = 0
@export var flag_req: StringName = &""
@export var flag_set: StringName = &""
@export var repeat: bool = false
@export var max_words: int = 12
