#!/usr/bin/env python3
"""Generate the original sound effects used by Drift City.

Pure Python standard library (no numpy / no external samples). Run from the
project root:

    python3 tools/generate_sfx.py

Outputs (16-bit mono WAV, 44.1 kHz), all seamlessly loopable except the crash:

    assets/audio/sfx/engine_low.wav    idle / low rev engine layer
    assets/audio/sfx/engine_high.wav   high rev engine layer
    assets/audio/sfx/tyre_skid.wav     tyre screech loop
    assets/audio/sfx/crash.wav         one-shot impact

The loops are built exclusively from sinusoidal partials whose frequencies are
integer multiples of 1 / loop_duration, so the first and last samples join
without a click. These are original synthetic sounds, not recordings of any
existing game or car.
"""

import array
import math
import os
import random
import sys
import wave

SR = 44100
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "audio", "sfx")
TAU = 2.0 * math.pi


def write_wav(name, samples, peak=0.82):
    """Normalise to `peak` and write a 16-bit mono PCM WAV."""
    samples = list(samples)
    top = max(abs(s) for s in samples)
    if top < 1e-9:
        raise ValueError("silent buffer: " + name)
    gain = peak / top
    pcm = array.array("h", (int(max(-1.0, min(1.0, s * gain)) * 32767) for s in samples))
    if sys.byteorder != "little":
        pcm.byteswap()
    path = os.path.normpath(os.path.join(OUT_DIR, name))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(SR)
        out.writeframes(pcm.tobytes())
    print("wrote %-18s %6d frames  %.2f s" % (name, len(samples), len(samples) / SR))


def engine_loop(frames, cycles, harmonics, seed, wobble):
    """Engine drone: aligned harmonics make a firing pulse, plus fine noise."""
    rng = random.Random(seed)
    base = cycles * SR / frames          # exactly `cycles` periods in the buffer
    partials = []
    for n in range(1, harmonics + 1):
        amp = 1.0 / (n ** 0.78)
        # Near-aligned phases -> a buzzy pulse train instead of a smooth chord.
        phase = -TAU * n * 0.11 + rng.gauss(0.0, 0.16)
        partials.append((n * base, amp, phase))

    # Periodic "mechanical" noise: sines at integer multiples of the loop base.
    lo_bin = max(1, int(500.0 / base))
    hi_bin = int(4200.0 / base)
    for _ in range(85):
        k = rng.randint(lo_bin, hi_bin)
        partials.append((k * base, rng.uniform(0.005, 0.022), rng.uniform(0.0, TAU)))

    out = []
    for i in range(frames):
        t = i / SR
        v = 0.0
        for freq, amp, phase in partials:
            v += amp * math.sin(TAU * freq * t + phase)
        # Slow unevenness, also periodic over the loop.
        v *= 1.0 + wobble * math.sin(TAU * 2.0 * base * t + 0.7)
        out.append(v)
    return out


def skid_loop(name="tyre_skid.wav", frames=30870, seed=7):
    """Tyre screech: band-limited noise with two loud squealing partials."""
    rng = random.Random(seed)
    base = SR / frames                   # 1 Hz-ish: every frequency is k * base
    partials = []
    for _ in range(120):
        freq = rng.uniform(700.0, 3800.0)
        k = max(1, int(round(freq / base)))
        # Emphasis around 1.6-2.2 kHz, like a slipping contact patch.
        weight = math.exp(-((k * base - 1850.0) / 1050.0) ** 2)
        partials.append((k * base, rng.uniform(0.25, 0.9) * weight, rng.uniform(0.0, TAU)))
    for freq in (1510.0, 1970.0):
        k = max(1, int(round(freq / base)))
        partials.append((k * base, 1.4, rng.uniform(0.0, TAU)))

    out = []
    for i in range(frames):
        t = i / SR
        v = 0.0
        for freq, amp, phase in partials:
            v += amp * math.sin(TAU * freq * t + phase)
        # 5 Hz-amplitude flutter (5 is an integer number of loop periods).
        v *= 0.88 + 0.12 * math.sin(TAU * 5.0 * base * t)
        out.append(v)
    return out


def crash_one_shot(name="crash.wav", duration=0.48, seed=11):
    """Impact: low chirped thump + noise transient + decaying metal ring."""
    rng = random.Random(seed)
    frames = int(duration * SR)
    ring = [(rng.uniform(520.0, 2600.0), rng.uniform(0.0, TAU)) for _ in range(5)]
    out = []
    phase_thump = 0.0
    for i in range(frames):
        t = i / SR
        noise = rng.uniform(-1.0, 1.0)
        # Short, bright crack.
        v = 0.85 * noise * math.exp(-t / 0.045)
        # Falling body impact.
        freq = 110.0 * math.exp(-t / 0.09) + 48.0
        phase_thump += TAU * freq / SR
        v += 0.75 * math.sin(phase_thump) * math.exp(-t / 0.16)
        # Metallic ring and a longer, quieter scrape.
        for k, (f, p) in enumerate(ring):
            v += (0.16 / (k + 1)) * math.sin(TAU * f * t + p) * math.exp(-t / 0.26)
        v += 0.13 * noise * math.exp(-t / 0.30)
        # 3 ms fade-in avoids a DC click at the very first sample.
        if t < 0.003:
            v *= t / 0.003
        out.append(v)
    return out


if __name__ == "__main__":
    write_wav("engine_low.wav", engine_loop(44100, 45, 26, seed=3, wobble=0.10))
    write_wav("engine_high.wav", engine_loop(29400, 60, 20, seed=5, wobble=0.05))
    write_wav("tyre_skid.wav", skid_loop())
    write_wav("crash.wav", crash_one_shot())
