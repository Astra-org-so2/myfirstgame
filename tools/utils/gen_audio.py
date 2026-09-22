#!/usr/bin/env python3
"""gen_audio.py — the procedural soundtrack (Phase 14, GDD v2.0 §7).

One melody, «The Wound», in five variations (normal / memory / echo /
archivist / ending) + six ambient layers (camp / wild / stone / mine /
lake / undercroft) + one stinger (the boss reveal).

The same contract as gen_textures.py: pure stdlib (wave / math /
random), a fixed seed (byte-stable regeneration), 0 ₽ budget — the
soundtrack is math, not assets. The engine is the port of
MusicLibrary's GDScript reference (P14): 11025 Hz mono 16-bit
(halves runtime memory vs 22050 — music and ambients carry no
content above ~3.1 kHz).

Output: assets/audio/*.wav (12 files, ~5.5 MB total).
"""

import math
import os
import random
import struct
import wave

RATE = 11025
MUSIC_PEAK = 0.85
AMB_PEAK = 0.35

BEAT = 1.0
# The 8-beat phrase: rises, does not resolve (D minor).
MOTIF = [293.66, 349.23, 440.0, 587.33, 523.25, 440.0, 349.23, 329.63]
# The 8-beat answer: lower, still open. The loop seam lands on D4.
RESPONSE = [220.0, 293.66, 349.23, 440.0, 329.63, 349.23, 293.66, 293.66]
LOOP_BEATS = 24
MUSIC_XFADE = 0.25

STINGER_DUR = 4.0
STINGER_HIT_AT = 3.0

AMB_DUR = 16.0
AMB_XFADE = 0.5

SEEDS = {
    "camp": 0xC0A1,
    "wild": 0x51A7,
    "stone": 0x570E,
    "mine": 0x21E7,
    "lake": 0xA0E4,
    "undercroft": 0xD00F,
}

OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "audio")


# --- The melody engine ----------------------------------------------------

def add_note(buf, start, dur, freq, harmonics, gain, attack, release,
             reversed_note):
    n0 = int(start * RATE)
    if n0 >= len(buf):
        return
    n1 = min(int((start + dur + release) * RATE), len(buf))
    for i in range(n0, n1):
        t = (i - n0) / RATE
        body = 0.0
        for hi, amp in enumerate(harmonics):
            body += math.sin(2 * math.pi * freq * (hi + 1) * t) * amp
        if not reversed_note:
            if t < attack:
                env = t / attack
            elif t < dur:
                env = 1.0
            else:
                env = max(0.0, 1.0 - (t - dur) / release)
        else:
            rt = (dur + release) - t
            if rt < 0.0 or rt > dur + release:
                env = 0.0
            elif rt < attack:
                env = 1.0 - rt / attack
            elif rt < dur:
                env = 1.0
            else:
                env = max(0.0, 1.0 - (rt - dur) / release)
        buf[i] += body * env * gain


def melody(spec):
    oct = spec.get("oct", 1.0)
    harmonics = spec.get("harmonics", [1.0])
    gain = spec.get("gain", 0.4)
    attack = spec.get("attack", 0.02)
    release = spec.get("release", 0.3)
    staccato = spec.get("staccato", 0.95)
    delay = spec.get("delay", 0.0)
    delay_gain = spec.get("delay_gain", 0.0)
    taps = spec.get("delay_taps", 2)
    reverse_every = spec.get("reverse_every", 0)
    drone = spec.get("drone", -1.0)
    drone_gain = spec.get("drone_gain", 0.0)
    accent = spec.get("accent", -1.0)
    accent_gain = spec.get("accent_gain", 0.0)
    pad = spec.get("pad", False)
    end_up = spec.get("end_up", False)

    total = LOOP_BEATS * BEAT
    n = int(RATE * total)
    buf = [0.0] * n

    seq = list(MOTIF) + list(RESPONSE) + list(MOTIF)
    for beat, f0 in enumerate(seq):
        start = beat * BEAT
        note_len = BEAT * staccato
        f = f0 * oct
        if end_up and beat >= 16:
            f *= 2.0
        is_reversed = reverse_every > 0 and (beat % reverse_every) == 0
        add_note(buf, start, note_len, f, harmonics, gain, attack, release,
                 is_reversed)
        if accent > 0.0 and beat % 8 == 0:
            add_note(buf, start, 0.3, accent, [1.0, 0.3, 0.12], accent_gain,
                     0.004, 0.25, False)

    if pad:
        for h in (146.83, 220.0, 349.23):  # D3, A3, F4
            for i in range(n):
                t = i / RATE
                env = min(1.0, t / 2.0) * min(1.0, max(0.0, total - t) / 2.0)
                buf[i] += math.sin(2 * math.pi * h * t) * env * 0.045

    if drone > 0.0:
        for i in range(n):
            t = i / RATE
            buf[i] += math.sin(2 * math.pi * drone * t) * drone_gain

    if delay > 0.0:
        d = int(delay * RATE)
        out_n = n + d * taps
        w = [0.0] * out_n
        for tap in range(taps):
            off = d * (tap + 1)
            gg = delay_gain * (0.6 ** tap)
            for i in range(n):
                if i + off < out_n:
                    w[i + off] += buf[i] * gg
        for i in range(n):
            buf[i] += w[i]
        buf = buf + [0.0] * (out_n - n)

    loop_seam(buf)
    normalize(buf, MUSIC_PEAK)
    return buf


