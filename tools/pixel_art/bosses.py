import math

from pixel_kit import Sprite, preview

# Jefes: 48x48, dibujados mirando a la DERECHA y volteados al final (miran al héroe).


def rey_osario():
    """Rey Osario (Catacumbas): calavera coronada, capa real, cetro."""
    s = Sprite(48, 48)
    # ── Capa (detrás de todo) ──
    for y in range(20, 45):
        left = 12 - (y - 20) * 7 // 24
        right = 30 + (y - 20) * 6 // 24
        row = ""
        for x in range(left, right + 1):
            rel = x - left
            if rel in (3, 9) or x == right - 5:
                row += "Z"
            elif x < left + 3:
                row += "P"
            elif x > right - 4:
                row += "Z"
            else:
                row += "z"
        s.put(y, left, row)
    s.put(45, 6, "Z.zZ.Z.zZZ.Z.zZ.ZZ.zZ.Z.zZ.ZZ")  # bajo raído
    # cuello alto de la capa con ribete dorado
    for y in range(14, 22):
        s.put(y, 12, "GzzP")
    s.put(13, 13, "GGG")
    # ── Calavera ──
    s.put(7, 21, "eeeeeeEEE")
    s.put(8, 19, "eeeeeeeeeEEEE")
    s.put(9, 18, "eeeueeeeeeeEEEE")
    s.put(10, 17, "eeeeueeeeeeeeEEEu")
    s.put(11, 17, "eeeueeeeeeeeeeEEu")
    s.put(12, 17, "eeeee" + "KKK" + "ee" + "KKK" + "eEEu")
    s.put(13, 17, "eeeee" + "K5K" + "ee" + "K5K" + "eEEu")
    s.put(14, 17, "eeeee" + "K5K" + "ee" + "K5K" + "eEuu")
    s.put(15, 17, "Eeeee" + "KKK" + "ee" + "KKK" + "Euuu")
    s.put(16, 17, "Eeeeeeee" + "KK" + "eeeeEuu")
    s.put(17, 18, "EEeeeeeKeeeeEuu")
    s.put(18, 19, "uEeeeeeeeeEEu")
    s.put(19, 19, "uKeKeKeKeKeKu")
    s.put(20, 19, "uKeKeKeKeKeKu")
    s.put(21, 20, "uEEEEEEEEEu")
    # ── Corona ──
    s.put(2, 20, "g").put(2, 25, "g").put(2, 31, "g")
    s.put(3, 19, "ggG").put(3, 24, "gggG").put(3, 30, "gGj")
    s.put(4, 19, "gGG").put(4, 23, "ggggGG").put(4, 30, "gGj")
    s.put(5, 19, "gggggggggggGGj")
    s.put(6, 19, "ggRggg5gggRGGj")
    s.put(7, 19, "GGGGGGGGGGGGjj")
    # ── Costillar con amuleto ──
    s.put(22, 21, "EeeeeeeeE")
    s.put(23, 19, "eeeeeeeeeeeEu")
    s.put(24, 19, "999999E999999")
    s.put(25, 19, "eeeeeegeeeeEu")
    s.put(26, 20, "99999G99999")
    s.put(27, 20, "eeeeeeeeeEu")
    s.put(28, 21, "9999E9999")
    s.put(29, 21, "eeeeeeeEu")
    s.put(30, 22, "999E999")
    s.put(31, 24, "EEu")
    s.put(32, 20, "uEeeeeeeeEu")
    s.put(33, 20, "Ee9eeEee9eE")
    s.put(34, 19, "GPPPPPPPPPzzG").put(35, 20, "PzPzzPzPzzP")
    # ── Piernas ──
    for y in range(36, 44):
        s.put(y, 21, "uE").put(y, 27, "eE")
    s.put(39, 20, "EEu").put(39, 27, "eEE")
    s.put(44, 19, "EEeu").put(44, 27, "eeEEu")
    s.put(45, 19, "uuuu").put(45, 27, "uuuuu")
    # ── Brazo delantero y cetro ──
    s.put(22, 31, "e").put(23, 32, "ee").put(24, 33, "e").put(25, 34, "E").put(26, 34, "E")
    for y in range(9, 46):
        s.put(y, 36, "gj")
    s.put(26, 35, "eee").put(27, 35, "eEE")
    s.put(3, 35, "gggG")
    s.put(4, 34, "gGGGGj")
    s.put(5, 34, "g55RGj")
    s.put(6, 34, "gRRRGj")
    s.put(7, 34, "gGGGGj")
    s.put(8, 35, "jGGj")
    s.outline()
    return s.flip()


