# ChildSpawns — the Child's scripted appearance table (MVP: 1 row
# per run window; a `skip_flag` row: the world «takes» the child
# after the soft penalty — the child_hit flag hides all later rows).
class_name ChildSpawns
extends Resource

const _SPAWN = preload("res://scripts/gameplay/mystery/child_spawn.gd")

@export var spawns: Array = []  # Array[ChildSpawn]
# The soft-penalty flag (CHARACTER_BIBLE 5): set -> no more spawns.
@export var skip_flag: StringName = &"child_hit"


# The spawn for this run (null = the child is not here).
# `stats` = the MemoryStats (the total deaths — the child counts
# the player's whole history, not one run).
func for_run(run_id: int, ws: Variant, stats: Variant) -> _SPAWN:
	if skip_flag != &"" and ws.flag(skip_flag):
		return null
	for s in spawns:
		var sp: _SPAWN = s
		if run_id >= sp.run_min and run_id <= sp.run_max:
			if int(stats.deaths) < sp.min_deaths:
				continue
			return sp
	return null
