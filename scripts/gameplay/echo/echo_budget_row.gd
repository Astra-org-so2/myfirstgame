# EchoBudgetRow — one row of the per-run echo budget (ADR-014,
# ECHO_SYSTEM_DESIGN section 7): from run N — up to `passive` Passive
# + `combat` Combat + `special` «special» (Memory|Forgotten|False).
#
# Rows are evaluated top-down, the FIRST row with min_run <= run_id
# wins (the budget only ever steps up within the MVP pre-boss arc).
class_name EchoBudgetRow
extends Resource

@export var min_run: int = 1
@export var passive: int = 0
@export var combat: int = 0
@export var special: int = 0