def madre_musgo():
    """Madre del Musgo (Cripta Musgosa): planta carnívora con casquete de musgo florido, fauces y hojas-brazo."""
    s = Sprite(48, 48)
    # ── Raíces y montículo de tierra con musgo ──
    s.fill_poly([(10, 46), (13, 41), (20, 39), (28, 39), (35, 41), (38, 46)],
                lambda x, y: 'A' if y <= 40 else ('W' if x < 22 else 'v'))
    s.put(46, 4, "vvWW").put(45, 6, "vW").put(46, 38, "WWvvv").put(45, 38, "vW").put(44, 40, "v")
    s.put(41, 15, "6").put(40, 16, "7").put(41, 30, "6").put(40, 31, "7")
    # ── Tallo grueso ──
    s.fill_poly([(21, 22), (29, 22), (27, 31), (27, 40), (19, 40), (20, 31)],
                lambda x, y: 'A' if x < 23 else ('c' if x < 26 else 'C'))
    for y in (26, 30, 34, 37):
        s.put(y, 21, "cc")
    # ── Hoja trasera (brazo izquierdo) ──
    s.fill_poly([(21, 31), (13, 24), (3, 19), (7, 26), (15, 32)],
                lambda x, y: 'a' if (x + y) % 7 == 0 else 'A')
    for x, y in [(19, 30), (17, 28), (15, 27), (13, 25), (11, 24), (9, 23), (7, 22), (5, 21)]:
        s.put(y, x, "c")
    # ── Hoja delantera (brazo derecho) ──
    s.fill_poly([(26, 32), (34, 28), (44, 30), (38, 35), (29, 36)],
                lambda x, y: 'a' if y < 31 else ('A' if y < 34 else 'c'))
    for x, y in [(28, 33), (30, 32), (32, 32), (34, 31), (36, 31), (38, 31), (40, 31), (42, 30)]:
        s.put(y, x, "c")
    # ── Bulbo: casquete de musgo arriba, carne roja abajo ──
    def bulb(x, y, nx, ny):
        if ny < -0.12 + 0.13 * math.sin(x * 1.7):
            if (x * 3 + y * 2) % 7 == 0:
                return 'c'
            if -nx * 0.6 - ny > 1.0:
                return 'a'
            return 'c' if nx > 0.45 else 'A'
        if nx > 0.55 or ny > 0.72:
            return 'x'
        if nx < -0.35 and ny < 0.35:
            return '6'
        return 'R'
    s.fill_ellipse(25.5, 14.5, 11.5, 10.5, bulb)
    # el musgo gotea sobre la carne
    for x, n in [(15, 2), (16, 3), (18, 1), (19, 3), (21, 2), (23, 1)]:
        ys = [y for y in range(48) if s.px[y][x] in ('A', 'c', 'a')]
        if ys:
            for k in range(1, n + 1):
                s.put(ys[-1] + k, x, 'A' if k < n else 'c')
    # ── Fauces abiertas hacia el héroe, con labios rojos ──
    for y in range(8, 22):
        x0 = int(27 + abs(y - 14.5) * 1.55)
        s.put(y, x0 - 2, "RR" + "9" * max(0, 38 - x0))
    s.put(14, 30, "666666").put(15, 30, "66666R").put(13, 32, "x")
    for x, y in [(30, 11), (32, 10), (34, 9), (36, 8)]:
        s.put(y, x, "e").put(y + 1, x, "E")
    for x, y in [(30, 18), (32, 19), (34, 20), (36, 21)]:
        s.put(y, x, "e").put(y - 1, x, "E")
    # ── Flores y un brote sobre el musgo ──
    for fx, fy in [(18, 5), (24, 3)]:
        s.put(fy - 1, fx, "6").put(fy, fx - 1, "616").put(fy + 1, fx, "6")
    s.put(3, 29, "7").put(4, 29, "c").put(4, 30, "A")
    # ── Ojos amarillos de pupila rasgada asomando del musgo ──
    for ex, ey in [(23, 10), (28, 7)]:
        s.put(ey - 1, ex, "CCC")
        s.put(ey, ex, "1K1").put(ey + 1, ex, "2K2")
    s.outline()
    return s.flip()


