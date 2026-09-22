# ItemData — one inventory item (PROGRESSION_DESIGN §2).
#
# MVP: the ONE item — the camp fire (a healing consumable, 3 per run,
# dropped by 1/10 of defeated enemies). There is NO currency and NO
# XP (GDD §9) — items are the only "progress within a run" and they
# RESTORE, they don't stack ("not +HP — restore").
#
# New item = new .tres (data-driven, PROGRESSION_DESIGN §7).
class_name ItemData
extends Resource

enum Type { CONSUMABLE }

@export var id: StringName = &""
@export var display_name: String = ""
@export var type: int = Type.CONSUMABLE
# The one-line use description (UI).
@export var use_line: String = ""
# CONSUMABLE: how much hp it restores (0 = no heal, e.g. a key item).
@export_range(0.0, 100.0) var heal_amount: float = 0.0
# How many of this item a single run may hold (3 camp fires).
@export_range(0, 99) var max_per_run: int = 1


func validate() -> Array[String]:
	var problems: Array[String] = []
	if id == &"":
		problems.append("id must be set")
	if display_name == "" or use_line == "":
		problems.append("display_name and use_line are required")
	if max_per_run < 1:
		problems.append("max_per_run must be >= 1")
	return problems
