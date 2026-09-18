# EchoBudgetData — the per-run echo budget (ADR-014,
# ECHO_SYSTEM_DESIGN sections 7/8): which echoes may exist in run N.
#
# MVP (pre-boss): RUN 1 = 0 (no past yet), RUN 02/03 = 1 Passive +
# 1 Combat, RUN 04+ = +1 «special». Post-boss («тише», -2) arrives
# with the boss (Phase 12) as data, not code.
class_name EchoBudgetData
extends Resource

const _ROW = preload("res://scripts/gameplay/echo/echo_budget_row.gd")

@export var rows: Array = []  # Array[EchoBudgetRow]


# Pure (unit-tested): the budget row for a run id. Null = data bug
# (the caller falls back to "no echoes" — never "unlimited").
func row_for(run_id: int):
	var out = null
	for i in rows.size():
		var r: _ROW = rows[i]
		if r != null and r.min_run <= run_id:
			out = r
	return out


func passive(run_id: int) -> int:
	var r = row_for(run_id)
	return r.passive if r != null else 0


func combat(run_id: int) -> int:
	var r = row_for(run_id)
	return r.combat if r != null else 0


func special(run_id: int) -> int:
	var r = row_for(run_id)
	return r.special if r != null else 0