def _rock(cx, cy, rw, rh, dark=0.0):
    """Sombreado de basalto con luz arriba-izquierda: D claro, N medio, V sombra (dark lo oscurece todo)."""
    def f(x, y, *_):
        l = -(x + 0.5 - cx) / rw - (y + 0.5 - cy) / rh * 1.4 - dark
        return 'D' if l > 0.45 else ('V' if l < -0.5 else 'N')
    return f


def _flames(s, tongues, base):
    """Masa de fuego continua: cada lengua (cx, punta, semiancho) crece hasta la fila base."""
    heat = {}
    for cx, tip, hw in tongues:
        for y in range(tip, base + 1):
            t = (y - tip) / max(1, base - tip)
            half = hw * t ** 0.6 + 0.4
            for x in range(int(cx - half) - 1, int(cx + half) + 2):
                d = abs(x + 0.5 - cx)
                if d <= half:
                    h = (1 - d / half) * (0.3 + 0.7 * t)
                    heat[(x, y)] = max(heat.get((x, y), 0), h)
    for (x, y), h in heat.items():
        s.put(y, x, '1' if h > 0.7 else ('2' if h > 0.42 else ('3' if h > 0.14 else '4')))


MAGMA_HEAD = [
    "..DDDDDDDDDNN..",
    ".DDDNNNNNNNNNV.",
    "DDNNNNNNNNNNNVV",
    "DNDDDDDDDDDDDDV",
    "DNNVV12VVVV12VV",
    "NNNNV23VNNV23VV",
    "NNNNNNNNNNNNNVV",
    "NNNNV43434343VV",
    "VNNNV32121212VV",
    "VVNNV43434343V.",
    ".VVNNVVVVVVVVV.",
    "..VVVVVVVVVVV..",
]


def senor_magma(embers=True):
    """Señor del Magma (Caverna de Magma): titán de basalto encorvado, grietas de lava y corona de llamas."""
    s = Sprite(48, 48)
    # ── Brazo y puño traseros, en sombra ──
    back = Sprite(48, 48)
    back.fill_poly([(6, 21), (13, 20), (13, 30), (10, 34), (5, 34), (4, 27)], _rock(8, 24, 10, 14, 0.4))
    back.fill_poly([(2, 33), (12, 32), (14, 36), (13, 43), (3, 43), (1, 39)], _rock(6, 35, 12, 10, 0.3))
    s.stamp(back)
    # ── Piernas y pies ──
    legs = Sprite(48, 48)
    legs.fill_poly([(14, 35), (21, 35), (21, 43), (14, 43)], _rock(16, 36, 8, 8, 0.5))
    legs.fill_poly([(22, 35), (29, 35), (29, 43), (22, 43)], _rock(24, 36, 8, 8))
    legs.put(43, 12, "NNNNNNNNNV").put(44, 12, "NNNNNNNNNV").put(45, 12, "VVVVVVVVVV")
    legs.put(43, 21, "DDNNNNNNNNV").put(44, 21, "DNNNNNNNNNV").put(45, 21, "VVVVVVVVVVV")
    s.stamp(legs, edge='V')
    # ── Torso con joroba ──
    torso = Sprite(48, 48)
    torso.fill_poly([(8, 25), (10, 17), (16, 12), (24, 10), (29, 11), (33, 15), (35, 22), (34, 31), (30, 36),
                     (15, 37), (10, 33)], _rock(20, 20, 26, 24))
    s.stamp(torso, edge='V')
    # ── Hombro y antebrazo delanteros ──
    arm = Sprite(48, 48)
    arm.fill_ellipse(35.5, 22.5, 6, 4.5, _rock(34, 20, 8, 6))
    arm.fill_poly([(32, 25), (41, 24), (43, 33), (35, 34)], _rock(36, 26, 10, 12))
    s.stamp(arm, edge='V')
    # ── Cabeza adelantada ──
    head = Sprite(48, 48)
    head.rows(9, 26, MAGMA_HEAD)
    s.stamp(head, edge='V')
    # ── Puño delantero con dedos ──
    fist = Sprite(48, 48)
    fist.fill_poly([(31, 33), (43, 32), (46, 36), (45, 44), (33, 44), (30, 39)], _rock(35, 34, 14, 12))
    fist.line([(40, 36), (45, 36)], 'V').line([(40, 39), (45, 39)], 'V').line([(40, 42), (44, 42)], 'V')
    fist.put(37, 41, "DD").put(40, 41, "DD").put(43, 41, "D")
    s.stamp(fist, edge='V')
    s.put(36, 40, "3").put(39, 40, "3").put(42, 39, "2")     # lava entre los dedos
    # ── Corazón de magma y grietas que dibujan placas ──
    s.rows(20, 17, ["...4...", "..434..", ".43234.", "4321234", ".43234.", "..434..", "...4..."])
    s.line([(12, 18), (15, 23), (13, 29), (16, 35)], '3')
    s.line([(15, 23), (17, 23)], '3')
    s.line([(19, 13), (21, 19)], '4')
    s.line([(22, 27), (25, 31), (24, 35)], '3')
    s.line([(13, 29), (19, 30)], '4')
    s.line([(24, 22), (28, 20)], '4')
    s.line([(37, 26), (38, 30), (36, 33)], '3')
    s.line([(5, 36), (8, 38), (11, 37)], '4')
    s.line([(17, 38), (18, 41)], '4').line([(25, 37), (26, 40)], '3')
    s.put(15, 23, "2").put(25, 31, "2").put(38, 30, "2")
    # ── Corona de llamas ──
    _flames(s, [(28.5, 5, 2.4), (31.5, 2, 2.6), (34.5, 1, 3.2), (37.5, 3, 2.6), (40.0, 6, 1.4)], 10)
    s.outline()
    if embers:
        s.put(0, 30, "2").put(3, 25, "3").put(2, 43, "2")     # ascuas sin contorno
    return s.flip()


