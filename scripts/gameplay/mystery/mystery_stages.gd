# MysteryStages — the MVP stage table (MYSTERY_REVEAL_MAP section 5:
# M1 stages 1-4, M2/M3/M4 stages 1-3). validate() enforces the
# reveal rules as DATA invariants (the no-fake rule: a broken table
# is a build error, not a runtime surprise):
#   - unique stage ids;
#   - per mystery: sequential stages 1..N (no gaps);
#   - no early reveal: flag_req(stage n) is the flag_set of some
#     earlier stage of the same mystery (the chain);
#   - ambiguity budget: a spoken line fits its max_words.
class_name MysteryStages
extends Resource

const _STAGE = preload("res://scripts/gameplay/mystery/mystery_stage.gd")

@export var stages: Array = []  # Array[MysteryStage]


func stage(id: StringName) -> _STAGE:
	for s in stages:
		var st: _STAGE = s
		if st.stage_id == id:
			return st
	return null


# The stages of one mystery, in stage order.
func of(mystery: int) -> Array:
	var out: Array = []
	for s in stages:
		var st: _STAGE = s
		if st.mystery == mystery:
			out.append(st)
	out.sort_custom(func(a, b):
		var sa: _STAGE = a
		var sb: _STAGE = b
		return sa.stage < sb.stage)
	return out


func validate() -> Array:
	var problems: Array = []
	var seen: Dictionary = {}
	var by_mystery: Dictionary = {}
	for s in stages:
		var st: _STAGE = s
		if seen.has(st.stage_id):
			problems.append("duplicate stage id: %s" % st.stage_id)
		seen[st.stage_id] = true
		if st.mystery < 1 or st.mystery > 4:
			problems.append("%s: mystery out of range" % st.stage_id)
		if not by_mystery.has(st.mystery):
			by_mystery[st.mystery] = []
		(by_mystery[st.mystery] as Array).append(st)
	for m in by_mystery:
		var list: Array = (by_mystery[m] as Array).duplicate()
		list.sort_custom(func(a, b):
			var sa: _STAGE = a
			var sb: _STAGE = b
			return sa.stage < sb.stage)
		var prev_sets: Dictionary = {}
		for i in list.size():
			var st: _STAGE = list[i]
			if st.stage != i + 1:
				problems.append("M%d: stage gap/dup at %d (id %s)"
						% [m, st.stage, st.stage_id])
			if i > 0 and st.flag_req != "" \
					and not prev_sets.has(st.flag_req):
				problems.append("%s: flag_req %s is not set by an "
						+ "earlier M%d stage (no early reveal)"
						% [st.stage_id, st.flag_req, m])
			if st.flag_set != "":
				prev_sets[st.flag_set] = true
			if st.line != "" and _word_count(st.line) > st.max_words:
				problems.append("%s: the line exceeds the ambiguity "
						+ "budget (%d > %d words)"
						% [st.stage_id, _word_count(st.line),
								st.max_words])
	return problems


static func _word_count(text: String) -> int:
	var words: PackedStringArray = text.split(" ", true)
	var n: int = 0
	for w in words:
		if w != "":
			n += 1
	return n
