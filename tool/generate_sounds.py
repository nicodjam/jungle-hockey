"""Synthesizes the sound effects of Jungle Hockey, in a jungle mood:
assets/sounds/*.wav.

Usage (from the project root):
    pip install numpy
    python3 tool/generate_sounds.py

    hit_1.wav, hit_2.wav, hit_3.wav  mallet on puck: a hollow coconut "tock"
                                      (three pitches, played in turn)
    power.wav                         a power starts: rising marimba arpeggio
                                      with a shimmer
    goal.wav                          goal: tribal drums and a marimba call
    victory.wav                       end of the match: drum roll and a
                                      marimba melody

Everything is computed (no samples, nothing to license): edit the recipes
below and run the script again. Mono, 44.1 kHz, 16 bits: short WAV files
start fastest on Android (SoundPool).
"""

import os
import wave

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "sounds")
RATE = 44100
rng = np.random.default_rng(5)


def t_axis(duration):
    return np.arange(int(duration * RATE)) / RATE


def env(t, attack, decay):
    """Fast attack, exponential decay."""
    return np.minimum(1, t / attack) * np.exp(-t / decay)


def tail(x, fade=0.025):
    """Fades the end of a note out, so that cutting it does not click."""
    n = min(len(x), int(fade * RATE))
    x[-n:] *= np.linspace(1, 0, n) ** 2
    return x


def place(track, sound, at):
    i = int(at * RATE)
    end = min(len(track), i + len(sound))
    track[i:end] += sound[: end - i]


def lowpass(x, cutoff):
    """One-pole low-pass filter."""
    a = np.exp(-2 * np.pi * cutoff / RATE)
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


def coconut(freq, duration=0.16):
    """Hollow wooden knock: a resonance that drops slightly in pitch, an
    inharmonic overtone, and the click of the impact."""
    t = t_axis(duration)
    pitch = freq * (1 + 0.08 * np.exp(-t / 0.012))
    phase = 2 * np.pi * np.cumsum(pitch) / RATE
    body = np.sin(phase) * env(t, 0.0008, 0.032)
    body += 0.45 * np.sin(2.76 * phase) * env(t, 0.0005, 0.014)
    body += 0.18 * np.sin(5.4 * phase) * env(t, 0.0005, 0.006)
    click = rng.standard_normal(len(t)) * env(t, 0.0002, 0.0025)
    click = click - lowpass(click, 1500)  # keep the bright part
    return tail(body + 0.5 * click)


def marimba(freq, duration=0.9, level=1.0):
    """Marimba bar: fundamental plus its 4th and 10th partials, the upper
    ones fading faster; a soft mallet thump."""
    t = t_axis(duration)
    s = np.sin(2 * np.pi * freq * t) * env(t, 0.002, 0.32)
    s += 0.32 * np.sin(2 * np.pi * freq * 3.93 * t) * env(t, 0.001, 0.07)
    s += 0.08 * np.sin(2 * np.pi * freq * 9.2 * t) * env(t, 0.001, 0.02)
    thump = lowpass(rng.standard_normal(len(t)), 900) * env(t, 0.0005, 0.01)
    return tail(level * (s + 0.25 * thump), 0.15)


def drum(freq, duration=0.5, level=1.0, decay=0.16):
    """Hand drum (djembe-like): a pitched membrane that drops, plus a slap."""
    t = t_axis(duration)
    pitch = freq * (1 + 0.6 * np.exp(-t / 0.03))
    s = np.sin(2 * np.pi * np.cumsum(pitch) / RATE) * env(t, 0.001, decay)
    slap = lowpass(rng.standard_normal(len(t)), 3000) * env(t, 0.0005, 0.018)
    return tail(level * (s + 0.5 * slap))


def shaker(duration=0.12, level=0.3):
    t = t_axis(duration)
    n = rng.standard_normal(len(t))
    n = n - lowpass(n, 4000)
    return tail(level * n * env(t, 0.01, 0.035))


def note(name):
    names = {"C": -9, "D": -7, "E": -5, "F": -4, "G": -2, "A": 0, "B": 2}
    semitone = names[name[0]] + 12 * (int(name[-1]) - 4)
    return 440 * 2 ** (semitone / 12)


def finish(x, peak=0.89):
    fade = int(0.02 * RATE)
    x = x.copy()
    x[-fade:] *= np.linspace(1, 0, fade)
    return x / np.max(np.abs(x)) * peak


def write(name, x):
    path = os.path.join(OUT, name)
    data = (np.clip(x, -1, 1) * 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data.tobytes())
    print(f"{os.path.relpath(path, ROOT)}: {len(x) / RATE:.2f} s, {os.path.getsize(path) // 1024} KB")


def power():
    track = np.zeros(int(1.1 * RATE))
    for k, n in enumerate(["C5", "E5", "G5", "A5", "C6", "E6"]):
        place(track, marimba(note(n), 0.75, 0.8 + 0.04 * k), k * 0.055)
    # Shimmer: two high detuned partials fading in and out.
    t = t_axis(0.8)
    shimmer = (np.sin(2 * np.pi * note("E7") * t) + np.sin(2 * np.pi * note("E7") * 1.006 * t))
    shimmer *= np.sin(np.pi * np.minimum(1, t / 0.8)) ** 2 * 0.12
    shimmer = tail(shimmer)
    place(track, shimmer, 0.18)
    return finish(track, 0.8)


def goal():
    track = np.zeros(int(1.6 * RATE))
    # Drums: da-da DUM, DUM.
    for at, f, lvl in ((0.0, 190, 0.7), (0.09, 190, 0.7), (0.2, 120, 1.0), (0.42, 95, 1.0)):
        place(track, drum(f, 0.6, lvl), at)
    for k in range(6):
        place(track, shaker(level=0.25), 0.2 + k * 0.07)
    # Marimba call on the last drum.
    for at, n in ((0.42, "G4"), (0.5, "C5"), (0.58, "E5"), (0.66, "G5"), (0.74, "C6")):
        place(track, marimba(note(n), 0.8, 0.7), at)
    place(track, marimba(note("C5"), 0.9, 0.5) + marimba(note("E5"), 0.9, 0.4), 0.74)
    return finish(track)


def victory():
    track = np.zeros(int(2.8 * RATE))
    # Drum roll, faster and louder.
    at, gap = 0.0, 0.11
    while at < 0.9:
        place(track, drum(170 if int(at / gap) % 2 else 150, 0.3, 0.35 + 0.5 * at, 0.08), at)
        at += gap
        gap = max(0.045, gap * 0.9)
    place(track, drum(85, 0.9, 1.1, 0.3), 0.92)
    melody = [("C5", 0.92), ("E5", 1.06), ("G5", 1.2), ("A5", 1.34), ("G5", 1.48), ("C6", 1.62)]
    for n, t0 in melody:
        place(track, marimba(note(n), 0.9, 0.8), t0)
    for n in ("C5", "E5", "G5", "C6"):
        place(track, marimba(note(n), 1.1, 0.45), 1.62)
    for k in range(10):
        place(track, shaker(level=0.2), 0.92 + k * 0.1)
    return finish(track)


def main():
    os.makedirs(OUT, exist_ok=True)
    for k, freq in enumerate((560, 640, 720), start=1):
        write(f"hit_{k}.wav", finish(coconut(freq), 0.9))
    write("power.wav", power())
    write("goal.wav", goal())
    write("victory.wav", victory())


if __name__ == "__main__":
    main()
