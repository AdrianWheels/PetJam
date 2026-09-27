from pixel_kit import Sprite, preview


def smith():
    """Brasa, la herrera (el jugador): 32x32, enana robusta, mirando a la derecha."""
    s = Sprite(32, 32)
    # ── Pelo pelirrojo con moño alto ──
    s.put(1, 13, "4334")
    s.put(2, 12, "433334")
    s.put(3, 10, "4333333334")
    s.put(4, 9, "433333333344")
    # ── Gafas de forja sobre la frente ──
    s.put(5, 8, "44ddiGGiGGiI4")
    s.put(6, 8, "44ddiGjiGjiI4")
    # ── Cara: pecas, sonrisa ──
    s.put(7, 8, "x44" + "sssssssss" + "S")
    s.put(8, 8, "x44" + "ssssKssKs" + "S")
    s.put(9, 8, "x44" + "ssssKssKs" + "S")
    s.put(10, 8, "xx4" + "sq6sssq6s" + "S")
    s.put(11, 9, "x4" + "ssssKYYKs")
    s.put(12, 10, "4" + "SSSSSSSS")
    # ── Trenza cayendo por la espalda ──
    s.put(11, 7, "44")
    s.put(12, 6, "334").put(13, 6, "443").put(14, 6, "334").put(15, 6, "443")
    s.put(16, 6, "GGj").put(17, 6, "343").put(18, 7, "3")
    # ── Camisa arremangada y delantal de cuero ──
    s.put(13, 9, "88L8888L88E")
    s.put(14, 9, "88L8888L88EE8")
    s.put(15, 8, "E8LLLLLLLLE88")
    s.put(16, 8, "SELlLLLLLLdss")
    s.put(17, 8, "SELlLLLLLLdsS")
    s.put(18, 8, "SELlLddLLLdsS")
    s.put(19, 8, "qELlLdGdLLd")
    s.put(20, 8, "q.LlLLLLLLd")
    s.put(21, 10, "LlLLLLLLd")
    s.put(22, 10, "LlLLLLLLd")
    s.put(23, 10, "dLLLLLLLd")
    s.put(24, 11, "dddddddd")
    # ── Mano delantera agarrando el mango del martillo ──
    s.put(19, 20, "ssS").put(20, 20, "sSq")
    # ── Martillo apoyado en el suelo ──
    s.put(21, 21, "wW").put(22, 22, "wW").put(23, 22, "wW")
    s.put(24, 19, "iMMmmmMMi")
    s.put(25, 19, "IMmmmmmMI")
    s.put(26, 19, "IiMMMMMiI")
    s.put(27, 19, "IiiiiiiiI")
    s.put(28, 19, "IIIIIIIII")
    # ── Piernas cortas y botas de trabajo ──
    s.put(25, 11, "nnB").put(25, 15, "nBB")
    s.put(26, 10, "kkdd").put(26, 15, "kddd")
    s.put(27, 10, "kkddd").put(27, 15, "kdddd")
    s.put(28, 10, "kkkkk").put(28, 15, "kkkk")
    s.outline()
    return s


if __name__ == "__main__":
    sm = smith()
    sm.save("out/smith.png", 1)
    preview([sm], "out/review_smith.png", scale=12)
    print("ok")
