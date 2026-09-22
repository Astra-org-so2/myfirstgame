# DialogueLines — the NPC mystery-line table (data/dialogue/).
# validate(): unique ids, the word budget (DIALOGUE_GUIDELINES 7:
# 12 words, the Archivist is the exception and never enters this
# table — the Archivist is whispers, not dialogue), and the char
# exists.
class_name DialogueLines
extends Resource

const _LINE = preload("res://scripts/gameplay/mystery/dialogue_line.gd")

@export var lines: Array = []  # Array[DialogueLine]
@export var known_chars: PackedStringArray = PackedStringArray()


func for_char(char: StringName, ws: Variant, run_id: int,
		used: Dictionary) -> _LINE:
	# Table order = priority (the first match wins).
	for l in lines:
		var ln: _LINE = l
		if ln.char != char:
			continue
		if used.has(ln.id) and not ln.repeat:
			continue
		if run_id < ln.run_req:
			continue
		if ln.flag_req != &"" and not ws.flag(ln.flag_req):
			continue
		var e: Dictionary = ws.npc_entry(char)
		if int(e.trust) < ln.trust_req:
			continue
		return ln
	return null


func mark_used(ln: _LINE, used: Dictionary) -> void:
	if not ln.repeat:
		used[ln.id] = true
	if ln.flag_set != &"":
		# The flag lands with the line (the scene shows the line).
		pass


func validate() -> Array:
	var problems: Array = []
	var seen: Dictionary = {}
	for l in lines:
		var ln: _LINE = l
		if seen.has(ln.id):
			problems.append("duplicate line id: %s" % ln.id)
		seen[ln.id] = true
		if not known_chars.has(String(ln.char)):
			problems.append("%s: unknown char %s" % [ln.id, ln.char])
		var words: int = 0
		for w in ln.text.split(" ", true):
			if w != "":
				words += 1
		if words > ln.max_words:
			problems.append("%s: exceeds the word budget (%d > %d)"
					% [ln.id, words, ln.max_words])
	return problems