def loop_seam(samples):
    xf = int(MUSIC_XFADE * RATE)
    if len(samples) < xf * 2:
        return
    n = len(samples)
    for j in range(xf):
        k = j / xf
        tail_i = n - xf + j
        head = samples[j]
        samples[j] = samples[j] * k + samples[tail_i] * (1.0 - k)
        samples[tail_i] = head * (1.0 - k) + samples[tail_i] * k


def amb_loop_seam(samples):
    xf = int(AMB_XFADE * RATE)
    if len(samples) < xf * 2:
        return
    n = len(samples)
    for j in range(xf):
        k = j / xf
        tail_i = n - xf + j
        head = samples[j]
        samples[j] = samples[j] * k + samples[tail_i] * (1.0 - k)
        samples[tail_i] = head * (1.0 - k) + samples[tail_i] * k


def normalize(samples, peak):
    m = max((abs(s) for s in samples), default=0.0)
    if m > 0.0001:
        g = peak / m
        for i in range(len(samples)):
            samples[i] *= g


def lowpass_noise(rnd, n, base_fc, lfo_freq, lfo_phase=0.0):
    y = 0.0
    out = [0.0] * n
    for i in range(n):
        t = i / RATE
        lfo = 0.5 + 0.5 * math.sin(2 * math.pi * lfo_freq * t + lfo_phase)
        fc = base_fc[0] + base_fc[1] * lfo
        k = 1.0 - math.exp(-2 * math.pi * fc / RATE)
        y += (rnd.uniform(-1.0, 1.0) - y) * k
        out[i] = y
    return out, lfo


# --- The Wound, five variations -------------------------------------------

VARIATIONS = {
    "wound_normal": {
        "oct": 1.0, "harmonics": [1.0, 0.25], "gain": 0.40,
        "attack": 0.02, "release": 0.35, "staccato": 0.95,
    },
    "wound_memory": {
        "oct": 2.0, "harmonics": [1.0, 0.4, 0.15], "gain": 0.34,
        "attack": 0.05, "release": 0.9, "staccato": 1.0,
        "delay": 0.45, "delay_gain": 0.22, "delay_taps": 3,
    },
    "wound_echo": {
        "oct": 1.0, "harmonics": [1.0, 0.1], "gain": 0.36,
        "attack": 0.02, "release": 0.5, "staccato": 0.8,
        "delay": 0.375, "delay_gain": 0.3, "delay_taps": 4,
        "reverse_every": 4,
    },
    "wound_archivist": {
        "oct": 1.0, "harmonics": [1.0], "gain": 0.42,
        "attack": 0.005, "release": 0.15, "staccato": 0.6,
        "drone": 73.42, "drone_gain": 0.10,
        "accent": 1188.16, "accent_gain": 0.05,
    },
    "wound_ending": {
        "oct": 1.0, "harmonics": [1.0, 0.5, 0.2], "gain": 0.44,
        "attack": 0.03, "release": 0.6, "staccato": 0.95,
        "pad": True, "end_up": True,
    },
}


# --- The stinger ------------------------------------------------------------

def stinger():
    n = int(RATE * STINGER_DUR)
    out = [0.0] * n
    for i in range(n):
        t = i / RATE
        s = 0.0
        if t < STINGER_HIT_AT:
            k = t / STINGER_HIT_AT
            f = 73.42 + (146.83 - 73.42) * k
            s += math.sin(2 * math.pi * f * t) * k * k * 0.5
        if t >= STINGER_HIT_AT:
            dt = t - STINGER_HIT_AT
            s += math.sin(2 * math.pi * 55.0 * dt) * math.exp(-4.0 * dt) * 0.9
            s += (math.sin(2 * math.pi * 237.5 * dt) * 0.5
                  + math.sin(2 * math.pi * 475.0 * dt) * 0.3
                  + math.sin(2 * math.pi * 1187.5 * dt) * 0.2) \
                * math.exp(-2.2 * dt) * 0.5
        out[i] = s
    normalize(out, MUSIC_PEAK)
    return out


# --- Ambient layers ------------------------------------------------------------

