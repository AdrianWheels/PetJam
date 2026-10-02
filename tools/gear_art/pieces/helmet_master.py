"""Casco maestro en T.

La fila de abajo es la franja de la visera de lado a lado (rendija, ribete dorado y gema rosa), cortada justo
encima de las respiraderas; la casilla de arriba es la parte alta del casco con la punta y su ribete dorado. En el
original la punta queda a la izquierda, así que la parte alta se inclina (cizalla con la base fija, sin costura)
para que la punta suba por el centro. Todo se aplasta un 12 % en vertical para caber en la T.
"""
from PIL import Image

X0, X1 = 137, 948  # ancho del casco en el original
TOP = 35           # fila de la punta
JOINT = 360        # fila donde empieza la franja de la visera (la parte alta queda encima)
BOTTOM = 630       # fila donde se corta la franja (justo encima de las respiraderas)
PEAK = 325         # x de la punta en el original
SQUASH = 0.88


def prepare(img: Image.Image) -> Image.Image:
    w = X1 - X0
    ht = JOINT - TOP
    top = img.crop((X0, TOP, X1, JOINT))
    a = ((X0 + X1) // 2 - PEAK) / ht  # la punta se desplaza hasta el centro; la fila JOINT no se mueve
    top = top.transform(top.size, Image.AFFINE, (1, a, -a * ht, 0, 1, 0), resample=Image.BICUBIC)
    band = img.crop((X0, JOINT, X1, BOTTOM))
    out = Image.new("RGBA", (w, ht + band.height), (0, 0, 0, 0))
    out.alpha_composite(top, (0, 0))
    out.alpha_composite(band, (0, ht))
    return out.resize((out.width, round(out.height * SQUASH)), Image.LANCZOS)
