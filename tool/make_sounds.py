"""Synthesizes every sound in Orbit Hopper from scratch (no samples, no licences).

Usage:  python3 tool/make_sounds.py        (needs numpy, scipy; ffmpeg to downsample the music)
Writes: assets/audio/*.wav (effects + four looping music_<mood>.wav tracks)
"""
import os
import subprocess

import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, lfilter

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'audio')
rng = np.random.default_rng(7)


def t_axis(dur):
    return np.arange(int(SR * dur)) / SR


def env(n, attack=0.005, decay=None, sr=SR):
    """Fast attack + exponential decay envelope."""
    e = np.ones(n)
    a = max(1, int(attack * sr))
    e[:a] = np.linspace(0, 1, a)
    if decay:
        e[a:] *= np.exp(-np.arange(n - a) / (decay * sr))
    return e


def lowpass(x, cutoff):
    b, a = butter(2, cutoff / (SR / 2), 'low')
    return lfilter(b, a, x)


def highpass(x, cutoff):
    b, a = butter(2, cutoff / (SR / 2), 'high')
    return lfilter(b, a, x)


def sweep(f0, f1, dur, shape='sine'):
    t = t_axis(dur)
    f = f0 * (f1 / f0) ** (t / dur)  # exponential sweep
    phase = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(phase) if shape == 'sine' else np.sign(np.sin(phase)) * 0.5


def tone(freq, dur, decay=0.2, harmonics=(1.0, 0.3, 0.12)):
    t = t_axis(dur)
    x = sum(a * np.sin(2 * np.pi * freq * (i + 1) * t) for i, a in enumerate(harmonics))
    return x * env(len(t), 0.003, decay)


def place(buf, x, at):
    i = int(at * SR)
    end = min(len(buf), i + len(x))
    buf[i:end] += x[: end - i]


def save(name, x, peak=0.85, fade_out=True):
    x = np.asarray(x, dtype=np.float64)
    if fade_out:  # avoid end clicks; skipped for the loop, which must stay seamless
        fade = min(len(x), int(0.01 * SR))
        x[-fade:] *= np.linspace(1, 0, fade)
    x = x / (np.max(np.abs(x)) + 1e-9) * peak
    wavfile.write(os.path.join(OUT, name), SR, (x * 32767).astype(np.int16))


