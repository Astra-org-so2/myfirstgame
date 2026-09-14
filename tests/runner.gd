# AFTER YOU — test runner (headless rig; see tools/godot-node/README.md).
#
# Entry point for `--tests` mode: the harness swaps run/main_scene to this
# scene. Runs the matching test suites, prints per-test PASS/FAIL lines and
# a final `TESTS_DONE rc=<N>` marker (N = failed count), then quits with N.
#
# Filtering: the harness writes tests/.test_filter (all|unit|integration)
# before the run (the wasm engine cannot read host env vars). Each suite
# declares its tags; a suite runs if its tag matches the filter (or the
# filter is "all").
#
# Suite entry: [name, target, [tags...]] where target is either a method
# on this node (legacy, built-in suites) or a path to a test class script
# (a Node with `func run(ctx: Node)` — the class instantiates, joins the
# tree, runs, and is freed).
#
# Note (ADR-022): the headless wasm rig has no global class_name registry —
# cross-file references in all project scripts use preload-consts.
extends Node

const _PLAYER_SCRIPT = preload("res://scripts/player/player_controller.gd")

const SUITES = [
	["smoke", "suite_smoke", ["unit"]],
	["player_data", "res://tests/unit/player_data_test.gd", ["unit"]],
	["movement_logic", "res://tests/unit/movement_logic_test.gd", ["unit"]],
	["camera_rig", "res://tests/unit/camera_rig_test.gd", ["unit"]],
	["touch_layout", "res://tests/unit/touch_layout_test.gd", ["unit"]],
	["player_scene", "res://tests/integration/player_scene_test.gd",
			["integration"]],
]

var _failed: int = 0
var _passed: int = 0


func _ready() -> void:
	var filter: String = _read_filter()
	print("=== AFTER YOU test runner (filter: %s) ===" % filter)
	var ran: int = 0
	for entry in SUITES:
		var suite_name: String = entry[0]
		var target: String = entry[1]
		var tags: Array = entry[2]
		if filter != "all" and not tags.has(filter):
			continue
		ran += 1
		print("-- suite: " + suite_name)
		await _run_suite(target)
	if ran == 0:
		print("(no suites matched filter: %s)" % filter)
	print("=== summary: %d passed, %d failed ===" % [_passed, _failed])
	print("TESTS_DONE rc=%d" % _failed)
	get_tree().quit(_failed)


func _run_suite(target: String) -> void:
	if target.begins_with("res://"):
		var script: Script = load(target)
		if script == null:
			check(false, "runner: suite script loads: " + target)
			return
		var test: Node = script.new()
		add_child(test)
		await test.run(self)
		test.queue_free()
	else:
		if not has_method(target):
			check(false, "runner: suite method exists: " + target)
			return
		call(target)


func _read_filter() -> String:
	var f: FileAccess = FileAccess.open("res://tests/.test_filter", FileAccess.READ)
	if f == null:
		return "all"
	var v: String = f.get_line().strip_edges()
	f.close()
	return v if v != "" else "all"


# Public check API for test classes (ctx = this node).
func check(condition: bool, test_name: String) -> void:
	if condition:
		_passed += 1
		print("PASS " + test_name)
	else:
		_failed += 1
		print("FAIL " + test_name)


# ---------------------------------------------------------------------------
# Phase 1/2 — smoke: project boots, input map is complete, main scene loads.
# ---------------------------------------------------------------------------

const EXPECTED_ACTIONS: Array[String] = [
	"move_up", "move_down", "move_left", "move_right",
	"sprint", "dodge", "attack", "ranged_attack",
	"interact", "inventory", "pause",
	"camera_left", "camera_right", "camera_up", "camera_down",
	"ui_left", "ui_right", "ui_up", "ui_down", "ui_accept", "ui_cancel",
	"debug_f1", "debug_f2", "debug_f3", "debug_f4", "debug_f5",
	"debug_f6", "debug_f7", "debug_f8", "debug_f9",
]

func suite_smoke() -> void:
	# 1. The runner itself started (we are here) — engine booted headless.
	check(true, "smoke: runner started (engine booted)")

	# 2. Input map is complete (TECHNICAL_DESIGN §7: touch actions are the
	#    same actions; kb/m + gamepad layouts live in project.godot).
	var actions_list: Array = InputMap.get_actions()
	for action in EXPECTED_ACTIONS:
		check(
			InputMap.has_action(action)
				and InputMap.action_get_events(action).size() > 0
				and actions_list.has(action),
			"smoke: input_map action bound: " + action
		)

	# 3. Main scene loads and has the expected structure (hub + player).
	var packed: PackedScene = load("res://scenes/main.tscn")
	check(packed != null, "smoke: main scene loads")
	if packed == null:
		return
	var scene: Node = packed.instantiate()
	check(scene != null and scene is Node3D, "smoke: main scene root is Node3D")
	check(
		scene.find_child("Camera3D", true, false) is Camera3D,
		"smoke: main scene has Camera3D"
	)
	check(
		scene.find_child("WorldEnvironment", true, false) is WorldEnvironment,
		"smoke: main scene has WorldEnvironment (fog)"
	)
	check(
		scene.find_child("Sun", true, false) is DirectionalLight3D,
		"smoke: main scene has DirectionalLight3D"
	)
	check(
		scene.find_child("Ground", true, false) is MeshInstance3D,
		"smoke: main scene has Ground mesh"
	)
	# has_method (not just script identity): a failed-to-compile script is
	# still attached to the node, so identity alone would pass vacuously.
	var player_node: Node = scene.find_child("Player", true, false)
	check(
		player_node != null
			and player_node is CharacterBody3D
			and player_node.get_script() == _PLAYER_SCRIPT
			and player_node.has_method("take_hit")
			and player_node.has_method("respawn"),
		"smoke: main scene has Player (PlayerController)"
	)
	check(
		scene.find_child("SpawnPoint", true, false) is Marker3D,
		"smoke: main scene has SpawnPoint"
	)
	check(
		scene.find_child("TouchControls", true, false) is CanvasLayer,
		"smoke: main scene has TouchControls"
	)
	scene.free()

	# 4. Mobile-first config (ADR-021). Headless rig runs the dummy
	#    renderer, so we assert the PROJECT SETTING (config), not the
	#    active renderer.
	check(
		ProjectSettings.get_setting(
			"rendering/renderer/rendering_method", ""
		) == "forward_plus",
		"smoke: project setting renderer = forward_plus"
	)
	check(
		ProjectSettings.get_setting(
			"display/window/handheld/orientation", -1
		) == 0,
		"smoke: project setting orientation = landscape"
	)
