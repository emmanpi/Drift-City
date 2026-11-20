#!/usr/bin/env python3
"""Generate the ORIGINAL in-game music used by Drift City.

Fast industrial / breakcore-flavoured instrumental: overdriven saw bass,
pounding drums, dissonant stabs and a frantic arpeggio. The energy and
instrumentation are inspired by aggressive rhythm-game soundtracks, but every
note, riff and rhythm below is generated here from scratch -- no melody, sample
or source file from an existing soundtrack is used.

Pure Python standard library. Run from the project root:

    python3 tools/generate_game_music.py

Output: assets/audio/music/game_theme.wav (32 bars @ 174 BPM, seamless loop).
"""

import array
import math
import os
import random
import wave

SR = 44100
TAU = 2.0 * math.pi
BPM = 174
BEAT = int(round(SR * 60.0 / BPM))       # one quarter note
BAR = 4 * BEAT
BARS = 32
LOOP_LEN = BAR * BARS
OUT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "assets", "audio", "music", "game_theme.wav"))

E1 = 41.20
ROOTS = [E1, 43.65, 38.89, 36.71]        # E, F, D#, C# -- dark, chromatic motion


def semi(freq, steps):
    return freq * (2.0 ** (steps / 12.0))


def add(buf, index, value):
    buf[index % LOOP_LEN] += value


def kick(buf, start, amp=1.0):
    dur = int(0.30 * SR)
    phase = 0.0
    for i in range(dur):
        t = i / SR
        phase += TAU * (46.0 + 150.0 * math.exp(-t / 0.028)) / SR
        v = math.sin(phase) * math.exp(-t / 0.075)
        if t < 0.005:
            v += 0.35 * (1.0 - t / 0.005) * math.sin(TAU * 2100.0 * t)
        add(buf, start + i, 0.78 * amp * v)


def snare(buf, start, rng, amp=1.0):
    dur = int(0.23 * SR)
    prev = 0.0
    for i in range(dur):
        t = i / SR
        n = rng.uniform(-1.0, 1.0)
        hp = n - 0.78 * prev
        prev = n
        v = 0.75 * hp * math.exp(-t / 0.048)
        v += 0.32 * math.sin(TAU * 185.0 * t) * math.exp(-t / 0.060)
        v += 0.18 * math.sin(TAU * 330.0 * t) * math.exp(-t / 0.035)
        add(buf, start + i, 0.42 * amp * v)


def hat(buf, start, rng, amp=1.0, open_hat=False):
    dur = int((0.17 if open_hat else 0.045) * SR)
    prev = 0.0
    decay = 0.055 if open_hat else 0.010
    for i in range(dur):
        t = i / SR
        n = rng.uniform(-1.0, 1.0)
        hp = n - 0.90 * prev
        prev = n
        add(buf, start + i, 0.16 * amp * hp * math.exp(-t / decay))


def bass(buf, start, length, freq, amp=1.0):
    """Two detuned saws -> one-pole low-pass -> tanh overdrive."""
    phase_a = 0.0
    phase_b = 0.0
    lp = 0.0
    for i in range(length):
        t = i / SR
        phase_a += freq / SR
        phase_b += (freq * 1.006) / SR
        raw = 0.55 * (2.0 * (phase_a % 1.0) - 1.0)
        raw += 0.45 * (2.0 * (phase_b % 1.0) - 1.0)
        lp += 0.32 * (raw - lp)
        env = min(1.0, t / 0.0025) * math.exp(-t / (length / SR * 0.55))
        v = math.tanh(3.2 * lp) * env
        add(buf, start + i, 0.26 * amp * v)


def stab(buf, start, freqs, amp=1.0):
    """Short detuned chord with a metallic edge."""
    dur = int(0.20 * SR)
    phases = [rng01(k) for k in range(len(freqs))]
    for i in range(dur):
        t = i / SR
        env = min(1.0, t / 0.002) * math.exp(-t / 0.065)
        v = 0.0
        for k, f in enumerate(freqs):
            phases[k] += f / SR
            saw = 2.0 * (phases[k] % 1.0) - 1.0
            v += saw + 0.25 * math.sin(TAU * f * 2.01 * t + k)
        add(buf, start + i, 0.11 * amp * math.tanh(1.8 * v) * env)


def lead(buf, start, length, freq, amp=1.0):
    phase = 0.0
    for i in range(length):
        t = i / SR
        phase += freq / SR
        sq = 1.0 if (phase % 1.0) < 0.5 else -1.0
        v = 0.65 * sq + 0.35 * math.sin(TAU * freq * 2.0 * t)
        env = min(1.0, t / 0.0015) * math.exp(-t / (length / SR * 0.7))
        add(buf, start + i, 0.105 * amp * v * env)


def riser(buf, start, length, rng, amp=1.0):
    prev = 0.0
    for i in range(length):
        t = i / SR
        n = rng.uniform(-1.0, 1.0)
        hp = n - 0.85 * prev
        prev = n
        env = (i / length) ** 2.2
        add(buf, start + i, 0.13 * amp * hp * env)


def rng01(seed):
    return (seed * 0.3183098861837907) % 1.0


