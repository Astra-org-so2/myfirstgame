# BossGate — the event-based boss condition (ADR-019: "a window, not
# a timer"; GDD §8). Pure logic (RefCounted, unit-testable): the door
# to the Undercroft opens in the NEXT run when all three hold.
#
#   1. mine_level_3_explored — the player reached the deep mine
#      (the 3rd room of the mine chain, at least once);
#   2. deaths >= 3 — the world "knows the player's death";
#   3. first_traces_seen — RUN 05+: "the big footprints + his
#      lantern" (the mine's deep level).
#
# The result lands in ONE world flag (`boss_door_open`) — the
# room/door layer is data-driven on a single flag (area_connection.
# gd `condition`); the compound rule lives here, the flag is the
# interface.
class_name BossGate
extends RefCounted

const MINE_EXPLORED: StringName = &"mine_level_3_explored"
const TRACES_SEEN: StringName = &"first_traces_seen"
const DOOR_OPEN: StringName = &"boss_door_open"
const DEATHS_MIN: int = 3

# The mine chain depth that counts as "level 3" (0-based index of
# the 3rd room; the mine chain is 5 rooms, the deep ones carry the
# traces).
const MINE_DEEP_INDEX: int = 2


# Should the door be opened (in the upcoming run)? `ws` = the
# WorldState (its flag view), `deaths` = the session's death count.
func should_open(ws: Variant, deaths: int) -> bool:
	if ws == null:
		return false
	if ws.flag(DOOR_OPEN):
		return true  # once open, always open (the world remembers)
	if not ws.flag(MINE_EXPLORED):
		return false
	if deaths < DEATHS_MIN:
		return false
	if not ws.flag(TRACES_SEEN):
		return false
	return true
