#!/usr/bin/env python3
"""Compose and synthesize the background music (R-26, D-18).

Cheesy 90s General-MIDI style: brass and square leads, string pads, harpsichord
arpeggios, organ, slap-ish bass, a drum kit and the odd orchestra hit. Everything is
original: chord progressions are written below and melodies are generated from them
with a fixed seed, so re-running gives the same tracks.

Usage:  python3 tools/make_music.py            (writes audio/music_*.ogg)
        python3 tools/make_music.py crypts     (one track only)
Needs:  numpy, ffmpeg (with libvorbis)
"""
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np

RATE = 32000
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "audio")

SCALES = {
    "major": [0, 2, 4, 5, 7, 9, 11],
    "minor": [0, 2, 3, 5, 7, 8, 10],
}
# Roman numeral -> semitones above the tonic (minor-key numerals use the flat degrees).
ROMAN = {"i": 0, "bii": 1, "ii": 2, "iii": 3, "iv": 5, "v": 7, "vi": 8, "vii": 10}
ROMAN_MAJOR = {"i": 0, "ii": 2, "iii": 4, "iv": 5, "v": 7, "vi": 9, "vii": 11, "bvii": 10, "bvi": 8}


def mtof(m):
    return 440.0 * 2 ** ((m - 69) / 12)


# --- Instruments -------------------------------------------------------------------------

def _t(n):
    return np.arange(n) / RATE


def _adsr(n, a, d, s, r, gate):
    """Attack/decay/sustain then release after `gate` seconds."""
    t = _t(n)
    e = np.where(t < a, t / max(a, 1e-4), s + (1 - s) * np.exp(-(t - a) / max(d, 1e-4)))
    rel = np.clip(1 - (t - gate) / max(r, 1e-4), 0, 1)
    return e * np.where(t > gate, rel, 1.0)


def _phase(f, n, vib=0.0, vib_rate=5.5, vib_delay=0.18):
    t = _t(n)
    depth = vib * np.clip((t - vib_delay) / 0.25, 0, 1)
    inst = f * (1 + depth * np.sin(2 * np.pi * vib_rate * t))
    return 2 * np.pi * np.cumsum(inst) / RATE


def _saw(ph, harmonics=14):
    out = np.zeros_like(ph)
    for k in range(1, harmonics + 1):
        out += np.sin(k * ph) / k
    return out * 0.55


def _pulse(ph, duty=0.5):
    x = (ph / (2 * np.pi)) % 1.0
    return np.where(x < duty, 1.0, -1.0) * 0.5


def _lowpass(x, cutoff):
    a = np.exp(-2 * np.pi * cutoff / RATE)
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):          # short notes only; fine for our sizes
        acc = (1 - a) * x[i] + a * acc
        y[i] = acc
    return y


def _lp_fast(x, cutoff):
    """One-pole lowpass via scipy-free recursion using cumulative trick on blocks."""
    try:
        from scipy.signal import lfilter
        a = np.exp(-2 * np.pi * cutoff / RATE)
        return lfilter([1 - a], [1, -a], x)
    except ImportError:
        return _lowpass(x, cutoff)


def inst_brass(f, dur, vel):
    n = int((dur + 0.25) * RATE)
    ph = _phase(f, n, vib=0.012)
    x = _saw(ph) + 0.6 * _saw(ph * 1.004)
    env = _adsr(n, 0.04, 0.2, 0.75, 0.2, dur)
    bright = _lp_fast(x, 900 + 2500 * vel)
    return bright * env * 0.45 * vel


def inst_square(f, dur, vel):
    n = int((dur + 0.12) * RATE)
    ph = _phase(f, n, vib=0.008, vib_delay=0.25)
    x = _pulse(ph, 0.5) + 0.4 * _pulse(ph * 2.0, 0.25)
    return _lp_fast(x, 3500) * _adsr(n, 0.005, 0.3, 0.65, 0.1, dur) * 0.35 * vel


