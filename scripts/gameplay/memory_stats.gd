# MemoryStats — hidden behavior counters (WORLD_STATE_DESIGN §3).
#
# The player NEVER sees the numbers; the CONSEQUENCES are visible
# (NPC dialogue, Mimic spawn, Echo aggression — ENEMY_DESIGN §7).
# Phase 5 implements the structure + the counters that exist yet
# (kills, deaths, fled, style inputs, explored stub); the remaining
# sources (notes, NPCs, runs) hook in with their own phases.
#
# Cross-run accumulation + persistence: Phase 10 (World memory).
class_name MemoryStats
extends RefCounted

# dominant_style (WORLD_STATE_DESIGN §3).
const STYLE_NONE: int = 0
const STYLE_MELEE: int = 1
const STYLE_RANGED: int = 2
const STYLE_DODGE: int = 3

# Aggression profiles (ENEMY_DESIGN §7: slayer/runner/explorer).
const PROFILE_NORMAL: int = 0
const PROFILE_SLAYER: int = 1
const PROFILE_RUNNER: int = 2
const PROFILE_EXPLORER: int = 3

# --- The 10 counters (WORLD_STATE_DESIGN §3) ---
var kills: int = 0
var fled: int = 0
var explored_pct: int = 0  # 0..100
var notes_written: int = 0
var npc_killed: int = 0
var child_hit: int = 0
var strange_actions: int = 0
var deaths: int = 0
var runs_completed: int = 0
# Style inputs for dominant_style (aggregated over N runs; Phase 5:
# current session).
var dodge_count: int = 0
var melee_hits: int = 0
var ranged_hits: int = 0


# dominant_style: the verb the player commits to. `min_total_actions`
# and `dominance_pct` from the thresholds data (no magic numbers).
func dominant_style(min_total_actions: int, dominance_pct: int) -> int:
	var total: int = dodge_count + melee_hits + ranged_hits
	if total < min_total_actions:
		return STYLE_NONE
	var best: int = STYLE_NONE
	var best_count: int = 0
	if melee_hits > best_count:
		best = STYLE_MELEE
		best_count = melee_hits
	if ranged_hits > best_count:
		best = STYLE_RANGED
		best_count = ranged_hits
	if dodge_count > best_count:
		best = STYLE_DODGE
		best_count = dodge_count
	if best_count * 100 < total * dominance_pct:
		return STYLE_NONE  # no committed style (varied play)
	return best


# Aggression profile for this run (ENEMY_DESIGN §7; thresholds from
# data/memory_stats_thresholds.tres). Precedence: slayer > runner >
# explorer (a slayer who also fled is still a slayer — "remembers").
func aggression_profile(thresholds: Resource) -> int:
	if kills > thresholds.slayer_kills:
		return PROFILE_SLAYER
	if fled > thresholds.runner_fled:
		return PROFILE_RUNNER
	if explored_pct > thresholds.explorer_explored_pct \
			and strange_actions > thresholds.explorer_strange_actions:
		return PROFILE_EXPLORER
	return PROFILE_NORMAL
