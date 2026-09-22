#!/usr/bin/env bash
# AFTER YOU — headless test runner (Godot 4.7.2 wasm rig on Node).
# Usage: ./tools/run_tests.sh [unit|integration|all]   (default: all)
# Exit code: 0 = all passed, N = N failed, 124 = timeout, 2 = infra error.
set -euo pipefail
cd "$(dirname "$0")/.."

RIG=tools/godot-node
if [ ! -d "$RIG/node_modules" ] || [ ! -f "$RIG/godot-api.mjs" ]; then
  echo "[run_tests] first run: bootstrapping the headless rig..."
  node "$RIG/bootstrap.mjs"
fi

MODE="${1:-all}"
export TEST_FILTER="$MODE"

# Safety: no leftover backup from a crashed run.
if [ -f project.godot.aybak ]; then
  echo "[run_tests] restoring project.godot from leftover .aybak"
  mv -f project.godot.aybak project.godot
fi

node "$RIG/harness.mjs" --tests