def inst_reed(f, dur, vel):          # nasal "bassoon/oboe" for the goblins
    n = int((dur + 0.1) * RATE)
    ph = _phase(f, n, vib=0.01, vib_rate=6.2)
    x = _pulse(ph, 0.18) + 0.3 * np.sin(ph)
    return _lp_fast(x, 2200) * _adsr(n, 0.02, 0.2, 0.8, 0.08, dur) * 0.4 * vel


def inst_flute(f, dur, vel):
    n = int((dur + 0.3) * RATE)
    ph = _phase(f, n, vib=0.009, vib_rate=5.0, vib_delay=0.12)
    breath = _lp_fast(np.random.default_rng(int(f)).standard_normal(n), 2500) * 0.08
    x = np.sin(ph) + 0.15 * np.sin(2 * ph) + breath
    return x * _adsr(n, 0.07, 0.3, 0.85, 0.25, dur) * 0.5 * vel


def inst_harpsi(f, dur, vel):
    n = int(min(dur + 0.4, 1.2) * RATE)
    ph = _phase(f, n)
    x = _pulse(ph, 0.3) + 0.5 * _pulse(ph * 2.002, 0.4)
    env = np.exp(-_t(n) / 0.35)
    return _lp_fast(x, 5000) * env * 0.28 * vel


def inst_organ(f, dur, vel):
    n = int((dur + 0.08) * RATE)
    ph = _phase(f, n, vib=0.004, vib_rate=6.5, vib_delay=0.0)
    x = np.sin(ph) + 0.6 * np.sin(2 * ph) + 0.35 * np.sin(3 * ph) + 0.25 * np.sin(4 * ph) + 0.15 * np.sin(6 * ph)
    return x * _adsr(n, 0.01, 0.1, 0.95, 0.06, dur) * 0.22 * vel


def inst_strings(f, dur, vel):
    n = int((dur + 0.5) * RATE)
    x = np.zeros(n)
    for det in (0.996, 1.0, 1.005):
        x += _saw(_phase(f * det, n, vib=0.006, vib_rate=5.0 + det, vib_delay=0.3), 10)
    return _lp_fast(x, 2200) * _adsr(n, 0.35, 0.5, 0.85, 0.45, dur) * 0.12 * vel


def inst_bass(f, dur, vel):
    n = int((dur + 0.08) * RATE)
    ph = _phase(f, n)
    x = np.sin(ph) + 0.45 * _saw(ph, 6)
    pluck = 1 + 1.5 * np.exp(-_t(n) / 0.03)
    return np.tanh(x * pluck * 1.2) * _adsr(n, 0.004, 0.25, 0.6, 0.05, dur) * 0.45 * vel


def inst_power(f, dur, vel):         # "overdriven guitar" power chord (root + fifth + octave)
    n = int((dur + 0.08) * RATE)
    x = np.zeros(n)
    for r in (1.0, 1.4983, 2.0):
        x += _saw(_phase(f * r, n), 8)
    x = np.tanh(x * 2.5)
    return _lp_fast(x, 2400) * _adsr(n, 0.005, 0.25, 0.7, 0.05, dur) * 0.17 * vel


def inst_hit(f, dur, vel):           # the legendary orchestra hit
    n = int(0.7 * RATE)
    x = np.zeros(n)
    for r in (0.5, 1.0, 1.19, 1.5, 2.0):
        x += _saw(_phase(f * r, n), 10)
    x += np.random.default_rng(3).standard_normal(n) * 0.6
    env = np.exp(-_t(n) / 0.16)
    return _lp_fast(x, 3500) * env * 0.16 * vel


INSTRUMENTS = {
    "brass": inst_brass, "square": inst_square, "reed": inst_reed, "flute": inst_flute,
    "harpsi": inst_harpsi, "organ": inst_organ, "strings": inst_strings, "bass": inst_bass,
    "power": inst_power, "hit": inst_hit,
}

# --- Drums -------------------------------------------------------------------------------

_drng = np.random.default_rng(11)


