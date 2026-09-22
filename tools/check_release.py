#!/usr/bin/env python3
# check_release — Phase 18 readiness audit (runs in the sandbox;
# the actual APK build is the owner's step, RELEASE_BUILD.md).
#
# Pure standard library. Checks:
#   1. project.godot: version, icon, landscape lock, stretch.
#   2. export_presets.cfg: the two Android presets, package
#      names, minSdk 26, exclude filters.
#   3. Broken resource references (every ext_resource path in
#      .tscn/.tres must exist).
#   4. Test/tooling leakage: game files must not reference
#      res://tests/, res://tools/, res://docs/.
#   5. Placeholders: no TODO/FIXME/HACK/XXX/PLACEHOLDER markers
#      in game code/scenes/data (the P13 house rule, re-audited
#      at the release gate).
#   6. Debug gate integrity: the debug tool handlers AND their
#      node creation are OS.is_debug_build()-gated.
#   7. Icon: a valid PNG, >= 512 px.
#   8. APK-size estimate vs the ~2 GB budget (§15.2).
#   9. .gitignore: signing secrets excluded.
#   10. Version consistency across project.godot and presets.
# Exit 0 = release-ready (on the sandbox side), 1 = problems.
import os
import re
import struct
import sys
import zlib

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), ".."))
FAILS = []


def check(ok, label):
    print(("PASS  " if ok else "FAIL  ") + label)
    if not ok:
        FAILS.append(label)


def read(p):
    with open(os.path.join(ROOT, p), "r", encoding="utf-8") as f:
        return f.read()


def rglob_files(patterns):
    out = []
    for pat in patterns:
        base = os.path.join(ROOT, pat)
        for dirpath, _dirnames, filenames in os.walk(base):
            for fn in filenames:
                full = os.path.join(dirpath, fn)
                out.append(os.path.relpath(full, ROOT).replace(os.sep, "/"))
    return sorted(set(out))


