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
    """Every file is peak-normalised to -1 dBFS. Levels are set by the mixer in
    the engine (AudioManager.MIX), never by baking quiet files."""
    x = np.asarray(x, float)
    x = x - np.mean(x)
    m = np.max(np.abs(x)) + 1e-9
    x = x / m * 0.89
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


# ------------------------------------------------------------------ horror
def _env(n, a, d):
    """attack/decay envelope in seconds."""
    e = np.ones(n)
    na = max(1, int(a * SR))
    e[:na] = np.linspace(0, 1, na) ** 0.5
    e[na:] = np.exp(-np.arange(n - na) / SR / d)
    return e


def horror():
    # stingers: a sharp transient (the jolt), a sub drop (the weight) and a
    # dissonant metallic screech that decays into reverb (the after-image)
    for i in range(3):
        r = np.random.default_rng(1300 + i)
        d = 3.2
        tt = t(d)
        n = len(tt)
        sub = np.sin(2 * np.pi * np.cumsum(np.linspace(r.uniform(70, 90), 28, n)) / SR) * _env(n, 0.004, 0.55)
        crack = hp(noise(d), 1500) * _env(n, 0.001, 0.05)
        scr = np.zeros(n)
        for k in range(5):
            f0 = r.uniform(600, 1900)
            f = f0 * (1 - 0.25 * tt / d) * (1 + 0.012 * np.sin(2 * np.pi * r.uniform(5, 11) * tt))
            scr += signal.sawtooth(2 * np.pi * np.cumsum(f) / SR) * r.uniform(0.4, 1.0)
        scr = bp(scr, 700, 4500) * _env(n, 0.01, r.uniform(0.5, 0.9))
        body = bp(noise(d), 80, 400) * _env(n, 0.003, 0.25)
        x = sub * 1.0 + crack * 0.9 + scr * 0.45 + body * 0.6
        x = np.tanh(x * 1.6)
        save(f"stinger_{i}", room(x, 0.6, 0.35, 3500)[: int(4.2 * SR)])
    # short shriek for the TV / behind-you scares
    d = 1.1
    tt = t(d)
    f = 900 + 500 * np.sin(2 * np.pi * 7 * tt) + 300 * tt
    src = signal.sawtooth(2 * np.pi * np.cumsum(f) / SR) + 0.8 * noise(d)
    v = bp(src, 900, 1400) + 0.8 * bp(src, 2200, 3200) + 0.4 * bp(src, 3500, 5000)
    v = np.tanh(v * 3) * _env(len(tt), 0.005, 0.5)
    save("shriek", room(v, 0.4, 0.3))
    # TV scare burst: crushed static + shriek + sub
    d = 1.4
    st = np.sign(noise(d)) * 0.6 + bp(noise(d), 200, 8000)
    burst = st * _env(len(st), 0.002, 0.6)
    burst[: int(1.1 * SR)] += v[: int(1.1 * SR)] * 0.8
    burst += np.sin(2 * np.pi * 45 * t(d)) * _env(len(st), 0.003, 0.4)
    save("tv_scare", np.tanh(burst * 1.5))
    # breathing very close: slow inhale / exhale through the nose and mouth
    parts = []
    for k in range(3):
        r = np.random.default_rng(1400 + k)
        for kind, dur in (("in", r.uniform(1.1, 1.5)), ("out", r.uniform(1.4, 1.9))):
            n = int(dur * SR)
            e = np.sin(np.linspace(0, np.pi, n)) ** (1.6 if kind == "in" else 1.1)
            nz = noise(dur)
            lo, hi = (500, 2600) if kind == "in" else (250, 1500)
            b = bp(nz, lo, hi) + 0.3 * bp(nz, 2500, 5000) * (1 if kind == "in" else 0.3)
            b *= e * (1 + 0.15 * np.sin(np.linspace(0, r.uniform(10, 25), n)))
            parts += [b, np.zeros(int(r.uniform(0.15, 0.45) * SR))]
    save("breath_close", np.concatenate(parts))
    # whisper: noisy formant syllables, unintelligible
    d = 2.6
    n = int(d * SR)
    w = np.zeros(n)
    pos = 0
    r = np.random.default_rng(1500)
    while pos < n - int(0.3 * SR):
        sl = int(r.uniform(0.12, 0.3) * SR)
        f1, f2 = r.uniform(300, 800), r.uniform(1100, 2600)
        nz = R.standard_normal(sl)
        syl = bp(nz, f1 * 0.8, f1 * 1.2) + bp(nz, f2 * 0.85, f2 * 1.15) + 0.4 * hp(nz, 4000)
        w[pos:pos + sl] += syl * np.sin(np.linspace(0, np.pi, sl))
        pos += sl + int(r.uniform(0.03, 0.15) * SR)
    save("whisper", room(w, 0.3, 0.3))
    # palm slamming against a window: thump + glass ring + rattle
    d = 2.2
    tt = t(d)
    n = len(tt)
    thump_ = thump(85, d, 0.08, 0.9, 150, 2500)
    ring = np.zeros(n)
    for f, a in ((1830, 1.0), (2710, 0.7), (4120, 0.5), (5630, 0.3)):
        ring += np.sin(2 * np.pi * f * tt) * a * _env(n, 0.001, 0.35)
    rattle = bp(noise(d), 2000, 7000) * (np.abs(np.sin(2 * np.pi * 31 * tt)) > 0.9) * _env(n, 0.001, 0.18)
    save("window_bang", room(thump_ + ring * 0.25 + rattle * 0.5, 0.3, 0.25))
    # hard banging on a door (heavier than the polite knock)
    out = np.zeros(int(2.4 * SR))
    for k, tm in enumerate((0.0, 0.55, 1.1)):
        th = thump(65, 0.6, 0.07, 1.0, 100, 2500) + 0.4 * thump(140, 0.6, 0.03, 0.6)
        i0 = int(tm * SR)
        out[i0:i0 + len(th)] += th[: len(out) - i0]
    save("bang_door", room(out, 0.35, 0.35))
    # distant chanting: layered slow syllables in a minor drone, far away
    voices_ = []
    for k, (voice, pitch) in enumerate((("mb-us1", "20"), ("mb-us3", "15"), ("mb-us2", "28"))):
        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tf:
            path = tf.name
        try:
            subprocess.run(["espeak-ng", "-v", voice, "-s", "70", "-p", pitch, "-a", "120",
                            " ".join(["oh. ah. veh. nee. oh. ah. leh. oh."] * 4), "-w", path], check=True, capture_output=True)
            with wave.open(path) as wv:
                sr = wv.getframerate()
                x = np.frombuffer(wv.readframes(wv.getnframes()), np.int16).astype(float) / 32768
            x = signal.resample(x, int(len(x) * SR / sr))
        except Exception:
            x = np.zeros(SR * 8)
        voices_.append(x)
    L = max(len(v_) for v_ in voices_) + SR
    mix_ = np.zeros(L)
    for k, v_ in enumerate(voices_):
        off = int(k * 0.07 * SR)
        mix_[off:off + len(v_)] += v_
    dr = np.zeros(L)
    tt = np.arange(L) / SR
    for f in (73.4, 87.3, 110.0):
        dr += signal.sawtooth(2 * np.pi * f * tt) * 0.15
    mix_ = lp(mix_ + lp(dr, 600) * 0.4, 1100, 4)
    mix_ = room(mix_, 0.9, 0.6, 1200)
    save("chant_far", loopable(mix_, 1.0))
    # slow low swell (tension, used sparingly before something happens)
    d = 9.0
    tt = t(d)
    sw = (np.sin(2 * np.pi * 41 * tt) + 0.6 * np.sin(2 * np.pi * 43.3 * tt) + 0.3 * lp(noise(d), 120))
    sw *= np.sin(np.linspace(0, np.pi, len(tt))) ** 2
    save("drone_swell", sw)
    # quick footsteps of something running (barefoot, heavy)
    out = np.zeros(int(1.6 * SR))
    for k in range(6):
        th = thump(75, 0.25, 0.03, 0.7, 120, 1800)
        i0 = int(k * 0.19 * SR)
        out[i0:i0 + len(th)] += th[: len(out) - i0] * (0.6 + 0.08 * k)
    save("run_steps", room(out, 0.3, 0.3))
    # electrical crackle / buzz
    d = 6.0
    tt = t(d)
    bz = signal.sawtooth(2 * np.pi * 60 * tt) * 0.3 + 0.2 * signal.square(2 * np.pi * 120 * tt)
    crk = (R.random(len(tt)) > 0.9995).astype(float)
    crk = signal.lfilter([1.0], [1, -0.97], crk) * hp(noise(d), 2000)
    save("elec_buzz", loopable(lp(bz, 3000) * 0.4 + crk * 0.8, 0.3))
    # heartbeat (only after something happened, very low)
    out = np.zeros(int(1.0 * SR))
    for tm, a in ((0.0, 1.0), (0.24, 0.7)):
        th = thump(48, 0.3, 0.06, 0.1, 40, 200)
        i0 = int(tm * SR)
        out[i0:i0 + len(th)] += th[: len(out) - i0] * a
    save("heartbeat", out)


