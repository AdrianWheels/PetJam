# Franja de combate en pixel art · Fase 1: render y medidas — Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** que el pasillo de combate funcione ya a 216×96 ampliado ×5, con Tico, los enemigos y los jefes como sprites pixel en reposo, textos en fuente pixel y medidas en píxeles del arte.

**Architecture:** `HeroViewPanel` pasa a `stretch_shrink = 5` y amplía con un sombreador *sharp bilinear*. Todo el pasillo trabaja en píxeles del arte: las constantes viven en `PixelView`, los sprites y sus medidas los exporta `tools/pixel_art` a `art/sprites/pixel/`, y las fuentes a `art/font/pixel/` en formato BMFont. `Hero` y `Enemy` cambian el dibujo con formas por un `Sprite2D` con `pixel_sprite.gdshader` (destello y disolución), sin tocar la lógica de combate. El fondo, las puertas y los efectos se quedan en una versión provisional en píxeles; las fases 3 a 5 los redibujan.

**Tech Stack:** Godot 4.5.1 (GDScript, tabs), Python 3 + Pillow 12 para la herramienta de sprites, `unittest` (stdlib) para las pruebas de Python y una escena de pruebas sin ventana para GDScript.

**Spec:** `doc/specs/2026-09-27-franja-combate-pixel-art.md` (este plan cubre su fase 1, apartado 12.1).

## Global Constraints

- Godot: usar siempre `D:/Software/Godot/godot_ver4.5.exe` (4.5.1). Nunca `godot.exe` (4.7): actualizaría los recursos del proyecto.
- Tras crear scripts con `class_name` o recursos nuevos: `D:/Software/Godot/godot_ver4.5.exe --headless --path . --import`.
- Lienzo de la franja: **216×96**, ampliación **×5**, suelo en **y = 80**. Una unidad de mundo = un píxel del arte.
- Sprites: 32×32 con los pies en la fila 28 y 48×48 con los pies en la fila 45. El origen de `Hero`/`Enemy` es el centro de los pies; el fotograma se dibuja con su esquina superior izquierda en `(-frame_w/2, -(ground_row + 1))`.
- Dentro de la franja no hay texto con fuente vectorial: solo `PixelFont` (mayúsculas; el texto se convierte al pintarse).
- En la franja no se escalan ni giran sprites: solo desplazamientos en píxeles enteros.
- La lógica de combate y el balance no cambian. Se conservan los nombres de la API pública de `Hero`, `Enemy` y `Corridor` (spec §4 y §9); solo cambian las unidades de posición y distancia.
- Estilo del proyecto: GDScript con tabs y comentarios en español; Python solo con stdlib + Pillow.
- Las pruebas y capturas guardan y restauran `%APPDATA%/Godot/app_userdata/PetJam/save.json` (la partida del usuario).
- **Sin commits.** Los cambios de la fase anterior siguen sin commit y comparten ficheros con este plan; el usuario decide cuándo commitear. Donde la plantilla dice "Commit", aquí hay un punto de control.
- `HeroViewOverlay` (el HUD de alta resolución de la franja) no se toca en esta fase.

## Review Focus

- **Escala de pantalla no entera** (ventana de 540 o móvil de 720 de ancho): los píxeles deben verse regulares, ni borrosos ni de grosor desigual. Lo comprueban las capturas a 540×960 y 720×1280 de la tarea 10.
- **La partida del usuario:** pruebas y capturas no deben dejar `save.json` cambiado. La escena de pruebas lo guarda y restaura (tarea 3) y la tarea 10 compara su huella antes y después.
- **Nombres que se pisan o se salen de la franja:** jefes con nombre largo y nivel de tres cifras, o un esqueleto alto junto a Tico. Lo cubre `test_names_do_not_overlap_in_combat` (tarea 7).
- **Equipar durante la caída:** cambiar el equipo con Tico muerto no debe hacerlo reaparecer. Lo cubre `test_dead_hero_stays_hidden_after_equipping` (tarea 6).
- **Recursos que faltan** (no se ejecutó `export.py`): error claro y valores por defecto, sin cuelgue. Lo cubren `test_pixel_sprites_load_with_metrics` (tarea 3) y `test_gate_plate_fits_the_room_number` para cifras largas (tarea 9).

---

## Mapa de ficheros

| Fichero | Acción | Responsabilidad |
|---|---|---|
| `tools/pixel_art/game_assets.py` | crear | exportar tiras de juego y `metrics.json` |
| `tools/pixel_art/fonts.py` | crear | glifos 3×5 y 5×7 y escritura BMFont |
| `tools/pixel_art/export.py` | modificar | llamar a las dos exportaciones anteriores |
| `tools/pixel_art/tests/test_game_assets.py`, `test_fonts.py` | crear | pruebas de la herramienta |
| `art/sprites/pixel/**`, `art/font/pixel/**` | generados | recursos del juego |
| `scripts/gameplay/visual/PixelView.gd` | crear | medidas de la franja |
| `scripts/gameplay/visual/PixelSprites.gd` | crear | carga de tiras y medidas |
| `scripts/gameplay/visual/PixelFont.gd` | crear | carga y dibujo de las fuentes pixel |
| `scripts/gameplay/visual/PixelHud.gd` | crear | barra de vida, sombra e icono de armadura |
| `shaders/pixel_upscale.gdshader` | crear | ampliación *sharp bilinear* del contenedor |
| `shaders/pixel_sprite.gdshader` | crear | destello y disolución de los sprites |
| `scenes/UI/HUD_Main.tscn` | modificar | contenedor ×5, filtros y ajuste a píxel |
| `scripts/gameplay/visual/CorridorCamera.gd` | reescribir | cámara en píxeles enteros |
| `scripts/gameplay/Hero.gd` | reescribir el dibujo | sprite, sombra, barra y nombre |
| `scripts/ui/EquipmentPanel.gd` | modificar | héroe de muestra a escala entera |
| `scripts/gameplay/Enemy.gd` | reescribir el dibujo | sprite, sombra, barra, nombre y alerta |
| `scripts/gameplay/visual/EnemyArchetypes.gd` | modificar | sin medidas escritas a mano |
| `scripts/gameplay/visual/CombatFX.gd` | reescribir | efectos en píxeles y fuentes pixel |
| `scripts/gameplay/Corridor.gd`, `CombatController.gd` | modificar | unidades nuevas |
| `scripts/gameplay/visual/DungeonBackdrop.gd`, `BackdropLayer.gd` | modificar | fondo liso provisional a 216×96 |
| `scripts/gameplay/visual/RoomGate.gd` | reescribir | puerta pixel provisional |
| `scenes/tests/PixelTests.tscn`, `scripts/tests/PixelTests.gd` | crear | pruebas GDScript sin ventana |

---

### Task 1: Sprites del juego y sus medidas (herramienta)

**Files:**
- Create: `tools/pixel_art/game_assets.py`
- Create: `tools/pixel_art/tests/test_game_assets.py`
- Modify: `tools/pixel_art/export.py` (añadir la exportación al final)
- Genera: `art/sprites/pixel/hero/tico_{0,1,2}.png`, `art/sprites/pixel/enemies/{slime,skeleton,bat,golem,wraith}.png`, `art/sprites/pixel/bosses/boss_{0..4}.png`, `art/sprites/pixel/metrics.json`

**Interfaces:**
- Consumes: `export.CAST` (tiras de 2 fotogramas ya existentes), `pixel_kit.Sprite`.
- Produces: `metrics.json` con una entrada por clave (`"hero/tico_0"`, `"enemies/slime"`, `"bosses/boss_0"`…):
  `{"frame_w": int, "frame_h": int, "frames": int, "ground_row": int, "half_width": int, "body_height": int, "center_y": float, "hover": int}`.
  `center_y` es la y del centro de la caja de píxeles opacos respecto al suelo (negativa); `hover` es la distancia entre la fila de los pies y el píxel opaco más bajo (0 si pisa el suelo).

- [ ] **Step 1: Escribir las pruebas que fallan**

Crear `tools/pixel_art/tests/test_game_assets.py`:

```python
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
            img = Image.open(game_assets.SPRITES / f"{key}.png")
            self.assertEqual(img.size, (m["frame_w"] * m["frames"], m["frame_h"]), key)

    def test_measures_are_plausible(self):
        for key, m in self.metrics.items():
            self.assertTrue(4 <= m["half_width"] <= m["frame_w"] // 2, key)
            self.assertTrue(8 <= m["body_height"] <= m["frame_h"], key)
            self.assertLess(m["center_y"], 0, key)
        self.assertGreater(self.metrics["enemies/bat"]["hover"], 5)
        self.assertEqual(self.metrics["enemies/slime"]["hover"], 0)
        self.assertEqual(self.metrics["bosses/boss_0"]["frame_w"], 48)
```

- [ ] **Step 2: Ejecutar y ver que fallan**

Run: `python -m unittest discover -s tools/pixel_art/tests -v`
Expected: FAIL con `ModuleNotFoundError: No module named 'game_assets'`.

- [ ] **Step 3: Implementar la exportación**

Crear `tools/pixel_art/game_assets.py`:

```python
"""Exporta los sprites que usa el juego (tiras de fotogramas a escala 1) y sus medidas.

Lo llama export.py. Escribe en art/sprites/pixel/ del proyecto:
  hero/tico_0.png … tico_2.png   Tico sin forja, con hierro y con equipo maestro (provisional hasta las capas)
  enemies/<arquetipo>.png         slime, skeleton, bat, golem, wraith
  bosses/boss_<bioma>.png         0 Catacumbas … 4 Santuario del Vacío
  metrics.json                    caja de píxeles opacos de cada sprite, en píxeles del arte
"""
import json
from pathlib import Path

from PIL import Image

REPO = Path(__file__).resolve().parents[2]
SPRITES = REPO / "art" / "sprites" / "pixel"

# Fila de los pies según el tamaño del lienzo (el contorno queda en la fila siguiente)
GROUND_ROW = {32: 28, 48: 45}


def strip_image(frames):
    w, h = frames[0].w, frames[0].h
    img = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        img.alpha_composite(f.image(), (i * w, 0))
    return img


def measure(sprite):
    """Medidas del fotograma relativas al punto de apoyo (centro de los pies)."""
    xs, ys = [], []
    for y in range(sprite.h):
        for x in range(sprite.w):
            if sprite.px[y][x] != '.':
                xs.append(x)
                ys.append(y)
    left, right, top, bottom = min(xs), max(xs), min(ys), max(ys)
    ground = GROUND_ROW[sprite.h]
    mid = sprite.w // 2
    return {
        "frame_w": sprite.w,
        "frame_h": sprite.h,
        "ground_row": ground,
        "half_width": max(mid - left, right + 1 - mid),
        "body_height": bottom - top + 1,
        "center_y": (top + bottom + 1) / 2 - (ground + 1),
        "hover": max(0, ground - bottom),
    }


def export_game(cast):
    """cast: {clave: [fotogramas]}, con claves como "hero/tico_0". Devuelve las medidas escritas."""
    metrics = {}
    for key, frames in cast.items():
        path = SPRITES / f"{key}.png"
        path.parent.mkdir(parents=True, exist_ok=True)
        strip_image(frames).save(path)
        m = measure(frames[0])
        m["frames"] = len(frames)
        metrics[key] = m
    (SPRITES / "metrics.json").write_text(json.dumps(metrics, indent=1, sort_keys=True), encoding="utf-8")
    return metrics
```

En `tools/pixel_art/export.py`, añadir `import game_assets` junto a los demás imports (después de `import enemies`) y, al final del fichero, antes de los dos `print` finales:

```python
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
```

- [ ] **Step 4: Exportar y ver que pasan**

Run: `python tools/pixel_art/export.py && python -m unittest discover -s tools/pixel_art/tests -v`
Expected: `sprites del juego en D:\Proyectos\PetJam\art\sprites\pixel` y las 6 pruebas en `OK`.

- [ ] **Step 5: Punto de control (sin commit)**

Run: `git status --short tools/pixel_art art/sprites`
Expected: `game_assets.py`, `tests/` y `art/sprites/` como nuevos.

---

### Task 2: Fuentes pixel en BMFont (herramienta)

**Files:**
- Create: `tools/pixel_art/fonts.py`
- Create: `tools/pixel_art/tests/test_fonts.py`
- Modify: `tools/pixel_art/export.py`
- Genera: `art/font/pixel/pixel_small.fnt`, `pixel_small.png`, `pixel_big.fnt`, `pixel_big.png`

**Interfaces:**
- Produces: dos fuentes BMFont con `CHARSET = " ABCDEFGHIJKLMNOPQRSTUVWXYZÁÉÍÓÚÜÑ0123456789!¡?¿.,:;-+/()%'·×"`.
  Pequeña: alto de línea **9**, base 8 (contorno + 2 filas de tilde + 5 + contorno). Grande: alto de línea **11**, base 10.
  Cada glifo lleva su contorno `#241826` y el trazo en blanco, así el color del texto tiñe el trazo y el contorno sigue oscuro.
  Avance = ancho del trazo + 1; `xoffset = -1` (el contorno izquierdo cae en el hueco entre letras). Ejemplo: `A` avanza 4 en la pequeña, `M` y `W` avanzan 6.

- [ ] **Step 1: Escribir las pruebas que fallan**

Crear `tools/pixel_art/tests/test_fonts.py`:

```python
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
```

- [ ] **Step 2: Ejecutar y ver que fallan**

Run: `python -m unittest tools/pixel_art/tests/test_fonts.py -v`
Expected: FAIL con `ModuleNotFoundError: No module named 'fonts'`.

- [ ] **Step 3: Implementar las fuentes**

Crear `tools/pixel_art/fonts.py`:

