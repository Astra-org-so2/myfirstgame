# BossSense — what the boss logic knows each tick (the controller
# feeds it; the logic stays scene-free like EnemyLogic).
class_name BossSense
extends RefCounted

var player_pos: Vector2 = Vector2.ZERO
var player_present: bool = false