def main():
    rng = random.Random(1704)
    buf = [0.0] * LOOP_LEN

    for bar in range(BARS):
        section = bar // 8
        pos = bar * BAR
        root = ROOTS[(bar // 2) % len(ROOTS)]
        chord = [semi(root * 8.0, s) for s in (0, 3, 6, 10, 12)]

        if section == 0:                                  # intro : tension build
            for beat in (0, 2):
                kick(buf, pos + beat * BEAT, 0.85)
            for i in range(8):
                hat(buf, pos + i * BEAT // 2, rng, 0.35 + 0.08 * i)
            bass(buf, pos, BAR - 40, root, 0.55)
            if bar >= 4:
                for beat in (1, 3):
                    snare(buf, pos + beat * BEAT, rng, 0.45)
            if bar == 7:
                riser(buf, pos, BAR, rng, 1.2)

        elif section == 1:                                # main A : straight grind
            for beat in range(4):
                kick(buf, pos + beat * BEAT)
            kick(buf, pos + 3 * BEAT + BEAT * 3 // 4, 0.75)
            for beat in (1, 3):
                snare(buf, pos + beat * BEAT, rng)
            for i in range(16):
                hat(buf, pos + i * BEAT // 4, rng,
                    1.0 if i % 4 == 0 else 0.45, i % 8 == 6)
            riff = [0, 0, 3, 0, 0, 5, 3, -2]
            for i, step in enumerate(riff):
                bass(buf, pos + i * BEAT // 2, BEAT // 2 - 30,
                     semi(root, step), 0.95 if i % 4 == 0 else 0.8)
            for beat in (0, 2):
                stab(buf, pos + beat * BEAT + BEAT // 2, chord[:3], 0.8)
            if bar % 4 == 3:
                for i in range(8):
                    snare(buf, pos + 3 * BEAT + i * BEAT // 8, rng,
                          0.35 + i * 0.07)
            if bar == 15:
                riser(buf, pos + 2 * BEAT, 2 * BEAT, rng, 1.1)

        elif section == 2:                                # break : half-time, glitch
            kick(buf, pos, 1.1)
            kick(buf, pos + BEAT * 5 // 2, 0.9)
            snare(buf, pos + 2 * BEAT, rng, 1.25)
            for i in range(8):
                hat(buf, pos + i * BEAT // 2, rng, 0.5 if i % 2 else 0.9)
            bass(buf, pos, BEAT, root, 0.6)
            bass(buf, pos + 2 * BEAT, BEAT * 3 // 2, semi(root, -2), 0.6)
            arp = (0, 3, 6, 10, 12, 10, 6, 3)
            for i, step in enumerate(arp):
                lead(buf, pos + i * BEAT // 4, BEAT // 4 - 20,
                     semi(root * 8.0, step), 0.85)
            if bar % 2 == 1:
                for i in range(6):
                    snare(buf, pos + 3 * BEAT + i * BEAT // 12, rng, 0.3 + i * 0.05)
            if bar == 23:
                riser(buf, pos + 2 * BEAT, 2 * BEAT, rng, 1.4)

        else:                                             # main B : double kick chaos
            for beat in range(4):
                kick(buf, pos + beat * BEAT)
                kick(buf, pos + beat * BEAT + BEAT // 4, 0.7)
                kick(buf, pos + beat * BEAT + BEAT * 3 // 4, 0.65)
            for beat in (1, 3):
                snare(buf, pos + beat * BEAT, rng, 1.1)
            for i in range(32):
                hat(buf, pos + i * BEAT // 8, rng,
                    1.0 if i % 4 == 0 else 0.4, i % 16 == 14)
            riff = [0, 0, 0, 3, 0, 5, 0, 6, 0, 0, 3, 0, 7, 5, 3, 0]
            for i, step in enumerate(riff):
                bass(buf, pos + i * BEAT // 4, BEAT // 4 - 18,
                     semi(root, step), 1.0 if i % 4 == 0 else 0.82)
            for beat in (0, 1, 2, 3):
                stab(buf, pos + beat * BEAT + BEAT // 2, chord[:3], 0.7)
            lead_seq = (12, 10, 6, 3, 0, 3, 6, 10)
            for i, step in enumerate(lead_seq):
                lead(buf, pos + i * BEAT // 4, BEAT // 4 - 25,
                     semi(root * 8.0, step), 0.72)
            if bar % 4 == 3:
                for i in range(12):
                    snare(buf, pos + 3 * BEAT + i * BEAT // 16, rng,
                          0.3 + i * 0.05)
            if bar == 31:
                riser(buf, pos + 2 * BEAT, 2 * BEAT, rng, 1.5)

    peak = max(1e-6, max(abs(v) for v in buf))
    gain = 0.94 / peak
    samples = array.array("h")
    for v in buf:
        x = max(-1.0, min(1.0, v * gain))
        samples.append(int(32767.0 * math.tanh(1.05 * x) / math.tanh(1.05)))

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with wave.open(OUT, "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(SR)
        wav.writeframes(samples.tobytes())

    print("Wrote %s (%.1f s, %.2f MB)" % (
        OUT, LOOP_LEN / SR, os.path.getsize(OUT) / 1048576.0))


if __name__ == "__main__":
    main()