```python
"""Fuentes pixel de la franja: pequeña de 3x5 y grande de 5x7, solo mayúsculas, en formato BMFont.

Cada glifo lleva dentro su contorno oscuro de 1 px y el trazo en blanco: el texto se tiñe al pintarlo
y el contorno sigue oscuro. Encima de la altura de mayúscula hay dos filas para las tildes (tilde + hueco).
Salida: art/font/pixel/pixel_small.fnt + .png y pixel_big.fnt + .png
"""
from pathlib import Path

from PIL import Image

REPO = Path(__file__).resolve().parents[2]
FONT_DIR = REPO / "art" / "font" / "pixel"

GLYPH_RGBA = (255, 255, 255, 255)
OUTLINE_RGBA = (36, 24, 38, 255)  # el mismo contorno que los sprites (#241826)
ACCENT_ROWS = 2

CHARSET = " ABCDEFGHIJKLMNOPQRSTUVWXYZÁÉÍÓÚÜÑ0123456789!¡?¿.,:;-+/()%'·×"

ACCENTED = {"Á": ("A", "acute"), "É": ("E", "acute"), "Í": ("I", "acute"), "Ó": ("O", "acute"),
            "Ú": ("U", "acute"), "Ü": ("U", "umlaut"), "Ñ": ("N", "tilde")}

ACCENT_PATTERNS = {
    "acute": {3: "..#", 4: "..#.", 5: "...#."},
    "umlaut": {3: "#.#", 4: "#..#", 5: ".#.#."},
    "tilde": {3: "###", 4: ".##.", 5: ".###."},
}

# 3x5; M y W de 5 columnas, N de 4
SMALL = {
    " ": ["..", "..", "..", "..", ".."],
    "A": [".#.", "#.#", "###", "#.#", "#.#"], "B": ["##.", "#.#", "##.", "#.#", "##."],
    "C": [".##", "#..", "#..", "#..", ".##"], "D": ["##.", "#.#", "#.#", "#.#", "##."],
    "E": ["###", "#..", "##.", "#..", "###"], "F": ["###", "#..", "##.", "#..", "#.."],
    "G": [".##", "#..", "#.#", "#.#", ".##"], "H": ["#.#", "#.#", "###", "#.#", "#.#"],
    "I": ["###", ".#.", ".#.", ".#.", "###"], "J": ["..#", "..#", "..#", "#.#", ".#."],
    "K": ["#.#", "#.#", "##.", "#.#", "#.#"], "L": ["#..", "#..", "#..", "#..", "###"],
    "M": ["#...#", "##.##", "#.#.#", "#...#", "#...#"], "N": ["#..#", "##.#", "#.##", "#..#", "#..#"],
    "O": [".#.", "#.#", "#.#", "#.#", ".#."], "P": ["##.", "#.#", "##.", "#..", "#.."],
    "Q": [".#.", "#.#", "#.#", "##.", ".##"], "R": ["##.", "#.#", "##.", "#.#", "#.#"],
    "S": [".##", "#..", ".#.", "..#", "##."], "T": ["###", ".#.", ".#.", ".#.", ".#."],
    "U": ["#.#", "#.#", "#.#", "#.#", "###"], "V": ["#.#", "#.#", "#.#", "#.#", ".#."],
    "W": ["#...#", "#...#", "#.#.#", "##.##", "#...#"], "X": ["#.#", "#.#", ".#.", "#.#", "#.#"],
    "Y": ["#.#", "#.#", ".#.", ".#.", ".#."], "Z": ["###", "..#", ".#.", "#..", "###"],
    "0": ["###", "#.#", "#.#", "#.#", "###"], "1": [".#.", "##.", ".#.", ".#.", "###"],
    "2": ["##.", "..#", ".#.", "#..", "###"], "3": ["##.", "..#", ".#.", "..#", "##."],
    "4": ["#.#", "#.#", "###", "..#", "..#"], "5": ["###", "#..", "##.", "..#", "##."],
    "6": [".##", "#..", "###", "#.#", "###"], "7": ["###", "..#", ".#.", ".#.", ".#."],
    "8": ["###", "#.#", "###", "#.#", "###"], "9": ["###", "#.#", "###", "..#", "##."],
    "!": ["#", "#", "#", ".", "#"], "¡": ["#", ".", "#", "#", "#"],
    "?": ["##.", "..#", ".#.", "...", ".#."], "¿": [".#.", "...", ".#.", "#..", ".##"],
    ".": [".", ".", ".", ".", "#"], ",": ["..", "..", "..", ".#", "#."],
    ":": [".", "#", ".", "#", "."], ";": ["..", ".#", "..", ".#", "#."],
    "-": ["...", "...", "###", "...", "..."], "+": ["...", ".#.", "###", ".#.", "..."],
    "/": ["..#", "..#", ".#.", "#..", "#.."], "(": [".#", "#.", "#.", "#.", ".#"],
    ")": ["#.", ".#", ".#", ".#", "#."], "%": ["#.#", "..#", ".#.", "#..", "#.#"],
    "'": ["#", "#", ".", ".", "."], "·": [".", ".", "#", ".", "."],
    "×": ["...", "#.#", ".#.", "#.#", "..."],
}

# 5x7; I y 1 de 3 columnas
BIG = {
    " ": ["...", "...", "...", "...", "...", "...", "..."],
    "A": [".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
    "B": ["####.", "#...#", "#...#", "####.", "#...#", "#...#", "####."],
    "C": [".###.", "#...#", "#....", "#....", "#....", "#...#", ".###."],
    "D": ["####.", "#...#", "#...#", "#...#", "#...#", "#...#", "####."],
    "E": ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
    "F": ["#####", "#....", "#....", "####.", "#....", "#....", "#...."],
    "G": [".###.", "#...#", "#....", "#.###", "#...#", "#...#", ".###."],
    "H": ["#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
    "I": ["###", ".#.", ".#.", ".#.", ".#.", ".#.", "###"],
    "J": ["..###", "...#.", "...#.", "...#.", "#..#.", "#..#.", ".##.."],
    "K": ["#...#", "#..#.", "#.#..", "##...", "#.#..", "#..#.", "#...#"],
    "L": ["#....", "#....", "#....", "#....", "#....", "#....", "#####"],
    "M": ["#...#", "##.##", "#.#.#", "#.#.#", "#...#", "#...#", "#...#"],
    "N": ["#...#", "##..#", "#.#.#", "#..##", "#...#", "#...#", "#...#"],
    "O": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
    "P": ["####.", "#...#", "#...#", "####.", "#....", "#....", "#...."],
    "Q": [".###.", "#...#", "#...#", "#...#", "#.#.#", "#..#.", ".##.#"],
    "R": ["####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#"],
    "S": [".####", "#....", "#....", ".###.", "....#", "....#", "####."],
    "T": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
    "U": ["#...#", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
    "V": ["#...#", "#...#", "#...#", "#...#", "#...#", ".#.#.", "..#.."],
    "W": ["#...#", "#...#", "#...#", "#.#.#", "#.#.#", "#.#.#", ".#.#."],
    "X": ["#...#", "#...#", ".#.#.", "..#..", ".#.#.", "#...#", "#...#"],
    "Y": ["#...#", "#...#", ".#.#.", "..#..", "..#..", "..#..", "..#.."],
    "Z": ["#####", "....#", "...#.", "..#..", ".#...", "#....", "#####"],
    "0": [".###.", "#...#", "#..##", "#.#.#", "##..#", "#...#", ".###."],
    "1": [".#.", "##.", ".#.", ".#.", ".#.", ".#.", "###"],
    "2": [".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####"],
    "3": ["#####", "...#.", "..#..", "...#.", "....#", "#...#", ".###."],
    "4": ["...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "...#."],
    "5": ["#####", "#....", "####.", "....#", "....#", "#...#", ".###."],
    "6": ["..##.", ".#...", "#....", "####.", "#...#", "#...#", ".###."],
    "7": ["#####", "....#", "...#.", "..#..", ".#...", ".#...", ".#..."],
    "8": [".###.", "#...#", "#...#", ".###.", "#...#", "#...#", ".###."],
    "9": [".###.", "#...#", "#...#", ".####", "....#", "...#.", ".##.."],
    "!": ["#", "#", "#", "#", "#", ".", "#"], "¡": ["#", ".", "#", "#", "#", "#", "#"],
    "?": [".###.", "#...#", "....#", "...#.", "..#..", ".....", "..#.."],
    "¿": ["..#..", ".....", "..#..", ".#...", "#....", "#...#", ".###."],
    ".": [".", ".", ".", ".", ".", ".", "#"], ",": ["..", "..", "..", "..", "..", ".#", "#."],
    ":": [".", ".", "#", ".", ".", "#", "."], ";": ["..", "..", ".#", "..", "..", ".#", "#."],
    "-": ["....", "....", "....", "####", "....", "....", "...."],
    "+": [".....", "..#..", "..#..", "#####", "..#..", "..#..", "....."],
    "/": ["....#", "....#", "...#.", "..#..", ".#...", "#....", "#...."],
    "(": ["..#", ".#.", "#..", "#..", "#..", ".#.", "..#"],
    ")": ["#..", ".#.", "..#", "..#", "..#", ".#.", "#.."],
    "%": ["##..#", "##.#.", "...#.", "..#..", ".#...", ".#.##", "#..##"],
    "'": ["#", "#", ".", ".", ".", ".", "."], "·": [".", ".", ".", "#", ".", ".", "."],
    "×": [".....", ".....", "#...#", ".#.#.", "..#..", ".#.#.", "#...#"],
}


def glyph_rows(table, ch):
    """Filas del glifo con las dos filas de tilde encima (vacías si no lleva)."""
    if ch in ACCENTED:
        base, kind = ACCENTED[ch]
        rows = table[base]
        width = len(rows[0])
        return [ACCENT_PATTERNS[kind][width], "." * width] + rows
    rows = table[ch]
    return ["." * len(rows[0])] * ACCENT_ROWS + rows


def render_glyph(rows):
    """Glifo con contorno de 1 px (sin diagonales) alrededor: (w + 2) x (h + 2)."""
    w, h = len(rows[0]), len(rows)
    img = Image.new("RGBA", (w + 2, h + 2), (0, 0, 0, 0))
    on = {(x, y) for y, row in enumerate(rows) for x, c in enumerate(row) if c == "#"}
    for (x, y) in on:
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            if (x + dx, y + dy) not in on:
                img.putpixel((x + dx + 1, y + dy + 1), OUTLINE_RGBA)
    for (x, y) in on:
        img.putpixel((x + 1, y + 1), GLYPH_RGBA)
    return img


def build(table, cap, name, face, per_row=16):
    """Escribe el atlas PNG y el .fnt. Devuelve (alto de línea, base)."""
    line_height = cap + ACCENT_ROWS + 2
    base = 1 + ACCENT_ROWS + cap
    glyphs = [(ch, render_glyph(glyph_rows(table, ch))) for ch in CHARSET]
    cell_w = max(g.width for _, g in glyphs) + 1
    rows = (len(glyphs) + per_row - 1) // per_row
    atlas = Image.new("RGBA", (per_row * cell_w, rows * (line_height + 1)), (0, 0, 0, 0))
    lines = [
        f'info face="{face}" size={line_height} bold=0 italic=0 charset="" unicode=1 stretchH=100 '
        f'smooth=0 aa=0 padding=0,0,0,0 spacing=0,0 outline=0',
        f"common lineHeight={line_height} base={base} scaleW={atlas.width} scaleH={atlas.height} "
        f"pages=1 packed=0 alphaChnl=0 redChnl=0 greenChnl=0 blueChnl=0",
        f'page id=0 file="{name}.png"',
        f"chars count={len(glyphs)}",
    ]
    for i, (ch, g) in enumerate(glyphs):
        x, y = (i % per_row) * cell_w, (i // per_row) * (line_height + 1)
        atlas.alpha_composite(g, (x, y))
        lines.append(f"char id={ord(ch)} x={x} y={y} width={g.width} height={g.height} "
                     f"xoffset=-1 yoffset=0 xadvance={g.width - 1} page=0 chnl=15")
    FONT_DIR.mkdir(parents=True, exist_ok=True)
    atlas.save(FONT_DIR / f"{name}.png")
    (FONT_DIR / f"{name}.fnt").write_text("\n".join(lines) + "\n", encoding="utf-8")
    return line_height, base


def export_fonts():
    return {
        "pixel_small": build(SMALL, 5, "pixel_small", "PetJam Pixel 3x5"),
        "pixel_big": build(BIG, 7, "pixel_big", "PetJam Pixel 5x7"),
    }
```

En `tools/pixel_art/export.py`, añadir `import fonts` junto a los imports y, después de la llamada a `game_assets.export_game(...)`:

```python
fonts.export_fonts()
print("fuentes pixel en", fonts.FONT_DIR)
```

- [ ] **Step 4: Exportar y ver que pasan**

Run: `python tools/pixel_art/export.py && python -m unittest discover -s tools/pixel_art/tests -v`
Expected: `fuentes pixel en D:\Proyectos\PetJam\art\font\pixel` y todas las pruebas (13) en `OK`.

- [ ] **Step 5: Revisar las fuentes a ojo**

Run:
```bash
python -c "
from PIL import Image
for n in ('pixel_small', 'pixel_big'):
    im = Image.open(f'art/font/pixel/{n}.png')
    im.resize((im.width * 6, im.height * 6), Image.NEAREST).save(f'tools/pixel_art/out/{n}_x6.png')
"
```
Abrir `tools/pixel_art/out/pixel_small_x6.png` y `pixel_big_x6.png`. Expected: glifos legibles, tildes separadas de la letra por una fila de contorno, sin píxeles sueltos. Corregir en `SMALL`/`BIG` cualquier glifo que no se lea y repetir el paso 4.

- [ ] **Step 6: Punto de control (sin commit)**

Run: `git status --short tools/pixel_art art/font/pixel`

---

### Task 3: Ayudantes pixel en Godot y escena de pruebas

**Files:**
- Create: `scripts/gameplay/visual/PixelView.gd`, `PixelSprites.gd`, `PixelFont.gd`, `PixelHud.gd`
- Create: `scenes/tests/PixelTests.tscn`, `scripts/tests/PixelTests.gd`

**Interfaces:**
- Consumes: `art/sprites/pixel/metrics.json` y tiras (tarea 1), `art/font/pixel/*.fnt` (tarea 2).
- Produces:
  - `PixelView`: `SCALE := 5`, `VIEW_W := 216.0`, `VIEW_H := 96.0`, `VIEW_SIZE := Vector2(216, 96)`, `FLOOR_Y := 80.0`, `HERO_SCREEN_X := 0.3`, `HERO_START := Vector2(52, 80)`.
  - `PixelSprites.metrics(key: String) -> Dictionary` (vacío si no existe), `PixelSprites.texture(key: String) -> Texture2D`, `PixelSprites.enemy_key(archetype: StringName, level: int) -> String`.
  - `PixelFont.small() -> FontFile`, `PixelFont.big() -> FontFile`, `PixelFont.SMALL_SIZE := 9`, `PixelFont.BIG_SIZE := 11`, `PixelFont.line_size(is_big: bool) -> int`, `PixelFont.width(text: String, is_big := false) -> int`, `PixelFont.draw(ci, pos, text, color, alpha := 1.0, is_big := false, scale := 1)` (pos = esquina superior izquierda), `PixelFont.draw_centered(ci, top_center, text, color, alpha := 1.0, is_big := false, scale := 1)`.
  - `PixelHud.draw_bar(ci, rect, ratio, ghost, fill, alpha := 1.0)`, `PixelHud.draw_shadow(ci, center, width: int, alpha := 1.0)`, `PixelHud.draw_armor_icon(ci, pos, alpha := 1.0, color := Color("b3bdca"))`.
  - `PixelTests.check(cond: bool, msg: String)`: cada tarea siguiente añade funciones `test_*` a `scripts/tests/PixelTests.gd`.

- [ ] **Step 1: Crear la escena de pruebas con las primeras pruebas**

Crear `scenes/tests/PixelTests.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/tests/PixelTests.gd" id="1"]

[node name="PixelTests" type="Node"]
script = ExtResource("1")
```

Crear `scripts/tests/PixelTests.gd`:

```gdscript
extends Node
## 🧪 Pruebas de la franja de combate pixel (solo desarrollo), sin ventana:
##   D:/Software/Godot/godot_ver4.5.exe --headless --path . res://scenes/tests/PixelTests.tscn
## Sale con código 0 si todo pasa y 1 si algo falla. Guarda y restaura user://save.json
## (las pruebas cargan los autoloads, que pueden autoguardar).

const SAVE_PATH := "user://save.json"

var _checks := 0
var _failures := 0
var _had_save := false
var _save_backup := PackedByteArray()


func _ready() -> void:
	_backup_save()
	for m in get_method_list():
		var method_name: String = m.name
		if not method_name.begins_with("test_"):
			continue
		var before := _failures
		await call(method_name)
		print("%s %s" % ["ok   " if _failures == before else "FALLO", method_name])
	_restore_save()
	print("[PixelTests] %d comprobaciones, %d fallos" % [_checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		printerr("  ✗ ", msg)


func _backup_save() -> void:
	_had_save = FileAccess.file_exists(SAVE_PATH)
	if _had_save:
		_save_backup = FileAccess.get_file_as_bytes(SAVE_PATH)


func _restore_save() -> void:
	if _had_save:
		var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		f.store_buffer(_save_backup)
		f.close()
	elif FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


# ─── Tarea 3: ayudantes ────────────────────────────────────────────────

func test_pixel_view_scales_to_the_strip() -> void:
	check(PixelView.VIEW_SIZE * PixelView.SCALE == Vector2(1080, 480), "216x96 por 5 debe dar la franja de 1080x480")
	check(PixelView.HERO_START.y == PixelView.FLOOR_Y, "el héroe empieza sobre el suelo")


func test_pixel_sprites_load_with_metrics() -> void:
	var keys := ["hero/tico_0", "hero/tico_1", "hero/tico_2", "enemies/slime", "enemies/skeleton",
		"enemies/bat", "enemies/golem", "enemies/wraith", "bosses/boss_0", "bosses/boss_1",
		"bosses/boss_2", "bosses/boss_3", "bosses/boss_4"]
	for key in keys:
		var m := PixelSprites.metrics(key)
		var tex := PixelSprites.texture(key)
		check(not m.is_empty(), "medidas de " + key)
		check(tex != null and tex.get_width() == int(m.get("frame_w", 0)) * int(m.get("frames", 0)), "tira de " + key)
	check(PixelSprites.metrics("no/existe").is_empty(), "una clave desconocida devuelve medidas vacías")


func test_enemy_sprite_keys() -> void:
	check(PixelSprites.enemy_key(&"slime", 3) == "enemies/slime", "enemigo normal")
	check(PixelSprites.enemy_key(&"boss", 10) == "bosses/boss_0", "jefe de Catacumbas")
	check(PixelSprites.enemy_key(&"boss", 50) == "bosses/boss_4", "jefe del Santuario del Vacío")
	check(PixelSprites.enemy_key(&"boss", 60) == "bosses/boss_0", "los jefes ciclan con los biomas")


func test_pixel_fonts() -> void:
	check(PixelFont.small() != null and PixelFont.big() != null, "las dos fuentes cargan")
	check(PixelFont.width("AB") == 8, "A y B avanzan 4 px cada una (%d)" % PixelFont.width("AB"))
	check(PixelFont.width("ab") == PixelFont.width("AB"), "el texto se pasa a mayúsculas")
	check(PixelFont.width("MW") == 12, "M y W avanzan 6 px (%d)" % PixelFont.width("MW"))
	check(PixelFont.width("HERALDO DEL VACÍO NV 150") < int(PixelView.VIEW_W), "el nombre de jefe más largo cabe en la franja")
	check(int(PixelFont.small().get_height(PixelFont.SMALL_SIZE)) == PixelFont.SMALL_SIZE, "alto de línea de la pequeña")
	check(int(PixelFont.big().get_height(PixelFont.BIG_SIZE)) == PixelFont.BIG_SIZE, "alto de línea de la grande")
```

- [ ] **Step 2: Ejecutar y ver que fallan**

Run: `D:/Software/Godot/godot_ver4.5.exe --headless --path . res://scenes/tests/PixelTests.tscn`
Expected: errores de análisis `Identifier "PixelView" not declared` (y de `PixelSprites`, `PixelFont`); la escena no llega a imprimir el resumen.

- [ ] **Step 3: Implementar los cuatro ayudantes**

Crear `scripts/gameplay/visual/PixelView.gd`:

```gdscript
class_name PixelView
extends RefCounted

## Medidas de la franja de combate en pixel art (spec doc/specs/2026-09-27-franja-combate-pixel-art.md).
## Una unidad de mundo = un píxel del arte. La franja de 1080x480 se pinta a 216x96 y se amplía x5.

const SCALE := 5
const VIEW_W := 216.0
const VIEW_H := 96.0
const VIEW_SIZE := Vector2(VIEW_W, VIEW_H)
const FLOOR_Y := 80.0
const HERO_SCREEN_X := 0.3  ## fracción del ancho donde va el héroe (x ≈ 65)
const HERO_START := Vector2(52.0, FLOOR_Y)
```

Crear `scripts/gameplay/visual/PixelSprites.gd`:

```gdscript
class_name PixelSprites
extends RefCounted

## Sprites pixel del juego y sus medidas. Los genera tools/pixel_art/export.py en art/sprites/pixel/.
## Claves: "hero/tico_0", "enemies/slime", "bosses/boss_0"…

const ROOT := "res://art/sprites/pixel/"
const BOSS_COUNT := 5

static var _metrics: Dictionary = {}
static var _textures: Dictionary = {}


## Medidas de la tira (ver tools/pixel_art/game_assets.py). Diccionario vacío si la clave no existe.
static func metrics(key: String) -> Dictionary:
	if _metrics.is_empty():
		var res := load(ROOT + "metrics.json") as JSON
		if res == null:
			push_error("PixelSprites: falta %smetrics.json (ejecuta python tools/pixel_art/export.py)" % ROOT)
			return {}
		_metrics = res.data
	return _metrics.get(key, {})


static func texture(key: String) -> Texture2D:
	if not _textures.has(key):
		_textures[key] = load(ROOT + key + ".png")
	return _textures[key]


## Clave del sprite de un enemigo: el jefe es el de su bioma (ciclan igual que los biomas).
static func enemy_key(archetype: StringName, level: int) -> String:
	if archetype == &"boss":
		return "bosses/boss_%d" % posmod(Biomes.biome_index_for_room(level), BOSS_COUNT)
	return "enemies/%s" % String(archetype)
```

Crear `scripts/gameplay/visual/PixelFont.gd`:

```gdscript
class_name PixelFont
extends RefCounted

## Fuentes pixel de la franja (BMFont que genera tools/pixel_art/fonts.py en art/font/pixel/).
## Solo tienen mayúsculas: el texto se convierte al pintarlo. El contorno oscuro va dentro del glifo,
## así que sirven con cualquier color de texto. Se dibujan a su tamaño o a múltiplos enteros.

const SMALL_PATH := "res://art/font/pixel/pixel_small.fnt"
const BIG_PATH := "res://art/font/pixel/pixel_big.fnt"
const SMALL_SIZE := 9  ## alto de línea de la pequeña (contorno + 2 filas de tilde + 5 + contorno)
const BIG_SIZE := 11  ## alto de línea de la grande (contorno + 2 + 7 + contorno)

static var _small: FontFile
static var _big: FontFile


static func small() -> FontFile:
	if _small == null:
		_small = _load(SMALL_PATH)
	return _small


static func big() -> FontFile:
	if _big == null:
		_big = _load(BIG_PATH)
	return _big


static func _load(path: String) -> FontFile:
	var f := load(path) as FontFile
	if f == null:
		push_error("PixelFont: falta %s (ejecuta python tools/pixel_art/export.py)" % path)
		return null
	f.fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_INTEGER_ONLY
	if "modulate_color_glyphs" in f:
		f.modulate_color_glyphs = true  # el trazo blanco toma el color del texto
	return f


static func font(is_big: bool) -> FontFile:
	return big() if is_big else small()


static func line_size(is_big: bool) -> int:
	return BIG_SIZE if is_big else SMALL_SIZE


## Ancho en píxeles del arte a escala 1.
static func width(text: String, is_big: bool = false) -> int:
	return int(font(is_big).get_string_size(text.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, line_size(is_big)).x)


## Pinta el texto con su esquina superior izquierda en `pos` (redondeada a píxel entero).
static func draw(ci: CanvasItem, pos: Vector2, text: String, color: Color, alpha: float = 1.0, is_big: bool = false, scale: int = 1) -> void:
	var f := font(is_big)
	var size := line_size(is_big) * scale
	var c := Color(color.r, color.g, color.b, color.a * alpha)
	ci.draw_string(f, pos.round() + Vector2(0, f.get_ascent(size)), text.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, size, c)


## Como draw(), centrado en x sobre `top_center`.
static func draw_centered(ci: CanvasItem, top_center: Vector2, text: String, color: Color, alpha: float = 1.0, is_big: bool = false, scale: int = 1) -> void:
	var w := width(text, is_big) * scale
	draw(ci, Vector2(roundf(top_center.x - w * 0.5), top_center.y), text, color, alpha, is_big, scale)
```

Crear `scripts/gameplay/visual/PixelHud.gd`:

```gdscript
class_name PixelHud
extends RefCounted

## Piezas de HUD pixel que comparten Tico y los enemigos: barra de vida, sombra e icono de armadura.
## Todo en píxeles enteros del arte, sin antialiasing.

const OUTLINE := Color("241826")
const EMPTY := Color("3a2a30")
const GHOST := Color("fff3a8")


## Barra de vida con borde oscuro de 1 px, daño fantasma y brillo en la fila superior.
static func draw_bar(ci: CanvasItem, rect: Rect2, ratio: float, ghost: float, fill: Color, alpha: float = 1.0) -> void:
	var r := Rect2(rect.position.round(), rect.size.round())
	ci.draw_rect(r.grow(1.0), _a(OUTLINE, alpha))
	ci.draw_rect(r, _a(EMPTY, alpha))
	var ghost_w := roundf(r.size.x * clampf(ghost, 0.0, 1.0))
	var fill_w := roundf(r.size.x * clampf(ratio, 0.0, 1.0))
	if ghost_w > fill_w:
		ci.draw_rect(Rect2(r.position, Vector2(ghost_w, r.size.y)), _a(GHOST, alpha))
	if fill_w > 0.0:
		ci.draw_rect(Rect2(r.position, Vector2(fill_w, r.size.y)), _a(fill, alpha))
		ci.draw_rect(Rect2(r.position, Vector2(fill_w, 1.0)), _a(fill.lightened(0.35), alpha))


## Sombra de dos filas sobre el suelo, centrada en los pies (`center`).
static func draw_shadow(ci: CanvasItem, center: Vector2, width: int, alpha: float = 1.0) -> void:
	var c := Color(0, 0, 0, 0.35 * alpha)
	var x := roundf(center.x - width * 0.5)
	ci.draw_rect(Rect2(x, center.y, width, 1.0), c)
	ci.draw_rect(Rect2(x + 2.0, center.y + 1.0, maxf(1.0, width - 4.0), 1.0), c)


## Escudo de 4x4 píxeles con su esquina superior izquierda en `pos`.
static func draw_armor_icon(ci: CanvasItem, pos: Vector2, alpha: float = 1.0, color: Color = Color("b3bdca")) -> void:
	var p := pos.round()
	ci.draw_rect(Rect2(p + Vector2(-1, -1), Vector2(6, 6)), _a(OUTLINE, alpha))
	ci.draw_rect(Rect2(p, Vector2(4, 3)), _a(color, alpha))
	ci.draw_rect(Rect2(p + Vector2(1, 3), Vector2(2, 1)), _a(color, alpha))


static func _a(c: Color, alpha: float) -> Color:
	return Color(c.r, c.g, c.b, c.a * alpha)
```

- [ ] **Step 4: Importar y ver que pasan**

Run:
```bash
D:/Software/Godot/godot_ver4.5.exe --headless --path . --import
D:/Software/Godot/godot_ver4.5.exe --headless --path . res://scenes/tests/PixelTests.tscn
```
Expected: cuatro líneas `ok   test_…`, `[PixelTests] N comprobaciones, 0 fallos` y código de salida 0.

- [ ] **Step 5: Punto de control (sin commit)**

Run: `git status --short scripts/gameplay/visual scripts/tests scenes/tests`

---

### Task 4: Viewport ×5 y sombreadores

**Files:**
- Create: `shaders/pixel_upscale.gdshader`, `shaders/pixel_sprite.gdshader`
- Modify: `scenes/UI/HUD_Main.tscn:1-60` (cabecera y nodos `HeroViewPanel`/`HeroViewport`)
- Test: `scripts/tests/PixelTests.gd` (añadir)

**Interfaces:**
- Produces: `pixel_sprite.gdshader` con los uniformes `flash: float` (0..1, mezcla hacia `flash_color`), `dissolve: float` (0..1, 1 = invisible) y `flash_color: vec4` (blanco). `HeroViewport` pinta a 216×96.

- [ ] **Step 1: Escribir la prueba que falla**

Añadir al final de `scripts/tests/PixelTests.gd`:

```gdscript
# ─── Tarea 4: viewport x5 ──────────────────────────────────────────────

func test_hero_strip_renders_at_216x96() -> void:
	var hud: Node = load("res://scenes/UI/HUD_Main.tscn").instantiate()
	var panel: SubViewportContainer = hud.get_node("HeroViewPanel")
	var vp: SubViewport = hud.get_node("HeroViewPanel/HeroViewport")
	check(panel.stretch and panel.stretch_shrink == PixelView.SCALE, "el contenedor pinta a 1/5 (%d)" % panel.stretch_shrink)
	check(panel.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR, "el contenedor amplía con filtro lineal (lo pide el sombreador)")
	var mat := panel.material as ShaderMaterial
	check(mat != null and mat.shader.resource_path == "res://shaders/pixel_upscale.gdshader", "el contenedor usa pixel_upscale")
	check(vp.canvas_item_default_texture_filter == Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST, "dentro del viewport no se suaviza")
	check(vp.snap_2d_transforms_to_pixel and vp.snap_2d_vertices_to_pixel, "el viewport ajusta a píxel entero")
	hud.free()


func test_sprite_shader_has_flash_and_dissolve() -> void:
	var shader := load("res://shaders/pixel_sprite.gdshader") as Shader
	var names := shader.get_shader_uniform_list().map(func(u): return u.name)
	check("flash" in names and "dissolve" in names, "pixel_sprite tiene flash y dissolve (%s)" % [names])
```

- [ ] **Step 2: Ejecutar y ver que fallan**

Run: `D:/Software/Godot/godot_ver4.5.exe --headless --path . res://scenes/tests/PixelTests.tscn`
Expected: `FALLO test_hero_strip_renders_at_216x96` (stretch_shrink 1) y error al cargar `pixel_sprite.gdshader`; código de salida 1.

- [ ] **Step 3: Crear los sombreadores y configurar el contenedor**

Crear `shaders/pixel_upscale.gdshader`:

```glsl
shader_type canvas_item;

// Ampliación de la franja pixel ("sharp bilinear"): cada píxel del arte se ve con su color exacto y
// solo se mezcla en su borde, así los píxeles salen regulares aunque la escala no sea entera
// (ventana de 540, móviles de 720 o 1440 de ancho). Necesita filtro lineal en el nodo que lo usa.

void fragment() {
	vec2 size = 1.0 / TEXTURE_PIXEL_SIZE;
	vec2 pix = UV * size;
	vec2 seam = floor(pix + 0.5);
	vec2 w = max(fwidth(pix), vec2(1e-5));
	pix = seam + clamp((pix - seam) / w, -0.5, 0.5);
	COLOR = texture(TEXTURE, pix / size);
}
```

Crear `shaders/pixel_sprite.gdshader`:

```glsl
shader_type canvas_item;

// Sprites de la franja: destello al recibir daño (mezcla hacia flash_color) y disolución por patrón
// de píxeles para aparecer y caer sin escalar. El patrón es una matriz de Bayer 4x4 sobre el píxel del arte.

uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform float dissolve : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0);

const float BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

void fragment() {
	ivec2 p = ivec2(floor(UV / TEXTURE_PIXEL_SIZE));
	float threshold = (BAYER[(p.y % 4) * 4 + (p.x % 4)] + 0.5) / 16.0;
	if (threshold < dissolve) {
		discard;
	}
	vec4 c = COLOR;
	c.rgb = mix(c.rgb, flash_color.rgb, flash);
	COLOR = c;
}
```

En `scenes/UI/HUD_Main.tscn`:

1. Cambiar la primera línea `load_steps=16` por `load_steps=18`.
2. Después de la línea `[ext_resource type="Script" path="res://scripts/ui/ForgeIdleFX.gd" id="13_forge_idle"]`, añadir:
```
[ext_resource type="Shader" path="res://shaders/pixel_upscale.gdshader" id="14_pixel_upscale"]
```
3. Antes de `[node name="HUD_Main" type="Control"]`, añadir:
```
[sub_resource type="ShaderMaterial" id="ShaderMaterial_pixel_upscale"]
shader = ExtResource("14_pixel_upscale")

```
4. Sustituir los nodos `HeroViewPanel` y `HeroViewport` por:
```
[node name="HeroViewPanel" type="SubViewportContainer" parent="."]
texture_filter = 2
material = SubResource("ShaderMaterial_pixel_upscale")
layout_mode = 1
anchors_preset = 10
anchor_right = 1.0
offset_bottom = 480.0
grow_horizontal = 2
stretch = true
stretch_shrink = 5

[node name="HeroViewport" type="SubViewport" parent="HeroViewPanel"]
transparent_bg = true
handle_input_locally = false
snap_2d_transforms_to_pixel = true
snap_2d_vertices_to_pixel = true
canvas_item_default_texture_filter = 0
size = Vector2i(216, 96)
render_target_update_mode = 4
```

- [ ] **Step 4: Ejecutar y ver que pasan**

Run: `D:/Software/Godot/godot_ver4.5.exe --headless --path . res://scenes/tests/PixelTests.tscn`
Expected: `0 fallos`, código 0.

- [ ] **Step 5: Punto de control (sin commit)**

Run: `git diff --stat scenes/UI/HUD_Main.tscn && git status --short shaders`

---

### Task 5: Cámara en píxeles enteros

**Files:**
- Modify (reescribir): `scripts/gameplay/visual/CorridorCamera.gd`
- Test: `scripts/tests/PixelTests.gd` (añadir)

**Interfaces:**
- Produces: la misma API que hoy (`snap_to(x, y)`, `set_target_x(x)`, `add_trauma(amount)`, `punch(amount := 0.04)`); `punch()` queda sin efecto (el zoom deformaba el pixel art). Posición y temblor siempre enteros; temblor máximo 3×2 px; sin giro ni zoom.

- [ ] **Step 1: Escribir la prueba que falla**

Añadir a `scripts/tests/PixelTests.gd`:

```gdscript
# ─── Tarea 5: cámara ───────────────────────────────────────────────────

func test_camera_moves_in_whole_pixels() -> void:
	var cam := Camera2D.new()
	cam.set_script(load("res://scripts/gameplay/visual/CorridorCamera.gd"))
	add_child(cam)
	cam.snap_to(10.4, 48.0)
	check(cam.position == Vector2(10, 48), "snap_to redondea a píxel entero (%s)" % cam.position)
	cam.set_target_x(57.3)
	for i in 5:
		cam._process(0.05)
		check(cam.position.x == roundf(cam.position.x), "la cámara sigue en píxeles enteros (%s)" % cam.position)
	cam.add_trauma(1.0)
	for i in 10:
		cam._process(0.016)
		check(absf(cam.offset.x) <= 3.0 and absf(cam.offset.y) <= 2.0, "el temblor no pasa de 3x2 (%s)" % cam.offset)
		check(cam.offset == cam.offset.round(), "el temblor es de píxeles enteros (%s)" % cam.offset)
	cam.punch(0.2)
	cam._process(0.016)
	check(cam.rotation == 0.0 and cam.zoom == Vector2.ONE, "sin giro ni zoom")
	cam.queue_free()
```

- [ ] **Step 2: Ejecutar y ver que falla**

Run: `D:/Software/Godot/godot_ver4.5.exe --headless --path . res://scenes/tests/PixelTests.tscn`
Expected: `FALLO test_camera_moves_in_whole_pixels` (snap_to no redondea, temblor de 14×10 y zoom distinto de 1).

- [ ] **Step 3: Reescribir la cámara**

Sustituir todo `scripts/gameplay/visual/CorridorCamera.gd` por:

```gdscript
extends Camera2D

## Cámara del corredor pixel: sigue al héroe en X con suavizado, altura fija y shake por "trauma".
## Todo en píxeles enteros del arte (216x96): sin giro ni zoom, que deforman el pixel art.
## El trauma decae solo; el desplazamiento es trauma² para que los golpes pequeños apenas muevan.

const MAX_OFFSET := Vector2(3, 2)
const TRAUMA_DECAY := 1.6
const FOLLOW_SHARPNESS := 6.0

var trauma := 0.0
var _t := 0.0
var _target_x := 0.0
var _x := 0.0  # posición suavizada, sin redondear


func _ready() -> void:
	ignore_rotation = true
	_x = position.x


## Coloca la cámara al instante (respawn, arranque).
func snap_to(x: float, y: float) -> void:
	_target_x = x
	_x = x
	position = Vector2(roundf(x), roundf(y))
	reset_smoothing()


func set_target_x(x: float) -> void:
	_target_x = x


func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)


## Compatibilidad: el zoom de impacto deformaba el pixel art y se ha quitado. El temblor lo da add_trauma().
func punch(_amount: float = 0.04) -> void:
	pass


func _process(delta: float) -> void:
	_t += delta
	_x = lerpf(_x, _target_x, 1.0 - exp(-FOLLOW_SHARPNESS * delta))
	position.x = roundf(_x)
	trauma = maxf(0.0, trauma - TRAUMA_DECAY * delta)
	var shake := trauma * trauma
	offset = Vector2(
		roundf(MAX_OFFSET.x * shake * _noise(_t * 31.0, 0.0)),
		roundf(MAX_OFFSET.y * shake * _noise(_t * 29.0, 7.3))
	)


## Ruido suave barato en [-1, 1] (suma de senos incommensurables).
func _noise(x: float, seed_off: float) -> float:
	return (sin(x + seed_off) * 0.6 + sin(x * 1.73 + seed_off * 2.1) * 0.3 + sin(x * 3.11 + seed_off * 0.7) * 0.1)
```

- [ ] **Step 4: Ejecutar y ver que pasa**

Run: `D:/Software/Godot/godot_ver4.5.exe --headless --path . res://scenes/tests/PixelTests.tscn`
Expected: `0 fallos`.

- [ ] **Step 5: Punto de control (sin commit)**

---

### Task 6: Tico como sprite

**Files:**
- Modify (reescribir el dibujo, conservar la lógica): `scripts/gameplay/Hero.gd`
- Modify: `scripts/ui/EquipmentPanel.gd` (función `_create_puppet`, líneas del escalado)
- Test: `scripts/tests/PixelTests.gd` (añadir)

**Interfaces:**
- Consumes: `PixelSprites`, `PixelFont`, `PixelHud`, `PixelView.HERO_START`, `pixel_sprite.gdshader`.
- Produces: la API pública de siempre con unidades nuevas (`reach = 9`, `half_width = 6`, `respawn(start_position := PixelView.HERO_START)`, `body_center() = position + (0, center_y)`), más:
  - `hud_bar_rect() -> Rect2` y `hud_label_rect() -> Rect2`, relativos al nodo.
  - Privados que usan las pruebas: `_sprite: Sprite2D`, `_apply_sprite()`, `_update_sprite()`.
  - `_materialize` sigue existiendo (lo usa `EquipmentPanel`; la fase 2 lo cambia por `play_materialize()`).

- [ ] **Step 1: Escribir las pruebas que fallan**

Añadir a `scripts/tests/PixelTests.gd`:

```gdscript
# ─── Tarea 6: Tico ─────────────────────────────────────────────────────

func _new_hero() -> Node2D:
	var hero: Node2D = load("res://scenes/Hero.tscn").instantiate()
	hero.remove_from_group("hero")  # que no lo confundan con el héroe de la partida
	add_child(hero)
	return hero


func test_hero_uses_pixel_units() -> void:
	var hero := _new_hero()
	check(hero.reach == 9.0 and hero.half_width == 6.0, "alcance y medio ancho en píxeles del arte")
	hero.respawn(PixelView.HERO_START)
	check(hero.position == PixelView.HERO_START, "reaparece en HERO_START")
	var c: Vector2 = hero.body_center()
	check(c.x == hero.position.x and c.y < hero.position.y - 8.0 and c.y > hero.position.y - 20.0, "centro del cuerpo a media altura (%s)" % c)
	hero.queue_free()


func test_hero_sprite_stands_on_the_floor() -> void:
	var hero := _new_hero()
	hero._update_sprite()
	var spr: Sprite2D = hero._sprite
	check(spr.position == Vector2(-16, -29), "en reposo el fotograma apoya los pies en el origen (%s)" % spr.position)
	check(spr.hframes == 2, "tira de reposo de 2 fotogramas")
	check((spr.material as ShaderMaterial).shader.resource_path == "res://shaders/pixel_sprite.gdshader", "usa pixel_sprite")
	hero._strike = 1.0
	hero._update_sprite()
	check(spr.position.x > -16.0, "la estocada lo adelanta hacia el enemigo (%s)" % spr.position)
	hero.queue_free()


func test_hero_sprite_follows_the_sword() -> void:
	var hero := _new_hero()
	var cases := [
		[{}, "tico_0"],
		[{"main_hand": {"tier": "rare", "rarity": "advanced"}}, "tico_1"],
		[{"main_hand": {"tier": "legendary", "rarity": "master"}}, "tico_2"],
	]
	for c in cases:
		hero.gear = c[0]
		hero._apply_sprite()
		check(hero._sprite.texture.resource_path.ends_with("hero/%s.png" % c[1]), "espada %s → %s" % [c[0], c[1]])
	hero.queue_free()


func test_dead_hero_stays_hidden_after_equipping() -> void:
	var hero := _new_hero()
	hero.alive = false
	hero.gear = {"main_hand": {"tier": "common", "rarity": "basic"}}
	hero._apply_sprite()
	hero._update_sprite()
	check(not hero._sprite.visible, "equipar durante la caída no hace reaparecer el sprite")
	hero.queue_free()
```