def _ice(cx, cy, rw, rh):
    """Sombreado de hielo con luz arriba-izquierda: f brillo, F medio, y sombra, Q sombra honda."""
    def f(x, y, *_):
        l = -(x + 0.5 - cx) / rw - (y + 0.5 - cy) / rh * 1.3
        if l > 0.55:
            return 'f'
        if l > -0.1:
            return 'F'
        if l > -0.6:
            return 'y'
        return 'Q'
    return f


def _shard(s, bx, by, tx, ty, w):
    """Cristal alargado de la base (bx, by) a la punta (tx, ty); cara iluminada f, filo F, sombra y."""
    dx, dy = tx - bx, ty - by
    L = math.hypot(dx, dy)
    nx, ny = -dy / L, dx / L
    if nx + ny > 0:                      # que la normal apunte hacia la luz (arriba-izquierda)
        nx, ny = -nx, -ny
    hw = w / 2
    mx, my = bx + dx * 0.72, by + dy * 0.72
    pts = [(bx + nx * hw, by + ny * hw), (mx + nx * hw * 0.9, my + ny * hw * 0.9), (tx, ty),
           (mx - nx * hw * 0.9, my - ny * hw * 0.9), (bx - nx * hw, by - ny * hw)]

    def shade(x, y):
        d = (x + 0.5 - bx) * nx + (y + 0.5 - by) * ny
        return 'f' if d > hw * 0.25 else ('F' if d > -hw * 0.3 else 'y')
    s.fill_poly(pts, shade)


