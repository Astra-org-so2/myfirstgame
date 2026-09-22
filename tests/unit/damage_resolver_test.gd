# Unit: DamageResolver — the single damage point (ARCHITECTURE §3.2).
# Plain nodes (no scene): the resolver works without the EventBus
# autoload present (tolerant lookup).
extends Node

const _RES = preload("res://scripts/gameplay/combat/damage_resolver.gd")
const _CT = preload("res://scripts/gameplay/combat/combat_target.gd")
const _DREQ = preload("res://scripts/gameplay/combat/damage_request.gd")

const DT: float = 1.0 / 60.0


func run(ctx: Variant) -> void:
	var resolver: _RES = _RES.new()
	resolver.name = "Resolver"
	add_child(resolver)

	var a_node: Node = Node.new()
	a_node.name = "TargetA"
	add_child(a_node)
	var ct: _CT = _CT.new(a_node, 100.0)
	resolver.register(a_node, ct)

	# 1. Basic application.
	var r: Variant = _resolve(resolver, null, a_node, 25.0)
	ctx.check(r.applied == 25.0 and not r.blocked,
			"resolver: 25 dmg applied")
	ctx.check(ct.hp == 75.0, "resolver: hp 100 -> 75")

	# 2. Blocked by invulnerability (dodge i-frames).
	ct.invulnerable = true
	r = _resolve(resolver, null, a_node, 25.0)
	ctx.check(r.blocked and r.blocked_reason == &"invulnerable"
			and ct.hp == 75.0,
			"resolver: i-frame block, hp unchanged")
	ct.invulnerable = false

	# 3. Kill at 0 hp: result.killed + target_killed once.
	var killed_nodes: Array = []
	resolver.target_killed.connect(func(n) -> void:
		killed_nodes.append(n)
	)
	r = _resolve(resolver, null, a_node, 1000.0)
	ctx.check(r.killed and ct.hp == 0.0, "resolver: kill at 0 hp")
	ctx.check(killed_nodes.size() == 1 and killed_nodes[0] == a_node,
			"resolver: target_killed emitted once with the victim")

	# 4. Dead target refuses further damage.
	r = _resolve(resolver, null, a_node, 10.0)
	ctx.check(r.blocked and r.blocked_reason == &"dead_target"
			and r.applied == 0.0,
			"resolver: dead target blocked")

	# 5. Unknown target: safe blocked result, no crash.
	var stranger: Node = Node.new()
	stranger.name = "Stranger"
	add_child(stranger)
	r = _resolve(resolver, null, stranger, 10.0)
	ctx.check(r.blocked and r.blocked_reason == &"unknown_target",
			"resolver: unknown target -> blocked (no crash)")

	# 6. Stun flag: applied + decays with update().
	var b_node: Node = Node.new()
	b_node.name = "TargetB"
	add_child(b_node)
	var ct_b: _CT = _CT.new(b_node, 50.0)
	resolver.register(b_node, ct_b)
	var stun_req: _DREQ = _DREQ.new()
	stun_req.target = b_node
	stun_req.amount = 5.0
	stun_req.flags = _DREQ.FLAG_STUN
	stun_req.stun_duration = 1.5
	_resolve(resolver, null, b_node, 0.0, stun_req)
	ctx.check(ct_b.is_stunned(), "resolver: stun applied via flag")
	for i in 30:  # 0.5 s
		ct_b.update(DT)
	ctx.check(ct_b.is_stunned() and ct_b.get_stun_remaining() > 0.8,
			"resolver: stun still active after 0.5 s")
	for i in 90:  # +1.5 s
		ct_b.update(DT)
	ctx.check(not ct_b.is_stunned(), "resolver: stun expired")

	# 7. Negative amount clamps to 0 (no hp gain, no crash).
	var c_node: Node = Node.new()
	c_node.name = "TargetC"
	add_child(c_node)
	var ct_c: _CT = _CT.new(c_node, 10.0)
	resolver.register(c_node, ct_c)
	r = _resolve(resolver, null, c_node, -50.0)
	ctx.check(not r.blocked and r.applied == 0.0 and ct_c.hp == 10.0,
			"resolver: negative amount clamped to 0")


func _resolve(resolver: _RES, src: Node, target: Node,
	amount: float, pre: _DREQ = null) -> Variant:
	var req: _DREQ = pre if pre != null else _DREQ.new()
	if pre == null:
		req.source = src
		req.target = target
		req.amount = amount
	return resolver.resolve(req)
