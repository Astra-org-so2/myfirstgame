# Unit: P19 (FINAL_REVIEW, localization lock): every user-visible string
# passes through Godot's localization layer (tr()). This test closes the
# loop mechanically:
#   1. extract every tr() key from the game scripts — both the plain
#      literals (tr("...")) and the const/dict references
#      (tr(LINE_X), tr(String(WEAPON_LINES[wid]))) with their values
#      resolved from the source;
#   2. the extracted key set MUST equal the en column of
#      res://data/loc/strings.csv (no code string without a RU draft,
#      no CSV row without a use site);
#   3. every ru value is non-empty.
# Excluded by design (documented in FINAL_REVIEW): pure symbols
# ("!", "X", "· "), the proper-noun label "VEYRA B", node names and
# push_error/log messages (developer-facing, not user-visible).
#
# NOTE: the wasm rig exposes no Dir/RegEx classes — this test uses
# DirAccess + plain string scanning only (same constraint as game code).
extends Node

const _CSV_PATH: String = "res://data/loc/strings.csv"
const _SCRIPTS_DIR: String = "res://scripts"


func run(ctx: Variant) -> void:
	var csv: Dictionary = _load_csv()
	ctx.check(csv.size() >= 60,
			"loc: csv row count (full inventory, got %d)" % csv.size())
	var code_keys: Dictionary = _extract_code_keys()
	ctx.check(code_keys.size() >= 60,
			"loc: tr() keys found in code (got %d)" % code_keys.size())
	var missing: Array = _missing(code_keys, csv)
	ctx.check(missing.is_empty(),
			"loc: every tr() key has a CSV row (%s)" % str(missing))
	var orphans: Array = _missing(csv, code_keys)
	ctx.check(orphans.is_empty(),
			"loc: every CSV row is used in code (%s)" % str(orphans))
	var bad_ru: Array = []
	for k in csv.keys():
		if String(csv[k]).strip_edges().is_empty():
			bad_ru.append(k)
	ctx.check(bad_ru.is_empty(),
			"loc: every RU translation is non-empty (%s)" % str(bad_ru))


# --- CSV ------------------------------------------------------------------

func _load_csv() -> Dictionary:
	var f: FileAccess = FileAccess.open(_CSV_PATH, FileAccess.READ)
	if f == null:
		return {}
	f.get_line() # the locale header (en,ru)
	var keys: Dictionary = {}
	while not f.eof_reached():
		var line: String = f.get_line()
		if line.strip_edges().is_empty():
			continue
		var parts: PackedStringArray = _split_csv(line)
		if parts.size() < 2:
			continue
		keys[parts[0]] = parts[1]
	return keys


