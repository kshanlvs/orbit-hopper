"""Synthesizes every Neon Shift sound from scratch (no samples, no licences).

Usage:  python3 tool/make_neon_sounds.py      (needs numpy, scipy; ffmpeg for the music)
Writes: assets/audio/neon/*.wav
"""
import os
import subprocess
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import make_sounds as ms  # noqa: E402  (shared synth helpers)

SR = ms.SR
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'audio', 'neon')
ms.OUT = OUT
rng = np.random.default_rng(11)
t_axis, env, lowpass, highpass, sweep, tone, place, save, note = (
    ms.t_axis, ms.env, ms.lowpass, ms.highpass, ms.sweep, ms.tone, ms.place, ms.save, ms.note)


def noise(dur):
    return rng.standard_normal(int(SR * dur))


# ------------------------------------------------------------------ SFX

def flip():
    """Short bright 'zip' — a pitch flick that reads as a gravity swap."""
    dur = 0.11
    n = int(SR * dur)
    z = ms.sweep(900, 2200, dur) * env(n, 0.001, 0.03)
    sub = np.sin(2 * np.pi * 180 * t_axis(dur)) * env(n, 0.001, 0.02) * 0.5
    return z * 0.6 + sub


def shard():
    """Glassy two-note ping."""
    x = tone(note(88), 0.25, 0.07, (1, 0.25, 0.1))
    place(x, tone(note(95), 0.2, 0.06, (1, 0.2)) * 0.6, 0.035)
    return x


def chain(level):
    """Rising chain chime: five steps of a minor pentatonic."""
    steps = [81, 84, 86, 88, 91]
    m = steps[level - 1]
    x = tone(note(m), 0.5, 0.16, (1, 0.35, 0.15, 0.05))
    place(x, tone(note(m + 12), 0.35, 0.1, (1, 0.2)) * 0.45, 0.04)
    return x


def near_miss():
    """Air rushing past: filtered noise swell plus a whistle."""
    dur = 0.32
    n = int(SR * dur)
    t = t_axis(dur)
    shape = np.sin(np.pi * np.minimum(1, t / dur)) ** 2
    hiss = highpass(lowpass(noise(dur), 6000), 900) * shape * 0.5
    whistle = ms.sweep(1500, 700, dur) * shape * 0.25
    return hiss + whistle


def dash_ready():
    x = np.zeros(int(SR * 0.6))
    for i, m in enumerate([76, 83, 88]):
        place(x, tone(note(m), 0.45, 0.18, (1, 0.3, 0.1)), i * 0.07)
    return x


def dash():
    """Heavy zap with a downward sub drop."""
    dur = 0.5
    n = int(SR * dur)
    zap = ms.sweep(2400, 300, dur, 'square') * env(n, 0.002, 0.12)
    sub = ms.sweep(160, 45, dur) * env(n, 0.004, 0.25)
    hiss = highpass(noise(dur), 3000) * env(n, 0.001, 0.05) * 0.3
    return lowpass(zap, 5000) * 0.5 + sub * 0.9 + hiss


def pierce():
    """Crystal shattering."""
    dur = 0.3
    n = int(SR * dur)
    x = highpass(noise(dur), 2500) * env(n, 0.001, 0.05) * 0.6
    for m in (96, 101, 103):
        x += tone(note(m), dur, 0.06, (1, 0.5)) * 0.25
    return x


def break_warn():
    """Riser: noise sweep up over a second."""
    dur = 1.2
    t = t_axis(dur)
    n = len(t)
    x = noise(dur)
    # Crude rising filter: blend of high-passed versions.
    lo = lowpass(x, 1200)
    hi = highpass(x, 2500)
    k = t / dur
    riser = (lo * (1 - k) + hi * k) * k ** 1.5 * 0.5
    tone_up = ms.sweep(200, 1600, dur) * k ** 2 * 0.25
    return (riser + tone_up) * np.minimum(1, (dur - t) / 0.05)


