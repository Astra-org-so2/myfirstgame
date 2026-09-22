# Unit: SaveData — the save format (TECHNICAL_DESIGN §3, Phase 15).
extends Node

const _D = preload("res://scripts/gameplay/save/save_data.gd")


func run(ctx: Variant) -> void:
	# --- CRC32: the standard test vector (RFC: "123456789" =
	#     0xCBF43926) — catches any implementation drift. ---
	var c: int = _D.crc32("123456789")
	ctx.check(c == 0xCBF43926,
			"savedata: the CRC32 vector (got 0x%08X)" % c)
	ctx.check(_D.crc32("") == 0x00000000,
			"savedata: the CRC32 of empty")

	# --- Build/parse round-trip ---
	var world: Dictionary = {
		"version": 1,
		"flags": {"kettle_washed": true, "boss_defeated": false},
		"inheritances": {"sharp": 2},
		"weapons": {"weapon_blade": true},
		"npcs": {"mara": {"alive": true, "trust": 2, "interactions": 4,
				"help_done": true, "gifts_given": false}},
		"notes": {"camp": {"line_id": 2, "run_id": 3, "t": 120000}},
		"mystery_progress": {1: 2},
		"runs": {"full": [{"run_id": 3, "seed": 7, "events": []}],
				"summaries": []},
	}
	var settings: Dictionary = {"quality": "high",
			"audio": {"master": 0.8, "muted": false}}
	var d: Dictionary = _D.build(world, settings, 1757760000)
	ctx.check(d.format == "ay_save", "savedata: the format tag")
	ctx.check(d.version == 1, "savedata: the version")
	ctx.check(str(d.crc32).length() == 8, "savedata: the crc hex")

	var text: String = _D.canonical(d)
	var back: Dictionary = _D.parse(text)
	ctx.check(back.size() == d.size(), "savedata: the parse round-trip")
	ctx.check(_D.verify(back).size() == 0,
			"savedata: the round-trip verifies (%s)"
			% str(_D.verify(back)))

	# --- Canonical: the key order is stable (sorted) ---
	var t1: String = _D.canonical({"b": 1, "a": 2})
	var t2: String = _D.canonical({"a": 2, "b": 1})
	ctx.check(t1 == t2, "savedata: canonical is order-free")

	# --- The verification matrix ---
	var good: Dictionary = _D.build(world, settings, 1)
	var tampered: Dictionary = good.duplicate(true)
	(tampered["world"] as Dictionary)["flags"]["boss_defeated"] = true
	var p: Array = _D.verify(tampered)
	ctx.check(p.has("crc_mismatch"),
			"savedata: a tampered world is caught (got %s)" % str(p))
	ctx.check(not p.has("format"),
			"savedata: a tamper is not mislabeled")

	var badfmt: Dictionary = good.duplicate(true)
	badfmt["format"] = "other"
	badfmt["crc32"] = _D.crc_of(badfmt)
	var p2: Array = _D.verify(badfmt)
	ctx.check(p2.has("format"), "savedata: the format is checked")

	var nover: Dictionary = good.duplicate(true)
	nover["version"] = 0
	nover["crc32"] = _D.crc_of(nover)
	ctx.check(_D.verify(nover).has("version"),
			"savedata: the version is checked")

	var noworld: Dictionary = good.duplicate(true)
	noworld.erase("world")
	noworld["crc32"] = _D.crc_of(noworld)
	ctx.check(_D.verify(noworld).has("world"),
			"savedata: the world section is checked")

	var nocrc: Dictionary = good.duplicate(true)
	nocrc.erase("crc32")
	ctx.check(_D.verify(nocrc).has("crc_missing"),
			"savedata: a missing crc is checked")

	# --- Parse failures ---
	ctx.check(_D.parse("not json").is_empty(),
			"savedata: non-json -> empty")
	ctx.check(_D.parse("[1,2]").is_empty(),
			"savedata: a non-dict json -> empty")
