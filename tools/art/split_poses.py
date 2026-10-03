"""Separa las cuatro poses de cada hoja 2x2 de personaje sin cortarlas.

Las hojas de art/stickers/sources/characters traen las poses en cuartos, pero muchas se salen del suyo (la espada de
Tico, el brazo del golem, el báculo de un jefe). Recortar por cuartos las cortaba, y el trozo cortado aparecía por el
borde de la pose vecina. Aquí cada mancha de píxeles opacos va entera a la pose del cuarto donde tiene la mayoría de
sus píxeles, y cada pose se pega en un lienzo con margen alrededor de su cuarto.

Salida: art/stickers/poses/<clave>.png, una tira con los 4 fotogramas en fila (reposo, ataque, daño, derrota), todos
cuadrados y del mismo tamaño. El cuarto original queda centrado en su fotograma y escalado a CELL_PX en su lado mayor:
así el tamaño y la colocación de cada personaje no cambian respecto al recorte por cuartos (StickerSprites.CELL_PX).

Uso: python tools/art/split_poses.py  (desde la raíz del proyecto; luego godot --headless --import)
"""

from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "art/stickers/sources/characters"
OUT = ROOT / "art/stickers/poses"
CELL_PX = 320  # lado mayor del cuarto en la tira (el mismo que usaba StickerSprites al recortar)
SOLID = 8  # alfa a partir del cual un píxel cuenta para unir manchas (el resto es neblina de alfa 1 de ChatGPT)
FRINGE = 3  # la neblina a menos de estos píxeles de una mancha va con ella; la más lejana se descarta
PAD = 6  # margen extra alrededor de lo que más sobresale


def split(path: Path) -> tuple[Image.Image, int]:
    rgba = np.array(Image.open(path).convert("RGBA"))
    h, w = rgba.shape[:2]
    cw, ch = w // 2, h // 2
    alpha = rgba[:, :, 3]
    labels, count = ndimage.label(alpha > SOLID, structure=np.ones((3, 3)))
    # Neblina y bordes suaves: con la mancha más cercana si está a FRINGE píxeles o menos
    dist, (iy, ix) = ndimage.distance_transform_edt(labels == 0, return_indices=True)
    near = labels[iy, ix]
    owner = np.where(labels > 0, labels, np.where((alpha > 0) & (dist <= FRINGE), near, 0))
    # Cada mancha, a la pose del cuarto con más píxeles suyos
    ys, xs = np.nonzero(labels)
    quarter = (xs >= cw).astype(np.int64) + 2 * (ys >= ch).astype(np.int64)
    votes = np.zeros((count + 1, 4), dtype=np.int64)
    np.add.at(votes, (labels[ys, xs], quarter), 1)
    pose_of = np.argmax(votes, axis=1)
    pose = np.where(owner > 0, pose_of[owner], -1)
    # Cuánto sobresale cada pose de su cuarto, en el lado peor
    overflow = 0
    for p in range(4):
        py, px = np.nonzero(pose == p)
        if px.size == 0:
            continue
        ox, oy = (p % 2) * cw, (p // 2) * ch
        lx, ly = px - ox, py - oy
        overflow = max(overflow, -lx.min(), -ly.min(), lx.max() - (cw - 1), ly.max() - (ch - 1))
    margin = int(overflow) + PAD
    side = max(cw, ch) + 2 * margin
    frames = []
    for p in range(4):
        canvas = np.zeros((side, side, 4), dtype=np.uint8)
        py, px = np.nonzero(pose == p)
        ox, oy = (p % 2) * cw, (p // 2) * ch
        # El cuarto, centrado en el lienzo
        cx = (side - cw) // 2
        cy = (side - ch) // 2
        canvas[py - oy + cy, px - ox + cx] = rgba[py, px]
        frames.append(Image.fromarray(canvas, "RGBA"))
    scale = CELL_PX / max(cw, ch)
    frame_px = round(side * scale)
    strip = Image.new("RGBA", (frame_px * 4, frame_px), (0, 0, 0, 0))
    for p, frame in enumerate(frames):
        strip.paste(frame.resize((frame_px, frame_px), Image.LANCZOS), (p * frame_px, 0))
    return strip, frame_px


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for path in sorted(SRC.glob("*.png")):
        strip, frame_px = split(path)
        strip.save(OUT / path.name, optimize=True)
        print(f"{path.name:20s} fotograma {frame_px} px (cuarto a {CELL_PX})")


if __name__ == "__main__":
    main()