def break_start():
    """Impact + glitchy tail."""
    dur = 0.9
    n = int(SR * dur)
    t = t_axis(dur)
    boom = np.sin(2 * np.pi * 50 * t * (1 + 0.6 * np.exp(-t * 20))) * env(n, 0.002, 0.3)
    crack = highpass(noise(dur), 1800) * env(n, 0.001, 0.04) * 0.6
    glitch = np.sign(np.sin(2 * np.pi * 220 * t)) * (np.floor(t * 28) % 2) * env(n, 0.01, 0.25) * 0.12
    return boom + crack + lowpass(glitch, 4000)


def chase_warn():
    """Two-tone alarm pulse."""
    x = np.zeros(int(SR * 1.0))
    for i in range(4):
        f = 660 if i % 2 == 0 else 880
        seg = ms.sweep(f, f * 0.97, 0.2, 'square') * env(int(SR * 0.2), 0.005, 0.12)
        place(x, lowpass(seg, 3000) * 0.5, i * 0.24)
    return x


def escape():
    x = np.zeros(int(SR * 1.4))
    for i, m in enumerate([69, 72, 76, 81, 84]):
        place(x, tone(note(m), 0.9, 0.35, (1, 0.4, 0.2, 0.1)) * 0.5, i * 0.08)
    place(x, ms.sweep(300, 1400, 0.4) * env(int(SR * 0.4), 0.01, 0.2) * 0.2, 0)
    return x


def chain_break():
    dur = 0.25
    n = int(SR * dur)
    return ms.sweep(500, 180, dur) * env(n, 0.003, 0.09) * 0.7


def milestone():
    x = tone(note(84), 0.8, 0.3, (1, 0.3, 0.1))
    place(x, tone(note(91), 0.7, 0.25, (1, 0.2)) * 0.5, 0.09)
    return x


def death():
    """Crunch: distorted noise burst + falling tone."""
    dur = 1.0
    n = int(SR * dur)
    t = t_axis(dur)
    crunch = np.tanh(lowpass(noise(dur), 3000) * 3) * env(n, 0.001, 0.18) * 0.7
    fall = ms.sweep(700, 60, dur, 'square') * env(n, 0.002, 0.35)
    sub = np.sin(2 * np.pi * 45 * t) * env(n, 0.002, 0.4)
    return crunch + lowpass(fall, 2500) * 0.4 + sub * 0.8


def record():
    x = np.zeros(int(SR * 2.0))
    seq = [(72, 0), (76, 0.12), (79, 0.24), (84, 0.36), (79, 0.6), (84, 0.72), (88, 0.84)]
    for m, at in seq:
        place(x, tone(note(m), 1.0, 0.4, (1, 0.45, 0.2, 0.1)) * 0.45, at)
    place(x, ms._pad([60, 64, 67, 72], 1.6, 2500, 0.07), 0.3)
    return x


def ui():
    dur = 0.05
    n = int(SR * dur)
    return np.sin(2 * np.pi * 1400 * t_axis(dur)) * env(n, 0.001, 0.012)


# ------------------------------------------------------------------ music

def _kick(level=0.9):
    dur = 0.35
    t = t_axis(dur)
    f = 45 + 110 * np.exp(-t * 28)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * env(len(t), 0.001, 0.14) * level


def _snare(level=0.35):
    dur = 0.25
    n = int(SR * dur)
    body = np.sin(2 * np.pi * 190 * t_axis(dur)) * env(n, 0.001, 0.05)
    return (highpass(noise(dur), 1500) * env(n, 0.001, 0.08) + body * 0.5) * level


def _hat(level=0.06, open_=False):
    dur = 0.12 if open_ else 0.04
    n = int(SR * dur)
    return highpass(noise(dur), 8000) * env(n, 0.001, 0.04 if open_ else 0.01) * level


def _saw_note(m, dur, cutoff, level):
    t = t_axis(dur)
    x = ms._saw(note(m), t) + ms._saw(note(m + 0.07), t)
    return lowpass(x, cutoff) * env(len(t), 0.004, dur * 0.5) * level


