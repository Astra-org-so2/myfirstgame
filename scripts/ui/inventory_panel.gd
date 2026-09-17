# InventoryPanel — the 12-slot bag (Phase 6, mobile-first).
#
# Toggled by the `inventory` action (Tab / the INV touch button).
# A 4x3 grid; tapping a slot USES the item (the camp fire: heal).
# Code-built custom Controls (rig-safe, ADR-002); the data is the
# InventoryLogic (pure, unit-tested).
class_name InventoryPanel
extends CanvasLayer

const _INV = preload("res://scripts/gameplay/progression/inventory_logic.gd")
const _ITEM = preload("res://scripts/gameplay/progression/item_data.gd")

var _inv: _INV = null
var _root: Control
var _slots: Array = []  # [slot Control] x 12
var _open: bool = false

signal slot_used(index: int, item: _ITEM)


func _ready() -> void:
	layer = 15
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	visible = false


func setup(inv: _INV) -> void:
	_inv = inv
	_build()


func _build() -> void:
	for c in _root.get_children():
		c.queue_free()
	_slots.clear()
	var grid_w: float = 0.42
	var grid_h: float = 0.34
	var x0: float = (1.0 - grid_w) * 0.5
	var y0: float = 0.30
	var cell: float = grid_w / 4.0
	for i in _INV.SLOT_COUNT:
		var col: int = i % 4
		var row: int = i / 4
		var cell_c: Control = Control.new()
		cell_c.position = Vector2(x0 + col * cell, y0 + row * cell)
		cell_c.size = Vector2(cell * 0.9, (grid_h / 3.0) * 0.9)
		var bg: ColorRect = ColorRect.new()
		bg.color = Color(0.12, 0.13, 0.15, 0.9)
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		cell_c.add_child(bg)
		var lab: Label = Label.new()
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lab.add_theme_font_size_override("font_size", 16)
		lab.add_theme_color_override("font_color",
				Color(0.9, 0.87, 0.8, 1.0))
		lab.set_anchors_preset(Control.PRESET_FULL_RECT)
		cell_c.add_child(lab)
		cell_c.mouse_filter = Control.MOUSE_FILTER_STOP
		cell_c.gui_input.connect(_on_cell_input.bind(i, lab))
		_root.add_child(cell_c)
		_slots.append({"control": cell_c, "label": lab})
	_place()


func _place() -> void:
	var screen: Vector2 = get_viewport().get_visible_rect().size
	if screen.x < 1.0:
		return
	for s in _slots:
		var c: Control = s["control"]
		c.position = c.position * screen
		c.size = c.size * screen


func _on_cell_input(event: InputEvent, idx: int, _lab: Label) -> void:
	# Touch is the primary input (mobile-first): a touch-down on the
	# cell uses the item; mouse works too (dev convenience).
	var touched: bool = false
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null:
		touched = mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
	else:
		var st: InputEventScreenTouch = event as InputEventScreenTouch
		touched = st != null and st.pressed
	if touched:
		tap(idx)


func _refresh() -> void:
	if _inv == null:
		return
	for i in _slots.size():
		var s: Dictionary = _slots[i]
		var item: _ITEM = _inv.slots[i]
		s["label"].text = item.display_name if item != null else ""


func toggle() -> void:
	_open = not _open
	visible = _open
	if _open:
		_refresh()


# The programmatic touch-down (tests; the finger path is
# gui_input -> _on_cell_input -> tap). Uses the slot if it holds an
# item. Only while the panel is open.
func tap(index: int) -> void:
	if _inv == null or not _open or index < 0 \
			or index >= _INV.SLOT_COUNT:
		return
	var item: _ITEM = _inv.use(index)
	if item == null:
		return
	_refresh()
	slot_used.emit(index, item)


func is_open() -> bool:
	return _open


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var kb: InputEventKey = event as InputEventKey
	if kb != null and kb.pressed and kb.keycode == KEY_ESCAPE:
		toggle()
		get_viewport().set_input_as_handled()