# ------------------------------------------------------------------ chores / locks
def chores():
    lc = mix(thump(2600, 0.06, 0.004, 1.0, 2500, 9000), np.concatenate([np.zeros(int(0.05 * SR)), thump(1600, 0.08, 0.008, 1.0, 1500, 7000)]))
    save("lock_click", lc)
    out = np.zeros(int(0.7 * SR))
    for k in range(5):
        th = thump(r_ := 1200 + k * 90, 0.06, 0.006, 1.0, 1500, 8000)
        i0 = int(k * 0.09 * SR)
        out[i0:i0 + len(th)] += th[: len(out) - i0]
    out += np.concatenate([thump(95, 0.3, 0.04, 0.5)[: int(0.3 * SR)], np.zeros(len(out) - int(0.3 * SR))])
    save("door_rattle", room(out, 0.2, 0.2))
    # ceramic clinks
    for i in range(3):
        r = np.random.default_rng(1600 + i)
        d = 0.6
        tt = t(d)
        x = np.zeros(len(tt))
        for f in (r.uniform(2200, 3200), r.uniform(4100, 5200), r.uniform(6500, 7500)):
            x += np.sin(2 * np.pi * f * tt) * _env(len(tt), 0.001, r.uniform(0.05, 0.15))
        save(f"dish_{i}", x + 0.2 * hp(noise(d), 3000) * _env(len(tt), 0.001, 0.01))
    # scrubbing under water
    d = 2.0
    sc = bp(noise(d), 800, 6000) * (0.5 + 0.5 * np.abs(np.sin(2 * np.pi * 3.2 * t(d))))
    save("scrub", sc * np.sin(np.linspace(0, np.pi, len(sc))) ** 0.3)
    # plastic bag rustle
    d = 1.4
    rs = hp(noise(d), 1500) * (lp(np.abs(noise(d)), 25) * 5) ** 2
    save("trash_bag", rs * adsr(len(rs), 0.05, 0.2))
    save("bin_lid", room(thump(110, 0.5, 0.05, 0.9, 200, 3000), 0.3, 0.2))
    # mailbox: little metal creak + clank
    cr = creak(0.5, 900, 700, 0.3, 77) * 0.6
    save("mailbox", np.concatenate([cr, thump(500, 0.25, 0.02, 1.0, 1000, 6000)]))
    # sash window sliding
    d = 0.9
    sl = bp(noise(d), 300, 2500) * (0.6 + 0.4 * np.sin(np.linspace(0, 30, int(d * SR))) ** 2) * adsr(int(d * SR), 0.05, 0.15)
    save("window_slide", np.concatenate([sl, thump(140, 0.25, 0.03, 0.6)]))
    # stove knob + burner going out
    save("stove_knob", np.concatenate([thump(1800, 0.05, 0.005, 1.0, 2000, 8000), bp(noise(0.5), 200, 2000) * _env(int(0.5 * SR), 0.01, 0.12)]))
    d = 4.0
    save("gas_hiss", loopable(bp(noise(d), 1500, 7000) * 0.5 + lp(noise(d), 300) * 0.3, 0.5))
    # things falling over somewhere
    out = np.zeros(int(1.6 * SR))
    for k, tm in enumerate((0.0, 0.12, 0.31, 0.5)):
        th = thump(np.random.default_rng(k).uniform(120, 400), 0.4, 0.04, 1.0, 400, 5000)
        i0 = int(tm * SR)
        out[i0:i0 + len(th)] += th[: len(out) - i0] * (1 - k * 0.2)
    save("object_fall", room(out, 0.3, 0.3))