def music_run():
    """Driving synthwave, 112 bpm: Am - F - C - G, 16 bars."""
    bpm = 112
    beat = 60 / bpm
    bars = 16
    length = bars * 4 * beat
    buf = np.zeros(int(SR * (length + 3)))
    chords = [[57, 60, 64], [53, 57, 60], [48, 52, 55], [55, 59, 62]]
    roots = [45, 41, 48, 43]
    for bar in range(bars):
        ci = bar % 4
        start = bar * 4 * beat
        intro = bar < 2
        # Pad.
        place(buf, ms._pad([m + 12 for m in chords[ci]], 4 * beat + 1.0, 1800, 0.035), start)
        # Rolling 16th-note bass.
        for k in range(16):
            m = roots[ci] - 12 + (12 if k % 4 == 2 else 0)
            place(buf, _saw_note(m, beat / 4 * 0.9, 700 + 500 * (k % 2), 0.12), start + k * beat / 4)
        if not intro:
            for k in range(4):
                place(buf, _kick(), start + k * beat)
                place(buf, _hat(open_=True), start + k * beat + beat / 2)
            place(buf, _snare(), start + beat)
            place(buf, _snare(), start + 3 * beat)
        for k in range(8):
            place(buf, _hat(0.035), start + k * beat / 2)
        # Arpeggio lead from bar 4.
        if bar >= 4:
            arp = [chords[ci][0] + 24, chords[ci][1] + 24, chords[ci][2] + 24, chords[ci][1] + 24]
            for k in range(8):
                m = arp[k % 4] + (12 if (bar % 8 >= 6 and k % 4 == 3) else 0)
                place(buf, tone(note(m), 0.3, 0.09, (1, 0.5, 0.25, 0.12)) * 0.06, start + k * beat / 2)
    return ms._loop(ms._echo(buf, beat * 0.75, 0.25, 2), length)


def music_menu():
    """Slow neon haze, 84 bpm: Am - F - Dm - E, pulsing bass, no drums."""
    bpm = 84
    beat = 60 / bpm
    bars = 8
    length = bars * 4 * beat
    buf = np.zeros(int(SR * (length + 4)))
    chords = [[57, 60, 64, 69], [53, 57, 60, 65], [50, 53, 57, 62], [52, 56, 59, 64]]
    roots = [45, 41, 38, 40]
    for bar in range(bars):
        ci = (bar // 2) % 4
        start = bar * 4 * beat
        if bar % 2 == 0:
            place(buf, ms._pad(chords[ci], 8 * beat + 1.5, 1300, 0.05), start)
        for k in range(8):
            place(buf, _saw_note(roots[ci] - 12, beat / 2 * 0.8, 450, 0.1), start + k * beat / 2)
        for k in range(4):
            m = chords[ci][(k + bar) % 4] + 24
            place(buf, tone(note(m), 1.0, 0.35, (1, 0.2, 0.05)) * 0.05, start + k * beat + beat / 4)
    return ms._loop(ms._echo(buf, beat * 1.5, 0.3, 2), length)


def main():
    os.makedirs(OUT, exist_ok=True)
    save('flip.wav', flip(), 0.55)
    save('shard.wav', shard(), 0.55)
    for i in range(1, 6):
        save(f'chain_{i}.wav', chain(i), 0.6)
    save('near_miss.wav', near_miss(), 0.7)
    save('dash_ready.wav', dash_ready(), 0.6)
    save('dash.wav', dash(), 0.85)
    save('pierce.wav', pierce(), 0.65)
    save('break_warn.wav', break_warn(), 0.6)
    save('break_start.wav', break_start(), 0.9)
    save('chase_warn.wav', chase_warn(), 0.65)
    save('escape.wav', escape(), 0.85)
    save('chain_break.wav', chain_break(), 0.5)
    save('milestone.wav', milestone(), 0.6)
    save('death.wav', death(), 0.95)
    save('record.wav', record(), 0.9)
    save('ui.wav', ui(), 0.4)
    for name, fn in (('neon_run', music_run), ('neon_menu', music_menu)):
        tmp = os.path.join(OUT, f'_{name}.wav')
        save(f'_{name}.wav', fn(), 0.8, fade_out=False)
        subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', tmp, '-ar', '22050', '-ac', '1',
                        '-c:a', 'pcm_s16le', os.path.join(OUT, f'{name}.wav')], check=True)
        os.remove(tmp)
    print('neon sounds written to', os.path.abspath(OUT))


if __name__ == '__main__':
    main()
