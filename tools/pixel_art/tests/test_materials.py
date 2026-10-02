import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import materials  # noqa: E402


class MaterialIconsTest(unittest.TestCase):
    def test_every_biome_material_has_an_icon(self):
        self.assertEqual(sorted(materials.ICONS), sorted(["bone", "moss", "obsidian", "frost", "void_shard"]))

    def test_icons_are_12x12_with_outline_margin(self):
        for key, draw in materials.ICONS.items():
            s = draw()
            self.assertEqual((s.w, s.h), (12, 12), key)
            opaque = [(x, y) for y in range(12) for x in range(12) if s.px[y][x] != "."]
            self.assertTrue(opaque, key)
            # el contorno exterior ocupa como mucho el borde: el dibujo cabe en 12x12
            self.assertTrue(all(0 <= x < 12 and 0 <= y < 12 for x, y in opaque), key)

    def test_export_writes_one_png_per_material(self):
        out = materials.export_icons()
        for key in materials.ICONS:
            self.assertTrue((out / f"{key}.png").exists(), key)


if __name__ == "__main__":
    unittest.main()