def main():
    # 1. project.godot -------------------------------------------------
    proj = read("project.godot")
    m = re.search(r'^config/version="([^"]+)"', proj, re.M)
    version = m.group(1) if m else None
    check(bool(version), "project: config/version present (%s)" % version)
    m = re.search(r'^config/icon="([^"]+)"', proj, re.M)
    icon = m.group(1) if m else None
    check(icon == "res://icon.png" and os.path.exists(
        os.path.join(ROOT, "icon.png")),
        "project: the icon is wired (icon.png exists)")
    check('window/handheld/orientation=0' in proj,
          "project: landscape lock (orientation=0)")
    check('window/stretch/mode="canvas_items"' in proj
          and 'window/stretch/aspect="expand"' in proj,
          "project: canvas_items + expand (safe-area ready)")
    check('"Forward Plus"' in proj,
          "project: Forward Plus renderer (§15.1)")

    # 2. export presets ------------------------------------------------
    check(os.path.exists(os.path.join(ROOT, "export_presets.cfg")),
          "presets: export_presets.cfg exists")
    if os.path.exists(os.path.join(ROOT, "export_presets.cfg")):
        cfg = read("export_presets.cfg")
        check(cfg.count('platform="Android"') == 2,
              "presets: exactly two Android presets")
        check('name="Android QA"' in cfg and 'name="Android"' in cfg,
              "presets: the QA (debug) + release presets named")
        check('package/unique_name="after.you.qa"' in cfg
              and 'package/unique_name="after.you"' in cfg,
              "presets: the package names (QA vs release)")
        check(cfg.count('gradle_build/min_sdk="26"') == 2,
              "presets: minSdk 26 on both (§15.2)")
        check('exclude_filter="tests/*,tools/*,docs/*"' in cfg
              and cfg.count('exclude_filter=') == 2,
              "presets: tests/tools/docs excluded from the APK")
        for v in [version, None]:
            pass
        if version:
            check('version/name="%s"' % version in cfg,
                  "presets: the release version name matches "
                  "(%s)" % version)

    # 3. broken references --------------------------------------------
    broken = []
    res_files = rglob_files(["scenes", "assets", "data", "shaders"])
    ext_re = re.compile(r'path="res://([^"]+)"')
    for rel in res_files:
        if not rel.endswith((".tscn", ".tres")):
            continue
        text = read(rel)
        for mref in ext_re.finditer(text):
            target = mref.group(1)
            p = os.path.join(ROOT, target.replace("res://", ""))
            if not os.path.exists(p):
                broken.append("%s -> res://%s" % (rel, target))
    check(not broken, "refs: no broken ext_resource paths (%d broken)"
          % len(broken))
    for b in broken[:10]:
        print("        " + b)

    # 4. test/tooling leakage ------------------------------------------
    leak = []
    game_files = rglob_files(["scenes", "scripts", "data", "shaders",
                              "assets"])
    bad_ref = re.compile(r'res://(tests|tools|docs)/')
    for rel in game_files:
        if rel.endswith((".gd", ".tscn", ".tres", ".gdshader")):
            if bad_ref.search(read(rel)):
                leak.append(rel)
    check(not leak, "leak: no game file references tests/tools/docs"
          " (%d leaking)" % len(leak))
    for l in leak[:10]:
        print("        " + l)

    # 5. placeholders ----------------------------------------------------
    markers = re.compile(r"\b(TODO|FIXME|HACK|XXX|PLACEHOLDER)\b")
    dirty = []
    for rel in rglob_files(["scripts", "scenes", "data"]):
        if rel.endswith((".gd", ".tscn", ".tres")):
            for i, line in enumerate(read(rel).splitlines(), 1):
                if markers.search(line):
                    dirty.append("%s:%d" % (rel, i))
    check(not dirty, "placeholders: none in game code (%d found)"
          % len(dirty))
    for d in dirty[:10]:
        print("        " + d)

    # 6. debug gate integrity --------------------------------------------
    ms = read("scripts/world/main_scene.gd")
    handlers_gated = len(re.findall(
        r"func _debug_\w+.*?OS\.is_debug_build\(\)", ms, re.S))
    check(handlers_gated >= 4,
          "debug gate: the F1/F6/F8/F9 handlers are gated (%d)"
          % handlers_gated)
    m = re.search(r"if OS\.is_debug_build\(\):\n"
                  r"\t\tdebug_overlay = _DEBUG_OVERLAY\.new\(\)", ms)
    check(bool(m), "debug gate: DebugOverlay creation is gated (P18)")
    m = re.search(r"if OS\.is_debug_build\(\):\n"
                  r"\t\tdebug_overlay = _DEBUG_OVERLAY\.new\(\)"
                  r".*?perf_bench = _PERF_BENCH\.new\(\)", ms, re.S)
    check(bool(m), "debug gate: PerfBenchmark creation is gated (P18)")

    # 7. icon -------------------------------------------------------------
    ip = os.path.join(ROOT, "icon.png")
    if os.path.exists(ip):
        d = open(ip, "rb").read()
        ok_png = d[:8] == b"\x89PNG\r\n\x1a\n"
        w = h = 0
        if ok_png:
            w, h = struct.unpack(">II", d[16:24])
        check(ok_png and w >= 512 and h >= 512,
              "icon: valid PNG %dx%d" % (w, h))
        # a CRC sanity pass over the chunks
        i = 8
        crc_ok = True
        while i < len(d) and crc_ok:
            (ln,) = struct.unpack(">I", d[i:i + 4])
            tag = d[i + 4:i + 8]
            data = d[i + 8:i + 8 + ln]
            (crc,) = struct.unpack(">I", d[i + 8 + ln:i + 12 + ln])
            if (zlib.crc32(tag + data) & 0xFFFFFFFF) != crc:
                crc_ok = False
            i += 12 + ln
        check(crc_ok, "icon: chunk CRCs valid")
    else:
        check(False, "icon: icon.png exists")

    # 8. APK size estimate -------------------------------------------------
    total = 0
    for dirpath, _dirs, files in os.walk(os.path.join(ROOT, "assets")):
        for fn in files:
            total += os.path.getsize(os.path.join(dirpath, fn))
    template_est = 60 * 1024 * 1024  # Godot 4 Android template ~60 MB
    est = total + template_est
    check(est < 2 * 1024 * 1024 * 1024,
          "size: estimate %.1f MB (assets %.1f MB + template) "
          "< 2 GB budget" % (est / 1048576, total / 1048576))

    # 9. gitignore ----------------------------------------------------------
    gi = read(".gitignore")
    check("*.keystore" in gi and "*.jks" in gi,
          "gitignore: the signing secrets are excluded (§15.3)")

    # 10. summary -------------------------------------------------------------
    print()
    if FAILS:
        print("=== check_release: %d PROBLEM(S) — not release-ready ==="
              % len(FAILS))
        return 1
    print("=== check_release: RELEASE-READY (sandbox side) ===")
    print("(the APK build + ADB-QA run: RELEASE_BUILD.md §3–§5)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
