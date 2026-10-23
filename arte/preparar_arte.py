"""Prepara el arte recibido para el prototipo de Godot.

Uso:  python3 arte/preparar_arte.py <carpeta 01_ASSETS_PARA_CLAUDE> prototipo/assets/arte

- Copia unidades, edificios, torretas, efectos, retratos e interfaz con sus nombres.
- Terreno: llanura, bosque, colina, muro, ruinas y barricada tal cual; llanura_2 con el tono de llanura.
- Caminos y ríos: genera las 16 piezas de cada uno (una por combinación de vecinos N, E, S, O) a partir de
  la textura de la recta, para que todas entren por el mismo punto del borde y empalmen. Para las zonas
  de agua de 2×2 genera cuartos de lago, y la pasarela del puente aparte para dibujarla encima.
- Cartas: recorta la ilustración (quita el margen y el rótulo de texto de la lámina).
- Torreta destruida: la reduce y centra porque venía cortada por los bordes.
- Icono de la app en los tamaños de Android.

Máscara de vecinos: N=1, E=2, S=4, O=8 (camino_5 = norte y sur, camino_10 = este y oeste...).
"""
from __future__ import annotations

import math
import os
import random
import shutil
import sys

from PIL import Image, ImageChops, ImageFilter, ImageStat

N, E, S, W = 1, 2, 4, 8
T = 256                        # tamaño de casilla


def load(path: str) -> Image.Image:
    return Image.open(path).convert("RGBA")


def tone_match(im: Image.Image, ref: Image.Image) -> Image.Image:
    """Ajusta la media de cada canal de im a la de ref."""
    a, b = ImageStat.Stat(im.convert("RGB")).mean, ImageStat.Stat(ref.convert("RGB")).mean
    chans = [ch.point(lambda v, k=b[i] / max(1.0, a[i]): min(255, int(v * k))) for i, ch in enumerate(im.convert("RGB").split())]
    return Image.merge("RGB", chans).convert("RGBA")