def amb_camp():
    rnd = random.Random(SEEDS["camp"])
    n = int(RATE * AMB_DUR)
    noise, _ = lowpass_noise(rnd, n, (250.0, 150.0), 0.07)
    out = [0.0] * n
    for i in range(n):
        t = i / RATE
        lfo = 0.5 + 0.5 * math.sin(2 * math.pi * 0.07 * t)
        out[i] = noise[i] * (0.35 + 0.1 * lfo)
    for i in range(n):
        t = i / RATE
        log_wave = 0.5 + 0.5 * math.sin(2 * math.pi * 0.05 * t)
        if rnd.random() < 0.0006 * (0.4 + log_wave):
            burst = int(RATE * 0.008)
            for j in range(burst):
                if i + j >= n:
                    break
                out[i + j] += rnd.uniform(-1.0, 1.0) \
                    * (1.0 - j / burst) * 0.5
    for i in range(n):
        t = i / RATE
        swell = 0.3 + 0.7 * (0.5 + 0.5 * math.sin(2 * math.pi * 0.05 * t))
        out[i] += math.sin(2 * math.pi * 50.0 * t) * 0.02 * swell
    amb_loop_seam(out)
    normalize(out, AMB_PEAK)
    return out


def amb_wild():
    rnd = random.Random(SEEDS["wild"])
    n = int(RATE * AMB_DUR)
    noise, _ = lowpass_noise(rnd, n, (420.0, 260.0), 0.11, 1.0)
    out = [0.0] * n
    for i in range(n):
        t = i / RATE
        lfo = 0.5 + 0.5 * math.sin(2 * math.pi * 0.11 * t + 1.0)
        out[i] = noise[i] * (0.3 + 0.12 * lfo)
    for ev in range(3):
        at = int(rnd.uniform(1.0, AMB_DUR - 2.0) * RATE)
        f0 = rnd.uniform(2200.0, 2800.0)
        pairs = 2 if ev % 2 == 0 else 3
        for pidx in range(pairs):
            a0 = at + pidx * int(0.16 * RATE)
            ln = int(0.09 * RATE)
            for j in range(ln):
                if a0 + j >= n:
                    break
                tj = j / ln
                out[a0 + j] += math.sin(2 * math.pi * (f0 + 300.0 * tj) * tj) \
                    * math.sin(2 * math.pi * tj * 0.5) * 0.12
    ca = int(rnd.uniform(2.0, AMB_DUR - 2.0) * RATE)
    clen = int(0.3 * RATE)
    for j in range(clen):
        if ca + j >= n:
            break
        tj = j / clen
        out[ca + j] += math.sin(2 * math.pi * (140.0 + 25.0 * tj) * tj) \
            * math.sin(2 * math.pi * tj * 0.5) * 0.08
    amb_loop_seam(out)
    normalize(out, AMB_PEAK)
    return out


def amb_stone():
    rnd = random.Random(SEEDS["stone"])
    n = int(RATE * AMB_DUR)
    noise, _ = lowpass_noise(rnd, n, (180.0, 80.0), 0.05, 2.0)
    out = [0.0] * n
    for i in range(n):
        t = i / RATE
        lfo = 0.5 + 0.5 * math.sin(2 * math.pi * 0.05 * t + 2.0)
        out[i] = noise[i] * (0.28 + 0.08 * lfo)
    for i in range(n):
        t = i / RATE
        swell = 0.5 + 0.5 * math.sin(2 * math.pi * 0.033 * t)
        out[i] += math.sin(2 * math.pi * 45.0 * t) * 0.05 * swell \
            + math.sin(2 * math.pi * 90.0 * t) * 0.015 * swell
    for i in range(n):
        if rnd.random() < 0.00008:
            burst = int(RATE * 0.01)
            for j in range(burst):
                if i + j >= n:
                    break
                out[i + j] += math.sin(2 * math.pi * 900.0 * j / RATE) \
                    * (1.0 - j / burst) * 0.15
    amb_loop_seam(out)
    normalize(out, AMB_PEAK)
    return out


def amb_mine():
    rnd = random.Random(SEEDS["mine"])
    n = int(RATE * AMB_DUR)
    noise, _ = lowpass_noise(rnd, n, (120.0, 60.0), 0.09)
    out = [0.0] * n
    for i in range(n):
        t = i / RATE
        lfo = 0.5 + 0.5 * math.sin(2 * math.pi * 0.09 * t)
        out[i] = noise[i] * (0.3 + 0.1 * lfo)
        out[i] += math.sin(2 * math.pi * 55.0 * t) * 0.04
    for _ in range(8):
        at = int(rnd.uniform(0.5, AMB_DUR - 1.0) * RATE)
        f = rnd.uniform(1100.0, 1400.0)
        dl = int(0.05 * RATE)
        for j in range(dl):
            if at + j >= n:
                break
            tj = j / dl
            out[at + j] += math.sin(2 * math.pi * f * tj) * (1.0 - tj) * 0.3
        ea = at + int(0.25 * RATE)
        if ea + dl < n:
            for j in range(dl):
                tj = j / dl
                out[ea + j] += math.sin(2 * math.pi * f * tj) * (1.0 - tj) * 0.12
    amb_loop_seam(out)
    normalize(out, AMB_PEAK)
    return out


