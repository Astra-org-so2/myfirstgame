# SaveData — the save format (TECHNICAL_DESIGN §3, Phase 15).
#
# Pure static functions (unit-testable headless): the JSON envelope
# (format/version/saved_at/engine_version/world/settings/crc32),
# the canonical JSON (sorted keys — a stable CRC target), and the
# CRC32 (IEEE 802.3) integrity check. The File I/O and the
# recovery matrix live in SaveManager; the version chain lives in
# SaveMigrator.
class_name SaveData
extends RefCounted

const FORMAT: String = "ay_save"
const SAVE_VERSION: int = 1
const ENGINE_VERSION: String = "4.7.2"


# The full envelope. `world` is the WorldState.to_dict() section
# (it carries its own "version" — the world format version).
static func build(world: Dictionary, settings: Dictionary,
		saved_at_unix: int) -> Dictionary:
	var body: Dictionary = {
		"format": FORMAT,
		"version": SAVE_VERSION,
		"saved_at_unix": int(saved_at_unix),
		"engine_version": ENGINE_VERSION,
		"world": world,
		"settings": settings,
	}
	body["crc32"] = crc_of(body)
	return body


# The CRC over the canonical body (everything except the crc32
# field itself). Hex string, lowercase.
static func crc_of(body: Dictionary) -> String:
	var d: Dictionary = body.duplicate()
	d.erase("crc32")
	return _to_hex(crc32(canonical(d)))


# Canonical JSON: keys sorted (JSON.stringify default) AND numbers
# normalized (an integer-valued float is written as an int). The
# normalization is what makes the CRC stable across the int ->
# float JSON parse cycle (Godot's parser returns floats for every
# number: 1757760000 would otherwise come back "1757760000.0").
static func canonical(d: Dictionary) -> String:
	return JSON.stringify(_norm_numbers(d))


static func _norm_numbers(v: Variant) -> Variant:
	match typeof(v):
		TYPE_DICTIONARY:
			var out: Dictionary = {}
			for k in v:
				out[str(k)] = _norm_numbers(v[k])
			return out
		TYPE_ARRAY:
			var out: Array = []
			for e in v:
				out.append(_norm_numbers(e))
			return out
		TYPE_FLOAT:
			var f: float = v
			if is_zero_approx(f - roundf(f)):
				return int(f)
			return f
		_:
			return v


static func parse(text: String) -> Dictionary:
	var v: Variant = JSON.parse_string(text)
	if typeof(v) != TYPE_DICTIONARY:
		return {}
	return v


# The verification matrix (every failure is a named problem, not
# an exception): the envelope must exist and be sane before the
# CRC is even trusted.
static func verify(d: Dictionary) -> Array:
	var problems: Array = []
	if d.is_empty():
		problems.append("empty")
		return problems
	if str(d.get("format", "")) != FORMAT:
		problems.append("format")
	var v: int = int(d.get("version", -1))
	if v < 1:
		problems.append("version")
	if not d.has("world") or typeof(d.get("world")) != TYPE_DICTIONARY:
		problems.append("world")
	var crc: String = str(d.get("crc32", ""))
	if crc == "":
		problems.append("crc_missing")
	elif crc != crc_of(d):
		problems.append("crc_mismatch")
	return problems


# CRC32, IEEE 802.3 (the standard reflected polynomial 0xEDB88320,
# init/xorout 0xFFFFFFFF) over the UTF-8 bytes. Bit-by-bit: the
# save is small (5 MB hard cap, realistically < 1 MB) — no table,
# no memory cost. (The rig has no String.to_utf8 — the UTF-8
# encoding is inline; the JSON is ASCII in practice, the multi-
# byte path is there for the non-ASCII note lines.)
static func crc32(data: String) -> int:
	var crc: int = 0xFFFFFFFF
	var i: int = 0
	while i < data.length():
		var code: int = data.unicode_at(i)
		if code < 0x80:
			crc = _crc_byte(crc, code)
		elif code < 0x800:
			crc = _crc_byte(crc, 0xC0 | (code >> 6))
			crc = _crc_byte(crc, 0x80 | (code & 0x3F))
		elif code < 0x10000:
			crc = _crc_byte(crc, 0xE0 | (code >> 12))
			crc = _crc_byte(crc, 0x80 | ((code >> 6) & 0x3F))
			crc = _crc_byte(crc, 0x80 | (code & 0x3F))
		else:
			# A surrogate pair: combine, then 4 bytes.
			var high: int = code
			var low: int = 0
			if i + 1 < data.length():
				low = data.unicode_at(i + 1)
			if low >= 0xDC00 and low <= 0xDFFF:
				code = 0x10000 + ((high - 0xD800) << 10) \
						+ (low - 0xDC00)
				i += 1
			crc = _crc_byte(crc, 0xF0 | (code >> 18))
			crc = _crc_byte(crc, 0x80 | ((code >> 12) & 0x3F))
			crc = _crc_byte(crc, 0x80 | ((code >> 6) & 0x3F))
			crc = _crc_byte(crc, 0x80 | (code & 0x3F))
		i += 1
	return crc ^ 0xFFFFFFFF


static func _crc_byte(crc: int, b: int) -> int:
	var c: int = crc ^ (b & 0xFF)
	for k in 8:
		var mask: int = -(c & 1)
		c = (c >> 1) ^ (0xEDB88320 & mask)
	return c


static func _to_hex(v: int) -> String:
	var s: String = ""
	for i in 8:
		s = _hex_nibble((v >> (i * 4)) & 0xF) + s
	return s


static func _hex_nibble(n: int) -> String:
	match n:
		0: return "0"
		1: return "1"
		2: return "2"
		3: return "3"
		4: return "4"
		5: return "5"
		6: return "6"
		7: return "7"
		8: return "8"
		9: return "9"
		10: return "a"
		11: return "b"
		12: return "c"
		13: return "d"
		14: return "e"
		_: return "f"