# Minimal RFC-4180 split: quote a field if it has commas/quotes.
func _split_csv(line: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var cur: String = ""
	var in_q: bool = false
	var i: int = 0
	while i < line.length():
		var c: String = line[i]
		if in_q:
			if c == "\"":
				if i + 1 < line.length() and line[i + 1] == "\"":
					cur += "\""
					i += 1
				else:
					in_q = false
			else:
				cur += c
		elif c == "\"":
			in_q = true
		elif c == ",":
			out.append(cur)
			cur = ""
		else:
			cur += c
		i += 1
	out.append(cur)
	return out


# --- code-side extraction (string scanning — no RegEx in the rig) ---------

func _extract_code_keys() -> Dictionary:
	var keys: Dictionary = {}
	for rel in _collect_scripts(_SCRIPTS_DIR):
		var f: FileAccess = FileAccess.open("res://" + rel, FileAccess.READ)
		if f == null:
			continue
		var src: String = f.get_as_text()
		f.close()
		for key in _keys_in_source(src):
			keys[key] = true
	return keys


func _collect_scripts(base: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var d: DirAccess = DirAccess.open(base)
	if d == null:
		return out
	d.list_dir_begin()
	var name: String = d.get_next()
	while name != "":
		if name != "." and name != ".." and not name.begins_with("."):
			var full: String = base.path_join(name)
			if d.current_is_dir():
				out.append_array(_collect_scripts(full))
			elif name.ends_with(".gd"):
				out.append(full)
		name = d.get_next()
	d.list_dir_end()
	return out


# All tr() keys of one source: literals + resolved const/dict references.
func _keys_in_source(src: String) -> Array:
	var out: Array = []
	# 1) literals: tr("...")
	var i: int = 0
	while true:
		i = src.find('tr("', i)
		if i < 0:
			break
		if i > 0 and _is_ident_char(src[i - 1]):
			i += 4
			continue
		var j: int = i + 4
		while j < src.length() and not (src[j] == "\"" and src[j - 1] != "\\"):
			j += 1
		if j >= src.length():
			break
		out.append(src.substr(i + 4, j - i - 4))
		i = j + 1
	# 2) const references: tr(LINE_X) — resolve the const value
	i = 0
	while true:
		i = src.find("tr(LINE_", i)
		if i < 0:
			break
		if i > 0 and _is_ident_char(src[i - 1]):
			i += 8
			continue
		# the name starts right after "tr(" (3 chars); digits allowed
		# (LINE_A12_NOTE, LINE_D6, ...)
		var end: int = i + 3
		while end < src.length() and _is_name_char(src[end]):
			end += 1
		var cname: String = src.substr(i + 3, end - i - 3)
		var val: String = _const_value(src, cname)
		out.append(val if val != "" else "<unresolved:" + cname + ">")
		i = end
	# 3) dict references: tr(String(NAME[...])) — all values of the dict
	i = 0
	while true:
		i = src.find("tr(String(", i)
		if i < 0:
			break
		if i > 0 and _is_ident_char(src[i - 1]):
			i += 10
			continue
		# the name starts right after "tr(String(" (10 chars)
		var d2: int = i + 10
		while d2 < src.length() and _is_ident_char(src[d2]):
			d2 += 1
		var dname: String = src.substr(i + 10, d2 - i - 10)
		for v in _dict_values(src, dname):
			out.append(v)
		i = d2
	return out


# The value of `const NAME: String = ...` (literal, line continuation or
# parenthesized concatenation). "" = not found.
func _const_value(src: String, name: String) -> String:
	var needle: String = "const " + name + ": String = "
	var i: int = src.find(needle)
	if i < 0:
		return ""
	var p: int = i + needle.length()
	while p < src.length() and src[p] in [" ", "\t", "\n", "\r"]:
		p += 1
	if p >= src.length():
		return ""
	if src[p] == "\"":
		return _read_string(src, p)
	if src[p] == "\\":
		# continuation: the value starts at the next quote
		var q: int = src.find("\"", p)
		if q < 0:
			return ""
		return _read_string(src, q)
	if src[p] == "(":
		# concatenation: collect every string fragment up to the close
		var out: String = ""
		var depth: int = 0
		var in_str: bool = false
		var cur: int = p
		while cur < src.length():
			var c: String = src[cur]
			if in_str:
				if c == "\"":
					in_str = false
				else:
					out += c
			elif c == "\"":
				in_str = true
			elif c == "(":
				depth += 1
			elif c == ")":
				depth -= 1
				if depth == 0:
					break
			cur += 1
		return out
	return ""


func _read_string(src: String, open_q: int) -> String:
	var j: int = open_q + 1
	while j < src.length() and not (src[j] == "\"" and src[j - 1] != "\\"):
		j += 1
	if j >= src.length():
		return ""
	return src.substr(open_q + 1, j - open_q - 1)


func _dict_values(src: String, name: String) -> Array:
	var out: Array = []
	var needle: String = "const " + name + ": Dictionary = {"
	var i: int = src.find(needle)
	if i < 0:
		return out
	var p: int = i + needle.length()
	var end: int = src.find("}", p)
	if end < 0:
		return out
	var body: String = src.substr(p, end - p)
	var j: int = 0
	while true:
		var k: int = body.find(": ", j)
		if k < 0:
			break
		# value = the string literal after the colon (any spacing)
		var q: int = k + 1
		while q < body.length() and body[q] != "\"":
			q += 1
		var e: int = q + 1
		while e < body.length() and not (body[e] == "\"" and body[e - 1] != "\\"):
			e += 1
		if e >= body.length():
			break
		out.append(body.substr(q + 1, e - q - 1))
		j = e + 1
	return out


func _is_ident_char(c: String) -> bool:
	# The rig's String API lacks is_lower/is_upper — lexicographic ranges.
	return (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or c == "_"


func _is_name_char(c: String) -> bool:
	# Identifier + digits (const names: LINE_A12_NOTE, LINE_D6, ...)
	return _is_ident_char(c) or (c >= "0" and c <= "9")


func _missing(a: Dictionary, b: Dictionary) -> Array:
	var out: Array = []
	for k in a.keys():
		if not b.has(k):
			out.append(k)
	return out
