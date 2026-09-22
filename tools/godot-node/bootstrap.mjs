// Bootstrap for the headless Godot test rig.
// 1. Installs the engine packages (npm registry).
// 2. Patches @ringozz/godot-web-wasm32/src/index.ts (Node-compatible boot, preboot support).
// 3. Patches @ringozz/godot/src/boot.browser.ts (cross-bundle boot handoff via globalThis).
// 4. Bundles the minimum JS API surface (godot-api.mjs) with esbuild.
// Idempotent: safe to re-run.
import { execSync } from 'node:child_process';
import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = dirname(fileURLToPath(import.meta.url));
const nm = join(root, 'node_modules');

if (!existsSync(join(nm, '@ringozz/godot-web-wasm32'))) {
  console.log('[bootstrap] npm install...');
  execSync('npm install --no-audit --no-fund', { cwd: root, stdio: 'inherit' });
}

// --- patch 1: wasm package entry (Node-compatible, preboot-aware) ---
{
  const p = join(nm, '@ringozz/godot-web-wasm32/src/index.ts');
  const patched = `
// PATCHED by tools/godot-node/bootstrap.mjs for headless Node use.
// Original: Bun-only import attributes; boots only from a <canvas> element.
import createModule from '../gen/godot.web.template_release.wasm32.nothreads.js';

const __cfg = (globalThis as any).__GODOT_NODE_CONFIG__ ?? {};
const __dir = new URL('../gen/', import.meta.url);
const __wasm = new URL('godot.web.template_release.wasm32.nothreads.wasm', __dir);
const __audio = new URL('audio.worklet.js', __dir);
const __audioPos = new URL('audio.position.worklet.js', __dir);

function locateFile(path: string) {
  if (path.endsWith('.wasm')) return __wasm.href;
  if (path.endsWith('audio.worklet.js')) return __audio.href;
  if (path.endsWith('audio.position.worklet.js')) return __audioPos.href;
  return path;
}

let __mod: any;
if (__cfg.prebooted) {
  // Harness already booted the engine (with CLI args). Reuse it.
  __mod = __cfg.prebooted;
} else {
  const canvas = __cfg.canvas ?? document.getElementById('canvas');
  const Module = await createModule({ canvas, locateFile, arguments: __cfg.arguments ?? [] });
  Module.initConfig({ canvas, canvasResizePolicy: 2 });
  const { getDefaultContext } = await import('@emnapi/runtime');
  const context = getDefaultContext();
  __mod = Module.emnapiInit({ context });
  __mod.stageFile = Module.copyToFS;
  context.openScope();
}

export default __mod;
`;
  writeFileSync(p, patched);
  console.log('[bootstrap] patched wasm package entry');
}

// --- patch 2: boot.browser handoff via globalThis (separate bundles share one engine) ---
{
  const p = join(nm, '@ringozz/godot/src/boot.browser.ts');
  let s = readFileSync(p, 'utf8');
  if (!s.includes('__GODOT_BOOT__')) {
    s = s.replace(
      /let nativeModule: unknown = null;[\s\S]*?export function getNativeModule\(\): unknown \{\s*return nativeModule;\s*\}/,
      `// PATCHED (godot-node harness): handoff via globalThis so separate bundle
// copies (boot bundle / api bundle) share the booted module instance.
const __bootState: { nativeModule: unknown } =
    (globalThis as any).__GODOT_BOOT__ ??= { nativeModule: null };

/** The cached wasm module import (its namespace), or \`null\` until \`preloadGodot()\` completes. */
export function getNativeModule(): unknown {
    return __bootState.nativeModule;
}`,
    );
    s = s.replace(
      "return nativeModule ??= await import('@ringozz/godot-web-wasm32');",
      "return __bootState.nativeModule ??= await import('@ringozz/godot-web-wasm32');",
    );
    writeFileSync(p, s);
    console.log('[bootstrap] patched boot.browser handoff');
  }
}

// --- bundle the JS API surface (Node cannot strip TS types inside node_modules) ---
{
  const entry = join(root, 'godot-api-entry.ts');
  writeFileSync(entry, `
import '@ringozz/godot/GodotInstance';
import { getGodot } from '@ringozz/godot/runtime';
export { getGodot };
`);
  const esbuild = join(nm, '.bin', process.platform === 'win32' ? 'esbuild.cmd' : 'esbuild');
  for (const [entryName, outName] of [['godot-boot-entry.ts', 'godot-boot.mjs'], ['godot-api-entry.ts', 'godot-api.mjs']]) {
    execSync(
      `"${esbuild}" "${join(root, entryName)}" --bundle --format=esm --platform=node --conditions=browser --outfile="${join(root, outName)}" --log-level=warning`,
      { stdio: 'inherit' },
    );
    console.log('[bootstrap] built ' + outName);
  }
}
console.log('[bootstrap] done. Run: node harness.mjs [project_dir]');