def note(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


# ------------------------------------------------------------------ SFX

def launch():
    dur = 0.22
    n = int(SR * dur)
    noise = highpass(rng.standard_normal(n), 1500) * env(n, 0.01, 0.06) * 0.5
    zap = sweep(320, 1400, dur) * env(n, 0.002, 0.07)
    return noise + zap


def capture():
    buf = np.zeros(int(SR * 0.6))
    place(buf, tone(note(81), 0.6, 0.18, (1, 0.25, 0.08)), 0)
    place(buf, tone(note(88), 0.6, 0.22, (0.6, 0.15)), 0.035)
    click = rng.standard_normal(int(SR * 0.01)) * np.linspace(1, 0, int(SR * 0.01)) * 0.3
    place(buf, click, 0)
    return buf


PENTA = [84, 86, 88, 91, 93]  # C6 D6 E6 G6 A6


def perfect(level):
    """Bright 3-note arpeggio; higher root for bigger combos."""
    root = PENTA[level - 1]
    buf = np.zeros(int(SR * 0.9))
    for k, step in enumerate([0, 4, 7]):
        place(buf, tone(note(root + step), 0.8, 0.25, (1, 0.4, 0.15, 0.05)) * 0.8, k * 0.055)
    t = t_axis(0.9)
    shimmer = np.sin(2 * np.pi * note(root + 24) * t) * env(len(t), 0.02, 0.15) * 0.15
    return buf + shimmer


def stardust():
    buf = np.zeros(int(SR * 0.3))
    place(buf, tone(2093, 0.25, 0.05, (1, 0.2)), 0)
    place(buf, tone(2637, 0.25, 0.06, (1, 0.2)), 0.045)
    return buf


def warning():
    buf = np.zeros(int(SR * 0.45))
    for k in range(2):
        t = t_axis(0.13)
        b = np.sign(np.sin(2 * np.pi * 330 * t)) * 0.4 + np.sin(2 * np.pi * 660 * t) * 0.3
        place(buf, lowpass(b, 2500) * env(len(t), 0.004, 0.06), k * 0.18)
    return buf


def death():
    dur = 1.1
    n = int(SR * dur)
    noise = lowpass(rng.standard_normal(n), 900) * env(n, 0.002, 0.25)
    boom = sweep(180, 35, dur) * env(n, 0.002, 0.35) * 1.2
    crack = highpass(rng.standard_normal(n), 3000) * env(n, 0.001, 0.03) * 0.4
    return noise + boom + crack


def sector():
    dur = 1.6
    t = t_axis(dur)
    swell = np.minimum(1, t / 0.5) * np.exp(-np.maximum(0, t - 0.5) / 0.5)
    chord = sum(np.sin(2 * np.pi * note(m) * t) * (0.5 if i else 0.7)
                for i, m in enumerate([72, 76, 79, 84]))
    buf = chord * swell
    place(buf, tone(note(96), dur - 0.45, 0.35) * 0.4, 0.45)
    return buf


def ui_tap():
    return tone(1320, 0.08, 0.02, (1, 0.1))


# ------------------------------------------------------------------ music

def _saw(f, t):
    return 2 * ((t * f) % 1) - 1


def _pad(chord, dur, cutoff, level, detune=0.08, wave='saw'):
    t = t_axis(dur)
    x = np.zeros(len(t))
    for m in chord:
        for det in (-detune, detune):
            f = note(m + det)
            x += _saw(f, t) if wave == 'saw' else np.sin(2 * np.pi * f * t + 0.3 * np.sin(2 * np.pi * 5 * t))
    x = lowpass(x, cutoff) * level
    sw = np.minimum(1, t / 1.5) * np.minimum(1, np.maximum(0, (dur - t) / 1.8))
    return x * sw


def _loop(buf, length):
    """Folds the tail back onto the start so the track loops seamlessly."""
    loop_n = int(SR * length)
    out = buf[:loop_n].copy()
    tail = buf[loop_n:]
    out[: len(tail)] += tail
    return out


def _echo(buf, delay, amount, repeats=2):
    out = buf.copy()
    d = int(SR * delay)
    for k in range(1, repeats + 1):
        out[d * k:] += buf[: len(buf) - d * k] * (amount ** k)
    return out


def music_solar():
    """Warm and hopeful near the Sun: Am - F - C - G, 92 bpm."""
    bpm = 92
    beat = 60 / bpm
    bars = 8
    length = bars * 4 * beat
    buf = np.zeros(int(SR * (length + 4)))
    chords = [[57, 60, 64, 69], [53, 57, 60, 65], [48, 55, 60, 64], [55, 59, 62, 67]]
    bass = [45, 41, 48, 43]
    for bar in range(bars):
        ci = (bar // 2) % 4
        start = bar * 4 * beat
        if bar % 2 == 0:
            dur = 8 * beat + 1.5
            place(buf, _pad(chords[ci], dur, 1100, 0.06), start)
            t = t_axis(dur)
            place(buf, np.sin(2 * np.pi * note(bass[ci] - 12) * t) * 0.22 * np.minimum(1, t / 1.2)
                  * np.minimum(1, np.maximum(0, (dur - t) / 1.5)), start)
        arp = chords[ci] + [chords[ci][1] + 12, chords[ci][2] + 12]
        for k in range(8):
            if (bar * 8 + k) % 3 == 2 and k % 2:
                continue
            m = arp[(k * 3 + bar) % len(arp)] + 12
            place(buf, tone(note(m), 1.2, 0.35, (1, 0.2, 0.05)) * 0.11, start + k * beat / 2)
        for k in range(4):
            h = highpass(rng.standard_normal(int(SR * 0.05)), 7000) * env(int(SR * 0.05), 0.001, 0.012) * 0.04
            place(buf, h, start + k * beat + beat / 2)
    return _loop(_echo(buf, beat * 0.75, 0.3, 1), length)


def music_outer():
    """Cold and lonely among the giants: Dm - Bb - F - C, sparse bells, 76 bpm."""
    bpm = 76
    beat = 60 / bpm
    bars = 8
    length = bars * 4 * beat
    buf = np.zeros(int(SR * (length + 6)))
    chords = [[50, 57, 62, 65], [46, 53, 58, 62], [53, 57, 60, 65], [48, 55, 60, 64]]
    for bar in range(0, bars, 2):
        ci = (bar // 2) % 4
        start = bar * 4 * beat
        dur = 8 * beat + 2
        place(buf, _pad(chords[ci], dur, 800, 0.05, detune=0.12, wave='sine'), start)
        t = t_axis(dur)
        place(buf, np.sin(2 * np.pi * note(chords[ci][0] - 12) * t) * 0.18
              * np.minimum(1, t / 2) * np.minimum(1, np.maximum(0, (dur - t) / 2)), start)
        # Glassy bells, one every beat with gaps — lots of empty space.
        for k in range(8):
            if k in (3, 6):
                continue
            m = chords[ci][(k * 2 + bar) % 4] + 24
            place(buf, tone(note(m), 2.5, 0.8, (1, 0.0, 0.15, 0.0, 0.05)) * 0.07, start + k * beat)
    return _loop(_echo(buf, beat, 0.45, 3), length)


def music_deep():
    """Suspense in interstellar space: low drone, heartbeat pulse, distant pings. 60 bpm."""
    bpm = 60
    beat = 60 / bpm
    bars = 8
    length = bars * 4 * beat
    n = int(SR * (length + 6))
    buf = np.zeros(n)
    t = np.arange(n) / SR
    # Drone: D + A, slowly beating, with a breathing filter.
    drone = sum(np.sin(2 * np.pi * note(m) * t + 0.4 * np.sin(2 * np.pi * 0.07 * t)) for m in (38, 45, 50.05))
    breath = 0.6 + 0.4 * np.sin(2 * np.pi * t / length * 2)
    buf += drone * 0.07 * breath
    # Tense pads: Dm(add9) -> Bbmaj7(#11) -> Gm(add9) -> A(sus4)
    chords = [[50, 53, 57, 64], [46, 50, 57, 64], [43, 50, 55, 57], [45, 50, 52, 57]]
    for bar in range(0, bars, 2):
        ci = (bar // 2) % 4
        place(buf, _pad(chords[ci], 8 * beat + 3, 650, 0.035, detune=0.18, wave='sine'), bar * 4 * beat)
    # Heartbeat: soft double thump every beat.
    thump = lowpass(np.sin(2 * np.pi * 55 * t_axis(0.25)) * env(int(SR * 0.25), 0.004, 0.06), 300)
    for b in range(bars * 4):
        place(buf, thump * 0.35, b * beat)
        place(buf, thump * 0.2, b * beat + 0.22)
    # Distant sonar pings at fixed, irregular moments.
    for at, m in ((2.5, 86), (9.0, 81), (14.5, 89), (21.0, 84), (27.5, 88)):
        place(buf, tone(note(m), 3.0, 0.9, (1, 0.0, 0.05)) * 0.06, at)
    return _loop(_echo(buf, 0.75, 0.5, 3), length)


def music_cosmic():
    """Awe among the galaxies: E - C#m - A - B, wide choir pads and shimmer. 70 bpm."""
    bpm = 70
    beat = 60 / bpm
    bars = 8
    length = bars * 4 * beat
    buf = np.zeros(int(SR * (length + 6)))
    chords = [[52, 56, 59, 64, 68], [49, 56, 61, 64, 68], [45, 57, 61, 64, 69], [47, 54, 59, 63, 66]]
    for bar in range(0, bars, 2):
        ci = (bar // 2) % 4
        start = bar * 4 * beat
        dur = 8 * beat + 2.5
        place(buf, _pad(chords[ci], dur, 1600, 0.035, detune=0.1, wave='sine'), start)
        place(buf, _pad(chords[ci][1:], dur, 2400, 0.02, detune=0.05), start)
        t = t_axis(dur)
        place(buf, np.sin(2 * np.pi * note(chords[ci][0] - 12) * t) * 0.2
              * np.minimum(1, t / 2) * np.minimum(1, np.maximum(0, (dur - t) / 2)), start)
        # Shimmer: soft 16th-note sparkles high above.
        notes = [m + 24 for m in chords[ci][1:]]
        for k in range(32):
            if k % 4 == 3:
                continue
            m = notes[(k * 3) % len(notes)]
            place(buf, tone(note(m), 0.9, 0.25, (1, 0.1)) * 0.035, start + k * beat / 4)
    return _loop(_echo(buf, beat * 0.5, 0.35, 2), length)


# ------------------------------------------------------------------ journey SFX

def reveal():
    """Discovery: deep boom, rising shimmer, then a bright major chord bloom."""
    dur = 2.4
    n = int(SR * dur)
    buf = np.zeros(n)
    boom = sweep(90, 40, 1.2) * env(int(SR * 1.2), 0.003, 0.4) * 0.9
    place(buf, boom, 0)
    rise = highpass(rng.standard_normal(int(SR * 0.7)), 2500)
    rise *= np.linspace(0, 1, len(rise)) ** 2 * 0.25
    place(buf, rise, 0)
    for k, m in enumerate([76, 80, 83, 88, 92]):
        place(buf, tone(note(m), dur - 0.6, 0.6, (1, 0.35, 0.1)) * 0.35, 0.6 + k * 0.06)
    return buf


def ping():
    """Sonar ping from an unknown object."""
    dur = 1.6
    t = t_axis(dur)
    x = np.sin(2 * np.pi * 1180 * t) * np.exp(-t / 0.18) + 0.3 * np.sin(2 * np.pi * 2360 * t) * np.exp(-t / 0.08)
    x *= env(len(t), 0.002)
    return _echo(x, 0.32, 0.38, 3)


def warp():
    """Crossing into a new region: a filtered whoosh with a low swell."""
    dur = 1.8
    n = int(SR * dur)
    t = t_axis(dur)
    noise = rng.standard_normal(n)
    # Moving band-pass: blend of low and high passes along the sweep.
    lo = lowpass(noise, 600)
    hi = highpass(noise, 2500)
    shape = np.sin(np.pi * t / dur) ** 2
    mix = (lo * (1 - t / dur) + hi * (t / dur)) * shape * 0.6
    swell = sweep(60, 120, dur) * shape * 0.5
    return mix + swell


def main():
    os.makedirs(OUT, exist_ok=True)
    save('launch.wav', launch(), 0.6)
    save('capture.wav', capture(), 0.7)
    for i in range(1, 6):
        save(f'perfect_{i}.wav', perfect(i), 0.75)
    save('stardust.wav', stardust(), 0.5)
    save('warning.wav', warning(), 0.6)
    save('death.wav', death(), 0.95)
    save('sector.wav', sector(), 0.7)
    save('ui_tap.wav', ui_tap(), 0.45)

    save('reveal.wav', reveal(), 0.9)
    save('ping.wav', ping(), 0.55)
    save('warp.wav', warp(), 0.7)

    # One looping track per mood. WAV (not mp3) so loops are gapless;
    # 22 kHz mono keeps each around 1-1.5 MB.
    for name, fn in (('solar', music_solar), ('outer', music_outer), ('deep', music_deep), ('cosmic', music_cosmic)):
        tmp = os.path.join(OUT, f'_music_{name}.wav')
        save(f'_music_{name}.wav', fn(), 0.8, fade_out=False)
        subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', tmp, '-ar', '22050', '-ac', '1',
                        '-c:a', 'pcm_s16le', os.path.join(OUT, f'music_{name}.wav')], check=True)
        os.remove(tmp)
    old = os.path.join(OUT, 'music.wav')
    if os.path.exists(old):
        os.remove(old)
    print('sounds written to', os.path.abspath(OUT))


if __name__ == '__main__':
    main()
