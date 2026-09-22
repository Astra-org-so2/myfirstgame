# NotePanel — the player's note writing (WORLD_STATE_DESIGN section
# 4): the player picks 1 of the 5-line pool (no free text, ADR-018)
# or closes without writing. Code-built custom Controls (the
# headless rig instantiates it — ADR-002), the DeathScreen pattern:
# a `press(idx)` API for deterministic tests, the choice goes out
# as a signal; the caller applies it (WorldState.write_note).
class_name NotePanel
extends CanvasLayer

signal written(line_id: int)
signal closed()

var _root: Control
var _rows: Array = []  # Control per line
var _close: Control
var _visible: bool = false


func _ready() -> void:
	layer = 25
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	visible = false


# Show the 5-line pool. `existing` = the current note's line id
# (the stand is re-writable: it is highlighted).
var _theme: Variant = null  # the UiTheme kit (lazy: data default)


func _th() -> Variant:
	if _theme == null:
		_theme = load("res://data/ui/ui_theme.tres")
	return _theme

func show_pool(lines: PackedStringArray, existing: int = -1) -> void:
	_visible = true
	visible = true
	_rows.clear()
	for c in _root.get_children():
		c.queue_free()
	var screen: Vector2 = get_viewport().get_visible_rect().size
	if screen.x < 1.0:
		screen = Vector2(360.0, 640.0)
	var panel_w: float = screen.x * 0.86
	var panel_h: float = screen.y * 0.62
	var panel: Panel = Panel.new()
	var bg: StyleBoxFlat = _th().panel_style()
	bg.bg_color = _th().panel_bg
	panel.add_theme_stylebox_override("panel", bg)
	panel.position = Vector2((screen.x - panel_w) * 0.5,
			(screen.y - panel_h) * 0.3)
	panel.size = Vector2(panel_w, panel_h)
	_root.add_child(panel)
	var title: Label = Label.new()
	title.text = tr("leave a note")
	title.add_theme_font_size_override("font_size", _th().font_title)
	title.add_theme_color_override("font_color", _th().text_dim)
	title.position = Vector2(0.0, 8.0)
	title.size = Vector2(panel_w, 28.0)
	panel.add_child(title)
	var row_h: float = (panel_h - 90.0) / float(lines.size() + 1)
	for i in lines.size():
		var row: Control = _make_row(lines[i], i == existing, row_h,
				i)
		row.position = Vector2(0.0, 44.0 + float(i) * row_h)
		row.size = Vector2(panel_w, row_h)
		panel.add_child(row)
		_rows.append(row)
	var close_row: Control = _make_row("— close —", false, row_h, -1)
	close_row.position = Vector2(0.0, 44.0 + float(lines.size()) * row_h)
	close_row.size = Vector2(panel_w, row_h)
	panel.add_child(close_row)
	_close = close_row
	_close.gui_input.connect(_on_close_input)


func _make_row(text: String, highlight: bool, row_h: float,
		idx: int = -1) -> Control:
	var c: Control = Control.new()
	var bg: StyleBoxFlat = _th().cell_style(highlight)
	var p: Panel = Panel.new()
	p.add_theme_stylebox_override("panel", bg)
	p.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.add_child(p)
	var l: Label = Label.new()
	l.text = "· " + text
	l.add_theme_font_size_override("font_size", _th().font_small)
	l.add_theme_color_override("font_color",
			_th().text_parchment if highlight else _th().text_dim)
	l.position = Vector2(12.0, row_h * 0.5 - 10.0)
	l.size = Vector2(c.size.x - 24.0, 20.0)
	c.add_child(l)
	c.gui_input.connect(_on_row_input.bind(idx))
	return c


func _on_row_input(event: InputEvent, idx: int) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb == null or not mb.pressed \
			or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if idx < 0 or idx >= _rows.size():
		return
	_close_panel()
	written.emit(idx)


func _on_close_input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb == null or not mb.pressed \
			or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	_close_panel()
	closed.emit()


# The deterministic test seam (DeathScreen pattern).
func press(idx: int) -> void:
	if idx < 0:
		_close_panel()
		closed.emit()
		return
	if idx < _rows.size():
		_close_panel()
		written.emit(idx)


func _close_panel() -> void:
	_visible = false
	visible = false
	for c in _root.get_children():
		c.queue_free()
	_rows.clear()


func is_open() -> bool:
	return _visible
