#!/usr/bin/env python3
"""gen_textures.py — the MVP's procedural texture set (ASSET_GUIDE §7).

Pure standard library (zlib + struct), deterministic (fixed seed, no
randomness source) — a re-run reproduces byte-identical PNGs. The
textures are 64x64 tileable RGBA, grayscale-ish albedo (the tinting
lives in the material, see scripts/world/texture_bank.gd).

Output (committed, small):
  assets/textures/stone.png        dungeon walls / frames
  assets/textures/stone_dark.png   obstacles / slabs
  assets/textures/ground.png       floor / camp path
  assets/textures/wood.png         barrels, crate, table
  assets/textures/wood_dark.png    logs / trunks
  assets/textures/cloth.png        Eli's cloak / NPC cloaks
  assets/textures/rust.png         The First (corrosion)
  assets/textures/fog_soft.png     the soft alpha blob (K5 shimmer, P14)

Usage:  python3 tools/utils/gen_textures.py
"""
import hashlib
import math
import os
import struct
import sys
import zlib

SIZE = 64
SEED = 20260920  # fixed: the textures are content, not noise-of-the-day

OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "textures")


def _hash2(x, y, salt=0):
    """Deterministic pseudo-random in [0, 1) for a lattice point."""
    h = hashlib.sha256(
        struct.pack("<iii", x, y, salt ^ SEED)).digest()
    return int.from_bytes(h[:4], "little") / 2 ** 32


def value_noise(x, y, freq, salt=0):
    """Tileable value noise (period = SIZE / freq grid)."""
    g = SIZE // freq
    fx, fy = (x * g) / freq, (y * g) / freq
    x0, y0 = int(fx) % g, int(fy) % g
    x1, y1 = (x0 + 1) % g, (y0 + 1) % g
    tx, ty = fx - int(fx), fy - int(fy)
    tx = tx * tx * (3 - 2 * tx)
    ty = ty * ty * (3 - 2 * ty)

    def v(cx, cy):
        return _hash2(cx, cy, salt)

    a = v(x0, y0) + (v(x1, y0) - v(x0, y0)) * tx
    b = v(x0, y1) + (v(x1, y1) - v(x0, y1)) * tx
    return a + (b - a) * ty


def px(r, g, b, a=255):
    return (max(0, min(255, int(r))), max(0, min(255, int(g))),
            max(0, min(255, int(b))), max(0, min(255, int(a))))


def stone(base, salt):
    out = []
    for y in range(SIZE):
        row = []
        for x in range(SIZE):
            n = value_noise(x, y, 8, salt) * 0.5 + value_noise(x, y, 32, salt + 7)
            c = base + (n - 0.5) * 46
            row.append(px(c, c, c * 1.02))
        out.append(row)
    return out


def ground(base, salt):
    out = []
    for y in range(SIZE):
        row = []
        for x in range(SIZE):
            n = value_noise(x, y, 16, salt) * 0.6 + value_noise(x, y, 32, salt + 3) * 0.4
            c = base + (n - 0.5) * 30
            sp = _hash2(x, y, salt + 11)
            if sp > 0.985:  # sparse pebbles
                c += 26
            row.append(px(c, c * 1.04, c * 0.92))
        out.append(row)
    return out


def wood(base, salt):
    out = []
    for y in range(SIZE):
        row = []
        for x in range(SIZE):
            ring = 0.5 + 0.5 * math.cos(
                y * 0.55 + value_noise(x, y, 16, salt) * 2.4)
            n = value_noise(x, y, 32, salt + 5)
            c = base + (ring - 0.5) * 40 + (n - 0.5) * 14
            row.append(px(c, c * 0.78, c * 0.55))
        out.append(row)
    return out


def cloth(base, salt):
    out = []
    for y in range(SIZE):
        row = []
        for x in range(SIZE):
            weave = 0.5 + 0.5 * math.sin(x * 1.57) \
                * math.cos(y * 1.57)
            n = value_noise(x, y, 32, salt)
            c = base + (weave - 0.5) * 22 + (n - 0.5) * 10
            row.append(px(c, c, c * 1.05))
        out.append(row)
    return out


def rust(base, salt):
    out = []
    for y in range(SIZE):
        row = []
        for x in range(SIZE):
            n = value_noise(x, y, 8, salt) * 0.55 + value_noise(x, y, 32, salt + 9) * 0.45
            c = base + (n - 0.5) * 52
            row.append(px(c, c * 0.62, c * 0.42))
        out.append(row)
    return out


def fog_soft():
    """A soft radial alpha blob — the K5 shimmer particle (P14)."""
    import math
    out = []
    c = SIZE // 2
    r = SIZE // 2 - 1
    for y in range(SIZE):
        row = []
        for x in range(SIZE):
            d = math.hypot(x - c + 0.5, y - c + 0.5) / r
            a = max(0.0, 1.0 - d) ** 2.2
            row.append(px(210, 215, 230, a * 255))
        out.append(row)
    return out


MATERIALS = {
    "stone": lambda: stone(96, 1),
    "stone_dark": lambda: stone(58, 2),
    "ground": lambda: ground(46, 3),
    "wood": lambda: wood(122, 4),
    "wood_dark": lambda: wood(78, 5),
    "cloth": lambda: cloth(70, 6),
    "rust": lambda: rust(120, 7),
    "fog_soft": fog_soft,
}


def write_png(path, rows):
    raw = b"".join(
        b"\x00" + b"".join(bytes(p) for p in row) for row in rows)
    def chunk(tag, data):
        c = struct.pack(">I", len(data)) + tag + data
        return c + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
    png = (b"\x89PNG\r\n\x1a\n"
           + chunk(b"IHDR", struct.pack(">IIBBBBB", SIZE, SIZE, 8, 6, 0, 0, 0))
           + chunk(b"IDAT", zlib.compress(raw, 9))
           + chunk(b"IEND", b""))
    with open(path, "wb") as f:
        f.write(png)
    return len(png)


def main():
    out = os.path.normpath(OUT_DIR)
    os.makedirs(out, exist_ok=True)
    total = 0
    for name, fn in sorted(MATERIALS.items()):
        path = os.path.join(out, name + ".png")
        size = write_png(path, fn())
        total += size
        print("  %s.png  %d bytes" % (name, size))
    print("wrote %d textures, %d bytes total -> %s"
          % (len(MATERIALS), total, out))
    return 0


if __name__ == "__main__":
    sys.exit(main())
