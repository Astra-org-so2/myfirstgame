# MysteryStage — one stage of one mystery (MYSTERY_REVEAL_MAP §1):
# the «one fact, one source, one door» unit (NARRATIVE_STRUCTURE
# §7.2). Data-driven: a new stage = a new row, no code.
#
# flag_req = «no early reveal» (rule 2): the stage is only possible
# after its prerequisite flag (the previous stage's flag_set chain).
# `line` = what the player HEARS ("" = a world/visual beat, e.g. the
# RUN 02 trace). The ambiguity budget is `max_words` (DIALOGUE_
# GUIDELINES section 7: 12, Archivist 20).
class_name MysteryStage
extends Resource

@export var stage_id: StringName = &""
@export var mystery: int = 1  # 1-4 (M1-M4)
@export var stage: int = 1  # 1..N (MVP: <= 4 for M1, <= 3 rest)
@export var run_min: int = 1
@export var flag_req: StringName = &""
@export var flag_set: StringName = &""
@export var line: String = ""
@export var max_words: int = 12
