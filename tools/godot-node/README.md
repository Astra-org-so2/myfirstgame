# tools/godot-node — headless Godot 4.7.2 test rig

Godot **4.7.2** (wasm32 build, npm `@ringozz/godot` 4.7.2-626) running on
Node 22 — lets the sandbox execute the game's **logic** without a GPU or the
native binary (which is unreachable from this network environment — see
docs/DECISIONS.md ADR-002).

## Files
- `bootstrap.mjs` — idempotent setup: npm install + 2 small patches
  (Node-compatible boot, cross-bundle handoff) + esbuild bundles.
- `harness.mjs` — the runner: DOM shim (jsdom) → engine boot (`--headless`)
  → stage project files into the engine MEMFS → `GodotInstance.resume()`
  (the wasm instance boots paused; node callbacks don't fire until it's
  called) → frame pump (~60fps) → exit code. `--tests` mode swaps
  `run/main_scene` to `res://tests/runner.tscn` for the run (backup/restore,
  crash-safe).
- `godot-boot.mjs` / `godot-api.mjs` — generated bundles (do not edit).

## Verified capabilities
scenes, GDScript, text resources (.tscn/.tres/.gd), signals, timers,
`_ready`, math, File I/O (MEMFS), `quit(rc)`. After `GodotInstance.resume()`
(the harness calls it before the pump — the wasm instance boots paused):
`_process`/`_physics_process` run at a fixed 60 Hz during the pump.

## Verified limitations (do not design tests around these)
Full register — docs/DECISIONS.md ADR-022 (every item reproduced in
`/tmp` probes before being documented):
- **no 3D physics** (Dummy server: gravity/collisions/`move_and_slide` are
  no-ops) → movement is tested through `MovementPort` mock mode
  (docs/ARCHITECTURE.md §3.4);
- **no global class_name registry at runtime** → all cross-file references
  are `const _X = preload("res://...")` (types, `_X.new()`, statics,
  enums, `is`); `extends` — built-ins only;
- **cross-script `Callable.call()` crashes the engine (FATAL)** →
  push-based seams (source calls the receiver's method), never pull-by-Callable;
- **script method shadowing a built-in method of the base class crashes
  cross-script calls** (repro: `CameraRig.rotate` vs `Node3D.rotate`) →
  rename (in project: `orbit`);
- **missing globals/APIs**: `sinf/cosf/tanf/atanf/expf` (use
  `sin/cos/tan/atan/exp`), `Node3D.get_global_origin()` (use
  `global_position`), `Node3D.modulate` (absent; 3D flash via mesh material
  albedo), `JoyAxis.*` members (use `AXIS_RIGHT_X/Y` int consts),
  `OS.get_frame()`, `Engine.is_paused()`, `SceneTree.is_running()`;
- **`Input.parse_input_event` does not feed the action state** → tests use
  `Input.action_press/release` (synchronous, verified);
- **`is_action_just_pressed` is only cleared by real frame boundaries** →
  production edge logic uses held-edge (pressed this tick, not last) —
  see `PlayerController`;
- **frame timing is not trustworthy for test logic**: engine time can elapse
  during boot, before the pump starts (node callbacks silent then) →
  integration tests drive the clock deterministically: manual
  `node._physics_process(DT)` ticks with fixed `DT = 1/60` (see
  `tests/integration/player_scene_test.gd`);
- navigation classes partially absent → pathfinding logic is plain code with
  an injectable navmesh source;
- **geometry is partially registered** (Phase 3): `ConeMesh` (and the
  NavMesh pair) are absent from the wasm build; `BoxMesh/CylinderMesh/
  SphereMesh/CapsuleMesh` work. A cone = `CylinderMesh(radial_segments=3,
  top_radius≈0)`. The `.ts` declarations in `@ringozz/godot/gen` describe
  the FULL API, not what this build registers — verify against the .wasm;
- `MultiMesh` defaults to `TRANSFORM_2D` — set `transform_format = 1`
  for 3D instances; `Basis` only exposes the axes constructor
  (`Basis(Vector3, Vector3, Vector3)`);
- `PackedVector3Array` has no float-varargs constructor; `Node.find_children`
  has a different signature (arg 2 is a String) — use `find_child`;
- no rendering, no audio output (expected for headless).

## Usage
```sh
./tools/run_tests.sh              # all suites
./tools/run_tests.sh unit         # unit-only
./tools/run_tests.sh integration  # integration-only
```

### Filtering
`run_tests.sh` exports `TEST_FILTER`; the harness writes it to
`tests/.test_filter` before staging (the wasm engine cannot read host env
vars — a project file is the supported channel). The runner
(`tests/runner.gd`) skips suites whose tags don't match; the file is
deleted on exit (crash-safe).

### Exit codes (contract for CI)
- `0` — all matched tests passed (or none matched);
- `N` — N failed tests (the runner prints `TESTS_DONE rc=N`);
- `124` — hard timeout (watchdog: `HARNESS_TIMEOUT`, default 300 s) —
  the game never called `get_tree().quit()` (e.g. a swallowed script
  error);
- `1` — infra error (engine boot / main-scene load failure).
