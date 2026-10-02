"""Iconos de los materiales de bioma (12x12, con contorno de 1 px): botín de la franja e interfaz.

Lo llama export.py. Escribe art/sprites/pixel/materials/<id>.png a escala 1.
"""
from pathlib import Path

from pixel_kit import Sprite

REPO = Path(__file__).resolve().parents[2]
OUT = REPO / "art" / "sprites" / "pixel" / "materials"


def _icon(lines):
    s = Sprite(12, 12)
    s.rows(1, 1, lines)
    s.outline()
    return s


def bone():  # Catacumbas: dos huesos cruzados
    return _icon([
        "ee......ee",
        "eEe....eEe",
        ".eEe..eEe.",
        "..eEeeEe..",
        "...eEEe...",
        "...eEEe...",
        "..eEuuEe..",
        ".eEu..uEe.",
        "eEu....uEe",
        "ee......ee",
    ])


def moss():  # Cripta Musgosa: mata de musgo
    return _icon([
        "....aa....",
        "..aaAAa...",
        ".aAAcAAa..",
        "aAcAAcAAa.",
        "aAAcAAAcAa",
        "AcAAAcAAcA",
        "cAAcAAAcAc",
        ".cCcAcCcC.",
        "..CCcCCC..",
        "...CCCC...",
    ])


def obsidian():  # Caverna de Magma: piedra negra con veta de lava
    return _icon([
        "...UU.....",
        "..UoTU....",
        ".UooTTU...",
        "UooKo3TU..",
        "UoKK32oTU.",
        "UoKK3ooTU.",
        ".UKKooTU..",
        "..UKoTU...",
        "...UUU....",
        "..........",
    ])


def frost():  # Glaciar Olvidado: racimo de cristales de hielo
    return _icon([
        "....F.....",
        "...FfF....",
        "...FfF..F.",
        "..FFfFF.fF",
        "..FfYfF.fF",
        "F.FfffF.Ff",
        "fFFfffFFff",
        "fyyFfFyyFy",
        "yQQyyyQQyy",
        ".QQQQQQQQ.",
    ])


def void_shard():  # Santuario del Vacío: esquirla morada
    return _icon([
        ".....p....",
        "....pPp...",
        "....pPp...",
        "...pPYPp..",
        "...pPPPp..",
        "..pPPzPPp.",
        "..pPzzzPp.",
        "...PzZzP..",
        "....zZz...",
        ".....Z....",
    ])


ICONS = {"bone": bone, "moss": moss, "obsidian": obsidian, "frost": frost, "void_shard": void_shard}


def export_icons():
    OUT.mkdir(parents=True, exist_ok=True)
    for key, draw in ICONS.items():
        draw().image().save(OUT / f"{key}.png")
    return OUT


if __name__ == "__main__":
    from pixel_kit import preview
    preview([draw() for draw in ICONS.values()], "out/materiales.png", scale=10)