# ------------------------------------------------------------------ the tape / endings
def endings():
    # VHS playback hiss: tape noise, a faint 15.7 kHz-ish whine folded down, motor hum
    d = 6.0
    tt = t(d)
    hiss = bp(noise(d), 1200, 9000) * 0.5 + lp(noise(d), 400) * 0.15
    hum = np.sin(2 * np.pi * 60 * tt) * 0.05 + np.sin(2 * np.pi * 120 * tt) * 0.03
    flutter = 1 + 0.08 * np.sin(2 * np.pi * 0.7 * tt) + 0.05 * np.sin(2 * np.pi * 3.1 * tt)
    save("vhs_hiss", loopable((hiss + hum) * flutter, 0.5))
    # cassette pushed into the deck: plastic slide, clunk, motor spin-up
    slide = bp(noise(0.35), 800, 5000) * _env(int(0.35 * SR), 0.02, 0.15)
    clunk = thump(140, 0.4, 0.05, 0.9, 300, 4000)
    m = t(1.6)
    motor = (signal.sawtooth(2 * np.pi * np.cumsum(np.linspace(30, 95, len(m))) / SR) * 0.25 + bp(noise(1.6), 300, 1800) * 0.2)
    motor *= np.minimum(1, m / 0.2) * np.exp(-np.maximum(0, m - 1.1) * 6)
    out = mix(slide, np.concatenate([np.zeros(int(0.3 * SR)), clunk]), np.concatenate([np.zeros(int(0.55 * SR)), lp(motor, 2500)]))
    save("vhs_insert", room(out, 0.25, 0.2))
    # THE RUN: 0.27 s rising rush, a monstrous impact, a short screech (cut by the game)
    def big_scare(seed, d, rush, scream_hi):
        r = np.random.default_rng(seed)
        n = int(d * SR)
        tt = np.arange(n) / SR
        rise = np.clip(tt / rush, 0, 1) ** 3 * (tt < rush)
        whoosh = bp(noise(d), 300, 6000) * rise * 1.2
        hit = np.zeros(n)
        i0 = int(rush * SR)
        k = n - i0
        kt = np.arange(k) / SR
        sub = np.sin(2 * np.pi * np.cumsum(np.linspace(90, 26, k)) / SR) * np.exp(-kt / 0.6)
        crack = hp(R.standard_normal(k), 900) * np.exp(-kt / 0.06)
        scr = np.zeros(k)
        for j in range(7):
            f0 = r.uniform(500, scream_hi)
            f = f0 * (1 + 0.04 * np.sin(2 * np.pi * r.uniform(6, 13) * kt)) * (1 - 0.15 * kt / max(kt[-1], 1e-3))
            scr += signal.sawtooth(2 * np.pi * np.cumsum(f) / SR) * r.uniform(0.5, 1.0)
        scr = bp(scr, 600, 5200) * (1 - np.exp(-kt / 0.01)) * np.exp(-kt / 0.9)
        body = bp(R.standard_normal(k), 60, 500) * np.exp(-kt / 0.3)
        hit[i0:] = sub * 1.2 + crack * 1.0 + scr * 0.7 + body * 0.8
        x = np.tanh((whoosh + hit) * 2.2)
        return room(x, 0.5, 0.25, 4000)[:n]
    save("tape_scare", big_scare(1700, 3.0, 0.27, 2100))
    save("final_scare", big_scare(1800, 3.0, 0.08, 2400))
    # the mattress taking someone's weight: springs + slow wood creak + fabric
    d = 2.2
    tt = t(d)
    springs = np.zeros(len(tt))
    for f, a in ((310, 1.0), (467, 0.6), (690, 0.4), (1130, 0.25)):
        springs += np.sin(2 * np.pi * f * tt * (1 + 0.01 * np.sin(2 * np.pi * 5 * tt))) * a
    springs *= _env(len(tt), 0.25, 0.35) * 0.25
    cr = creak(1.6, 140, 95, 0.8, 7)
    fabric = bp(noise(d), 1500, 6000) * np.sin(np.linspace(0, np.pi, len(tt))) ** 2 * 0.25
    save("mattress_creak", room(mix(springs, cr * 0.8, fabric), 0.2, 0.15))
    # fingernail taps on glass
    out = np.zeros(int(2.6 * SR))
    for k, tm in enumerate((0.0, 0.9, 1.75)):
        tap = np.zeros(int(0.3 * SR))
        tp = t(0.3)
        for f, a in ((2900, 1.0), (4300, 0.6), (6100, 0.35)):
            tap += np.sin(2 * np.pi * f * tp) * a
        tap = tap * _env(len(tp), 0.0005, 0.03) + hp(noise(0.3), 3000) * _env(len(tp), 0.0005, 0.006) * 0.8
        i0 = int(tm * SR)
        out[i0:i0 + len(tap)] += tap * (0.8 + 0.1 * k)
    save("glass_tap", room(out, 0.25, 0.25))
    # heavy furniture dragged across a wooden floor, somewhere
    d = 2.4
    tt = t(d)
    stick = np.abs(np.sin(2 * np.pi * (14 + 6 * np.sin(2 * np.pi * 0.5 * tt)) * tt)) ** 6
    drag = bp(noise(d), 120, 1400) * (0.4 + stick) + 0.5 * creak(d, 90, 70, 0.9, 9)[: len(tt)]
    drag *= np.sin(np.linspace(0, np.pi, len(tt))) ** 0.5
    save("furniture_drag", room(drag, 0.35, 0.3))
    # something passing very fast: a rush of air
    d = 0.9
    tt = t(d)
    e = np.exp(-((tt - 0.35) / 0.12) ** 2)
    save("whoosh", bp(noise(d), 250, 4000) * e + lp(noise(d), 200) * e * 0.6)


