# SpawnEntry — one spawn rule in a SpawnTable (data-driven; new
# content = new .tres, no code — TECHNICAL_DESIGN §1).
class_name SpawnEntry
extends Resource

const _ENEMY_DATA = preload("res://scripts/gameplay/enemies/enemy_data.gd")

@export var enemy: _ENEMY_DATA
# Spawn point in hub-local world coordinates.
@export var position: Vector3 = Vector3.ZERO
# Spawn rule (ENEMY_DESIGN §6 spawn-правило; production zones are
# Phases 7/8 — Phase 5 evaluates the MVP subset, see EnemyDirector
# .should_spawn):
#   "" / "always"  — unconditionally
#   "slayer"      — aggression profile: slayer
#   "runner"      — aggression profile: runner
#   "explorer"    — aggression profile: explorer
#   "style:melee" | "style:ranged" | "style:dodge" — dominant style
#   "first_run"   — runs_completed == 0
@export var condition: String = "always"
# Spawn noise (m): a spawn burst this loud is HEARD by enemies this
# far (0 = silent placement — Watcher, Forgotten guards).
@export var noise_radius: float = 0.0
# The area this run spawn belongs to ("" = table-level, camp; the
# generator fills it for the zone spawns, Phase 7).
@export var area: StringName = &""


func validate() -> Array[String]:
	var problems: Array[String] = []
	if enemy == null:
		problems.append("enemy data is required")
	if noise_radius < 0.0:
		problems.append("noise_radius must be >= 0")
	return problems
