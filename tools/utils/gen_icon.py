# gen_icon — the app icon (Phase 18, RELEASE_BUILD).
#
# Pure standard library (zlib + struct), deterministic (no RNG): the
# icon is ORIGINAL procedural work — a camp fire on a graded dark
# ground (the game's visual language: monochrome slate + one warm
# ember accent), same house pattern as gen_textures.py. No third-
# party content (ASSET_LICENSES: 0 external assets).
import os
import struct
import zlib

SIZE = 1024
OUT = "icon.png"


def px(r, g, b, a=255):
    return bytes((int(r), int(g), int(b), a))


def lerp(a, b, t):
    return a + (b - a) * t


def flame_mask(cx, base_y, w, h, x, y):
    # A teardrop: a circle (the head) + a triangle down to the point.
    r = w / 2.0
    top_cy = base_y - h + r
    dx, dy = x - cx, y - top_cy
    if dx * dx + dy * dy <= r * r:
        return True
    # the tail: a triangle narrowing to (cx, base_y)
    if y > top_cy and y <= base_y:
        t = (y - top_cy) / (base_y - top_cy)
        half = r * (1.0 - t) * 0.92
        if abs(x - cx) <= half:
            return True
    return False


def main():
    rows = []
    for y in range(SIZE):
        row = []
        t = y / SIZE
        # graded background: near-black slate, a faint ember warmth
        # rising from the base.
        bg_r = lerp(24, 40, t * t)
        bg_g = lerp(21, 29, t * t)
        bg_b = lerp(19, 23, t * t)
        for x in range(SIZE):
            c = px(bg_r, bg_g, bg_b)
            cx = SIZE / 2.0
            base_y = 740.0
            # outer -> middle -> inner flame (last wins: brighter).
            if flame_mask(cx, base_y, 360, 430, x, y):
                c = px(122, 62, 28)
            if flame_mask(cx, base_y - 26, 250, 300, x, y):
                c = px(191, 104, 41)
            if flame_mask(cx, base_y - 52, 130, 160, x, y):
                c = px(238, 178, 96)
            # the crossed logs under the fire.
            if 292 <= x <= 732 and y >= 745 and y <= 825:
                # two bars: y = 800 - x*0.103 and y = 756 + x*0.103
                d1 = abs(y - (800.0 - (x - 300.0) * 0.1035))
                d2 = abs(y - (756.0 + (x - 300.0) * 0.1035))
                if d1 <= 27:
                    c = px(58, 44, 33)
                if d2 <= 27:
                    c = px(47, 36, 27)
            # the log end (a small ellipse on the left).
            if 272 <= x <= 330 and 728 <= y <= 830:
                nx = (x - 301.0) / 29.0
                ny = (y - 779.0) / 51.0
                if nx * nx + ny * ny <= 1.0:
                    c = px(70, 53, 39)
            # the ground line: the world remembers.
            if 120 <= x <= 904 and 852 <= y <= 858:
                c = px(64, 50, 38)
            row.append(c)
        rows.append(row)

    raw = b"".join(b"\x00" + b"".join(row) for row in rows)

    def chunk(tag, data):
        c = struct.pack(">I", len(data)) + tag + data
        return c + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    png = (b"\x89PNG\r\n\x1a\n"
           + chunk(b"IHDR",
                   struct.pack(">IIBBBBB", SIZE, SIZE, 8, 6, 0, 0, 0))
           + chunk(b"IDAT", zlib.compress(raw, 9))
           + chunk(b"IEND", b""))
    out = os.path.normpath(OUT)
    with open(out, "wb") as f:
        f.write(png)
    print("wrote %s (%d bytes)" % (out, len(png)))


if __name__ == "__main__":
    main()
