# Unit: InventoryLogic + ItemData (ROADMAP Phase 6, PROGRESSION_DESIGN §2).
extends Node

const _INV = preload("res://scripts/gameplay/progression/inventory_logic.gd")
const _ITEM = preload("res://scripts/gameplay/progression/item_data.gd")


func _item(id: StringName, max_run: int) -> _ITEM:
	var i: _ITEM = _ITEM.new()
	i.id = id
	i.display_name = str(id)
	i.use_line = "test"
	i.max_per_run = max_run
	return i


func run(ctx: Variant) -> void:
	# --- Data loads + validates ---
	var camp: _ITEM = load("res://data/items/camp_fire.tres")
	ctx.check(camp != null and camp.validate().size() == 0,
			"inventory: the camp fire data is valid")
	ctx.check(camp.max_per_run == 3 and camp.heal_amount > 0.0,
			"inventory: the camp fire heals (3 per run, data)")

	# --- 12 slots, no stacking ---
	var inv: _INV = _INV.new()
	ctx.check(inv.occupied() == 0 and not inv.is_full(),
			"inventory: starts empty (12 free slots)")
	var a: _ITEM = _item(&"a", 99)
	var idx: int = inv.add(a)
	ctx.check(idx == 0, "inventory: first item -> slot 0")
	for i in 11:
		ctx.check(inv.add(_item(&"x%d" % i, 99)) >= 0,
				"inventory: fills slot %d" % (i + 1))
	ctx.check(inv.occupied() == 12 and inv.is_full(),
			"inventory: 12 slots is full")
	ctx.check(inv.add(_item(&"late", 99)) == -1,
			"inventory: the 13th item is refused (no overflow)")

	# --- Per-run cap (the 3 camp fires) ---
	var inv2: _INV = _INV.new()
	var c1: _ITEM = _item(&"camp", 3)
	var c2: _ITEM = _item(&"camp", 3)
	var c3: _ITEM = _item(&"camp", 3)
	var c4: _ITEM = _item(&"camp", 3)
	ctx.check(inv2.add(c1) >= 0 and inv2.add(c2) >= 0
			and inv2.add(c3) >= 0,
			"inventory: 3 camp fires fit")
	ctx.check(inv2.add(c4) == -1,
			"inventory: the 4th camp fire is refused (max_per_run)")
	ctx.check(inv2.count(&"camp") == 3,
			"inventory: count respects the cap")

	# --- Use removes ---
	var used: _ITEM = inv2.use(0)
	ctx.check(used != null and used.id == &"camp"
			and inv2.occupied() == 2,
			"inventory: using frees the slot")
	ctx.check(inv2.use(0) == null,
			"inventory: an empty slot uses nothing")
	ctx.check(inv2.first_of(&"camp") == 1,
			"inventory: quick-use finds the next camp fire")
	inv2.clear()
	ctx.check(inv2.occupied() == 0, "inventory: clear empties all")

	# --- No currency surface (GDD §9): the logic has no value fields ---
	var has_money: bool = "price" in inv2 or "cost" in inv2 \
			or "value" in camp
	ctx.check(not has_money,
			"inventory: no currency surface (GDD: no currency)")
