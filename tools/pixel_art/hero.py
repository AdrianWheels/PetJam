from pixel_kit import Sprite, preview


def hero_base():
    """Tico, el héroe: 32x32, mirando a la derecha, pies en la fila 28."""
    s = Sprite(32, 32)
    # ── Pelo: puntas, masa con reflejo y flequillo ──
    s.put(1, 11, "h").put(1, 14, "hh").put(1, 19, "H")
    s.put(2, 10, "hh").put(2, 13, "hhhh").put(2, 18, "HHH")
    s.put(3, 9, "hhhwwwhhhhHHHH")
    s.put(4, 8, "hhhwwwhhhhhHHHH")
    s.put(5, 8, "Hhwwhhhhhhhhk" + "HH")
    s.put(6, 8, "HHhhhhhhHHHHHkk")
    s.put(7, 8, "kHHhhH" + "HsHssHss")
    # ── Cara (mira a la derecha): ojos, rubor, boca ──
    s.put(8, 8, "kHHHS" + "sssKssKs" + "S")
    s.put(9, 8, "kHHHS" + "sssKssKs" + "S")
    s.put(10, 8, "kkHHS" + "s6ssssss" + "S")
    s.put(11, 9, "kkHS" + "sssssqsS")
    s.put(12, 10, "kH" + "SSSSSSSS")
    # ── Bufanda roja: banda al cuello, nudo delante, cola ondeando hacia atrás ──
    s.put(13, 8, "RRr" + "rrrrrrrrrRx")
    s.put(14, 5, "xRRRRr" + "RRrrrrrRRx")
    s.put(15, 3, "xRRRr")
    s.put(16, 1, "xRRx")
    s.put(17, 0, "xx")
    s.put(15, 19, "rR").put(16, 19, "Rx").put(17, 20, "x")
    # ── Brazo trasero (más oscuro, detrás del cuerpo) ──
    s.put(15, 10, "d").put(16, 10, "d").put(17, 10, "d").put(18, 10, "q").put(19, 10, "q")
    # ── Chaleco de cuero ──
    s.put(15, 11, "llLLLLLLd")
    s.put(16, 11, "lLLLLLLLd")
    s.put(17, 11, "lLLLLLLdd")
    s.put(18, 11, "lLLLLLLLd")
    s.put(19, 11, "ddddGddddd")  # cinturón con hebilla
    s.put(20, 11, "lLLLLLLLLd")
    s.put(21, 11, "dLLLLLLLLd")
    # ── Brazo delantero y mano ──
    s.put(16, 19, "L").put(17, 19, "LL").put(18, 20, "L")
    s.put(18, 21, "ss").put(19, 21, "sS")
    # ── Piernas ──
    for y in (22, 23, 24):
        s.put(y, 12, "nnB").put(y, 16, "bBB")
    # ── Botas de cuero ──
    s.put(25, 11, "kddd").put(25, 16, "Lddd")
    s.put(26, 11, "kddd").put(26, 16, "Ldddd")
    s.put(27, 11, "kdddd").put(27, 16, "Lddddd")
    s.put(28, 11, "kkkkk").put(28, 16, "kkkkkk")
    return s


# ─── Armas y equipo (capas encima del cuerpo base) ────────────────────────

def stick(s):
    """Palo de madera: lo único que tiene sin la herrera."""
    s.put(22, 20, "vW").put(21, 20, "Ww").put(20, 22, "w")
    s.put(17, 23, "Ww").put(16, 23, "Ww").put(15, 24, "Ww")
    s.put(14, 24, "WWv").put(13, 25, "wWv").put(12, 25, "wWWv")
    s.put(11, 26, "wWW").put(10, 26, "wwW")
    s.put(18, 21, "ss").put(19, 21, "sS")  # la mano por encima del mango
    return s


