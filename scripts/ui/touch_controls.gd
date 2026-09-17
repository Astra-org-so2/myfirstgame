# TouchControls — the touch input layer (CanvasLayer; ADR-021).
#
# Owns the widgets (joystick, buttons, camera zone), places them from
# TouchLayout data into the safe area, and exposes the joystick to the
# player through a JoystickProvider (ARCHITECTURE §7: player/ never
# depends on ui/ directly).
#
# Buttons drive InputMap actions (Input.action_press/release) — the same
# actions as keyboard/gamepad (TECHNICAL_DESIGN §7).
class_name TouchControls
extends CanvasLayer

const _LAYOUT = preload("res://scripts/ui/touch_layout.gd")
const _JOY_WIDGET = preload("res://scripts/ui/touch_joystick.gd")
const _BTN = preload("res://scripts/ui/touch_button.gd")
const _CAM_ZONE = preload("res://scripts/ui/touch_camera_zone.gd")
const _PROVIDER = preload("res://scripts/utilities/joystick_provider.gd")

var layout: _LAYOUT

var _joystick: _JOY_WIDGET
var _dodge_btn: _BTN
var _attack_btn: _BTN
var _interact_btn: _BTN
var _inventory_btn: _BTN
var _special_btn: _BTN
var _weapon_btn: _BTN
var _soothe_btn: _BTN
var _disrupt_btn: _BTN
var _camera_zone: _CAM_ZONE

var _provider: _PROVIDER = _PROVIDER.new()
var _placed: bool = false


func get_provider() -> _PROVIDER:
	return _provider


func set_camera_rig(rig: Node) -> void:
	_camera_zone.set_rig(rig)


func _ready() -> void:
	_joystick = $Joystick
	_dodge_btn = $Dodge
	_attack_btn = $Attack
	_interact_btn = $Interact
	_inventory_btn = $Inventory
	_special_btn = $Special
	_weapon_btn = $WeaponSwitch
	_soothe_btn = $Soothe
	_disrupt_btn = $Disrupt
	_camera_zone = $CameraZone
	if layout == null:
		layout = load("res://data/ui/touch_layout.tres")
	if not DisplayServer.is_touchscreen_available():
		# No touch device (desktop dev/QA, headless rig): layer stays off.
		visible = false
		return
	# Joystick pushes its vector into the provider seam (the player reads
	# it). Push-based: cross-script Callable.call() crashes the rig.
	_joystick.set_provider(_provider)
	# Action bindings for the buttons (data lives in the scene).
	_dodge_btn.action = &"dodge"
	_attack_btn.action = &"attack"
	_interact_btn.action = &"interact"
	_inventory_btn.action = &"inventory"
	_special_btn.action = &"special"
	_weapon_btn.action = &"weapon_switch"
	_soothe_btn.action = &"staff_soothe"
	_disrupt_btn.action = &"staff_disrupt"
	_place()
	_placed = true
	get_viewport().size_changed.connect(_on_viewport_resized)


func _on_viewport_resized() -> void:
	if _placed:
		_place()


func _place() -> void:
	var screen: Rect2 = get_viewport().get_visible_rect()
	var safe: Rect2 = _safe_rect()
	var base: float = minf(screen.size.x, screen.size.y)
	var joy_r: float = layout.joystick_radius * base
	var btn_r: float = layout.button_radius * base

	_joystick.set_placement(
			_clamp_center(layout.joystick_center * screen.size, joy_r, safe), joy_r)
	_dodge_btn.set_placement(
			_clamp_center(layout.dodge_center * screen.size, btn_r, safe),
			btn_r, "DODGE")
	_attack_btn.set_placement(
			_clamp_center(layout.attack_center * screen.size, btn_r, safe),
			btn_r, "ATK")
	_interact_btn.set_placement(
			_clamp_center(layout.interact_center * screen.size, btn_r, safe),
			btn_r, "USE")
	_inventory_btn.set_placement(
			_clamp_center(layout.inventory_center * screen.size, btn_r, safe),
			btn_r, "INV")
	_special_btn.set_placement(
			_clamp_center(layout.special_center * screen.size, btn_r, safe),
			btn_r, "SPC")
	_weapon_btn.set_placement(
			_clamp_center(layout.weapon_center * screen.size, btn_r, safe),
			btn_r, "SWP")
	_soothe_btn.set_placement(
			_clamp_center(layout.soothe_center * screen.size, btn_r, safe),
			btn_r, "CALM")
	_disrupt_btn.set_placement(
			_clamp_center(layout.disrupt_center * screen.size, btn_r, safe),
			btn_r, "BRK")

	var z: Rect2 = Rect2(layout.camera_zone.position * screen.size,
			layout.camera_zone.size * screen.size)
	z = z.intersection(safe)
	_camera_zone.position = z.position
	_camera_zone.size = z.size
	_camera_zone.queue_redraw()


func _safe_rect() -> Rect2:
	var sa: Rect2i = DisplayServer.get_display_safe_area()
	var m: float = float(layout.safe_margin_px)
	var vp: Rect2 = get_viewport().get_visible_rect()
	return Rect2(
			maxf(float(sa.position.x), 0.0) + m,
			maxf(float(sa.position.y), 0.0) + m,
			minf(float(sa.size.x), vp.size.x) - m * 2.0,
			minf(float(sa.size.y), vp.size.y) - m * 2.0)


func _clamp_center(center: Vector2, radius: float, safe: Rect2) -> Vector2:
	return Vector2(
			clampf(center.x, safe.position.x + radius, safe.end.x - radius),
			clampf(center.y, safe.position.y + radius, safe.end.y - radius))
