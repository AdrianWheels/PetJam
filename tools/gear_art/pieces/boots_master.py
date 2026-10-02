"""boots_master: del par de grebas se queda con la de delante (la más completa) y la encaja en la L.

La forma es una L alta (caña de 3 casillas a la izquierda, pie abajo a la derecha) y la columna es justo la mitad
del ancho, pero la caña del dibujo es algo más ancha que la mitad de la bota. Así que, siempre anclado en la
parte trasera (talón), cada fila se escala en horizontal: la boca de la caña se estrecha un poco y el pie se
alarga un poco hacia la puntera, con un paso suave entre ambos. Después la caña (solo por encima del tobillo)
se alarga un 30 % en vertical y todo un 15 % más para llenar las 3 casillas de alto.
El volteo para que la puntera mire a la derecha lo hace el JSON ("flip").
"""
import numpy as np
from PIL import Image, ImageChops, ImageDraw

# Contorno (coordenadas del original, 1024x1024) que deja dentro la bota de delante y fuera la de detrás.
FRONT_BOOT = [(575, 0), (588, 40), (592, 150), (600, 250), (615, 350), (635, 420), (652, 480), (578, 550),
              (548, 610), (488, 645), (475, 668), (398, 745), (288, 770), (203, 785), (196, 798), (225, 840),
              (254, 884), (262, 1024), (1024, 1024), (1024, 0)]
ANKLE_Y = 470  # por encima, caña; por debajo, pie (coordenadas del original)
SHAFT_SQUEEZE = 0.80  # ancho de la boca de la caña, arriba del todo
FOOT_STRETCH = 1.15  # ancho del pie, hacia la puntera
BLEND = 120  # filas (bajo el tobillo) en las que se pasa de 1.0 a FOOT_STRETCH
SHAFT_STRETCH = 1.30
GLOBAL_STRETCH = 1.15


def row_factor(y: int, cut: int) -> float:
    if y < cut:
        return SHAFT_SQUEEZE + (1.0 - SHAFT_SQUEEZE) * (y / cut)
    t = min(1.0, (y - cut) / BLEND)
    t = t * t * (3 - 2 * t)
    return 1.0 + (FOOT_STRETCH - 1.0) * t


def reshape_rows(img: Image.Image, cut: int) -> Image.Image:
    """Escala cada fila en horizontal, anclada en el borde trasero (el derecho del original)."""
    a = np.asarray(img).astype(np.float32)
    h, w, _ = a.shape
    ow = round(w * FOOT_STRETCH)
    xs = np.arange(ow, dtype=np.float32)
    out = np.zeros((h, ow, 4), np.float32)
    back_in, back_out = w - 1, ow - 1
    for y in range(h):
        f = row_factor(y, cut)
        src = back_in - (back_out - xs) / f
        valid = src >= 0
        x0 = np.clip(np.floor(src).astype(int), 0, w - 1)
        x1 = np.clip(x0 + 1, 0, w - 1)
        t = (src - np.floor(src))[:, None]
        row = a[y, x0] * (1 - t) + a[y, x1] * t
        row[~valid] = 0
        out[y] = row
    return Image.fromarray(np.clip(out + 0.5, 0, 255).astype(np.uint8), "RGBA")


def prepare(img: Image.Image) -> Image.Image:
    m = Image.new("L", img.size, 0)
    ImageDraw.Draw(m).polygon(FRONT_BOOT, fill=255)
    img = img.copy()
    img.putalpha(ImageChops.multiply(img.getchannel("A"), m))
    box = img.getchannel("A").point(lambda v: 255 if v > 40 else 0).getbbox()
    img = img.crop(box)
    cut = ANKLE_Y - box[1]
    img = reshape_rows(img, cut)
    shaft = img.crop((0, 0, img.width, cut))
    foot = img.crop((0, cut, img.width, img.height))
    shaft = shaft.resize((img.width, round(shaft.height * SHAFT_STRETCH)), Image.LANCZOS)
    out = Image.new("RGBA", (img.width, shaft.height + foot.height), (0, 0, 0, 0))
    out.paste(shaft, (0, 0))
    out.paste(foot, (0, shaft.height))
    return out.resize((out.width, round(out.height * GLOBAL_STRETCH)), Image.LANCZOS)
