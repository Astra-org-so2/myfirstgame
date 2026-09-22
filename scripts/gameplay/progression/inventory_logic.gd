# InventoryLogic — 12 slots + equipment (ROADMAP Phase 6).
#
# Pure logic (no Node): the scene/UI and the tests drive it.
# Rules:
# - 12 item slots; items don't stack (one per slot);
# - each item type has a per-run cap (max_per_run, data);
# - NO currency, NO XP (GDD §9) — nothing is "bought";
# - the weapon is NOT an inventory slot: found weapons live in
#   WorldState.weapons and equip from the loadout (WEAPON_DESIGN §0:
#   weapons are FOUND, not dropped/bought).
class_name InventoryLogic
extends RefCounted

const _ITEM = preload("res://scripts/gameplay/progression/item_data.gd")
const SLOT_COUNT: int = 12

var slots: Array = []  # [ItemData | null] x 12


func _init() -> void:
	slots = []
	for i in SLOT_COUNT:
		slots.append(null)


func is_full() -> bool:
	return occupied() == SLOT_COUNT


func count(item_id: StringName) -> int:
	var n: int = 0
	for s in slots:
		if s != null and s.id == item_id:
			n += 1
	return n


func occupied() -> int:
	var n: int = 0
	for s in slots:
		if s != null:
			n += 1
	return n


# Add an item. Fails when the inventory is full OR the per-run cap for
# this item type is reached (both visible to the player: no hidden
# overflow). Returns the slot index, or -1.
func add(item: _ITEM) -> int:
	if item == null:
		return -1
	if count(item.id) >= item.max_per_run:
		return -1
	for i in SLOT_COUNT:
		if slots[i] == null:
			slots[i] = item
			return i
	return -1


# Use (remove) the item at the slot. Returns the ItemData, or null.
func use(index: int) -> _ITEM:
	if index < 0 or index >= SLOT_COUNT or slots[index] == null:
		return null
	var item: _ITEM = slots[index]
	slots[index] = null
	return item


# First occupied slot holding this item (the quick-use path).
func first_of(item_id: StringName) -> int:
	for i in SLOT_COUNT:
		if slots[i] != null and slots[i].id == item_id:
			return i
	return -1


func clear() -> void:
	for i in SLOT_COUNT:
		slots[i] = null