def drum(kind, vel):
    if kind == "kick":
        n = int(0.35 * RATE)
        t = _t(n)
        f = 50 + 90 * np.exp(-t / 0.04)
        x = np.sin(2 * np.pi * np.cumsum(f) / RATE) * np.exp(-t / 0.12)
        return x * 0.9 * vel
    if kind == "snare":
        n = int(0.25 * RATE)
        t = _t(n)
        x = _drng.standard_normal(n) * np.exp(-t / 0.06) * 0.5
        x += np.sin(2 * np.pi * 190 * t) * np.exp(-t / 0.05) * 0.4
        return _lp_fast(x, 6000) * vel
    if kind == "hat":
        n = int(0.06 * RATE)
        x = _drng.standard_normal(n)
        x = x - _lp_fast(x, 6000)
        return x * np.exp(-_t(n) / 0.015) * 0.22 * vel
    if kind == "tom":
        n = int(0.4 * RATE)
        t = _t(n)
        f = 90 + 60 * np.exp(-t / 0.08)
        return np.sin(2 * np.pi * np.cumsum(f) / RATE) * np.exp(-t / 0.18) * 0.55 * vel
    if kind == "timp":
        n = int(0.9 * RATE)
        t = _t(n)
        f = 65 + 8 * np.exp(-t / 0.1)
        x = np.sin(2 * np.pi * np.cumsum(f) / RATE) + 0.3 * _drng.standard_normal(n) * np.exp(-t / 0.02)
        return x * np.exp(-t / 0.4) * 0.6 * vel
    if kind == "crash":
        n = int(1.2 * RATE)
        x = _drng.standard_normal(n)
        x = x - _lp_fast(x, 3000)
        return x * np.exp(-_t(n) / 0.45) * 0.22 * vel
    raise ValueError(kind)


# 16 steps per bar. Letters: K kick, S snare, H hat, T tom, P timpani, C crash.
DRUMS = {
    "march": ["K...H...S...H.SS", "K...H...S.S.H.SS"],
    "rock":  ["K.H.S.H.K.KHS.H.", "K.H.S.H.K.H.S.HS"],
    "polka": ["K...S...K...S...", "K...S...K..KS.S."],
    "soft":  ["K.......H.......", "K.......H...H..."],
    "crypt": ["P...............", "P.......P...P..."],
    "boss":  ["KKH.SKH.KKH.S.HS", "KKH.SKH.KKS.SSSS"],
    "none":  ["................", "................"],
}
DRUM_KEY = {"K": "kick", "S": "snare", "H": "hat", "T": "tom", "P": "timp", "C": "crash"}

# --- Tracks ------------------------------------------------------------------------------
# Each section is a list of chords, one per bar. Uppercase = major triad, lowercase = minor.

TRACKS = {
    "title": dict(bpm=104, key=50, mode="minor", seed=1,
                  A=["i", "VI", "III", "VII", "i", "VI", "iv", "V"],
                  B=["VI", "VII", "i", "i", "iv", "V", "i", "V"],
                  lead="brass", lead2="square", acc=["strings", "arp"], bass="oom", drums="march",
                  hits=True, echo=0.25, rhythm="heroic"),
    "cellars": dict(bpm=96, key=57, mode="minor", seed=2,
                    A=["i", "iv", "VII", "III", "VI", "iv", "V", "i"],
                    B=["III", "VII", "i", "V", "VI", "III", "iv", "V"],
                    lead="harpsi", lead2="flute", acc=["arp"], bass="walk", drums="soft",
                    hits=False, echo=0.2, rhythm="minuet"),
    "warrens": dict(bpm=132, key=52, mode="minor", seed=3,
                    A=["i", "VII", "i", "VII", "iv", "i", "V", "i"],
                    B=["III", "VII", "III", "VII", "iv", "V", "i", "V"],
                    lead="reed", lead2="square", acc=["stab"], bass="oom", drums="polka",
                    hits=False, echo=0.12, rhythm="bouncy"),
    "caverns": dict(bpm=84, key=54, mode="minor", seed=4,
                    A=["i", "VI", "III", "VII", "i", "VI", "iv", "V"],
                    B=["VI", "VII", "III", "i", "iv", "VI", "V", "V"],
                    lead="flute", lead2="square", acc=["strings", "slowarp"], bass="long", drums="soft",
                    hits=False, echo=0.45, rhythm="slow"),
    "crypts": dict(bpm=76, key=48, mode="minor", seed=5,
                   A=["i", "iv", "i", "V", "VI", "bII", "V", "i"],
                   B=["iv", "i", "bII", "V", "VI", "iv", "V", "V"],
                   lead="organ", lead2="strings", acc=["organpad"], bass="long", drums="crypt",
                   hits=False, echo=0.35, rhythm="slow"),
    "forge": dict(bpm=144, key=55, mode="minor", seed=6,
                  A=["i", "VI", "VII", "i", "i", "iv", "VII", "V"],
                  B=["VI", "VII", "i", "i", "VI", "VII", "V", "V"],
                  lead="square", lead2="brass", acc=["power"], bass="root8", drums="rock",
                  hits=False, echo=0.15, rhythm="driving"),
    "boss": dict(bpm=156, key=47, mode="minor", seed=7,
                 A=["i", "VI", "VII", "V", "i", "bII", "i", "V"],
                 B=["iv", "V", "i", "VI", "iv", "bII", "V", "V"],
                 lead="brass", lead2="square", acc=["power", "strings"], bass="gallop", drums="boss",
                 hits=True, echo=0.15, rhythm="driving"),
}

