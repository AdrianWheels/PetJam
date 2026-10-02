"""Botas avanzadas: del par se queda la bota de delante (la izquierda, la más completa, puntera a la derecha).

La forma es una L (caña en la columna izquierda, pie en la casilla de abajo a la derecha), así que:
1. se borra la bota de detrás con un polígono hecho a mano;
2. se inclina (cizalla) la caña hacia la izquierda para que quepa en su columna y la puntera salga a la derecha;
3. se estira un poco en horizontal (STRETCH, por debajo del 20 %) para que el pie llegue a la casilla de la derecha.
"""
from PIL import Image, ImageChops, ImageDraw

# Contorno de la bota de delante (coordenadas del original de 1024x1024).
POLY = [
    (0, 0), (500, 0), (500, 145), (450, 235), (446, 290), (420, 312), (414, 375), (392, 392),
    (392, 490), (400, 540), (417, 590), (440, 610), (452, 640), (450, 668), (470, 690), (500, 712),
    (510, 738), (565, 752), (612, 767), (642, 783), (668, 812), (688, 843), (694, 862), (684, 888),
    (672, 905), (650, 935), (0, 1024),
]
SHEAR = 0.09  # px de desplazamiento a la izquierda por px de altura (la caña se inclina hacia atrás)
STRETCH = 1.18  # estirado horizontal


def prepare(img: Image.Image) -> Image.Image:
    m = Image.new("L", img.size, 0)
    ImageDraw.Draw(m).polygon(POLY, fill=255)
    img = img.copy()
    img.putalpha(ImageChops.multiply(img.getchannel("A"), m))
    img = img.crop(img.getchannel("A").point(lambda v: 255 if v > 40 else 0).getbbox())
    pad = int(SHEAR * img.height) + 4
    padded = Image.new("RGBA", (img.width + pad, img.height), (0, 0, 0, 0))
    padded.paste(img, (pad, 0))
    h = padded.height
    # salida (x, y) <- entrada (x + SHEAR * (h - y), y): abajo no se mueve, arriba va a la izquierda
    sheared = padded.transform(padded.size, Image.AFFINE, (1, -SHEAR, SHEAR * h, 0, 1, 0), resample=Image.BICUBIC)
    return sheared.resize((round(sheared.width * STRETCH), sheared.height), Image.LANCZOS)
