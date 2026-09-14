# EventBus (autoload) — the single point for significant events
# (ARCHITECTURE §3.1). NOT for frame logic.
#
# Created in Phase 4 (the first system that needs enemy_killed-style
# events; ADR-009: autoloads appear with their own system phase).
# Run/World/Audio/UI systems (Phases 8+) subscribe here — no direct
# dependencies between them.
#
# Parameters are built-in types only (the headless rig has no global
# class_name registry — ADR-022); richer payloads stay in the sender's
# own typed signals (e.g. DamageResolver.damage_applied -> DamageResult).
#
# No class_name: it would hide the autoload singleton of the same name
# (parse error). Cross-file access = get_node("/root/EventBus").
extends Node

signal player_died(position: Vector3)
signal player_spawned(position: Vector3)
signal target_killed(combat_id: StringName, position: Vector3)
