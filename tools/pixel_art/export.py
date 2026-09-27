"""Exporta el elenco: tiras de 2 fotogramas (reposo) por personaje y una hoja PNG para revisar."""
import os

from PIL import Image, ImageDraw, ImageFont

import bosses
import enemies
import fonts
import game_assets
import hero
import smith
from pixel_kit import PALETTE

# Rutas relativas a esta carpeta, se lance desde donde se lance
os.chdir(os.path.dirname(os.path.abspath(__file__)))
OUT = "out/strips"
os.makedirs(OUT, exist_ok=True)


def bob(s, y_to, dy=1):
    """Fotograma B: la banda de filas 0..y_to baja dy px (respiración/flotación).
    El contorno de la banda no tapa color de la parte fija y luego se repara el contorno."""
    out = s.copy()
    for y in range(0, y_to + 1):
        out.px[y] = ['.'] * s.w
    for y in range(0, y_to + 1):
        ny = y + dy
        if ny >= s.h:
            continue
        for x, ch in enumerate(s.px[y]):
            if ch == '.':
                continue
            if ch == 'O' and ny > y_to and s.px[ny][x] not in ('.', 'O'):
                continue
            out.px[ny][x] = ch
    out.outline()
    return [s, out]


def magma_frames():
    a, b = bob(bosses.senor_magma(embers=False), 31)
    # ascuas que suben entre fotogramas (sin contorno)
    a.put(1, 17, "2").put(4, 22, "3").put(3, 4, "2")
    b.put(0, 18, "3").put(2, 21, "2").put(1, 5, "3")
    return [a, b]


CAST = {
    "tico0": bob(hero.build(0), 21),
    "tico1": bob(hero.build(1), 21),
    "tico2": bob(hero.build(2), 21),
    "brasa": bob(smith.smith(), 22),
    "limo": bob(enemies.slime(), 22),
    "esqueleto": bob(enemies.skeleton(), 19),
    "murcielago": [enemies.bat(0), enemies.bat(1)],
    "golem": bob(enemies.golem(), 23),
    "espectro": bob(enemies.wraith(), 30),
    "rey": bob(bosses.rey_osario(), 35),
    "madre": bob(bosses.madre_musgo(), 24),
    "magma": magma_frames(),
    "coloso": bob(bosses.coloso_escarcha(), 31),
    "heraldo": bob(bosses.heraldo_vacio(), 46),
}


def strip(frames):
    w, h = frames[0].w, frames[0].h
    img = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        img.alpha_composite(f.image(), (i * w, 0))
    return img


for name, frames in CAST.items():
    strip(frames).save(f"{OUT}/{name}.png")

# Hoja de revisión con los fotogramas A y B uno junto al otro (para cazar saltos raros)
check = Image.new("RGBA", (48 * 2 * 7 + 8 * 8, 48 * 2 + 24), (52, 38, 44, 255))
x = 8
for i, name in enumerate(["tico2", "brasa", "limo", "rey", "madre", "magma", "coloso"]):
    img = strip(CAST[name])
    check.alpha_composite(img, (x, 12 + (48 - img.height)))
    x += img.width + 8
check = check.resize((check.width * 3, check.height * 3), Image.NEAREST)
check.save("out/review_frames.png")

# ── Hoja de presentación ──
BG = (26, 18, 23, 255)
INK = (244, 231, 210, 255)
MUTED = (191, 165, 147, 255)
EMBER = (255, 186, 69, 255)
F_TITLE = ImageFont.truetype("C:/Windows/Fonts/bahnschrift.ttf", 54)
F_SEC = ImageFont.truetype("C:/Windows/Fonts/segoeuib.ttf", 30)
F_NAME = ImageFont.truetype("C:/Windows/Fonts/segoeuib.ttf", 24)
F_SUB = ImageFont.truetype("C:/Windows/Fonts/segoeui.ttf", 19)

SCALE = 5
rows = [
    ("Protagonistas", [("brasa", "Brasa", "la herrera (tú)"), ("tico0", "Tico", "sin forja"),
                       ("tico1", "Tico", "equipo de hierro"), ("tico2", "Tico", "equipo maestro")]),
    ("Enemigos del pasillo", [("limo", "Limo", "salta"), ("esqueleto", "Esqueleto", "tajo"),
                              ("murcielago", "Murciélago", "picado"), ("golem", "Gólem", "machaca"),
                              ("espectro", "Espectro", "orbe")]),
    ("Jefes de bioma", [("rey", "Rey Osario", "Catacumbas"), ("madre", "Madre del Musgo", "Cripta Musgosa"),
                        ("magma", "Señor del Magma", "Caverna de Magma"),
                        ("coloso", "Coloso de Escarcha", "Glaciar Olvidado"),
                        ("heraldo", "Heraldo del Vacío", "Santuario del Vacío")]),
]
CELL = 48 * SCALE + 30
W = 60 * 2 + CELL * 5
H = 150 + sum(90 + (48 if sec == "Jefes de bioma" else 32) * SCALE + 80 for sec, _ in rows) + 30
sheet = Image.new("RGBA", (W, H), BG)
d = ImageDraw.Draw(sheet)
d.text((60, 44), "AFK Armory · el elenco en pixel art", font=F_TITLE, fill=INK)
d.text((60, 108), "Dibujados a mano píxel a píxel · 32×32 y 48×48 · todos miran hacia el héroe",
       font=F_SUB, fill=MUTED)
y = 170
for sec, items in rows:
    d.text((60, y), sec.upper(), font=F_SEC, fill=EMBER)
    y += 60
    size = (48 if sec == "Jefes de bioma" else 32) * SCALE
    x = 60
    for key, name, sub in items:
        img = CAST[key][0].image().resize((CAST[key][0].w * SCALE, CAST[key][0].h * SCALE), Image.NEAREST)
        cx = x + (CELL - img.width) // 2
        sheet.alpha_composite(img, (cx, y + size - img.height))
        tw = d.textlength(name, font=F_NAME)
        d.text((x + (CELL - tw) / 2, y + size + 8), name, font=F_NAME, fill=INK)
        sw = d.textlength(sub, font=F_SUB)
        d.text((x + (CELL - sw) / 2, y + size + 40), sub, font=F_SUB, fill=MUTED)
        x += CELL
    y += size + 110
sheet = sheet.crop((0, 0, W, y))
sheet.convert("RGB").save("out/afk_armory_personajes.png")
# ── Recursos del juego: tiras a escala 1 y medidas en art/sprites/pixel ──
GAME_KEYS = {
    "hero/tico_0": "tico0", "hero/tico_1": "tico1", "hero/tico_2": "tico2",
    "enemies/slime": "limo", "enemies/skeleton": "esqueleto", "enemies/bat": "murcielago",
    "enemies/golem": "golem", "enemies/wraith": "espectro",
    "bosses/boss_0": "rey", "bosses/boss_1": "madre", "bosses/boss_2": "magma",
    "bosses/boss_3": "coloso", "bosses/boss_4": "heraldo",
}
game_assets.export_game({key: CAST[name] for key, name in GAME_KEYS.items()})
print("sprites del juego en", game_assets.SPRITES)
fonts.export_fonts()
print("fuentes pixel en", fonts.FONT_DIR)
print("colores en paleta:", len(PALETTE))
print("ok", sheet.size)
