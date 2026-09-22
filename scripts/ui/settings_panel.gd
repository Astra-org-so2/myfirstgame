# SettingsPanel — the audio settings (Phase 14, the P14 exit).
#
# One kit-styled screen (ADR-002 code-built, the UiTheme kit): four
# level sliders (master/music/sfx/ambient) + the mute toggle. The
# values apply LIVE to the AudioManager (the buses hear the change);
# the settings themselves are the manager's dict (P15 persists it).
#
# Mobile: the panel is a centered box (aspect-safe on 16:9–20:9 —
# no edge-anchored content), the sliders are thumb-sized rows.
# Interaction: the rows take a press/drag (the same _gui_input path
# as the touch layer, ADR-021/ADR-033) AND a deterministic
# set_slider()/toggle() API for the tests (no input flakiness).
class_name SettingsPanel
extends CanvasLayer

const _SLIDERS: Array[String] = ["master", "music", "sfx", "ambient"]
const _TITLES: Array[String] = ["Master", "Music", "SFX", "Ambient"]
const _ROW_H_RATIO: float = 0.09  # thumb-sized rows (mobile)


var _root: Control = null
var _am: Node = null
var _sliders: Array = []  # [{track, fill, value, t}]
var _mute_row: Control = null
var _mute_fill: ColorRect = null

signal closed


func _ready() -> void:
	layer = 25
	_root = Control.new()
	add_child(_root)
	visible = false


# Show (or refresh) the panel over the given AudioManager.
func show_panel(am: Node) -> void:
	_am = am
	_rebuild()
	visible = true


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


# The deterministic API (tests + the touch rows both call this).
func set_slider(idx: int, t: float) -> void:
	if _am == null or idx < 0 or idx >= _SLIDERS.size():
		return
	var v: float = clampf(t, 0.0, 1.0)
	var row: Dictionary = _sliders[idx]
	row.t = v
	_apply(idx, v)
	_draw_slider(idx)


# The mute toggle (deterministic side).
func toggle_mute() -> void:
	if _am == null:
		return
	_am.muted = not _am.muted
	_am.apply_settings()
	_draw_mute()


func _rebuild() -> void:
	if _root == null:
		return
	for c in _root.get_children():
		c.queue_free()
	_sliders.clear()
	_mute_row = null
	_mute_fill = null
	var screen: Vector2 = get_viewport().get_visible_rect().size
	if screen.x < 1.0:
		screen = Vector2(360.0, 640.0)  # headless boot: a sane phone size
	var w: float = minf(screen.x * 0.82, 480.0)
	var row_h: float = maxf(screen.y * _ROW_H_RATIO, 44.0)
	var pad: float = row_h * 0.35
	var h: float = row_h * 6.2 + pad * 2.0
	var x: float = (screen.x - w) * 0.5
	var y: float = (screen.y - h) * 0.5
	var bg: ColorRect = ColorRect.new()
	bg.position = Vector2(x, y)
	bg.size = Vector2(w, h)
	bg.color = _th().panel_bg
	_root.add_child(bg)

	var title: Label = Label.new()
	title.text = tr("Sound")
	title.position = Vector2(x + pad, y + pad * 0.4)
	title.size = Vector2(w - pad * 2, row_h)
	title.add_theme_font_size_override("font_size", _th().font_title)
	title.add_theme_color_override("font_color", _th().text_bright)
	_root.add_child(title)

	var cy: float = y + pad + row_h * 1.1
	for i in _SLIDERS.size():
		var row: Dictionary = _build_row(i, x + pad, cy, w - pad * 2, row_h)
		_sliders.append(row)
		cy += row_h * 1.15

	_mute_row = _build_mute(x + pad, cy, w - pad * 2, row_h)
	cy += row_h * 1.15

	var close_btn: Control = _build_close(x + w * 0.5 - row_h * 0.5, cy, row_h)
	_root.add_child(close_btn)


func _build_row(idx: int, x: float, y: float, w: float, h: float) -> Dictionary:
	var t: float = 1.0
	if _am != null:
		match _SLIDERS[idx]:
			"master":
				t = _am.master
			"music":
				t = _am.music_level
			"sfx":
				t = _am.sfx_level
			"ambient":
				t = _am.ambient_level
	var label: Label = Label.new()
	label.text = _TITLES[idx]
	label.position = Vector2(x, y)
	label.size = Vector2(w * 0.22, h)
	label.add_theme_font_size_override("font_size", _th().font_body)
	label.add_theme_color_override("font_color", _th().text_parchment)
	_root.add_child(label)
	var track_x: float = x + w * 0.24
	var track_w: float = w * 0.58
	var track: ColorRect = ColorRect.new()
	track.position = Vector2(track_x, y + h * 0.35)
	track.size = Vector2(track_w, h * 0.3)
	track.color = _th().cell_bg
	_root.add_child(track)
	var fill: ColorRect = ColorRect.new()
	fill.position = track.position
	fill.size = Vector2(track_w * t, h * 0.3)
	fill.color = _th().accent_warm
	_root.add_child(fill)
	var value: Label = Label.new()
	value.position = Vector2(track_x + track_w + h * 0.15, y)
	value.size = Vector2(w * 0.16, h)
	value.add_theme_font_size_override("font_size", _th().font_small)
	value.add_theme_color_override("font_color", _th().text_dim)
	_root.add_child(value)
	# The touch target: a row-wide Control over the track (thumb zone).
	var hit: Control = Control.new()
	hit.position = Vector2(track_x - h * 0.25, y)
	hit.size = Vector2(track_w + h * 0.5, h)
	hit.mouse_filter = Control.MOUSE_FILTER_STOP
	var i: int = idx
	hit.gui_input.connect(_on_row_input.bind(i, track_x, track_w))
	_root.add_child(hit)
	var row: Dictionary = {
		"track": track, "fill": fill, "value": value, "t": t,
	}
	_draw_slider(idx)
	return row


