extends Node
func run(ctx) -> void:
	var t1: int = int(Time.get_ticks_msec())
	await get_tree().process_frame
	var t2: int = int(Time.get_ticks_msec())
	ctx.check(t2 >= t1, "perf: Time.get_ticks_msec works (%d -> %d)" % [t1, t2])
	var t3: int = int(Time.get_ticks_usec())
	ctx.check(t3 > 0, "perf: Time.get_ticks_usec = %d" % t3)
	# count particles in the main scene (structural)
	var packed: PackedScene = load("res://scenes/main.tscn")
	var scene: Node = packed.instantiate()
	var player = scene.find_child("Player", true, false)
	var mock = load("res://scripts/player/movement_port.gd").new(null,
			player.data.gravity, player.data.max_fall_speed)
	player.set_port(mock)
	add_child(scene)
	var nodes: int = _count(scene)
	var bodies: int = 0
	var parts: int = 0
	for n in get_tree().root.find_children("*", "Node3D", false):
		pass
	ctx.check(nodes > 0, "perf: camp scene nodes = %d" % nodes)
	scene.queue_free()
	await get_tree().process_frame

func _count(n: Node) -> int:
	var c: int = 1
	for ch in n.get_children():
		c += _count(ch)
	return c
