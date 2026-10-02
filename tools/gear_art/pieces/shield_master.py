"""Escudo maestro: el original es más ancho que 2:3; se estira un 20 % en vertical para que llene el 2×3."""
from PIL import Image


def prepare(img: Image.Image) -> Image.Image:
    return img.resize((img.width, round(img.height * 1.2)), Image.LANCZOS)
