# tools/godot-node — headless Godot 4.7.2 test rig

Godot **4.7.2** (wasm32 build, npm `@ringozz/godot` 4.7.2-626) running on
Node 22 — lets the sandbox execute the game's **logic** without a GPU or the
native binary (which is unreachable from this network environment — see
docs/DECISIONS.md ADR-002).

## Files
- `bootstrap.mjs` — idempotent setup: npm install + 2 small patches
  (Node-compatible boot, cross-bundle handoff) + esbuild bundles.
- `harness.mjs` — the runner: DOM shim (jsdom) → engine boot (`--headless`)
  → stage project files into the engine MEMFS → frame pump (~60fps) →
  exit code. `--tests` mode swaps `run/main_scene` to
  `res://tests/runner.tscn` for the run (backup/restore, crash-safe).
- `godot-boot.mjs` / `godot-api.mjs` — generated bundles (do not edit).

## Verified capabilities (Phase 0 spike)
scenes, GDScript, text resources (.tscn/.tres/.gd), signals, timers
(explicit `Timer.start()`), `_ready`/`_process`/`_physics_process`
(fixed 60Hz), math, File I/O (MEMFS), `quit(rc)`.

## Verified limitations (do not design tests around these)
- **no 3D physics** (Dummy server: gravity/collisions/`move_and_slide` are
  no-ops) → movement logic is tested through `MockMovementPort`
  (docs/ARCHITECTURE.md §3.4);
- navigation classes partially absent → pathfinding logic is plain code with
  an injectable navmesh source;
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
