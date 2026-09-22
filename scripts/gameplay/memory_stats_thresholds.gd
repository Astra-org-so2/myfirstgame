# MemoryStatsThresholds — behavior-counter thresholds
# (WORLD_STATE_DESIGN §3, ENEMY_DESIGN §7). All numbers here, not code.
class_name MemoryStatsThresholds
extends Resource

# Slayer: kills > threshold (ENEMY_DESIGN §7).
@export var slayer_kills: int = 20
# Runner: fled > threshold.
@export var runner_fled: int = 10
# Explorer: explored > % AND strange actions > threshold.
@export var explorer_explored_pct: int = 50
@export var explorer_strange_actions: int = 5
# dominant_style (Mimic): at least this many style actions, and the
# dominant verb >= this % of the total (a "consistent style" player).
@export var style_min_actions: int = 10
@export var style_dominance_pct: int = 50


func validate() -> Array[String]:
	var problems: Array[String] = []
	if slayer_kills < 0 or runner_fled < 0:
		problems.append("counters must be >= 0")
	if explorer_explored_pct < 0 or explorer_explored_pct > 100:
		problems.append("explored pct must be in 0..100")
	if style_min_actions < 1 or style_dominance_pct < 50 \
			or style_dominance_pct > 100:
		problems.append("style: min_actions >= 1, dominance in 50..100")
	return problems