def whisper_tape():
    """'You forgot to check the tape.' Very close, breathy, slow."""
    parts = []
    for voice, pitch, amp in (("en-us+whisper", "30", 1.0), ("en-us+whisperf", "20", 0.45)):
        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tf:
            path = tf.name
        try:
            subprocess.run(["espeak-ng", "-v", voice, "-s", "105", "-p", pitch, "-g", "6",
                            "You forgot to check the tape.", "-w", path], check=True, capture_output=True)
            with wave.open(path) as wv:
                sr = wv.getframerate()
                x = np.frombuffer(wv.readframes(wv.getnframes()), np.int16).astype(float) / 32768
            x = signal.resample(x, int(len(x) * SR / sr))
        except Exception as e:
            print("espeak failed", e)
            x = np.zeros(SR)
        parts.append(x * amp)
    L = max(len(p) for p in parts) + int(0.03 * SR)
    v = np.zeros(L)
    v[: len(parts[0])] += parts[0]
    v[int(0.03 * SR): int(0.03 * SR) + len(parts[1])] += parts[1]
    # breath on the ear: low-frequency proximity rumble + lip noise
    v = v + lp(v, 300) * 0.8
    pre = bp(noise(0.5), 400, 2500) * np.sin(np.linspace(0, np.pi, int(0.5 * SR))) * 0.06
    save("whisper_tape", np.concatenate([pre, v, np.zeros(int(0.3 * SR))]))


