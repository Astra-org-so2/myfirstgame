# RunHistory — all runs of the session (TECHNICAL_DESIGN §3,
# WORLD_STATE_DESIGN §1): the world_state "runs" section.
#
#   full[]: recent runs with full event logs (ghost replay source);
#   summaries[]: older runs reduced to RunSummary (≤ 64);
#   5 MB hard cap on the whole section → the oldest FULL run is reduced
#   to a summary (logged); summaries beyond 64 are dropped oldest-first.
#
# Pure (RefCounted): the save system serializes to_dict(), restores with
# load_dict(). MVP scale: 10–15 runs ≈ 150 KB (TECHNICAL_DESIGN §3).
class_name RunHistory
extends RefCounted

const _RR = preload("res://scripts/gameplay/run/run_record.gd")
const _RS = preload("res://scripts/gameplay/run/run_summary.gd")

# 5 MB hard cap (TECHNICAL_DESIGN §3).
const MAX_SECTION_BYTES: int = 5 * 1024 * 1024
# Summary list cap.
const MAX_SUMMARIES: int = 64

var full: Array = []  # Array[RunRecord]
var summaries: Array = []  # Array[RunSummary]


func add_run(r) -> void:
	full.append(r)
	_enforce_cap()


func _enforce_cap() -> void:
	while section_bytes() > MAX_SECTION_BYTES and full.size() >= 2:
		var oldest: Variant = full[0]
		var s := _RS.new()
		s.init_from_record(oldest)
		summaries.insert(0, s)
		full.remove_at(0)
		push_warning(("RunHistory: runs section over 5 MB — run %d "
				+ "reduced to summary") % oldest.run_id)
	while summaries.size() > MAX_SUMMARIES:
		summaries.pop_back()


# Estimated serialized size of the whole runs section (the save budget
# check). Uses the real JSON text length (not a guess).
func section_bytes() -> int:
	return String(JSON.stringify(to_dict())).length()


func get_run(run_id: int):
	for i in full.size():
		if full[i].run_id == run_id:
			return full[i]
	return null


func latest():
	if full.is_empty():
		return null
	return full[full.size() - 1]


# ---- JSON -------------------------------------------------------------

func to_dict() -> Dictionary:
	var f: Array = []
	for i in full.size():
		f.append(full[i].to_dict())
	var s: Array = []
	for i in summaries.size():
		s.append(summaries[i].to_dict())
	return {"full": f, "summaries": s}


func load_dict(d: Dictionary) -> void:
	full.clear()
	summaries.clear()
	var f: Array = d.get("full", [])
	for i in f.size():
		var r := _RR.new()
		r.load_dict(f[i])
		full.append(r)
	var s: Array = d.get("summaries", [])
	for i in s.size():
		var sm := _RS.new()
		sm.load_dict(s[i])
		summaries.append(sm)


func to_json() -> String:
	return JSON.stringify(to_dict())


func load_json(text: String) -> bool:
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("RunHistory.load_json: bad JSON (null)")
		return false
	load_dict(parsed)
	return true