def coloso_escarcha():
    """Coloso de Escarcha (Glaciar Olvidado): gigante de sillares de hielo, barba de carámbanos y maza de cristal."""
    s = Sprite(48, 48)
    # ── Cristales de la espalda (detrás de todo) ──
    spikes = Sprite(48, 48)
    _shard(spikes, 13, 19, 4, 4, 6)
    _shard(spikes, 18, 16, 15, 3, 5)
    _shard(spikes, 10, 24, 2, 15, 5)
    s.stamp(spikes)
    # ── Brazo trasero y puño, en sombra ──
    back = Sprite(48, 48)
    back.fill_poly([(8, 20), (15, 20), (14, 31), (12, 33), (6, 33), (6, 26)], _ice(6, 20, 10, 14))
    back.fill_poly([(4, 32), (13, 32), (14, 38), (12, 39), (5, 39), (3, 36)], _ice(5, 31, 10, 8))
    s.stamp(back, edge='Q')
    # ── Piernas-pilar y pies ──
    legs = Sprite(48, 48)
    legs.fill_poly([(15, 35), (22, 35), (22, 43), (15, 43)], _ice(15, 34, 8, 10))
    legs.fill_poly([(25, 35), (32, 35), (32, 43), (25, 43)], _ice(26, 36, 8, 10))
    legs.put(43, 14, "fFFFFFFFy").put(44, 14, "FFFFFFFFyQ").put(45, 14, "QQQQQQQQQQ")
    legs.put(43, 24, "fFFFFFFFFy").put(44, 24, "FFFFFFFFFyQ").put(45, 24, "QQQQQQQQQQQ")
    s.stamp(legs, edge='Q')
    # ── Torso de sillares de hielo ──
    torso = Sprite(48, 48)
    torso.fill_poly([(10, 21), (14, 15), (24, 13), (33, 15), (37, 20), (37, 30), (33, 36), (14, 36), (11, 31)],
                    _ice(20, 18, 24, 22))
    torso.line([(12, 26), (18, 26)], 'y').line([(21, 26), (35, 26)], 'y')
    torso.line([(14, 31), (26, 31)], 'y').line([(29, 31), (35, 31)], 'y')
    torso.line([(19, 27), (19, 30)], 'y').line([(27, 32), (27, 35)], 'y').line([(31, 27), (31, 30)], 'y')
    torso.line([(16, 32), (16, 35)], 'y')
    torso.put(27, 13, "f").put(27, 22, "f").put(32, 17, "f").put(32, 20, "f").put(15, 22, "Y")
    torso.line([(33, 22), (35, 25)], 'Q').line([(24, 33), (25, 35)], 'Q')
    s.stamp(torso, edge='Q')
    # ── Hombro y brazo delanteros (sube la maza) ──
    arm = Sprite(48, 48)
    arm.fill_ellipse(34.5, 18.5, 5, 4.5, _ice(32, 15, 7, 6))
    arm.fill_poly([(32, 21), (38, 20), (41, 26), (37, 28), (33, 25)], _ice(34, 20, 8, 8))
    s.stamp(arm, edge='Q')
    # ── Maza: mango y racimo de cristal ──
    club = Sprite(48, 48)
    club.line([(37, 33), (42, 12)], 'Q').line([(38, 33), (43, 12)], 'y')
    club.fill_poly([(37, 13), (38, 8), (42, 6), (45, 9), (45, 14), (41, 16)], _ice(38, 7, 8, 9))
    _shard(club, 41, 15, 37, 3, 7)
    _shard(club, 42, 14, 45, 3, 6)
    _shard(club, 40, 13, 35, 8, 4)
    club.put(6, 39, "Y").put(8, 42, "f")
    s.stamp(club, edge='Q')
    # ── Mano cerrada sobre el mango ──
    hand = Sprite(48, 48)
    hand.put(20, 38, "fff").put(21, 37, "fFFFy").put(22, 37, "FFFFy").put(23, 37, "yFFyy").put(24, 38, "yyy")
    hand.put(21, 41, "y").put(22, 41, "Q")
    s.stamp(hand, edge='Q')
    # ── Cabeza con corona de carámbanos ──
    head = Sprite(48, 48)
    head.fill_poly([(20, 8), (23, 5), (31, 5), (34, 8), (34, 15), (31, 17), (23, 17), (20, 15)], _ice(23, 7, 12, 10))
    _shard(head, 23, 6, 22, 1, 3)
    _shard(head, 27, 6, 27, 1, 3)
    _shard(head, 31, 6, 32, 2, 3)
    head.put(9, 21, "ffffffffffffy")             # ceño
    head.put(10, 24, "nnnF.nnn").put(11, 24, "nYnF.nYn").put(12, 24, "nnnFFnnn")
    head.put(10, 28, "F").put(11, 28, "F")
    head.put(14, 22, "QQQQQQQQQQQQ")             # sombra bajo la mandíbula
    s.stamp(head, edge='Q')
    # ── Barba de carámbanos sobre el pecho ──
    for x, n in [(22, 4), (24, 7), (26, 10), (28, 8), (30, 11), (32, 6), (34, 3)]:
        for k in range(n):
            s.put(15 + k, x, "fy" if k < n - 1 else "F")
    s.outline()
    return s.flip()


