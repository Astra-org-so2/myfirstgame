# Unit: SaveManager — the recovery matrix with real file I/O
# (Phase 15, TECHNICAL_DESIGN §3). The seam: a private user://
# path (the production user://save/ is untouched).
extends Node

const _MGR = preload("res://scripts/gameplay/save/save_manager.gd")
const _DATA = preload("res://scripts/gameplay/save/save_data.gd")

const PATH: String = "user://save_test/test.json"


func _world(v: int = 7) -> Dictionary:
	return {
		"version": 1,
		"flags": {"kettle_washed": true},
		"inheritances": {"sharp": v},
		"weapons": {"weapon_blade": true},
		"npcs": {},
		"notes": {},
		"mystery_progress": {},
		"runs": {"full": [], "summaries": []},
	}


func _clean() -> void:
	for suffix in ["", ".bak", ".tmp", ".corrupt_corrupt",
			".corrupt_unreadable"]:
		DirAccess.remove_absolute(PATH + suffix)


func run(ctx: Variant) -> void:
	_clean()
	var mgr: _MGR = _MGR.new()
	mgr.path = PATH
	add_child(mgr)
	await get_tree().process_frame

	# --- empty: no file at all ---
	var r: Dictionary = mgr.load()
	ctx.check(str(r.status) == "empty",
			"svmgr: no file = empty (got %s)" % str(r.status))

	# --- save -> ok round-trip ---
	var settings: Dictionary = {"quality": "high",
			"audio": {"master": 0.8, "muted": false}}
	ctx.check(mgr.save(_world(), settings), "svmgr: save succeeds")
	r = mgr.load()
	ctx.check(str(r.status) == "ok",
			"svmgr: the saved file loads (got %s)" % str(r.status))
	var w: Dictionary = r.world
	ctx.check(int((w.get("inheritances", {}) as Dictionary)["sharp"]) == 7,
			"svmgr: the world round-trips")
	ctx.check(str((r.settings as Dictionary).quality) == "high",
			"svmgr: the settings round-trip")

	# --- the backup: the previous valid file becomes .bak ---
	ctx.check(FileAccess.file_exists(PATH + ".bak") == false,
			"svmgr: no backup before the 2nd save")
	ctx.check(mgr.save(_world(8), settings), "svmgr: the 2nd save")
	ctx.check(FileAccess.file_exists(PATH + ".bak"),
			"svmgr: the backup appears after the 2nd save")

	# --- corrupt main + valid bak -> recovered_bak ---
	var f: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string("{ this is not json")
	f.close()
	r = mgr.load()
	ctx.check(str(r.status) == "recovered_bak",
			"svmgr: corrupt main + valid bak = recovered_bak (got %s)"
			% str(r.status))
	ctx.check(int((r.world as Dictionary)
			.get("inheritances", {}).get("sharp", -1)) == 7,
			"svmgr: the recovery restores the PREVIOUS save")
	ctx.check(FileAccess.file_exists(PATH + ".corrupt_corrupt"),
			"svmgr: the corrupt file is preserved")

	# --- corrupt BOTH -> fresh (the user data is preserved) ---
	f = FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string("garbage")
	f.close()
	f = FileAccess.open(PATH + ".bak", FileAccess.WRITE)
	f.store_string("also garbage")
	f.close()
	r = mgr.load()
	ctx.check(str(r.status) == "fresh",
			"svmgr: both corrupt = fresh (got %s)" % str(r.status))
	ctx.check((r.world as Dictionary).is_empty(),
			"svmgr: fresh = no world (safe defaults)")
	ctx.check(FileAccess.file_exists(PATH + ".corrupt_corrupt"),
			"svmgr: the bad main stays on disk")
	ctx.check(FileAccess.file_exists(PATH + ".bak.corrupt_corrupt"),
			"svmgr: the bad backup stays on disk")

	# --- the newer save: the file is UNTOUCHED, meta from the bak ---
	# A valid v2 file (the crc is recomputed for the new version).
	var d2: Dictionary = _DATA.build(_world(9), settings, 1)
	d2["version"] = 2
	d2["crc32"] = _DATA.crc_of(d2)
	f = FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(_DATA.canonical(d2))
	f.close()
	# A valid v1 backup (the v8 save's content).
	var dbak: Dictionary = _DATA.build(_world(8), settings, 1)
	f = FileAccess.open(PATH + ".bak", FileAccess.WRITE)
	f.store_string(_DATA.canonical(dbak))
	f.close()
	r = mgr.load()
	ctx.check(str(r.status) == "newer",
			"svmgr: the newer save is named (got %s)" % str(r.status))
	var v2now: String = ""
	var fr: FileAccess = FileAccess.open(PATH, FileAccess.READ)
	if fr != null:
		v2now = fr.get_as_text()
		fr.close()
	ctx.check(v2now == _DATA.canonical(d2),
			"svmgr: the newer file is byte-identical (untouched)")
	ctx.check(int((r.world as Dictionary)
			.get("inheritances", {}).get("sharp", -1)) == 8,
			"svmgr: the meta comes from the backup, not the newer file")

	# --- kill-mid-write: a crash between the .tmp write and the
	#     rename leaves a PARTIAL tmp + the intact old file. The
	#     load must take the old file (the tmp is never read) and
	#     the next save must clear the tmp. ---
	ctx.check(mgr.save(_world(3), settings), "svmgr: a good save")
	f = FileAccess.open(PATH + ".tmp", FileAccess.WRITE)
	f.store_string("{ partial write, cr")
	f.close()
	r = mgr.load()
	ctx.check(str(r.status) == "ok",
			"svmgr: kill-mid-write keeps the old file (got %s)"
			% str(r.status))
	ctx.check(int((r.world as Dictionary)
			.get("inheritances", {}).get("sharp", -1)) == 3,
			"svmgr: the old save wins over the partial tmp")
	ctx.check(mgr.save(_world(4), settings), "svmgr: the next save")
	ctx.check(not FileAccess.file_exists(PATH + ".tmp"),
			"svmgr: the stale tmp is gone after the next save")

	# --- a valid crc but a broken envelope -> treated corrupt ---
	var dbad: Dictionary = _DATA.build(_world(), settings, 1)
	dbad["world"] = "not a dict"
	dbad["crc32"] = _DATA.crc_of(dbad)
	DirAccess.remove_absolute(PATH)
	f = FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(_DATA.canonical(dbad))
	f.close()
	r = mgr.load()
	ctx.check(str(r.status) == "fresh" or str(r.status) == "recovered_bak",
			"svmgr: a broken envelope is not 'ok' (got %s)"
			% str(r.status))

	_clean()
	mgr.queue_free()
	await get_tree().process_frame
