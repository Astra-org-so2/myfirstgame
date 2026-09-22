# EchoBudgetState — the per-run budget counters (ADR-014).
#
# The scene composes one per run (GhostDirector owns it, EnemyDirector
# queries it): the spawn tables say «this echo MAY spawn here», the
# budget says «is this run's slot still free». RUN 1: all zero.
class_name EchoBudgetState
extends RefCounted

var run_id: int = 1
var passive_left: int = 0
var combat_left: int = 0
var special_left: int = 0


func init_run(p_run_id: int, p_passive: int, p_combat: int,
		p_special: int) -> void:
	run_id = p_run_id
	passive_left = maxi(0, p_passive)
	combat_left = maxi(0, p_combat)
	special_left = maxi(0, p_special)


func passive_remaining() -> int:
	return passive_left


func combat_remaining() -> int:
	return combat_left


func special_remaining() -> int:
	return special_left


func use_passive() -> void:
	passive_left = maxi(0, passive_left - 1)


func use_combat() -> void:
	combat_left = maxi(0, combat_left - 1)


func use_special() -> void:
	special_left = maxi(0, special_left - 1)
