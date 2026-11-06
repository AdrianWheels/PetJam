"""Iconos del panel de Equipo (poción, mochila) desde imágenes hechas en ChatGPT con fondo blanco liso.

Cada icono se recorta, se encaja en su caja (px de pantalla a 1080 de ancho) y lleva el borde blanco de pegatina,
como las piezas (build_gear_art.py).

Uso:
    python tools/gear_art/build_ui_icons.py
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image

import build_gear_art as gear

ROOT = Path(__file__).resolve().parents[2]
OUT_DIR = ROOT / "art" / "ui"
SOURCES = Path(__file__).resolve().parent / "sources" / "nuevas"

# nombre de salida → (original, caja en px)
ICONS = {
    "pocion_vida": ("pocion_vida.png", (64, 104)),
    "mochila": ("mochila.png", (52, 52)),
}


def build(name: str, source: str, box: tuple[int, int]) -> Path:
    src = gear.remove_white_bg(Image.open(SOURCES / source))
    src = src.crop(gear.opaque_box(src))
    pad = 6  # borde blanco y sombra
    k = min((box[0] - 2 * pad) / src.width, (box[1] - 2 * pad) / src.height)
    art = src.resize((max(1, round(src.width * k)), max(1, round(src.height * k))), Image.LANCZOS)
    canvas = Image.new("RGBA", box, (0, 0, 0, 0))
    canvas.alpha_composite(art, ((box[0] - art.width) // 2, (box[1] - art.height) // 2))
    old = gear.OUTLINE, gear.SHADOW
    gear.OUTLINE, gear.SHADOW = 3, 2  # un icono pequeño lleva el borde más fino
    out = gear.sticker(canvas)
    gear.OUTLINE, gear.SHADOW = old
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    path = OUT_DIR / f"{name}.png"
    out.save(path, optimize=True)
    return path


if __name__ == "__main__":
    for name, (source, box) in ICONS.items():
        print(build(name, source, box))