# Melody rhythms: lists of (start_step, length_steps) per bar, 16 steps per bar.
RHYTHMS = {
    "heroic":  [[(0, 6), (6, 2), (8, 4), (12, 4)], [(0, 3), (3, 1), (4, 4), (8, 8)],
                [(0, 4), (4, 4), (8, 2), (10, 2), (12, 4)], [(0, 12), (12, 2), (14, 2)]],
    "minuet":  [[(0, 4), (4, 2), (6, 2), (8, 4), (12, 4)], [(0, 2), (2, 2), (4, 2), (6, 2), (8, 8)],
                [(0, 6), (6, 2), (8, 2), (10, 2), (12, 4)], [(0, 8), (8, 4), (12, 4)]],
    "bouncy":  [[(0, 2), (2, 2), (4, 2), (6, 2), (8, 3), (12, 2)], [(0, 3), (4, 3), (8, 2), (10, 2), (12, 4)],
                [(0, 2), (3, 1), (4, 2), (8, 2), (11, 1), (12, 4)], [(0, 6), (8, 2), (10, 2), (12, 2)]],
    "slow":    [[(0, 8), (8, 4), (12, 4)], [(0, 12), (12, 4)], [(0, 4), (4, 4), (8, 8)], [(0, 16)]],
    "driving": [[(0, 2), (2, 2), (4, 4), (8, 2), (10, 2), (12, 4)], [(0, 3), (3, 3), (6, 2), (8, 8)],
                [(0, 2), (2, 1), (3, 1), (4, 4), (8, 4), (12, 4)], [(0, 8), (8, 2), (10, 2), (12, 2), (14, 2)]],
}


def chord_notes(sym, key, mode):
    """Return (root_midi, [triad semitone offsets]) for a roman numeral."""
    low = sym.lower()
    table = ROMAN if mode == "minor" else ROMAN_MAJOR
    root = key + table[low]
    major = sym[-1].isupper() or sym == "bII"
    return root, [0, 4 if major else 3, 7]


def scale_pcs(key, mode, chord_root, third):
    """Scale pitch classes, with the leading tone raised over a major V chord."""
    pcs = {(key + s) % 12 for s in SCALES[mode]}
    if mode == "minor" and (chord_root - key) % 12 == 7 and third == 4:
        pcs.discard((key + 10) % 12)
        pcs.add((key + 11) % 12)
    if (chord_root - key) % 12 == 1:   # Neapolitan: flat 2
        pcs.discard((key + 2) % 12)
        pcs.add((key + 1) % 12)
    return sorted(pcs)


def nearest(target, candidates):
    return min(candidates, key=lambda c: (abs(c - target), c))


def in_range(pcs, lo, hi):
    return [m for m in range(lo, hi + 1) if m % 12 in pcs]


