#!/usr/bin/env python3
"""Procedural sound generator for Untitled.

Every sound is synthesised here (numpy/scipy) or spoken by espeak-ng + MBROLA
(GPL voices, output audio is free to use). No third-party recordings.
Run:  python3 tools/gen_audio.py      -> assets/audio/*.wav
"""
import os
import subprocess
import tempfile
import wave
import numpy as np
from scipy import signal

SR = 44100
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio")
os.makedirs(OUT, exist_ok=True)
R = np.random.default_rng(4242)


def save(name, x, peak=0.9, sr=SR):
    x = np.asarray(x, float)
    m = np.max(np.abs(x)) + 1e-9
    x = x / m * peak
    data = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(data.tobytes())
    print("snd", name, f"{len(x)/sr:.2f}s")


def t(d):
    return np.arange(int(SR * d)) / SR


def noise(d):
    return R.standard_normal(int(SR * d))


def bp(x, lo, hi, order=2):
    sos = signal.butter(order, [lo, hi], "bandpass", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def lp(x, f, order=2):
    sos = signal.butter(order, f, "lowpass", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def hp(x, f, order=2):
    sos = signal.butter(order, f, "highpass", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def env_exp(n, decay):
    return np.exp(-np.arange(n) / SR / decay)


def adsr(n, a=0.01, r=0.05):
    e = np.ones(n)
    na, nr = int(a * SR), int(r * SR)
    if na:
        e[:na] = np.linspace(0, 1, na)
    if nr:
        e[-nr:] *= np.linspace(1, 0, nr)
    return e


def room(x, size=0.25, mix=0.25, damp=3000):
    """Cheap Schroeder-style reverb (parallel combs)."""
    y = np.concatenate([x, np.zeros(int(SR * 1.5))])
    wet = np.zeros_like(y)
    for k in (0.29, 0.37, 0.43, 0.53):
        d = max(1, int(SR * size * k * 0.2))
        a = np.zeros(d + 1)
        a[0] = 1.0
        a[d] = -0.7
        wet += signal.lfilter([1.0], a, y)
    wet = lp(wet, damp)
    return y * (1 - mix) + wet * mix / 4


def loopable(x, fade=0.5):
    """Crossfade tail into head so a loop is seamless."""
    n = int(SR * fade)
    head = x[:n]
    tail = x[-n:]
    w = np.linspace(0, 1, n)
    x = np.copy(x[:-n])
    x[:n] = head * w + tail * (1 - w)
    return x


# ------------------------------------------------------------------ foley
def mix(*arrs):
    n = max(len(a) for a in arrs)
    out = np.zeros(n)
    for a in arrs:
        out[: len(a)] += a
    return out


def thump(freq, d, decay, noise_amt=0.3, nlo=200, nhi=2000):
    tt = t(d)
    body = np.sin(2 * np.pi * freq * tt * (1 - 0.3 * tt / d)) * env_exp(len(tt), decay)
    n = bp(noise(d), nlo, nhi) * env_exp(len(tt), decay * 0.5) * noise_amt
    return body + n


def footsteps():
    for i in range(4):
        r = np.random.default_rng(10 + i)
        # wood: dull thump + small creak
        x = thump(r.uniform(85, 110), 0.28, 0.035, 0.6, 150, 1800)
        x[int(0.02 * SR):] += 0.25 * thump(r.uniform(140, 180), 0.26, 0.02, 0.3)[: len(x) - int(0.02 * SR)]
        save(f"step_wood_{i}", lp(x, 2500), 0.7)
        # tile: harder click
        x = thump(r.uniform(150, 190), 0.2, 0.02, 1.0, 1200, 6000)
        save(f"step_tile_{i}", x, 0.6)
        # grass: soft rustle
        n = bp(noise(0.3), 800, 6000) * env_exp(int(0.3 * SR), 0.06)
        n *= 1 + 0.6 * np.sin(np.linspace(0, r.uniform(20, 40), len(n)))
        save(f"step_grass_{i}", n + 0.4 * thump(70, 0.3, 0.03, 0.0), 0.5)
        # concrete: gritty scuff
        n = bp(noise(0.25), 400, 5000) * env_exp(int(0.25 * SR), 0.03)
        save(f"step_concrete_{i}", n + 0.6 * thump(r.uniform(90, 120), 0.25, 0.025, 0.2), 0.6)
        # heavier, slower steps used by the "someone walking" event
        x = thump(r.uniform(70, 90), 0.4, 0.05, 0.5, 120, 1500)
        creak = np.sin(2 * np.pi * np.cumsum(np.linspace(r.uniform(300, 500), r.uniform(250, 400), int(0.25 * SR))) / SR)
        creak *= adsr(len(creak), 0.05, 0.1) * 0.08 * r.uniform(0.3, 1.0)
        x[int(0.06 * SR):int(0.06 * SR) + len(creak)] += creak
        save(f"step_heavy_{i}", lp(x, 1800), 0.8)


def creak(d, f0, f1, rough=0.6, seed=0):
    r = np.random.default_rng(seed)
    n = int(d * SR)
    f = np.linspace(f0, f1, n) * (1 + 0.04 * np.sin(np.linspace(0, r.uniform(20, 60), n)))
    ph = np.cumsum(f) / SR
    # stick-slip: pulse train with jitter
    saw = (ph % 1.0) ** 6
    saw *= 1 + rough * r.standard_normal(n) * 0.3
    x = bp(saw, 200, 3000)
    am = np.abs(np.sin(np.linspace(0, r.uniform(3, 8), n))) ** 0.5
    return x * am * adsr(n, 0.05, 0.15)


def doors():
    x = creak(0.9, 180, 120, seed=1)
    latch = thump(900, 0.08, 0.01, 1.0, 2000, 8000)
    open_ = np.concatenate([latch * 0.8, np.zeros(int(0.03 * SR))])
    open_ = np.concatenate([open_, x * 0.35])
    save("door_open", room(open_, 0.2, 0.2), 0.7)
    close = creak(0.4, 140, 110, seed=2) * 0.3
    slam = mix(thump(70, 0.35, 0.06, 0.8, 100, 1500), 0.6 * thump(1100, 0.1, 0.012, 1.0, 2500, 9000))
    close = np.concatenate([close, slam])
    save("door_close", room(close, 0.2, 0.25), 0.8)
    save("door_creak", room(creak(1.6, 260, 190, seed=3), 0.25, 0.3), 0.5)
    save("knock", room(thump(120, 0.3, 0.03, 0.7, 300, 3000), 0.18, 0.3), 0.9)
    # fridge door suck/thud
    save("fridge_open", np.concatenate([bp(noise(0.12), 300, 3000) * env_exp(int(0.12 * SR), 0.03), np.zeros(1000)]), 0.4)
    save("fridge_close", thump(60, 0.3, 0.04, 0.6, 100, 1200), 0.6)
    # garage door rumble (loopable)
    tt = t(4.0)
    rum = lp(noise(4.0), 300) * (1 + 0.3 * np.sin(2 * np.pi * 7 * tt)) + 0.2 * bp(noise(4.0), 1500, 4000) * (np.sin(2 * np.pi * 11 * tt) > 0.7)
    save("garage_door", loopable(rum), 0.6)


def clicks():
    x = mix(thump(2500, 0.05, 0.004, 1.0, 3000, 10000), 0.6 * thump(1200, 0.06, 0.008, 0.6))
    save("switch_click", x, 0.6)
    for i in range(3):
        save(f"key_{i}", thump(1800 + i * 300, 0.05, 0.006, 1.0, 2000, 9000), 0.4)
    save("phone_pickup", np.concatenate([thump(400, 0.1, 0.02, 1.0, 600, 5000), np.zeros(800), thump(900, 0.08, 0.01, 0.8, 1500, 7000)]), 0.6)
    save("phone_hangup", thump(300, 0.25, 0.03, 0.8, 300, 4000), 0.7)
    save("thud", thump(90, 0.35, 0.05, 0.6, 100, 2000), 0.7)
    save("tick", thump(3000, 0.03, 0.003, 1.0, 3000, 9000), 0.5)
    # paper rustle
    n = bp(noise(0.5), 1500, 9000) * (np.abs(lp(noise(0.5), 30)) * 6)
    save("paper", n * adsr(len(n), 0.02, 0.1), 0.4)


def phone():
    # classic electromechanical bell: two bells hammered at 20Hz for 2s
    d = 2.0
    tt = t(d)
    strikes = np.zeros(len(tt))
    for k in range(int(d * 20)):
        i = int(k / 20 * SR)
        strikes[i] = 1.0 if k % 2 == 0 else 0.8
    bell = np.zeros(len(tt))
    for f, a in ((1020, 1.0), (1530, 0.5), (2710, 0.3), (720, 0.4)):
        ir = np.sin(2 * np.pi * f * t(0.25)) * env_exp(int(0.25 * SR), 0.08) * a
        bell += signal.fftconvolve(strikes, ir)[: len(tt)]
    bell = np.concatenate([bell, np.zeros(int(0.3 * SR))])
    bell = room(bell, 0.2, 0.2)
    save("phone_ring", bell, 0.9)
    # line hiss (loop)
    h = bp(noise(6), 300, 3400) * 0.15 + 0.02 * np.sin(2 * np.pi * 60 * t(6))
    save("line_hiss", loopable(h), 0.15)
    # dial tone 350+440
    dt = np.sin(2 * np.pi * 350 * t(3)) + np.sin(2 * np.pi * 440 * t(3))
    save("dial_tone", bp(dt, 300, 3400) * adsr(len(dt), 0.01, 0.01), 0.25)


def _speak(voice, speed, text):
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tf:
        path = tf.name
    try:
        subprocess.run(["espeak-ng", "-v", voice, "-s", str(speed), "-p", "40", text, "-w", path], check=True,
                       capture_output=True)
        with wave.open(path) as w:
            sr = w.getframerate()
            x = np.frombuffer(w.readframes(w.getnframes()), np.int16).astype(float) / 32768
    except Exception as e:  # pragma: no cover
        print("espeak failed", e)
        return np.zeros(SR)
    return signal.resample(x, int(len(x) * SR / sr))


def voices():
    """Voice lines via espeak-ng + MBROLA, assembled phrase by phrase with real
    pauses, then degraded to telephone quality (or distance)."""
    lines = {
        # name: (voice, speed, [(text, pause_after_seconds), ...])
        "voice_time": ("mb-us2", 125, [("Hi.", 1.6), ("Sorry.", 0.5), ("What time do you have?", 3.2), ("Okay.", 0.9), ("Thank you.", 0.6)]),
        "voice_wrong": ("mb-us1", 145, [("Hey.", 0.4), ("Is Dana there?", 2.6), ("Oh.", 0.8), ("Sorry. I think I have the wrong number.", 0.6)]),
        "voice_spell": ("mb-us3", 100, [("E.", 1.1), ("X.", 1.1), ("I.", 1.1), ("T.", 0.5)]),
        "voice_hello": ("mb-us2", 140, [("Hello?", 0.3)]),
    }
    for name, (voice, speed, parts) in lines.items():
        chunks = []
        for text, pause in parts:
            chunks.append(_speak(voice, speed, text))
            chunks.append(np.zeros(int(pause * SR)))
        x = np.concatenate(chunks)
        if name == "voice_spell":
            x = lp(x, 900, 4)
            x = room(x, 0.6, 0.6, 1500)
            save(name, x, 0.6)
        else:
            x = bp(x, 350, 3200, 4)
            x = np.tanh(x * 3) * 0.6
            x = x + bp(R.standard_normal(len(x)), 300, 3400) * 0.01
            save(name, x, 0.7)


# ------------------------------------------------------------------ ambience
def ambience():
    # crickets: several chirping insects at different rates
    d = 12.0
    tt = t(d)
    x = np.zeros(len(tt))
    for k in range(7):
        r = np.random.default_rng(500 + k)
        f = r.uniform(3800, 5200)
        rate = r.uniform(1.2, 3.0)
        pulses = (np.sin(2 * np.pi * 30 * tt) > 0.2).astype(float)
        gate = (np.sin(2 * np.pi * rate * tt + r.uniform(0, 6)) > 0.55).astype(float)
        gate = lp(gate, 40)
        x += np.sin(2 * np.pi * f * tt) * pulses * gate * r.uniform(0.2, 1.0)
    x += bp(noise(d), 2000, 8000) * 0.02
    save("crickets", loopable(lp(x, 7000)), 0.4)
    # wind bed
    d = 20.0
    n = noise(d)
    mod = lp(np.abs(noise(d)), 0.3)
    mod = mod / mod.max()
    w = bp(n, 150, 900) * (0.3 + mod) + bp(n, 900, 2500) * mod * 0.2
    save("wind", loopable(w, 1.5), 0.5)
    # gust
    d = 5.0
    e = np.sin(np.linspace(0, np.pi, int(d * SR))) ** 2
    g = bp(noise(d), 200, 1500) * e + bp(noise(d), 1500, 4000) * e ** 3 * 0.3
    save("wind_gust", g, 0.6)
    # distant traffic hum
    d = 16.0
    tr = lp(noise(d), 180) + 0.3 * bp(noise(d), 300, 800) * (0.5 + 0.5 * np.sin(2 * np.pi * 0.07 * t(d)))
    save("distant_traffic", loopable(tr, 1.5), 0.3)
    # leaves rustle loop (for trees)
    d = 8.0
    lr = bp(noise(d), 2000, 9000) * (lp(np.abs(noise(d)), 2) * 8)
    save("leaves", loopable(lr), 0.3)


def appliances():
    d = 8.0
    tt = t(d)
    hum = 0.5 * np.sin(2 * np.pi * 60 * tt) + 0.3 * np.sin(2 * np.pi * 120 * tt) + 0.15 * np.sin(2 * np.pi * 180 * tt)
    hum += 0.08 * lp(noise(d), 400)
    save("fridge_hum", loopable(hum), 0.3)
    st = np.concatenate([thump(55, 0.5, 0.12, 0.8, 60, 600), np.zeros(int(0.1 * SR))])
    save("fridge_clunk", st, 0.6)
    # computer hum + fan
    comp = 0.3 * np.sin(2 * np.pi * 120 * tt) + lp(noise(d), 1200) * 0.4 + 0.05 * np.sin(2 * np.pi * 15734 * tt)
    save("computer_hum", loopable(comp), 0.2)
    # CRT power on: thunk + rising whine
    on = thump(80, 0.4, 0.08, 0.5)
    wh = np.sin(2 * np.pi * np.cumsum(np.linspace(2000, 15000, int(0.6 * SR))) / SR) * 0.05
    on = np.concatenate([on, np.zeros(int(0.2 * SR))])
    on[: len(wh)] += wh
    save("crt_on", on, 0.6)
    off = thump(140, 0.3, 0.04, 0.4, 2000, 8000)
    save("crt_off", off, 0.5)
    # tv static (loop)
    st = bp(noise(6), 300, 9000) * 0.6 + 0.02 * np.sin(2 * np.pi * 15734 * t(6))
    save("tv_static", loopable(st), 0.4)
    # tv tone (no signal)
    tone = np.sin(2 * np.pi * 1000 * t(4)) * 0.3
    save("tv_tone", loopable(tone, 0.2), 0.25)
    # faucet water loop
    wa = bp(noise(6), 500, 8000) * (0.8 + 0.2 * lp(noise(6), 8))
    save("water", loopable(wa), 0.4)
    # street lamp buzz
    bz = signal.sawtooth(2 * np.pi * 120 * t(4)) * 0.2 + 0.05 * bp(noise(4), 3000, 6000)
    save("lamp_buzz", loopable(lp(bz, 2000)), 0.15)
    # clock tick-tock 2 s loop
    tk = np.zeros(int(2 * SR))
    a = thump(3200, 0.03, 0.003, 1.0, 3000, 9000)
    b = thump(2600, 0.03, 0.003, 1.0, 2500, 8000)
    tk[: len(a)] += a
    tk[SR: SR + len(b)] += b * 0.8
    save("clock_tick", tk, 0.3)
    # house settling creaks
    for i in range(4):
        r = np.random.default_rng(700 + i)
        c = creak(r.uniform(0.3, 1.2), r.uniform(120, 300), r.uniform(80, 250), seed=700 + i)
        save(f"house_creak_{i}", room(c, 0.3, 0.4), 0.4)
    # pipes knocking (very normal in old houses)
    p = np.zeros(int(1.2 * SR))
    for k, tm in enumerate((0.0, 0.18, 0.31)):
        th = thump(200 + k * 20, 0.25, 0.03, 0.6, 300, 3000)
        i = int(tm * SR)
        p[i:i + len(th)] += th * (1 - k * 0.2)
    save("pipes", room(p, 0.25, 0.4), 0.4)


def vehicles():
    d = 6.0
    tt = t(d)
    f0 = 32
    eng = np.zeros(len(tt))
    for h, a in ((1, 1.0), (2, 0.6), (3, 0.35), (4, 0.25), (6, 0.12)):
        eng += a * np.sin(2 * np.pi * f0 * h * tt + 0.3 * np.sin(2 * np.pi * 0.7 * tt))
    eng *= 1 + 0.15 * np.sin(2 * np.pi * f0 / 2 * tt)
    eng += lp(noise(d), 500) * 0.4
    tyre = bp(noise(d), 300, 2000) * 0.15
    save("car_engine", loopable(lp(eng, 900) + tyre), 0.6)
    idle = np.zeros(len(tt))
    for h, a in ((1, 1.0), (2, 0.5), (3, 0.3)):
        idle += a * np.sin(2 * np.pi * 24 * h * tt)
    idle *= 1 + 0.25 * np.sin(2 * np.pi * 12 * tt)
    save("car_idle", loopable(lp(idle + lp(noise(d), 300) * 0.3, 600)), 0.5)
    # distant car pass (pre-panned in time, no doppler needed)
    d = 9.0
    tt = t(d)
    e = np.exp(-((tt - d / 2) ** 2) / (2 * 1.4 ** 2))
    f = 40 * (1 + 0.08 * np.tanh((d / 2 - tt) * 1.5))
    ph = np.cumsum(f) / SR
    car = (np.sin(2 * np.pi * ph) + 0.5 * np.sin(4 * np.pi * ph)) * 0.5 + bp(noise(d), 200, 1800) * 0.6
    save("car_pass", lp(car, 1500) * e, 0.6)
    # car door
    save("car_door", room(thump(70, 0.4, 0.05, 0.9, 100, 2000), 0.3, 0.3), 0.7)


def animals():
    # dog bark: pitched harmonic burst through formants
    for i in range(4):
        r = np.random.default_rng(900 + i)
        barks = []
        for k in range(r.integers(1, 4)):
            d = r.uniform(0.14, 0.24)
            tt = t(d)
            f = np.linspace(r.uniform(480, 620), r.uniform(280, 360), len(tt))
            ph = np.cumsum(f) / SR
            src = signal.sawtooth(2 * np.pi * ph) + 0.4 * noise(d)
            v = bp(src, 500, 900) + 0.7 * bp(src, 1100, 1700) + 0.3 * bp(src, 2300, 3000)
            v *= np.sin(np.linspace(0, np.pi, len(tt))) ** 0.6
            barks.append(v)
            barks.append(np.zeros(int(r.uniform(0.18, 0.35) * SR)))
        x = np.concatenate(barks)
        x = room(lp(x, 2500), 0.7, 0.5, 1800)
        save(f"dog_bark_{i}", x, 0.6)
    # owl: two soft hoots
    out = []
    for k, (f, d) in enumerate(((380, 0.35), (360, 0.2), (370, 0.6))):
        tt = t(d)
        v = np.sin(2 * np.pi * f * tt * (1 - 0.05 * tt)) * np.sin(np.linspace(0, np.pi, len(tt)))
        out += [v, np.zeros(int(0.25 * SR))]
    save("owl", room(np.concatenate(out), 0.8, 0.5, 1500), 0.4)
    # distant train horn? no - keep the neighbourhood small. Wind chime instead.
    ch = np.zeros(int(4 * SR))
    for k in range(6):
        r = np.random.default_rng(950 + k)
        f = r.choice([1318, 1568, 1760, 2093, 2349])
        tm = r.uniform(0, 2.5)
        n = int(1.5 * SR)
        tone = (np.sin(2 * np.pi * f * t(1.5)) + 0.3 * np.sin(2 * np.pi * f * 2.76 * t(1.5))) * env_exp(n, 0.4)
        i = int(tm * SR)
        ch[i:i + n] += tone * r.uniform(0.3, 1.0)
    save("wind_chime", ch, 0.3)


if __name__ == "__main__":
    import sys
    if len(sys.argv) > 1:
        for fn in sys.argv[1:]:
            globals()[fn]()
        sys.exit(0)
    footsteps()
    doors()
    clicks()
    phone()
    voices()
    ambience()
    appliances()
    vehicles()
    animals()
