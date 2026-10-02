"""Monta las texturas de las piezas del inventario en rejilla (spec del inventario, apartado 9.5).

Cada pieza sale de una imagen ilustrada (las pegatinas de la franja o los iconos de los objetos): se recorta,
se gira, se escala a su forma (110 px de pantalla por casilla) y se enmascara a sus casillas, con el borde
blanco de pegatina horneado. La textura queda en el giro 0 de `shape_cells`; el juego la gira en los otros 3.

Uso:
    python tools/gear_art/build_gear_art.py                 # todas las piezas de pieces/
    python tools/gear_art/build_gear_art.py sword_masterwork
    python tools/gear_art/build_gear_art.py --preview=<carpeta> sword_masterwork   # y su hoja de revisión

Las rutas de origen se buscan en SOURCE_DIRS, en orden: los originales viven en el repositorio de assets.
"""
from __future__ import annotations

import importlib.util
import json
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

PIECES_DIR = Path(__file__).resolve().parent / "pieces"

# Una pieza por fichero, pieces/<item_id>.json (así cada pieza se trabaja por separado):
#   source: fichero de imagen (en SOURCE_DIRS)
#   cells: casillas de la forma en el giro 0, como shape_cells de data/items/<id>.tres
#   crop: [x0, y0, x1, y1] opcional sobre el original, antes de girar; por defecto, lo opaco
#   flip: true lo voltea en horizontal (después de recortar)
#   rotate: grados en sentido antihorario que se gira antes de encajarlo (PIL)
#   fit: "contain" (cabe entera en la caja) o "cover" (llena la caja y la máscara recorta lo que sobra)
#   scale, offset: ajuste fino del tamaño (factor) y de la posición (px) dentro de la caja
#   mask: true recorta a las casillas de la forma (formas en T o L); en un rectángulo no hace falta
# Si existe pieces/<item_id>.py con `prepare(img) -> img`, se aplica al original antes de recortarlo: para
# borrar o mover partes de la imagen cuando las opciones no bastan.


def load_piece(item_id: str) -> dict:
    return json.loads((PIECES_DIR / f"{item_id}.json").read_text(encoding="utf-8"))


def all_pieces() -> list[str]:
    return sorted(p.stem for p in PIECES_DIR.glob("*.json"))


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
    hook = PIECES_DIR / f"{item_id}.py"
    if hook.exists():
        mod_spec = importlib.util.spec_from_file_location(f"piece_{item_id}", hook)
        mod = importlib.util.module_from_spec(mod_spec)
        mod_spec.loader.exec_module(mod)
        src = mod.prepare(src)
    src = src.crop(spec.get("crop") or opaque_box(src))
    if spec.get("flip"):
        src = src.transpose(Image.FLIP_LEFT_RIGHT)
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


def preview(item_id: str, spec: dict, path: Path) -> None:
    """Hoja de revisión: la textura en sus 4 giros sobre casillas como las del juego (fondo oscuro, borde de calidad)."""
    tex = Image.open(OUT_DIR / f"{item_id}.png").convert("RGBA")
    cells = [tuple(c) for c in spec["cells"]]
    tiles = []
    for r in range(4):
        t = tex
        cs = cells
        for _ in range(r):
            t = t.transpose(Image.ROTATE_270)  # un cuarto de vuelta a la derecha, como GearArt
            cs = [(-y, x) for (x, y) in cs]
        mx, my = min(c[0] for c in cs), min(c[1] for c in cs)
        cs = [(x - mx, y - my) for (x, y) in cs]
        tile = Image.new("RGBA", (t.width + 40, t.height + 40), (40, 28, 24, 255))
        from PIL import ImageDraw
        d = ImageDraw.Draw(tile)
        for (x, y) in cs:
            d.rectangle((20 + x * CELL + 4, 20 + y * CELL + 4, 20 + (x + 1) * CELL - 5, 20 + (y + 1) * CELL - 5),
                        fill=(30, 20, 16, 255), outline=(170, 110, 230, 255), width=3)
        tile.alpha_composite(t, (20, 20))
        tiles.append(tile)
    w = sum(t.width for t in tiles) + 10 * 5
    h = max(t.height for t in tiles) + 20
    sheet = Image.new("RGBA", (w, h), (24, 16, 14, 255))
    x = 10
    for t in tiles:
        sheet.alpha_composite(t, (x, 10))
        x += t.width + 10
    sheet.save(path)


def main(args: list[str]) -> None:
    prev_dir = None
    if args and args[0].startswith("--preview="):
        prev_dir = Path(args.pop(0).split("=", 1)[1])
    for item_id in args or all_pieces():
        spec = load_piece(item_id)
        print(build(item_id, spec))
        if prev_dir:
            prev_dir.mkdir(parents=True, exist_ok=True)
            preview(item_id, spec, prev_dir / f"{item_id}_preview.png")


if __name__ == "__main__":
    main(sys.argv[1:])
