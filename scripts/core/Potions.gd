class_name Potions
extends RefCounted

## Pociones de la tienda (spec doc/specs/2026-09-27-inventario-en-rejilla.md, apartado 8): se compran
## para llevarlas en los huecos de consumibles y se beben solas. Vida, cuando Tico (vivo) baja de
## HEAL_BELOW; Velocidad y Suerte, al aparecer un jefe si su efecto no está activo. Las de efecto
## temporal llevan el id del efecto en GameManager ("buff") y su duración. Nombres y descripciones son
## el texto base: se enseñan con tr(). "icon" (opcional) es su dibujo en los huecos del panel de Equipo.

const SLOTS := 2
const MAX_STACK := 5
const HEAL_BELOW := 0.3
const CATALOG := {
	&"potion_heal": {"display_name": "Poción de Vida", "short": "Vida", "price": 100, "icon": "res://art/ui/pocion_vida.png", "description": "Se bebe sola si a Tico le queda menos del 30 % de vida: cura al máximo"},
	&"potion_speed": {"display_name": "Poción de Velocidad", "short": "Velocidad", "price": 150, "description": "Se bebe sola al aparecer un jefe: ataca un 50 % más rápido (30 s)", "buff": &"speed", "duration": 30.0},
	&"potion_luck": {"display_name": "Poción de Suerte", "short": "Suerte", "price": 200, "description": "Se bebe sola al aparecer un jefe: botín doble el 20 % de las veces (60 s)", "buff": &"luck", "duration": 60.0},
}
