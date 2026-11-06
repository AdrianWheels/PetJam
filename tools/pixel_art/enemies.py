from pixel_kit import Sprite, preview

# Todos se dibujan mirando a la DERECHA y al final se voltean (miran al héroe, a su izquierda).


def slime():
    """Limo de cripta: gelatina verde con ojos grandes."""
    s = Sprite(32, 32)
    s.put(13, 13, "aaaaAA")
    s.put(14, 11, "aaYYaaaaAA")
    s.put(15, 9, "aaYYYaaaaaAAAA")
    s.put(16, 8, "aaYYaaaaaaaaAAAA")
    s.put(17, 7, "aaaaaaaaaaaaaaAAAA")
    s.put(18, 6, "aaaaaaaa" + "YK" + "aaa" + "YK" + "aAAAA")
    s.put(19, 6, "aaaaaaaa" + "KK" + "aaa" + "KK" + "aAAAA")
    s.put(20, 6, "Aaaaaaaa" + "KK" + "aaa" + "KK" + "aAAAc")
    s.put(21, 6, "AAaaaa6aaaaaaaa6aAAc")
    s.put(22, 6, "AAaaaaaaaaKKaaaaaAAc")
    s.put(23, 6, "AAAaaaaaaaaaaaaaAAcc")
    s.put(24, 6, "cAAAaaaaaaaaaaaAAAcc")
    s.put(25, 6, "cAAAAAaaaaaaaaAAAccC")
    s.put(26, 6, "ccAAAAAAAAAAAAAAAccC")
    s.put(27, 6, "CcccAAAAAAAAAAAcccCC")
    s.put(28, 7, "CCccccccccccccccCC")
    # gota que resbala
    s.put(25, 26, "A").put(26, 26, "c")
    s.outline()
    return s.flip()


def skeleton():
    """Esqueleto del osario: calavera agrietada, ojos rojos, espada oxidada y taparrabos."""
    s = Sprite(32, 32)
    # calavera
    s.put(3, 13, "eeeeEE")
    s.put(4, 12, "euueeeEEE")
    s.put(5, 11, "eeeueeeeEEE")
    s.put(6, 11, "eeuueeeeeEE")
    s.put(7, 11, "eeee" + "K5" + "e" + "K5" + "EE")
    s.put(8, 11, "eeee" + "KK" + "e" + "KK" + "uE")
    s.put(9, 11, "EeeeeeKeeEu")
    s.put(10, 12, "uEeKeKeKu")
    s.put(11, 13, "uEEEEEu")
    # cuello y costillas
    s.put(12, 15, "Eu")
    s.put(13, 12, "uEeeeeeEu")
    s.put(14, 13, "eeeeeeE")
    s.put(15, 13, "999E999")
    s.put(16, 13, "eeeeeeE")
    s.put(17, 14, "99E99")
    s.put(18, 14, "eeeeE")
    s.put(19, 13, "uEeeeEu")
    # taparrabos rojo hecho jirones
    s.put(20, 12, "RRrrrrRRx")
    s.put(21, 12, "xRRrRRRxx")
    s.put(22, 12, "x.R.Rx.x")
    # piernas y pies
    for y in (22, 23, 25, 26):
        s.put(y, 13, "uE").put(y, 17, "eE")
    s.put(24, 13, "EEu").put(24, 17, "eEE")
    s.put(27, 12, "EEu").put(27, 17, "eEEu")
    # brazo trasero
    s.put(14, 11, "E").put(15, 11, "u").put(16, 10, "E").put(17, 10, "u").put(18, 10, "E")
    # brazo delantero
    s.put(13, 21, "e").put(14, 22, "e").put(15, 22, "E").put(15, 23, "e")
    # espada oxidada en diagonal
    s.put(16, 23, "U").put(14, 24, "U").put(16, 25, "U")
    s.put(14, 25, "To").put(13, 25, "To").put(12, 26, "TW").put(11, 27, "To")
    s.put(10, 27, "tT").put(9, 28, "to").put(8, 28, "t").put(7, 29, "t")
    s.outline()
    return s.flip()


def _sym(s, y, x, text, w=32):
    """Coloca text en (x,y) y su reflejo respecto al centro vertical del lienzo."""
    s.put(y, x, text)
    s.put(y, w - x - len(text), text[::-1])


def bat(frame=0):
    """Murciélago de sombras: frontal, alas desplegadas (frame 0 arriba, 1 abajo)."""
    s = Sprite(32, 32)
    if frame == 0:
        _sym(s, 3, 3, "P")
        _sym(s, 4, 3, "zP")
        _sym(s, 5, 3, "zzP")
        _sym(s, 6, 3, "zzzP")
        _sym(s, 7, 3, "zzzzP")
        _sym(s, 8, 3, "zzZzzPP")
        _sym(s, 9, 3, "zZzzZzzP")
        _sym(s, 10, 4, "Z.zZzzzP")
        _sym(s, 11, 7, "Z.zzP")
        _sym(s, 12, 10, "zP")
    else:
        _sym(s, 10, 2, "PPP")
        _sym(s, 11, 2, "zzPPPPP")
        _sym(s, 12, 2, "zzzzzzzPP")
        _sym(s, 13, 3, "ZzzzzzzP")
        _sym(s, 14, 3, "Z.ZzzzzP")
        _sym(s, 15, 4, "Z..ZzzP")
        _sym(s, 16, 8, "Z.z")
    # orejas y cuerpo
    _sym(s, 6, 13, "P")
    _sym(s, 7, 13, "pz")
    s.put(8, 13, "pPPPPz")
    s.put(9, 12, "pppPPPPz")
    s.put(10, 12, "pp5PP5Pz")
    s.put(11, 12, "pPPPPPPz")
    s.put(12, 12, "PPPKKPPz")
    s.put(13, 12, "PPPYYPPz")
    s.put(14, 13, "zPPPPz")
    s.put(15, 14, "zzzz")
    s.put(16, 14, "z").put(16, 17, "z")
    s.outline()
    return s