def heraldo_vacio():
    """Heraldo del Vacío (Santuario del Vacío): encapuchado flotante, halo rúnico, túnica abierta al vacío estrellado."""
    s = Sprite(48, 48)
    # ── Halo dorado con runas (detrás) ──
    cx, cy, R = 21.5, 13.5, 11.5
    for y in range(48):
        for x in range(48):
            d = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
            if R - 2 <= d <= R:
                lit = (x + 0.5 - cx) + (y + 0.5 - cy)
                s.px[y][x] = 'g' if lit < -6 else ('G' if lit < 6 else 'j')
    for a in (165, 200, 235, 270, 305, 340):
        r = math.radians(a)
        s.put(int(cy + math.sin(r) * (R - 1)), int(cx + math.cos(r) * (R - 1)), "7")
    # ── Manga trasera y mano con un jirón de vacío ──
    s.fill_poly([(13, 21), (18, 22), (16, 31), (11, 33), (9, 29)], lambda x, y: 'z' if x > 12 else 'P')
    s.put(32, 9, "gG").put(33, 9, "Gj")
    s.put(29, 7, "p").put(27, 8, "7")
    # ── Túnica ──
    def cloth(x, y):
        l = -(x - 22) / 14 - (y - 26) / 30
        return 'P' if l > 0.55 else ('Z' if l < -0.35 else 'z')
    s.fill_poly([(14, 20), (32, 20), (35, 28), (38, 40), (8, 40), (11, 28)], cloth)
    # bajo deshilachado: flota
    s.put(40, 8, "ZzzZ.zzZ.ZzZZ.zZz.ZzZ.Zz.ZZ")
    s.put(41, 9, "ZZ..Zz..ZZ.Z..zZ..ZZ...Z")
    s.put(42, 10, "Z...Z....Z....Z...Z")
    s.put(43, 14, "Z.........Z")
    # ── Túnica abierta: el vacío estrellado ──
    s.fill_poly([(26, 22), (30, 22), (34, 40), (25, 40)], 'K')
    for x, y, c in [(28, 25, 'Y'), (27, 29, 'p'), (30, 31, '7'), (28, 34, 'Y'), (31, 37, 'p'), (27, 38, 'f'), (29, 27, 'z')]:
        s.put(y, x, c)
    s.line([(25, 22), (24, 40)], 'g').line([(31, 22), (35, 40)], 'G')
    s.line([(8, 40), (38, 40)], 'j')
    s.put(40, 24, "g").put(40, 34, "G")
    # ── Capucha puntiaguda con ribete dorado ──
    def hood(x, y):
        l = -(x - 23) / 9 - (y - 12) / 10
        return 'P' if l > 0.5 else ('Z' if l < -0.6 else 'z')
    s.fill_poly([(14, 17), (15, 9), (15, 4), (20, 6), (26, 6), (30, 8), (32, 13), (32, 19), (29, 22), (16, 22)], hood)
    s.fill_ellipse(27.5, 14.5, 3.6, 5.2, 'K')
    for y in range(8, 21):
        row = [x for x in range(48) if s.px[y][x] == 'K' and x < 33]
        if row:
            s.put(y, row[0] - 1, "g")
    s.put(8, 26, "gg").put(20, 26, "Gj")
    # ojo único del vacío
    s.put(12, 26, "p7p").put(13, 25, "p7Y7p").put(14, 26, "p7p")
    # broche dorado en el cuello
    s.put(21, 22, "jgGj").put(22, 23, "Gj")
    # ── Manga delantera, guantelete y báculo ──
    s.fill_poly([(29, 21), (34, 22), (36, 28), (32, 29), (29, 25)], lambda x, y: 'z' if y < 25 else 'Z')
    for y in range(9, 45):
        s.put(y, 36, "zZ" if y % 7 else "Gj")
    s.put(26, 35, "gGG").put(27, 35, "GGj").put(28, 35, "jj")
    # remate: media luna dorada con orbe de vacío
    s.put(8, 34, "gG").put(8, 38, "Gj").put(9, 35, "gGGj")
    s.put(7, 33, "g").put(7, 39, "j").put(6, 33, "g").put(6, 39, "j").put(5, 33, "G").put(5, 39, "j")
    s.fill_ellipse(37.0, 5.0, 2.6, 2.6, 'K')
    s.put(4, 36, "p").put(3, 37, "z").put(5, 37, "7")
    # motas de vacío flotando
    s.put(24, 4, "p").put(31, 42, "7").put(18, 44, "p")
    s.outline()
    return s.flip()


if __name__ == "__main__":
    b = [rey_osario(), madre_musgo(), senor_magma(), coloso_escarcha(), heraldo_vacio()]
    preview(b, "out/review_bosses.png", scale=6)
    print("ok")