- [ ] **Step 2: Ejecutar y ver que fallan**

Run: `D:/Software/Godot/godot_ver4.5.exe --headless --path . res://scenes/tests/PixelTests.tscn`
Expected: `FALLO` en las cuatro pruebas de Tico (`reach` vale 44, no existe `_sprite`, `_apply_sprite` ni `_update_sprite`).

- [ ] **Step 3: Reescribir `Hero.gd`**

Sustituir todo `scripts/gameplay/Hero.gd` por:

```gdscript
extends CharacterBody2D

## Héroe del corredor (IA) en pixel art. La lógica es la de siempre (stats del equipo + ataques por cooldown):
##  - sprite de 32x32 con reposo de 2 fotogramas. Provisional hasta la fase 2 del spec
##    doc/specs/2026-09-27-franja-combate-pixel-art.md: la tira se elige según la espada que lleva,
##  - carga, estocada y retroceso como desplazamientos en píxeles enteros; destello al recibir daño y
##    disolución al reaparecer con shaders/pixel_sprite.gdshader,
##  - barra de vida y nombre en fuente pixel,
##  - la armadura reduce el daño físico.
## Unidades: píxeles del arte (la franja mide 216x96). El origen del nodo es el centro de los pies.

signal stats_reset
signal died
signal respawned
signal attack_triggered  # Emitida cuando el cooldown de ataque llega a 0
signal pulse_hit(amount: int, target_pos: Vector2)  # Pulso mágico aplicado (posición previa al daño)

const SPRITE_SHADER := preload("res://shaders/pixel_sprite.gdshader")
const HERO_NAME := "Tico"

const BASE_HP := 60
const BASE_DMG := 6.0
const BASE_APS := 1.0
const BASE_STR := 10
const BASE_AGI := 10
const BASE_INT := 8
const PULSE_INTERVAL := 2.5

# Armadura: reducción con rendimientos decrecientes (armor / (armor + K)), con tope.
const ARMOR_K := 40.0
const MAX_MITIGATION := 0.6

const WINDUP_TIME := 0.16
const HURT_TIME := 0.2
const MATERIALIZE_TIME := 0.5
const IDLE_FRAME_TIME := 0.5

## Colores de Tico para los fragmentos al morir (chaleco, bufanda, piel, pelo)
const DEATH_COLORS := [Color("c8905a"), Color("c23644"), Color("f7d2ae"), Color("8f4f2c")]

## Color de cada tier de calidad (más suave que los colores puros de CraftedItem)
const TIER_COLORS := {
	"common": Color("cfd6dc"),
	"uncommon": Color("6ad16a"),
	"rare": Color("4ea3ff"),
	"epic": Color("b46bff"),
	"legendary": Color("ffa629"),
}

var STR: int = BASE_STR
var AGI: int = BASE_AGI
var INT: int = BASE_INT

var max_hp: int = BASE_HP
var hp: int = BASE_HP
var dmg: float = BASE_DMG
var aps: float = BASE_APS
var crit_p: float = 0.0
var crit_m: float = 1.5
var armor: int = 0
var atk_timer: float = 0.0
var pulse_timer: float = PULSE_INTERVAL
var alive: bool = true
var is_attacking: bool = false
var debug_invincible: bool = false
var stored_hp: int = 0
var stored_dmg: float = 0.0

var size: Vector2 = Vector2(12, 28)  # Compatibilidad
var half_width: float = 6.0
var reach: float = 9.0  # Alcance del arma (para decidir cuándo se engancha el combate)

## Lo actualiza el Corridor
var walking: bool = false
var walk_speed: float = 0.0
var fx: Node = null
var look_target: Vector2 = Vector2(1, 0)  # Compatibilidad: el sprite no mueve los ojos

## Equipo visible: slot → {"tier": String, "rarity": String}
var gear: Dictionary = {}
## false en el héroe de muestra del panel de Equipo (sin barra de vida)
var show_hud: bool = true

# Estado visual
var _t := 0.0
var _walk_phase := 0.0
var _last_step_sign := 1.0
var _windup := 0.0
var _strike := 0.0
var _strike_time := 0.22
var _hurt := 0.0
var _materialize := 1.0
var _hp_ghost := 1.0
var _ghost_delay := 0.0
var _block_flash := 0.0
var _sprite: Sprite2D
var _hud: Node2D
var _sprite_key := ""
var _metrics: Dictionary = {}


## Pinta barra y nombre por encima del sprite (los hijos se dibujan después que el padre).
class HudDrawer extends Node2D:
	var hero  # sin tipo: llama a métodos del script del héroe

	func _draw() -> void:
		if hero:
			hero._draw_hud(self)


func _ready():
	_sprite = Sprite2D.new()
	_sprite.centered = false
	var mat := ShaderMaterial.new()
	mat.shader = SPRITE_SHADER
	_sprite.material = mat
	add_child(_sprite)
	_hud = HudDrawer.new()
	_hud.hero = self
	add_child(_hud)
	respawn(position)


func _process(delta: float) -> void:
	_t += delta
	_hurt = maxf(0.0, _hurt - delta)
	_block_flash = maxf(0.0, _block_flash - delta * 3.0)
	if _strike > 0.0:
		_strike = maxf(0.0, _strike - delta / _strike_time)
	if not is_attacking:
		_windup = move_toward(_windup, 0.0, delta * 6.0)
	if _materialize < 1.0:
		_materialize = minf(1.0, _materialize + delta / MATERIALIZE_TIME)
	if walking and alive:
		# Misma cadencia de pasos que a 1080: 190 / 26 = 38 / 5.2
		_walk_phase += delta * maxf(walk_speed, 12.0) / 5.2
		var s := signf(sin(_walk_phase))
		if s != _last_step_sign:
			_last_step_sign = s
			if fx and s > 0.0:
				fx.dust_puff(position + Vector2(-1, 0), Color(0.7, 0.66, 0.6, 0.35), 2, 0.5)
	else:
		_walk_phase = 0.0
	# Barra fantasma
	var ratio := _hp_ratio()
	if _ghost_delay > 0.0:
		_ghost_delay -= delta
	elif _hp_ghost > ratio:
		_hp_ghost = move_toward(_hp_ghost, ratio, delta * 1.2)
	_hp_ghost = maxf(_hp_ghost, ratio)
	_update_sprite()
	queue_redraw()
	if _hud:
		_hud.queue_redraw()


# --- Stats ------------------------------------------------------------

func reset_stats():
	var equipment_stats := {}
	var inv_manager = get_node_or_null("/root/InventoryManager")
	if inv_manager and inv_manager.has_method("calculate_total_stats"):
		equipment_stats = inv_manager.calculate_total_stats()

	STR = BASE_STR + int(equipment_stats.get("str", 0))
	AGI = BASE_AGI + int(equipment_stats.get("agi", 0))
	INT = BASE_INT + int(equipment_stats.get("int", 0))

	var bonus_hp: int = int(equipment_stats.get("hp", 0))
	var bonus_dmg: float = float(equipment_stats.get("damage", 0))
	var bonus_aps: float = float(equipment_stats.get("aps", 0.0))
	var bonus_crit_p: float = float(equipment_stats.get("crit", 0.0))
	var bonus_armor: int = int(equipment_stats.get("armor", 0))

	max_hp = BASE_HP + STR * 10 + bonus_hp
	hp = max_hp
	dmg = BASE_DMG + STR * 1.5 + bonus_dmg
	aps = clamp(BASE_APS + AGI * 0.02 + bonus_aps, 0.3, 5.0)
	crit_p = clamp(AGI * 0.005 + bonus_crit_p, 0.0, 0.75)
	crit_m = clamp(1.5 + INT * 0.01, 1.0, 3.0)
	armor = bonus_armor
	atk_timer = 1.0 / aps
	pulse_timer = PULSE_INTERVAL
	# `alive` no se toca aquí: equipar durante la caída no debe resucitarlo (lo hace respawn())
	_hp_ghost = 1.0
	_strike_time = clampf(0.6 / aps, 0.12, 0.24)
	refresh_gear()

	emit_signal("stats_reset")
	DebugManager.log_msg(&"combat", "Hero stats — HP:%d DMG:%.1f APS:%.2f CRIT:%.0f%% ARM:%d (-%d%%)" % [max_hp, dmg, aps, crit_p * 100, armor, int(armor_mitigation() * 100.0)])


## Lee el equipo actual (espada, escudo, casco, botas) y elige el sprite.
func refresh_gear() -> void:
	gear.clear()
	var inv_manager = get_node_or_null("/root/InventoryManager")
	if inv_manager != null and "equipped_items" in inv_manager:
		for slot in inv_manager.equipped_items.keys():
			var item = inv_manager.equipped_items[slot]
			if item == null:
				continue
			var rarity := "basic"
			if item.item_resource:
				rarity = String(item.item_resource.rarity)
			gear[String(slot)] = {"tier": item.get_quality_tier(), "rarity": rarity}
	_apply_sprite()


func expected_dps() -> float:
	var hit := dmg * (1.0 + crit_p * (crit_m - 1.0))
	var pulse_dmg := (INT * 3.0) / PULSE_INTERVAL
	return aps * hit + pulse_dmg


## Fracción de daño físico que absorbe la armadura (0..MAX_MITIGATION).
func armor_mitigation() -> float:
	if armor <= 0:
		return 0.0
	return minf(MAX_MITIGATION, float(armor) / (float(armor) + ARMOR_K))


# --- Combate ----------------------------------------------------------

## Aplica daño y devuelve el daño real recibido (tras armadura). El pulso mágico ignora la armadura.
func take_damage(amount: int, is_pulse: bool = false) -> int:
	if debug_invincible or not alive:
		return 0
	var final := amount
	if not is_pulse:
		final = maxi(1, int(round(float(amount) * (1.0 - armor_mitigation()))))
		if final < amount and armor_mitigation() >= 0.15:
			_block_flash = 1.0
	hp = max(0, hp - final)
	_hurt = HURT_TIME
	_ghost_delay = 0.35
	if hp == 0:
		alive = false
		_spawn_death_fx()
		emit_signal("died")
	return final


func set_invincible(invincible: bool) -> void:
	debug_invincible = invincible
	if invincible:
		stored_hp = hp
		stored_dmg = dmg
		hp = 10000
		max_hp = 10000
		dmg = 10000.0
	else:
		hp = stored_hp if stored_hp > 0 else BASE_HP
		max_hp = BASE_HP
		dmg = stored_dmg if stored_dmg > 0 else BASE_DMG
		reset_stats()


func attack(target, _particles: Array = []) -> void:
	"""Gestiona el timer de ataque. Emite attack_triggered cuando el cooldown llega a 0."""
	if not alive or target == null or not target.alive:
		is_attacking = false
		return
	is_attacking = true
	look_target = target.position
	atk_timer -= get_process_delta_time()
	# Anticipación ligada al cooldown: el ritmo de ataque no cambia
	var windup := minf(WINDUP_TIME, 0.45 / aps)
	if atk_timer <= windup:
		_windup = clampf(1.0 - atk_timer / windup, 0.0, 1.0)
	if atk_timer <= 0.0:
		_strike = 1.0
		_windup = 0.0
		emit_signal("attack_triggered")
		atk_timer = 1.0 / aps


func pulse(target, _particles: Array = []) -> void:
	if not alive or target == null or not target.alive:
		return
	pulse_timer -= get_process_delta_time()
	if pulse_timer <= 0.0:
		pulse_timer += PULSE_INTERVAL
		# La posición se toma antes del daño: si el enemigo muere, se recoloca en la sala siguiente
		var target_pos: Vector2 = target.body_center() if target.has_method("body_center") else target.position
		var dealt = target.take_damage(INT * 3, true)
		emit_signal("pulse_hit", int(dealt) if dealt != null else INT * 3, target_pos)


func prepare_for_combat() -> void:
	atk_timer = 1.0 / aps
	pulse_timer = PULSE_INTERVAL
	is_attacking = false


func respawn(start_position: Vector2 = PixelView.HERO_START) -> void:
	reset_stats()
	position = start_position
	velocity = Vector2.ZERO
	alive = true
	is_attacking = false
	_windup = 0.0
	_strike = 0.0
	_hurt = 0.0
	_materialize = 0.0
	emit_signal("respawned")


func apply_loadout(_loadout: Dictionary) -> void:
	reset_stats()


func body_center() -> Vector2:
	return position + Vector2(0, float(_metrics.get("center_y", -14.0)))


func _spawn_death_fx() -> void:
	if fx == null:
		return
	var c := body_center()
	fx.shatter(c, DEATH_COLORS, 16, Vector2(1, 3), position.y)
	fx.ring(c, Color(0.75, 0.9, 1.0, 0.9), 2.0, 24.0, 0.45, 1.0)
	fx.spark_burst(c, Vector2.UP, Color("9fd0ff"), 16, Vector2(32, 84), PI)


# --- Dibujo -----------------------------------------------------------

func _hp_ratio() -> float:
	return clampf(float(hp) / float(max_hp), 0.0, 1.0) if max_hp > 0 else 0.0


func _rarity(slot: String) -> String:
	return String(gear[slot].get("rarity", "basic")) if gear.has(slot) else ""


## Provisional (fase 1): la tira de Tico según la espada. La fase 2 compone una capa por pieza.
func _hero_sprite_key() -> String:
	match _rarity("main_hand"):
		"":
			return "hero/tico_0"
		"master":
			return "hero/tico_2"
		_:
			return "hero/tico_1"


func _apply_sprite() -> void:
	if _sprite == null:
		return
	var key := _hero_sprite_key()
	if key == _sprite_key:
		return
	_sprite_key = key
	_metrics = PixelSprites.metrics(key)
	_sprite.texture = PixelSprites.texture(key)
	_sprite.hframes = maxi(1, int(_metrics.get("frames", 1)))


func _update_sprite() -> void:
	if _sprite == null:
		return
	_sprite.visible = alive
	if not alive:
		return
	_sprite.frame = int(_t / IDLE_FRAME_TIME) % _sprite.hframes
	var flash := clampf(_hurt / HURT_TIME, 0.0, 1.0)
	var lunge := -1.6 * _windup + 5.2 * pow(_strike, 1.4) - 2.4 * flash
	var bob := 1.0 if walking and absf(sin(_walk_phase)) > 0.5 else 0.0
	_sprite.position = _sprite_origin() + Vector2(roundf(lunge), -bob)
	var mat := _sprite.material as ShaderMaterial
	mat.set_shader_parameter("flash", flash * 0.8)
	mat.set_shader_parameter("dissolve", 1.0 - clampf(_materialize * 1.6, 0.0, 1.0))


## Esquina superior izquierda del fotograma para que los pies apoyen en el origen del nodo.
func _sprite_origin() -> Vector2:
	var fw := float(_metrics.get("frame_w", 32))
	var ground := float(_metrics.get("ground_row", 28))
	return Vector2(-fw * 0.5, -(ground + 1.0))


## Barra de vida relativa al nodo: 1 px por encima de la cabeza y 2 px hacia atrás para no
## chocar con la del enemigo en combate.
func hud_bar_rect() -> Rect2:
	var top := roundf(float(_metrics.get("center_y", -14.0)) - float(_metrics.get("body_height", 28)) * 0.5)
	return Rect2(-13, top - 5, 22, 3)


## Nombre centrado sobre la barra, relativo al nodo.
func hud_label_rect() -> Rect2:
	var bar := hud_bar_rect()
	var w := PixelFont.width(HERO_NAME)
	return Rect2(roundf(bar.get_center().x - w * 0.5), bar.position.y - PixelFont.SMALL_SIZE, w, PixelFont.SMALL_SIZE)


func _draw() -> void:
	if not alive:
		return
	PixelHud.draw_shadow(self, Vector2.ZERO, 14, clampf(_materialize * 1.6, 0.0, 1.0))


func _draw_hud(canvas: CanvasItem) -> void:
	if not show_hud or not alive:
		return
	var a := clampf(_materialize * 1.6, 0.0, 1.0)
	var bar := hud_bar_rect()
	PixelHud.draw_bar(canvas, bar, _hp_ratio(), _hp_ghost, _bar_color(), a)
	PixelFont.draw(canvas, hud_label_rect().position, HERO_NAME, Color("fef6e4"), a)
	if armor > 0:
		var icon_pos := bar.position + Vector2(-6, -1)
		PixelHud.draw_armor_icon(canvas, icon_pos, a)
		if _block_flash > 0.0:
			PixelHud.draw_armor_icon(canvas, icon_pos, a * _block_flash, Color.WHITE)


func _bar_color() -> Color:
	var ratio := _hp_ratio()
	if ratio <= 0.3:
		return Color("e5433b").lerp(Color.WHITE, 0.25 + 0.25 * sin(_t * 12.0))
	if ratio <= 0.6:
		return Color("f0b43c")
	return Color("54d162")
```

En `scripts/ui/EquipmentPanel.gd`, dentro de `_create_puppet()`, sustituir la línea `_puppet.scale = Vector2(2.5, 2.5)` por:

```gdscript
	_puppet.scale = Vector2(8, 8)  # pixel art a escala entera (fase 2: mini-lienzo propio)
	_puppet.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
```

- [ ] **Step 4: Importar, ejecutar y ver que pasan**

Run:
```bash
D:/Software/Godot/godot_ver4.5.exe --headless --path . --import
D:/Software/Godot/godot_ver4.5.exe --headless --path . res://scenes/tests/PixelTests.tscn
```
Expected: `0 fallos`, sin `SCRIPT ERROR` en la salida.

- [ ] **Step 5: Punto de control (sin commit)**

Run: `git diff --stat scripts/gameplay/Hero.gd scripts/ui/EquipmentPanel.gd`

---

### Task 7: Enemigos y jefes como sprites

