# Unit: Phase 13 batch 3 — the UI kit (UiTheme): the data loads,
# validates, builds the styles, and the four screens are wired to it
# (the ad-hoc per-screen colors are gone).
extends Node


func run(ctx: Variant) -> void:
	var res: Resource = load("res://data/ui/ui_theme.tres")
	ctx.check(res != null, "uikit: data/ui/ui_theme.tres loads")
	if res == null:
		return
	var problems: Array = res.validate()
	ctx.check(problems.is_empty(),
			"uikit: validate() clean (%s)" % str(problems))
	# The world rule in the UI: the campfire is the only warm accent.
	var warm: Color = res.accent_warm
	var cold: Color = res.accent_cold
	ctx.check(warm.r > warm.b, "uikit: the warm accent is warm")
	ctx.check(cold.b > cold.r, "uikit: the cold accent is cold")
	# Text is parchment (lighter than the panels).
	ctx.check(res.text_parchment.r > res.panel_bg.r + 0.3,
			"uikit: the parchment is readable on the panel")
	# The style builders.
	var panel: StyleBoxFlat = res.panel_style()
	ctx.check(panel != null and panel.bg_color == res.panel_bg,
			"uikit: panel_style carries the kit color")
	var cell: StyleBoxFlat = res.cell_style(true)
	var cell_lo: StyleBoxFlat = res.cell_style(false)
	ctx.check(cell.bg_color == res.cell_bg_hi
			and cell_lo.bg_color == res.cell_bg,
			"uikit: cell_style honors the highlight")
	# Typography is positive and ordered.
	ctx.check(res.font_title > res.font_body and res.font_body > res.font_small,
			"uikit: the type scale is ordered")
	# The screens are wired to the kit (no ad-hoc colors left).
	var wired: Array = [
		"res://scripts/ui/toast.gd",
		"res://scripts/ui/inventory_panel.gd",
		"res://scripts/ui/note_panel.gd",
		"res://scripts/ui/death_screen.gd",
	]
	var all_wired: bool = true
	for f in wired:
		var text: String = ""
		var file: FileAccess = FileAccess.open(f, FileAccess.READ)
		if file == null:
			all_wired = false
			continue
		text = file.get_as_text()
		file.close()
		if not text.contains("_th()."):
			all_wired = false
	ctx.check(all_wired, "uikit: all four screens use the kit")
