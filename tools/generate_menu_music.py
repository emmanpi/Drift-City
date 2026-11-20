#!/usr/bin/env python3
"""Generate the ORIGINAL menu theme used by Drift City.

This is a short looping synth/industrial track composed procedurally here;
it is not a copy or a derivative of any existing soundtrack. The in-game
music is a separate, user-provided MP3.

Pure Python standard library. Run from the project root:

    python3 tools/generate_menu_music.py

Output: assets/audio/music/menu_theme.wav (8 bars @ ~140 BPM, seamless loop).
"""

import array
import math
import os
import random
import sys
import wave

SR = 44100
TAU = 2.0 * math.pi
BEATS_PER_BAR = 4
BARS = 8
BEAT = 18911                       # samples; 8 * 4 * BEAT = loop length
LOOP_LEN = BEATS_PER_BAR * BARS * BEAT
OUT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "assets", "audio", "music", "menu_theme.wav"))

# 4 sections of 2 bars: root note, minor/major-ish chord for the arp.
SECTIONS = [
    (55.00, (220.00, 261.63, 329.63, 440.00)),   # A minor
    (43.65, (174.61, 220.00, 261.63, 349.23)),   # F major
    (65.41, (196.00, 261.63, 329.63, 392.00)),   # C major
    (49.00, (196.00, 246.94, 293.66, 392.00)),   # G major
]


def add(buf, index, value):
    buf[index % LOOP_LEN] += value


def kick(buf, start):
    dur = int(0.28 * SR)
    phase = 0.0
    for i in range(dur):
        t = i / SR
        phase += TAU * (52.0 + 115.0 * math.exp(-t / 0.035)) / SR
        v = 0.62 * math.sin(phase) * math.exp(-t / 0.095)
        if t < 0.006:
            v += 0.16 * (1.0 - t / 0.006) * math.sin(TAU * 1700.0 * t)
        add(buf, start + i, v)


def snare(buf, start, rng):
    dur = int(0.20 * SR)
    prev = 0.0
    for i in range(dur):
        t = i / SR
        n = rng.uniform(-1.0, 1.0)
        hp = n - 0.72 * prev
        prev = n
        v = 0.32 * hp * math.exp(-t / 0.055)
        v += 0.15 * math.sin(TAU * 190.0 * t) * math.exp(-t / 0.075)
        add(buf, start + i, v)


def hat(buf, start, rng, accent):
    dur = int(0.055 * SR)
    prev = 0.0
    amp = 0.14 if accent else 0.08
    for i in range(dur):
        t = i / SR
        n = rng.uniform(-1.0, 1.0)
        hp = n - 0.88 * prev
        prev = n
        add(buf, start + i, amp * hp * math.exp(-t / 0.013))


def bass(buf, start, freq):
    dur = int(0.21 * SR)
    for i in range(dur):
        t = i / SR
        env = min(1.0, t / 0.004) * math.exp(-t / 0.085)
        v = 0.0
        for n in range(1, 7):
            v += (1.0 / n) * math.sin(TAU * n * freq * t)
        add(buf, start + i, 0.15 * env * v)


def arp(buf, start, freq):
    dur = int(0.17 * SR)
    for i in range(dur):
        t = i / SR
        env = min(1.0, t / 0.003) * math.exp(-t / 0.055)
        v = (0.60 * math.sin(TAU * freq * t)
             + 0.28 * math.sin(TAU * 2.0 * freq * t)
             + 0.14 * math.sin(TAU * 3.0 * freq * t + 0.5)
             + 0.07 * math.sin(TAU * 5.0 * freq * t))
        add(buf, start + i, 0.075 * env * v)


def pad(buf, start, length, freqs):
    attack = int(0.35 * SR)
    release = int(0.55 * SR)
    for i in range(length):
        t = i / SR
        a = min(1.0, i / attack)
        r = min(1.0, (length - i) / release)
        env = a * r
        v = 0.0
        for f in freqs:
            v += 0.5 * math.sin(TAU * f * t) + 0.18 * math.sin(TAU * 2.0 * f * t + 0.4)
        add(buf, start + i, 0.045 * env * v)


def main():
    rng = random.Random(20261120)
    buf = [0.0] * LOOP_LEN

    for section, (root, chord) in enumerate(SECTIONS):
        section_start = section * 2 * BEAT * BEATS_PER_BAR
        pad(buf, section_start, 2 * BEAT * BEATS_PER_BAR, chord)

    for bar in range(BARS):
        bar_start = bar * BEAT * BEATS_PER_BAR
        root, chord = SECTIONS[bar // 2]
        for beat in range(BEATS_PER_BAR):
            at = bar_start + beat * BEAT
            kick(buf, at)
            if beat % 2 == 1:
                snare(buf, at, rng)
        for eighth in range(8):
            at = bar_start + eighth * (BEAT // 2)
            hat(buf, at, rng, accent=(eighth % 4 == 0))
            bass_steps = (1.0, 1.0, 2.0, 1.0, 1.0, 1.5, 1.0, 2.0)
            bass(buf, at, root * bass_steps[eighth])
        for sixteenth in range(16):
            at = bar_start + sixteenth * (BEAT // 4)
            arp(buf, at, chord[sixteenth % len(chord)])

    # Soft saturation, then normalise.
    buf = [math.tanh(v * 1.25) for v in buf]
    peak = max(abs(v) for v in buf)
    gain = 0.86 / peak
    pcm = array.array("h", (int(max(-1.0, min(1.0, v * gain)) * 32767) for v in buf))
    if sys.byteorder != "little":
        pcm.byteswap()
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with wave.open(OUT, "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(SR)
        out.writeframes(pcm.tobytes())
    print("wrote %s  %.2f s  %.1f KB" % (OUT, LOOP_LEN / SR, os.path.getsize(OUT) / 1024))


if __name__ == "__main__":
    main()