def melody_for(section, spec, rng, octave_shift=0):
    """Phrase-based melody: 2-bar motifs repeated over new chords, cadence at the end."""
    key, mode = spec["key"], spec["mode"]
    lo, hi = key + 12 + octave_shift, key + 28 + octave_shift
    rhythms = RHYTHMS[spec["rhythm"]]
    notes = []
    prev = key + 19 + octave_shift
    motif = None
    for bar, sym in enumerate(section):
        root, tri = chord_notes(sym, key, mode)
        ctones = in_range({(root + o) % 12 for o in tri}, lo, hi)
        stones = in_range(set(scale_pcs(key, mode, root, tri[1])), lo, hi)
        pos_in_phrase = bar % 4
        if bar == len(section) - 1:
            rhythm = [(0, 12)] if spec["rhythm"] != "slow" else [(0, 16)]
        elif pos_in_phrase in (0, 2) and motif is not None and pos_in_phrase == 2:
            rhythm = motif[0]
        else:
            rhythm = rhythms[rng.integers(len(rhythms))]
        bar_notes = []
        if pos_in_phrase == 2 and motif is not None:
            # Sequence: replay the motif's shape from the nearest chord tone (cheesy, catchy).
            start = nearest(motif[1][0] + rng.choice([-2, 2, 3, 5]), ctones)
            for (st, ln), step in zip(rhythm, motif[2]):
                idx = stones.index(nearest(start, stones))
                m = stones[int(np.clip(idx + step, 0, len(stones) - 1))]
                bar_notes.append((bar * 16 + st, ln, m))
            prev = bar_notes[-1][2]
        else:
            steps = []
            for k, (st, ln) in enumerate(rhythm):
                strong = st % 8 == 0 or ln >= 6
                if bar == len(section) - 1:
                    m = nearest(prev, in_range({key % 12} if section[-1].lower() == "i" else {root % 12}, lo, hi))
                elif strong:
                    m = nearest(prev + rng.choice([-4, -2, 0, 2, 4, 5]), ctones)
                else:
                    idx = stones.index(nearest(prev, stones))
                    m = stones[int(np.clip(idx + rng.choice([-1, 1, 1, 2, -2]), 0, len(stones) - 1))]
                if bar_notes:
                    i0 = stones.index(nearest(bar_notes[0][2], stones))
                    steps.append(stones.index(nearest(m, stones)) - i0)
                else:
                    steps.append(0)
                bar_notes.append((bar * 16 + st, ln, m))
                prev = m
            if pos_in_phrase == 0:
                motif = (rhythm, [bar_notes[0][2]], steps)
        notes.extend(bar_notes)
    return notes