def scream():
    """Someone in the bedroom, screaming: a raw, rising, breaking human scream,
    cut off mid-breath, and something heavy hitting the floor."""
    r = np.random.default_rng(3303)
    d = 2.35
    n = int(d * SR)
    tt = np.arange(n) / SR
    # pitch: a gasp that tears up into the scream, wavering, then the voice cracks
    f0 = np.interp(tt, [0, 0.07, 0.3, 0.9, 1.5, 1.72, 1.78, 2.05, d], [330, 420, 760, 820, 880, 900, 1180, 1050, 900])
    jitter = lp(r.standard_normal(n), 30) * 40
    vib = 1 + 0.035 * np.sin(2 * np.pi * 6.3 * tt + 2 * np.sin(2 * np.pi * 0.9 * tt))
    f = (f0 + jitter) * vib
    ph = np.cumsum(f) / SR
    src = signal.sawtooth(2 * np.pi * ph, 0.97)
    # vocal-fold chaos: period doubling and noise, more of it as it breaks
    rough = np.interp(tt, [0, 0.3, 1.5, 1.75, d], [0.1, 0.35, 0.45, 0.9, 0.8])
    src = src * (1 + rough * 0.6 * np.sin(2 * np.pi * ph * 0.5)) + hp(r.standard_normal(n), 900) * rough * 0.35
    # vocal tract: a wide-open "aah"
    v = (bp(src, 850, 1250) * 1.0 + bp(src, 1500, 2000) * 0.8 + bp(src, 2600, 3300) * 0.55
         + bp(src, 3600, 4600) * 0.3 + lp(src, 500) * 0.2)
    amp = np.interp(tt, [0, 0.06, 0.25, 1.6, 1.75, 2.0, 2.08, 2.1, d], [0, 0.35, 1.0, 0.95, 1.0, 1.0, 0.25, 0.0, 0.0])
    v = np.tanh(v * amp * 3.5)
    # the gasp before it
    gasp = bp(r.standard_normal(n), 700, 3500) * np.exp(-((tt - 0.04) / 0.035) ** 2) * 0.5
    # cut off: something heavy hits the floor, wood rattles
    i0 = int(2.09 * SR)
    k = n - i0
    kt = np.arange(k) / SR
    thud = np.sin(2 * np.pi * np.cumsum(np.linspace(85, 40, k)) / SR) * np.exp(-kt / 0.18)
    thud += bp(r.standard_normal(k), 80, 900) * np.exp(-kt / 0.09) * 0.8
    hit = np.zeros(n)
    hit[i0:] = thud * 0.9
    out = room(mix(v, gasp, hit), 0.35, 0.3, 5000)
    save("scream", out)


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
    horror()
    chores()
    endings()
    whisper_tape()
    scream()
