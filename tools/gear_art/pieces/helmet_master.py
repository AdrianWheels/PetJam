"""Casco maestro: imagen hecha en ChatGPT sobre la plantilla de la T (doc/arte/plantillas/helmet_master.png),
con fondo blanco. Se quita el blanco que toca el borde de la imagen; los brillos blancos del metal quedan."""
import numpy as np
from PIL import Image
from scipy import ndimage


def prepare(img: Image.Image) -> Image.Image:
    a = np.array(img.convert("RGBA"))
    rgb = a[..., :3].astype(int)
    white = rgb.min(axis=2) > 235
    lab, _ = ndimage.label(white)
    edge = np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))
    bg = np.isin(lab, edge[edge > 0])
    bg = ndimage.binary_dilation(bg, iterations=1)  # el halo claro del recorte
    a[..., 3] = np.where(bg, 0, 255)
    return Image.fromarray(a)
