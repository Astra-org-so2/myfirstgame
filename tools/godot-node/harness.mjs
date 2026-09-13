// Headless Godot 4.7.2 test harness (wasm engine on Node).
//
// Boots the engine with --headless, stages the project files into the engine's
// in-memory FS (the wasm build cannot read the host filesystem), pumps frames
// at ~60fps (jsdom requestAnimationFrame + GodotInstance.iteration()), and
// reports the test result back through the `TESTS_DONE rc=<n>` stdout marker
// emitted by the GDScript test runner (see tests/ for the runner template).
//
// Usage (cwd must be the Godot project directory, or pass it as first arg):
//   node harness.mjs [project_dir]
//
// Exit codes: 0 = all tests passed, n = n test failures, 124 = timeout.
import { JSDOM, VirtualConsole } from 'jsdom';
import { readFileSync, readdirSync, statSync, existsSync, copyFileSync, writeFileSync, renameSync } from 'node:fs';
import { join, relative } from 'node:path';

const args = process.argv.slice(2);
const testMode = args.includes('--tests');
const posArgs = args.filter(a => !a.startsWith('-'));
const projectDir = posArgs[0] || '.';
const hardTimeoutSec = Number(process.env.HARNESS_TIMEOUT ?? 300);
const selfDir = new URL('.', import.meta.url);
const glueDir = new URL('node_modules/@ringozz/godot-web-wasm32/gen/', selfDir);
const glueUrl = new URL('godot.web.template_release.wasm32.nothreads.js', glueDir);

// --- DOM shim: the engine's JS glue expects a minimal browser environment ---
const dom = new JSDOM('<!doctype html><html><body><canvas id="canvas" width="128" height="72"></canvas></body></html>', {
  pretendToBeVisual: true,
  url: 'http://localhost/?',
  virtualConsole: new VirtualConsole(),
});
const w = dom.window;
w.alert = () => {};
w.confirm = () => true;
w.prompt = () => null;
for (const k of ['document', 'location', 'navigator', 'localStorage', 'sessionStorage', 'HTMLCanvasElement', 'Image', 'FileReader', 'Blob', 'File', 'XMLHttpRequest', 'DOMParser', 'CustomEvent', 'Event', 'MessageChannel']) {
  if (w[k] !== undefined) {
    try { Object.defineProperty(globalThis, k, { value: w[k], configurable: true, writable: true }); } catch {}
  }
}
try { Object.defineProperty(globalThis, 'window', { value: w, configurable: true, writable: true }); } catch {}
// Keep Node's native performance (jsdom's recurses when installed globally).
if (!globalThis.requestAnimationFrame) globalThis.requestAnimationFrame = w.requestAnimationFrame.bind(w);
if (!globalThis.fetch) globalThis.fetch = (u, o) => fetch(new URL(String(u), 'http://localhost/'), o);
if (!globalThis.crypto) globalThis.crypto = crypto;
URL.createObjectURL = () => `blob:shim-${Math.random().toString(36).slice(2, 10)}`;
URL.revokeObjectURL = () => {};
const canvasEl = w.document.getElementById('canvas');
canvasEl.getContext = () => null; // headless: engine must never touch the GL context
w.HTMLCanvasElement.prototype.getContext = () => null;

// --- boot the engine (args are fixed to --headless; this build has no CLI parsing) ---
const createModule = (await import(glueUrl)).default;
const wasmPath = new URL('godot.web.template_release.wasm32.nothreads.wasm', glueDir);
const origWrite = process.stdout.write.bind(process.stdout);
let markerRc = null;
const Module = {
  canvas: canvasEl,
  locateFile: (p) => {
    if (p.endsWith('.wasm')) return wasmPath.href;
    if (p.endsWith('audio.worklet.js')) return new URL('audio.worklet.js', glueDir).href;
    if (p.endsWith('audio.position.worklet.js')) return new URL('audio.position.worklet.js', glueDir).href;
    return p;
  },
  arguments: ['--headless'],
  print: (...a) => {
    const line = a.join(' ') + '\n';
    const m = line.match(/TESTS_DONE rc=(\d+)/);
    if (m) markerRc = Number(m[1]);
    return origWrite(line);
  },
  printErr: (...a) => process.stderr.write(a.join(' ') + '\n'),
};
Module.wasmBinary = new Uint8Array(readFileSync(wasmPath));