def amb_lake():
    rnd = random.Random(SEEDS["lake"])
    n = int(RATE * AMB_DUR)
    out = [0.0] * n
    y = 0.0
    for i in range(n):
        t = i / RATE
        lap = 0.5 + 0.5 * math.sin(2 * math.pi * 0.4 * t)
        fc = 700.0 + 300.0 * lap
        k = 1.0 - math.exp(-2 * math.pi * fc / RATE)
        y += (rnd.uniform(-1.0, 1.0) - y) * k
        out[i] = y * (0.2 + 0.25 * lap)
    w = 0.0
    for i in range(n):
        k = 1.0 - math.exp(-2 * math.pi * 200.0 / RATE)
        w += (rnd.uniform(-1.0, 1.0) - w) * k
        out[i] += w * 0.12
    at = int(rnd.uniform(3.0, AMB_DUR - 3.0) * RATE)
    f0 = 2400.0
    for pidx in range(3):
        a0 = at + pidx * int(0.14 * RATE)
        ln = int(0.08 * RATE)
        for j in range(ln):
            if a0 + j >= n:
                break
            tj = j / ln
            out[a0 + j] += math.sin(2 * math.pi * (f0 + 250.0 * tj) * tj) \
                * math.sin(2 * math.pi * tj * 0.5) * 0.1
    amb_loop_seam(out)
    normalize(out, AMB_PEAK)
    return out


def amb_undercroft():
    rnd = random.Random(SEEDS["undercroft"])
    n = int(RATE * AMB_DUR)
    out = [0.0] * n
    y = 0.0
    for i in range(n):
        t = i / RATE
        breathe = 0.5 + 0.5 * math.sin(2 * math.pi * 0.0625 * t)
        fc = 150.0 + 50.0 * breathe
        k = 1.0 - math.exp(-2 * math.pi * fc / RATE)
        y += (rnd.uniform(-1.0, 1.0) - y) * k
        out[i] = y * (0.16 + 0.08 * breathe)
    for i in range(n):
        t = i / RATE
        breathe = 0.5 + 0.5 * math.sin(2 * math.pi * 0.0625 * t)
        out[i] += math.sin(2 * math.pi * 73.42 * t) * (0.10 + 0.06 * breathe) \
            + math.sin(2 * math.pi * 146.83 * t) * (0.03 + 0.02 * breathe)
    for knock_at in (5.0, 11.0):
        a0 = int(knock_at * RATE)
        bl = int(0.12 * RATE)
        for j in range(bl):
            if a0 + j >= n:
                break
            tj = j / bl
            out[a0 + j] += math.sin(2 * math.pi * 38.0 * tj) \
                * (1.0 - tj) * (1.0 - tj) * 0.35
    amb_loop_seam(out)
    normalize(out, AMB_PEAK)
    return out


AMBIENTS = {
    "amb_camp": amb_camp,
    "amb_wild": amb_wild,
    "amb_stone": amb_stone,
    "amb_mine": amb_mine,
    "amb_lake": amb_lake,
    "amb_undercroft": amb_undercroft,
}


# --- WAV output ----------------------------------------------------------------

def write_wav(path, samples):
    n = len(samples)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        data = bytearray()
        for s in samples:
            v = int(max(-1.0, min(1.0, s)) * 32767.0)
            data += struct.pack("<h", v)
        w.writeframes(bytes(data))


def main():
    out = os.path.normpath(OUT_DIR)
    os.makedirs(out, exist_ok=True)
    total = 0
    for name, spec in VARIATIONS.items():
        samples = melody(spec)
        write_wav(os.path.join(out, name + ".wav"), samples)
        print("  %-18s %6.2f s" % (name, len(samples) / RATE))
        total += len(samples) * 2
    st = stinger()
    write_wav(os.path.join(out, "stinger.wav"), st)
    print("  %-18s %6.2f s" % ("stinger", len(st) / RATE))
    total += len(st) * 2
    for name, fn in AMBIENTS.items():
        samples = fn()
        write_wav(os.path.join(out, name + ".wav"), samples)
        print("  %-18s %6.2f s" % (name, len(samples) / RATE))
        total += len(samples) * 2
    print("total: %.1f KB (%d files)" % (total / 1024.0,
                                          len(VARIATIONS) + 1 + len(AMBIENTS)))


if __name__ == "__main__":
    main()
