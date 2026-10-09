#!/usr/bin/env python3
"""Procedural texture generator for Untitled.

All textures are generated from scratch (no third-party assets), so the project
has no licensing concerns. Run:  python3 tools/gen_textures.py
Output goes to assets/textures/.
"""
import os
import sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "textures")
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(1977)


def save(name, arr):
    arr = np.clip(arr, 0, 255).astype(np.uint8)
    Image.fromarray(arr).save(os.path.join(OUT, name + ".png"), optimize=True)
    print("tex", name)


def tile_noise(size, scale, octaves=4, seed=0):
    """Tileable value noise in [0,1]."""
    r = np.random.default_rng(seed)
    out = np.zeros((size, size))
    amp = 1.0
    total = 0.0
    for o in range(octaves):
        cells = max(2, int(scale * (2 ** o)))
        grid = r.random((cells, cells))
        # bilinear upsample with wrap
        xs = np.linspace(0, cells, size, endpoint=False)
        x0 = np.floor(xs).astype(int)
        fx = xs - x0
        fx = fx * fx * (3 - 2 * fx)
        x1 = (x0 + 1) % cells
        g00 = grid[np.ix_(x0, x0)]
        g10 = grid[np.ix_(x1, x0)]
        g01 = grid[np.ix_(x0, x1)]
        g11 = grid[np.ix_(x1, x1)]
        fy = fx[:, None]
        fxx = fx[None, :]
        v = (g00 * (1 - fy) * (1 - fxx) + g10 * fy * (1 - fxx) + g01 * (1 - fy) * fxx + g11 * fy * fxx)
        out += v * amp
        total += amp
        amp *= 0.5
    return out / total


def colorize(gray, c0, c1):
    c0 = np.array(c0, float)
    c1 = np.array(c1, float)
    return c0[None, None, :] * (1 - gray[..., None]) + c1[None, None, :] * gray[..., None]


