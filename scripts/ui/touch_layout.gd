# TouchLayout — data for the touch controls layout (TECHNICAL_DESIGN §7/§10).
#
# All positions are normalized (0..1) screen coords, y-down, anchored to the
# screen edges — so the same layout works across aspect ratios 16:9–20:9
# (ADR-021). Safe area (notch/punch-hole) is applied at runtime by clamping
# into the safe rect. Final ergonomics: device test in Phase 2/13.
class_name TouchLayout
extends Resource

# Virtual joystick: center (normalized) + radius (normalized by min(w, h)).
@export var joystick_center: Vector2 = Vector2(0.16, 0.72)
@export var joystick_radius: float = 0.14

# Buttons (normalized center + shared radius).
@export var dodge_center: Vector2 = Vector2(0.86, 0.78)
@export var attack_center: Vector2 = Vector2(0.76, 0.60)
@export var interact_center: Vector2 = Vector2(0.92, 0.52)
@export var inventory_center: Vector2 = Vector2(0.96, 0.36)
# Weapon special (BLADE: Riposte, Phase 4).
@export var special_center: Vector2 = Vector2(0.66, 0.78)
@export var button_radius: float = 0.075

# Camera drag zone (normalized rect): right side of the screen.
@export var camera_zone: Rect2 = Rect2(0.50, 0.0, 0.50, 1.0)

# Extra margin (px) inside the OS safe area for thumb comfort.
@export var safe_margin_px: int = 16


func validate() -> Array[String]:
	var problems: Array[String] = []
	if not (joystick_center.x < 0.35 and joystick_center.y > 0.4):
		problems.append("joystick must be in the left-bottom quadrant")
	if camera_zone.position.x < 0.45:
		problems.append("camera zone must stay in the right half")
	var centers: Array[Vector2] = [
		dodge_center, attack_center, interact_center, inventory_center,
		special_center,
	]
	if joystick_center.distance_to(centers[0]) < joystick_radius + button_radius:
		problems.append("joystick overlaps the dodge button")
	for i in centers.size():
		if centers[i].x < 0.0 or centers[i].x > 1.0 \
				or centers[i].y < 0.0 or centers[i].y > 1.0:
			problems.append("button %d outside 0..1" % i)
		for j in range(i + 1, centers.size()):
			if centers[i].distance_to(centers[j]) < button_radius * 2.0:
				problems.append("buttons %d and %d overlap" % [i, j])
	return problems
