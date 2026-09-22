# Unit: SaveMigrator — the version chain (Phase 15).
extends Node

const _M = preload("res://scripts/gameplay/save/save_migrator.gd")


func _step_v0(d: Dictionary) -> Dictionary:
	# v0 -> v1: the v0 world section had no "version" inside; the
	# step stamps it (a real step shape).
	var out: Dictionary = d.duplicate(true)
	out["version"] = 1
	var w: Dictionary = out.get("world", {})
	w["version"] = 1
	out["world"] = w
	return out


func _bad_step(_d: Dictionary) -> Dictionary:
	return {}  # non-advancing (keeps version 0)


func _null_step(_d: Dictionary) -> Variant:
	return null


func run(ctx: Variant) -> void:
	var m: _M = _M.new()
	m.set_target(2)
	m.register_step(0, Callable(self, "_step_v0"))

	# Current version: passes through untouched.
	var cur: Dictionary = {"version": 2, "world": {"a": 1}}
	var r: Dictionary = m.migrate(cur)
	ctx.check(r.ok and (r.dict as Dictionary).world.a == 1,
			"migrator: the current version passes")

	# The chain: v0 -> (step) -> v1 -> (no step needed: target 2?
	# no — v1 < 2 and no v1 step) -> the gap is caught.
	var v0: Dictionary = {"version": 0, "world": {}}
	var r0: Dictionary = m.migrate(v0)
	ctx.check(not r0.ok and str(r0.error) == "no_migration_from_v1",
			"migrator: the missing step is the named gap (got %s)"
			% str(r0.error))

	# The full chain (target 1): v0 -> v1.
	var m2: _M = _M.new()
	m2.set_target(1)
	m2.register_step(0, Callable(self, "_step_v0"))
	var r2: Dictionary = m2.migrate(v0)
	ctx.check(r2.ok, "migrator: the chain completes")
	ctx.check(int((r2.dict as Dictionary)["version"]) == 1,
			"migrator: the chain advances the version")
	ctx.check(int(((r2.dict as Dictionary)["world"] as Dictionary)
			["version"]) == 1,
			"migrator: the step transforms the world section")

	# A newer save: never migrated, named error.
	var newer: Dictionary = {"version": 99, "world": {}}
	var rn: Dictionary = m2.migrate(newer)
	ctx.check(not rn.ok and str(rn.error) == "newer_save",
			"migrator: the newer save is refused (got %s)"
			% str(rn.error))

	# A missing version.
	var rm: Dictionary = m2.migrate({"world": {}})
	ctx.check(not rm.ok and str(rm.error) == "missing_version",
			"migrator: the missing version is named")

	# A step that does not advance (the loop guard).
	var m3: _M = _M.new()
	m3.set_target(1)
	m3.register_step(0, Callable(self, "_bad_step"))
	var rb: Dictionary = m3.migrate(v0)
	ctx.check(not rb.ok and str(rb.error) == "step_v0_no_progress",
			"migrator: a stuck step is caught (got %s)" % str(rb.error))

	# A step that returns non-dict.
	var m4: _M = _M.new()
	m4.set_target(1)
	m4.register_step(0, Callable(self, "_null_step"))
	var r4: Dictionary = m4.migrate(v0)
	ctx.check(not r4.ok and str(r4.error) == "step_v0_invalid",
			"migrator: a null step is caught (got %s)" % str(r4.error))