def normal_from_height(h, strength=2.0):
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * strength
    dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * strength
    nz = np.ones_like(h)
    n = np.stack([-dx, dy, nz], -1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    return (n * 0.5 + 0.5) * 255


S = 512

# ---------------------------------------------------------------- wallpapers
def wallpaper_damask():
    y, x = np.mgrid[0:S, 0:S] / S
    n = tile_noise(S, 6, 5, 11)
    base = colorize(n * 0.3 + 0.35, (150, 122, 92), (178, 150, 115))
    # diamond lattice (4 x 4 per tile)
    u = (x * 4) % 1.0
    v = (y * 4) % 1.0
    d = np.abs(u - 0.5) + np.abs(v - 0.5)
    ring = np.exp(-((d - 0.42) ** 2) / 0.0012)
    inner = np.exp(-((d - 0.18) ** 2) / 0.0025) * 0.7
    dot = np.exp(-(d ** 2) / 0.003)
    motif = np.clip(ring + inner + dot, 0, 1)
    img = base * (1 - motif[..., None] * 0.22) + np.array([120, 92, 66])[None, None] * motif[..., None] * 0.08
    # aged vertical streaks
    streak = tile_noise(S, 2, 3, 12)[:, :1].repeat(S, 1).T
    img *= (0.94 + 0.08 * streak[..., None])
    save("wallpaper_damask", img)


def wallpaper_stripe():
    y, x = np.mgrid[0:S, 0:S] / S
    n = tile_noise(S, 8, 4, 21)
    base = colorize(n * 0.25 + 0.4, (128, 140, 118), (150, 160, 136))
    stripe = ((x * 12) % 1.0 < 0.18).astype(float)
    thin = (np.abs((x * 12) % 1.0 - 0.55) < 0.02).astype(float)
    img = base * (1 - stripe[..., None] * 0.1 - thin[..., None] * 0.12)
    save("wallpaper_stripe", img)


def paint(name, c, var=10, seed=0):
    n = tile_noise(S, 10, 5, seed)
    img = np.array(c, float)[None, None] + (n[..., None] - 0.5) * var
    save(name, img)


def ceiling():
    n = rng.random((S, S))
    n = np.array(Image.fromarray((n * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.2))) / 255.0
    img = np.array([205, 198, 186], float)[None, None] + (n[..., None] - 0.5) * 50
    save("ceiling", img)
    save("ceiling_n", normal_from_height(n, 3.0))


# ---------------------------------------------------------------- floors
def wood_floor():
    h = np.zeros((S, S))
    img = np.zeros((S, S, 3))
    plank_h = S // 8
    grain = tile_noise(S, 3, 4, 31)
    y, x = np.mgrid[0:S, 0:S]
    for i in range(8):
        r = np.random.default_rng(100 + i)
        tone = r.uniform(0.75, 1.1)
        off = r.integers(0, S)
        rows = slice(i * plank_h, (i + 1) * plank_h)
        g = np.roll(grain, off, 1)[rows]
        stretched = np.sin((y[rows] * 0.9 + g * 40 + x[rows] * 0.02) * 0.6) * 0.5 + 0.5
        base = colorize(stretched * 0.5 + g * 0.5, (92, 58, 34), (138, 92, 56)) * tone
        img[rows] = base
        h[rows] = 0.6 + g * 0.1
        # plank end joint
        jx = (off + S // 2) % S
        img[rows, max(0, jx - 1):jx + 1] *= 0.45
        h[rows, max(0, jx - 1):jx + 1] = 0.2
        img[i * plank_h, :] *= 0.4
        h[i * plank_h, :] = 0.1
    save("wood_floor", img)
    save("wood_floor_n", normal_from_height(h, 3.0))


def carpet():
    n = rng.random((S, S))
    n = np.array(Image.fromarray((n * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.7))) / 255.0
    big = tile_noise(S, 4, 3, 41)
    img = colorize(n * 0.5 + big * 0.5, (96, 80, 66), (128, 110, 92))
    save("carpet", img)


def tiles(name, count, c_tile, c_grout, grout=0.04, checker=None, var=8, seed=0):
    y, x = np.mgrid[0:S, 0:S] / S
    u = (x * count) % 1.0
    v = (y * count) % 1.0
    tx = np.floor(x * count).astype(int)
    ty = np.floor(y * count).astype(int)
    edge = np.minimum(np.minimum(u, 1 - u), np.minimum(v, 1 - v))
    g = (edge < grout).astype(float)
    n = tile_noise(S, 8, 4, seed)
    tile_col = np.array(c_tile, float)[None, None].repeat(S, 0).repeat(S, 1)
    if checker is not None:
        mask = ((tx + ty) % 2 == 1)
        tile_col[mask] = np.array(checker, float)
    r = np.random.default_rng(seed)
    per = r.uniform(-var, var, (count, count))
    tile_col += per[ty % count, tx % count][..., None]
    tile_col += (n[..., None] - 0.5) * var
    img = tile_col * (1 - g[..., None]) + np.array(c_grout, float)[None, None] * g[..., None]
    h = 1.0 - g * 0.8 - np.clip(grout * 2 - edge, 0, 1) * 2
    save(name, img)
    save(name + "_n", normal_from_height(h, 2.5))


# ---------------------------------------------------------------- materials
def wood_furniture(name, c0, c1, seed):
    y, x = np.mgrid[0:S, 0:S]
    g = tile_noise(S, 3, 5, seed)
    rings = np.sin((x * 0.05 + g * 30)) * 0.5 + 0.5
    img = colorize(rings * 0.6 + g * 0.4, c0, c1)
    save(name, img)


def fabric(name, c, seed):
    y, x = np.mgrid[0:S, 0:S]
    weave = (np.sin(x * 1.6) * np.sin(y * 1.6)) * 0.5 + 0.5
    n = tile_noise(S, 6, 4, seed)
    img = np.array(c, float)[None, None] * (0.85 + 0.15 * weave[..., None]) * (0.9 + 0.2 * n[..., None])
    save(name, img)


def siding(name, c, seed):
    y, x = np.mgrid[0:S, 0:S] / S
    boards = 10
    v = (y * boards) % 1.0
    h = v  # lap siding: ramp per board
    shade = 0.78 + 0.25 * v
    n = tile_noise(S, 6, 4, seed)
    img = np.array(c, float)[None, None] * shade[..., None] * (0.92 + 0.12 * n[..., None])
    lip = (v > 0.96).astype(float)
    img *= (1 - lip[..., None] * 0.35)
    save(name, img)
    save(name + "_n", normal_from_height(h * 0.5, 4.0))


def shingles():
    y, x = np.mgrid[0:S, 0:S] / S
    rows = 12
    ry = np.floor(y * rows).astype(int)
    v = (y * rows) % 1.0
    shift = (ry % 2) * 0.5 / 6
    u = ((x + shift) * 6) % 1.0
    r = np.random.default_rng(7)
    tone = r.uniform(0.7, 1.15, (rows, 6))
    col_idx = np.floor(((x + shift) * 6) % 6).astype(int)
    t = tone[ry % rows, col_idx % 6]
    n = rng.random((S, S)) * 0.25
    base = np.array([62, 58, 56], float)[None, None] * (t[..., None] * (0.85 + n[..., None]))
    gap = (u < 0.025).astype(float)
    base *= (1 - gap[..., None] * 0.5) * (0.75 + 0.3 * v[..., None])
    h = v * 0.5 - gap * 0.3
    save("shingles", base)
    save("shingles_n", normal_from_height(h, 3.0))


def brick():
    y, x = np.mgrid[0:S, 0:S] / S
    rows = 16
    ry = np.floor(y * rows).astype(int)
    v = (y * rows) % 1.0
    shift = (ry % 2) * 0.5 / 4
    u = ((x + shift) * 4) % 1.0
    mortar = ((v < 0.12) | (u < 0.03)).astype(float)
    r = np.random.default_rng(9)
    tone = r.uniform(0.75, 1.15, (rows, 4))
    t = tone[ry % rows, np.floor(((x + shift) * 4) % 4).astype(int)]
    n = tile_noise(S, 16, 4, 91)
    b = np.array([128, 66, 50], float)[None, None] * t[..., None] * (0.85 + 0.3 * n[..., None])
    img = b * (1 - mortar[..., None]) + np.array([150, 144, 134])[None, None] * mortar[..., None]
    save("brick", img)
    save("brick_n", normal_from_height(1 - mortar * 0.6, 3.0))


def grass():
    n1 = tile_noise(S, 4, 5, 51)
    blades = rng.random((S, S))
    blades = np.array(Image.fromarray((blades * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.6))) / 255.0
    img = colorize(n1 * 0.6 + blades * 0.4, (36, 48, 26), (72, 88, 44))
    save("grass", img)


def asphalt():
    n = rng.random((S, S))
    big = tile_noise(S, 5, 4, 61)
    img = colorize(n * 0.35 + big * 0.65, (38, 38, 40), (70, 70, 72))
    # cracks
    im = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8))
    d = ImageDraw.Draw(im)
    r = np.random.default_rng(62)
    for _ in range(6):
        px, py = r.integers(0, S, 2)
        for _ in range(30):
            nx, ny = px + r.integers(-12, 13), py + r.integers(-12, 13)
            d.line([(px, py), (nx, ny)], fill=(28, 28, 30), width=1)
            px, py = nx % S, ny % S
    save("asphalt", np.array(im).astype(float))


