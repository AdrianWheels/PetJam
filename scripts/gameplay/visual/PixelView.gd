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