const t0 = Date.now();
const mod = await createModule(Module);
mod.initConfig({ canvas: canvasEl, canvasResizePolicy: 2 });

// Test mode: swap run/main_scene to the test runner (crash-safe restore).
if (testMode) {
  const root0 = projectDir === '.' ? process.cwd() : new URL(projectDir, import.meta.url).pathname;
  const pg = root0 + '/project.godot';
  const bak = pg + '.aybak';
  try {
    if (existsSync(bak)) {
      console.error('[harness] found leftover .aybak from a crashed run - restoring');
      renameSync(bak, pg);
    }
    copyFileSync(pg, bak);
    const t = readFileSync(pg, 'utf8');
    if (/run\/main_scene=/.test(t)) {
      writeFileSync(pg, t.replace(/run\/main_scene=.*/, 'run/main_scene="res://tests/runner.tscn"'));
    } else {
      writeFileSync(pg, t + '\nrun/main_scene="res://tests/runner.tscn"\n');
    }
    console.error('[harness] test mode: main scene swapped to res://tests/runner.tscn');
  } finally {}
}

// Stage project files into the engine's MEMFS (skip .godot import cache & VCS dirs).
{
  const root = projectDir === '.' ? process.cwd() : new URL(projectDir, import.meta.url).pathname;
  const walk = (dir, out = []) => {
    for (const e of readdirSync(dir)) {
      if (e === '.godot' || e === '.git' || e === 'node_modules') continue;
      const p = join(dir, e);
      if (statSync(p).isDirectory()) walk(p, out);
      else out.push(p);
    }
    return out;
  };
  const files = walk(root);
  for (const f of files) {
    const rel = relative(root, f).split(/[\\/]/).join('/');
    mod.copyToFS('/' + rel, readFileSync(f));
  }
  console.error(`[harness] staged ${files.length} project files from ${root}`);
}

// --- exit handling (defined before boot so boot failures can use it) ---
let finished = false;
const done = (code, msg) => {
  if (finished) return;
  finished = true;
  if (msg) console.error('[harness] ' + msg);
  if (testMode) {
    const root0 = projectDir === '.' ? process.cwd() : new URL(projectDir, import.meta.url).pathname;
    const pg = root0 + '/project.godot';
    const bak = pg + '.aybak';
    try { if (existsSync(bak)) renameSync(bak, pg); } catch (e) { console.error('[harness] restore failed:', e.message); }
  }
  process.exit(code);
};

let nmod;
try {
  const { getDefaultContext } = await import('@emnapi/runtime');
  const context = getDefaultContext();
  nmod = mod.emnapiInit({ context });
  context.openScope();
} catch (e) {
  done(1, 'engine instance creation failed (main scene missing/broken?): ' + e.message);
}
console.error(`[harness] Godot booted in ${Date.now() - t0}ms`);

// --- keep alive + watchdog ---
globalThis.__GODOT_NODE_CONFIG__ = { prebooted: nmod };
const { preloadGodot } = await import(new URL('./godot-boot.mjs', import.meta.url));
await preloadGodot();
const { getGodot } = await import(new URL('./godot-api.mjs', import.meta.url));
const godot = getGodot();
console.error('[harness] started=' + godot.isStarted() + '; pumping frames...');

(async () => {
  try {
    while (!godot.iteration()) {
      await new Promise((r) => w.requestAnimationFrame(r));
    }
    console.error('[harness] main loop exited');
    if (markerRc !== null) done(markerRc);
    else { console.error('[harness] no TESTS_DONE marker received'); done(1); }
  } catch (e) {
    console.error('[harness] pump error:', e);
    done(1);
  }
})();