def concrete(name, c, seed, joints=0):
    n = tile_noise(S, 8, 5, seed)
    sp = rng.random((S, S))
    img = np.array(c, float)[None, None] * (0.85 + 0.2 * n[..., None] + 0.06 * sp[..., None])
    if joints:
        img[: 2, :] *= 0.55
        img[:, : 2] *= 0.55
    save(name, img)


def fence():
    y, x = np.mgrid[0:S, 0:S] / S
    boards = 8
    u = (x * boards) % 1.0
    bi = np.floor(x * boards).astype(int)
    g = tile_noise(S, 3, 4, 71)
    grain = np.sin(y[:, :] * 200 + g * 20) * 0.5 + 0.5
    r = np.random.default_rng(72)
    tone = r.uniform(0.8, 1.1, boards)[bi % boards]
    img = colorize(grain * 0.4 + g * 0.6, (82, 64, 46), (122, 98, 72)) * tone[..., None]
    gap = (u < 0.03).astype(float)
    img *= (1 - gap[..., None] * 0.7)
    save("fence", img)


def mulch():
    n = rng.random((S, S))
    n = np.array(Image.fromarray((n * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.5))) / 255.0
    img = colorize(n, (40, 26, 18), (90, 60, 38))
    save("mulch", img)


def leaves():
    n = tile_noise(S, 10, 4, 81)
    sp = rng.random((S, S))
    img = colorize(n * 0.7 + sp * 0.3, (22, 34, 18), (58, 74, 36))
    save("leaves", img)


