import json
import sys
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(HERE))

import game_assets  # noqa: E402
from pixel_kit import Sprite  # noqa: E402


class MeasureTest(unittest.TestCase):
    def test_grounded_sprite(self):
        s = Sprite(32, 32)
        s.rect(12, 20, 8, 9, 'A')  # x 12-19, y 20-28: los pies en la fila 28
        m = game_assets.measure(s)
        self.assertEqual(m["half_width"], 4)
        self.assertEqual(m["body_height"], 9)
        self.assertEqual(m["center_y"], -4.5)
        self.assertEqual(m["hover"], 0)
        self.assertEqual(m["ground_row"], 28)

    def test_floating_sprite(self):
        s = Sprite(32, 32)
        s.rect(10, 5, 12, 10, 'P')  # y 5-14: flota 14 filas por encima de los pies
        m = game_assets.measure(s)
        self.assertEqual(m["hover"], 14)
        self.assertEqual(m["half_width"], 6)

    def test_boss_canvas_uses_row_45(self):
        s = Sprite(48, 48)
        s.rect(20, 30, 8, 16, 'e')
        self.assertEqual(game_assets.measure(s)["ground_row"], 45)


class ExportedAssetsTest(unittest.TestCase):
    """Comprueba lo que export.py deja en art/sprites/pixel (ejecutar export.py antes)."""

    @classmethod
    def setUpClass(cls):
        cls.metrics = json.loads((game_assets.SPRITES / "metrics.json").read_text(encoding="utf-8"))

    def test_expected_keys(self):
        expected = {"hero/tico_0", "hero/tico_1", "hero/tico_2"}
        expected |= {f"enemies/{e}" for e in ("slime", "skeleton", "bat", "golem", "wraith")}
        expected |= {f"bosses/boss_{i}" for i in range(5)}
        self.assertTrue(expected <= set(self.metrics), expected - set(self.metrics))

    def test_every_strip_matches_its_metrics(self):
        from PIL import Image
        for key, m in self.metrics.items():
            with Image.open(game_assets.SPRITES / f"{key}.png") as img:
                self.assertEqual(img.size, (m["frame_w"] * m["frames"], m["frame_h"]), key)

    def test_measures_are_plausible(self):
        for key, m in self.metrics.items():
            self.assertTrue(4 <= m["half_width"] <= m["frame_w"] // 2, key)
            self.assertTrue(8 <= m["body_height"] <= m["frame_h"], key)
            self.assertLess(m["center_y"], 0, key)
        self.assertGreater(self.metrics["enemies/bat"]["hover"], 5)
        self.assertEqual(self.metrics["enemies/slime"]["hover"], 0)
        self.assertEqual(self.metrics["bosses/boss_0"]["frame_w"], 48)
