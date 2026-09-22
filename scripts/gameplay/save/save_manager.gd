# SaveManager — the save/load/recovery (TECHNICAL_DESIGN §3, P15).
#
# One slot file (user://save/ay_save.json), the recovery matrix:
#   ok              — the file is valid (migrated to current);
#   empty           — no file yet (fresh world, the normal first
#                     boot);
#   recovered_bak   — the file is corrupt, the backup is valid
#                     (restored, the bad file preserved as .corrupt);
#   fresh           — both are bad/missing (fresh world; the bad
#                     file is preserved as .corrupt — user data is
#                     never destroyed, the scene shows the note);
#   newer           — a save from a NEWER game: the file is NOT
#                     touched; the meta is restored from the
#                     backup (or safe defaults).
#
# Writes are atomic-ish (TECHNICAL_DESIGN §3): write to .tmp ->
# flush -> close -> DirAccess.rename (POSIX/NTFS atomic on the
# file). A crash between steps leaves the OLD or the NEW file,
# never a torn one. The previous valid file is kept as .bak.
#
# Scene composition (not an autoload — ADR-023): main_scene owns
# it. The manager deals in DICTS (the world section is
# WorldState.to_dict(); the scene applies load_dict) — no
# progression dependency.
class_name SaveManager
extends Node

const _DATA = preload("res://scripts/gameplay/save/save_data.gd")
const _MIG = preload("res://scripts/gameplay/save/save_migrator.gd")

const DEFAULT_PATH: String = "user://save/ay_save.json"
const MAX_SAVE_BYTES: int = 5 * 1024 * 1024  # the hard cap (§3)

# Overridable for tests (the res:// seam); production = user://.
var path: String = DEFAULT_PATH

var _migrator: _MIG
signal saved(ok: bool, path: String)
signal loaded(status: String)


func _ready() -> void:
	_migrator = _MIG.new()
	_migrator.set_target(_DATA.SAVE_VERSION)


# The production migration chain (v1 = current: empty). A future
# v2 registers a step here (the mechanism is tested in unit with a
# registered step).
func register_migrations() -> void:
	pass


# --- Save -------------------------------------------------------------------

# Save the world section + the settings. Returns false (and keeps
# the previous file) on any failure — a failed save never destroys
# a good save.
func save(world: Dictionary, settings: Dictionary) -> bool:
	if not _ensure_dir():
		return false
	var d: Dictionary = _DATA.build(world, settings,
			Time.get_unix_time_from_system())
	var text: String = _DATA.canonical(d)
	# The 5 MB hard cap: the runs section is the only growing part
	# (RunHistory already trims at runtime; this is the file-level
	# last line).
	while text.length() > MAX_SAVE_BYTES \
			and _runs_full_count(world) >= 2:
		_shrink_runs(world)
		d = _DATA.build(world, settings,
				Time.get_unix_time_from_system())
		text = _DATA.canonical(d)
	if text.length() > MAX_SAVE_BYTES:
		push_error("SaveManager: the save exceeds the hard cap "
				+ "(%d bytes) — not written" % text.length())
		saved.emit(false, path)
		return false
	_backup_current()
	if not _atomic_write(text):
		return false
	saved.emit(true, path)
	return true


# --- Load -------------------------------------------------------------------

# The load matrix (the return: {status, world, settings}).
# world = {} when there is nothing to restore (the scene starts
# fresh); settings = {} when absent (safe defaults).
#
# The two file families: CORRUPT files are quarantined (preserved
# as .corrupt_*, never deleted); INTACT files the game cannot read
# (newer version, an unmigratable gap) are left UNTOUCHED — they
# are the user's save for another build.
func load() -> Dictionary:
	# 1. The main file.
	var d: Dictionary = _read_valid(path)
	if not d.is_empty():
		var m: Dictionary = _migrator.migrate(d)
		if m.ok:
			var md: Dictionary = m.dict
			loaded.emit("ok")
			return {
				"status": "ok",
				"world": md.get("world", {}),
				"settings": _as_dict(md.get("settings", {})),
			}
		if str(m.error) == "newer_save" \
				or str(m.error).begins_with("no_migration_from"):
			# Intact, but not for this build: keep it; the meta
			# comes from the backup (or safe defaults).
			var meta: Dictionary = _backup_meta()
			meta["status"] = "newer" if str(m.error) == "newer_save" \
					else "fresh"
			push_warning("SaveManager: the save is not readable by "
					+ "this build (%s) — kept, playing from the "
					+ "backup" % str(m.error))
			loaded.emit(str(meta.status))
			return meta
		# A valid parse with a failed verify should be unreachable
		# (_read_valid only returns verified dicts) — fall through
		# to the backup with the file preserved.
	# 2. No valid main file: quarantine a corrupt one (preserved),
	#    then the backup, then fresh/empty.
	var had_file: bool = FileAccess.file_exists(path)
	if had_file:
		_quarantine(path, "corrupt")
	var had_bak: bool = FileAccess.file_exists(path + ".bak")
	var bak: Dictionary = _read_valid(path + ".bak")
	if not bak.is_empty():
		var bm: Dictionary = _migrator.migrate(bak)
		if bm.ok:
			var bd: Dictionary = bm.dict
			# Restore the backup as the live file.
			_atomic_write(_DATA.canonical(bd))
			loaded.emit("recovered_bak")
			return {
				"status": "recovered_bak",
				"world": bd.get("world", {}),
				"settings": _as_dict(bd.get("settings", {})),
			}
	# The backup is corrupt (unparseable): preserve it too. An
	# intact-but-unmigratable backup (newer build) is left alone.
	if had_bak and bak.is_empty():
		_quarantine(path + ".bak", "corrupt")
	var status: String = "fresh" if (had_file or had_bak) else "empty"
	loaded.emit(status)
	return {"status": status, "world": {}, "settings": {}}


