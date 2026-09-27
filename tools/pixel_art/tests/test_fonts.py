import sys
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(HERE))

import fonts  # noqa: E402


class GlyphTablesTest(unittest.TestCase):
    def test_every_char_has_a_glyph(self):
        for table in (fonts.SMALL, fonts.BIG):
            for ch in fonts.CHARSET:
                base = fonts.ACCENTED[ch][0] if ch in fonts.ACCENTED else ch
                self.assertIn(base, table, repr(ch))

    def test_glyph_rows_are_rectangular(self):
        for table, cap in ((fonts.SMALL, 5), (fonts.BIG, 7)):
            for ch, rows in table.items():
                self.assertEqual(len(rows), cap, repr(ch))
                self.assertEqual(len({len(r) for r in rows}), 1, repr(ch))
                self.assertTrue(set("".join(rows)) <= {"#", "."}, repr(ch))

    def test_accented_glyph_has_mark_and_gap_above(self):
        rows = fonts.glyph_rows(fonts.SMALL, "Á")
        self.assertIn("#", rows[0])
        self.assertNotIn("#", rows[1])
        self.assertEqual(rows[2:], fonts.SMALL["A"])
        self.assertEqual(fonts.glyph_rows(fonts.SMALL, "A")[:2], ["...", "..."])

    def test_outline_surrounds_glyph_without_diagonals(self):
        img = fonts.render_glyph(["#"])
        self.assertEqual(img.size, (3, 3))
        self.assertEqual(img.getpixel((1, 1)), fonts.GLYPH_RGBA)
        self.assertEqual(img.getpixel((0, 1)), fonts.OUTLINE_RGBA)
        self.assertEqual(img.getpixel((0, 0))[3], 0)


class BMFontFileTest(unittest.TestCase):
    """Comprueba lo que export.py deja en art/font/pixel (ejecutar export.py antes)."""

    def parse(self, name):
        lines = (fonts.FONT_DIR / f"{name}.fnt").read_text(encoding="utf-8").splitlines()
        common = dict(kv.split("=") for kv in lines[1].split()[1:])
        chars = [dict(kv.split("=") for kv in l.split()[1:]) for l in lines if l.startswith("char ")]
        return common, chars

    def test_small_font_metrics(self):
        common, chars = self.parse("pixel_small")
        self.assertEqual((common["lineHeight"], common["base"]), ("9", "8"))
        self.assertEqual(len(chars), len(fonts.CHARSET))
        a = next(c for c in chars if c["id"] == str(ord("A")))
        self.assertEqual((a["xadvance"], a["xoffset"]), ("4", "-1"))

    def test_big_font_metrics(self):
        common, chars = self.parse("pixel_big")
        self.assertEqual((common["lineHeight"], common["base"]), ("11", "10"))
        self.assertEqual(len(chars), len(fonts.CHARSET))

    def test_glyph_rects_inside_atlas(self):
        for name in ("pixel_small", "pixel_big"):
            common, chars = self.parse(name)
            w, h = int(common["scaleW"]), int(common["scaleH"])
            for c in chars:
                self.assertLessEqual(int(c["x"]) + int(c["width"]), w, c)
                self.assertLessEqual(int(c["y"]) + int(c["height"]), h, c)