def bark():
    y, x = np.mgrid[0:S, 0:S] / S
    g = tile_noise(S, 6, 5, 85)
    ridges = np.abs(np.sin(x * 40 + g * 8))
    img = colorize(ridges * 0.6 + g * 0.4, (40, 32, 26), (88, 74, 60))
    save("bark", img)
    save("bark_n", normal_from_height(ridges, 2.0))


def photos():
    """Blurry, generic family-snapshot-like images (abstract silhouettes)."""
    specs = [
        ((180, 160, 130), (90, 120, 160), 2),
        ((120, 140, 100), (200, 190, 170), 3),
        ((90, 80, 70), (170, 120, 90), 1),
        ((150, 170, 190), (230, 220, 200), 2),
        ((70, 90, 70), (160, 150, 120), 0),
        ((140, 120, 110), (60, 60, 70), 4),
    ]
    for i, (bg0, bg1, people) in enumerate(specs):
        W, H = 256, 320
        r = np.random.default_rng(300 + i)
        y = np.linspace(0, 1, H)[:, None, None]
        img = np.array(bg1)[None, None] * (1 - y) + np.array(bg0)[None, None] * y
        img = np.repeat(img, W, 1).astype(float)
        im = Image.fromarray(img.astype(np.uint8))
        d = ImageDraw.Draw(im)
        if people == 0:  # landscape: horizon + house
            d.rectangle([0, 200, W, H], fill=(60, 80, 50))
            d.polygon([(70, 200), (70, 140), (128, 100), (186, 140), (186, 200)], fill=(200, 196, 186))
            d.rectangle([115, 160, 140, 200], fill=(80, 60, 50))
        xs = np.linspace(50, W - 50, max(people, 1))
        for k in range(people):
            cx = int(xs[k] + r.integers(-10, 10))
            hh = int(r.integers(110, 160))
            top = H - hh
            col = tuple(int(c) for c in r.integers(30, 160, 3))
            d.ellipse([cx - 18, top - 40, cx + 18, top], fill=(196, 160, 132))
            d.rounded_rectangle([cx - 32, top, cx + 32, H], 18, fill=col)
        im = im.filter(ImageFilter.GaussianBlur(3.5))
        arr = np.array(im).astype(float)
        # faded print look
        arr = arr * 0.8 + np.array([40, 30, 20]) * 0.5
        arr += (np.random.default_rng(i).random(arr.shape[:2])[..., None] - 0.5) * 18
        # white border
        arr[:10, :] = 235
        arr[-10:, :] = 235
        arr[:, :10] = 235
        arr[:, -10:] = 235
        Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8)).save(os.path.join(OUT, f"photo_{i}.png"))
        print("tex photo", i)


def drawing():
    """Crayon drawing taped to a wall."""
    W, H = 256, 200
    im = Image.new("RGB", (W, H), (236, 232, 220))
    d = ImageDraw.Draw(im)
    d.line([(10, 160), (246, 160)], fill=(60, 140, 60), width=4)
    d.rectangle([60, 90, 140, 160], outline=(170, 40, 40), width=4)
    d.polygon([(55, 92), (100, 50), (145, 92)], outline=(80, 60, 160), width=4)
    d.rectangle([90, 120, 110, 160], outline=(40, 40, 40), width=3)
    # windows: one lit
    d.rectangle([70, 100, 85, 115], fill=(240, 210, 40))
    d.rectangle([118, 100, 133, 115], outline=(40, 40, 40), width=2)
    # stick figure far from house
    d.ellipse([196, 104, 210, 118], outline=(20, 20, 20), width=2)
    d.line([(203, 118), (203, 142), (195, 160)], fill=(20, 20, 20), width=2)
    d.line([(203, 142), (211, 160)], fill=(20, 20, 20), width=2)
    d.line([(193, 126), (213, 126)], fill=(20, 20, 20), width=2)
    d.ellipse([200, 20, 230, 50], fill=(230, 220, 120))
    im = im.filter(ImageFilter.GaussianBlur(0.6))
    im.save(os.path.join(OUT, "drawing.png"))
    print("tex drawing")


