# MysteryDirector — the reveal gate (MYSTERY_REVIEW_MAP section 4,
# the reveal rules). Pure logic (RefCounted, no scene): the scene
# asks can_reveal() before delivering a beat and calls reveal()
# when the beat lands.
#
# Rules enforced here (the data table enforces them too — validate):
#   1. 1 stage / run: a mystery does not advance more than one
#      stage per run (rule 6: the «world is not in a hurry» — the
#      stage shifts to the next run);
#   2. no early reveal: strict sequence (progress == n-1) AND the
#      prerequisite flag (the flag chain, rule 2);
#   3. run_min: the stage is not possible before its run.
class_name MysteryDirector
extends RefCounted

const _STAGES = preload("res://scripts/gameplay/mystery/mystery_stages.gd")
const _STAGE = preload("res://scripts/gameplay/mystery/mystery_stage.gd")

var stages: _STAGES = null

# The mysteries that advanced THIS run (mystery id -> true).
var revealed_this_run: Dictionary = {}


func setup(p_stages: _STAGES) -> void:
	stages = p_stages


# A new run begins: the 1-stage-per-run allowance resets.
func reset_run() -> void:
	revealed_this_run.clear()


func can_reveal(stage_id: StringName, ws: Variant, run_id: int) -> bool:
	if stages == null:
		return false
	var s: _STAGE = stages.stage(stage_id)
	if s == null:
		return false
	if run_id < s.run_min:
		return false
	# Strict sequence: this is the NEXT stage of its mystery.
	if int(ws.mystery_stage(s.mystery)) != s.stage - 1:
		return false
	# The no-early-reveal flag (the chain).
	if s.flag_req != &"" and not ws.flag(s.flag_req):
		return false
	# 1 stage / run.
	if revealed_this_run.has(s.mystery):
		return false
	return true


# The scene calls this AFTER the beat actually happened (the flag
# and the progress land together — no «revealed but unseen»).
func reveal(stage_id: StringName, ws: Variant, run_id: int) -> bool:
	if not can_reveal(stage_id, ws, run_id):
		return false
	var s: _STAGE = stages.stage(stage_id)
	ws.set_mystery_stage(s.mystery, s.stage)
	revealed_this_run[s.mystery] = true
	if s.flag_set != &"":
		ws.set_flag(s.flag_set)
	return true


# Debug/QA view: "M1:3 M2:2 M3:1 M4:0".
func progress_view(ws: Variant) -> String:
	var out: String = ""
	for m in [1, 2, 3, 4]:
		out += "M%d:%d " % [m, int(ws.mystery_stage(m))]
	return out.strip_edges()
