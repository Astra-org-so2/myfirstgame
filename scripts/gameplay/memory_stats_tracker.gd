# MemoryStatsTracker — fills the session's MemoryStats from real
# signals (WORLD_STATE_DESIGN §3).
#
# Phase 5 sources (the systems that exist):
#   kills        <- EventBus.enemy_killed (the enemy director emits)
#   deaths       <- EventBus.player_died
#   fled         <- the director: a Hollow retreated (the player fled)
#   dodge_count  <- player.dodge_started
#   melee_hits   <- synced from the player weapon (landed hits)
#   explored     <- 0 until zone tracking exists (Phases 7/8/10)
#   strange/notes/npc/child/runs <- their systems (Phases 8/10/11)
#
# Cross-run accumulation + persistence: Phase 10 (World memory).
class_name MemoryStatsTracker
extends Node

const _STYLE = preload("res://scripts/gameplay/memory_stats.gd")

var stats: _STYLE = _STYLE.new()


func _ready() -> void:
	var bus: Node = get_node_or_null("/root/EventBus")
	if bus == null:
		return
	bus.connect("enemy_killed", _on_enemy_killed)
	bus.connect("player_died", _on_player_died)


func bind_player(player: Node) -> void:
	if player == null:
		return
	player.connect("dodge_started", _on_dodge)


# Snapshot the player's landed melee hits (called before enemy
# spawn so dominant_style sees the session's combat).
func sync_player_hits(n: int) -> void:
	stats.melee_hits = n


# The director calls when a Hollow retreats (the player fled it).
func on_fled() -> void:
	stats.fled += 1


func _on_enemy_killed(_enemy_id: StringName, _pos: Vector3) -> void:
	stats.kills += 1


func _on_player_died(_pos: Vector3) -> void:
	stats.deaths += 1


func _on_dodge() -> void:
	stats.dodge_count += 1