**Files:**
- Modify (reescribir el dibujo, conservar la lógica): `scripts/gameplay/Enemy.gd`
- Modify: `scripts/gameplay/visual/EnemyArchetypes.gd` (quitar medidas y `crown`)
- Modify: `scripts/gameplay/Corridor.gd:217-218` (quitar la llamada a `set_biome_palette`)
- Test: `scripts/tests/PixelTests.gd` (añadir)

**Interfaces:**
- Consumes: `PixelSprites.enemy_key/metrics/texture`, `PixelFont`, `PixelHud`, `pixel_sprite.gdshader`.
- Produces: la API pública de siempre (`configure_for_level`, `wake`, `is_awake`, `alert`, `take_damage`, `attack`, `pulse`, `prepare_for_combat`, `cast_origin`, `body_center`, `death_info`, `half_width`, `body_height`, `hover`, `style`, `accent_color`, `display_name`, `is_boss`, `level`) con medidas del sprite, más `hud_bar_rect()`, `hud_label() -> String` y `hud_label_rect()`. Desaparecen `set_biome_palette`, `rim_color`, `size_mult`, `boss_crown` y `shape`.

- [ ] **Step 1: Escribir las pruebas que fallan**

Añadir a `scripts/tests/PixelTests.gd`:

```gdscript
# ─── Tarea 7: enemigos ─────────────────────────────────────────────────

func _new_enemy() -> Node2D:
	var e: Node2D = load("res://scenes/Enemy.tscn").instantiate()
	e.remove_from_group("enemy")
	add_child(e)
	return e


func test_enemy_takes_sprite_and_size_from_metrics() -> void:
	var e := _new_enemy()
	e.configure_for_level(1, false)  # sala 1 de Catacumbas: siempre un Limo
	check(e.archetype == &"slime", "la sala 1 trae un Limo")
	var m := PixelSprites.metrics("enemies/slime")
	check(e.half_width == float(m.half_width) and e.body_height == float(m.body_height), "medidas del sprite")
	check(e._sprite.texture.resource_path.ends_with("enemies/slime.png"), "tira del Limo")
	check(e.body_center().y < e.position.y and e.cast_origin().x < e.position.x, "centro sobre los pies y orbe hacia el héroe")
	e.queue_free()


func test_each_biome_has_its_boss_sprite() -> void:
	var e := _new_enemy()
	for i in 5:
		e.configure_for_level((i + 1) * 10, true)
		check(e._sprite.texture.resource_path.ends_with("bosses/boss_%d.png" % i), "jefe de la sala %d" % ((i + 1) * 10))
		check(e.display_name == EnemyArchetypes.BOSS_NAMES[i], "nombre del jefe %d" % i)
	e.queue_free()


func test_enemy_sprite_faces_the_hero_and_stands_on_floor() -> void:
	var e := _new_enemy()
	e.configure_for_level(1, false)
	e.wake()
	e._intro = 1.0
	e._update_sprite()
	check(e._sprite.visible, "despierto y vivo se ve")
	check(e._sprite.position == Vector2(-16, -29), "en reposo apoya los pies en el origen (%s)" % e._sprite.position)
	e._strike = 1.0
	e._update_sprite()
	check(e._sprite.position.x < -16.0, "el golpe lo acerca al héroe (%s)" % e._sprite.position)
	e.queue_free()


func test_names_do_not_overlap_in_combat() -> void:
	var hero := _new_hero()
	var e := _new_enemy()
	var hero_x := PixelView.VIEW_W * PixelView.HERO_SCREEN_X
	for id in [&"slime", &"skeleton", &"bat", &"golem", &"wraith"]:
		e.level = 99
		e._apply_archetype(id)
		_check_labels(hero, e, hero_x)
	for room in [60, 70, 80, 90, 100]:
		e.configure_for_level(room, true)
		_check_labels(hero, e, hero_x)
	hero.queue_free()
	e.queue_free()


func _check_labels(hero: Node2D, e: Node2D, hero_x: float) -> void:
	var ex: float = hero_x + hero.reach + e.half_width + 3.0
	var hl: Rect2 = hero.hud_label_rect()
	hl.position += Vector2(hero_x, PixelView.FLOOR_Y)
	var el: Rect2 = e.hud_label_rect()
	el.position += Vector2(ex, PixelView.FLOOR_Y)
	check(not hl.intersects(el), "los nombres de Tico y %s no se pisan" % e.hud_label())
	check(el.end.x <= PixelView.VIEW_W, "%s cabe en la franja (acaba en %d)" % [e.hud_label(), int(el.end.x)])
	check(el.position.y >= 0.0, "%s no se sale por arriba" % e.hud_label())
```

- [ ] **Step 2: Ejecutar y ver que fallan**

Run: `D:/Software/Godot/godot_ver4.5.exe --headless --path . res://scenes/tests/PixelTests.tscn`
Expected: `FALLO` en las cuatro pruebas de enemigos (no existe `_sprite`, `hud_label_rect` ni `_update_sprite`).

- [ ] **Step 3: Quitar las medidas de `EnemyArchetypes`**

En `scripts/gameplay/visual/EnemyArchetypes.gd`:

1. Añadir al comentario de cabecera, después de la línea `## para no romper la curva de dificultad…`:
```gdscript
## Las medidas (medio ancho, alto, vuelo) salen del sprite: art/sprites/pixel/metrics.json (PixelSprites).
## body/shade/accent son los colores de los efectos (fragmentos, chispas, orbe).
```
2. Sustituir la constante `DATA` completa (sin `"half_w"`, `"height"` ni `"hover"`) por:
```gdscript
const DATA := {
	&"slime": {
		"name": "Limo", "hp": 1.25, "dmg": 0.85, "aps": 0.95,
		"body": Color("63c95b"), "shade": Color("3b8a3a"), "accent": Color("b6ff9e"),
		"windup": 0.24, "strike": 0.26, "style": "hop",
	},
	&"skeleton": {
		"name": "Esqueleto", "hp": 1.0, "dmg": 1.0, "aps": 1.0,
		"body": Color("e8ddc2"), "shade": Color("ab9c7c"), "accent": Color("ff4a3a"),
		"windup": 0.22, "strike": 0.22, "style": "swing",
	},
	&"bat": {
		"name": "Murciélago", "hp": 0.7, "dmg": 0.75, "aps": 1.9,
		"body": Color("7c4bb5"), "shade": Color("4f2d7a"), "accent": Color("ff5a5a"),
		"windup": 0.15, "strike": 0.2, "style": "dive",
	},
	&"golem": {
		"name": "Gólem", "hp": 1.25, "dmg": 1.6, "aps": 0.5,
		"body": Color("8b8f99"), "shade": Color("5b5e68"), "accent": Color("ffb347"),
		"windup": 0.38, "strike": 0.3, "style": "slam",
	},
	&"wraith": {
		"name": "Espectro", "hp": 0.8, "dmg": 1.25, "aps": 1.0,
		"body": Color("a6ece6"), "shade": Color("5fa6a8"), "accent": Color("c77dff"),
		"windup": 0.32, "strike": 0.2, "style": "cast",
	},
	&"boss": {
		"name": "Jefe", "hp": 1.0, "dmg": 1.0, "aps": 1.0,
		"body": Color("e2a82c"), "shade": Color("9a6a12"), "accent": Color("ff3b30"),
		"windup": 0.34, "strike": 0.3, "style": "slam",
	},
}
```
3. Sustituir el comentario y la constante `BOSS_STYLES` por:
```gdscript
## Colores de efectos del jefe de cada bioma (su aspecto es el sprite de art/sprites/pixel/bosses/).
const BOSS_STYLES := [
	{"body": Color("e2a82c"), "shade": Color("9a6a12"), "accent": Color("ff3b30")},
	{"body": Color("73c24c"), "shade": Color("3d7a2a"), "accent": Color("e8ff7a")},
	{"body": Color("dd5a2c"), "shade": Color("8a2a12"), "accent": Color("ffd23f")},
	{"body": Color("93d6f2"), "shade": Color("4a88b0"), "accent": Color("ffffff")},
	{"body": Color("9d5cdb"), "shade": Color("56308a"), "accent": Color("ff6af0")},
]
```

En `scripts/gameplay/Corridor.gd`, dentro de `spawn_enemy`, borrar:
```gdscript
	if enemy.has_method("set_biome_palette"):
		enemy.set_biome_palette(Biomes.biome_for_room(lv))
```

- [ ] **Step 4: Reescribir `Enemy.gd`**

Sustituir todo `scripts/gameplay/Enemy.gd` por:

```gdscript
extends CharacterBody2D

## Enemigo del corredor en pixel art.
## Lógica de combate original (stats por nivel + ataques por cooldown) y encima:
##  - arquetipos (Limo, Esqueleto, Murciélago, Gólem, Espectro y el jefe de cada bioma) con su sprite,
##    que ya mira hacia el héroe (lo exporta tools/pixel_art); de momento solo el reposo de 2 fotogramas,
##  - entrada, carga, golpe y retroceso como desplazamientos en píxeles enteros; destello al recibir daño
##    y disolución al aparecer con shaders/pixel_sprite.gdshader,
##  - barra de vida con "daño fantasma", nombre y aviso "!" en fuente pixel.
## Unidades: píxeles del arte (la franja mide 216x96). El origen del nodo es el centro de los pies.

signal stats_reset
signal died(drops)
signal attack_triggered  # Emitida cuando el cooldown de ataque llega a 0
signal pulse_hit(amount: int, target_pos: Vector2)  # Pulso mágico aplicado (posición previa al daño)

const SPRITE_SHADER := preload("res://shaders/pixel_sprite.gdshader")
const DEFAULT_DROP_TABLE := preload("res://data/drops/basic_enemy_drop.tres")

const BASE_HP := 40
const BASE_DMG := 5.0
const BASE_APS := 0.8
const PULSE_INTERVAL := 2.5
const BOSS_LEVEL_MULTIPLIER := 1.6
const HURT_TIME := 0.18
const INTRO_TIME := 0.5
const IDLE_FRAME_TIME := 0.5
const MATERIAL_DROP_QTY := 15

var level: int = 1
var STR: float = 0.0
var AGI: float = 0.0
var INT: float = 0.0

var max_hp: int = BASE_HP
var hp: int = BASE_HP
var dmg: float = BASE_DMG
var aps: float = BASE_APS
var crit_p: float = 0.0
var crit_m: float = 1.5
var atk_timer: float = 0.0
var pulse_timer: float = PULSE_INTERVAL
var alive: bool = true
var is_attacking: bool = false

var size: Vector2 = Vector2(16, 25)  # Compatibilidad

@export var is_boss: bool = false
@export var drop_table: DropTable

# ─── Arquetipo ─────────────────────────────────────────────────────────
var archetype: StringName = &"skeleton"
var display_name: String = "Esqueleto"
var half_width: float = 8.0
var body_height: float = 25.0
var hover: float = 0.0
var style: String = "swing"
var windup_time: float = 0.22
var strike_time: float = 0.22
var body_color: Color = Color("e8ddc2")
var shade_color: Color = Color("ab9c7c")
var accent_color: Color = Color("ff4a3a")

var fx: Node = null  # CombatFX (lo asigna el Corridor)
var last_material_drop: Dictionary = {}  # {"item_id", "quantity"} del último botín
## Datos del último enemigo muerto. Se rellenan ANTES de emitir died, porque los que escuchan
## después (Corridor) ya ven al nodo recolocado en la sala siguiente.
var death_info: Dictionary = {}

var _rng := RandomNumberGenerator.new()
var _t := 0.0
var _hurt := 0.0
var _windup := 0.0
var _strike := 0.0
var _intro := 1.0
var _awake := false
var _alert := 0.0
var _hp_ghost := 1.0
var _ghost_delay := 0.0
var _cast_launched := false
var _landed := false
var _sprite: Sprite2D
var _hud: Node2D
var _metrics: Dictionary = {}


## Pinta barra, nombre y alerta por encima del sprite.
class HudDrawer extends Node2D:
	var enemy  # sin tipo: llama a métodos del script del enemigo

	func _draw() -> void:
		if enemy:
			enemy._draw_hud(self)


func _ready() -> void:
	if drop_table == null:
		drop_table = DEFAULT_DROP_TABLE
	_rng.randomize()
	_sprite = Sprite2D.new()
	_sprite.centered = false
	var mat := ShaderMaterial.new()
	mat.shader = SPRITE_SHADER
	_sprite.material = mat
	add_child(_sprite)
	_hud = HudDrawer.new()
	_hud.enemy = self
	add_child(_hud)
	_apply_archetype(archetype)
	reset_stats()


func _process(delta: float) -> void:
	_t += delta
	_hurt = maxf(0.0, _hurt - delta)
	if _strike > 0.0:
		_strike = maxf(0.0, _strike - delta / strike_time)
	if not is_attacking:
		_windup = move_toward(_windup, 0.0, delta * 5.0)
	if _awake and _intro < 1.0:
		_intro = minf(1.0, _intro + delta / INTRO_TIME)
		if not _landed and _intro >= 0.62:
			_landed = true
			_on_intro_landed()
	_alert = maxf(0.0, _alert - delta / 0.75)
	# Barra fantasma: espera un momento y luego alcanza a la vida real
	var ratio := _hp_ratio()
	if _ghost_delay > 0.0:
		_ghost_delay -= delta
	elif _hp_ghost > ratio:
		_hp_ghost = move_toward(_hp_ghost, ratio, delta * 1.4)
	_hp_ghost = maxf(_hp_ghost, ratio)
	_update_sprite()
	queue_redraw()
	if _hud:
		_hud.queue_redraw()


# ─── Configuración ─────────────────────────────────────────────────────

func configure_for_level(lv: int, boss: bool) -> void:
	level = lv
	is_boss = boss
	_apply_archetype(&"boss" if boss else EnemyArchetypes.pick_for_room(lv))
	reset_stats()
	_awake = false
	_intro = 0.0
	_landed = false
	_alert = 0.0
	_windup = 0.0
	_strike = 0.0
	_hurt = 0.0
	_hp_ghost = 1.0
	_cast_launched = false
	queue_redraw()


func _apply_archetype(id: StringName) -> void:
	archetype = id
	var d: Dictionary = EnemyArchetypes.get_data(id)
	display_name = EnemyArchetypes.boss_name_for_room(level) if id == &"boss" else String(d.name)
	style = d.style
	windup_time = d.windup
	strike_time = d.strike
	body_color = d.body
	shade_color = d.shade
	accent_color = d.accent
	if id == &"boss":
		var bs: Dictionary = EnemyArchetypes.boss_style_for_room(level)
		body_color = bs.body
		shade_color = bs.shade
		accent_color = bs.accent
	var key := PixelSprites.enemy_key(id, level)
	_metrics = PixelSprites.metrics(key)
	half_width = float(_metrics.get("half_width", 8))
	body_height = float(_metrics.get("body_height", 25))
	hover = float(_metrics.get("hover", 0))
	size = Vector2(half_width * 2.0, body_height)
	if _sprite:
		_sprite.texture = PixelSprites.texture(key)
		_sprite.hframes = maxi(1, int(_metrics.get("frames", 1)))


## Empieza la animación de entrada (el Corridor la llama cuando entra en pantalla).
func wake() -> void:
	if _awake:
		return
	_awake = true
	_intro = 0.0
	_landed = false


func is_awake() -> bool:
	return _awake


## "!" sobre la cabeza al empezar el combate.
func alert() -> void:
	_alert = 1.0


func reset_stats():
	var exp_factor := pow(1.04, level - 1)
	var lin_factor := 1.0 + 0.15 * (level - 1)
	var stat_scale := lin_factor * exp_factor
	var multiplier := (BOSS_LEVEL_MULTIPLIER if is_boss else 1.0)
	var d: Dictionary = EnemyArchetypes.get_data(archetype)

	STR = (3.0 + level * 1.5) * exp_factor
	AGI = (1.5 + level * 0.8) * sqrt(exp_factor)
	INT = (1.5 + level * 0.6) * sqrt(exp_factor)

	max_hp = maxi(1, int(BASE_HP * stat_scale * multiplier * float(d.hp)))
	hp = max_hp
	dmg = (BASE_DMG + STR * 1.5) * multiplier * float(d.dmg)
	aps = clamp(BASE_APS + AGI * 0.02, 0.3, 4.0) * float(d.aps)
	crit_p = min(0.5, AGI * 0.006)
	crit_m = clamp(1.5 + INT * 0.012, 1.0, 3.0)
	atk_timer = 1.0 / aps
	pulse_timer = PULSE_INTERVAL
	alive = true
	is_attacking = false
	DebugManager.log_msg(&"combat", "Enemy Lv%d %s: HP=%d, DMG=%.1f, APS=%.2f, scale=%.2f" % [level, archetype, max_hp, dmg, aps, stat_scale])
	emit_signal("stats_reset")


func expected_dps() -> float:
	var hit := dmg * (1.0 + crit_p * (crit_m - 1.0))
	var pulse_dmg := (INT * 3.0) / PULSE_INTERVAL
	return aps * hit + pulse_dmg


# ─── Combate ───────────────────────────────────────────────────────────

func take_damage(amount: int, _is_pulse: bool = false) -> int:
	if not alive:
		return 0
	hp = max(0, hp - amount)
	_hurt = HURT_TIME
	_ghost_delay = 0.3
	if hp == 0:
		_die()
	return amount


func attack(target, _particles: Array = []) -> void:
	"""Gestiona el timer de ataque. Emite attack_triggered cuando el cooldown llega a 0."""
	if not alive or target == null or not target.alive:
		is_attacking = false
		return
	is_attacking = true
	atk_timer -= get_process_delta_time()
	# Anticipación ligada al cooldown: no cambia el ritmo de ataque
	if atk_timer <= windup_time:
		_windup = clampf(1.0 - atk_timer / windup_time, 0.0, 1.0)
		if style == "cast" and not _cast_launched and fx:
			_cast_launched = true
			fx.orb(cast_origin(), target.position + Vector2(2, -13), accent_color, maxf(0.06, atk_timer))
			Sfx.play(&"wraith_orb")
	if atk_timer <= 0.0:
		_strike = 1.0
		_windup = 0.0
		_cast_launched = false
		emit_signal("attack_triggered")
		atk_timer = 1.0 / aps


func pulse(target, _particles: Array = []) -> void:
	if not alive or target == null or not target.alive:
		return
	pulse_timer -= get_process_delta_time()
	if pulse_timer <= 0.0:
		pulse_timer += PULSE_INTERVAL
		var target_pos: Vector2 = target.body_center() if target.has_method("body_center") else target.position
		var dealt = target.take_damage(int(INT * 3), true)
		emit_signal("pulse_hit", int(dealt) if dealt != null else int(INT * 3), target_pos)


func prepare_for_combat() -> void:
	atk_timer = 1.0 / aps
	pulse_timer = PULSE_INTERVAL
	is_attacking = false


## Punto (en coordenadas del Corridor) donde nace el orbe del espectro.
func cast_origin() -> Vector2:
	return body_center() + Vector2(-half_width * 0.9, -body_height * 0.05)


## Centro de la caja de píxeles del sprite (para chispas y números).
func body_center() -> Vector2:
	return position + Vector2(0, float(_metrics.get("center_y", -body_height * 0.5)))


func generate_drops() -> Array:
	if drop_table == null:
		return []
	_drop_random_materials()
	return drop_table.roll_drops(_rng)


func _drop_random_materials() -> void:
	last_material_drop = {}
	var dm := get_node_or_null("/root/DataManager")
	if not dm or not dm.has_method("get_all_blueprints"):
		return
	var all_materials: Array[StringName] = []
	var all_blueprints: Dictionary = dm.get_all_blueprints()
	for bp_id in all_blueprints:
		var blueprint = all_blueprints[bp_id]
		if blueprint is BlueprintResource and not blueprint.materials.is_empty():
			for mat_id in blueprint.materials.keys():
				if not all_materials.has(mat_id):
					all_materials.append(StringName(mat_id))
	if all_materials.is_empty():
		return
	var random_material: StringName = all_materials[_rng.randi() % all_materials.size()]
	var im := get_node_or_null("/root/InventoryManager")
	if im and im.has_method("add_item"):
		im.add_item(random_material, MATERIAL_DROP_QTY)
		last_material_drop = {"item_id": random_material, "quantity": MATERIAL_DROP_QTY}


func _die() -> void:
	if not alive:
		return
	alive = false
	hp = 0
	is_attacking = false
	_spawn_death_fx()
	var drops := generate_drops()
	death_info = {
		"pos": body_center(), "boss": is_boss, "level": level, "name": display_name,
		"archetype": archetype, "material": last_material_drop.duplicate(),
	}
	emit_signal("died", drops)


func _spawn_death_fx() -> void:
	if fx == null:
		return
	var center := body_center()
	var count := 26 if is_boss else 14
	fx.shatter(center, [body_color, shade_color, accent_color, body_color.lightened(0.3)], count, Vector2(1, 3) * (1.4 if is_boss else 1.0), position.y)
	fx.ring(center, Color(1, 1, 1, 0.9), 2.0, 34.0 if is_boss else 19.0, 0.38, 1.0)
	fx.spark_burst(center, Vector2.UP, accent_color, 14, Vector2(32, 84), PI)
	fx.dust_puff(position, Color(0.8, 0.75, 0.7, 0.6), 8, 1.4)


func _on_intro_landed() -> void:
	if fx == null:
		return
	match style:
		"hop", "slam":
			fx.dust_puff(position, Color(0.75, 0.7, 0.65, 0.55), 7, 1.2 if style == "slam" else 0.8)
		"swing":
			fx.dust_puff(position, Color(0.55, 0.5, 0.45, 0.5), 5, 0.7)


# ─── Dibujo ────────────────────────────────────────────────────────────

func _hp_ratio() -> float:
	return clampf(float(hp) / float(max_hp), 0.0, 1.0) if max_hp > 0 else 0.0


func _ease_out_back(x: float) -> float:
	var c1 := 1.70158
	var c3 := c1 + 1.0
	return 1.0 + c3 * pow(x - 1.0, 3.0) + c1 * pow(x - 1.0, 2.0)


func _update_sprite() -> void:
	if _sprite == null:
		return
	_sprite.visible = _awake and alive
	if not _sprite.visible:
		return
	_sprite.frame = int(_t / IDLE_FRAME_TIME) % _sprite.hframes
	var e := _ease_out_back(_intro)
	var st := pow(_strike, 1.6)
	var w := _windup
	var flash := clampf(_hurt / HURT_TIME, 0.0, 1.0)
	# Desplazamiento en "espacio de cara": x positiva = hacia el héroe
	var off := Vector2.ZERO
	match style:
		"hop":
			off = Vector2(7.0 * st, -7.0 * sin(_strike * PI))
		"swing":
			off = Vector2(-1.2 * w + 4.0 * st, 0.0)
		"dive":
			off = Vector2(-3.2 * w + 9.2 * st, -5.6 * w + 6.0 * st)
		"slam":
			off = Vector2(2.0 * st, -1.6 * w)
		"cast":
			off = Vector2(-1.6 * st, -2.0 * w)
	off.x -= 2.0 * flash
	# Entrada: cae, entra en picado o sube; todos aparecen por disolución
	match style:
		"hop":
			off.y -= 30.0 * (1.0 - e)
		"dive":
			off += Vector2(-16.0, -18.0) * (1.0 - e)
		"cast":
			off.y += 5.0 * (1.0 - e)
	# El enemigo mira a la izquierda: la x de cara se invierte en el mundo
	_sprite.position = _sprite_origin() + Vector2(roundf(-off.x), roundf(off.y))
	var mat := _sprite.material as ShaderMaterial
	mat.set_shader_parameter("flash", flash * 0.85)
	mat.set_shader_parameter("dissolve", 1.0 - clampf(_intro * 2.2, 0.0, 1.0))


## Esquina superior izquierda del fotograma para que los pies apoyen en el origen del nodo.
func _sprite_origin() -> Vector2:
	var fw := float(_metrics.get("frame_w", 32))
	var ground := float(_metrics.get("ground_row", 28))
	return Vector2(-fw * 0.5, -(ground + 1.0))


## Barra relativa al nodo: 1 px por encima de la cabeza, desplazada lejos del héroe (menos el jefe).
func hud_bar_rect() -> Rect2:
	var top := roundf(float(_metrics.get("center_y", -body_height * 0.5)) - body_height * 0.5)
	var boss := archetype == &"boss"
	var w := 40.0 if boss else 22.0
	var shift := 0.0 if boss else 3.0
	return Rect2(roundf(-w * 0.5 + shift), top - 5.0, w, 3.0)


func hud_label() -> String:
	return "%s Nv %d" % [display_name, level]


## El nombre arranca en el borde izquierdo de la barra y crece hacia la derecha, lejos del de Tico.
func hud_label_rect() -> Rect2:
	var bar := hud_bar_rect()
	return Rect2(bar.position.x, bar.position.y - PixelFont.SMALL_SIZE, PixelFont.width(hud_label()), PixelFont.SMALL_SIZE)


func _draw() -> void:
	if not _awake or not alive:
		return
	var a := clampf(_intro * 2.2, 0.0, 1.0)
	var sh := clampf(1.0 - hover / 44.0, 0.45, 1.0)
	PixelHud.draw_shadow(self, Vector2.ZERO, int(roundf(half_width * 2.1 * sh)), a)


func _draw_hud(canvas: CanvasItem) -> void:
	if not _awake or not alive:
		return
	var a := clampf(_intro * 2.2, 0.0, 1.0)
	var boss := archetype == &"boss"
	var bar := hud_bar_rect()
	PixelHud.draw_bar(canvas, bar, _hp_ratio(), _hp_ghost, Color("ff7a2a") if boss else Color("e5433b"), a)
	PixelFont.draw(canvas, hud_label_rect().position, hud_label(), Color("ffd54a") if boss else Color("f1e4cf"), a)
	if _alert > 0.0:
		var bounce := roundf(2.0 * (1.0 - _alert))
		var top := Vector2(bar.get_center().x, bar.position.y - PixelFont.SMALL_SIZE - PixelFont.BIG_SIZE - bounce)
		PixelFont.draw_centered(canvas, top, "!", Color(1, 0.85, 0.2), minf(1.0, _alert * 3.0) * a, true)
```