# The meta (world + settings) from the backup, or safe defaults.
# The backup is NEVER touched here (the caller decides the
# quarantine).
func _backup_meta() -> Dictionary:
	var bak: Dictionary = _read_valid(path + ".bak")
	var meta: Dictionary = {"world": {}, "settings": {}}
	if not bak.is_empty():
		var bm: Dictionary = _migrator.migrate(bak)
		if bm.ok:
			meta["world"] = (bm.dict as Dictionary).get("world", {})
			meta["settings"] = _as_dict(
					(bm.dict as Dictionary).get("settings", {}))
	return meta


# --- Internals ------------------------------------------------------------------

# Read + verify + (the caller migrates). {} when absent/invalid.
func _read_valid(p: String) -> Dictionary:
	if not FileAccess.file_exists(p):
		return {}
	var f: FileAccess = FileAccess.open(p, FileAccess.READ)
	if f == null:
		return {}
	var text: String = f.get_as_text()
	f.close()
	var d: Dictionary = _DATA.parse(text)
	if _DATA.verify(d).size() > 0:
		return {}
	return d


# Preserve the bad file for the user (the «данные: <path>» note)
# and back it up under a quarantined name.
func _quarantine(p: String, reason: String) -> void:
	var q: String = p + ".corrupt_%s" % reason
	if DirAccess.rename_absolute(p, q) != OK:
		push_warning("SaveManager: cannot quarantine %s (%s)" % [p, reason])


func _backup_current() -> void:
	# The previous VALID file becomes the backup (an invalid file
	# is never promoted to .bak).
	if not FileAccess.file_exists(path):
		return
	if _read_valid(path).is_empty():
		return
	var bak: String = path + ".bak"
	if _copy_file(path, bak) != OK:
		push_warning("SaveManager: backup copy failed for " + path)


func _copy_file(from: String, to: String) -> Error:
	var f: FileAccess = FileAccess.open(from, FileAccess.READ)
	if f == null:
		return ERR_FILE_CANT_OPEN
	var raw: PackedByteArray = f.get_buffer(f.get_length())
	f.close()
	var o: FileAccess = FileAccess.open(to, FileAccess.WRITE)
	if o == null:
		return ERR_FILE_CANT_OPEN
	o.store_buffer(raw)
	o.flush()
	o.close()
	return OK


func _atomic_write(text: String) -> bool:
	var tmp: String = path + ".tmp"
	var f: FileAccess = FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("SaveManager: cannot write %s" % tmp)
		return false
	f.store_string(text)
	f.flush()
	f.close()
	if DirAccess.rename_absolute(tmp, path) != OK:
		push_error("SaveManager: rename %s -> %s failed" % [tmp, path])
		DirAccess.remove_absolute(tmp)
		return false
	return true


func _ensure_dir() -> bool:
	var dir: String = path.get_base_dir()
	if dir == "":
		return true
	var err: Error = DirAccess.make_dir_recursive_absolute(dir)
	return err == OK or err == ERR_ALREADY_EXISTS


func _runs_full_count(world: Dictionary) -> int:
	var runs: Variant = world.get("runs", {})
	if typeof(runs) != TYPE_DICTIONARY:
		return 0
	var full: Variant = (runs as Dictionary).get("full", [])
	if typeof(full) != TYPE_ARRAY:
		return 0
	return (full as Array).size()


func _shrink_runs(world: Dictionary) -> void:
	var runs: Dictionary = world.get("runs", {})
	var full: Array = runs.get("full", [])
	if full.size() < 2:
		return
	var oldest: Dictionary = full[0]
	full.remove_at(0)
	var summaries: Array = runs.get("summaries", [])
	# Reduce to a summary (the record's own fields, minus the log).
	var s: Dictionary = {
		"run_id": oldest.get("run_id", 0),
		"seed": oldest.get("seed", 0),
		"deaths": oldest.get("deaths", 0),
		"kills": oldest.get("kills", 0),
		"duration_ms": oldest.get("duration_ms", 0),
	}
	summaries.insert(0, s)
	while summaries.size() > 64:
		summaries.pop_back()
	runs["summaries"] = summaries
	world["runs"] = runs
	push_warning("SaveManager: save over the cap — the oldest full "
			+ "run was reduced to a summary")


static func _as_dict(v: Variant) -> Dictionary:
	if typeof(v) == TYPE_DICTIONARY:
		return v
	return {}
