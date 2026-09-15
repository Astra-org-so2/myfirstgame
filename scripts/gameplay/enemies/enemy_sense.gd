# EnemySense — the per-tick sensory snapshot the controller computes
# for the pure EnemyLogic (geometry + player state, no Node access in
# the logic itself).
class_name EnemySense
extends RefCounted

# World position of the player (feet).
var player_position: Vector3 = Vector3.ZERO
# The enemy sees the player: range + fov (+ LOS seam, Phase 7 rooms).
var player_seen: bool = false
# The player made noise within hear_range (dodge/attack; the explorer
# profile mutes this — the director decides before filling the sense).
var player_noise: bool = false
# Mutual eye-line (Watcher): the player looks AT the enemy too.
var eye_line: bool = false
# Player's weapon state (Mimic punish patterns; phase = WeaponLogic).
var player_weapon_phase: int = 0
var player_combo_index: int = 0
# Player is dodging (Mimic: the over-dodge punish window).
var player_dodging: bool = false