def render_track(name, spec):
    rng = np.random.default_rng(spec["seed"])
    step = 60.0 / spec["bpm"] / 4               # one 16th note in seconds
    form = [("A", 0), ("B", 12), ("A", 0)]      # A B A', A' an octave up on the second lead
    bars = sum(len(spec[s]) for s, _ in form)
    total = int(bars * 16 * step * RATE)
    buf = np.zeros(total + RATE * 3)
    key, mode = spec["key"], spec["mode"]

    def put(sig, t_sec, pan_gain=1.0):
        i = int(t_sec * RATE)
        buf[i:i + len(sig)] += sig[: max(0, len(buf) - i)] * pan_gain

    melodies = {"A": melody_for(spec["A"], spec, rng), "B": melody_for(spec["B"], spec, rng, 0)}
    bar0 = 0
    for pass_i, (sec, _) in enumerate(form):
        chords = spec[sec]
        lead = INSTRUMENTS[spec["lead"]]
        # Melody (A' doubles on the second lead an octave up: peak cheese)
        for st, ln, m in melodies[sec]:
            t0 = (bar0 * 16 + st) * step
            dur = ln * step * 0.92
            vel = 0.9 if st % 4 == 0 else 0.75
            put(lead(mtof(m), dur, vel), t0)
            if pass_i == 2:
                put(INSTRUMENTS[spec["lead2"]](mtof(m + 12), dur, vel * 0.55), t0)
        for b, sym in enumerate(chords):
            bt = (bar0 + b) * 16 * step
            root, tri = chord_notes(sym, key, mode)
            croot = root if root - key < 7 else root - 12
            voicing = [croot + 12 + o for o in tri]
            # Accompaniment
            for acc in spec["acc"]:
                if acc == "strings":
                    for m in voicing:
                        put(inst_strings(mtof(m), 16 * step, 0.8), bt)
                elif acc == "organpad":
                    for m in voicing:
                        put(inst_organ(mtof(m - 12), 16 * step * 0.98, 0.55), bt)
                elif acc == "arp":
                    pat = [0, 1, 2, 1] * 4
                    for k in range(16):
                        m = voicing[pat[k]] + (12 if k % 8 >= 4 else 0)
                        put(inst_harpsi(mtof(m), step, 0.55), bt + k * step)
                elif acc == "slowarp":
                    for k in range(8):
                        m = voicing[[0, 1, 2, 1][k % 4]] + 12
                        put(inst_harpsi(mtof(m), 2 * step, 0.3), bt + 2 * k * step)
                elif acc == "stab":
                    for k in (4, 12):
                        for m in voicing:
                            put(inst_harpsi(mtof(m), step, 0.7), bt + k * step)
                elif acc == "power":
                    for k in (0, 3, 6, 8, 11, 14):
                        put(inst_power(mtof(croot), 2 * step, 0.9 if k in (0, 8) else 0.7), bt + k * step)
            # Bass
            br = croot - 12
            style = spec["bass"]
            if style == "oom":
                seq = [(0, br, 3), (4, br + 7, 3), (8, br, 3), (12, br + 7, 3)]
            elif style == "walk":
                seq = [(0, br, 3), (4, br + 7, 3), (8, br + 12, 3), (12, br + 7, 3)]
            elif style == "long":
                seq = [(0, br, 15)]
            elif style == "root8":
                seq = [(k, br + (12 if k in (6, 14) else 0), 2) for k in range(0, 16, 2)]
            else:  # gallop
                seq = [(k + o, br, 1) for k in range(0, 16, 4) for o in (0, 2, 3)]
            for st, m, ln in seq:
                put(inst_bass(mtof(m), ln * step * 0.9, 0.9), bt + st * step)
            # Drums
            pat = DRUMS[spec["drums"]][1 if b % 4 == 3 else 0]
            for k, ch in enumerate(pat):
                if ch in DRUM_KEY:
                    put(drum(DRUM_KEY[ch], 0.9 if k % 4 == 0 else 0.65), bt + k * step)
            if b == 0 and spec["drums"] not in ("none", "crypt", "soft"):
                put(drum("crash", 0.8), bt)
            if spec["hits"] and b % 4 == 0:
                put(inst_hit(mtof(croot + 12), 0.5, 0.9), bt)
        bar0 += len(chords)

    # Echo (feedback delay of a dotted 8th), then fold the tail back to the start
    # so the loop point is seamless.
    if spec["echo"] > 0:
        d = int(step * 3 * RATE)
        wet = np.zeros_like(buf)
        src = buf.copy()
        g = spec["echo"]
        for k in range(1, 6):
            wet[d * k:] += src[: len(buf) - d * k] * (g ** k)
        buf = buf + wet
    loop = buf[:total].copy()
    tail = buf[total:]
    loop[: len(tail)] += tail[: total]
    loop = np.tanh(loop / (np.max(np.abs(loop)) * 0.9) * 1.1) * 0.8   # gentle glue + normalise
    return loop


def write_ogg(name, data):
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, f"music_{name}.ogg")
    with tempfile.TemporaryDirectory() as tmp:
        wav_path = os.path.join(tmp, "m.wav")
        with wave.open(wav_path, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(RATE)
            w.writeframes((np.clip(data, -1, 1) * 32767).astype("<i2").tobytes())
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav_path,
                        "-c:a", "libvorbis", "-q:a", "3", path], check=True)
    print(f"  music_{name}.ogg  {len(data) / RATE:5.1f} s  {os.path.getsize(path) // 1024} KB")


def main():
    names = sys.argv[1:] or list(TRACKS)
    for n in names:
        write_ogg(n, render_track(n, TRACKS[n]))


if __name__ == "__main__":
    main()