def sword_iron(s):
    """Espada de hierro (básica)."""
    # hoja en diagonal hacia arriba-delante
    s.put(17, 22, "mM").put(16, 23, "mM").put(15, 24, "mM").put(14, 25, "mM")
    s.put(13, 26, "mM").put(12, 27, "mM").put(11, 28, "mi").put(10, 29, "m")
    # guarda y empuñadura
    s.put(19, 20, "ii").put(18, 23, "i").put(20, 21, "d").put(21, 20, "d")
    s.put(18, 21, "ss").put(19, 21, "sS")
    return s


def sword_master(s):
    """Espada maestra: hoja más larga con filo azul y guarda dorada."""
    s.put(17, 22, "mb").put(16, 23, "mb").put(15, 24, "mb").put(14, 25, "mb")
    s.put(13, 26, "mb").put(12, 27, "mb").put(11, 28, "mb").put(10, 29, "mb")
    s.put(9, 30, "mb").put(8, 30, "m").put(7, 31, "m")
    s.put(19, 19, "gGG").put(18, 23, "g").put(17, 24, "G")
    s.put(20, 21, "d").put(21, 20, "gj")
    s.put(18, 21, "ss").put(19, 21, "sS")
    return s


def shield_wood(s):
    """Escudo redondo de madera con tachón de hierro, en el brazo trasero."""
    s.put(14, 7, "vWWv")
    s.put(15, 6, "vWwwWv")
    s.put(16, 5, "vWwWWwWv")
    s.put(17, 5, "vwWMMWwv")
    s.put(18, 5, "vWWMiWWv")
    s.put(19, 5, "vwWWWWwv")
    s.put(20, 6, "vWwwWv")
    s.put(21, 7, "vWWv")
    return s


def shield_master(s):
    """Escudo de cometa de acero con borde dorado y emblema azul."""
    s.put(13, 5, "gggggg")
    s.put(14, 5, "gmmmMg")
    s.put(15, 5, "gmbbMg")
    s.put(16, 5, "gmbBMg")
    s.put(17, 5, "gmbBMg")
    s.put(18, 5, "gMbBig")
    s.put(19, 6, "gMMig")
    s.put(20, 6, "gMig")
    s.put(21, 7, "gig")
    s.put(22, 7, "gg")
    return s


def helmet_iron(s):
    """Casco de hierro redondo con borde de cuero (sustituye la parte alta del pelo)."""
    for y in range(0, 6):
        s.erase(y, 6, 20)
    s.put(1, 12, "MMMMM")
    s.put(2, 10, "MmmmmMMMM")
    s.put(3, 9, "MmmmmmMMMMi")
    s.put(4, 8, "MmmmmmMMMMMii")
    s.put(5, 8, "MMmmmmMMMMMiiI")
    s.put(6, 8, "ddddddddddddddd")
    return s


def helmet_master(s):
    """Yelmo con cresta de plumas azul y remate dorado."""
    helmet_iron(s)
    s.put(6, 8, "jgggggggggggggj")
    s.put(0, 14, "bb").put(0, 16, "B")
    s.put(1, 12, "gbbbB")
    s.put(1, 9, "bB").put(2, 7, "bBB").put(3, 6, "bB")  # plumas cayendo hacia atrás
    return s


def boots_master(s):
    """Grebas de acero con puntera dorada."""
    s.put(25, 11, "IMMm").put(25, 16, "mMMi")
    s.put(26, 11, "IMMm").put(26, 16, "mMMMi")
    s.put(27, 11, "IiMMm").put(27, 16, "mMMMMi")
    s.put(28, 11, "jGGGG").put(28, 16, "gGGGGj")
    return s


def build(stage):
    s = hero_base()
    if stage == 0:
        stick(s)
    elif stage == 1:
        shield_wood(s)
        sword_iron(s)
        helmet_iron(s)
    else:
        shield_master(s)
        sword_master(s)
        helmet_master(s)
        boots_master(s)
    s.outline()
    return s


if __name__ == "__main__":
    stages = [build(i) for i in range(3)]
    for i, st in enumerate(stages):
        st.save(f"out/hero_{i}.png", 1)
    preview(stages, "out/review_hero.png", scale=10)
    print("ok")
