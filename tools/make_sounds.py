#!/usr/bin/env python3
"""Generate the game's sound effects (R-14). Original, synthesized - no third-party audio.

Usage:  python3 tools/make_sounds.py        (writes audio/*.wav)
Needs:  numpy
"""
import os
import wave

import numpy as np

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "audio")
rng = np.random.default_rng(7)


def t(dur):
    return np.linspace(0, dur, int(RATE * dur), endpoint=False)


def env(n, attack=0.005, release=0.6):
    """Linear attack, exponential release."""
    x = np.arange(n) / RATE
    a = np.clip(x / max(attack, 1e-4), 0, 1)
    r = np.exp(-x / max(release * (n / RATE), 1e-4) * 3)
    return a * r


def sweep(f0, f1, dur, shape="sine"):
    tt = t(dur)
    f = np.linspace(f0, f1, len(tt))
    ph = 2 * np.pi * np.cumsum(f) / RATE
    if shape == "square":
        return np.sign(np.sin(ph)) * 0.6
    if shape == "tri":
        return 2 / np.pi * np.arcsin(np.sin(ph))
    return np.sin(ph)


def noise(dur, lowpass=0.0):
    x = rng.uniform(-1, 1, int(RATE * dur))
    if lowpass > 0:  # simple one-pole lowpass
        y = np.zeros_like(x)
        for i in range(1, len(x)):
            y[i] = y[i - 1] + lowpass * (x[i] - y[i - 1])
        x = y / (np.max(np.abs(y)) + 1e-9)
    return x


def notes(freqs, each, shape="tri", gap=0.0):
    parts = []
    for f in freqs:
        s = sweep(f, f, each, shape) * env(int(RATE * each), 0.004, 0.8)
        parts.append(s)
        if gap:
            parts.append(np.zeros(int(RATE * gap)))
    return np.concatenate(parts)


def mix(*sigs):
    n = max(len(s) for s in sigs)
    out = np.zeros(n)
    for s in sigs:
        out[: len(s)] += s
    return out


def write(name, sig, vol=0.5):
    sig = sig / (np.max(np.abs(sig)) + 1e-9) * vol
    data = (sig * 32767).astype("<i2").tobytes()
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data)


def main():
    os.makedirs(OUT, exist_ok=True)
    d = 0.05
    write("step", noise(d, 0.25) * env(int(RATE * d), 0.002, 0.3), 0.18)
    d = 0.14
    write("hit", mix(noise(d, 0.35) * env(int(RATE * d), 0.002, 0.35),
                     sweep(180, 90, d) * env(int(RATE * d), 0.002, 0.4)), 0.55)
    d = 0.3
    write("crit", mix(noise(d, 0.5) * env(int(RATE * d), 0.002, 0.3),
                      sweep(320, 80, d, "square") * env(int(RATE * d), 0.002, 0.45),
                      notes([880], 0.12) * 0.5), 0.6)
    d = 0.18
    write("miss", noise(d, 0.08) * np.sin(np.linspace(0, np.pi, int(RATE * d))), 0.3)
    d = 0.22
    write("hurt", mix(sweep(140, 55, d, "square") * env(int(RATE * d), 0.002, 0.5),
                      noise(d, 0.15) * env(int(RATE * d), 0.002, 0.3) * 0.6), 0.55)
    d = 0.35
    write("kill", mix(sweep(400, 60, d, "tri") * env(int(RATE * d), 0.002, 0.6),
                      noise(d, 0.2) * env(int(RATE * d), 0.002, 0.25) * 0.5), 0.5)
    d = 0.4
    sp = sweep(300, 1400, d, "sine") * env(int(RATE * d), 0.02, 0.7)
    write("spell", mix(sp, sweep(450, 2100, d) * env(int(RATE * d), 0.02, 0.6) * 0.4), 0.45)
    write("heal", notes([523, 659, 784, 1047], 0.09), 0.4)
    write("pickup", notes([988, 1319], 0.07, "square"), 0.3)
    write("levelup", notes([523, 659, 784, 1047, 1319], 0.1, "square"), 0.4)
    d = 0.7
    write("descend", mix(sweep(440, 110, d, "tri") * env(int(RATE * d), 0.01, 0.8),
                         noise(d, 0.05) * env(int(RATE * d), 0.05, 0.8) * 0.3), 0.45)
    write("death", mix(notes([392, 330, 262, 196], 0.22, "tri"),
                       sweep(200, 40, 0.9, "square") * env(int(RATE * 0.9), 0.01, 0.9) * 0.4), 0.5)
    write("victory", notes([523, 659, 784, 1047, 784, 1047, 1319], 0.13, "square", 0.02), 0.45)
    d = 0.35
    write("enemy_spell", mix(sweep(900, 200, d, "square") * env(int(RATE * d), 0.01, 0.6) * 0.6,
                             noise(d, 0.3) * env(int(RATE * d), 0.01, 0.5) * 0.4), 0.4)
    d = 0.6
    write("summon", mix(sweep(60, 120, d, "square") * env(int(RATE * d), 0.1, 0.8),
                        noise(d, 0.05) * env(int(RATE * d), 0.1, 0.7) * 0.5), 0.5)
    print("Wrote", len(os.listdir(OUT)), "files to", os.path.abspath(OUT))


if __name__ == "__main__":
    main()
