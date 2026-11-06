"""Exporta los sprites que usa el juego (tiras de fotogramas a escala 1) y sus medidas.

Lo llama export.py. Escribe en art/sprites/pixel/ del proyecto:
  hero/tico_0.png … tico_2.png   Tico sin forja, con hierro y con equipo maestro (provisional hasta las capas)
  enemies/<arquetipo>.png         slime, skeleton, bat, golem, wraith
  bosses/boss_<bioma>.png         0 Catacumbas … 4 Santuario del Vacío
  metrics.json                    caja de píxeles opacos de cada sprite, en píxeles del arte
"""
import json
from pathlib import Path

from PIL import Image

REPO = Path(__file__).resolve().parents[2]
SPRITES = REPO / "art" / "sprites" / "pixel"

# Fila de los pies según el tamaño del lienzo (el contorno queda en la fila siguiente)
GROUND_ROW = {32: 28, 48: 45}


def strip_image(frames):
    w, h = frames[0].w, frames[0].h
    img = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        img.alpha_composite(f.image(), (i * w, 0))
    return img


def measure(sprite):
    """Medidas del fotograma relativas al punto de apoyo (centro de los pies)."""
    xs, ys = [], []
    for y in range(sprite.h):
        for x in range(sprite.w):
            if sprite.px[y][x] != '.':
                xs.append(x)
                ys.append(y)
    left, right, top, bottom = min(xs), max(xs), min(ys), max(ys)
    ground = GROUND_ROW[sprite.h]
    mid = sprite.w // 2
    return {
        "frame_w": sprite.w,
        "frame_h": sprite.h,
        "ground_row": ground,
        "half_width": max(mid - left, right + 1 - mid),
        "body_height": bottom - top + 1,
        "center_y": (top + bottom + 1) / 2 - (ground + 1),
        "hover": max(0, ground - bottom),
    }


def export_game(cast):
    """cast: {clave: [fotogramas]}, con claves como "hero/tico_0". Devuelve las medidas escritas."""
    metrics = {}
    for key, frames in cast.items():
        path = SPRITES / f"{key}.png"
        path.parent.mkdir(parents=True, exist_ok=True)
        strip_image(frames).save(path)
        m = measure(frames[0])
        m["frames"] = len(frames)
        metrics[key] = m
    (SPRITES / "metrics.json").write_text(json.dumps(metrics, indent=1, sort_keys=True), encoding="utf-8")
    return metrics
