"""Casco avanzado: el yelmo es casi cuadrado y la forma es 2×1; se ensancha un 20 % en horizontal
para que el recorte de arriba y abajo (fit cover) no se coma la visera."""
from PIL import Image


def prepare(img: Image.Image) -> Image.Image:
    return img.resize((round(img.width * 1.2), img.height), Image.LANCZOS)