def calendar():
    W, H = 256, 320
    im = Image.new("RGB", (W, H), (232, 228, 214))
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, W, 130], fill=(120, 140, 160))
    d.polygon([(0, 130), (90, 60), (160, 110), (256, 50), (256, 130)], fill=(80, 96, 80))
    d.text((90, 136), "OCTOBER", fill=(40, 40, 40))
    for r_ in range(5):
        for c in range(7):
            x0, y0 = 14 + c * 33, 156 + r_ * 31
            d.rectangle([x0, y0, x0 + 30, y0 + 28], outline=(150, 150, 150))
            day = r_ * 7 + c - 2
            if 1 <= day <= 31:
                d.text((x0 + 3, y0 + 2), str(day), fill=(60, 60, 60))
            if day == 11:
                d.ellipse([x0 - 3, y0 - 3, x0 + 33, y0 + 31], outline=(180, 30, 30), width=2)
            if 1 <= day <= 8:
                d.line([(x0 + 2, y0 + 26), (x0 + 28, y0 + 2)], fill=(90, 90, 120), width=1)
    im.save(os.path.join(OUT, "calendar.png"))
    print("tex calendar")


def window_glow():
    """Neighbour window: warm interior with curtain silhouette."""
    W, H = 128, 128
    y, x = np.mgrid[0:H, 0:W] / W
    base = np.array([255, 196, 120], float)[None, None] * (0.75 + 0.25 * (1 - y[..., None]))
    curtain = ((x < 0.18) | (x > 0.82)).astype(float)
    folds = np.sin(x * 60) * 0.5 + 0.5
    base *= (1 - curtain[..., None] * (0.55 + folds[..., None] * 0.15))
    save("window_glow", base)


def sky_noise():
    n = tile_noise(S, 4, 6, 99)
    g = (n * 255)[..., None].repeat(3, -1)
    save("cloud_noise", g)


if __name__ == "__main__":
    wallpaper_damask()
    wallpaper_stripe()
    paint("paint_cream", (196, 184, 160), 10, 1)
    paint("paint_yellow", (196, 178, 128), 10, 2)
    paint("paint_blue", (150, 164, 172), 10, 3)
    paint("paint_white", (200, 196, 188), 8, 4)
    paint("paint_garage", (150, 148, 140), 16, 5)
    ceiling()
    wood_floor()
    carpet()
    tiles("tile_kitchen", 6, (200, 190, 160), (110, 104, 94), 0.03, checker=(120, 100, 80), var=6, seed=8)
    tiles("tile_bath", 12, (196, 206, 206), (150, 150, 146), 0.05, var=4, seed=9)
    tiles("tile_backsplash", 10, (190, 200, 180), (160, 156, 146), 0.05, var=6, seed=10)
    wood_furniture("wood_dark", (58, 38, 24), (96, 64, 40), 201)
    wood_furniture("wood_light", (140, 104, 70), (186, 148, 106), 202)
    wood_furniture("wood_painted", (196, 190, 176), (214, 208, 196), 203)
    fabric("fabric_sofa", (104, 92, 74), 211)
    fabric("fabric_green", (78, 92, 72), 212)
    fabric("fabric_red", (122, 62, 52), 213)
    fabric("fabric_blue", (70, 82, 104), 214)
    fabric("fabric_white", (200, 196, 184), 215)
    fabric("fabric_stripe", (170, 160, 140), 216)
    siding("siding_white", (200, 200, 192), 221)
    siding("siding_blue", (120, 140, 156), 222)
    siding("siding_yellow", (196, 182, 132), 223)
    siding("siding_green", (128, 146, 120), 224)
    siding("siding_gray", (150, 150, 146), 225)
    shingles()
    brick()
    grass()
    asphalt()
    concrete("concrete", (150, 146, 138), 231, joints=1)
    concrete("concrete_dark", (110, 108, 104), 232)
    fence()
    mulch()
    leaves()
    bark()
    photos()
    drawing()
    calendar()
    window_glow()
    sky_noise()


