# SaveMigrator — the version chain (TECHNICAL_DESIGN §3, Phase 15).
#
# Pure (RefCounted): each step is a function dict -> dict (or null
# on an invalid source), registered per FROM-version. migrate()
# walks the chain up to the target; a missing step = the unknown
# gap -> the recovery path (the manager decides: backup or fresh).
#
# Today the target is v1, so the production chain is empty — the
# mechanism (chain walking, the newer-save rule, the gap failure)
# is real and unit-tested with a registered step.
class_name SaveMigrator
extends RefCounted

var target: int = 1
var _steps: Dictionary = {}  # from_version(int) -> Callable


func set_target(v: int) -> void:
	target = maxi(1, v)


func register_step(from_version: int, step: Callable) -> void:
	_steps[from_version] = step


# {ok: bool, dict: Dictionary, error: String}
func migrate(d: Dictionary) -> Dictionary:
	if not d.has("version"):
		return {
			"ok": false, "dict": {}, "error": "missing_version",
		}
	var v: int = int(d["version"])
	if v > target:
		# A save from a NEWER game: never touch it (the meta
		# restore comes from the backup, not from here).
		return {
			"ok": false, "dict": {}, "error": "newer_save",
		}
	var cur: Dictionary = d
	while v < target:
		if not _steps.has(v):
			return {
				"ok": false, "dict": {}, "error": "no_migration_from_v%d" % v,
			}
		var step: Callable = _steps[v]
		var out: Variant = step.call(cur)
		if typeof(out) != TYPE_DICTIONARY:
			return {
				"ok": false, "dict": {}, "error": "step_v%d_invalid" % v,
			}
		var nv: int = int((out as Dictionary).get("version", -1))
		if nv <= v:
			# A step must advance the version (no infinite loops).
			return {
				"ok": false, "dict": {}, "error": "step_v%d_no_progress" % v,
			}
		cur = out
		v = nv
	return {"ok": true, "dict": cur, "error": ""}