- [ ] **Step 5: Ejecutar y ver que pasan**

Run: `D:/Software/Godot/godot_ver4.5.exe --headless --path . res://scenes/tests/PixelTests.tscn`
Expected: `0 fallos`. Si falla `test_names_do_not_overlap_in_combat`, la salida dice qué nombre se sale o se pisa: ajustar `hud_bar_rect()` (desplazamiento) en `Enemy.gd`, nunca acortar nombres.

- [ ] **Step 6: Punto de control (sin commit)**

---

### Task 8: Efectos en píxeles con fuentes pixel

**Files:**
- Modify (reescribir): `scripts/gameplay/visual/CombatFX.gd`
- Test: `scripts/tests/PixelTests.gd` (añadir)

**Interfaces:**
- Produces: la misma API salvo `float_text`, que cambia a
  `float_text(pos: Vector2, text: String, color: Color, big: bool = false, duration: float = 1.1, rise: float = 14.0, delay: float = 0.0)`.
  Valores por defecto en píxeles del arte: `spark_burst(..., speed := Vector2(36, 84))`, `shatter(..., size := Vector2(1, 3), floor_y := PixelView.FLOOR_Y)`, `ring(..., r0 := 2.0, r1 := 12.0, duration := 0.3, width := 1.0)`, `slash(..., thickness := 3.0)`, `star(..., size := 8.0)`, `beam(..., height := 92.0, width := 14.0)`. Las partículas de texto guardan `big: bool` en lugar de `size`/`font`.
- Consumers que cambian en la tarea 9: las 3 llamadas a `float_text` (2 en `Corridor.gd`, 1 en `CombatController.gd`).

- [ ] **Step 1: Escribir las pruebas que fallan**

Añadir a `scripts/tests/PixelTests.gd`:

```gdscript
# ─── Tarea 8: efectos ──────────────────────────────────────────────────

func _new_fx() -> Node2D:
	var fx := Node2D.new()
	fx.set_script(load("res://scripts/gameplay/visual/CombatFX.gd"))
	add_child(fx)
	return fx


func test_fx_texts_use_pixel_fonts() -> void:
	var fx := _new_fx()
	fx.damage_number(Vector2(100, 40), 12, &"normal")
	fx.damage_number(Vector2(100, 40), 30, &"crit")
	fx.float_text(Vector2(100, 30), "¡Jefe derrotado!", Color.GOLD, true)
	var texts: Array = fx._parts.filter(func(p): return p.kind == fx.Kind.TEXT)
	check(texts.size() == 3, "tres textos en cola (%d)" % texts.size())
	check(not texts[0].big and texts[1].big and texts[2].big, "el crítico y el cartel usan la fuente grande")
	check(texts[1].text == "30!", "el crítico lleva exclamación")
	check(absf(texts[0].vel.y) < 25.0, "velocidades en píxeles del arte (%s)" % texts[0].vel)
	fx.queue_free()


func test_fx_shatter_bounces_on_pixel_floor() -> void:
	var fx := _new_fx()
	fx.shatter(Vector2(100, 60), [Color.RED], 4)
	check(fx._parts.size() == 4, "cuatro fragmentos")
	check(fx._parts[0].floor == PixelView.FLOOR_Y - 1.0, "rebotan en el suelo de la franja (%s)" % fx._parts[0].floor)
	fx.queue_free()
```

- [ ] **Step 2: Ejecutar y ver que fallan**

Run: `D:/Software/Godot/godot_ver4.5.exe --headless --path . res://scenes/tests/PixelTests.tscn`
Expected: `FALLO test_fx_texts_use_pixel_fonts` (no existe la clave `big`) y `FALLO test_fx_shatter_bounces_on_pixel_floor` (el suelo es 398).

- [ ] **Step 3: Reescribir `CombatFX.gd`**

Sustituir todo `scripts/gameplay/visual/CombatFX.gd` por:

```gdscript
extends Node2D

## Capa de efectos del corredor, en espacio de mundo (se mueve con la cámara del viewport del héroe).
## Unidades: píxeles del arte (la franja mide 216x96). Un único nodo dibuja todas las partículas en un
## _draw() → barato en móvil. Los halos aditivos los dibuja un hijo con material ADD que lee la misma lista.
## Textos con las fuentes pixel (PixelFont). Provisional hasta la fase 5 del spec de pixel art, que
## sustituye estos dibujos por sprites manteniendo la API.

const SK := preload("res://scripts/gameplay/visual/ShapeKit.gd")
const MAX_PARTS := 360
const ICON_SIZE := 10.0

enum Kind { SPARK, SHARD, DOT, RING, SLASH, TEXT, STAR, BEAM, ORB, ICON, WAVE }

var _parts: Array = []
var _glow: Node2D
var _num_side := 1.0


class GlowDrawer extends Node2D:
	var fx: Node2D

	func _draw() -> void:
		if fx == null:
			return
		var tex: Texture2D = SK.glow_texture()
		for p in fx._parts:
			var g: float = p.get("glow", 0.0)
			if g <= 0.0 or p.get("delay", 0.0) > 0.0:
				continue
			var life_t: float = clampf(p.t / p.life, 0.0, 1.0)
			var a: float = (1.0 - life_t) * g
			var r: float = p.get("glow_r", 5.0)
			var c: Color = p.color
			draw_texture_rect(tex, Rect2(p.pos - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(c.r, c.g, c.b, a))


func _ready() -> void:
	_glow = GlowDrawer.new()
	_glow.fx = self
	_glow.material = SK.additive_material()
	add_child(_glow)


func _process(delta: float) -> void:
	if _parts.is_empty():
		return
	for i in range(_parts.size() - 1, -1, -1):
		var p: Dictionary = _parts[i]
		# Retardo opcional (para escalonar textos y botín en las celebraciones)
		if p.get("delay", 0.0) > 0.0:
			p.delay -= delta
			continue
		p.t += delta
		if p.t >= p.life:
			_parts.remove_at(i)
			continue
		var grav: float = p.get("grav", 0.0)
		var drag: float = p.get("drag", 0.0)
		var vel: Vector2 = p.get("vel", Vector2.ZERO)
		vel.y += grav * delta
		if drag > 0.0:
			vel *= maxf(0.0, 1.0 - drag * delta)
		p.vel = vel
		p.pos += vel * delta
		if p.has("rot_vel"):
			p.rot += p.rot_vel * delta
		match p.kind:
			Kind.SHARD, Kind.ICON:
				# Rebote simple contra el suelo
				if p.pos.y > p.get("floor", 99999.0) and p.vel.y > 0.0:
					p.pos.y = p.floor
					p.vel = Vector2(p.vel.x * 0.5, -p.vel.y * 0.33)
					if p.has("rot_vel"):
						p.rot_vel *= 0.6
			Kind.WAVE:
				var life_w: float = clampf(p.t / p.life, 0.0, 1.0)
				p.pos = (p.from as Vector2).lerp(p.to, life_w)
			Kind.ORB:
				var life_o: float = clampf(p.t / p.life, 0.0, 1.0)
				var op: Vector2 = (p.from as Vector2).lerp(p.to, ease(life_o, 0.6))
				op.y -= sin(life_o * PI) * 5.0
				p.pos = op
	queue_redraw()
	_glow.queue_redraw()


func _add(p: Dictionary) -> void:
	if _parts.size() >= MAX_PARTS:
		_parts.remove_at(0)
	if not p.has("t"):
		p.t = 0.0
	_parts.append(p)
	queue_redraw()


# ─── Emisores ──────────────────────────────────────────────────────────

## Chispas direccionales (impactos).
func spark_burst(pos: Vector2, dir: Vector2, color: Color, count: int = 10, speed: Vector2 = Vector2(36, 84), spread: float = 0.9) -> void:
	var base_a := dir.angle() if dir != Vector2.ZERO else -PI * 0.5
	for i in count:
		var a := base_a + randf_range(-spread, spread)
		var sp := randf_range(speed.x, speed.y)
		_add({
			"kind": Kind.SPARK, "pos": pos, "vel": Vector2(cos(a), sin(a)) * sp,
			"life": randf_range(0.18, 0.34), "color": color, "grav": 104.0, "drag": 3.0,
			"len": randf_range(2.0, 4.5), "width": 1.0, "glow": 0.6, "glow_r": 3.0,
		})


## Fragmentos poligonales (muertes). La fase 3 los cambia por trozos del propio sprite.
func shatter(pos: Vector2, colors: Array, count: int = 10, size: Vector2 = Vector2(1, 3), floor_y: float = PixelView.FLOOR_Y, up_bias: float = 1.0) -> void:
	for i in count:
		var a := randf_range(-PI * 0.95, -PI * 0.05)
		var sp := randf_range(32.0, 84.0) * up_bias
		_add({
			"kind": Kind.SHARD, "pos": pos + Vector2(randf_range(-4, 4), randf_range(-6, 4)),
			"vel": Vector2(cos(a) * sp * 0.8, sin(a) * sp), "life": randf_range(0.7, 1.1),
			"color": colors[i % colors.size()], "grav": 180.0, "drag": 0.6,
			"size": randf_range(size.x, size.y), "rot": randf() * TAU, "rot_vel": randf_range(-12.0, 12.0),
			"floor": floor_y - 1.0, "shape": randi() % 3,
		})


## Anillo que se expande.
func ring(pos: Vector2, color: Color, r0: float = 2.0, r1: float = 12.0, duration: float = 0.3, width: float = 1.0) -> void:
	_add({"kind": Kind.RING, "pos": pos, "life": duration, "color": color, "r0": r0, "r1": r1, "width": width, "glow": 0.35, "glow_r": r1})


## Onda de pulso mágico que viaja de un punto a otro.
func pulse_wave(from: Vector2, to: Vector2, color: Color, duration: float = 0.28) -> void:
	_add({"kind": Kind.WAVE, "pos": from, "from": from, "to": to, "life": duration, "color": color, "glow": 0.5, "glow_r": 5.0})


## Arco de corte (media luna) delante del atacante.
func slash(center: Vector2, radius: float, a0: float, a1: float, color: Color, duration: float = 0.16, thickness: float = 3.0) -> void:
	_add({"kind": Kind.SLASH, "pos": center, "life": duration, "color": color, "r": radius, "a0": a0, "a1": a1, "thick": thickness})


## Destello en estrella (críticos, recoger botín).
func star(pos: Vector2, color: Color, size: float = 8.0, duration: float = 0.22) -> void:
	_add({"kind": Kind.STAR, "pos": pos, "life": duration, "color": color, "size": size, "rot": randf() * TAU, "glow": 0.7, "glow_r": size * 1.2})


## Columna de luz (reaparición del héroe).
func beam(pos: Vector2, color: Color, height: float = 92.0, duration: float = 0.7, width: float = 14.0) -> void:
	_add({"kind": Kind.BEAM, "pos": pos, "life": duration, "color": color, "height": height, "width": width, "glow": 0.5, "glow_r": width * 1.4})


## Orbe (proyectil del espectro) que viaja en la duración dada.
func orb(from: Vector2, to: Vector2, color: Color, duration: float) -> void:
	_add({"kind": Kind.ORB, "pos": from, "from": from, "to": to, "life": maxf(0.05, duration), "color": color, "glow": 0.9, "glow_r": 6.0})


## Polvo al pisar / aterrizar.
func dust_puff(pos: Vector2, color: Color, count: int = 5, strength: float = 1.0) -> void:
	for i in count:
		var dir := -1.0 if i % 2 == 0 else 1.0
		_add({
			"kind": Kind.DOT, "pos": pos + Vector2(randf_range(-2, 2), -1),
			"vel": Vector2(dir * randf_range(6.0, 18.0) * strength, randf_range(-10.0, -3.0) * strength),
			"life": randf_range(0.35, 0.6), "color": color, "grav": -2.0, "drag": 3.5,
			"size": randf_range(1.0, 2.0) * strength, "grow": 1.8,
		})


## Número de daño. style: "normal", "crit", "hero", "pulse", "enemy_pulse", "block"
func damage_number(pos: Vector2, amount: int, style: StringName = &"normal") -> void:
	var color := Color(1, 1, 1)
	var big := false
	var text := str(amount)
	match style:
		&"crit":
			color = Color("ffd23f")
			big = true
			text = "%d!" % amount
		&"hero":
			color = Color("ff5a4f")
		&"pulse":
			color = Color("6fe3ff")
		&"enemy_pulse":
			color = Color("c77dff")
		&"block":
			color = Color("b8c4d6")
	_num_side = -_num_side
	var start := pos + Vector2(_num_side * randf_range(1.0, 4.0), randf_range(-1.0, 1.0))
	_add({
		"kind": Kind.TEXT, "pos": start, "vel": Vector2(_num_side * randf_range(3.0, 7.0), -19.0),
		"life": 1.15 if big else 0.9, "color": color, "text": text, "big": big,
		"drag": 2.2, "grav": 8.0,
	})
	if style == &"crit":
		star(pos, Color("ffe08a"), 9.0, 0.2)


## Texto flotante genérico (botín, avisos, "Bloqueo"). big usa la fuente grande.
func float_text(pos: Vector2, text: String, color: Color, big: bool = false, duration: float = 1.1, rise: float = 14.0, delay: float = 0.0) -> void:
	_add({
		"kind": Kind.TEXT, "pos": pos, "vel": Vector2(0, -rise * 1.6), "life": duration,
		"color": color, "text": text, "big": big, "drag": 2.4, "grav": 0.0, "delay": delay,
	})


## Icono + texto que sube (botín de materiales).
func loot_pop(pos: Vector2, icon: Texture2D, text: String, color: Color = Color(1, 0.93, 0.7), delay: float = 0.0, floor_y: float = NAN) -> void:
	var vx := randf_range(8.0, 18.0)  # hacia delante: se aleja del héroe y de su barra de vida
	# El icono se dibuja centrado: su "suelo" queda medio icono por encima de la línea del suelo
	var ground := (floor_y - ICON_SIZE * 0.5) if not is_nan(floor_y) else pos.y + 8.0
	_add({
		"kind": Kind.ICON, "pos": pos, "vel": Vector2(vx, -52.0), "life": 1.5, "color": color,
		"icon": icon, "text": text, "grav": 104.0, "drag": 0.5, "floor": ground,
		"glow": 0.5, "glow_r": 7.0, "delay": delay,
	})


func clear() -> void:
	_parts.clear()
	queue_redraw()
	_glow.queue_redraw()


# ─── Dibujo ────────────────────────────────────────────────────────────

func _draw() -> void:
	for p in _parts:
		if p.get("delay", 0.0) > 0.0:
			continue
		var life_t: float = clampf(p.t / p.life, 0.0, 1.0)
		match p.kind:
			Kind.SPARK:
				var c: Color = p.color
				c.a = 1.0 - life_t
				var v: Vector2 = p.vel
				var tail: Vector2 = v.normalized() * p.len * (1.0 - life_t * 0.5)
				draw_line(p.pos - tail, p.pos, c, p.width, false)
			Kind.SHARD:
				_draw_shard(p, life_t)
			Kind.DOT:
				var c2: Color = p.color
				c2.a *= (1.0 - life_t) * 0.8
				var r: float = p.size * (1.0 + life_t * p.get("grow", 0.0))
				draw_circle(p.pos, r, c2)
			Kind.RING:
				var e := 1.0 - pow(1.0 - life_t, 3.0)
				var rr: float = lerpf(p.r0, p.r1, e)
				var c3: Color = p.color
				c3.a *= 1.0 - life_t
				draw_arc(p.pos, rr, 0.0, TAU, 24, c3, maxf(1.0, p.width * (1.0 - life_t * 0.6)), false)
			Kind.WAVE:
				var head: Vector2 = p.pos
				var dir_x := signf((p.to as Vector2).x - (p.from as Vector2).x)
				var a_start := -PI * 0.5 if dir_x >= 0.0 else PI * 0.5
				var c4: Color = p.color
				c4.a = 1.0 - life_t * 0.5
				draw_arc(head, 3.0 + 2.0 * life_t, a_start, a_start + PI, 12, c4, 1.0, false)
				draw_arc(head - Vector2(2.0 * dir_x, 0), 2.4 + 1.6 * life_t, a_start, a_start + PI, 10, SK.fade(c4, 0.5), 1.0, false)
			Kind.SLASH:
				_draw_slash(p, life_t)
			Kind.TEXT:
				_draw_text(p, life_t)
			Kind.STAR:
				var s: float = p.size * (0.6 + 0.8 * life_t)
				var c5: Color = p.color
				c5.a = 1.0 - life_t
				draw_colored_polygon(SK.star_pts(p.pos, s, s * 0.18, 4, p.rot), c5)
			Kind.BEAM:
				var a := sin(life_t * PI)
				var w: float = p.width * (1.0 - life_t * 0.6)
				var top: Vector2 = p.pos - Vector2(0, p.height)
				var cb: Color = p.color
				SK.v_gradient(self, Rect2(top.x - w * 0.5, top.y, w, p.height), Color(cb.r, cb.g, cb.b, 0.0), Color(cb.r, cb.g, cb.b, 0.75 * a))
				SK.v_gradient(self, Rect2(top.x - w * 0.18, top.y, w * 0.36, p.height), Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.8 * a))
			Kind.ORB:
				draw_circle(p.pos, 2.0, p.color)
				draw_circle(p.pos, 1.0, Color(1, 1, 1, 0.9))
			Kind.ICON:
				_draw_icon(p, life_t)


func _draw_shard(p: Dictionary, life_t: float) -> void:
	var c: Color = p.color
	c.a = 1.0 - maxf(0.0, (life_t - 0.6) / 0.4)
	var s: float = p.size
	var xf := Transform2D(p.rot, p.pos)
	var pts: PackedVector2Array
	match int(p.shape):
		0:
			pts = PackedVector2Array([Vector2(-s, -s * 0.6), Vector2(s, 0), Vector2(-s * 0.4, s * 0.8)])
		1:
			pts = PackedVector2Array([Vector2(-s * 0.7, -s * 0.5), Vector2(s * 0.6, -s * 0.7), Vector2(s * 0.7, s * 0.5), Vector2(-s * 0.5, s * 0.6)])
		_:
			pts = PackedVector2Array([Vector2(0, -s), Vector2(s * 0.5, 0), Vector2(0, s), Vector2(-s * 0.5, 0)])
	draw_colored_polygon(SK.xform_pts(pts, xf), c)


func _draw_slash(p: Dictionary, life_t: float) -> void:
	var grow := 1.0 - pow(1.0 - minf(1.0, life_t * 1.6), 2.0)
	var a0: float = p.a0
	var a1: float = lerpf(p.a0, p.a1, grow)
	if absf(a1 - a0) < 0.12:
		return  # Arco aún sin abrir: el polígono sería degenerado
	var r: float = p.r
	var c: Color = p.color
	c.a = 1.0 - life_t
	var pts := SK.crescent_pts(p.pos, r, r - p.thick, a0, a1, 16)
	if pts.size() >= 3:
		draw_colored_polygon(pts, c)
		var core := SK.crescent_pts(p.pos, r - 1.0, r - p.thick * 0.45, a0, a1, 16)
		if core.size() >= 3:
			draw_colored_polygon(core, Color(1, 1, 1, c.a * 0.9))


func _draw_text(p: Dictionary, life_t: float) -> void:
	var alpha := 1.0 - maxf(0.0, (life_t - 0.65) / 0.35)
	var big: bool = p.get("big", false)
	var lift := 1.0 if p.t < 0.1 else 0.0  # rebote de 1 px al aparecer (sin escalar)
	var top: Vector2 = p.pos - Vector2(0, PixelFont.line_size(big) * 0.5 + lift)
	PixelFont.draw_centered(self, top, p.text, p.color, alpha, big)


func _draw_icon(p: Dictionary, life_t: float) -> void:
	var alpha := 1.0 - maxf(0.0, (life_t - 0.7) / 0.3)
	var icon: Texture2D = p.icon
	if icon:
		var rect := Rect2((p.pos - Vector2(ICON_SIZE, ICON_SIZE) * 0.5).round(), Vector2(ICON_SIZE, ICON_SIZE))
		draw_texture_rect(icon, rect, false, Color(1, 1, 1, alpha))
	var text: String = p.text
	if text != "":
		PixelFont.draw_centered(self, p.pos + Vector2(0, -ICON_SIZE * 0.5 - PixelFont.SMALL_SIZE), text, p.color, alpha)
```

- [ ] **Step 4: Ejecutar y ver que pasan**

Run: `D:/Software/Godot/godot_ver4.5.exe --headless --path . res://scenes/tests/PixelTests.tscn`
Expected: `0 fallos`. (Aún aparecerán errores de argumentos en `Corridor.gd`/`CombatController.gd` si se ejecuta el juego: los arregla la tarea 9.)

- [ ] **Step 5: Punto de control (sin commit)**

---

### Task 9: Pasillo en píxeles: Corridor, CombatController, fondo liso y puertas

**Files:**
- Modify: `scripts/gameplay/Corridor.gd` (constantes 24-33, mirada 110-113, respawn 336-337, celebración 370 y 375, plano 382-393)
- Modify: `scripts/gameplay/CombatController.gd` (funciones `_execute_hero_attack`, `_execute_enemy_attack`, `_on_hero_pulse`, `_on_enemy_pulse`)
- Modify: `scripts/gameplay/visual/DungeonBackdrop.gd` (constantes 13-25, polvo 140-141 y 210-231)
- Modify: `scripts/gameplay/visual/BackdropLayer.gd` (`_draw()` y nueva `_draw_plain()`)
- Modify (reescribir): `scripts/gameplay/visual/RoomGate.gd`
- Test: `scripts/tests/PixelTests.gd` (añadir)

**Interfaces:**
- Consumes: `CombatFX.float_text(pos, text, color, big, duration, rise, delay)` (tarea 8), `Hero.reach`, `Enemy.half_width`, `PixelView`.
- Produces: `RoomGate.plate_rect() -> Rect2` (placa relativa al nodo); `DungeonBackdrop` con una sola capa `"plain"` hasta la fase 4 y la misma API (`set_room`, `set_biome`, `follow_camera`, `reset_dust`, `set_foreground_dim`, `flash`, `pulse_tint`, `get_palette`, señal `biome_changed`).

- [ ] **Step 1: Escribir las pruebas que fallan**

Añadir a `scripts/tests/PixelTests.gd`:

```gdscript
# ─── Tarea 9: pasillo ──────────────────────────────────────────────────

func test_backdrop_is_plain_and_pixel_sized() -> void:
	var bd := Node2D.new()
	bd.set_script(load("res://scripts/gameplay/visual/DungeonBackdrop.gd"))
	add_child(bd)
	check(bd._layers.size() == 1 and bd._layers[0].kind == "plain", "fase 1: una sola capa lisa")
	check(bd._flash_rect.size == PixelView.VIEW_SIZE, "el destello cubre la franja de 216x96")
	check(bd._torches.is_empty(), "sin antorchas vectoriales")
	bd.queue_free()


func test_gate_plate_fits_the_room_number() -> void:
	var gate := Node2D.new()
	gate.set_script(load("res://scripts/gameplay/visual/RoomGate.gd"))
	add_child(gate)
	gate.setup(7, 100.0, Biomes.get_biome(0))
	var w1: float = gate.plate_rect().size.x
	gate.setup(120, 100.0, Biomes.get_biome(0))
	check(gate.plate_rect().size.x > w1, "la placa crece con las cifras")
	check(gate.plate_rect().size.x >= PixelFont.width("120") + 2, "el número cabe en la placa")
	gate.queue_free()


func test_corridor_engages_at_pixel_distance() -> void:
	var corridor: Node2D = load("res://scenes/Corridor.tscn").instantiate()
	add_child(corridor)
	var hero: Node2D = corridor.get_node("Hero")
	var enemy: Node2D = corridor.get_node("Enemy")
	check(hero.position == PixelView.HERO_START, "el héroe arranca en HERO_START (%s)" % hero.position)
	check(enemy.position.y == PixelView.FLOOR_Y, "el enemigo pisa el suelo")
	var gap: float = enemy.position.x - hero.position.x
	check(gap >= 150.0, "el enemigo aparece fuera de pantalla por la derecha (a %d px)" % int(gap))
	var t := 0.0
	while t < 8.0 and corridor.state != corridor.State.FIGHT:
		await get_tree().process_frame
		t += get_process_delta_time()
	check(corridor.state == corridor.State.FIGHT, "el héroe llega al enemigo y empieza el combate")
	var dist: float = enemy.position.x - hero.position.x
	check(dist <= hero.reach + enemy.half_width + corridor.ENGAGE_GAP + 1.0, "se engancha a distancia de píxeles (%.1f)" % dist)
	check(dist >= 8.0, "no se solapan (%.1f)" % dist)
	corridor.queue_free()
	await get_tree().process_frame
```

- [ ] **Step 2: Ejecutar y ver que fallan**

Run: `D:/Software/Godot/godot_ver4.5.exe --headless --path . res://scenes/tests/PixelTests.tscn`
Expected: `FALLO` en las tres (5 capas vectoriales, no existe `plate_rect`, el héroe arranca en (260, 400)).

- [ ] **Step 3: Pasar `Corridor.gd` a píxeles del arte**

Sustituir el bloque de constantes (líneas 24-33, de `const HERO_SPEED` a `const HERO_START`) por:

```gdscript
# Medidas en píxeles del arte (216x96): las de 1080x480 divididas entre 5
const HERO_SPEED := 38.0
const FLOOR_Y := PixelView.FLOOR_Y
const VIEW_W := PixelView.VIEW_W
const VIEW_H := PixelView.VIEW_H
const HERO_SCREEN_X := PixelView.HERO_SCREEN_X  # posición del héroe en pantalla (fracción del ancho)
const SPAWN_AHEAD := 160.0  # el enemigo aparece justo fuera de pantalla por la derecha
const BOSS_EXTRA_DISTANCE := 52.0  # el jefe entra en pantalla andando, no de golpe
const GATE_BEFORE_ENEMY := 66.0
const ENGAGE_GAP := 3.0
const HERO_START := PixelView.HERO_START
```

En `_process`, sustituir el bloque de `look_target` por:

```gdscript
	if enemy.alive:
		hero.look_target = enemy.position + Vector2(0, -12)
	else:
		hero.look_target = hero.position + Vector2(60, -12)
```

En `_perform_respawn`, sustituir las dos llamadas a `fx` por:

```gdscript
	fx.beam(hero.position, Color(0.65, 0.85, 1.0), 94.0, 0.75, 16.0)
	fx.ring(hero.position + Vector2(0, -1), Color(0.7, 0.9, 1.0, 0.9), 2.0, 18.0, 0.5, 1.0)
```

En `_on_enemy_died_fx`, sustituir la llamada a `fx.float_text` y la de `fx.loot_pop` por:

```gdscript
		fx.float_text(pos + Vector2(0, -30), "¡JEFE DERROTADO!", Color("ffd54a"), true, 1.8, 6.0, 0.25)
```
```gdscript
		fx.loot_pop(pos + Vector2(2, -4), mat.get("icon"), "+%d %s" % [int(md.get("quantity", 0)), mat.get("name", "")], Color(1, 0.93, 0.7), 0.3 if was_boss else 0.12, FLOOR_Y)
```

En `_on_blueprint_unlocked`, sustituir la primera línea y las tres últimas llamadas por:

```gdscript
	var pos: Vector2 = enemy.death_info.get("pos", hero.position + Vector2(24, 0))
```
```gdscript
	fx.star(pos + Vector2(0, -16), Color("ffe08a"), 14.0, 0.4)
	fx.float_text(pos + Vector2(0, -26), "¡Nuevo plano!", Color("ffe08a"), true, 1.6, 8.0)
	Sfx.play(&"blueprint_found", 1.0)
	loot_dropped.emit(&"blueprint", pos + Vector2(0, -16), {"id": bp_id, "name": bp_name, "icon": icon})
```

- [ ] **Step 4: Pasar `CombatController.gd` a píxeles del arte**

Sustituir las cuatro funciones por:

```gdscript
func _execute_hero_attack():
	var damage: float = hero.dmg
	var crit: bool = randf() < hero.crit_p
	if crit:
		damage *= hero.crit_m
	var amount := int(damage)
	# Posiciones ANTES del daño (si muere, el nodo se recoloca en la sala siguiente)
	var center: Vector2 = enemy.body_center()
	var hit_pos := center + Vector2(-enemy.half_width * 0.45, randf_range(-2.0, 2.0))
	var number_pos := center + Vector2(0, -enemy.body_height * 0.45 - 2.0)

	if fx:
		var slash_color: Color = COLOR_CRIT if crit else _weapon_color()
		fx.slash(hero.position + Vector2(6, -13), 13.0 if not crit else 15.0, -1.95, 0.85, slash_color, 0.17, 3.0 if not crit else 4.0)
		fx.spark_burst(hit_pos, Vector2(1, -0.35), Color(1, 0.93, 0.7), 16 if crit else 8, Vector2(36, 92), 0.8)
	enemy.take_damage(amount)
	if fx:
		fx.damage_number(number_pos, amount, &"crit" if crit else &"normal")
	if crit:
		if fx:
			fx.ring(hit_pos, COLOR_CRIT, 2.0, 13.0, 0.24, 1.0)
		if _crit_fx_cd <= 0.0:
			_crit_fx_cd = CRIT_FX_COOLDOWN
			if camera:
				camera.add_trauma(0.3)
			if corridor.has_method("hitstop"):
				corridor.hitstop(0.06)
			_play(CRIT_SFX, -11.0, 1.2, 0.05)
		elif camera:
			camera.add_trauma(0.1)
	elif camera:
		camera.add_trauma(0.07)
	_play_random(HIT_SFX, -12.0 if crit else -14.0, 1.0, 0.1)


func _execute_enemy_attack():
	var damage: float = enemy.dmg
	var crit: bool = randf() < enemy.crit_p
	if crit:
		damage *= enemy.crit_m
	var raw := int(damage)
	var hit_pos: Vector2 = hero.body_center() + Vector2(2, randf_range(-3.0, 2.0))
	var number_pos: Vector2 = hero.body_center() + Vector2(-2, -16)
	var style: String = enemy.style
	var heavy := style == "slam"

	var dealt: int = hero.take_damage(raw)
	if fx:
		fx.damage_number(number_pos, dealt, &"hero")
		if dealt < raw and _block_text_cd <= 0.0 and hero.has_method("armor_mitigation") and hero.armor_mitigation() >= 0.2:
			_block_text_cd = 2.5
			fx.float_text(hit_pos + Vector2(-9, -4), "Bloqueo", Color("b8c4d6"), false, 0.7, 8.0)
		match style:
			"slam":
				fx.dust_puff(hero.position + Vector2(8, 0), Color(0.75, 0.7, 0.62, 0.6), 9, 1.6)
				fx.ring(hero.position + Vector2(4, -1), Color(0.9, 0.85, 0.75, 0.7), 2.0, 18.0, 0.32, 1.0)
				fx.spark_burst(hit_pos, Vector2(-1, -0.4), Color(1, 0.75, 0.5), 10, Vector2(32, 76), 0.9)
			"cast":
				fx.ring(hit_pos, enemy.accent_color, 1.0, 11.0, 0.3, 1.0)
				fx.spark_burst(hit_pos, Vector2(-1, -0.2), enemy.accent_color, 10, Vector2(28, 72), 1.0)
			_:
				fx.spark_burst(hit_pos, Vector2(-1, -0.25), Color(1, 0.55, 0.45), 8, Vector2(30, 76), 0.8)
	if camera:
		camera.add_trauma((0.42 if heavy else 0.14) + (0.2 if crit else 0.0))
	if heavy:
		Sfx.play(&"golem_slam", -1.0, 0.9 if enemy.is_boss else 1.0)
	if crit and _crit_fx_cd <= 0.0 and corridor.has_method("hitstop"):
		_crit_fx_cd = CRIT_FX_COOLDOWN
		corridor.hitstop(0.05)
	_play_random(HURT_SFX, -15.0, 0.8 if heavy else 0.95, 0.08)


func _on_hero_pulse(amount: int, target_pos: Vector2) -> void:
	if fx == null:
		return
	fx.pulse_wave(hero.body_center() + Vector2(6, 0), target_pos, COLOR_PULSE_HERO, 0.22)
	fx.ring(target_pos, COLOR_PULSE_HERO, 2.0, 9.0, 0.3, 1.0)
	fx.damage_number(target_pos + Vector2(0, -12), amount, &"pulse")


func _on_enemy_pulse(amount: int, target_pos: Vector2) -> void:
	if fx == null or enemy == null:
		return
	var from: Vector2 = enemy.death_info.get("pos", enemy.body_center()) if not enemy.alive else enemy.body_center()
	fx.pulse_wave(from + Vector2(-4, 0), target_pos, Color("c77dff"), 0.22)
	fx.ring(target_pos, Color("c77dff"), 2.0, 8.0, 0.3, 1.0)
	fx.damage_number(target_pos + Vector2(4, -12), amount, &"enemy_pulse")
```

- [ ] **Step 5: Fondo liso provisional**

En `scripts/gameplay/visual/DungeonBackdrop.gd`, sustituir las constantes (líneas 13-25) por:

```gdscript
const VIEW_SIZE := PixelView.VIEW_SIZE
const FLOOR_Y := PixelView.FLOOR_Y
const TILE := PixelView.VIEW_W
const TRANSITION_TIME := 1.4

## kind, scroll_scale, z_index, ancho de baldosa, semilla.
## Fase 1 del spec de pixel art: una capa lisa. La fase 4 vuelve a las 5 capas con teselas pixel.
const LAYERS := [
	["plain", 1.0, -60, TILE, 41],
]
```

En `_build_dust()`, sustituir `scale_amount_min`/`scale_amount_max` por:

```gdscript
	_dust.scale_amount_min = 0.008  # 1-2 píxeles del arte
	_dust.scale_amount_max = 0.016
```

En `_configure_dust()`, sustituir el `match decor:` completo por (velocidades ÷5):

```gdscript
	match decor:
		"lava":  # brasas que suben
			_dust.direction = Vector2(0.2, -1)
			_dust.spread = 25.0
			_dust.gravity = Vector2(0, -3.6)
			_dust.initial_velocity_min = 2.4
			_dust.initial_velocity_max = 6.0
			_dust.amount = 48
		"crystals":  # nieve que cae
			_dust.direction = Vector2(-0.3, 1)
			_dust.spread = 20.0
			_dust.gravity = Vector2(0, 2)
			_dust.initial_velocity_min = 2.0
			_dust.initial_velocity_max = 4.8
			_dust.amount = 56
		_:  # polvo/esporas flotando
			_dust.direction = Vector2(0.1, -1)
			_dust.spread = 60.0
			_dust.gravity = Vector2(0, -0.6)
			_dust.initial_velocity_min = 0.6
			_dust.initial_velocity_max = 2.4
			_dust.amount = 36
```

En `scripts/gameplay/visual/BackdropLayer.gd`, añadir el caso al `match kind:` de `_draw()` (después de `"front": _draw_front()`):

```gdscript
		"plain":
			_draw_plain()
```

y la función, justo después de `_draw()`:

```gdscript
## Provisional (fase 1 del spec de pixel art): muro y suelo lisos del color del bioma.
func _draw_plain() -> void:
	draw_rect(Rect2(0, 0, tile_width, floor_y - 2.0), _c("wall"))
	draw_rect(Rect2(0, floor_y - 2.0, tile_width, 1.0), _c("wall_dark"))
	draw_rect(Rect2(0, floor_y - 1.0, tile_width, 1.0), _c("wall_dark").darkened(0.3))
	draw_rect(Rect2(0, floor_y, tile_width, 1.0), _c("floor_hi"))
	draw_rect(Rect2(0, floor_y + 1.0, tile_width, view_height - floor_y - 1.0), _c("floor"))
```

- [ ] **Step 6: Puerta pixel provisional**

Sustituir todo `scripts/gameplay/visual/RoomGate.gd` por:

```gdscript
extends Node2D

## Puerta de sala provisional en pixel (fase 1 del spec de pixel art): marco de piedra y placa numerada.
## Marca la frontera entre salas y se dibuja detrás de los personajes (z_index negativo en la escena).
## La fase 4 la sustituye por el arco dibujado.

var room := 1
var is_boss := false
var palette: Dictionary = {}


func _ready() -> void:
	visible = false


func setup(p_room: int, x: float, p_palette: Dictionary) -> void:
	room = p_room
	is_boss = Biomes.is_boss_room(p_room)
	palette = p_palette
	position = Vector2(roundf(x), 0)
	visible = true
	# Se coloca dentro de la pantalla tras cada victoria: aparece con un fundido, no de golpe
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)
	queue_redraw()


func set_palette(p: Dictionary) -> void:
	palette = p
	queue_redraw()


## Medidas del marco: ancho, alto y grosor de las jambas.
func _frame() -> Vector3:
	return Vector3(34, 46, 4) if is_boss else Vector3(28, 40, 4)


## Placa con el número de sala, relativa al nodo (crece con las cifras).
func plate_rect() -> Rect2:
	var f := _frame()
	var w := float(PixelFont.width(str(room))) + 4.0
	return Rect2(roundf(-w * 0.5), PixelView.FLOOR_Y - f.y - 9.0, w, 8.0)


func _draw() -> void:
	if palette.is_empty():
		return
	var stone: Color = palette.get("pillar", Color(0.3, 0.25, 0.25))
	var dark: Color = palette.get("pillar_dark", stone.darkened(0.4))
	var hi: Color = palette.get("pillar_hi", stone.lightened(0.2))
	var f := _frame()
	var left := roundf(-f.x * 0.5)
	var top := PixelView.FLOOR_Y - f.y
	# Hueco en sombra
	draw_rect(Rect2(left + f.z, top + f.z, f.x - f.z * 2.0, f.y - f.z), Color(0, 0, 0, 0.35))
	# Jambas y dintel con luz arriba-izquierda
	for r in [Rect2(left, top, f.z, f.y), Rect2(left + f.x - f.z, top, f.z, f.y), Rect2(left, top, f.x, f.z)]:
		draw_rect(r, stone)
		draw_rect(Rect2(r.position, Vector2(r.size.x, 1.0)), hi)
		draw_rect(Rect2(r.position, Vector2(1.0, r.size.y)), hi)
		draw_rect(Rect2(r.position.x + r.size.x - 1.0, r.position.y, 1.0, r.size.y), dark)
	# Placa con el número
	var plate := plate_rect()
	draw_rect(plate.grow(1.0), PixelHud.OUTLINE)
	draw_rect(plate, Color("7a2020") if is_boss else Color("3b2a1c"))
	PixelFont.draw_centered(self, Vector2(0, plate.position.y - 2.0), str(room), Color("f3d9a4"))
```

- [ ] **Step 7: Ejecutar y ver que pasan**

Run: `D:/Software/Godot/godot_ver4.5.exe --headless --path . res://scenes/tests/PixelTests.tscn`
Expected: todas las pruebas en `ok`, `0 fallos`, código 0 y ningún `SCRIPT ERROR` en la salida.

- [ ] **Step 8: Punto de control (sin commit)**

Run: `git diff --stat scripts/gameplay`

---

### Task 10: Verificación visual, escalas no enteras y tablero

**Files:**
- Ninguno de código. Capturas en la carpeta temporal de la sesión.
- Modify: `D:/Proyectos/CONTROL/Tableros/Futuro/PetJam.md` (tarjeta nueva en «Completada - Pendiente Revisión»)

**Interfaces:**
- Consumes: todo lo anterior, `scenes/tests/VisualCapture.tscn` (planes `main`, `boss`, `death`, `unlock`, `biome`, `panels`).

- [ ] **Step 1: Todas las pruebas desde cero**

Run:
```bash
python tools/pixel_art/export.py
python -m unittest discover -s tools/pixel_art/tests -v
D:/Software/Godot/godot_ver4.5.exe --headless --path . --import
D:/Software/Godot/godot_ver4.5.exe --headless --path . res://scenes/tests/PixelTests.tscn
```
Expected: Python `OK`; Godot `0 fallos` y código 0.

- [ ] **Step 2: Guardar la partida del usuario**

Run:
```bash
cp "$APPDATA/Godot/app_userdata/PetJam/save.json" "$APPDATA/Godot/app_userdata/PetJam/save.json.fase1.bak" && md5sum "$APPDATA/Godot/app_userdata/PetJam/save.json"
```
Anotar la huella.

- [ ] **Step 3: Capturas de los planes**

Run:
```bash
SCR=C:/Users/drila/AppData/Local/Temp/claude/D--Proyectos-PetJam/8d375348-75f2-43a5-8c32-03a97410a812/scratchpad
for p in main boss death unlock biome panels; do
  mkdir -p "$SCR/cap_$p"
  D:/Software/Godot/godot_ver4.5.exe --path . --write-movie "$SCR/cap_$p/f.png" --fixed-fps 10 --quit-after 300 res://scenes/tests/VisualCapture.tscn -- --plan=$p > "$SCR/cap_$p.log" 2>&1
done
grep -c "SCRIPT ERROR" "$SCR"/cap_*.log
```
Expected: `:0` en los seis registros.

Revisar fotogramas representativos de cada plan (leer los PNG):
- `main`: franja con píxeles gruesos y nítidos, Tico y el enemigo sobre el suelo liso, barras y nombres en fuente pixel, números de daño pixel al golpear, puerta con número.
- `boss`: jefe de 48 px del bioma, nombre dorado sin salirse, "!" al empezar.
- `death`: Tico destella, cae en fragmentos, fundido y reaparición por disolución con el haz.
- `unlock`: "¡NUEVO PLANO!" en fuente grande y el pergamino volando al botón de Planos.
- `biome`: el color del muro y del suelo cambia al entrar en el bioma nuevo.
- `panels`: el Tico del panel de Equipo, pixel y nítido a escala 8.

- [ ] **Step 4: Escalas no enteras**

Run:
```bash
SCR=C:/Users/drila/AppData/Local/Temp/claude/D--Proyectos-PetJam/8d375348-75f2-43a5-8c32-03a97410a812/scratchpad
for r in 720x1280 540x960; do
  mkdir -p "$SCR/cap_$r"
  D:/Software/Godot/godot_ver4.5.exe --path . --resolution $r --write-movie "$SCR/cap_$r/f.png" --fixed-fps 10 --quit-after 120 res://scenes/tests/VisualCapture.tscn -- --plan=main > "$SCR/cap_$r.log" 2>&1
done
```
Expected, ampliando un recorte de la franja: todos los píxeles del arte con el mismo tamaño aparente y bordes limpios, sin columnas más gruesas que otras ni desenfoque general.

- [ ] **Step 5: Restaurar la partida y comprobarla**

Run:
```bash
cp "$APPDATA/Godot/app_userdata/PetJam/save.json.fase1.bak" "$APPDATA/Godot/app_userdata/PetJam/save.json" && md5sum "$APPDATA/Godot/app_userdata/PetJam/save.json"
```
Expected: la misma huella del paso 2.

- [ ] **Step 6: Tarjeta del tablero**

Añadir en `D:/Proyectos/CONTROL/Tableros/Futuro/PetJam.md`, al final de «🔄 Completada - Pendiente Revisión» (antes de `## ✔ Done`), sin ningún `^` en el texto:

```markdown
- [x] **Franja pixel, fase 1: render y medidas** (2026-09-27)
  - Descripción: el pasillo de combate se pinta a 216x96 y se amplía x5 con filtro sharp bilinear. Tico, los 5 enemigos y los 5 jefes son sprites pixel en reposo; barras, nombres, números de daño y carteles en fuente pixel propia; cámara en píxeles enteros; fondo liso y puertas pixel provisionales.
  - Archivos: scripts/gameplay/visual/PixelView.gd, PixelSprites.gd, PixelFont.gd, PixelHud.gd, shaders/pixel_upscale.gdshader, shaders/pixel_sprite.gdshader, scripts/gameplay/Hero.gd, Enemy.gd, Corridor.gd, CombatController.gd, visual/CombatFX.gd, CorridorCamera.gd, DungeonBackdrop.gd, BackdropLayer.gd, RoomGate.gd, EnemyArchetypes.gd, scenes/UI/HUD_Main.tscn, tools/pixel_art/game_assets.py, fonts.py, scenes/tests/PixelTests.tscn
  - Impacto: la franja ya se ve en pixel art; base para las fases 2 a 6 del spec
  - Criterios:
    - [x] Pruebas de Python y de Godot en verde
    - [x] Capturas sin errores de script en los planes main, boss, death, unlock, biome y panels
    - [x] Píxeles regulares a 540 y 720 de ancho
  - Notas: spec en doc/specs/2026-09-27-franja-combate-pixel-art.md y plan en doc/plans/2026-09-27-franja-pixel-fase-1.md. Provisional hasta sus fases: Tico elige tira por la espada (fase 2), enemigos sin fotogramas de ataque (fase 3), fondo liso y puertas simples (fase 4), efectos con primitivas y HUD de alta resolución (fase 5). Cambios sin commit.
```

Run: `cd D:/Proyectos/CONTROL && node scripts/kanban.js lint`
Expected: ningún aviso para PetJam.

---

## Fases siguientes (cada una con su propio plan)

Cada fase se planifica en detalle al terminar la anterior, sobre el código que haya quedado. Todas mantienen las restricciones globales de este documento.

| Fase | Objetivo | Ficheros principales | Hecho cuando |
|---|---|---|---|
| 2. Tico | 13 fotogramas (reposo, andar, carga, golpe, daño, caída), capas de equipo por pieza y nivel (incluidas las avanzadas), `HeroSpriteBuilder` con recoloreado por calidad y material de botas, destello del filo, `play_materialize()` y mini-lienzo en el panel de Equipo | `tools/pixel_art/hero.py`, `scripts/gameplay/visual/HeroSpriteBuilder.gd`, `Hero.gd`, `EquipmentPanel.gd`, `pixel_sprite.gdshader` | las 12 piezas y 5 calidades se distinguen en la franja y en el panel |
| 3. Enemigos y jefes | fotogramas de carga y golpe por estilo, entradas, `shatter_sprite()`, alerta en sprite | `tools/pixel_art/enemies.py`, `bosses.py`, `Enemy.gd`, `CombatFX.gd` | cada estilo se reconoce por su carga y su golpe |
| 4. Escenario | teselas de las 5 capas en tonos de papel, `palette_swap.gdshader`, decoración por bioma, antorchas de 4 fotogramas, arcos de puerta, cielo tramado | `tools/pixel_art/backdrop.py` (nuevo), `DungeonBackdrop.gd`, `BackdropLayer.gd`, `TorchFlame.gd`, `RoomGate.gd`, `shaders/palette_swap.gdshader` | los 5 biomas se reconocen y el fundido de paleta funciona |
| 5. Efectos y HUD | efectos como sprites (corte, orbe, polvo, estrella, haz), iconos de 12×12 para los 9 materiales, HUD de la franja dentro del lienzo 216×96 | `tools/pixel_art/fx.py` (nuevo), `CombatFX.gd`, `HeroViewOverlay.gd`, `HUD_Main.tscn`, `HUDMain.gd` | nada en la franja usa fuente vectorial ni líneas suavizadas |
| 6. Limpieza | `PixelGallery` en lugar de `ShapeGallery`, borrar `CorridorParallax.gd` y `FloatingNumber.gd`, corregir el comentario del plan `boss` de `VisualCapture`, capturas finales | `scenes/tests/PixelGallery.tscn`, `scripts/tests/` | criterios del spec §1 comprobados en capturas |