# ---------------------------------------------------------------- night 2+ additions
def sigil(name="sigil", ink=(30, 24, 22), bg=None, size=256, width=6):
    """The court's mark: a broken circle, a downward fork and three short bars.
    Deliberately not a pentagram — something a neighbour could scratch quickly."""
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0) if bg is None else bg)
    d = ImageDraw.Draw(im)
    c = size // 2
    r = int(size * 0.36)
    d.arc([c - r, c - r, c + r, c + r], 110, 430, fill=ink + (255,), width=width)
    d.line([(c, c - r + 10), (c, c + 8)], fill=ink + (255,), width=width)
    d.line([(c, c + 8), (c - int(r * 0.55), c + int(r * 0.75))], fill=ink + (255,), width=width)
    d.line([(c, c + 8), (c + int(r * 0.55), c + int(r * 0.75))], fill=ink + (255,), width=width)
    for k in range(3):
        y = c - int(r * 0.45) + k * int(r * 0.22)
        d.line([(c - int(r * 0.28), y), (c - int(r * 0.12), y)], fill=ink + (255,), width=max(2, width - 2))
    im = im.filter(ImageFilter.GaussianBlur(0.8))
    im.save(os.path.join(OUT, name + ".png"))
    print("tex", name)


def photo_cult():
    """Faded 1970s snapshot: pale robed figures in a ring holding candles, at dusk."""
    W, H = 320, 240
    y = np.linspace(0, 1, H)[:, None, None]
    img = np.array([70, 60, 70])[None, None] * (1 - y) + np.array([40, 34, 30])[None, None] * y
    img = np.repeat(img, W, 1).astype(float)
    im = Image.fromarray(img.astype(np.uint8))
    d = ImageDraw.Draw(im)
    d.rectangle([0, 170, W, H], fill=(36, 40, 30))
    r = np.random.default_rng(55)
    for k in range(9):
        x = 30 + k * 32 + r.integers(-6, 6)
        h = r.integers(70, 92)
        top = 190 - h
        d.ellipse([x - 9, top - 18, x + 9, top + 2], fill=(150, 140, 125))
        d.polygon([(x - 16, 196), (x - 9, top), (x + 9, top), (x + 16, 196)], fill=(178, 170, 150))
        d.ellipse([x - 3, top + 30, x + 3, top + 36], fill=(255, 220, 140))
    d.ellipse([140, 182, 180, 196], fill=(20, 18, 16))
    im = im.filter(ImageFilter.GaussianBlur(2.2))
    arr = np.array(im).astype(float)
    arr = arr * np.array([1.05, 0.95, 0.75]) + 20
    arr += (np.random.default_rng(56).random(arr.shape[:2])[..., None] - 0.5) * 22
    arr[:8, :] = 225
    arr[-8:, :] = 225
    arr[:, :8] = 225
    arr[:, -8:] = 225
    Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8)).save(os.path.join(OUT, "photo_cult.png"))
    print("tex photo_cult")


def photo_altered():
    """photo_5 again, but somebody stands at the back who wasn't there."""
    im = Image.open(os.path.join(OUT, "photo_5.png")).convert("RGB")
    d = ImageDraw.Draw(im)
    x = 205
    d.ellipse([x - 13, 110, x + 13, 140], fill=(14, 12, 14))
    d.rounded_rectangle([x - 24, 138, x + 24, 300], 12, fill=(12, 10, 12))
    im = im.filter(ImageFilter.GaussianBlur(1.6))
    im.save(os.path.join(OUT, "photo_5b.png"))
    print("tex photo_5b")


def silhouette():
    """Figure standing behind a lit curtain (alpha mask, used in neighbour windows)."""
    W, H = 128, 128
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.ellipse([52, 18, 76, 46], fill=(10, 8, 8, 235))
    d.rounded_rectangle([40, 44, 88, 140], 14, fill=(10, 8, 8, 235))
    d.rectangle([58, 40, 70, 50], fill=(10, 8, 8, 235))
    im = im.filter(ImageFilter.GaussianBlur(3.0))
    im.save(os.path.join(OUT, "silhouette.png"))
    print("tex silhouette")


if __name__ == "__main__" and len(sys.argv) > 1 and sys.argv[1] == "night":
    sigil()
    sigil("sigil_chalk", (205, 200, 190), None, 256, 7)
    photo_cult()
    photo_altered()
    silhouette()