def band(im: Image.Image, test) -> tuple[int, int]:
    """Filas (min, max) donde la columna central cumple test (la franja del camino o del río)."""
    px = im.load()
    rows = [y for y in range(im.size[1]) if sum(test(px[x, y]) for x in range(0, im.size[0], 8)) > im.size[0] // 8 * 0.7]
    return min(rows), max(rows)


def is_road(p) -> bool:
    r, g, b = p[:3]
    return r > 170 and g > 140 and b < 150 and r - b > 50 and abs(r - g) < 60


def is_water(p) -> bool:
    r, g, b = p[:3]
    return b > 150 and b > r + 40 and b > g + 10


def noise_edge(mask: Image.Image, amount: float, seed: int) -> Image.Image:
    """Borde algo irregular: desplaza la máscara con ruido suave y la difumina un poco."""
    rnd = random.Random(seed)
    small = Image.new("L", (16, 16))
    small.putdata([rnd.randint(0, 255) for _ in range(256)])
    nz = small.resize(mask.size, Image.BICUBIC)
    blurred = mask.filter(ImageFilter.GaussianBlur(amount))
    out = ImageChops.add(blurred, nz.point(lambda v: v // 6), scale=1.0, offset=-21)
    return out.point(lambda v: 255 if v > 127 else 0).filter(ImageFilter.GaussianBlur(1.2))


def strip_texture(src: Image.Image, y0: int, y1: int) -> Image.Image:
    """Textura de la franja (sin bordes) repetida en un cuadrado T×T, horizontal."""
    pad = (y1 - y0) // 6
    strip = src.crop((0, y0 + pad, T, y1 - pad)).resize((T, y1 - y0))
    out = Image.new("RGBA", (T, T))
    for y in range(0, T, strip.size[1]):
        out.paste(strip, (0, y))
    return out


def piece_mask(mask_bits: int, half: float, lake_corner: int = 0) -> Image.Image:
    """Máscara de una pieza: franjas desde el centro hacia cada lado conectado; curvas redondeadas.
    lake_corner (N|E, E|S, S|W, W|N): cuarto de lago que llena la casilla hacia esa esquina."""
    m = Image.new("L", (T, T), 0)
    px = m.load()
    c = T / 2
    h = half * T
    dirs = [d for d in (N, E, S, W) if mask_bits & d]
    corner = {N | E: (T, 0), E | S: (T, T), S | W: (0, T), W | N: (0, 0)}
    for y in range(T):
        for x in range(T):
            inside = False
            if lake_corner:
                cx, cy = corner[lake_corner]
                inside = math.hypot(x + 0.5 - cx, y + 0.5 - cy) < T * 0.86
            elif len(dirs) == 2 and (mask_bits in corner):
                cx, cy = corner[mask_bits]          # curva: anillo centrado en la esquina
                inside = abs(math.hypot(x + 0.5 - cx, y + 0.5 - cy) - c) < h
            else:
                for d in dirs:
                    if d == N and y <= c + h and abs(x + 0.5 - c) < h: inside = True
                    if d == S and y >= c - h and abs(x + 0.5 - c) < h: inside = True
                    if d == E and x >= c - h and abs(y + 0.5 - c) < h: inside = True
                    if d == W and x <= c + h and abs(y + 0.5 - c) < h: inside = True
                if not dirs:
                    inside = math.hypot(x + 0.5 - c, y + 0.5 - c) < h * 1.3
                elif len(dirs) == 1:                # final: un poco redondeado en el centro
                    inside = inside or math.hypot(x + 0.5 - c, y + 0.5 - c) < h
            px[x, y] = 255 if inside else 0
    return m


def compose(base: Image.Image, tex_h: Image.Image, mask: Image.Image, edge_color, edge_px: int, seed: int,
            vertical_bits: bool) -> Image.Image:
    """Pega la textura sobre la base con la máscara, con un reborde (orilla o tierra pisada)."""
    mask = noise_edge(mask, 2.0, seed)
    tex = tex_h.rotate(90) if vertical_bits else tex_h
    out = base.copy()
    if edge_px:
        rim = mask.filter(ImageFilter.MaxFilter(edge_px * 2 + 1)).filter(ImageFilter.GaussianBlur(1.5))
        out = Image.composite(Image.new("RGBA", (T, T), edge_color), out, rim)
    return Image.composite(tex, out, mask)


def main(src: str, dst: str) -> None:
    os.makedirs(dst, exist_ok=True)
    for sub in ("unidades", "edificios", "torretas", "efectos", "retratos", "ui"):
        os.makedirs(os.path.join(dst, sub), exist_ok=True)
        for f in sorted(os.listdir(os.path.join(src, sub))):
            shutil.copy(os.path.join(src, sub, f), os.path.join(dst, sub, f))

    # torreta destruida: venía cortada por la derecha y por abajo; se reduce y centra
    t = load(os.path.join(src, "torretas", "destruida.png"))
    t = t.crop(t.getbbox())
    t.thumbnail((int(T * 0.8), int(T * 0.8)))
    out = Image.new("RGBA", (T, T))
    out.alpha_composite(t, ((T - t.size[0]) // 2, (T - t.size[1]) // 2))
    out.save(os.path.join(dst, "torretas", "destruida.png"))

    # terreno
    td = os.path.join(dst, "terreno")
    os.makedirs(td, exist_ok=True)
    plain = load(os.path.join(src, "terreno", "llanura.png"))
    for f in ("llanura", "bosque", "colina", "muro", "ruinas", "barricada"):
        shutil.copy(os.path.join(src, "terreno", f + ".png"), os.path.join(td, f + ".png"))
    tone_match(load(os.path.join(src, "terreno", "llanura_2.png")), plain).save(os.path.join(td, "llanura_2.png"))

    road = load(os.path.join(src, "terreno", "camino_recto.png"))
    ry0, ry1 = band(road, is_road)
    road_tex = strip_texture(road, ry0, ry1)
    road_half = (ry1 - ry0) / 2 / T * 0.85
    river = load(os.path.join(src, "terreno", "rio_recto.png"))
    wy0, wy1 = band(river, is_water)
    water_tex = strip_texture(river, wy0, wy1)
    water_half = (wy1 - wy0) / 2 / T * 0.9
    bank = (122, 98, 66, 255)
    for bits in range(16):
        vert = bits in (N, S, N | S)
        compose(plain, road_tex, piece_mask(bits, road_half), (150, 128, 84, 255), 2, 100 + bits, vert).save(
            os.path.join(td, f"camino_{bits}.png"))
        compose(plain, water_tex, piece_mask(bits, water_half), bank, 5, 200 + bits, vert).save(
            os.path.join(td, f"rio_{bits}.png"))
    for name, corner in (("ne", N | E), ("se", E | S), ("so", S | W), ("no", W | N)):
        compose(plain, water_tex, piece_mask(0, water_half, corner), bank, 5, 300 + corner, False).save(
            os.path.join(td, f"lago_{name}.png"))

    # pasarela del puente: la parte de madera de puente.png (cruza en horizontal), sobre transparente
    bridge = load(os.path.join(src, "terreno", "puente.png"))
    px = bridge.load()
    deck = Image.new("RGBA", (T, T))
    dp = deck.load()
    rows = [y for y in range(T) if sum(1 for x in range(T // 2 - 20, T // 2 + 20) if not is_water(px[x, y])
                                        and px[x, y][0] > 90 and px[x, y][0] > px[x, y][2] + 20) > 30]
    by0, by1 = min(rows), max(rows)
    for y in range(by0, by1 + 1):
        for x in range(T):
            dp[x, y] = px[x, y]
    deck.save(os.path.join(td, "puente_h.png"))
    deck.rotate(90).save(os.path.join(td, "puente_v.png"))

    # cartas: recorte de la ilustración (sin margen ni rótulo)
    cd = os.path.join(dst, "cartas")
    os.makedirs(cd, exist_ok=True)
    for f in sorted(os.listdir(os.path.join(src, "cartas"))):
        im = load(os.path.join(src, "cartas", f))
        if f.startswith("marco_"):
            im.save(os.path.join(cd, f))
            continue
        rgb = im.convert("RGB")
        bg = rgb.getpixel((4, 4))
        diff = ImageChops.difference(rgb, Image.new("RGB", rgb.size, bg)).convert("L").point(lambda v: 255 if v > 40 else 0)
        x0, y0, x1, y1 = diff.getbbox()
        for y in range(y0 + int((y1 - y0) * 0.7), y1):           # el rótulo empieza con una franja lisa y oscura
            st = ImageStat.Stat(rgb.crop((x0 + 4, y, x1 - 4, y + 1)))
            if st.mean[1] < 28 and st.stddev[1] < 20:
                y1 = y
                break
        im.crop((x0 + 2, y0 + 2, x1 - 2, y1)).save(os.path.join(cd, f))

    # icono de la app
    icon = load(os.path.join(src, "ui", "icono_app.png"))
    idir = os.path.join(os.path.dirname(dst.rstrip("/")), "..", "icons")
    os.makedirs(idir, exist_ok=True)
    icon.resize((512, 512), Image.LANCZOS).save(os.path.join(idir, "icon.png"))
    icon.resize((192, 192), Image.LANCZOS).save(os.path.join(idir, "icon_192.png"))
    fg = Image.new("RGBA", (432, 432))
    fg.alpha_composite(icon.resize((288, 288), Image.LANCZOS), (72, 72))
    fg.save(os.path.join(idir, "icon_foreground.png"))
    Image.new("RGBA", (432, 432), (22, 34, 44, 255)).save(os.path.join(idir, "icon_background.png"))
    print("Arte preparado en", dst)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