func _build_mute(x: float, y: float, w: float, h: float) -> Control:
	var row: Control = Control.new()
	row.position = Vector2(x, y)
	row.size = Vector2(w, h)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	var label: Label = Label.new()
	label.text = tr("Mute")
	label.position = Vector2(0.0, 0.0)
	label.size = Vector2(w * 0.22, h)
	label.add_theme_font_size_override("font_size", _th().font_body)
	label.add_theme_color_override("font_color", _th().text_parchment)
	row.add_child(label)
	_mute_fill = ColorRect.new()
	_mute_fill.position = Vector2(w * 0.24, h * 0.35)
	_mute_fill.size = Vector2(w * 0.58, h * 0.3)
	_mute_fill.color = _th().cell_bg
	row.add_child(_mute_fill)
	var value: Label = Label.new()
	value.name = "MuteValue"
	value.position = Vector2(w * 0.84, 0.0)
	value.size = Vector2(w * 0.16, h)
	value.add_theme_font_size_override("font_size", _th().font_small)
	value.add_theme_color_override("font_color", _th().text_dim)
	row.add_child(value)
	row.gui_input.connect(_on_mute_input)
	_root.add_child(row)
	_draw_mute()
	return row


func _build_close(x: float, y: float, size: float) -> Control:
	var btn: Control = Control.new()
	btn.position = Vector2(x, y)
	btn.size = Vector2(size, size)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	var bg: ColorRect = ColorRect.new()
	bg.position = Vector2.ZERO
	bg.size = btn.size
	bg.color = _th().cell_bg
	btn.add_child(bg)
	var label: Label = Label.new()
	label.text = "X"
	label.position = Vector2.ZERO
	label.size = btn.size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", _th().font_body)
	label.add_theme_color_override("font_color", _th().text_bright)
	btn.add_child(label)
	btn.gui_input.connect(_on_close_input)
	return btn


# --- Touch input (the same _gui_input path as the touch layer) -------------

func _on_row_input(event: InputEvent, idx: int, track_x: float,
		track_w: float) -> void:
	var x: float = -1.0
	if event is InputEventScreenTouch and event.pressed:
		x = event.position.x
	elif event is InputEventScreenDrag:
		x = event.position.x
	if x < 0.0:
		return
	set_slider(idx, (x - track_x) / track_w)


func _on_mute_input(event: InputEvent) -> void:
	var tapped: bool = false
	if event is InputEventScreenTouch and event.pressed:
		tapped = true
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		tapped = true
	if tapped:
		toggle_mute()


func _on_close_input(event: InputEvent) -> void:
	var tapped: bool = false
	if event is InputEventScreenTouch and event.pressed:
		tapped = true
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		tapped = true
	if tapped:
		close()


# --- Drawing -----------------------------------------------------------------

func _draw_slider(idx: int) -> void:
	var row: Dictionary = _sliders[idx]
	var t: float = float(row.t)
	var fill: ColorRect = row.fill
	var track: ColorRect = row.track
	fill.size.x = track.size.x * t
	var value: Label = row.value
	value.text = str(int(t * 100))


func _draw_mute() -> void:
	if _am == null or _mute_row == null:
		return
	var on: bool = _am.muted
	if _mute_fill != null:
		_mute_fill.color = _th().danger if on else _th().accent_warm
	var v: Label = _mute_row.get_node_or_null("MuteValue")
	if v != null:
		v.text = tr("on") if on else tr("off")
		v.add_theme_color_override("font_color",
				_th().danger if on else _th().text_dim)


func _apply(idx: int, v: float) -> void:
	match _SLIDERS[idx]:
		"master":
			_am.master = v
		"music":
			_am.music_level = v
		"sfx":
			_am.sfx_level = v
		"ambient":
			_am.ambient_level = v
	_am.apply_settings()


var _theme: Variant = null  # the UiTheme kit (lazy: data default)


func _th() -> Variant:
	if _theme == null:
		_theme = load("res://data/ui/ui_theme.tres")
	return _theme
