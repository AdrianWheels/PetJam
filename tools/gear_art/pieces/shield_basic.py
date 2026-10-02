"""Escudo básico (1×2 vertical) desde shield_advanced.png, que es casi cuadrado.

Quita una franja vertical del centro (x 336-689 del original de 1024 px), junta los dos lados y estrecha
el resultado un 20 % en horizontal: queda un escudo alto y estrecho (proporción ~0,45) que conserva el
marco y las tablas. El corte es casi simétrico respecto al centro para que la curva del marco case. Arriba
se va el remache del centro y quedan enteros los dos de los lados; abajo el corte pasa justo por el centro
de los remaches de x 337 y x 690, así que la mitad izquierda de uno y la derecha del otro forman un solo
remache centrado. Un fundido de pocos px suaviza la unión de las tablas (las dos son rojizas).
"""
from PIL import Image

CUT = (336, 689)  # franja que se quita, en px del original de 1024
BLEND = 6  # px de fundido a cada lado de la unión
SQUASH = 0.8  # estrechamiento horizontal tras juntar (lo máximo permitido: 20 %)


def prepare(img: Image.Image) -> Image.Image:
    k = img.width / 1024
    x0, x1 = round(CUT[0] * k), round(CUT[1] * k)
    b = max(1, round(BLEND * k))
    left = img.crop((0, 0, x0, img.height))
    right = img.crop((x1, 0, img.width, img.height))
    out = Image.new("RGBA", (left.width + right.width, img.height), (0, 0, 0, 0))
    out.paste(left, (0, 0))
    out.paste(right, (left.width, 0))
    # Fundido: los últimos b px de la izquierda se mezclan con los b px que había justo tras el corte.
    for i in range(b):
        t = (i + 1) / (b + 1)
        col_l = img.crop((x0 - b + i, 0, x0 - b + i + 1, img.height))
        col_r = img.crop((x1 - b + i, 0, x1 - b + i + 1, img.height))
        out.paste(Image.blend(col_l, col_r, t), (x0 - b + i, 0))
    return out.resize((round(out.width * SQUASH), out.height), Image.LANCZOS)