def golem():
    """Gólem de mampostería: bloque de piedra con musgo y grietas incandescentes."""
    s = Sprite(32, 32)
    s.put(5, 14, "ttTTo")
    s.put(6, 13, "tttTTTo")
    s.put(7, 13, "t12T12o")
    s.put(8, 13, "tTTTTTo")
    s.put(9, 9, "tttttTTTTTTTTTo")
    s.put(8, 9, "aAa").put(9, 9, "aAAca").put(8, 20, "Aa").put(9, 19, "aAAc")
    for y in range(10, 24):
        s.put(y, 8, "tttTTTTTTTTTTTTTo")
    s.put(10, 8, "ttttTTTTTTTTTTTTo")
    s.put(23, 8, "tTTTTTTTTTTTTTToo")
    # juntas de sillería
    s.put(13, 9, "oooooo").put(13, 18, "oooooo")
    s.put(18, 9, "ooooooooo").put(18, 21, "ooo")
    for y in (11, 12):
        s.put(y, 16, "o")
    for y in (14, 15, 16, 17):
        s.put(y, 15, "o")
    for y in (19, 20, 21, 22):
        s.put(y, 18, "o")
    # grietas con brillo
    s.put(12, 12, "3").put(13, 13, "2").put(14, 13, "1").put(15, 12, "2").put(16, 12, "3")
    s.put(16, 20, "3").put(17, 19, "2").put(18, 19, "1").put(19, 20, "2").put(20, 20, "3")
    s.put(20, 14, "o").put(21, 15, "o").put(12, 17, "o").put(13, 18, "o")
    # brazos y puños
    for y in range(11, 17):
        s.put(y, 5, "tTo").put(y, 25, "tTo")
    s.put(17, 3, "tttTTo").put(18, 3, "tTTTTo").put(19, 3, "tTTTTo").put(20, 3, "tTToTo").put(21, 3, "oooooo")
    s.put(17, 23, "ttttTo").put(18, 23, "tTTTTTo").put(19, 23, "tTTTTTo").put(20, 23, "tToToTo").put(21, 23, "tTTTTTo").put(22, 23, "ooooooo")
    # piernas cortas
    for y in (24, 25, 26):
        s.put(y, 10, "tTTTo").put(y, 17, "tTTTo")
    s.put(27, 9, "TTTTTo").put(27, 17, "TTTTTo")
    s.put(28, 9, "oooooo").put(28, 17, "oooooo")
    s.outline()
    return s.flip()


def wraith():
    """Espectro errante: capucha espectral, cara en sombra con ojos brillantes, bajo deshilachado."""
    s = Sprite(32, 32)
    s.put(4, 14, "fFFy")
    s.put(5, 12, "fffFFFy")
    s.put(6, 11, "ffFFFFFFy")
    s.put(7, 10, "ffFF" + "ZZZZ" + "Fy")
    s.put(8, 10, "fFF" + "ZZZZZ" + "Fy")
    s.put(9, 10, "fFF" + "Z7Z7Z" + "Fy")
    s.put(10, 10, "fFF" + "ZpZpZ" + "Fy")
    s.put(11, 10, "FFF" + "ZZZZZ" + "yQ")
    s.put(12, 9, "fFFFF" + "ZZZ" + "FyQ")
    for y, x, t in [(13, 8, "fFFFFFFFFFyQ"), (14, 8, "fFFFFFFFFFFyQ"), (15, 7, "fFFFFFFFFFFyyQ"),
                    (16, 7, "fFFFFFFFFFFFyQ"), (17, 7, "FFFFFFFFFFFFyQ"), (18, 7, "FFFFFFFFFFFFyyQ"),
                    (19, 6, "FFFFFFFFFFFFFyyQ"), (20, 6, "FFFFFFFFFFFFyyyQ"), (21, 6, "yFFFFFFFFFFyyyQQ"),
                    (22, 6, "yyFFFFFFFFyyyyQQ"), (23, 6, "QyyyFFFyyyyyyQQ")]:
        s.put(y, x, t)
    # bajo deshilachado
    s.put(24, 6, "Qyy.yyQ.yyQ.yQ")
    s.put(25, 7, "Q..yQ...yQ..Q")
    s.put(26, 7, "Q...Q....Q")
    # garras espectrales delante
    s.put(15, 21, "fF").put(16, 22, "fFf").put(17, 23, "F.F")
    s.outline()
    return s.flip()


if __name__ == "__main__":
    sprites = [slime(), skeleton(), bat(0), bat(1), golem(), wraith()]
    preview(sprites, "out/review_enemies.png", scale=8)
    print("ok")
