"""Monta las texturas de las piezas del inventario en rejilla (spec del inventario, apartado 9.5).

Cada pieza sale de una imagen ilustrada (las pegatinas de la franja o los iconos de los objetos): se recorta,
se gira, se escala a su forma (110 px de pantalla por casilla) y se enmascara a sus casillas, con el borde
blanco de pegatina horneado. La textura queda en el giro 0 de `shape_cells`; el juego la gira en los otros 3.

Uso:
    python tools/gear_art/build_gear_art.py                 # todas las piezas de PIECES
    python tools/gear_art/build_gear_art.py sword_masterwork

Las rutas de origen se buscan en SOURCE_DIRS, en orden: los originales viven en el repositorio de assets.
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
OUT_DIR = ROOT / "art" / "gear"
CELL = 110  # px de pantalla por casilla (GearGridView.CELL)
OUTLINE = 5  # grosor del borde blanco, en px
SHADOW = 3  # desplazamiento de la sombra, en px
PAD = OUTLINE + SHADOW + 2  # margen hasta el borde de la caja: el borde y la sombra no se cortan

SOURCE_DIRS = [
    ROOT / "art" / "assets" / "Stickers" / "originales",
    ROOT / "art" / "assets" / "Imagenes" / "Items",
    Path("D:/Proyectos/PetJam/.claude/worktrees/kind-robinson-8996cf/art/assets/Stickers/originales"),
]

# Una entrada por pieza:
#   source: fichero de imagen (en SOURCE_DIRS)
#   cells: casillas de la forma en el giro 0, como shape_cells de data/items/<id>.tres
#   rotate: grados en sentido antihorario que se gira el original antes de encajarlo (PIL)
#   crop: (x0, y0, x1, y1) opcional sobre el original, antes de girar; por defecto, lo opaco
#   fit: "contain" (cabe entera en la caja) o "cover" (llena la caja y la máscara recorta lo que sobra)
#   mask: True recorta a las casillas de la forma (formas en T o L); en un rectángulo no hace falta
PIECES: dict[str, dict] = {
    "sword_basic": {"source": "arma_basica.png", "cells": [(0, 0), (0, 1)], "rotate": 90, "fit": "contain"},
    "sword_advanced": {"source": "arma_avanzada.png", "cells": [(0, 0), (0, 1), (0, 2)], "rotate": 90, "fit": "contain"},
    "sword_masterwork": {"source": "arma_maestra.png", "cells": [(0, 0), (0, 1), (0, 2), (0, 3)], "rotate": 90, "fit": "contain"},
}


def find_source(name: str) -> Path:
    for d in SOURCE_DIRS:
        p = d / name
        if p.exists():
            return p
    raise FileNotFoundError(f"no encuentro {name} en {[str(d) for d in SOURCE_DIRS]}")


def box_of(cells: list[tuple[int, int]]) -> tuple[int, int]:
    return max(c[0] for c in cells) + 1, max(c[1] for c in cells) + 1


def cell_mask(cells: list[tuple[int, int]], size: tuple[int, int]) -> Image.Image:
    """Máscara de las casillas de la forma, metida PAD px hacia dentro en los lados que no tocan otra casilla."""
    m = Image.new("L", size, 0)
    s = set(cells)
    for (x, y) in cells:
        x0, y0, x1, y1 = x * CELL, y * CELL, (x + 1) * CELL, (y + 1) * CELL
        x0 += 0 if (x - 1, y) in s else PAD
        x1 -= 0 if (x + 1, y) in s else PAD
        y0 += 0 if (x, y - 1) in s else PAD
        y1 -= 0 if (x, y + 1) in s else PAD
        m.paste(255, (x0, y0, x1, y1))
    return m


def sticker(art: Image.Image) -> Image.Image:
    """Borde blanco de pegatina y una sombra corta bajo la pieza, como los iconos de los objetos."""
    a = art.getchannel("A").point(lambda v: 255 if v > 40 else 0)
    ring = a.filter(ImageFilter.MaxFilter(OUTLINE * 2 + 1)).filter(ImageFilter.GaussianBlur(0.8))
    out = Image.new("RGBA", art.size, (0, 0, 0, 0))
    shadow = Image.new("RGBA", art.size, (20, 12, 10, 0))
    shadow.putalpha(ImageChops.offset(ring, SHADOW, SHADOW).point(lambda v: v * 90 // 255))
    out.alpha_composite(shadow)
    white = Image.new("RGBA", art.size, (255, 255, 255, 0))
    white.putalpha(ring)
    out.alpha_composite(white)
    out.alpha_composite(art)
    return out


def opaque_box(img: Image.Image) -> tuple[int, int, int, int]:
    """Caja de lo opaco de verdad: los originales traen halos casi transparentes que inflan getbbox."""
    return img.getchannel("A").point(lambda v: 255 if v > 40 else 0).getbbox()


def build(item_id: str, spec: dict) -> Path:
    src = Image.open(find_source(spec["source"])).convert("RGBA")
    src = src.crop(spec.get("crop") or opaque_box(src))
    if spec.get("rotate"):
        src = src.rotate(spec["rotate"], expand=True, resample=Image.BICUBIC)
        src = src.crop(opaque_box(src))
    cells = [tuple(c) for c in spec["cells"]]
    bw, bh = box_of(cells)
    size = (bw * CELL, bh * CELL)
    inner = (size[0] - 2 * PAD, size[1] - 2 * PAD)
    sx, sy = inner[0] / src.width, inner[1] / src.height
    k = max(sx, sy) if spec.get("fit") == "cover" else min(sx, sy)
    k *= spec.get("scale", 1.0)
    art_img = src.resize((max(1, round(src.width * k)), max(1, round(src.height * k))), Image.LANCZOS)
    canvas = Image.new("RGBA", size, (0, 0, 0, 0))
    ox, oy = spec.get("offset", (0, 0))
    canvas.alpha_composite(art_img, ((size[0] - art_img.width) // 2 + ox, (size[1] - art_img.height) // 2 + oy))
    if spec.get("mask") or spec.get("fit") == "cover":
        canvas.putalpha(ImageChops.multiply(canvas.getchannel("A"), cell_mask(cells, size)))
    out = sticker(canvas)
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    path = OUT_DIR / f"{item_id}.png"
    out.save(path, optimize=True)
    return path


def main(ids: list[str]) -> None:
    for item_id in ids or list(PIECES):
        print(build(item_id, PIECES[item_id]))


if __name__ == "__main__":
    main(sys.argv[1:])
