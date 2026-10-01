# Inventario en rejilla — Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** que el equipo de Tico sea una rejilla como la de Lootbound. Sus rasgos:
- piezas con forma que se giran y se colocan donde quepan, y todo lo que está en la rejilla cuenta;
- aristas según la calidad;
- auras entre vecinas y zonas del cuerpo;
- habilidades de combate en las legendarias;
- botín sin límite y mochila;
- 2 consumibles que se beben solos;
- una rejilla que crece de 4×4 a 6×6 al vencer a los jefes del ciclo I (las 4 recetas únicas del spec llegarán con los rangos).

**Architecture:** las reglas van en clases estáticas o `RefCounted`, sin nodos, en `scripts/core/`:
- `PieceShape`: formas, giros y aristas;
- `GearGrid`: una rejilla (caber, colocar y vecinas);
- `GearAuras`: auras, zonas y tope;
- `LegendaryPowers`: habilidades;
- `GearPacker`: colocación automática, solo para la migración y la simulación;
- `GridExpansions`: recetas de ampliación;
- `Potions`: catálogo de pociones.

`InventoryManager` guarda los tres sitios de las piezas (rejilla de Tico, mochila y botín) y mantiene `calculate_total_stats()`, así que `Hero`, `CombatMath` y `BalanceSim` no cambian de interfaz. El panel de Equipo se rehace a pantalla completa. Cada rejilla es un control que se dibuja a sí mismo (`GearGridView`), el botín es una tira (`LootStripView`), y el panel lleva el dedo en `_input`.

**Tech Stack:** Godot 4.5.1 (GDScript con tabuladores) y suites sin ventana sobre `scripts/tests/TestSuite.gd`.

**Spec:** `doc/specs/2026-09-27-inventario-en-rejilla.md`

## Requisitos previos

- **Orden (decisión del usuario, 2026-10-01):** el sistema de la rejilla se implementa ya, antes que el resto de los rangos. Los rangos siguen parados hasta que Balanza calibre su curva. La base es `franja-pixel-fase-1` en 01ba6f7: tiene `Ranks` (2ad0f45) y el muro (5c05938). La tarea 0 deja la rama encima.
- **Aplazadas:**
  - la tarea 16 (balance), que necesita Balanza;
  - las recetas de ampliación del spec (apartado 7), que necesitan los materiales de bioma y el encargo propio de los rangos. Mientras tanto, la tarea 12 hace crecer la rejilla al vencer por primera vez a esos jefes;
  - las tareas 14 y 15 (arte), que van al final, en su tarjeta.
- **Lo que hay en la base y usa este plan:**
  - de `Ranks`: `gold_mult`, `suffix`, `ROOMS_PER_CYCLE` y `TIERS`;
  - el muro: `GameManager.retry_wall_now()`, que llaman `apply_buff` y `_on_equipment_changed`, con `wall_room` y `room_locked`;
  - los duelos: `Corridor._enter_room` llena la vida, y `CombatController.start_combat()` llama a `hero.prepare_for_combat()`;
  - `GameManager.register_enemy_defeat(level)`, que `CombatController` llama antes de `room_cleared()`;
  - `HeroViewOverlay.show_toast(text, color)`;
  - `Hero.take_damage(amount, is_pulse)`, `Hero.armor_mitigation()` y `CombatMath.armor_mitigation(armor)`, sin la sala del enemigo;
  - `SaveManager.SAVE_VERSION := 1`, y `CraftingManager.enqueue(recipe_id, gold_reward)`.
- **Lo que no hay todavía, y cómo lo suple o lo evita este plan:**
  - `CraftedItem.rank`: la tarea 1 lo añade con valor 1 y con `get_name_with_rank()`, como los define la tarea 5 de los rangos;
  - el guardado: el inventario pasa de la versión 1 a la 2, y los rangos usarán la 3;
  - `BalanceSim` no existe, así que la batería no la incluye.
- **El plan de rangos se adapta después** (decisión del usuario). Sus tareas 5, 6, 8 y 11 tocan los mismos ficheros: piezas, guardado, tienda, forja y panel de Equipo. La tarea 17 lo anota en el tablero.
- **Franja con pegatinas** (rama `franja-pegatinas`): no hace falta, pero si está integrada el plan usa lo suyo:
  - `Hero.read_equipped_gear()`: la única lectura del equipo para el dibujo (tarea 6);
  - el Tico de pegatina, que también es la marioneta del panel (tarea 9).
  La fase 2 del pixel art quedó sin usar: este plan ya no depende de ella.
- **Recursos que no están en git:** `art/assets` es un repositorio aparte. En el worktree es un enlace (junction) a `D:/Proyectos/PetJam/art/assets`; sin él los objetos no cargan y una suite puede guardar la partida vacía. Nunca se añade a un commit.

## Global Constraints

- **Godot:** siempre 4.5.1 (`D:/Software/Godot/godot_ver4.5.exe`), nunca `godot.exe` (4.7), y siempre a través del lanzador `bash D:/Proyectos/PetJam-inventario/.superpowers/sdd/2026-09-27-inventario-en-rejilla/godot-run.sh`.
  - El lanzador añade `--headless --path` al worktree (sin `--headless` con `GODOT_WINDOW=1`, para las capturas) y un `timeout` de 300 s (`GODOT_TIMEOUT` para cambiarlo).
  - Aísla la partida: Godot saca `user://` de `APPDATA`, y el lanzador usa una carpeta propia (`appdata/`, junto a él) con una copia fresca de la partida real. Las pruebas y las capturas ven datos reales, pero nunca escriben el `save.json` del usuario, aunque esté jugando a la vez. También deshace la reescritura de `default_bus_layout.tres`.
  - Donde un paso diga `D:/Software/Godot/godot_ver4.5.exe --headless --path . <argumentos>`, ejecuta `bash D:/Proyectos/PetJam-inventario/.superpowers/sdd/2026-09-27-inventario-en-rejilla/godot-run.sh <argumentos>`.
  - Tras crear scripts con `class_name`, recursos o PNG nuevos: `bash D:/Proyectos/PetJam-inventario/.superpowers/sdd/2026-09-27-inventario-en-rejilla/godot-run.sh --import`.
- **Código:** GDScript con tabuladores y comentarios en español. Sin autoloads nuevos ni plugins.
- **Textos:** todo texto visible nuevo va en español en el código o en los datos, con su fila en `locale/textos.csv`, y con `tr()` en los textos formateados.
  - Columnas `keys,es,en`, sin líneas en blanco.
  - Las filas van sin comillas, salvo las que llevan comas: esas van entre comillas dobles (Ruling R7 del plan de rangos).
  - Antes de añadir una fila, comprueba con `grep -n "^<texto>," locale/textos.csv` que no existe.
  - Tras editar el CSV: `D:/Software/Godot/godot_ver4.5.exe --headless --path . --import`.
  - Los textos de la franja (scripts de `TextTests.STRIP_SCRIPTS`) usan solo caracteres de `PixelFont`: A-Z, ÁÉÍÓÚÜÑ, cifras y ! ¡ ? ¿ . , : ; - + / ( ) % ' · ×.
- **Partida del usuario:** `%APPDATA%/Godot/app_userdata/PetJam/save.json` la comparten todos los worktrees, y el usuario puede estar jugando. Con el lanzador nunca se escribe; no hace falta copiarla ni restaurarla a mano, aunque algún paso del plan lo diga. El 2026-10-01 una batería sin `art/assets` y sin el lanzador la dejó vacía, y se restauró desde la copia.
- **Commits:** sin Co-Authored-By, añadiendo los ficheros por su ruta (nunca `git add -A`). Nunca entran `art/assets` (enlace) ni `default_bus_layout.tres`.
- **Arte:** aplazado al final, por decisión del usuario (2026-10-01): es un prototipo personal y los estilos pueden mezclarse mientras tanto. Las piezas se dibujan con casillas de color (tarea 8) y las tareas 14 y 15 no tienen nada que hacer.
- **Medidas:** casillas de 110 px de pantalla.
  - La rejilla de Tico empieza en 4×4 (ancho × alto) y crece 4×4 → 5×4 → 5×5 → 6×5 → 6×6: columna a la derecha y fila abajo, alternando.
  - La mochila es de 6×4, fija.
- **Aristas por calidad:** Básico 2, Bueno 2, Raro 1, Épico 0 y Legendario 0.
  - Ocupan sitio, pero no dan estadísticas ni emiten o reciben auras, y no cuentan para la vecindad ni para las zonas.
- **Auras** (por `equipment_slot`):
  - `main_hand`: +daño a las armas vecinas;
  - `off_hand`: +armadura a las armaduras vecinas;
  - `head`: +vida a todas las vecinas;
  - `feet`: +velocidad de ataque a las armas vecinas.
  - Fuerza por calidad del emisor: 0 / 5 / 10 / 15 / 20 %.
  - Vecinas: por un lado entre casillas limpias; nunca en diagonal; una vez por vecina.
- **Zonas:** +10 % en todo a la pieza con alguna casilla limpia en su zona. El casco, en la fila de arriba; las botas, en la de abajo; el escudo, en la columna izquierda; la espada, en la derecha.
- **Tope:** +50 % por estadística y pieza, entre zona y auras.
- **Habilidades legendarias:** la tabla del spec, apartado 5. Son multiplicativas, se aplican después de `CombatMath.hero_stats()` y no se repiten; se mantienen los topes de crítico (75 %) y velocidad (0,3-5).
- **Consumibles:** 2 huecos, un tipo por hueco y 5 unidades como máximo.
  - Vida se bebe sola cuando Tico, vivo, baja del 30 %.
  - Velocidad y Suerte se beben solas al aparecer un jefe, si su efecto no está activo.
- **Nada se coloca solo:** lo forjado va siempre al botín. La única excepción es la migración de partidas antiguas.
- **Ampliaciones de la rejilla:** una por jefe de las salas 10, 20, 30 y 40 del ciclo I (`GridExpansions`).
  - Mientras no lleguen las recetas (esperan a los rangos), vencer por primera vez a cada uno de esos jefes amplía la rejilla directamente (tarea 12).
  - Las recetas del spec (apartado 7) sustituirán esto en una tarea posterior.

## Review Focus

- **Llega una pieza nueva de la forja mientras se arrastra otra.** El arrastre sigue, la pieza que se arrastra no se pierde y la nueva aparece en el botín. Prueba: `test_new_loot_while_dragging_is_not_lost` (tarea 9).
- **Golpe doble cuando el primer golpe mata.** El nodo `Enemy` se recoloca en la sala siguiente al morir, así que el segundo golpe no puede llegar al enemigo nuevo. Prueba: `test_double_hit_never_reaches_the_next_enemy` (tarea 11).
- **Quemadura que sigue viva cuando el enemigo muere.** Por el mismo motivo, el enemigo de la sala siguiente no puede empezar quemado. Prueba: `test_burn_does_not_carry_over_to_the_next_enemy` (tarea 11).
- **Las Espinas matan al enemigo durante su propio ataque.** Muere una sola vez, sin botín doble ni errores. Prueba: `test_thorns_kill_counts_once` (tarea 11).
- **Partida con una posición imposible,** por ejemplo tras cambiar una forma en los datos: la pieza pasa al botín y nunca se pierde. Prueba: `test_impossible_saved_position_goes_to_loot` (tarea 7).

---

## Equivalencias tras los rangos

Con el nuevo orden (2026-10-01), el plan ya está escrito sobre la base 01ba6f7: ver "Requisitos previos". La tarea 0 anota aquí lo que encuentre distinto.

## Mapa de ficheros

| Fichero | Acción | Responsabilidad |
|---|---|---|
| `scripts/core/PieceShape.gd` | crear | formas, giros, caja y aristas |
| `scripts/core/GearGrid.gd` | crear | una rejilla: caber, colocar, quitar, vecinas y copia |
| `scripts/core/GearAuras.gd` | crear | auras, zonas, tope y totales de la rejilla de Tico |
| `scripts/core/LegendaryPowers.gd` | crear | tabla de habilidades, activas, multiplicadores y efectos |
| `scripts/core/GearPacker.gd` | crear | colocación automática (migración y BalanceSim) |
| `scripts/core/GridExpansions.gd` | crear | tamaños de la rejilla y jefes que la amplían (las recetas, con los rangos) |
| `scripts/core/Potions.gd` | crear | catálogo de pociones y reglas de los huecos |
| `scripts/data/ItemResource.gd`, `data/items/*.tres` | modificar | forma y sitios de arista; estadísticas por casilla (tarea 16) |
| `scripts/data/CraftedItem.gd` | modificar | sitio, casilla, giro, aristas y precio de venta |
| `scripts/autoload/InventoryManager.gd` | modificar | tres sitios, mover/intercambiar/vender, totales, ampliaciones, consumibles, guardado versión 2 |
| `scripts/autoload/CraftingManager.gd` | modificar | aristas al forjar |
| `scripts/autoload/GameManager.gd` | modificar | ampliación al vencer a los jefes; pociones automáticas |
| `scripts/core/SaveManager.gd` | modificar | versión 2 y récord para la migración |
| `scripts/core/CombatMath.gd` | modificar | `hero_stats_with_powers` |
| `scripts/gameplay/Hero.gd`, `Enemy.gd`, `CombatController.gd`, `Corridor.gd`, `visual/CombatFX.gd` | modificar | mejor pieza por tipo, habilidades en combate, quemadura, jefe → pociones |
| `scripts/ui/GearGridView.gd`, `scripts/ui/LootStripView.gd` | crear | vistas de rejilla y botín |
| `scenes/UI/EquipmentPanel.tscn`, `scripts/ui/EquipmentPanel.gd` | rehacer | panel a pantalla completa y el dedo |
| `scripts/ui/HUDMain.gd`, `ShopPanel.gd`, `CraftResultScreen.gd`, `HeroViewOverlay.gd` | modificar | insignia, venta, pociones, resultado y avisos |
| `scripts/tests/InventoryGridTests.gd`, `scenes/tests/InventoryGridTests.tscn` | crear | pruebas de este plan (la partida de la versión 2 se genera en la propia prueba) |
| `scripts/tests/GameplayTests.gd`, `RankTests.gd`, `TextTests.gd`, `BalanceSim.gd`, `VisualCapture.gd` | modificar | pruebas y capturas afectadas; duelos con rejillas en `BalanceSim` |
| `balance/` y el enlace de PetJam con Balanza | modificar, si los rangos se calibraron con Balanza | calibración con rejillas (tarea 16) |
| `locale/textos.csv` | modificar | filas nuevas |
| `doc/ARCHITECTURE.md`, `doc/ROADMAP.md`, `doc/specs/2026-09-27-inventario-en-rejilla.md` | modificar | documentación y valores calibrados |

Comandos de la batería (todos desde la raíz del worktree, `D:/Proyectos/PetJam-inventario`):

```bash
bash D:/Proyectos/PetJam-inventario/.superpowers/sdd/2026-09-27-inventario-en-rejilla/godot-run.sh res://scenes/tests/InventoryGridTests.tscn
bash D:/Proyectos/PetJam-inventario/.superpowers/sdd/2026-09-27-inventario-en-rejilla/godot-run.sh res://scenes/tests/RankTests.tscn
bash D:/Proyectos/PetJam-inventario/.superpowers/sdd/2026-09-27-inventario-en-rejilla/godot-run.sh res://scenes/tests/GameplayTests.tscn
bash D:/Proyectos/PetJam-inventario/.superpowers/sdd/2026-09-27-inventario-en-rejilla/godot-run.sh res://scenes/tests/PixelTests.tscn
bash D:/Proyectos/PetJam-inventario/.superpowers/sdd/2026-09-27-inventario-en-rejilla/godot-run.sh res://scenes/tests/TextTests.tscn
python -m unittest discover tools/pixel_art/tests
```

- **Salida:** cada escena sale con 0 si todo pasa y con 1 si algo falla, e imprime `[Suite] N comprobaciones, M fallos`.
- **Referencia en la base (2026-10-01):** GameplayTests 119, RankTests 52, PixelTests 150 y TextTests 2423 comprobaciones, todas sin fallos.
- **"Run: la batería"** en una tarea quiere decir las seis líneas.
- **"Run: InventoryGridTests"** quiere decir solo la primera.

---

### Task 0: Montar el worktree sobre la base

**Files:** ninguno. Es el montaje del entorno; si algo no cuadra, se anota en "Equivalencias tras los rangos" en un commit `docs:`.

Hecha por el controlador el 2026-10-01: rama rebasada sobre 01ba6f7, `art/assets` enlazado, lanzador creado y batería de referencia en verde. Si se retoma más tarde y `franja-pixel-fase-1` ha avanzado, se repite:

- [ ] **Step 1: Rebasar**

```bash
git -C D:/Proyectos/PetJam-inventario status --short
git -C D:/Proyectos/PetJam-inventario rebase franja-pixel-fase-1
```

Expected: solo sale ` ? art/assets` antes de rebasar, y el rebase no da conflictos. Si los rangos ya han avanzado, revisa "Requisitos previos" contra la base nueva antes de seguir.

- [ ] **Step 2: `art/assets` enlazado**

```bash
ls D:/Proyectos/PetJam-inventario/art/assets/Imagenes/Items/sword_basic.png
```

Si no está: `New-Item -ItemType Junction -Path D:\Proyectos\PetJam-inventario\art\assets -Target D:\Proyectos\PetJam\art\assets` (PowerShell), con la carpeta vacía borrada antes.

- [ ] **Step 3: Batería de referencia**

Run: `GODOT_TIMEOUT=900 bash D:/Proyectos/PetJam-inventario/.superpowers/sdd/2026-09-27-inventario-en-rejilla/godot-run.sh --import` y después la batería (sin `InventoryGridTests`, que aún no existe).
Expected: los números de referencia, sin fallos.

---

### Task 1: Formas, giros y aristas (`PieceShape`), y la pieza guarda su sitio

**Files:**
- Create: `scripts/core/PieceShape.gd`, `scripts/tests/InventoryGridTests.gd`, `scenes/tests/InventoryGridTests.tscn`
- Modify: `scripts/data/ItemResource.gd`, los 12 `data/items/*.tres`, `scripts/data/CraftedItem.gd`
- Test: `scripts/tests/InventoryGridTests.gd`

**Interfaces:**
- Consumes: `CraftedItem.get_quality_tier()`, `ItemResource`
- Produces:
  - `ItemResource.shape_cells: Array[Vector2i]` y `ItemResource.arista_spots: Array[Vector2i]`;
  - de `PieceShape`:
    - `ARISTAS_BY_TIER` y `aristas_for_tier(tier: String) -> int`;
    - `rotate_raw(cells: Array[Vector2i], rot: int) -> Array[Vector2i]` y `shift(cells: Array[Vector2i], by: Vector2i) -> Array[Vector2i]`;
    - `footprint(clean: Array[Vector2i], aristas: Array[Vector2i], rot: int) -> Dictionary`, con claves `clean`, `aristas` y `size`, relativas a su caja;
    - `of_item(item: CraftedItem, rot: int = -1) -> Dictionary`;
    - `roll_aristas(res: ItemResource, tier: String, rng: RandomNumberGenerator) -> Array[Vector2i]`;
    - `check_resource(res: ItemResource) -> String`;
  - campos de `CraftedItem`: `rank: int` (1 por defecto; los rangos aún no están), `place: StringName` (`&"loot"` por defecto), `cell: Vector2i`, `rot: int` y `aristas: Array[Vector2i]`. `to_dict()` los guarda como `rank`, `place`, `x`, `y`, `rot` y `aristas`, y `from_dict()` los lee. `to_dict()` deja de escribir `equipped`;
  - `CraftedItem.get_name_with_rank() -> String`: el nombre traducido con el numeral del rango ("Espada maestra III"; sin numeral en el rango I).

- [ ] **Step 1: Escena de la suite**

`scenes/tests/InventoryGridTests.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/tests/InventoryGridTests.gd" id="1"]

[node name="InventoryGridTests" type="Node"]
script = ExtResource("1")
```

- [ ] **Step 2: Pruebas que fallan**

`scripts/tests/InventoryGridTests.gd`:

```gdscript
extends "res://scripts/tests/TestSuite.gd"
## 🧪 Pruebas del inventario en rejilla (spec doc/specs/2026-09-27-inventario-en-rejilla.md), solo
## desarrollo, sin ventana:
##   D:/Software/Godot/godot_ver4.5.exe --headless --path . res://scenes/tests/InventoryGridTests.tscn

const ITEM_IDS := [&"sword_basic", &"sword_advanced", &"sword_masterwork", &"shield_basic",
	&"shield_advanced", &"shield_master", &"helmet_basic", &"helmet_advanced", &"helmet_master",
	&"boots_basic", &"boots_advanced", &"boots_master"]

## Casillas limpias de cada pieza (spec, apartado 2.2), sin girar.
const SHAPES := {
	&"sword_basic": [Vector2i(0, 0), Vector2i(0, 1)],
	&"sword_advanced": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2)],
	&"sword_masterwork": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3)],
	&"shield_basic": [Vector2i(0, 0), Vector2i(0, 1)],
	&"shield_advanced": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)],
	&"shield_master": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(0, 2), Vector2i(1, 2)],
	&"helmet_basic": [Vector2i(0, 0)],
	&"helmet_advanced": [Vector2i(0, 0), Vector2i(1, 0)],
	&"helmet_master": [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)],
	&"boots_basic": [Vector2i(0, 0)],
	&"boots_advanced": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1)],
	&"boots_master": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 2)],
}


func _res(id: StringName) -> ItemResource:
	return load("res://data/items/%s.tres" % id)


## Pieza de prueba con calidad y aristas fijas (sin sorteo).
func _piece(id: StringName, quality: float = 0.95, aristas: Array[Vector2i] = []) -> CraftedItem:
	var item := CraftedItem.new(_res(id), quality)
	item.aristas = aristas
	return item


## Casillas ordenadas por fila y columna, para comparar sin depender del orden.
func _sorted(cells: Array) -> Array:
	var out := cells.duplicate()
	out.sort_custom(func(a, b): return a.y < b.y or (a.y == b.y and a.x < b.x))
	return out


# ─── Tarea 1: formas, giros y aristas ──────────────────────────────────

func test_every_piece_has_the_spec_shape() -> void:
	for id in ITEM_IDS:
		var res := _res(id)
		check(_sorted(res.shape_cells) == _sorted(SHAPES[id]), "%s: forma %s" % [id, res.shape_cells])
		check(PieceShape.check_resource(res) == "", "%s: %s" % [id, PieceShape.check_resource(res)])
	var areas := {}
	for id in ITEM_IDS:
		var tier := String(_res(id).rarity)
		areas[tier] = int(areas.get(tier, 0)) + SHAPES[id].size()
	check(areas == {"basic": 6, "advanced": 12, "master": 18}, "un juego completo ocupa 6, 12 y 18 casillas (%s)" % areas)


func test_rotation_is_clockwise_and_normalized() -> void:
	var none: Array[Vector2i] = []
	var sword: Array[Vector2i] = [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2)]
	var fp := PieceShape.footprint(sword, none, 1)
	check(_sorted(fp.clean) == [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)] and fp.size == Vector2i(3, 1), "la espada tumbada ocupa 3×1 (%s)" % [fp.clean])
	var boots: Array[Vector2i] = [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1)]
	var fp2 := PieceShape.footprint(boots, none, 1)
	check(_sorted(fp2.clean) == [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)], "la bota en L gira a la derecha: la puntera pasa a apuntar abajo (%s)" % [fp2.clean])
	check(PieceShape.footprint(boots, none, 4).clean == PieceShape.footprint(boots, none, 0).clean, "4 giros vuelven al principio")


func test_aristas_rotate_with_the_piece() -> void:
	var sword: Array[Vector2i] = [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3)]
	var aristas: Array[Vector2i] = [Vector2i(-1, 2)]
	var fp := PieceShape.footprint(sword, aristas, 0)
	check(fp.size == Vector2i(2, 4) and fp.aristas == [Vector2i(0, 2)] and fp.clean[0] == Vector2i(1, 0), "una arista a la izquierda amplía la caja y desplaza la hoja (%s / %s)" % [fp.clean, fp.aristas])
	var fp1 := PieceShape.footprint(sword, aristas, 1)
	check(fp1.size == Vector2i(4, 2) and fp1.aristas == [Vector2i(1, 0)], "girada, la arista queda encima de la hoja (%s)" % [fp1.aristas])


func test_aristas_count_by_quality() -> void:
	var expected := {0.2: 2, 0.55: 2, 0.8: 1, 0.95: 0, 1.0: 0}
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for q in expected:
		var item := CraftedItem.new(_res(&"sword_masterwork"), q)
		var rolled := PieceShape.roll_aristas(item.item_resource, item.get_quality_tier(), rng)
		check(rolled.size() == expected[q], "calidad %.2f: %d aristas (%d)" % [q, expected[q], rolled.size()])
		var unique := {}
		for a in rolled:
			check(a in item.item_resource.arista_spots, "cada arista sale de un sitio permitido (%s)" % a)
			unique[a] = true
		check(unique.size() == rolled.size(), "sin repetir sitio")


func test_arista_roll_is_repeatable_with_a_seed() -> void:
	var a := RandomNumberGenerator.new()
	var b := RandomNumberGenerator.new()
	a.seed = 12345
	b.seed = 12345
	var res := _res(&"shield_master")
	check(PieceShape.roll_aristas(res, "common", a) == PieceShape.roll_aristas(res, "common", b), "misma semilla, mismas aristas")


func test_crafted_item_saves_its_place() -> void:
	var rough: Array[Vector2i] = [Vector2i(1, 2)]
	var item := _piece(&"helmet_master", 0.6, rough)
	item.place = &"hero"
	item.cell = Vector2i(2, 3)
	item.rot = 3
	item.rank = 2
	var data := item.to_dict()
	var back := CraftedItem.from_dict(data, item.item_resource)
	check(back.place == &"hero" and back.cell == Vector2i(2, 3) and back.rot == 3, "sitio, casilla y giro vuelven igual")
	check(back.aristas == [Vector2i(1, 2)], "las aristas vuelven igual (%s)" % [back.aristas])
	check(back.rank == 2 and back.get_name_with_rank().ends_with(" II"), "el rango vuelve igual y sale en el nombre (%s)" % back.get_name_with_rank())
	check(not data.has("equipped"), "ya no se guarda equipped")
	var old := data.duplicate()
	for k in ["rank", "place", "x", "y", "rot", "aristas"]:
		old.erase(k)
	var before := CraftedItem.from_dict(old, item.item_resource)
	check(before.place == &"loot" and before.aristas.is_empty() and before.rank == 1, "una pieza de una partida anterior empieza en el botín, sin aristas y en el rango I")
	check(not before.get_name_with_rank().ends_with(" I"), "sin numeral en el rango I (%s)" % before.get_name_with_rank())
```

- [ ] **Step 3: Ejecutar y ver que falla**

Run: `timeout 300 D:/Software/Godot/godot_ver4.5.exe --headless --path . res://scenes/tests/InventoryGridTests.tscn`
Expected: error de análisis (`PieceShape` no existe) y salida por el `timeout`.

- [ ] **Step 4: Forma en `ItemResource.gd`**

Al final de las variables exportadas, después del grupo `Base Stats`:

```gdscript
# Forma en la rejilla de equipo (spec doc/specs/2026-09-27-inventario-en-rejilla.md, apartado 2)
@export_group("Rejilla")
## Casillas de la pieza bien hecha, sin girar: (columna, fila), con la fila hacia abajo.
@export var shape_cells: Array[Vector2i] = [Vector2i(0, 0)]
## 3 casillas pegadas por un lado a la forma, donde puede salir una arista al forjarla peor.
@export var arista_spots: Array[Vector2i] = []
```

- [ ] **Step 5: Formas y sitios de arista en los 12 `.tres`**

Añade las dos líneas al final del bloque `[resource]` de cada fichero de `data/items/`. Los sitios están elegidos para que se vean creíbles: rebaba en el filo o en el pomo, bulto en el borde del escudo, correa en la bota, y en el casco en L el hueco de la L.

| Fichero | `shape_cells` | `arista_spots` |
|---|---|---|
| `sword_basic.tres` | (0,0) (0,1) | (1,0) (-1,1) (0,2) |
| `sword_advanced.tres` | (0,0) (0,1) (0,2) | (1,1) (-1,0) (0,3) |
| `sword_masterwork.tres` | (0,0) (0,1) (0,2) (0,3) | (1,1) (-1,2) (0,4) |
| `shield_basic.tres` | (0,0) (0,1) | (1,0) (-1,1) (0,2) |
| `shield_advanced.tres` | (0,0) (1,0) (0,1) (1,1) | (2,0) (-1,1) (1,2) |
| `shield_master.tres` | (0,0) (1,0) (0,1) (1,1) (0,2) (1,2) | (2,1) (-1,0) (0,3) |
| `helmet_basic.tres` | (0,0) | (1,0) (0,1) (-1,0) |
| `helmet_advanced.tres` | (0,0) (1,0) | (0,-1) (2,0) (1,1) |
| `helmet_master.tres` | (1,0) (0,1) (1,1) (2,1) | (0,0) (2,0) (1,2) |
| `boots_basic.tres` | (0,0) | (0,-1) (1,0) (-1,0) |
| `boots_advanced.tres` | (0,0) (0,1) (1,1) | (1,0) (0,-1) (2,1) |
| `boots_master.tres` | (0,0) (0,1) (0,2) (1,2) | (1,1) (-1,0) (2,2) |

Formato (ejemplo de `sword_basic.tres`):

```
shape_cells = Array[Vector2i]([Vector2i(0, 0), Vector2i(0, 1)])
arista_spots = Array[Vector2i]([Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 2)])
```

- [ ] **Step 6: `scripts/core/PieceShape.gd`**

```gdscript
class_name PieceShape
extends RefCounted

## Formas de las piezas en la rejilla de equipo (spec doc/specs/2026-09-27-inventario-en-rejilla.md,
## apartado 2). Casillas en (columna, fila), con la fila hacia abajo. Sin nodos: lo usan GearGrid,
## InventoryManager, las vistas y BalanceSim.

## Aristas que trae una pieza según su calidad (CraftedItem.get_quality_tier()).
const ARISTAS_BY_TIER := {"common": 2, "uncommon": 2, "rare": 1, "epic": 0, "legendary": 0}
const SIDES: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]


static func aristas_for_tier(tier: String) -> int:
	return int(ARISTAS_BY_TIER.get(tier, 2))


## Gira unas casillas `rot` cuartos de vuelta en el sentido de las agujas del reloj: (x, y) → (−y, x).
## No las normaliza.
static func rotate_raw(cells: Array[Vector2i], rot: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c in cells:
		var p := c
		for i in posmod(rot, 4):
			p = Vector2i(-p.y, p.x)
		out.append(p)
	return out


static func shift(cells: Array[Vector2i], by: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c in cells:
		out.append(c + by)
	return out


## Casillas de la pieza girada, limpias y aristas por separado, relativas a su caja (esquina en 0,0):
## {"clean": Array[Vector2i], "aristas": Array[Vector2i], "size": Vector2i}.
static func footprint(clean: Array[Vector2i], aristas: Array[Vector2i], rot: int) -> Dictionary:
	var rc := rotate_raw(clean, rot)
	var ra := rotate_raw(aristas, rot)
	var all: Array[Vector2i] = []
	all.append_array(rc)
	all.append_array(ra)
	var lo := Vector2i(all[0].x, all[0].y)
	var hi := lo
	for c in all:
		lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
		hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
	return {"clean": shift(rc, -lo), "aristas": shift(ra, -lo), "size": hi - lo + Vector2i.ONE}


## Caja de una pieza forjada con su giro, o con `rot` si se da.
static func of_item(item: CraftedItem, rot: int = -1) -> Dictionary:
	return footprint(item.item_resource.shape_cells, item.aristas, item.rot if rot < 0 else rot)


## Sortea sin repetir las aristas de una pieza de calidad `tier` entre sus sitios posibles.
static func roll_aristas(res: ItemResource, tier: String, rng: RandomNumberGenerator) -> Array[Vector2i]:
	var spots: Array[Vector2i] = []
	spots.assign(res.arista_spots)
	var out: Array[Vector2i] = []
	for i in mini(aristas_for_tier(tier), spots.size()):
		var k := rng.randi_range(0, spots.size() - 1)
		out.append(spots[k])
		spots.remove_at(k)
	return out


## "" si la forma y los sitios de arista del recurso valen; si no, el motivo. Los sitios tienen que ser 3,
## distintos, fuera de la forma y pegados a ella por un lado.
static func check_resource(res: ItemResource) -> String:
	if res.shape_cells.is_empty():
		return "sin forma"
	if res.arista_spots.size() != 3:
		return "hacen falta 3 sitios de arista (%d)" % res.arista_spots.size()
	var seen := {}
	for s in res.arista_spots:
		if s in res.shape_cells:
			return "el sitio %s pisa la forma" % s
		if seen.has(s):
			return "el sitio %s está repetido" % s
		seen[s] = true
		var touches := false
		for d in SIDES:
			if (s + d) in res.shape_cells:
				touches = true
		if not touches:
			return "el sitio %s no toca la forma por un lado" % s
	return ""
```

- [ ] **Step 7: Sitio, casilla, giro y aristas en `CraftedItem.gd`**

Variables. El rango aún no existe en esta base: se añade aquí con su valor por defecto, como lo define la tarea 5 de los rangos, que después le añadirá el escalado:

```gdscript
var rank: int = 1  # rango del plano con que se forjó (1 = rango I)
# Sitio en el inventario (spec del inventario en rejilla, apartado 3). Lo mantiene InventoryManager.
var place: StringName = &"loot"  ## &"hero" (rejilla de Tico), &"bag" (mochila) o &"loot" (botín)
var cell: Vector2i = Vector2i.ZERO  ## esquina de arriba a la izquierda de su caja en la rejilla
var rot: int = 0  ## cuartos de vuelta en el sentido de las agujas del reloj (0-3)
var aristas: Array[Vector2i] = []  ## casillas de más, en coordenadas de la pieza sin girar (PieceShape)
```

`to_dict()`: sustituye la clave `"equipped": is_equipped` por el rango y las del sitio:

```gdscript
		"rank": rank,
		"place": String(place),
		"x": cell.x,
		"y": cell.y,
		"rot": rot,
		"aristas": aristas.map(func(a): return [a.x, a.y]),
```

`from_dict()`: quita la línea `item.is_equipped = data.get("equipped", false)` y añade antes del `return`:

```gdscript
	item.rank = maxi(1, int(data.get("rank", 1)))
	item.place = StringName(data.get("place", "loot"))
	item.cell = Vector2i(int(data.get("x", 0)), int(data.get("y", 0)))
	item.rot = posmod(int(data.get("rot", 0)), 4)
	var ar: Array[Vector2i] = []
	for pair in data.get("aristas", []):
		if pair is Array and pair.size() == 2:
			ar.append(Vector2i(int(pair[0]), int(pair[1])))
	item.aristas = ar
```

Después de `get_display_name()`, el nombre con el numeral (el mismo que define la tarea 5 de los rangos; "Objeto desconocido" ya está en el CSV):

```gdscript
## Nombre con el numeral del rango, ya traducido: "Espada maestra III" (sin numeral en el rango I).
func get_name_with_rank() -> String:
	if item_resource == null:
		return tr("Objeto desconocido")
	return tr(item_resource.display_name) + Ranks.suffix(rank)
```

La variable `is_equipped` se queda por ahora: `InventoryManager` aún la usa y la quita la tarea 6. Su guardado sigue funcionando porque escribe el equipo aparte (`equipped_slots`).

- [ ] **Step 8: Ejecutar y ver que pasa**

Run: `D:/Software/Godot/godot_ver4.5.exe --headless --path . --import` y después InventoryGridTests, RankTests, GameplayTests y PixelTests.
Expected: 0 fallos en las cuatro.

- [ ] **Step 9: Commit**

```bash
git add scripts/core/PieceShape.gd scripts/core/PieceShape.gd.uid scripts/data/ItemResource.gd scripts/data/CraftedItem.gd data/items/*.tres scripts/tests/InventoryGridTests.gd scripts/tests/InventoryGridTests.gd.uid scenes/tests/InventoryGridTests.tscn
git commit -m "feat: formas de las piezas, giros y aristas por calidad (PieceShape)"
```

(Si `--import` no ha generado algún `.uid`, quítalo del `git add`. El repo guarda los `.gd.uid` de los scripts nuevos: ver la tarea 1 del plan de rangos.)

---

### Task 2: La rejilla (`GearGrid`)

**Files:**
- Create: `scripts/core/GearGrid.gd`
- Test: `scripts/tests/InventoryGridTests.gd`

**Interfaces:**
- Consumes: `PieceShape.of_item`, `PieceShape.shift`, `PieceShape.SIDES`
- Produces (`class_name GearGrid`, `RefCounted`):
  - datos: `size: Vector2i` e `items: Array[CraftedItem]`, y `GearGrid.new(grid_size: Vector2i)`;
  - consultas:
    - `in_bounds(c: Vector2i) -> bool`;
    - `cells_at(item, cell: Vector2i, rot: int) -> Dictionary` (casillas absolutas `clean` y `aristas`);
    - `overlapping(item, cell, rot) -> Array[CraftedItem]` (sin contar `item`);
    - `fits(item, cell, rot, ignore: Array = []) -> bool`;
    - `has(item) -> bool`, `cell_of(item) -> Vector2i`, `rot_of(item) -> int` e `item_at(c: Vector2i) -> CraftedItem`;
    - `placed_clean_cells(item) -> Array[Vector2i]` y `neighbors(item) -> Array[CraftedItem]`;
  - cambios: `place(item, cell, rot) -> bool`, `remove(item) -> void`, `resize(new_size: Vector2i) -> void` (nunca encoge) y `duplicate_grid() -> GearGrid`.
- La rejilla guarda la casilla y el giro de cada pieza por su cuenta y **no** escribe en la pieza: así las copias sirven para la vista previa. `InventoryManager` copia casilla y giro a la pieza al confirmar un movimiento.

- [ ] **Step 1: Pruebas que fallan**

Añade a `InventoryGridTests.gd`:

```gdscript
# ─── Tarea 2: la rejilla ───────────────────────────────────────────────

func test_grid_fits_and_places() -> void:
	var g := GearGrid.new(Vector2i(4, 4))
	var sword := _piece(&"sword_masterwork")  # 1×4
	check(g.fits(sword, Vector2i(0, 0), 0), "la espada de 1×4 cabe de pie en 4×4")
	check(not g.fits(sword, Vector2i(0, 1), 0), "una casilla más abajo se sale")
	check(g.fits(sword, Vector2i(0, 3), 1), "tumbada en la última fila cabe")
	check(g.place(sword, Vector2i(3, 0), 0) and g.cell_of(sword) == Vector2i(3, 0) and g.rot_of(sword) == 0, "se coloca en la columna derecha")
	var shield := _piece(&"shield_advanced")  # 2×2
	check(not g.fits(shield, Vector2i(2, 0), 0), "no puede pisar la espada")
	check(g.overlapping(shield, Vector2i(2, 0), 0) == [sword], "sabe a quién pisaría")
	check(g.fits(shield, Vector2i(2, 0), 0, [sword]), "si se ignora la espada, cabe (para intercambiar)")
	check(g.item_at(Vector2i(3, 2)) == sword and g.item_at(Vector2i(0, 0)) == null, "casillas ocupadas y libres")
	g.remove(sword)
	check(not g.has(sword) and g.item_at(Vector2i(3, 2)) == null, "al quitarla deja libres sus casillas")


func test_aristas_take_room_but_are_not_neighbors() -> void:
	var g := GearGrid.new(Vector2i(4, 4))
	var rough: Array[Vector2i] = [Vector2i(1, 0)]  # rebaba a la derecha de la punta
	var sword := _piece(&"sword_basic", 0.5, rough)
	check(g.place(sword, Vector2i(0, 0), 0), "la espada con arista ocupa 2 de ancho")
	var helmet := _piece(&"helmet_basic")
	check(not g.fits(helmet, Vector2i(1, 0), 0), "la arista ocupa su casilla")
	check(g.place(helmet, Vector2i(2, 0), 0), "el casco al lado de la arista")
	check(g.neighbors(helmet).is_empty() and g.neighbors(sword).is_empty(), "tocar solo la arista no es ser vecinas")
	var boots := _piece(&"boots_basic")
	check(g.place(boots, Vector2i(1, 1), 0), "las botas junto a la empuñadura")
	check(g.neighbors(sword) == [boots] and g.neighbors(boots) == [sword], "vecinas por un lado limpio")
	var diag := _piece(&"helmet_basic")
	check(g.place(diag, Vector2i(2, 2), 0) and not (diag in g.neighbors(boots)), "en diagonal no son vecinas")


func test_neighbors_count_each_piece_once() -> void:
	var g := GearGrid.new(Vector2i(4, 4))
	var a := _piece(&"sword_advanced")  # 1×3
	var b := _piece(&"sword_advanced")
	g.place(a, Vector2i(0, 0), 0)
	g.place(b, Vector2i(1, 0), 0)
	check(g.neighbors(a) == [b], "dos espadas pegadas por 3 casillas son vecinas una vez")


func test_grid_copy_does_not_touch_pieces() -> void:
	var g := GearGrid.new(Vector2i(4, 4))
	var s := _piece(&"shield_basic")
	g.place(s, Vector2i(0, 0), 0)
	var copy := g.duplicate_grid()
	copy.remove(s)
	copy.place(s, Vector2i(2, 2), 1)
	check(g.cell_of(s) == Vector2i(0, 0) and g.rot_of(s) == 0 and s.cell == Vector2i.ZERO, "mover en la copia no cambia la rejilla ni la pieza")
	g.resize(Vector2i(5, 4))
	check(g.size == Vector2i(5, 4) and g.cell_of(s) == Vector2i(0, 0), "crecer no mueve las piezas")
	g.resize(Vector2i(3, 3))
	check(g.size == Vector2i(5, 4), "nunca encoge")
```

Run InventoryGridTests. Expected: error de análisis (`GearGrid` no existe).

- [ ] **Step 2: `scripts/core/GearGrid.gd`**

```gdscript
class_name GearGrid
extends RefCounted

## Una rejilla de equipo (la de Tico o la mochila) con sus piezas colocadas (spec del inventario en
## rejilla, apartado 3). Guarda la casilla y el giro de cada pieza por su cuenta, sin escribir en la
## pieza: InventoryManager se los copia al confirmar un movimiento, y las copias (duplicate_grid)
## sirven para la vista previa sin tocar nada de verdad.

var size: Vector2i
var items: Array[CraftedItem] = []
var _pos: Dictionary = {}  # CraftedItem → {"cell": Vector2i, "rot": int}
var _occ: Dictionary = {}  # Vector2i → CraftedItem (todas sus casillas, aristas incluidas)
var _clean_occ: Dictionary = {}  # Vector2i → CraftedItem (solo las casillas limpias)


func _init(grid_size: Vector2i) -> void:
	size = grid_size


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < size.x and c.y < size.y


## Casillas absolutas de `item` si su caja empezara en `cell` con el giro `rot`.
func cells_at(item: CraftedItem, cell: Vector2i, rot: int) -> Dictionary:
	var fp := PieceShape.of_item(item, rot)
	return {"clean": PieceShape.shift(fp.clean, cell), "aristas": PieceShape.shift(fp.aristas, cell)}


## Piezas (sin contar `item`) que pisaría `item` en esa casilla y giro.
func overlapping(item: CraftedItem, cell: Vector2i, rot: int) -> Array[CraftedItem]:
	var out: Array[CraftedItem] = []
	var cs := cells_at(item, cell, rot)
	for c in cs.clean + cs.aristas:
		var other: CraftedItem = _occ.get(c)
		if other != null and other != item and not (other in out):
			out.append(other)
	return out


## true si `item` cabe en esa casilla y giro: todo dentro y sin pisar piezas que no estén en `ignore`.
func fits(item: CraftedItem, cell: Vector2i, rot: int, ignore: Array = []) -> bool:
	var cs := cells_at(item, cell, rot)
	for c in cs.clean + cs.aristas:
		if not in_bounds(c):
			return false
		var other: CraftedItem = _occ.get(c)
		if other != null and other != item and not (other in ignore):
			return false
	return true


## Coloca `item` (si ya estaba, lo mueve). false si no cabe.
func place(item: CraftedItem, cell: Vector2i, rot: int) -> bool:
	if not fits(item, cell, rot, [item]):
		return false
	remove(item)
	var cs := cells_at(item, cell, rot)
	for c in cs.clean:
		_occ[c] = item
		_clean_occ[c] = item
	for c in cs.aristas:
		_occ[c] = item
	_pos[item] = {"cell": cell, "rot": posmod(rot, 4)}
	items.append(item)
	return true


func remove(item: CraftedItem) -> void:
	if not _pos.has(item):
		return
	for key in _occ.keys():
		if _occ[key] == item:
			_occ.erase(key)
	for key in _clean_occ.keys():
		if _clean_occ[key] == item:
			_clean_occ.erase(key)
	_pos.erase(item)
	items.erase(item)


func has(item: CraftedItem) -> bool:
	return _pos.has(item)


func cell_of(item: CraftedItem) -> Vector2i:
	return _pos[item].cell if _pos.has(item) else Vector2i(-1, -1)


func rot_of(item: CraftedItem) -> int:
	return int(_pos[item].rot) if _pos.has(item) else 0


func item_at(c: Vector2i) -> CraftedItem:
	return _occ.get(c)


func placed_clean_cells(item: CraftedItem) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if _pos.has(item):
		out = cells_at(item, cell_of(item), rot_of(item)).clean
	return out


## Piezas que tocan por un lado alguna casilla limpia de `item` con una casilla limpia suya. Cada una,
## una vez.
func neighbors(item: CraftedItem) -> Array[CraftedItem]:
	var out: Array[CraftedItem] = []
	for c in placed_clean_cells(item):
		for d in PieceShape.SIDES:
			var other: CraftedItem = _clean_occ.get(c + d)
			if other != null and other != item and not (other in out):
				out.append(other)
	return out


## Hace crecer la rejilla (nunca encoge). Las piezas no se mueven.
func resize(new_size: Vector2i) -> void:
	size = Vector2i(maxi(size.x, new_size.x), maxi(size.y, new_size.y))


## Copia con las mismas piezas en los mismos sitios (para simular sin tocar esta).
func duplicate_grid() -> GearGrid:
	var g := GearGrid.new(size)
	for item in items:
		g.place(item, cell_of(item), rot_of(item))
	return g
```

- [ ] **Step 3: Ejecutar y ver que pasa**

Run: `--import` y después InventoryGridTests. Expected: 0 fallos.

- [ ] **Step 4: Commit**

```bash
git add scripts/core/GearGrid.gd scripts/core/GearGrid.gd.uid scripts/tests/InventoryGridTests.gd
git commit -m "feat: rejilla de equipo con piezas, aristas y vecinas (GearGrid)"
```

---

### Task 3: Auras, zonas y tope (`GearAuras`)

**Files:**
- Create: `scripts/core/GearAuras.gd`
- Modify: `scripts/tests/TextTests.gd` (tablas nuevas), `locale/textos.csv`
- Test: `scripts/tests/InventoryGridTests.gd`

**Interfaces:**
- Consumes: `GearGrid`, `CraftedItem.get_quality_tier()`, `CraftedItem.get_equipment_slot()`, `CraftedItem.calculated_stats`
- Produces (`class_name GearAuras`, estática):
  - constantes: `AURA_BY_TIER`, `ZONE_BONUS` (0,10), `CAP` (0,5), `STATS`, `INT_STATS`, `AURAS`, `ZONES`, `AURA_TEXTS` y `ZONE_TEXTS`;
  - `kind(item) -> StringName` (`&"weapon"` o `&"armor"`) y `aura_strength(item) -> float`;
  - zonas: `cell_in_zone(c: Vector2i, zone: StringName, size: Vector2i) -> bool` e `in_zone(grid, item) -> bool`;
  - `bonuses(grid: GearGrid) -> Dictionary` (pieza → {estadística: fracción, con tope}; solo las que suben);
  - `boosted_stats(item, pct: Dictionary) -> Dictionary`;
  - `totals(grid: GearGrid) -> Dictionary`, con las claves de `InventoryManager.calculate_total_stats()`.

- [ ] **Step 1: Pruebas que fallan**

```gdscript
# ─── Tarea 3: auras, zonas y tope ──────────────────────────────────────

func test_shield_aura_reaches_armor_neighbors_only() -> void:
	var g := GearGrid.new(Vector2i(5, 5))
	var shield := _piece(&"shield_advanced", 0.8)  # Raro: aura del 10 %
	var helmet := _piece(&"helmet_advanced", 0.2)  # Básico: sin aura propia
	var sword := _piece(&"sword_advanced", 0.2)
	g.place(shield, Vector2i(1, 1), 0)  # 2×2, lejos de los bordes
	g.place(helmet, Vector2i(1, 0), 0)  # 2×1 encima, en la fila de arriba (su zona)
	g.place(sword, Vector2i(3, 1), 0)   # 1×3 a la derecha del escudo, fuera de su zona (columna 4)
	var b := GearAuras.bonuses(g)
	check(is_equal_approx(b[helmet].get("armor", 0.0), 0.10 + GearAuras.ZONE_BONUS), "el casco recibe el 10 %% de armadura del escudo más su zona (%s)" % b[helmet])
	check(b[sword].get("armor", 0.0) == 0.0, "la espada no es armadura: no recibe el aura del escudo (%s)" % b[sword])
	check(b[shield].is_empty(), "el escudo no se potencia a sí mismo ni está en su zona (%s)" % b[shield])


func test_sword_and_boots_auras_go_to_weapons() -> void:
	var g := GearGrid.new(Vector2i(5, 5))
	var legendary_sword := _piece(&"sword_basic", 1.0)  # Legendario: 20 %
	var other_sword := _piece(&"sword_basic", 0.2)
	var boots := _piece(&"boots_basic", 0.95)  # Épico: 15 %
	g.place(legendary_sword, Vector2i(1, 1), 0)
	g.place(other_sword, Vector2i(2, 1), 0)
	g.place(boots, Vector2i(2, 3), 0)  # debajo de la segunda espada
	var b := GearAuras.bonuses(g)
	check(is_equal_approx(b[other_sword].get("damage", 0.0), 0.20), "+20 %% de daño de la espada legendaria vecina (%s)" % b[other_sword])
	check(is_equal_approx(b[other_sword].get("aps", 0.0), 0.15), "+15 %% de velocidad de las botas épicas (%s)" % b[other_sword])
	check(b[legendary_sword].get("damage", 0.0) == 0.0, "una espada de calidad Básico no da aura (%s)" % b[legendary_sword])


func test_bonus_is_capped() -> void:
	var g := GearGrid.new(Vector2i(3, 3))
	var center := _piece(&"helmet_basic", 0.2)
	g.place(center, Vector2i(1, 1), 0)
	for c in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(2, 1), Vector2i(1, 2)]:
		g.place(_piece(&"helmet_basic", 1.0), c, 0)
	var b := GearAuras.bonuses(g)
	check(is_equal_approx(b[center].hp, GearAuras.CAP), "cuatro cascos legendarios dan +80 %%, pero el tope lo deja en +50 %% (%s)" % b[center])


func test_zone_follows_the_grid_edge() -> void:
	var g := GearGrid.new(Vector2i(4, 4))
	var sword := _piece(&"sword_basic", 0.2)
	g.place(sword, Vector2i(3, 0), 0)
	check(GearAuras.in_zone(g, sword), "la espada en la columna derecha está en su zona")
	g.resize(Vector2i(5, 4))
	check(not GearAuras.in_zone(g, sword), "al crecer la rejilla, la columna derecha es la nueva")


func test_totals_match_a_hand_count() -> void:
	var g := GearGrid.new(Vector2i(4, 4))
	var shield := _piece(&"shield_basic", 0.8)  # Raro
	var helmet := _piece(&"helmet_basic", 0.8)  # Raro
	g.place(shield, Vector2i(0, 1), 0)  # columna izquierda: su zona
	g.place(helmet, Vector2i(1, 1), 0)  # vecino del escudo, fuera de la fila de arriba
	var t := GearAuras.totals(g)
	var s: Dictionary = shield.calculated_stats
	var h: Dictionary = helmet.calculated_stats
	# Escudo: zona +10 % en todo y +10 % de vida del casco. Casco: +10 % de armadura del escudo.
	var hp := float(s.hp) * (1.0 + 0.10 + 0.10) + float(h.hp)
	var armor := float(s.armor) * 1.10 + float(h.armor) * 1.10
	check(t.hp == roundi(hp) and t.armor == roundi(armor), "vida %d (espera %d) y armadura %d (espera %d)" % [t.hp, roundi(hp), t.armor, roundi(armor)])
	check(t.keys().size() == GearAuras.STATS.size(), "las mismas claves que calculate_total_stats")
```

Run InventoryGridTests. Expected: error de análisis (`GearAuras` no existe).

- [ ] **Step 2: `scripts/core/GearAuras.gd`**

```gdscript
class_name GearAuras
extends RefCounted

## Auras, zonas y tope de la rejilla de Tico (spec doc/specs/2026-09-27-inventario-en-rejilla.md,
## apartado 4). Sin nodos: lo usan InventoryManager (estadísticas de Tico y vista previa), el panel de
## Equipo (ficha y brillos) y BalanceSim. Los valores son de partida: los fija la calibración (tarea 16).

## Fuerza del aura según la calidad de quien la emite.
const AURA_BY_TIER := {"common": 0.0, "uncommon": 0.05, "rare": 0.10, "epic": 0.15, "legendary": 0.20}
const ZONE_BONUS := 0.10
const CAP := 0.5
const STATS := ["damage", "str", "agi", "int", "hp", "armor", "crit", "aps"]
const INT_STATS := ["damage", "str", "agi", "int", "hp", "armor"]
## Aura de cada tipo de pieza (por equipment_slot): estadística que sube y a qué vecinas.
const AURAS := {
	"main_hand": {"stat": "damage", "to": &"weapon"},
	"off_hand": {"stat": "armor", "to": &"armor"},
	"head": {"stat": "hp", "to": &"any"},
	"feet": {"stat": "aps", "to": &"weapon"},
}
## Borde donde rinde más cada tipo: la rejilla está delante de Tico, que mira a la derecha.
const ZONES := {"head": &"top", "feet": &"bottom", "off_hand": &"left", "main_hand": &"right"}
## Textos (base en español, se enseñan con tr()): %d es la fuerza en tanto por ciento.
const AURA_TEXTS := {
	"main_hand": "+%d %% de daño a las armas vecinas",
	"off_hand": "+%d %% de armadura a las armaduras vecinas",
	"head": "+%d %% de vida a todas las piezas vecinas",
	"feet": "+%d %% de velocidad de ataque a las armas vecinas",
}
const ZONE_TEXTS := {
	"head": "Rinde más en la fila de arriba",
	"feet": "Rinde más en la fila de abajo",
	"off_hand": "Rinde más en la columna izquierda",
	"main_hand": "Rinde más en la columna derecha",
}


static func kind(item: CraftedItem) -> StringName:
	return &"weapon" if item.get_equipment_slot() == "main_hand" else &"armor"


static func aura_strength(item: CraftedItem) -> float:
	return float(AURA_BY_TIER.get(item.get_quality_tier(), 0.0))


static func cell_in_zone(c: Vector2i, zone: StringName, size: Vector2i) -> bool:
	match zone:
		&"top":
			return c.y == 0
		&"bottom":
			return c.y == size.y - 1
		&"left":
			return c.x == 0
		&"right":
			return c.x == size.x - 1
	return false


## true si alguna casilla limpia de la pieza está en su zona.
static func in_zone(grid: GearGrid, item: CraftedItem) -> bool:
	var zone: StringName = ZONES.get(item.get_equipment_slot(), &"")
	for c in grid.placed_clean_cells(item):
		if cell_in_zone(c, zone, grid.size):
			return true
	return false


## Aumento de cada estadística de cada pieza de la rejilla, con el tope ya aplicado:
## pieza → {estadística: fracción}. Solo aparecen las estadísticas que suben.
static func bonuses(grid: GearGrid) -> Dictionary:
	var out := {}
	for item in grid.items:
		var pct := {}
		if in_zone(grid, item):
			for s in STATS:
				pct[s] = ZONE_BONUS
		out[item] = pct
	for emitter in grid.items:
		var strength := aura_strength(emitter)
		var aura: Dictionary = AURAS.get(emitter.get_equipment_slot(), {})
		if strength <= 0.0 or aura.is_empty():
			continue
		for receiver in grid.neighbors(emitter):
			if aura.to != &"any" and kind(receiver) != aura.to:
				continue
			var pct: Dictionary = out[receiver]
			pct[aura.stat] = float(pct.get(aura.stat, 0.0)) + strength
	for item in out:
		var pct: Dictionary = out[item]
		for s in pct.keys():
			pct[s] = minf(CAP, float(pct[s]))
	return out


## Estadísticas de una pieza con sus aumentos, sin redondear.
static func boosted_stats(item: CraftedItem, pct: Dictionary) -> Dictionary:
	var out := {}
	for s in STATS:
		out[s] = float(item.calculated_stats.get(s, 0)) * (1.0 + float(pct.get(s, 0.0)))
	return out


## Totales de la rejilla para Tico, con las claves de InventoryManager.calculate_total_stats(): las
## enteras redondeadas al final y crítico y velocidad con decimales.
static func totals(grid: GearGrid) -> Dictionary:
	var sum := {}
	for s in STATS:
		sum[s] = 0.0
	var b := bonuses(grid)
	for item in grid.items:
		var st := boosted_stats(item, b[item])
		for s in STATS:
			sum[s] += st[s]
	var out := {}
	for s in STATS:
		out[s] = roundi(sum[s]) if s in INT_STATS else sum[s]
	return out
```

- [ ] **Step 3: Textos**

En `TextTests._code_table_texts()`, antes del `return out`:

```gdscript
	for slot in GearAuras.AURA_TEXTS:
		out.append([String(GearAuras.AURA_TEXTS[slot]), "GearAuras.AURA_TEXTS"])
	for slot in GearAuras.ZONE_TEXTS:
		out.append([String(GearAuras.ZONE_TEXTS[slot]), "GearAuras.ZONE_TEXTS"])
```

Filas en `locale/textos.csv`:

```
+%d %% de daño a las armas vecinas,+%d %% de daño a las armas vecinas,+%d %% damage to adjacent weapons
+%d %% de armadura a las armaduras vecinas,+%d %% de armadura a las armaduras vecinas,+%d %% armor to adjacent armor
+%d %% de vida a todas las piezas vecinas,+%d %% de vida a todas las piezas vecinas,+%d %% health to all adjacent pieces
+%d %% de velocidad de ataque a las armas vecinas,+%d %% de velocidad de ataque a las armas vecinas,+%d %% attack speed to adjacent weapons
Rinde más en la fila de arriba,Rinde más en la fila de arriba,Stronger in the top row
Rinde más en la fila de abajo,Rinde más en la fila de abajo,Stronger in the bottom row
Rinde más en la columna izquierda,Rinde más en la columna izquierda,Stronger in the left column
Rinde más en la columna derecha,Rinde más en la columna derecha,Stronger in the right column
```

Run: `D:/Software/Godot/godot_ver4.5.exe --headless --path . --import`

- [ ] **Step 4: Ejecutar y ver que pasa**

Run: InventoryGridTests y TextTests. Expected: 0 fallos.

- [ ] **Step 5: Commit**

```bash
git add scripts/core/GearAuras.gd scripts/core/GearAuras.gd.uid scripts/tests/InventoryGridTests.gd scripts/tests/TextTests.gd locale/textos.csv
git commit -m "feat: auras entre vecinas, zonas del cuerpo y tope (GearAuras)"
```

**Nota tras la revisión (2026-10-01):** `bonuses()` solo apunta las estadísticas que la pieza tiene, tanto la zona como las auras (spec 4.1). La prueba de las claves de `totals()` compara con la lista literal. El código bueno está en el commit 862fd79; el de arriba es la primera versión.

---

### Task 4: Habilidades legendarias: datos y multiplicadores (`LegendaryPowers`)

**Files:**
- Create: `scripts/core/LegendaryPowers.gd`
- Modify: `scripts/core/CombatMath.gd`, `scripts/tests/TextTests.gd`, `locale/textos.csv`
- Test: `scripts/tests/InventoryGridTests.gd`

**Interfaces:**
- Consumes: `CombatMath.hero_stats`, `CraftedItem.get_quality_tier()`
- Produces:
  - de `LegendaryPowers` (estática):
    - constantes: `POWERS` (id de pieza → `name`, `text`, `price` y sus efectos), `EFFECT_KEYS` y `BURN_TIME` (3,0);
    - `is_legendary(item) -> bool`;
    - `active(items: Array) -> Array[StringName]` (ids de pieza, sin repetir, solo legendarias);
    - `apply_multipliers(stats: Dictionary, powers: Array) -> Dictionary`;
    - `effects(powers: Array) -> Dictionary` (cada clave de `EFFECT_KEYS` → valor, 0 si ninguna la da);
  - `CombatMath.hero_stats_with_powers(equipment: Dictionary, powers: Array) -> Dictionary`.

- [ ] **Step 1: Pruebas que fallan**

```gdscript
# ─── Tarea 4: habilidades legendarias (datos y multiplicadores) ────────

func test_every_piece_has_one_power() -> void:
	for id in ITEM_IDS:
		check(LegendaryPowers.POWERS.has(id), "%s tiene habilidad legendaria" % id)
	var priced := LegendaryPowers.POWERS.keys().filter(func(id): return LegendaryPowers.POWERS[id].price != "")
	check(priced.size() == 4 and priced.all(func(id): return String(_res(id).rarity) == "master"), "las 4 con precio son las maestras (%s)" % [priced])


func test_only_legendaries_count_and_only_once() -> void:
	var a := _piece(&"sword_basic", 1.0)
	var b := _piece(&"sword_basic", 1.0)
	var epic := _piece(&"shield_advanced", 0.95)
	check(LegendaryPowers.active([a, b, epic]) == [&"sword_basic"], "dos iguales cuentan como una y la épica no tiene habilidad")


func test_multipliers_apply_after_hero_stats_with_caps() -> void:
	var equip := {"damage": 20, "hp": 100, "armor": 10, "crit": 0.6, "aps": 1.0}
	var base := CombatMath.hero_stats(equip)
	var with := CombatMath.hero_stats_with_powers(equip, [&"sword_basic", &"helmet_basic", &"boots_master"])
	check(is_equal_approx(with.dmg, base.dmg * 1.25), "Filo perfecto: daño ×1,25 (%.2f)" % with.dmg)
	check(is_equal_approx(with.crit_p, 0.75), "Ojo de halcón multiplica el crítico, con el tope del 75 %% (%.3f)" % with.crit_p)
	check(with.armor == roundi(base.armor * 0.8), "Ímpetu cuesta un 20 %% de armadura (%d)" % with.armor)
	check(with.max_hp == base.max_hp, "la vida no cambia")
	var fx := LegendaryPowers.effects([&"boots_master", &"shield_advanced"])
	check(fx.first_strike == 3.0 and fx.block == 0.15 and fx.dodge == 0.0, "efectos de combate juntos (%s)" % fx)
```

Run InventoryGridTests. Expected: error de análisis (`LegendaryPowers` no existe).

- [ ] **Step 2: `scripts/core/LegendaryPowers.gd`**

```gdscript
class_name LegendaryPowers
extends RefCounted

## Habilidades de las piezas legendarias (spec doc/specs/2026-09-27-inventario-en-rejilla.md, apartado 5):
## una por pieza, cuenta si la pieza está en la rejilla de Tico y dos iguales cuentan como una. Las de las
## maestras tienen precio. Efectos:
##  - "mult": multiplica estadísticas finales de Tico (claves de CombatMath.hero_stats);
##  - "double_hit", "block" y "dodge": probabilidades;
##  - "burn": fracción del daño del golpe que quema en BURN_TIME s;
##  - "thorns": fracción del daño recibido que vuelve al atacante;
##  - "regen": fracción de la vida máxima que se recupera por segundo;
##  - "second_chance": fracción de vida con la que Tico sigue la primera vez que iba a caer en cada duelo;
##  - "first_strike": multiplicador del primer golpe contra cada enemigo.
## Los valores son de partida: los fija la calibración (tarea 16). Textos base en español, con tr().

const BURN_TIME := 3.0
const EFFECT_KEYS := ["double_hit", "burn", "block", "dodge", "thorns", "regen", "second_chance", "first_strike"]
const POWERS := {
	&"sword_basic": {"name": "Filo perfecto", "text": "Daño ×1,25", "price": "", "mult": {"dmg": 1.25}},
	&"sword_advanced": {"name": "Golpe doble", "text": "25 % de golpear dos veces", "price": "", "double_hit": 0.25},
	&"sword_masterwork": {"name": "Filo ígneo", "text": "Cada golpe quema: el 40 % de su daño en 3 s, sin contar la armadura", "price": "Probabilidad de crítico ×0,5", "burn": 0.4, "mult": {"crit_p": 0.5}},
	&"shield_basic": {"name": "Aguante", "text": "Vida máxima ×1,2", "price": "", "mult": {"max_hp": 1.2}},
	&"shield_advanced": {"name": "Parada", "text": "15 % de parar un golpe entero", "price": "", "block": 0.15},
	&"shield_master": {"name": "Espinas", "text": "Devuelve el 30 % del daño recibido", "price": "Velocidad de ataque ×0,85", "thorns": 0.3, "mult": {"aps": 0.85}},
	&"helmet_basic": {"name": "Ojo de halcón", "text": "Probabilidad de crítico ×1,5", "price": "", "mult": {"crit_p": 1.5}},
	&"helmet_advanced": {"name": "Regeneración", "text": "Recupera el 1,5 % de la vida máxima por segundo", "price": "", "regen": 0.015},
	&"helmet_master": {"name": "Segunda oportunidad", "text": "Una vez por duelo, al caer vuelve con el 40 % de la vida", "price": "Vida máxima ×0,85", "second_chance": 0.4, "mult": {"max_hp": 0.85}},
	&"boots_basic": {"name": "Paso ligero", "text": "Velocidad de ataque ×1,15", "price": "", "mult": {"aps": 1.15}},
	&"boots_advanced": {"name": "Esquiva", "text": "12 % de esquivar un golpe", "price": "", "dodge": 0.12},
	&"boots_master": {"name": "Ímpetu", "text": "El primer golpe contra cada enemigo hace ×3", "price": "Armadura ×0,8", "first_strike": 3.0, "mult": {"armor": 0.8}},
}


static func is_legendary(item: CraftedItem) -> bool:
	return item.get_quality_tier() == "legendary"


## Habilidades que dan unas piezas (las de la rejilla de Tico): una por pieza legendaria distinta.
static func active(items: Array) -> Array[StringName]:
	var out: Array[StringName] = []
	for item in items:
		if item == null or item.item_resource == null or not is_legendary(item):
			continue
		var id := StringName(item.item_resource.item_id)
		if POWERS.has(id) and not (id in out):
			out.append(id)
	return out


## Estadísticas de Tico (CombatMath.hero_stats) con los multiplicadores de las habilidades y los topes
## de siempre: crítico 75 %, velocidad de ataque entre 0,3 y 5.
static func apply_multipliers(stats: Dictionary, powers: Array) -> Dictionary:
	var out := stats.duplicate()
	for id in powers:
		var mult: Dictionary = POWERS[id].get("mult", {})
		for key in mult:
			out[key] = float(out[key]) * float(mult[key])
	out.max_hp = maxi(1, roundi(out.max_hp))
	out.armor = roundi(out.armor)
	out.aps = clampf(out.aps, 0.3, 5.0)
	out.crit_p = clampf(out.crit_p, 0.0, 0.75)
	return out


## Efectos de combate de unas habilidades: cada clave de EFFECT_KEYS → valor (0 si ninguna lo da).
static func effects(powers: Array) -> Dictionary:
	var out := {}
	for key in EFFECT_KEYS:
		out[key] = 0.0
	for id in powers:
		for key in EFFECT_KEYS:
			if POWERS[id].has(key):
				out[key] = float(POWERS[id][key])
	return out
```

En `CombatMath.gd`, después de `hero_stats`:

```gdscript
## hero_stats con los multiplicadores de las habilidades legendarias activas (LegendaryPowers.active).
static func hero_stats_with_powers(equipment: Dictionary, powers: Array) -> Dictionary:
	return LegendaryPowers.apply_multipliers(hero_stats(equipment), powers)
```

Puede que la tarea 0 anotara que `hero_stats` recibe el rango del equipo (la base de Tico por rango). Entonces esta función también lo recibe, como último parámetro y con el mismo valor por defecto, y se lo pasa. Quién le da cada valor:
- `Hero.reset_stats` (tarea 6): `InventoryManager.equipment_rank()`;
- `BalanceSim` (tarea 16): el rango de la rejilla simulada;
- las pruebas: pueden dejar el valor por defecto.

- [ ] **Step 3: Textos**

En `TextTests._code_table_texts()`, antes del `return out`:

```gdscript
	for id in LegendaryPowers.POWERS:
		var p: Dictionary = LegendaryPowers.POWERS[id]
		for key in ["name", "text", "price"]:
			if String(p[key]) != "":
				out.append([String(p[key]), "LegendaryPowers.POWERS.%s.%s" % [id, key]])
```

Filas en `locale/textos.csv` (las que llevan coma, entre comillas):

```
Filo perfecto,Filo perfecto,Perfect Edge
Golpe doble,Golpe doble,Double Strike
Filo ígneo,Filo ígneo,Fiery Edge
Aguante,Aguante,Endurance
Parada,Parada,Parry
Espinas,Espinas,Thorns
Ojo de halcón,Ojo de halcón,Hawk Eye
Regeneración,Regeneración,Regeneration
Segunda oportunidad,Segunda oportunidad,Second Chance
Paso ligero,Paso ligero,Light Step
Esquiva,Esquiva,Dodge
Ímpetu,Ímpetu,Momentum
"Daño ×1,25","Daño ×1,25","Damage ×1.25"
25 % de golpear dos veces,25 % de golpear dos veces,25 % chance to strike twice
"Cada golpe quema: el 40 % de su daño en 3 s, sin contar la armadura","Cada golpe quema: el 40 % de su daño en 3 s, sin contar la armadura","Each hit burns: 40 % of its damage over 3 s, ignoring armor"
"Vida máxima ×1,2","Vida máxima ×1,2","Max health ×1.2"
15 % de parar un golpe entero,15 % de parar un golpe entero,15 % chance to block a whole hit
Devuelve el 30 % del daño recibido,Devuelve el 30 % del daño recibido,Returns 30 % of damage taken
"Probabilidad de crítico ×1,5","Probabilidad de crítico ×1,5","Critical chance ×1.5"
"Recupera el 1,5 % de la vida máxima por segundo","Recupera el 1,5 % de la vida máxima por segundo","Recovers 1.5 % of max health per second"
"Una vez por duelo, al caer vuelve con el 40 % de la vida","Una vez por duelo, al caer vuelve con el 40 % de la vida","Once per fight, gets back up with 40 % health"
"Velocidad de ataque ×1,15","Velocidad de ataque ×1,15","Attack speed ×1.15"
12 % de esquivar un golpe,12 % de esquivar un golpe,12 % chance to dodge a hit
El primer golpe contra cada enemigo hace ×3,El primer golpe contra cada enemigo hace ×3,The first hit on each enemy deals ×3
"Probabilidad de crítico ×0,5","Probabilidad de crítico ×0,5","Critical chance ×0.5"
"Velocidad de ataque ×0,85","Velocidad de ataque ×0,85","Attack speed ×0.85"
"Vida máxima ×0,85","Vida máxima ×0,85","Max health ×0.85"
"Armadura ×0,8","Armadura ×0,8","Armor ×0.8"
```

Run: `--import`

- [ ] **Step 4: Ejecutar y ver que pasa**

Run: InventoryGridTests, RankTests y TextTests. Expected: 0 fallos.

- [ ] **Step 5: Commit**

```bash
git add scripts/core/LegendaryPowers.gd scripts/core/LegendaryPowers.gd.uid scripts/core/CombatMath.gd scripts/tests/InventoryGridTests.gd scripts/tests/TextTests.gd locale/textos.csv
git commit -m "feat: habilidades legendarias: tabla, activas y multiplicadores (LegendaryPowers)"
```

---

### Task 5: Colocación automática para la migración y la simulación (`GearPacker`)

**Files:**
- Create: `scripts/core/GearPacker.gd`
- Test: `scripts/tests/InventoryGridTests.gd`

**Interfaces:**
- Consumes: `GearGrid.fits`, `GearGrid.cells_at`, `GearGrid.place`, `GearAuras.ZONES`, `GearAuras.cell_in_zone`
- Produces (`class_name GearPacker`, estática):
  - `find_spot(grid: GearGrid, item: CraftedItem, prefer_zone: bool = true) -> Dictionary`: `{"cell": Vector2i, "rot": int}`, o `{}` si no cabe;
  - `pack(grid: GearGrid, items: Array, prefer_zone: bool = true) -> Array`: coloca en orden y devuelve lo que no ha cabido.
- En el juego no se usa para colocar nada: solo lo usan la migración (tarea 6) y `BalanceSim` (tarea 16).

- [ ] **Step 1: Pruebas que fallan**

```gdscript
# ─── Tarea 5: colocación automática (migración y simulación) ───────────

func test_packer_prefers_each_piece_zone() -> void:
	var g := GearGrid.new(Vector2i(4, 4))
	var pieces := [_piece(&"sword_advanced"), _piece(&"helmet_advanced"), _piece(&"boots_basic"), _piece(&"shield_basic")]
	check(GearPacker.pack(g, pieces).is_empty(), "las cuatro caben en 4×4")
	for item in pieces:
		check(GearAuras.in_zone(g, item), "%s queda en su zona" % item.item_resource.item_id)


func test_packer_returns_what_does_not_fit() -> void:
	var g := GearGrid.new(Vector2i(4, 4))
	var towers := []
	for i in 4:
		towers.append(_piece(&"shield_master"))  # 2×3 cada uno
	var left := GearPacker.pack(g, towers)
	check(left.size() == 2 and g.items.size() == 2, "en 4×4 caben 2 escudos torre; los otros 2 se devuelven (%d)" % left.size())
	check(GearPacker.find_spot(g, left[0]).is_empty(), "no queda sitio")
```

Run InventoryGridTests. Expected: error de análisis (`GearPacker` no existe).

- [ ] **Step 2: `scripts/core/GearPacker.gd`**

```gdscript
class_name GearPacker
extends RefCounted

## Colocación automática (spec del inventario en rejilla, apartados 6 y 10). En el juego no se coloca
## nada solo: esto lo usan la migración de partidas antiguas y BalanceSim. Determinista: prueba los
## giros 0 a 3 y las casillas de arriba abajo y de izquierda a derecha, primero las que tocan la zona de
## la pieza y después cualquiera.

## Primer sitio libre para `item`: {"cell": Vector2i, "rot": int}, o {} si no cabe en ninguno.
static func find_spot(grid: GearGrid, item: CraftedItem, prefer_zone: bool = true) -> Dictionary:
	var passes := [true, false] if prefer_zone else [false]
	for zone_only in passes:
		for rot in 4:
			for y in grid.size.y:
				for x in grid.size.x:
					var cell := Vector2i(x, y)
					if not grid.fits(item, cell, rot, [item]):
						continue
					if zone_only and not _touches_zone(grid, item, cell, rot):
						continue
					return {"cell": cell, "rot": rot}
	return {}


static func _touches_zone(grid: GearGrid, item: CraftedItem, cell: Vector2i, rot: int) -> bool:
	var zone: StringName = GearAuras.ZONES.get(item.get_equipment_slot(), &"")
	for c in grid.cells_at(item, cell, rot).clean:
		if GearAuras.cell_in_zone(c, zone, grid.size):
			return true
	return false


## Coloca las piezas en el orden dado donde quepan, sin mover las que ya hay. Devuelve las que no caben.
static func pack(grid: GearGrid, items: Array, prefer_zone: bool = true) -> Array:
	var left := []
	for item in items:
		var spot := find_spot(grid, item, prefer_zone)
		if spot.is_empty() or not grid.place(item, spot.cell, spot.rot):
			left.append(item)
	return left
```

- [ ] **Step 3: Ejecutar y ver que pasa**

Run: `--import` y después InventoryGridTests. Expected: 0 fallos.

- [ ] **Step 4: Commit**

```bash
git add scripts/core/GearPacker.gd scripts/core/GearPacker.gd.uid scripts/tests/InventoryGridTests.gd
git commit -m "feat: colocación automática para la migración y la simulación (GearPacker)"
```

---

### Task 6: `InventoryManager` con rejilla de Tico, mochila y botín

**Files:**
- Create: `scripts/core/GridExpansions.gd` (solo datos; los planos llegan en la tarea 12)
- Modify:
  - `scripts/autoload/InventoryManager.gd`;
  - `scripts/data/CraftedItem.gd` (precio de venta, sin `is_equipped`);
  - `scripts/ui/ShopPanel.gd` (`_get_sell_price`);
  - `scripts/autoload/CraftingManager.gd` (aristas al forjar);
  - `scripts/gameplay/Hero.gd` (`refresh_gear`, `reset_stats`);
  - `scripts/tests/GameplayTests.gd` (prueba de equipar), `scripts/tests/RankTests.gd` (estadísticas con habilidades), `scripts/tests/TextTests.gd` y `locale/textos.csv`.
- Test: `scripts/tests/InventoryGridTests.gd`

**Interfaces:**
- Consumes: `GearGrid`, `GearAuras.totals`, `GearAuras.bonuses`, `LegendaryPowers.active`, `GearPacker.find_spot`, `PieceShape.roll_aristas`, `PieceShape.of_item`, `Ranks.gold_mult`
- Produces:
  - `GridExpansions` (estática):
    - constantes `START_SIZE`, `SIZES`, `MAX_SIZE` y `RECIPES` (id → `room` y `name`);
    - `size_after(count: int) -> Vector2i`, `ids() -> Array[StringName]` e `is_expansion(id: StringName) -> bool`;
    - `recipe_for_boss_room(room: int) -> StringName` y `unlocked_for_record(record: int) -> Array[StringName]`;
  - `CraftedItem.SELL_PRICE_BY_TIER` y `CraftedItem.get_sell_price() -> int`. Se quita `CraftedItem.is_equipped`;
  - `CraftingManager.rng: RandomNumberGenerator`, que sortea las aristas;
  - `InventoryManager`:
    - constantes `PLACE_HERO`, `PLACE_BAG`, `PLACE_LOOT` y `BAG_SIZE`;
    - datos: `hero_grid: GearGrid`, `bag_grid: GearGrid`, `loot: Array[CraftedItem]` y `expansions: Array[StringName]`;
    - señales nuevas: `loot_changed(count: int)` y `grid_resized(size: Vector2i)`;
    - consultas de piezas:
      - `get_loot()`, `get_loot_count()`, `get_hero_items()` y `get_bag_items()`;
      - `get_unequipped_items()`, que devuelve botín y mochila;
      - `grid_for(place) -> GearGrid` y `hero_grid_size() -> Vector2i`;
    - movimientos:
      - `drop_result(item, place, cell, rot) -> {"ok": bool, "swap": CraftedItem}`;
      - `move_item(item, place, cell := Vector2i.ZERO, rot := 0) -> bool`;
      - `rotate_in_place(item) -> bool`;
    - venta: `sell_item(item) -> int`, `sellable_loot() -> Array[CraftedItem]` y `sell_all_loot() -> int`;
    - estadísticas:
      - `calculate_total_stats()` (misma firma y claves que antes), `hero_bonuses() -> Dictionary` y `active_legendary_powers() -> Array[StringName]`;
      - `simulate_hero_grid(item, place, cell, rot) -> GearGrid` y `preview_stats(item, place, cell, rot) -> Dictionary`;
    - sprite: `best_hero_item(slot: String) -> CraftedItem` y `static gear_score(item) -> float`;
    - rango del equipo: `equipment_rank() -> int` (spec, apartado 6);
    - guardado: `load_save_data(data: Dictionary, record: int = 1)`;
    - compatibilidad provisional, hasta la tarea 10: `equip_item`, `unequip_item` y `get_equipped_item`.

- [ ] **Step 1: Pruebas que fallan**

```gdscript
# ─── Tarea 6: los tres sitios del inventario ───────────────────────────

func _im() -> Node:
	return get_node("/root/InventoryManager")


## Deja el inventario vacío (rejilla de 4×4) y devuelve lo que había para restaurarlo.
func _fresh_inventory() -> Dictionary:
	var saved: Dictionary = _im().to_save_data()
	_im().clear()
	return saved


func _restore_inventory(saved: Dictionary) -> void:
	_im().load_save_data(saved, int(get_node("/root/GameManager").best_enemy_level))
	await get_tree().process_frame  # deja pasar los guardados diferidos del cambio de equipo


func test_grid_expansion_sizes_and_bosses() -> void:
	check(GridExpansions.size_after(0) == Vector2i(4, 4) and GridExpansions.size_after(1) == Vector2i(5, 4), "de 4×4 a 5×4")
	check(GridExpansions.size_after(4) == Vector2i(6, 6) and GridExpansions.size_after(9) == Vector2i(6, 6), "el máximo es 6×6")
	check(GridExpansions.recipe_for_boss_room(10) == &"grid_bone_straps" and GridExpansions.recipe_for_boss_room(50) == &"", "jefes 10-40 del ciclo I")
	check(GridExpansions.unlocked_for_record(10).is_empty() and GridExpansions.unlocked_for_record(11) == [&"grid_bone_straps"], "récord mayor que la sala del jefe")


func test_new_pieces_arrive_at_the_front_of_the_loot() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var a := _piece(&"sword_basic")
	var b := _piece(&"shield_basic")
	im.add_crafted_item(a)
	im.add_crafted_item(b)
	check(im.get_loot() == [b, a] and a.place == &"loot", "lo más nuevo delante (%s)" % [im.get_loot()])
	check(im.hero_grid_size() == Vector2i(4, 4) and im.get_hero_items().is_empty(), "rejilla de 4×4 vacía: nada se coloca solo")
	check(im.get_unequipped_items().size() == 2, "botín y mochila se pueden vender")
	await _restore_inventory(saved)


func test_move_place_swap_and_back_to_loot() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var old_sword := _piece(&"sword_basic", 0.5)
	var new_sword := _piece(&"sword_advanced", 0.95)
	im.add_crafted_item(old_sword)
	im.add_crafted_item(new_sword)
	check(im.move_item(old_sword, &"hero", Vector2i(3, 0), 0), "la espada vieja a la columna derecha")
	check(old_sword.place == &"hero" and old_sword.cell == Vector2i(3, 0), "la pieza guarda su sitio")
	check(not im.move_item(new_sword, &"hero", Vector2i(3, 2), 0), "la nueva no cabe si se sale por abajo")
	var res: Dictionary = im.drop_result(new_sword, &"hero", Vector2i(3, 0), 0)
	check(res.ok and res.swap == old_sword, "encima de la vieja: intercambio")
	check(im.move_item(new_sword, &"hero", Vector2i(3, 0), 0), "se intercambian")
	check(new_sword.place == &"hero" and old_sword.place == &"loot", "la vieja va al botín, de donde salió la nueva")
	check(im.get_loot()[0] == old_sword, "en el sitio del botín que tenía la nueva")
	check(im.move_item(new_sword, &"loot"), "de vuelta al botín")
	check(im.get_hero_items().is_empty(), "la rejilla queda vacía")
	await _restore_inventory(saved)


func test_swap_sends_the_other_to_loot_if_it_does_not_fit_back() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var tower := _piece(&"shield_master")  # 2×3
	var small := _piece(&"helmet_basic")   # 1×1
	im.add_crafted_item(tower)
	im.add_crafted_item(small)
	check(im.move_item(small, &"bag", Vector2i(5, 3), 0), "el casco en la esquina de la mochila")
	check(im.move_item(tower, &"hero", Vector2i(0, 0), 0), "el escudo torre en Tico")
	check(im.move_item(small, &"hero", Vector2i(0, 0), 0), "el casco encima del escudo: intercambio")
	check(small.place == &"hero" and tower.place == &"loot", "el escudo no cabe en la esquina de la mochila: va al botín y no se pierde")
	await _restore_inventory(saved)


func test_rotate_in_place_needs_room() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var sword := _piece(&"sword_masterwork")  # 1×4
	im.add_crafted_item(sword)
	check(im.move_item(sword, &"hero", Vector2i(1, 0), 0), "de pie en la columna 1")
	check(im.rotate_in_place(sword) and sword.rot == 1 and sword.cell == Vector2i(0, 1), "gira sobre su centro: tumbada en la fila 1 (%s)" % sword.cell)
	var helmet := _piece(&"helmet_basic")
	im.add_crafted_item(helmet)
	check(im.move_item(helmet, &"hero", Vector2i(1, 3), 0), "un casco debajo")
	check(not im.rotate_in_place(sword) and sword.rot == 1, "de pie ya no cabe: no gira")
	await _restore_inventory(saved)


func test_sell_and_sell_all_keep_the_best() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var common := _piece(&"boots_basic", 0.2)
	var epic := _piece(&"boots_basic", 0.95)
	var legend := _piece(&"boots_basic", 1.0)
	var kept := _piece(&"helmet_basic", 0.5)
	for p in [common, epic, legend, kept]:
		im.add_crafted_item(p)
	check(im.move_item(kept, &"bag", Vector2i(0, 0), 0), "una pieza en la mochila")
	var gold := im.sell_all_loot()
	check(gold == common.get_sell_price(), "Vender todo solo vende lo que no es Épico ni Legendario (%d)" % gold)
	check(im.get_loot().size() == 2 and epic in im.get_loot() and legend in im.get_loot(), "la épica y la legendaria siguen en el botín")
	check(kept.place == &"bag", "la mochila no se toca")
	check(im.sell_item(legend) == legend.get_sell_price() and not (legend in im.get_crafted_items()), "vender una suelta")
	check(im.get_quantity(&"gold") == gold + legend.get_sell_price(), "el oro sube lo vendido")
	await _restore_inventory(saved)


func test_totals_and_preview_use_the_hero_grid_only() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var shield := _piece(&"shield_basic", 0.8)
	var helmet := _piece(&"helmet_basic", 0.8)
	im.add_crafted_item(shield)
	im.add_crafted_item(helmet)
	im.move_item(shield, &"hero", Vector2i(0, 1), 0)
	im.move_item(helmet, &"bag", Vector2i(0, 0), 0)
	check(im.calculate_total_stats() == GearAuras.totals(im.hero_grid), "las estadísticas de Tico son las de su rejilla")
	var before: Dictionary = im.calculate_total_stats()
	var preview: Dictionary = im.preview_stats(helmet, &"hero", Vector2i(1, 1), 0)
	check(preview.hp > before.hp, "la vista previa suma el casco con su aura (%d → %d)" % [before.hp, preview.hp])
	check(im.calculate_total_stats() == before and helmet.place == &"bag", "la vista previa no mueve nada")
	await _restore_inventory(saved)


func test_hero_sprite_shows_the_best_piece_of_each_kind() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var weak := _piece(&"sword_masterwork", 0.3)
	var strong := _piece(&"sword_advanced", 0.9)
	strong.rank = 2
	for p in [weak, strong]:
		im.add_crafted_item(p)
	im.move_item(weak, &"hero", Vector2i(0, 0), 0)
	im.move_item(strong, &"hero", Vector2i(1, 0), 0)
	check(im.best_hero_item("main_hand") == strong, "el rango manda sobre el nivel")
	var hero: Node2D = load("res://scenes/Hero.tscn").instantiate()
	hero.remove_from_group("hero")
	add_child(hero)
	await get_tree().process_frame
	hero.refresh_gear()
	check(hero.gear.get("main_hand", {}).get("rarity", "") == "advanced", "Tico dibuja la espada de rango II (%s)" % hero.gear)
	hero.queue_free()
	await _restore_inventory(saved)


func test_equipment_rank_is_the_weakest_best_piece() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	check(im.equipment_rank() == 1, "sin piezas, rango I")
	var sword3 := _piece(&"sword_basic")
	sword3.rank = 3
	var sword1 := _piece(&"sword_basic")
	var helmet2 := _piece(&"helmet_basic")
	helmet2.rank = 2
	for p in [sword3, sword1, helmet2]:
		im.add_crafted_item(p)
	im.move_item(sword3, &"hero", Vector2i(3, 0), 0)
	check(im.equipment_rank() == 3, "una espada de rango III: rango III")
	im.move_item(sword1, &"hero", Vector2i(2, 0), 0)
	check(im.equipment_rank() == 3, "otra espada de rango I no lo baja: cuenta la mejor espada")
	im.move_item(helmet2, &"hero", Vector2i(0, 0), 0)
	check(im.equipment_rank() == 2, "un casco de rango II sí: el menor entre los tipos")
	await _restore_inventory(saved)


func test_hero_stats_include_legendary_multipliers() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var shield := _piece(&"shield_basic", 1.0)  # Aguante: vida máxima ×1,2
	im.add_crafted_item(shield)
	im.move_item(shield, &"hero", Vector2i(0, 0), 0)
	var hero: Node2D = load("res://scenes/Hero.tscn").instantiate()
	hero.remove_from_group("hero")
	add_child(hero)
	await get_tree().process_frame
	var expected := CombatMath.hero_stats_with_powers(im.calculate_total_stats(), [&"shield_basic"])
	check(hero.max_hp == expected.max_hp and hero.max_hp > CombatMath.hero_stats(im.calculate_total_stats()).max_hp, "Aguante sube la vida de Tico (%d)" % hero.max_hp)
	hero.queue_free()
	await _restore_inventory(saved)


func test_forging_rolls_aristas_by_quality() -> void:
	var cm := get_node("/root/CraftingManager")
	var im := _im()
	var Task = cm.get_script().CraftingTask  # clase interna del autoload (no tiene class_name)
	var bp: BlueprintResource = get_node("/root/DataManager").get_blueprint(&"sword_masterwork")
	var task = Task.new(9100, bp, 0)
	task.score_accumulated = 50.0
	task.max_score_accumulated = 100.0
	var fm_before: int = cm.forjamagia
	cm.forjamagia = 0  # sin bonus de Forjamagia: calidad 0,5 (Bueno)
	cm.rng.seed = 99
	var result: Dictionary = cm._finalize_task(task)
	var item: CraftedItem = result.crafted_item
	check(item != null and item.get_quality_tier() == "uncommon" and item.aristas.size() == 2, "una espada al 50 %% sale con 2 aristas (%s)" % (str(item.aristas) if item else "sin pieza"))
	check(item != null and item.place == &"loot" and im.get_loot()[0] == item, "y llega al botín, delante")
	if item:
		im.remove_crafted_item(item)
	cm.forjamagia = fm_before
```

Run InventoryGridTests. Expected: error de análisis (`GridExpansions` no existe) o fallos por las funciones que faltan.

- [ ] **Step 2: `scripts/core/GridExpansions.gd` (datos)**

```gdscript
class_name GridExpansions
extends RefCounted

## Recetas de ampliación de la rejilla de Tico (spec doc/specs/2026-09-27-inventario-en-rejilla.md,
## apartado 7): una por jefe de las salas 10, 20, 30 y 40 del ciclo I. Cada receta forjada lleva la
## rejilla al tamaño siguiente de SIZES, sea cual sea la receta. Solo cuentan los jefes del ciclo I.

const START_SIZE := Vector2i(4, 4)
## Tamaño tras 1, 2, 3 y 4 ampliaciones: columna a la derecha, fila abajo, alternando.
const SIZES: Array[Vector2i] = [Vector2i(5, 4), Vector2i(5, 5), Vector2i(6, 5), Vector2i(6, 6)]
const MAX_SIZE := Vector2i(6, 6)
## Receta → jefe que la desbloquea (sala del ciclo I) y nombre (texto base, con tr()), en el orden de
## los jefes. Materiales y pruebas del plano: blueprint() (tarea 12).
const RECIPES := {
	&"grid_bone_straps": {"room": 10, "name": "Correas de hueso"},
	&"grid_moss_pouches": {"room": 20, "name": "Bolsas de musgo"},
	&"grid_obsidian_buckles": {"room": 30, "name": "Hebillas de obsidiana"},
	&"grid_frost_harness": {"room": 40, "name": "Arnés de escarcha"},
}


static func size_after(count: int) -> Vector2i:
	if count <= 0:
		return START_SIZE
	return SIZES[mini(count, SIZES.size()) - 1]


static func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for id in RECIPES:
		out.append(id)
	return out


static func is_expansion(id: StringName) -> bool:
	return RECIPES.has(id)


## Receta que desbloquea vencer al jefe de `room`, o &"" (solo las salas 10 a 40 del ciclo I).
static func recipe_for_boss_room(room: int) -> StringName:
	for id in RECIPES:
		if int(RECIPES[id].room) == room:
			return id
	return &""


## Recetas desbloqueadas con un récord: las de los jefes que ya ha vencido (récord mayor que su sala).
static func unlocked_for_record(record: int) -> Array[StringName]:
	var out: Array[StringName] = []
	for id in RECIPES:
		if record > int(RECIPES[id].room):
			out.append(id)
	return out
```

- [ ] **Step 3: Precio de venta en `CraftedItem.gd`**

Quita la línea `var is_equipped: bool = false`. Añade:

```gdscript
## Precio de venta según la calidad (antes en ShopPanel), por el multiplicador de oro de su rango.
const SELL_PRICE_BY_TIER := {"legendary": 500, "epic": 250, "rare": 120, "uncommon": 60, "common": 25}


func get_sell_price() -> int:
	return roundi(SELL_PRICE_BY_TIER.get(get_quality_tier(), 25) * Ranks.gold_mult(rank))
```

En `ShopPanel.gd`, `_get_sell_price(item)` pasa a ser `return item.get_sell_price()` y se borra `SELL_PRICE_BY_TIER`. Comprueba antes que nadie más lo usa: `grep -rn "SELL_PRICE_BY_TIER" scripts`. Si algo más lo usa, cámbialo a `CraftedItem.SELL_PRICE_BY_TIER`.

- [ ] **Step 4: `InventoryManager.gd`**

El bloque de materiales (`_ready`, `STARTING_MATERIALS`, `_give_starting_materials`, `add_item`, `add_drops`, `get_quantity`, `get_materials`, `has_materials` y `consume_materials`) se queda igual. Cambia la cabecera y sustituye todo lo que va desde `func clear()` hasta el final del fichero.

Cabecera (sustituye las líneas desde `extends Node` hasta `var equipped_items`):

```gdscript
extends Node
class_name InventoryManager

## Materiales y piezas forjadas. Cada pieza está siempre en uno de tres sitios (spec
## doc/specs/2026-09-27-inventario-en-rejilla.md, apartado 3):
##  - la rejilla de Tico (hero_grid): lo único que cuenta para sus estadísticas;
##  - la mochila (bag_grid, 6×4 fija): guarda sin contar;
##  - el botín (loot): lista sin límite con lo más nuevo delante. Aquí llega todo lo forjado.
## Nada se coloca solo, salvo en la migración de partidas antiguas. Las reglas viven en PieceShape,
## GearGrid, GearAuras, LegendaryPowers, GearPacker y GridExpansions.

const _SaveManager = preload("res://scripts/core/SaveManager.gd")

signal inventory_changed(current_inventory)
signal crafted_items_changed(items_array)
signal equipment_changed(equipment_stats: Dictionary)  ## ha cambiado la rejilla de Tico
signal loot_changed(count: int)
signal grid_resized(size: Vector2i)

const PLACE_HERO := &"hero"
const PLACE_BAG := &"bag"
const PLACE_LOOT := &"loot"
const BAG_SIZE := Vector2i(6, 4)
const LEVEL_ORDER := {"basic": 0, "advanced": 1, "master": 2}

# Diccionario de materiales (StringName -> int)
var inventory: Dictionary = {}
## Todas las piezas forjadas, estén donde estén
var crafted_items: Array[CraftedItem] = []
var hero_grid: GearGrid = GearGrid.new(GridExpansions.START_SIZE)
var bag_grid: GearGrid = GearGrid.new(BAG_SIZE)
var loot: Array[CraftedItem] = []
## Recetas de ampliación ya forjadas: la rejilla de Tico mide GridExpansions.size_after(expansions.size())
var expansions: Array[StringName] = []
```

Desde `func clear()` hasta el final:

```gdscript
func clear() -> void:
	inventory.clear()
	crafted_items.clear()
	loot.clear()
	expansions.clear()
	hero_grid = GearGrid.new(GridExpansions.START_SIZE)
	bag_grid = GearGrid.new(BAG_SIZE)
	emit_signal("inventory_changed", inventory.duplicate())
	grid_resized.emit(hero_grid.size)
	_changed(true)

# ═══════════════════════════════════════════════════════════════════
#  PIEZAS
# ═══════════════════════════════════════════════════════════════════

## Lo recién forjado llega al botín, delante. Nada se coloca solo.
func add_crafted_item(item: CraftedItem) -> void:
	if item == null:
		push_warning("InventoryManager: Intentando añadir item null")
		return
	crafted_items.append(item)
	_put_in_loot(item, 0)
	_changed(false)
	print("InventoryManager: Pieza al botín: %s (calidad: %d%%)" % [item.get_display_name(), item.get_quality_percent()])


func get_crafted_items() -> Array[CraftedItem]:
	return crafted_items


func get_loot() -> Array[CraftedItem]:
	return loot


func get_loot_count() -> int:
	return loot.size()


func get_hero_items() -> Array[CraftedItem]:
	return hero_grid.items


func get_bag_items() -> Array[CraftedItem]:
	return bag_grid.items


## Lo que no lleva Tico (botín y mochila): lo que la tienda deja vender.
func get_unequipped_items() -> Array[CraftedItem]:
	var out: Array[CraftedItem] = []
	out.append_array(loot)
	out.append_array(bag_grid.items)
	return out


func grid_for(place: StringName) -> GearGrid:
	if place == PLACE_HERO:
		return hero_grid
	if place == PLACE_BAG:
		return bag_grid
	return null


func hero_grid_size() -> Vector2i:
	return hero_grid.size


## Qué pasaría al soltar `item` en `place` con esa casilla y giro: {"ok": bool, "swap": pieza o null}.
## En el botín siempre cabe. En una rejilla, en casillas libres, o encima de una sola pieza si cabe al
## quitarla (intercambio).
func drop_result(item: CraftedItem, place: StringName, cell: Vector2i = Vector2i.ZERO, rot: int = 0) -> Dictionary:
	if place == PLACE_LOOT:
		return {"ok": true, "swap": null}
	var grid := grid_for(place)
	if grid == null or item == null:
		return {"ok": false, "swap": null}
	var others := grid.overlapping(item, cell, rot)
	if others.is_empty():
		return {"ok": grid.fits(item, cell, rot, [item]), "swap": null}
	if others.size() == 1 and grid.fits(item, cell, rot, [item, others[0]]):
		return {"ok": true, "swap": others[0]}
	return {"ok": false, "swap": null}


## Mueve una pieza. Encima de una sola pieza se intercambian: la otra va al sitio de donde salió la
## primera (con su propio giro) si cabe allí; si no, al botín. true si se ha movido.
func move_item(item: CraftedItem, place: StringName, cell: Vector2i = Vector2i.ZERO, rot: int = 0) -> bool:
	if item == null or not (item in crafted_items):
		return false
	var res := drop_result(item, place, cell, rot)
	if not res.ok:
		return false
	var from_place := item.place
	var from_cell := item.cell
	var from_loot := loot.find(item)
	var other: CraftedItem = res.swap
	var hero_changed := from_place == PLACE_HERO or place == PLACE_HERO
	_take_out(item)
	if other:
		_take_out(other)
	_put(item, place, cell, rot)
	if other:
		if from_place == PLACE_LOOT or not _try_put(other, from_place, from_cell, other.rot):
			_put_in_loot(other, maxi(0, from_loot))
	_changed(hero_changed)
	return true


## Toque sobre una pieza de una rejilla: gira 90° sobre su centro, o sobre su esquina si así cabe.
## false si girada no cabe (el panel la hace temblar).
func rotate_in_place(item: CraftedItem) -> bool:
	var grid := grid_for(item.place)
	if grid == null:
		return false
	var new_rot := (item.rot + 1) % 4
	var old_size: Vector2i = PieceShape.of_item(item).size
	var new_size: Vector2i = PieceShape.of_item(item, new_rot).size
	@warning_ignore("integer_division")
	var centered := item.cell + Vector2i((old_size.x - new_size.x) / 2, (old_size.y - new_size.y) / 2)
	for cell in [centered, item.cell]:
		if grid.fits(item, cell, new_rot, [item]):
			grid.place(item, cell, new_rot)
			item.cell = cell
			item.rot = new_rot
			_changed(item.place == PLACE_HERO)
			return true
	return false


## Vende una pieza (esté donde esté) y suma su oro. Devuelve el oro (0 si no se vendió).
func sell_item(item: CraftedItem) -> int:
	if item == null or not (item in crafted_items):
		return 0
	var price := item.get_sell_price()
	remove_crafted_item(item)
	add_item(&"gold", price)
	return price


## Lo que vende "Vender todo": el botín salvo las Épicas y las Legendarias.
func sellable_loot() -> Array[CraftedItem]:
	var out: Array[CraftedItem] = []
	for item in loot:
		if not (item.get_quality_tier() in ["epic", "legendary"]):
			out.append(item)
	return out


## "Vender todo": vende sellable_loot() y devuelve el oro ganado.
func sell_all_loot() -> int:
	var gold := 0
	for item in sellable_loot():
		gold += item.get_sell_price()
		_take_out(item)
		crafted_items.erase(item)
	if gold > 0:
		add_item(&"gold", gold)
		_changed(false)
	return gold


## Quita una pieza del inventario (venta en la tienda, pruebas).
func remove_crafted_item(item: CraftedItem) -> bool:
	if item == null or not (item in crafted_items):
		return false
	var was_hero := item.place == PLACE_HERO
	_take_out(item)
	crafted_items.erase(item)
	_changed(was_hero)
	return true

# ═══════════════════════════════════════════════════════════════════
#  ESTADÍSTICAS DE TICO
# ═══════════════════════════════════════════════════════════════════

## Totales del equipo para Tico: las piezas de su rejilla con auras, zonas y tope (GearAuras).
func calculate_total_stats() -> Dictionary:
	return GearAuras.totals(hero_grid)


## Aumentos de cada pieza de Tico (pieza → {estadística: fracción}): ficha y brillos del panel.
func hero_bonuses() -> Dictionary:
	return GearAuras.bonuses(hero_grid)


## Habilidades legendarias que cuentan: las de las piezas legendarias de la rejilla de Tico.
func active_legendary_powers() -> Array[StringName]:
	return LegendaryPowers.active(hero_grid.items)


## La rejilla de Tico como quedaría tras soltar `item` ahí. Es una copia: no mueve nada.
func simulate_hero_grid(item: CraftedItem, place: StringName, cell: Vector2i, rot: int) -> GearGrid:
	var g := hero_grid.duplicate_grid()
	var res := drop_result(item, place, cell, rot)
	if not res.ok:
		return g
	var other: CraftedItem = res.swap
	g.remove(item)
	if place == PLACE_HERO:
		if other:
			g.remove(other)
		g.place(item, cell, rot)
	if other and item.place == PLACE_HERO:
		g.place(other, item.cell, other.rot)  # la otra vuelve al sitio de la primera, si cabe
	return g


## Estadísticas del equipo si `item` se soltara ahí (sin mover nada): vista previa del arrastre.
func preview_stats(item: CraftedItem, place: StringName, cell: Vector2i, rot: int) -> Dictionary:
	return GearAuras.totals(simulate_hero_grid(item, place, cell, rot))


## La mejor pieza de un tipo ("main_hand", "off_hand", "head" o "feet") en la rejilla de Tico: primero
## el rango, después el nivel y después la calidad. Es la que dibuja su sprite.
func best_hero_item(slot: String) -> CraftedItem:
	var best: CraftedItem = null
	for item in hero_grid.items:
		if item.get_equipment_slot() != slot:
			continue
		if best == null or gear_score(item) > gear_score(best):
			best = item
	return best


static func gear_score(item: CraftedItem) -> float:
	var level: int = LEVEL_ORDER.get(String(item.item_resource.rarity) if item.item_resource else "basic", 0)
	return float(item.rank) * 1000.0 + float(level) * 10.0 + item.quality


## Rango del equipo (spec de rangos, apartado 6, "Base de Tico"; spec del inventario, apartado 6): el
## menor rango entre las mejores piezas de cada tipo de la rejilla de Tico. Añadir una pieza de un tipo
## que ya lleva nunca lo baja. Sin piezas, rango I.
func equipment_rank() -> int:
	var rank := 0
	for slot in ["main_hand", "off_hand", "head", "feet"]:
		var best := best_hero_item(slot)
		if best:
			rank = best.rank if rank == 0 else mini(rank, best.rank)
	return maxi(1, rank)

# ═══════════════════════════════════════════════════════════════════
#  SITIOS (privado)
# ═══════════════════════════════════════════════════════════════════

## Saca una pieza de donde esté, sin avisar.
func _take_out(item: CraftedItem) -> void:
	hero_grid.remove(item)
	bag_grid.remove(item)
	loot.erase(item)


## Pone una pieza (ya fuera de todo sitio) en `place`. Si no cabe en la rejilla, al botín.
func _put(item: CraftedItem, place: StringName, cell: Vector2i, rot: int) -> void:
	if place == PLACE_LOOT or not _try_put(item, place, cell, rot):
		_put_in_loot(item, 0)


func _try_put(item: CraftedItem, place: StringName, cell: Vector2i, rot: int) -> bool:
	var grid := grid_for(place)
	if grid == null or not grid.place(item, cell, rot):
		return false
	item.place = place
	item.cell = cell
	item.rot = posmod(rot, 4)
	return true


func _put_in_loot(item: CraftedItem, index: int) -> void:
	loot.insert(clampi(index, 0, loot.size()), item)
	item.place = PLACE_LOOT


## Avisa de un cambio de piezas; si ha cambiado la rejilla de Tico, también de su equipo.
func _changed(hero_changed: bool) -> void:
	emit_signal("crafted_items_changed", crafted_items)
	loot_changed.emit(loot.size())
	if hero_changed:
		emit_signal("equipment_changed", calculate_total_stats())

# ═══════════════════════════════════════════════════════════════════
#  COMPATIBILIDAD PROVISIONAL (la quita la tarea 10, con el panel nuevo)
# ═══════════════════════════════════════════════════════════════════

## Equipa como el panel viejo: la pieza entra en el primer sitio libre de la rejilla de Tico.
func equip_item(item: CraftedItem) -> bool:
	if item == null or not (item in crafted_items) or item.place == PLACE_HERO:
		return false
	var spot := GearPacker.find_spot(hero_grid, item)
	return not spot.is_empty() and move_item(item, PLACE_HERO, spot.cell, spot.rot)


## Quita de Tico la mejor pieza de ese hueco antiguo y la manda al botín.
func unequip_item(slot: String) -> bool:
	var item := best_hero_item(slot)
	return item != null and move_item(item, PLACE_LOOT)


func get_equipped_item(slot: String) -> CraftedItem:
	return best_hero_item(slot)

# ═══════════════════════════════════════════════════════════════════
#  PERSISTENCIA
# ═══════════════════════════════════════════════════════════════════

func to_save_data() -> Dictionary:
	var mats := {}
	for mat_id in inventory:
		mats[String(mat_id)] = inventory[mat_id]
	# El botín primero y en su orden (lo más nuevo delante); después la rejilla de Tico y la mochila
	var ordered: Array[CraftedItem] = []
	ordered.append_array(loot)
	ordered.append_array(hero_grid.items)
	ordered.append_array(bag_grid.items)
	var items_arr: Array = []
	for item in ordered:
		items_arr.append(item.to_dict())
	return {
		"materials": mats,
		"crafted_items": items_arr,
		"hero_grid": [hero_grid.size.x, hero_grid.size.y],
		"expansions": expansions.map(func(id): return String(id)),
	}


## Carga el inventario. `record` es la sala máxima alcanzada de la misma partida
## (GameManager.best_enemy_level). En una partida anterior a la rejilla (sin "hero_grid"), la migra:
## da forjadas las ampliaciones de los jefes vencidos, sortea las aristas de cada pieza con una semilla
## fija, coloca lo que estaba equipado con GearPacker (las mejores primero) y manda el resto al botín.
## Nunca se pierde una pieza: una posición guardada imposible también acaba en el botín.
func load_save_data(data: Dictionary, record: int = 1) -> void:
	inventory.clear()
	crafted_items.clear()
	loot.clear()
	expansions.clear()
	var mats: Dictionary = data.get("materials", {})
	for mat_id_str in mats:
		inventory[StringName(mat_id_str)] = int(mats[mat_id_str])
	var migrating := not data.has("hero_grid")
	if migrating:
		expansions.assign(GridExpansions.unlocked_for_record(record))
	else:
		for id in data.get("expansions", []):
			if GridExpansions.is_expansion(StringName(id)) and not (StringName(id) in expansions):
				expansions.append(StringName(id))
	hero_grid = GearGrid.new(GridExpansions.size_after(expansions.size()))
	bag_grid = GearGrid.new(BAG_SIZE)
	var was_equipped := {}  # posiciones de la lista equipadas en las versiones 1 y 2
	var slots: Dictionary = data.get("equipped_slots", {})
	for slot in slots:
		was_equipped[int(slots[slot])] = true
	var to_pack: Array = []
	var to_loot: Array = []
	var dm := get_node_or_null("/root/DataManager")
	var items_arr: Array = data.get("crafted_items", [])
	for i in items_arr.size():
		var item_data = items_arr[i]
		if not item_data is Dictionary:
			continue
		var item_id := StringName(item_data.get("item_id", ""))
		var item_res: ItemResource = null
		if item_id != StringName() and dm and dm.has_method("get_item_resource"):
			item_res = dm.get_item_resource(item_id)
		if item_res == null:
			push_warning("InventoryManager: No se pudo resolver ItemResource '%s' — pieza omitida" % item_id)
			continue
		var crafted := CraftedItem.from_dict(item_data, item_res)
		crafted_items.append(crafted)
		if migrating:
			var rng := RandomNumberGenerator.new()
			rng.seed = hash([int(item_data.get("timestamp", 0)), i])
			crafted.aristas = PieceShape.roll_aristas(item_res, crafted.get_quality_tier(), rng)
			if was_equipped.has(i) or bool(item_data.get("equipped", false)):
				to_pack.append(crafted)
			else:
				to_loot.append(crafted)
		elif crafted.place == PLACE_LOOT or not _try_put(crafted, crafted.place, crafted.cell, crafted.rot):
			_put_in_loot(crafted, loot.size())
	if migrating:
		to_pack.sort_custom(func(a, b): return gear_score(a) > gear_score(b))
		for item in to_pack:
			var spot := GearPacker.find_spot(hero_grid, item)
			if spot.is_empty() or not _try_put(item, PLACE_HERO, spot.cell, spot.rot):
				to_loot.append(item)
		to_loot.sort_custom(func(a, b): return gear_score(a) > gear_score(b))
		for item in to_loot:
			_put_in_loot(item, loot.size())
	print("InventoryManager: %d materiales, %d piezas (Tico %d, mochila %d, botín %d)%s" % [inventory.size(), crafted_items.size(), hero_grid.items.size(), bag_grid.items.size(), loot.size(), " — partida migrada" if migrating else ""])
	emit_signal("inventory_changed", inventory.duplicate())
	grid_resized.emit(hero_grid.size)
	_changed(true)
```

- [ ] **Step 5: Aristas al forjar (`CraftingManager.gd`)**

Variable, junto a las demás:

```gdscript
var rng := RandomNumberGenerator.new()  ## sorteo de aristas al forjar (las pruebas pueden sembrarlo)
```

En `_ready()`, `rng.randomize()`. En `_finalize_task`, después de `crafted_item = CraftedItem.new(item_res, quality_normalized)` y antes de `inv.add_crafted_item(crafted_item)`:

```gdscript
				# Aristas según la calidad (spec del inventario en rejilla, apartado 2.3)
				crafted_item.aristas = PieceShape.roll_aristas(item_res, crafted_item.get_quality_tier(), rng)
```

- [ ] **Step 6: `Hero.gd`: la mejor pieza de cada tipo y las habilidades**

Si la franja con pegatinas está integrada (tarea 0), la lectura del equipo para el dibujo vive en `read_equipped_gear()`, que hoy lee `equipped_items`. En ese caso, esa función devuelve, con su misma forma, la mejor pieza de cada tipo (`inv_manager.best_hero_item(slot)`) y `refresh_gear()` se queda como esté. Si no está integrada, sustituye `refresh_gear()`:

```gdscript
## Lee la rejilla de Tico y elige el sprite: la mejor pieza de cada tipo (InventoryManager.best_hero_item).
func refresh_gear() -> void:
	gear.clear()
	var inv_manager = get_node_or_null("/root/InventoryManager")
	if inv_manager != null and inv_manager.has_method("best_hero_item"):
		for slot in ["main_hand", "off_hand", "head", "feet"]:
			var item = inv_manager.best_hero_item(slot)
			if item == null:
				continue
			var rarity := "basic"
			if item.item_resource:
				rarity = String(item.item_resource.rarity)
			gear[slot] = {"tier": item.get_quality_tier(), "rarity": rarity}
	_apply_sprite()
```

En `reset_stats()`, sustituye la línea `var s := CombatMath.hero_stats(equipment_stats)` por:

```gdscript
	var powers: Array = []
	if inv_manager and inv_manager.has_method("active_legendary_powers"):
		powers = inv_manager.active_legendary_powers()
	var s := CombatMath.hero_stats_with_powers(equipment_stats, powers)
```

(Si `hero_stats_with_powers` recibe el rango del equipo, tarea 4, añade `inv_manager.equipment_rank()` como último argumento.)

La función de los rangos que da el rango del equipo (tarea 0) pasa a devolver `InventoryManager.equipment_rank()`: con la rejilla ya no hay huecos. Si esa función vivía en `InventoryManager` con otro nombre, deja la suya llamando a `equipment_rank()` para no romper a quien la use.

- [ ] **Step 7: Pruebas que dependían del modelo viejo**

`RankTests.test_hero_and_enemy_nodes_use_the_shared_formulas` compara con `CombatMath.hero_stats(...)`. Con una legendaria en la partida del usuario fallaría. Pasa a:

```gdscript
	var expected := CombatMath.hero_stats_with_powers(inv.calculate_total_stats(), inv.active_legendary_powers())
```

`GameplayTests.test_equipping_keeps_the_health_ratio_and_respawn_heals` usaba `equip_item` y `unequip_item` con la partida del usuario. Sustitúyela por esta, que vacía el inventario y lo restaura:

```gdscript
func test_equipping_keeps_the_health_ratio_and_respawn_heals() -> void:
	var gm := _gm()
	var im := _im()
	var hero := _new_hero()
	var prev_hero: Node = gm.get_hero()
	gm.register_hero(hero)  # GameManager recalcula sus stats en cada cambio de equipo
	var saved: Dictionary = im.to_save_data()
	im.clear()
	var boots := CraftedItem.new(load("res://data/items/boots_master.tres"), 1.0)
	im.add_crafted_item(boots)
	hero.hp = roundi(hero.max_hp * 0.5)
	var max_before: int = hero.max_hp
	im.move_item(boots, &"hero", Vector2i(0, 0), 0)
	check(hero.max_hp > max_before, "las botas suben la vida máxima (%d → %d)" % [max_before, hero.max_hp])
	check(absi(hero.hp - roundi(hero.max_hp * 0.5)) <= 1, "colocarlas no cura: conserva la mitad de la vida (%d/%d)" % [hero.hp, hero.max_hp])
	im.move_item(boots, &"loot")
	check(hero.max_hp == max_before and absi(hero.hp - roundi(max_before * 0.5)) <= 1, "quitárselas tampoco (%d/%d)" % [hero.hp, hero.max_hp])
	hero.take_damage(hero.hp * 10, true)
	im.move_item(boots, &"hero", Vector2i(0, 0), 0)
	check(not hero.alive and hero.hp == 0, "colocar con Tico caído no le da vida (%d)" % hero.hp)
	hero.respawn()
	check(hero.alive and hero.hp == hero.max_hp, "reaparecer sí cura del todo (%d/%d)" % [hero.hp, hero.max_hp])
	im.load_save_data(saved, int(gm.best_enemy_level))
	gm.register_hero(prev_hero)
	hero.free()
	await _flush_deferred_saves()  # cada cambio de equipo guarda la partida
```

- [ ] **Step 8: Textos de las recetas**

En `TextTests._code_table_texts()`, antes del `return out`:

```gdscript
	for id in GridExpansions.RECIPES:
		out.append([String(GridExpansions.RECIPES[id].name), "GridExpansions.RECIPES"])
```

Filas en `locale/textos.csv`:

```
Correas de hueso,Correas de hueso,Bone Straps
Bolsas de musgo,Bolsas de musgo,Moss Pouches
Hebillas de obsidiana,Hebillas de obsidiana,Obsidian Buckles
Arnés de escarcha,Arnés de escarcha,Frost Harness
```

Run: `--import`

- [ ] **Step 9: Ejecutar y ver que pasa**

Run: la batería. Expected: 0 fallos. El panel de Equipo viejo sigue funcionando con las funciones de compatibilidad.

Run también un arranque real. Antes, copia `save.json` (Global Constraints):

```bash
timeout 120 D:/Software/Godot/godot_ver4.5.exe --headless --path . --quit-after 600 res://scenes/Main.tscn 2>&1 | grep -iE "SCRIPT ERROR|Parse Error|InventoryManager:"
```

Expected: sin errores. La línea de `InventoryManager:` dice "partida migrada" y ninguna pieza se ha perdido: el total de piezas es el que había. Restaura `save.json`.

- [ ] **Step 10: Commit**

```bash
git add scripts/core/GridExpansions.gd scripts/core/GridExpansions.gd.uid scripts/autoload/InventoryManager.gd scripts/data/CraftedItem.gd scripts/ui/ShopPanel.gd scripts/autoload/CraftingManager.gd scripts/gameplay/Hero.gd scripts/tests/InventoryGridTests.gd scripts/tests/GameplayTests.gd scripts/tests/RankTests.gd scripts/tests/TextTests.gd locale/textos.csv
git commit -m "feat: inventario con rejilla de Tico, mochila y botín; aristas al forjar y migración de partidas"
```

---

### Task 7: Guardado versión 2

**Files:**
- Modify: `scripts/core/SaveManager.gd`
- Test: `scripts/tests/InventoryGridTests.gd`

**Interfaces:**
- Consumes: `InventoryManager.load_save_data(data, record)`, `InventoryManager.to_save_data()`
- Produces: `SaveManager.SAVE_VERSION` = 2 (los rangos usarán la 3). `SaveManager.load_game()` pasa el récord de la partida (`game.best_enemy_level`) al inventario.

- [ ] **Step 1: Pruebas que fallan**

```gdscript
# ─── Tarea 7: guardado versión 2 y migración ───────────────────────────

## Partida de la versión 1 (antes de la rejilla): 4 piezas equipadas y 40 sueltas, con récord 35.
func _v1_save() -> Dictionary:
	var items := []
	var equipped := {"main_hand": 0, "off_hand": 1, "head": 2, "feet": 3}
	var gear := [[&"sword_masterwork", 0.93], [&"shield_master", 0.5], [&"helmet_advanced", 0.6], [&"boots_master", 0.3]]
	for i in 44:
		var id: StringName = gear[i][0] if i < 4 else ITEM_IDS[i % ITEM_IDS.size()]
		var q: float = gear[i][1] if i < 4 else 0.2 + 0.018 * i
		var d := CraftedItem.new(_res(id), q).to_dict()
		for k in ["rank", "place", "x", "y", "rot", "aristas"]:
			d.erase(k)
		d["equipped"] = i < 4
		d["timestamp"] = 1000 + i
		items.append(d)
	return {
		"version": 1,
		"timestamp": 1790000000.0,
		"game": {"current_enemy_level": 7, "best_enemy_level": 35, "death_count": 2, "enemies_defeated": {}, "hero_loadout": {}},
		"data": {"unlocked_blueprints": {}},
		"inventory": {"materials": {"iron": 50, "gold": 300}, "crafted_items": items, "equipped_slots": equipped},
		"requests": {"free_requests_remaining": 0},
	}


func _load_save_dict(data: Dictionary) -> bool:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
	return SaveManager.load_game()


## Vuelve a cargar la partida de antes de la prueba (TestSuite solo restaura el fichero al terminar).
func _reload_user_save() -> void:
	if _had_save:
		var back := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		back.store_buffer(_save_backup)
		back.close()
		SaveManager.load_game()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	await get_tree().process_frame


func test_v1_save_migrates_without_losing_pieces() -> void:
	var im := _im()
	check(_load_save_dict(_v1_save()), "la partida de la versión 1 carga")
	check(im.get_crafted_items().size() == 44, "ninguna pieza perdida (%d de 44)" % im.get_crafted_items().size())
	check(im.hero_grid_size() == Vector2i(6, 5) and im.expansions.size() == 3, "récord 35: jefes 10, 20 y 30 vencidos, 3 ampliaciones y rejilla de 6×5 (%s)" % im.hero_grid_size())
	var hero_ids: Array = im.get_hero_items().map(func(it): return it.item_resource.item_id)
	check(&"sword_masterwork" in hero_ids and &"shield_master" in hero_ids, "lo que estaba equipado entra en la rejilla, las mejores primero (%s)" % [hero_ids])
	check(im.get_hero_items().size() + im.get_loot().size() == 44 and im.get_bag_items().is_empty(), "lo demás, al botín")
	var first: CraftedItem = im.get_loot()[0]
	check(im.get_loot().all(func(it): return InventoryManager.gear_score(it) <= InventoryManager.gear_score(first)), "el botín empieza por la mejor pieza")
	var aristas_a: Array = im.get_crafted_items().map(func(it): return it.aristas)
	check(_load_save_dict(_v1_save()), "se vuelve a cargar la misma partida")
	var aristas_b: Array = im.get_crafted_items().map(func(it): return it.aristas)
	check(aristas_a == aristas_b, "las aristas migradas salen siempre iguales")
	check(SaveManager.save_game(), "se guarda en la versión nueva")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	check(int(data.version) == 2 and data.inventory.has("hero_grid") and not data.inventory.has("equipped_slots"), "guardado versión 2, sin huecos fijos")
	await _reload_user_save()


func test_v2_save_round_trip() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var a := _piece(&"shield_master", 0.5, [Vector2i(2, 1)])
	var b := _piece(&"boots_advanced", 0.7)
	var c := _piece(&"sword_basic", 0.3)
	for p in [a, b, c]:
		im.add_crafted_item(p)
	im.move_item(a, &"hero", Vector2i(0, 0), 0)
	im.move_item(b, &"bag", Vector2i(2, 1), 3)
	var data: Dictionary = im.to_save_data()
	im.load_save_data(data, 1)
	var by_id := {}
	for it in im.get_crafted_items():
		by_id[it.item_resource.item_id] = it
	check(by_id[&"shield_master"].place == &"hero" and by_id[&"shield_master"].aristas == [Vector2i(2, 1)], "el escudo vuelve a Tico con su arista")
	check(by_id[&"boots_advanced"].place == &"bag" and by_id[&"boots_advanced"].cell == Vector2i(2, 1) and by_id[&"boots_advanced"].rot == 3, "las botas vuelven a su casilla y giro de la mochila")
	check(by_id[&"sword_basic"].place == &"loot", "la espada sigue en el botín")
	await _restore_inventory(saved)


func test_impossible_saved_position_goes_to_loot() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var a := _piece(&"shield_master")
	var b := _piece(&"helmet_basic")
	im.add_crafted_item(a)
	im.add_crafted_item(b)
	im.move_item(a, &"hero", Vector2i(0, 0), 0)
	im.move_item(b, &"bag", Vector2i(5, 3), 0)
	var data: Dictionary = im.to_save_data()
	for d in data.crafted_items:
		if d.item_id == "shield_master":
			d.x = 3  # un escudo de 2×3 desde la columna 3 de una rejilla de 4×4 se sale
	im.load_save_data(data, 1)
	var by_id := {}
	for it in im.get_crafted_items():
		by_id[it.item_resource.item_id] = it
	check(by_id.size() == 2, "las dos piezas siguen ahí")
	check(by_id[&"shield_master"].place == &"loot", "el escudo con una posición imposible pasa al botín")
	check(by_id[&"helmet_basic"].place == &"bag" and by_id[&"helmet_basic"].cell == Vector2i(5, 3), "el casco sigue en su sitio de la mochila")
	await _restore_inventory(saved)
```

Run InventoryGridTests. Expected: falla `test_v1_save_migrates_without_losing_pieces`: el récord no llega al inventario, así que la rejilla sale de 4×4, y la versión guardada es 1.

- [ ] **Step 2: `SaveManager.gd`**

```gdscript
const SAVE_VERSION := 2
```

En `load_game()`, la carga del inventario pasa el récord de la misma partida (el inventario se carga antes que `GameManager`):

```gdscript
	# InventoryManager (materiales y piezas). Con una partida anterior a la rejilla, el récord decide las
	# ampliaciones que ya tenía ganadas (spec del inventario en rejilla, apartado 10)
	if im and im.has_method("load_save_data") and save_data.has("inventory"):
		var record := int(save_data.get("game", {}).get("best_enemy_level", 1))
		im.load_save_data(save_data["inventory"], record)
```

(Si la tarjeta de guardado robusto ya cambió `SaveManager`, aplica estos cambios sobre su versión.)

- [ ] **Step 3: Ejecutar y ver que pasa**

Run: la batería. Expected: 0 fallos.

- [ ] **Step 4: Commit**

```bash
git add scripts/core/SaveManager.gd scripts/tests/InventoryGridTests.gd
git commit -m "feat: guardado versión 2 con la rejilla; la migración usa el récord de la partida"
```

---

### Task 8: Vistas de la rejilla y del botín (`GearGridView`, `LootStripView`)

**Files:**
- Create: `scripts/ui/GearGridView.gd`, `scripts/ui/LootStripView.gd`
- Test: `scripts/tests/InventoryGridTests.gd`

**Interfaces:**
- Consumes: `GearGrid`, `PieceShape.of_item`, `GearAuras.kind`, `CraftedItem.get_quality_color()`
- Produces:
  - `GearGridView` (`Control`):
    - constantes: `CELL` (110.0) y los colores `COLOR_OK`, `COLOR_BAD`, `COLOR_GAIN`, `COLOR_LOSS` y `COLOR_SWAP`;
    - estado de dibujo: `grid`, `max_size`, `hidden_item`, `drop_cells`, `swap_item`, `glow` y `sprite_for: Callable`;
    - funciones:
      - `setup(g: GearGrid, max_cells: Vector2i)`;
      - `cell_at(local: Vector2) -> Vector2i` y `cell_rect(c: Vector2i) -> Rect2`;
      - `item_at_local(local: Vector2) -> CraftedItem` e `item_origin(item) -> Vector2`;
      - `start_shake(item)`;
      - `static draw_piece_at(canvas: CanvasItem, item, top_left: Vector2, rot: int, cell_px: float, alpha: float, sprite_fn: Callable = Callable())`;
  - `LootStripView` (`Control`):
    - estado: `items`, `scroll`, `hidden_item` y `sprite_for`;
    - `set_items(list: Array)`;
    - `static flat_rot(item) -> int`;
    - `slot_at_local(local: Vector2) -> Dictionary` (`item`, `rot`, `rect`);
    - `content_width() -> float` y `max_scroll() -> float`.
- Las vistas no guardan estado de juego ni leen el dedo: `mouse_filter = IGNORE`, y el panel (tarea 9) decide.
- Sin `sprite_for` dibujan las piezas con casillas de color: coral las armas, verde las armaduras, con el borde del color de la calidad y las aristas en gris. Así se quedan hasta que llegue el arte (aplazado al final).

- [ ] **Step 1: Pruebas que fallan**

```gdscript
# ─── Tarea 8: vistas de rejilla y botín ────────────────────────────────

func test_grid_view_maps_points_to_cells_and_pieces() -> void:
	var g := GearGrid.new(Vector2i(4, 4))
	var sword := _piece(&"sword_advanced")
	g.place(sword, Vector2i(2, 1), 0)
	var view := GearGridView.new()
	add_child(view)
	view.setup(g, Vector2i(6, 6))
	check(view.size == Vector2(660, 660), "la rejilla dibuja 6×6 casillas de 110 px (%s)" % view.size)
	check(view.cell_at(Vector2(230, 120)) == Vector2i(2, 1), "un punto cae en su casilla")
	check(view.item_at_local(Vector2(240, 350)) == sword and view.item_at_local(Vector2(10, 10)) == null, "encuentra la pieza bajo el dedo")
	check(view.item_origin(sword) == Vector2(220, 110), "esquina de la pieza en píxeles")
	view.queue_free()


func test_loot_strip_lays_pieces_flat_and_scrolls() -> void:
	var tall := _piece(&"sword_masterwork")  # 1×4: tumbada ocupa 4×1
	var strip := LootStripView.new()
	strip.size = Vector2(960, 330)
	add_child(strip)
	var list := [tall]
	for i in 5:
		list.append(_piece(&"shield_master"))
	strip.set_items(list)
	check(LootStripView.flat_rot(tall) == 1, "la espada se enseña tumbada")
	var first: Dictionary = strip.slot_at_local(Vector2(40, 165))
	check(first.get("item") == tall and first.get("rot") == 1, "la primera pieza, a la izquierda")
	check(strip.max_scroll() > 0.0, "si no cabe todo, se desplaza (%.0f)" % strip.max_scroll())
	strip.scroll = strip.max_scroll()
	check(strip.slot_at_local(Vector2(900, 165)).get("item") == list.back(), "desplazada, la última queda a la derecha")
	strip.queue_free()
```

Run InventoryGridTests. Expected: error de análisis (`GearGridView` no existe).

- [ ] **Step 2: `scripts/ui/GearGridView.gd`**

```gdscript
class_name GearGridView
extends Control

## Una rejilla de equipo dibujada por sí misma (spec doc/specs/2026-09-27-inventario-en-rejilla.md,
## apartado 9): la de Tico o la mochila. Solo dibuja la GearGrid que le da el panel de Equipo; el dedo
## lo lleva el panel. Las casillas que aún no existen (ampliaciones pendientes) se dibujan punteadas.

const CELL := 110.0  ## 22 píxeles de arte a ×5, el tamaño de píxel de la franja
const COLOR_CELL := Color(0.16, 0.11, 0.09, 0.8)
const COLOR_LINE := Color(0.45, 0.33, 0.21, 0.9)
const COLOR_LOCKED := Color(0.6, 0.5, 0.38, 0.55)
const COLOR_WEAPON := Color("d85a30")
const COLOR_ARMOR := Color("1d9e75")
const COLOR_ARISTA := Color(0.62, 0.6, 0.58, 0.9)
const COLOR_OK := Color(0.45, 0.95, 0.5, 0.45)
const COLOR_BAD := Color(1.0, 0.35, 0.3, 0.45)
const COLOR_SWAP := Color("ffd76a")
const COLOR_GAIN := Color(0.45, 0.95, 0.5, 0.9)
const COLOR_LOSS := Color(1.0, 0.4, 0.35, 0.9)
const COLOR_ZONE := Color(1.0, 0.84, 0.42, 0.22)
const ZONE_BAND := 10.0  ## ancho de la franja que marca una zona, en píxeles de pantalla

var grid: GearGrid
var show_zones := false  ## la rejilla de Tico marca las zonas de GearAuras.ZONES; la mochila, no
var max_size := Vector2i(6, 6)  ## casillas que se dibujan; las que aún no existen, punteadas
var hidden_item: CraftedItem = null  ## la pieza que se arrastra no se dibuja en su sitio
var drop_cells: Dictionary = {}  ## casilla → color del destino del arrastre
var swap_item: CraftedItem = null  ## pieza con la que se intercambiaría (contorno amarillo)
var glow: Dictionary = {}  ## pieza → color: gana (verde) o pierde (rojo) aumento con el arrastre
var sprite_for: Callable = Callable()  ## (pieza, giro) → Texture2D; sin él, casillas de color
var _shake_item: CraftedItem = null
var _shake := 0.0


func setup(g: GearGrid, max_cells: Vector2i) -> void:
	grid = g
	max_size = max_cells
	custom_minimum_size = Vector2(max_cells) * CELL
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # el panel lleva el dedo
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	queue_redraw()


func _process(delta: float) -> void:
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta)
		queue_redraw()


func cell_at(local: Vector2) -> Vector2i:
	return Vector2i(floori(local.x / CELL), floori(local.y / CELL))


func cell_rect(c: Vector2i) -> Rect2:
	return Rect2(Vector2(c) * CELL, Vector2(CELL, CELL))


## Pieza bajo un punto (coordenadas locales), por sus casillas limpias o sus aristas; null si no hay.
func item_at_local(local: Vector2) -> CraftedItem:
	if grid == null:
		return null
	return grid.item_at(cell_at(local))


## Esquina de la caja de una pieza colocada, en coordenadas locales.
func item_origin(item: CraftedItem) -> Vector2:
	return Vector2(grid.cell_of(item)) * CELL


## La pieza tiembla un momento (no cabe girada).
func start_shake(item: CraftedItem) -> void:
	_shake_item = item
	_shake = 0.3


func _draw() -> void:
	if grid == null:
		return
	for y in max_size.y:
		for x in max_size.x:
			var c := Vector2i(x, y)
			var r := cell_rect(c).grow(-1.0)
			if grid.in_bounds(c):
				draw_rect(r, COLOR_CELL)
				draw_rect(r, COLOR_LINE, false, 2.0)
			else:
				_draw_dashed(r.grow(-6.0), COLOR_LOCKED)
	if show_zones:
		for slot in GearAuras.ZONES:
			_draw_zone(slot, GearAuras.ZONES[slot])
	for item in grid.items:
		if item == hidden_item:
			continue
		var offset := Vector2.ZERO
		if item == _shake_item and _shake > 0.0:
			offset.x = sin(_shake * 60.0) * 6.0
		draw_piece_at(self, item, item_origin(item) + offset, grid.rot_of(item), CELL, 1.0, sprite_for)
		if glow.has(item):
			_outline(item, glow[item])
	if swap_item and grid.has(swap_item):
		_outline(swap_item, COLOR_SWAP)
	for c in drop_cells:
		draw_rect(cell_rect(c).grow(-3.0), drop_cells[c])


## Dibuja una pieza con la esquina de su caja en `top_left` y casillas de `cell_px`. Lo usan la rejilla,
## el botín y la pieza que se arrastra. Con `sprite_fn` válido pinta su textura (cuando haya arte); si no, casillas de color.
static func draw_piece_at(canvas: CanvasItem, item: CraftedItem, top_left: Vector2, rot: int, cell_px: float, alpha: float, sprite_fn: Callable = Callable()) -> void:
	var fp := PieceShape.of_item(item, rot)
	if sprite_fn.is_valid():
		var tex: Texture2D = sprite_fn.call(item, rot)
		if tex:
			canvas.draw_texture_rect(tex, Rect2(top_left, Vector2(fp.size) * cell_px), false, Color(1, 1, 1, alpha))
			return
	var base := COLOR_WEAPON if GearAuras.kind(item) == &"weapon" else COLOR_ARMOR
	var edge := item.get_quality_color()
	for c in fp.clean:
		var r := Rect2(top_left + Vector2(c) * cell_px, Vector2(cell_px, cell_px)).grow(-4.0)
		canvas.draw_rect(r, Color(base, alpha))
		canvas.draw_rect(r, Color(edge, alpha), false, 4.0)
	for c in fp.aristas:
		var r := Rect2(top_left + Vector2(c) * cell_px, Vector2(cell_px, cell_px)).grow(-cell_px * 0.18)
		canvas.draw_rect(r, Color(COLOR_ARISTA, alpha * 0.85))


## Zona de un tipo de pieza: una franja tenue por dentro de su borde de la rejilla (que sigue al borde al
## ampliarla). Las piezas se dibujan encima.
func _draw_zone(_slot: String, zone: StringName) -> void:
	var w := float(grid.size.x) * CELL
	var h := float(grid.size.y) * CELL
	var r: Rect2
	match zone:
		&"top":
			r = Rect2(0.0, 0.0, w, ZONE_BAND)
		&"bottom":
			r = Rect2(0.0, h - ZONE_BAND, w, ZONE_BAND)
		&"left":
			r = Rect2(0.0, 0.0, ZONE_BAND, h)
		&"right":
			r = Rect2(w - ZONE_BAND, 0.0, ZONE_BAND, h)
		_:
			return
	draw_rect(r, COLOR_ZONE)


func _outline(item: CraftedItem, color: Color) -> void:
	for c in grid.placed_clean_cells(item):
		draw_rect(cell_rect(c).grow(-2.0), color, false, 5.0)


func _draw_dashed(r: Rect2, color: Color) -> void:
	var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for i in 4:
		draw_dashed_line(corners[i], corners[(i + 1) % 4], color, 2.0, 8.0)
```

- [ ] **Step 3: `scripts/ui/LootStripView.gd`**

```gdscript
class_name LootStripView
extends Control

## El botín en una tira con desplazamiento lateral (spec del inventario en rejilla, apartado 9.1): las
## piezas a tamaño real, tumbadas (con el giro que las deja más bajas) y lo más nuevo a la izquierda.
## Mide 3 casillas de alto: ninguna pieza tumbada, aristas incluidas, pasa de 3. El dedo lo lleva el panel.

const CELL := GearGridView.CELL
const PAD := 20.0
const COLOR_BG := Color(0.12, 0.08, 0.07, 0.85)

var items: Array[CraftedItem] = []
var scroll := 0.0
var hidden_item: CraftedItem = null  ## la pieza que se arrastra no se dibuja
var sprite_for: Callable = Callable()
var _slots: Array = []  # [{"item", "rot", "rect"}], rect en coordenadas sin desplazar


func set_items(list: Array) -> void:
	items.assign(list)
	_layout()
	queue_redraw()


## Giro con el que se enseña una pieza en la tira: el que la deja más baja (el primero si empatan).
static func flat_rot(item: CraftedItem) -> int:
	var best := 0
	var best_h := 999
	for r in 4:
		var h: int = PieceShape.of_item(item, r).size.y
		if h < best_h:
			best_h = h
			best = r
	return best


func _layout() -> void:
	_slots.clear()
	var x := PAD
	for item in items:
		var rot := flat_rot(item)
		var box: Vector2 = Vector2(PieceShape.of_item(item, rot).size) * CELL
		_slots.append({"item": item, "rot": rot, "rect": Rect2(Vector2(x, (size.y - box.y) * 0.5), box)})
		x += box.x + PAD
	scroll = clampf(scroll, 0.0, max_scroll())


func content_width() -> float:
	if _slots.is_empty():
		return 0.0
	var last: Rect2 = _slots.back().rect
	return last.end.x + PAD


func max_scroll() -> float:
	return maxf(0.0, content_width() - size.x)


## Pieza bajo un punto (coordenadas locales): {"item", "rot", "rect"}, o {} si no hay.
func slot_at_local(local: Vector2) -> Dictionary:
	var p := local + Vector2(scroll, 0.0)
	for s in _slots:
		if s.rect.has_point(p):
			return s
	return {}


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_BG)
	for s in _slots:
		if s.item == hidden_item:
			continue
		var top_left: Vector2 = s.rect.position - Vector2(scroll, 0.0)
		if top_left.x > size.x or top_left.x + s.rect.size.x < 0.0:
			continue
		GearGridView.draw_piece_at(self, s.item, top_left, s.rot, CELL, 1.0, sprite_for)
```

- [ ] **Step 4: Ejecutar y ver que pasa**

Run: `--import` y después InventoryGridTests. Expected: 0 fallos.

- [ ] **Step 5: Commit**

```bash
git add scripts/ui/GearGridView.gd scripts/ui/GearGridView.gd.uid scripts/ui/LootStripView.gd scripts/ui/LootStripView.gd.uid scripts/tests/InventoryGridTests.gd
git commit -m "feat: vistas de la rejilla y del botín (GearGridView, LootStripView)"
```

---

### Task 9: Panel de Equipo nuevo: tocar, arrastrar, girar e intercambiar

**Files:**
- Rewrite: `scenes/UI/EquipmentPanel.tscn`, `scripts/ui/EquipmentPanel.gd`
- Modify: `scripts/tests/TextTests.gd` (tablas del panel viejo fuera), `locale/textos.csv`
- Test: `scripts/tests/InventoryGridTests.gd`

**Interfaces:**
- Consumes:
  - de `InventoryManager`: `hero_grid`, `bag_grid`, `get_loot()`, `get_loot_count()`, `grid_for`, `drop_result`, `move_item`, `rotate_in_place`, `simulate_hero_grid`, `hero_bonuses()`, `active_legendary_powers()`, `expansions`, `calculate_total_stats()` y sus señales;
  - `GearGridView`, `LootStripView`, `GearAuras`, `LegendaryPowers`, `CombatMath.hero_stats_with_powers` y `CombatMath.armor_mitigation`.
- Produces (usado por las pruebas y por la tarea 10):
  - `open()`, `close()` y la señal `panel_closed`, como antes;
  - vistas: `_hero_view`, `_bag_view` y `_loot_view`;
  - estado del dedo: `_press`, `_dragging`, `_target`, `_drag_rot` y `_selected`;
  - funciones del dedo: `_on_press(pos)`, `_on_motion(pos)`, `_on_release(pos)` y `_rotate_drag()`.
- **La escena conserva su uid** (`uid://28clsjg2fun`): `HUD_Main.tscn` la instancia por él.

- [ ] **Step 1: Pruebas que fallan**

```gdscript
# ─── Tarea 9: panel de Equipo: tocar, arrastrar y soltar ───────────────

func _new_panel() -> Control:
	var panel: Control = load("res://scenes/UI/EquipmentPanel.tscn").instantiate()
	add_child(panel)
	panel.open()
	return panel


## Eventos de ratón en coordenadas del lienzo (1080×1920), directos al panel.
func _mouse(panel: Control, pos: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = pos
	panel._input(e)


func _move(panel: Control, pos: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = pos
	panel._input(e)


func _cell_center(view: Control, cell: Vector2i) -> Vector2:
	return view.global_position + (Vector2(cell) + Vector2(0.5, 0.5)) * GearGridView.CELL


## Dónde poner el dedo para que la pieza cogida caiga con su caja en `cell` de `view` (va una casilla
## por encima del dedo).
func _finger_for(panel: Control, view: Control, cell: Vector2i) -> Vector2:
	var grab: Vector2 = panel._press.origin - panel._press.pos
	return view.global_position + Vector2(cell) * GearGridView.CELL - grab + Vector2(0, GearGridView.CELL)


func test_tap_rotates_a_piece_in_the_grid() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var sword := _piece(&"sword_advanced")
	im.add_crafted_item(sword)
	im.move_item(sword, &"hero", Vector2i(1, 0), 0)
	var panel := _new_panel()
	var p := _cell_center(panel._hero_view, Vector2i(1, 1))
	_mouse(panel, p, true)
	_mouse(panel, p, false)
	check(sword.rot == 1, "un toque la gira (%d)" % sword.rot)
	check(panel._selected == sword, "y la enseña en la ficha")
	panel.queue_free()
	await _restore_inventory(saved)


func test_drag_from_loot_places_and_swaps() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var old_sword := _piece(&"sword_basic", 0.5)
	var new_sword := _piece(&"sword_basic", 0.95)
	im.add_crafted_item(old_sword)
	im.move_item(old_sword, &"hero", Vector2i(3, 0), 0)  # de pie en (3,0)-(3,1)
	im.add_crafted_item(new_sword)
	var panel := _new_panel()
	var start: Vector2 = panel._loot_view.global_position + Vector2(40, 165)
	_mouse(panel, start, true)
	check(panel._press.get("item") == new_sword and panel._press.get("rot") == 1, "se coge la espada nueva, tumbada como en el botín")
	_move(panel, start + Vector2(0, -30))  # hacia arriba: se coge (de lado se desplazaría el botín)
	check(panel._dragging, "empieza el arrastre")
	var finger := _finger_for(panel, panel._hero_view, Vector2i(2, 0))  # tumbada: (2,0)-(3,0), encima de la vieja
	_move(panel, finger)
	check(panel._target.get("ok", false) and panel._target.get("swap") == old_sword, "encima de la vieja: intercambio (%s)" % [panel._target])
	_mouse(panel, finger, false)
	check(new_sword.place == &"hero" and new_sword.cell == Vector2i(2, 0) and old_sword.place == &"loot", "la nueva en Tico y la vieja al botín")
	check(not panel._dragging and panel._press.is_empty(), "el arrastre termina")
	panel.queue_free()
	await _restore_inventory(saved)


func test_second_finger_rotates_while_dragging() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var sword := _piece(&"sword_advanced")
	im.add_crafted_item(sword)
	im.move_item(sword, &"bag", Vector2i(0, 0), 0)
	var panel := _new_panel()
	var start := _cell_center(panel._bag_view, Vector2i(0, 1))
	_mouse(panel, start, true)
	_move(panel, start + Vector2(40, 40))
	var touch := InputEventScreenTouch.new()
	touch.index = 1
	touch.pressed = true
	touch.position = Vector2(900, 1500)
	panel._input(touch)
	check(panel._drag_rot == 1, "un segundo dedo gira la pieza que se arrastra (%d)" % panel._drag_rot)
	var key := InputEventKey.new()
	key.keycode = KEY_R
	key.pressed = true
	panel._input(key)
	check(panel._drag_rot == 2, "en el ordenador, la tecla R también (%d)" % panel._drag_rot)
	_move(panel, Vector2(540, 60))  # arriba del todo, fuera de las rejillas y del botín
	_mouse(panel, Vector2(540, 60), false)  # soltada ahí vuelve a su sitio
	check(sword.place == &"bag" and sword.cell == Vector2i(0, 0) and sword.rot == 0, "soltada fuera, vuelve a su sitio sin girar")
	panel.queue_free()
	await _restore_inventory(saved)


func test_new_loot_while_dragging_is_not_lost() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var dragged := _piece(&"helmet_basic")
	im.add_crafted_item(dragged)
	var panel := _new_panel()
	var start: Vector2 = panel._loot_view.global_position + Vector2(60, 165)
	_mouse(panel, start, true)
	_move(panel, start + Vector2(0, -40))
	check(panel._dragging, "se arrastra el casco")
	var fresh := _piece(&"boots_basic")
	im.add_crafted_item(fresh)  # llega una pieza de la forja a mitad del arrastre
	check(panel._dragging and panel._press.get("item") == dragged, "el arrastre sigue con el casco")
	var finger := _finger_for(panel, panel._hero_view, Vector2i(0, 0))
	_move(panel, finger)
	_mouse(panel, finger, false)
	check(dragged.place == &"hero" and fresh.place == &"loot", "el casco en Tico y las botas nuevas en el botín")
	check(im.get_crafted_items().size() == 2, "no se pierde ninguna")
	panel.queue_free()
	await _restore_inventory(saved)


func test_loot_strip_scrolls_sideways() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	for i in 6:
		im.add_crafted_item(_piece(&"shield_master"))
	var panel := _new_panel()
	var start: Vector2 = panel._loot_view.global_position + Vector2(600, 165)
	_mouse(panel, start, true)
	_move(panel, start + Vector2(-300, 5))
	check(not panel._dragging and panel._loot_view.scroll > 250.0, "de lado se desplaza la tira, no se coge la pieza (%.0f)" % panel._loot_view.scroll)
	_mouse(panel, start + Vector2(-300, 5), false)
	panel.queue_free()
	await _restore_inventory(saved)
```

Run InventoryGridTests. Expected: fallos (la escena vieja no tiene `_hero_view`: errores de script en esas pruebas).

- [ ] **Step 2: `scenes/UI/EquipmentPanel.tscn` (sustituye el fichero entero)**

```
[gd_scene load_steps=2 format=3 uid="uid://28clsjg2fun"]

[ext_resource type="Script" path="res://scripts/ui/EquipmentPanel.gd" id="1"]

[node name="EquipmentPanel" type="ColorRect"]
visible = false
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
color = Color(0.09, 0.06, 0.05, 0.97)
script = ExtResource("1")

[node name="Title" type="Label" parent="."]
offset_left = 60.0
offset_top = 20.0
offset_right = 700.0
offset_bottom = 96.0
theme_override_font_sizes/font_size = 52
text = "Equipo"
vertical_alignment = 1

[node name="CloseBtn" type="Button" parent="."]
offset_left = 930.0
offset_top = 16.0
offset_right = 1020.0
offset_bottom = 96.0
theme_override_font_sizes/font_size = 40
text = "X"

[node name="LootTitle" type="Label" parent="."]
offset_left = 60.0
offset_top = 926.0
offset_right = 700.0
offset_bottom = 966.0
theme_override_font_sizes/font_size = 30
text = "Botín"

[node name="SellAllBtn" type="Button" parent="."]
offset_left = 760.0
offset_top = 920.0
offset_right = 1020.0
offset_bottom = 966.0
theme_override_font_sizes/font_size = 26
text = "Vender todo"

[node name="BagTitle" type="Label" parent="."]
offset_left = 60.0
offset_top = 1306.0
offset_right = 700.0
offset_bottom = 1346.0
theme_override_font_sizes/font_size = 30
text = "Mochila"

[node name="SellZone" type="Panel" parent="."]
offset_left = 760.0
offset_top = 1350.0
offset_right = 1020.0
offset_bottom = 1790.0
mouse_filter = 2

[node name="SellLabel" type="Label" parent="SellZone"]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
theme_override_font_sizes/font_size = 28
text = "Suelta aquí para vender"
horizontal_alignment = 1
vertical_alignment = 1
autowrap_mode = 3
```

El botón "Vender todo" y la zona de venta se conectan en la tarea 10.

- [ ] **Step 3: `scripts/ui/EquipmentPanel.gd` (sustituye el fichero entero)**

```gdscript
# res://scripts/ui/EquipmentPanel.gd
extends ColorRect

## Panel de Equipo a pantalla completa (spec doc/specs/2026-09-27-inventario-en-rejilla.md, apartado 9).
## De arriba abajo: estadísticas de Tico, ficha de la última pieza tocada, rejilla de Tico delante de su
## sprite (con los consumibles al lado), botín, mochila y zona de venta.
## El dedo lo lleva este panel, en _input:
##  - tocar una pieza de una rejilla la gira (si girada no cabe, tiembla); en el botín solo la enseña;
##  - mantener pulsado enseña su ficha (la completa, con botones, llega en la tarea 10);
##  - arrastrar la mueve: la pieza va una casilla por encima del dedo y un segundo dedo la gira;
##  - en el botín, de lado se desplaza la tira; hacia arriba o abajo se coge la pieza.
## En el ordenador el ratón hace lo mismo, y la rueda o la tecla R giran la pieza que se arrastra.

signal panel_closed

const HERO_SCENE := preload("res://scenes/Hero.tscn")
const CELL := GearGridView.CELL
const HERO_GRID_POS := Vector2(60, 262)
const BAG_POS := Vector2(60, 1350)
const LOOT_RECT := Rect2(60, 970, 960, 330)
const STATS_RECT := Rect2(60, 100, 960, 70)
const FICHA_RECT := Rect2(60, 174, 960, 84)
const NEXT_RECT := Rect2(760, 620, 260, 280)
const DRAG_THRESHOLD := 10.0
const LONG_PRESS_MS := 400
const COLOR_UP := "7dff8a"
const COLOR_DOWN := "ff7a6e"

@onready var close_btn: Button = $CloseBtn
@onready var sell_all_btn: Button = $SellAllBtn
@onready var sell_zone: Control = $SellZone
@onready var sell_label: Label = $SellZone/SellLabel
@onready var loot_title: Label = $LootTitle

var _im: Node
var _gm: Node
var _hero_view: GearGridView
var _bag_view: GearGridView
var _loot_view: LootStripView
var _stats_label: RichTextLabel
var _ficha_label: RichTextLabel
var _next_label: Label
var _ghost_layer: Control
var _puppet: Node2D
var _selected: CraftedItem = null

## Pulsación en curso: {"item", "from", "rot", "origin", "pos", "time", "long_done"}; {} si no hay.
## "origin" es la esquina de la caja de la pieza en la pantalla al pulsar. "item" es null si se pulsa el
## botín vacío (solo para desplazarlo).
var _press := {}
var _dragging := false
var _scrolling := false
var _scroll_start := 0.0
var _drag_rot := 0
var _drag_pos := Vector2.ZERO
## Destino del arrastre: {"place", "cell", "ok", "swap", "view"}; {} si no hay ninguno.
var _target := {}


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_im = get_node_or_null("/root/InventoryManager")
	_gm = get_node_or_null("/root/GameManager")
	close_btn.pressed.connect(close)
	_build()
	if _im:
		_im.crafted_items_changed.connect(func(_items): _refresh_if_open())
		_im.equipment_changed.connect(func(_stats): _refresh_if_open())
		_im.grid_resized.connect(func(_size): _refresh_if_open())


func _build() -> void:
	_stats_label = _rich(STATS_RECT, 30)
	_ficha_label = _rich(FICHA_RECT, 22)
	_puppet_setup()
	_hero_view = _grid_view(HERO_GRID_POS)
	_hero_view.show_zones = true  # la mochila no tiene zonas
	_bag_view = _grid_view(BAG_POS)
	_loot_view = LootStripView.new()
	_loot_view.position = LOOT_RECT.position
	_loot_view.size = LOOT_RECT.size
	_loot_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_loot_view)
	_next_label = Label.new()
	_next_label.position = NEXT_RECT.position
	_next_label.size = NEXT_RECT.size
	_next_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_next_label.add_theme_font_size_override("font_size", 24)
	_next_label.add_theme_color_override("font_color", Color(0.75, 0.66, 0.54))
	add_child(_next_label)
	_ghost_layer = Control.new()
	_ghost_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ghost_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ghost_layer.draw.connect(_draw_ghost)
	add_child(_ghost_layer)  # el último: se dibuja encima de todo


func _grid_view(pos: Vector2) -> GearGridView:
	var view := GearGridView.new()
	view.position = pos
	add_child(view)
	return view


func _rich(rect: Rect2, font_size: int) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.position = rect.position
	label.size = rect.size
	label.bbcode_enabled = true
	label.scroll_active = false
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("normal_font_size", font_size)
	add_child(label)
	return label


## Tico a gran tamaño y tenue detrás de su rejilla (el mismo dibujo que en la mazmorra; con la franja de
## pegatinas integrada, ver la nota después de este bloque).
func _puppet_setup() -> void:
	_puppet = HERO_SCENE.instantiate()
	_puppet.remove_from_group("hero")  # que no lo confundan con el héroe de la partida
	_puppet.set("show_hud", false)
	_puppet.scale = Vector2(18, 18)  # 32 px de arte a ×18: casi el alto de la rejilla
	_puppet.position = HERO_GRID_POS + Vector2(330, 640)  # pies al fondo de la rejilla, centrado
	_puppet.modulate = Color(1, 1, 1, 0.35)
	_puppet.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_puppet)
	_puppet.process_mode = Node.PROCESS_MODE_DISABLED  # solo se anima con el panel abierto


func open() -> void:
	visible = true
	_refresh()
	if _puppet:
		_puppet.process_mode = Node.PROCESS_MODE_INHERIT
		_puppet.respawn(_puppet.position)


func close() -> void:
	_cancel_press()
	visible = false
	if _puppet:
		_puppet.process_mode = Node.PROCESS_MODE_DISABLED
	emit_signal("panel_closed")

# ═══════════════════════════════════════════════════════════════════
#  REFRESCO
# ═══════════════════════════════════════════════════════════════════

func _refresh_if_open() -> void:
	if visible:
		_refresh()


func _refresh() -> void:
	if _im == null or not is_node_ready():
		return
	_hero_view.setup(_im.hero_grid, GridExpansions.MAX_SIZE)
	_bag_view.setup(_im.bag_grid, InventoryManager.BAG_SIZE)
	_loot_view.set_items(_im.get_loot())
	loot_title.text = tr("Botín · %d") % _im.get_loot_count()
	if _selected and not (_selected in _im.get_crafted_items()):
		_selected = null
	_refresh_stats({})
	_refresh_ficha()
	_refresh_next()
	if _puppet and _puppet.has_method("refresh_gear"):
		_puppet.refresh_gear()


## Estadísticas de Tico. `preview` ({"totals", "powers"}, del arrastre) añade el cambio en verde o rojo.
func _refresh_stats(preview: Dictionary) -> void:
	var now := CombatMath.hero_stats_with_powers(_im.calculate_total_stats(), _im.active_legendary_powers())
	var after: Dictionary = now if preview.is_empty() else CombatMath.hero_stats_with_powers(preview.totals, preview.powers)
	var mitigation := roundi(CombatMath.armor_mitigation(int(now.armor)) * 100.0)
	var parts := [
		tr("Vida %d") % now.max_hp + _delta(after.max_hp - now.max_hp, "%+d"),
		tr("Daño %.0f") % now.dmg + _delta(after.dmg - now.dmg, "%+.0f"),
		tr("Armadura %d (-%d%%)") % [now.armor, mitigation] + _delta(after.armor - now.armor, "%+d"),
		tr("Crítico %.0f%%") % (now.crit_p * 100.0) + _delta((after.crit_p - now.crit_p) * 100.0, "%+.0f"),
		tr("Velocidad %.2f") % now.aps + _delta(after.aps - now.aps, "%+.2f"),
	]
	_stats_label.text = "   ".join(parts)


## Cambio de la vista previa: verde si sube, rojo si baja, nada si no cambia.
func _delta(d: float, fmt: String) -> String:
	if absf(d) < 0.005:
		return ""
	return " [color=#%s]%s[/color]" % [COLOR_UP if d > 0.0 else COLOR_DOWN, fmt % d]


func _refresh_ficha() -> void:
	if _selected:
		_ficha_label.text = _ficha_text(_selected)
	else:
		_ficha_label.text = "[color=#a89a86]%s[/color]" % tr("Toca una pieza para verla; arrástrala para colocarla")


## Ficha breve (spec, apartado 9.1): nombre y calidad, estadísticas con su aumento, aura, zona y, si es
## legendaria, su habilidad y su precio.
func _ficha_text(item: CraftedItem) -> String:
	var pct: Dictionary = _im.hero_bonuses().get(item, {}) if item.place == InventoryManager.PLACE_HERO else {}
	var head := "[color=#%s]%s · %s[/color]" % [item.get_quality_color().to_html(false), item.get_name_with_rank(), item.get_quality_label()]
	var stats := []
	for key in ["damage", "hp", "armor", "crit", "aps"]:
		var v := float(item.calculated_stats.get(key, 0))
		if v <= 0.0:
			continue
		var boost := float(pct.get(key, 0.0))
		var text := _stat_text(key, v * (1.0 + boost))
		if boost > 0.0:
			text += " [color=#%s](+%d %%)[/color]" % [COLOR_UP, roundi(boost * 100.0)]
		stats.append(text)
	var extras := []
	var slot := item.get_equipment_slot()
	var strength := GearAuras.aura_strength(item)
	if strength > 0.0 and GearAuras.AURA_TEXTS.has(slot):
		extras.append(tr(GearAuras.AURA_TEXTS[slot]) % roundi(strength * 100.0))
	if GearAuras.ZONE_TEXTS.has(slot):
		extras.append(tr(GearAuras.ZONE_TEXTS[slot]))
	var power: Dictionary = LegendaryPowers.POWERS.get(StringName(item.item_resource.item_id), {})
	if LegendaryPowers.is_legendary(item) and not power.is_empty():
		var p := "[color=#ffa629]%s: %s[/color]" % [tr(power.name), tr(power.text)]
		if String(power.price) != "":
			p += " [color=#%s](%s)[/color]" % [COLOR_DOWN, tr(power.price)]
		extras.append(p)
	return "%s   %s\n%s" % [head, "  ".join(stats), " · ".join(extras)]


func _stat_text(key: String, v: float) -> String:
	match key:
		"damage":
			return tr("+%d Daño") % roundi(v)
		"hp":
			return tr("+%d Vida") % roundi(v)
		"armor":
			return tr("+%d Arm") % roundi(v)
		"crit":
			return tr("+%d%% Crít") % roundi(v * 100.0)
		"aps":
			return tr("+%.1f Vel") % v
	return ""


## Siguiente ampliación: el primer jefe del ciclo I que aún no ha ampliado la rejilla (tarea 12; con los
## rangos llegarán las recetas).
func _refresh_next() -> void:
	_next_label.text = ""
	for id in GridExpansions.ids():
		if id in _im.expansions:
			continue
		_next_label.text = tr("La rejilla crece al vencer al jefe de la sala %d") % int(GridExpansions.RECIPES[id].room)
		return

# ═══════════════════════════════════════════════════════════════════
#  EL DEDO
# ═══════════════════════════════════════════════════════════════════

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_on_press(event.position)
			else:
				_on_release(event.position)
		elif event.pressed and _dragging and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			_rotate_drag()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		_on_motion(event.position)
	elif event is InputEventScreenTouch and event.pressed and event.index >= 1 and _dragging:
		_rotate_drag()  # segundo dedo
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_R and _dragging:
		_rotate_drag()
		get_viewport().set_input_as_handled()


func _on_press(pos: Vector2) -> void:
	var hit := _piece_at(pos)
	if hit.is_empty():
		return  # botones y fondo: sigue su camino
	_press = hit
	_press.pos = pos
	_press.time = Time.get_ticks_msec()
	_press.long_done = false
	_dragging = false
	_scrolling = false
	_scroll_start = _loot_view.scroll
	get_viewport().set_input_as_handled()


## Pieza bajo un punto de la pantalla: {"item", "from", "rot", "origin"}, o {} si no hay nada que coger.
## En el botín vacío devuelve {"item": null, "from": &"loot"} para poder desplazarlo.
func _piece_at(pos: Vector2) -> Dictionary:
	for view in [_hero_view, _bag_view]:
		var local: Vector2 = pos - view.global_position
		if Rect2(Vector2.ZERO, view.size).has_point(local):
			var item: CraftedItem = view.item_at_local(local)
			if item:
				return {"item": item, "from": item.place, "rot": item.rot, "origin": view.global_position + view.item_origin(item)}
	var lp: Vector2 = pos - _loot_view.global_position
	if Rect2(Vector2.ZERO, _loot_view.size).has_point(lp):
		var slot: Dictionary = _loot_view.slot_at_local(lp)
		if slot.is_empty():
			return {"item": null, "from": InventoryManager.PLACE_LOOT, "rot": 0, "origin": pos}
		var origin: Vector2 = _loot_view.global_position + slot.rect.position - Vector2(_loot_view.scroll, 0.0)
		return {"item": slot.item, "from": InventoryManager.PLACE_LOOT, "rot": slot.rot, "origin": origin}
	return {}


func _on_motion(pos: Vector2) -> void:
	if _press.is_empty():
		return
	get_viewport().set_input_as_handled()
	if _dragging:
		_drag_pos = pos
		_update_target()
		return
	if _scrolling:
		_loot_view.scroll = clampf(_scroll_start - (pos.x - _press.pos.x), 0.0, _loot_view.max_scroll())
		_loot_view.queue_redraw()
		return
	var moved: Vector2 = pos - _press.pos
	if moved.length() < DRAG_THRESHOLD:
		return
	var in_loot: bool = _press.from == InventoryManager.PLACE_LOOT
	if _press.item == null or (in_loot and absf(moved.x) > absf(moved.y)):
		_scrolling = true
		_on_motion(pos)
		return
	_dragging = true
	_drag_rot = int(_press.rot)
	_drag_pos = pos
	_set_hidden(_press.item)
	_update_target()


func _on_release(_pos: Vector2) -> void:
	if _press.is_empty():
		return
	get_viewport().set_input_as_handled()
	var item: CraftedItem = _press.item
	if _dragging:
		_drop(item)
	elif not _scrolling and item and not _press.long_done:
		_tap(item)
	_cancel_press()


## Pulsación larga: enseña la ficha de la pieza.
func _process(_delta: float) -> void:
	if _press.is_empty() or _dragging or _scrolling or _press.item == null or _press.long_done:
		return
	if Time.get_ticks_msec() - int(_press.time) >= LONG_PRESS_MS:
		_press.long_done = true
		_selected = _press.item
		_refresh_ficha()


func _cancel_press() -> void:
	_press = {}
	_dragging = false
	_scrolling = false
	_target = {}
	_set_hidden(null)
	_clear_highlights()
	if _im and is_node_ready():
		_refresh_stats({})
	_ghost_layer.queue_redraw()


func _set_hidden(item: CraftedItem) -> void:
	_hero_view.hidden_item = item
	_bag_view.hidden_item = item
	_loot_view.hidden_item = item
	_hero_view.queue_redraw()
	_bag_view.queue_redraw()
	_loot_view.queue_redraw()


func _clear_highlights() -> void:
	for view in [_hero_view, _bag_view]:
		view.drop_cells = {}
		view.swap_item = null
		view.glow = {}
		view.queue_redraw()


## Toque: en una rejilla gira la pieza (si no cabe girada, tiembla); en el botín solo la enseña.
func _tap(item: CraftedItem) -> void:
	_selected = item
	if item.place != InventoryManager.PLACE_LOOT and not _im.rotate_in_place(item):
		(_hero_view if item.place == InventoryManager.PLACE_HERO else _bag_view).start_shake(item)
		Sfx.play(&"ui_tap", 0.0, 0.55)
	_refresh()


func _rotate_drag() -> void:
	_drag_rot = (_drag_rot + 1) % 4
	_target = {"rotated": true}  # distinto de cualquier destino: fuerza a volver a enseñarlo
	_update_target()


## Esquina de la caja de la pieza que se arrastra: donde la cogió el dedo, una casilla más arriba para
## que el dedo no tape el destino.
func _ghost_origin() -> Vector2:
	var grab: Vector2 = _press.origin - _press.pos
	return _drag_pos + grab + Vector2(0.0, -CELL)


## Busca el destino bajo la pieza (el centro de la primera casilla de su caja) y lo enseña.
func _update_target() -> void:
	var item: CraftedItem = _press.item
	var t := {}
	if _loot_view.get_global_rect().has_point(_drag_pos):
		t = {"place": InventoryManager.PLACE_LOOT, "ok": true}
	else:
		var anchor := _ghost_origin() + Vector2(CELL, CELL) * 0.5
		for view in [_hero_view, _bag_view]:
			var local: Vector2 = anchor - view.global_position
			if not Rect2(Vector2.ZERO, view.size).has_point(local):
				continue
			var place: StringName = InventoryManager.PLACE_HERO if view == _hero_view else InventoryManager.PLACE_BAG
			var cell: Vector2i = view.cell_at(local)
			var res: Dictionary = _im.drop_result(item, place, cell, _drag_rot)
			t = {"place": place, "cell": cell, "ok": res.ok, "swap": res.swap, "view": view}
			break
	if t != _target:
		_target = t
		_show_target()
	_ghost_layer.queue_redraw()


func _show_target() -> void:
	_clear_highlights()
	var item: CraftedItem = _press.item
	var preview := {}
	if _target.has("view"):
		var view: GearGridView = _target.view
		var fp := PieceShape.of_item(item, _drag_rot)
		var color := GearGridView.COLOR_OK if _target.ok else GearGridView.COLOR_BAD
		for c in fp.clean + fp.aristas:
			var cell: Vector2i = _target.cell + c
			if view.grid.in_bounds(cell):
				view.drop_cells[cell] = color
		view.swap_item = _target.swap
		if _target.ok:
			var sim: GearGrid = _im.simulate_hero_grid(item, _target.place, _target.cell, _drag_rot)
			preview = {"totals": GearAuras.totals(sim), "powers": LegendaryPowers.active(sim.items)}
			_hero_view.glow = _aura_changes(_im.hero_bonuses(), GearAuras.bonuses(sim))
	elif not _target.is_empty() and item.place == InventoryManager.PLACE_HERO:
		# Sacarla de Tico (al botín o, en la tarea 10, a la venta): la vista previa es sin ella
		var sim2: GearGrid = _im.simulate_hero_grid(item, InventoryManager.PLACE_LOOT, Vector2i.ZERO, 0)
		preview = {"totals": GearAuras.totals(sim2), "powers": LegendaryPowers.active(sim2.items)}
		_hero_view.glow = _aura_changes(_im.hero_bonuses(), GearAuras.bonuses(sim2))
	_refresh_stats(preview)
	for view in [_hero_view, _bag_view]:
		view.queue_redraw()


## Piezas de Tico que ganarían (verde) o perderían (rojo) aumento con el arrastre.
func _aura_changes(before: Dictionary, after: Dictionary) -> Dictionary:
	var out := {}
	for item in after:
		if item == _press.item:
			continue
		var d := _sum(after[item]) - _sum(before.get(item, {}))
		if d > 0.001:
			out[item] = GearGridView.COLOR_GAIN
		elif d < -0.001:
			out[item] = GearGridView.COLOR_LOSS
	return out


func _sum(pct: Dictionary) -> float:
	var s := 0.0
	for k in pct:
		s += float(pct[k])
	return s


func _drop(item: CraftedItem) -> void:
	if _target.is_empty() or not _target.get("ok", false):
		return  # vuelve a su sitio
	var place: StringName = _target.place
	if _im.move_item(item, place, _target.get("cell", Vector2i.ZERO), _drag_rot):
		_selected = item
		if place == InventoryManager.PLACE_HERO:
			Sfx.play(&"equip_clink")
			if _puppet:
				_puppet.set("_materialize", 0.55)


func _draw_ghost() -> void:
	if not _dragging or _press.is_empty():
		return
	GearGridView.draw_piece_at(_ghost_layer, _press.item, _ghost_origin(), _drag_rot, CELL, 0.85, _hero_view.sprite_for)
```

**Con la franja de pegatinas integrada** (tarea 0), la marioneta ya es el Tico de pegatina:
- quita la línea del filtro `TEXTURE_FILTER_NEAREST`, que es para pixel art;
- donde se pone `_materialize`, llama a `play_materialize()`;
- la escala ×18 vale igual: va en unidades del mundo, como en la franja.

- [ ] **Step 4: Textos**

En `TextTests._code_table_texts()`, borra el bloque que leía `TIER_NAMES` y `SLOT_NAMES` de `EquipmentPanel.gd` (las cuatro líneas que empiezan en `var equipment := _consts("res://scripts/ui/EquipmentPanel.gd")`): el panel nuevo ya no tiene esas tablas.

Filas en `locale/textos.csv` (comprueba antes con `grep` que no existan; "Vida %d", "Daño %.0f", "Armadura %d (-%d%%)", "Crítico %.0f%%", "+%d Daño", "+%d Vida", "+%d Arm", "+%d%% Crít" y "+%.1f Vel" ya estaban del panel viejo):

```
Equipo,Equipo,Gear
Botín,Botín,Loot
Botín · %d,Botín · %d,Loot · %d
Mochila,Mochila,Backpack
Vender todo,Vender todo,Sell all
Suelta aquí para vender,Suelta aquí para vender,Drop here to sell
Velocidad %.2f,Velocidad %.2f,Speed %.2f
Toca una pieza para verla; arrástrala para colocarla,Toca una pieza para verla; arrástrala para colocarla,Tap a piece to see it; drag it to place it
La rejilla crece al vencer al jefe de la sala %d,La rejilla crece al vencer al jefe de la sala %d,The grid grows when you beat the boss of room %d
```

Run: `--import`

- [ ] **Step 5: Ejecutar y ver que pasa**

Run: la batería. Expected: 0 fallos. `TextTests.test_los_textos_de_las_escenas_vivas_tienen_fila` sigue por encima de 25 textos revisados: la escena nueva aporta 6.

- [ ] **Step 6: Captura del panel**

Copia `save.json` antes (Global Constraints):

```bash
timeout 300 D:/Software/Godot/godot_ver4.5.exe --path . --write-movie <scratchpad>/t9/f.png --fixed-fps 10 --quit-after 90 --resolution 810x1440 res://scenes/tests/VisualCapture.tscn -- --plan=panels
```

Restaura `save.json`. Abre con Read 2 o 3 fotogramas del panel de Equipo y comprueba:
- la rejilla de Tico delante de su sprite tenue;
- las casillas por abrir, punteadas;
- botín, mochila, zona de venta y estadísticas sin salirse de la pantalla;
- ningún texto encima de otro.

- [ ] **Step 7: Commit**

```bash
git add scenes/UI/EquipmentPanel.tscn scripts/ui/EquipmentPanel.gd scripts/tests/InventoryGridTests.gd scripts/tests/TextTests.gd locale/textos.csv
git commit -m "feat: panel de Equipo en rejilla: tocar gira, arrastrar coloca e intercambia"
```

---

### Task 10: Ficha completa, venta, "Vender todo" e insignia

**Files:**
- Modify: `scripts/ui/EquipmentPanel.gd`, `scripts/ui/HUDMain.gd` (insignia), `scripts/autoload/InventoryManager.gd` (se quita la compatibilidad), `locale/textos.csv`
- Test: `scripts/tests/InventoryGridTests.gd`

**Interfaces:**
- Consumes: `InventoryManager.sell_item`, `sellable_loot`, `sell_all_loot`, `move_item`, `get_loot_count`; `GearPacker.find_spot` (botón "A la mochila")
- Produces:
  - En `EquipmentPanel`:
    - `_card` (ficha completa) y `_open_card(item)`, con los botones "A la mochila", "Al botín", "Vender" y "Cerrar";
    - `_confirm_box` y `_confirm(text: String, on_yes: Callable)`;
    - `_sell(item)` y `_on_sell_all()`.
  - La insignia del botón Equipo cuenta las piezas del botín.
- Se quitan `InventoryManager.equip_item`, `unequip_item` y `get_equipped_item`.

- [ ] **Step 1: Pruebas que fallan**

```gdscript
# ─── Tarea 10: ficha, venta e insignia ─────────────────────────────────

func _long_press(panel: Control, pos: Vector2) -> void:
	_mouse(panel, pos, true)
	panel._press.time = Time.get_ticks_msec() - 1000  # como si llevara 1 s pulsada
	panel._process(0.0)


func test_long_press_opens_the_card() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var helmet := _piece(&"helmet_advanced", 1.0)
	im.add_crafted_item(helmet)
	im.move_item(helmet, &"hero", Vector2i(0, 0), 0)
	var panel := _new_panel()
	var p := _cell_center(panel._hero_view, Vector2i(0, 0))
	_long_press(panel, p)
	check(panel._card.visible and panel._card_item == helmet, "mantener pulsado abre la ficha completa")
	check(panel._card_text.text.contains(tr("Regeneración")), "la ficha enseña la habilidad legendaria (%s)" % panel._card_text.text)
	_mouse(panel, p, false)
	check(helmet.rot == 0, "soltar tras la pulsación larga no gira")
	panel._card_to_bag()
	check(helmet.place == &"bag" and not panel._card.visible, "A la mochila la manda al primer hueco libre y cierra")
	panel.queue_free()
	await _restore_inventory(saved)


func test_sell_zone_sells_and_asks_for_the_best() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var plain := _piece(&"boots_basic", 0.3)
	var epic := _piece(&"boots_basic", 0.95)
	for p in [plain, epic]:
		im.add_crafted_item(p)
	im.move_item(plain, &"bag", Vector2i(0, 0), 0)
	im.move_item(epic, &"bag", Vector2i(2, 0), 0)
	var panel := _new_panel()
	var sell_point: Vector2 = panel.sell_zone.get_global_rect().get_center()
	for item in [plain, epic]:
		var start := _cell_center(panel._bag_view, item.cell)
		_mouse(panel, start, true)
		_move(panel, start + Vector2(0, -40))
		_move(panel, sell_point)
		check(panel._target.get("place") == &"sell", "sobre la zona de venta")
		check(panel.sell_label.text.contains(str(item.get_sell_price())), "la zona enseña el precio (%s)" % panel.sell_label.text)
		_mouse(panel, sell_point, false)
	check(not (plain in im.get_crafted_items()), "la pieza normal se vende al soltarla")
	check(epic in im.get_crafted_items() and panel._confirm_box.visible, "la épica pide confirmación antes")
	var gold: int = im.get_quantity(&"gold")
	panel._on_confirm_yes()
	check(not (epic in im.get_crafted_items()) and im.get_quantity(&"gold") == gold + epic.get_sell_price(), "al confirmar, se vende")
	panel.queue_free()
	await _restore_inventory(saved)


func test_sell_all_asks_and_keeps_the_best() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var a := _piece(&"sword_basic", 0.2)
	var b := _piece(&"sword_basic", 0.5)
	var legend := _piece(&"sword_basic", 1.0)
	for p in [a, b, legend]:
		im.add_crafted_item(p)
	var panel := _new_panel()
	panel._on_sell_all()
	check(panel._confirm_box.visible and panel._confirm_text.text.contains(str(a.get_sell_price() + b.get_sell_price())), "pide confirmación con el total (%s)" % panel._confirm_text.text)
	check(im.get_loot().size() == 3, "sin confirmar no vende nada")
	panel._on_confirm_yes()
	check(im.get_loot() == [legend], "vende todo salvo la legendaria")
	panel.queue_free()
	await _restore_inventory(saved)
```

Run InventoryGridTests. Expected: errores (`_card`, `_confirm_box` y `_on_sell_all` no existen).

- [ ] **Step 2: Ficha completa y confirmación en `EquipmentPanel.gd`**

Variables nuevas, junto a las demás:

```gdscript
var _card: ColorRect
var _card_text: RichTextLabel
var _card_sell_btn: Button
var _card_item: CraftedItem = null
var _confirm_box: ColorRect
var _confirm_text: Label
var _confirm_action: Callable = Callable()
```

Al final de `_build()`, después de añadir `_ghost_layer`:

```gdscript
	_build_card()
	_build_confirm()
	sell_all_btn.pressed.connect(_on_sell_all)
```

Funciones nuevas:

```gdscript
## Capa oscura a pantalla completa con un panel centrado; la usan la ficha y la confirmación.
func _overlay(top: float) -> Array:
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.visible = false
	add_child(shade)
	var panel := PanelContainer.new()
	panel.position = Vector2(90, top)
	panel.custom_minimum_size = Vector2(900, 0)
	shade.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	panel.add_child(box)
	return [shade, box]


func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(200, 96)
	b.add_theme_font_size_override("font_size", 26)
	b.pressed.connect(action)
	return b


func _build_card() -> void:
	var parts := _overlay(560)
	_card = parts[0]
	_card_text = RichTextLabel.new()
	_card_text.bbcode_enabled = true
	_card_text.fit_content = true
	_card_text.custom_minimum_size = Vector2(860, 0)
	_card_text.add_theme_font_size_override("normal_font_size", 28)
	parts[1].add_child(_card_text)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	parts[1].add_child(row)
	row.add_child(_button(tr("A la mochila"), _card_to_bag))
	row.add_child(_button(tr("Al botín"), _card_to_loot))
	_card_sell_btn = _button(tr("Vender"), _card_sell)
	row.add_child(_card_sell_btn)
	row.add_child(_button(tr("Cerrar"), _close_card))


func _build_confirm() -> void:
	var parts := _overlay(760)
	_confirm_box = parts[0]
	_confirm_text = Label.new()
	_confirm_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_confirm_text.custom_minimum_size = Vector2(860, 0)
	_confirm_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirm_text.add_theme_font_size_override("font_size", 30)
	parts[1].add_child(_confirm_text)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 40)
	parts[1].add_child(row)
	row.add_child(_button(tr("Sí"), _on_confirm_yes))
	row.add_child(_button(tr("No"), func(): _confirm_box.visible = false))


## Ficha completa de una pieza (pulsación larga): su ficha breve y qué se puede hacer con ella.
func _open_card(item: CraftedItem) -> void:
	_card_item = item
	var aristas := tr("Sin aristas") if item.aristas.is_empty() else tr("Aristas: %d") % item.aristas.size()
	_card_text.text = "%s\n[color=#a89a86]%s[/color]" % [_ficha_text(item), aristas]
	_card_sell_btn.text = tr("Vender por %d") % item.get_sell_price()
	_card.visible = true


func _close_card() -> void:
	_card.visible = false
	_card_item = null


func _card_to_bag() -> void:
	var item := _card_item
	_close_card()
	if item == null or item.place == InventoryManager.PLACE_BAG:
		return
	var spot := GearPacker.find_spot(_im.bag_grid, item, false)
	if spot.is_empty() or not _im.move_item(item, InventoryManager.PLACE_BAG, spot.cell, spot.rot):
		Sfx.play(&"ui_tap", 0.0, 0.55)  # la mochila está llena


func _card_to_loot() -> void:
	var item := _card_item
	_close_card()
	if item:
		_im.move_item(item, InventoryManager.PLACE_LOOT)


func _card_sell() -> void:
	var item := _card_item
	_close_card()
	if item:
		_sell(item)


## Pregunta antes de hacer algo que no se deshace.
func _confirm(text: String, action: Callable) -> void:
	_confirm_text.text = text
	_confirm_action = action
	_confirm_box.visible = true


func _on_confirm_yes() -> void:
	_confirm_box.visible = false
	if _confirm_action.is_valid():
		_confirm_action.call()
	_confirm_action = Callable()


## Venta desde la zona de venta o la ficha: las Épicas y las Legendarias piden confirmación.
func _sell(item: CraftedItem) -> void:
	if item.get_quality_tier() in ["epic", "legendary"]:
		_confirm(tr("¿Vender %s por %d de oro?") % [item.get_name_with_rank(), item.get_sell_price()], func(): _do_sell(item))
	else:
		_do_sell(item)


func _do_sell(item: CraftedItem) -> void:
	if _im.sell_item(item) > 0:
		Sfx.play(&"loot_coins")
	_refresh()


## "Vender todo": el botín salvo las Épicas y las Legendarias, tras confirmar con el total.
func _on_sell_all() -> void:
	var items: Array = _im.sellable_loot()
	if items.is_empty():
		Sfx.play(&"ui_tap", 0.0, 0.55)
		return
	var total := 0
	for item in items:
		total += item.get_sell_price()
	_confirm(tr("¿Vender %d piezas del botín por %d de oro? Las Épicas y Legendarias se quedan.") % [items.size(), total], func():
		if _im.sell_all_loot() > 0:
			Sfx.play(&"loot_coins")
		_refresh()
	)
```

- [ ] **Step 3: La pulsación larga abre la ficha y la zona de venta**

En `_process`, después de `_refresh_ficha()`:

```gdscript
		_open_card(_press.item)
```

En `_on_press`, al principio (con la ficha o la confirmación abiertas, el dedo es de sus botones):

```gdscript
	if _card.visible or _confirm_box.visible:
		return
```

En `_update_target`, la zona de venta va primero. Sustituye la línea `if _loot_view.get_global_rect().has_point(_drag_pos):` por:

```gdscript
	if sell_zone.get_global_rect().has_point(_drag_pos):
		t = {"place": &"sell", "ok": true}
	elif _loot_view.get_global_rect().has_point(_drag_pos):
```

En `_show_target`, al final (antes de `_refresh_stats(preview)`), el precio en la zona de venta:

```gdscript
	var selling: bool = _target.get("place", &"") == &"sell"
	sell_label.text = tr("Vender por %d de oro") % item.get_sell_price() if selling else tr("Suelta aquí para vender")
	sell_zone.modulate = Color(1.4, 1.25, 0.8) if selling else Color.WHITE
```

En `_cancel_press`, deja la zona como estaba:

```gdscript
	sell_label.text = tr("Suelta aquí para vender")
	sell_zone.modulate = Color.WHITE
```

En `_drop`, después del primer `return` (el de destino vacío o que no vale):

```gdscript
	if _target.place == &"sell":
		_sell(item)
		return
```

- [ ] **Step 4: Insignia del botón Equipo (`HUDMain.gd`)**

La insignia pasa a contar las piezas del botín: son las que están por colocar.
- Borra las variables `_new_items` y `_known_item_count`.
- Borra la conexión a `crafted_items_changed` de `_ready()` y la función `_on_crafted_items_changed`.
- En `_on_progress_loaded()` y `_on_delivery_pressed()`, borra las líneas que tocan `_new_items` o `_known_item_count`. `_update_badges()` se queda.
- En `_update_badges()`:

```gdscript
func _update_badges() -> void:
	var loot_count: int = _inventory_manager.get_loot_count() if _inventory_manager and _inventory_manager.has_method("get_loot_count") else 0
	_set_badge(_equip_badge, loot_count)
	_set_badge(_blueprint_badge, _new_blueprints)
```

- En `_ready()`, al cerrar el panel se actualiza:

```gdscript
	if equipment_panel and equipment_panel.has_signal("panel_closed"):
		equipment_panel.panel_closed.connect(_update_badges)
```

La insignia sigue encendiéndose al cerrar el resultado de la forja (`_show_craft_result` ya llama a `_update_badges` cuando llegan las partículas).

- [ ] **Step 5: Fuera la compatibilidad provisional**

- En `InventoryManager.gd`, borra la sección "COMPATIBILIDAD PROVISIONAL" entera: `equip_item`, `unequip_item` y `get_equipped_item`.
- Comprueba que nadie más las usa: `grep -rn "equip_item\|unequip_item\|get_equipped_item" scripts --include=*.gd`. Solo puede salir `DungeonHUD.gd`, que no se usa, las llama con `has_method` y no rompe. (La prueba de equipar de `GameplayTests` ya la reescribió la tarea 6.)

- [ ] **Step 6: Textos**

Filas en `locale/textos.csv` (comprueba antes que no existan "Cerrar", "Sí" y "No"):

```
A la mochila,A la mochila,To backpack
Al botín,Al botín,To loot
Vender,Vender,Sell
Cerrar,Cerrar,Close
Sí,Sí,Yes
No,No,No
Sin aristas,Sin aristas,No rough edges
Aristas: %d,Aristas: %d,Rough edges: %d
Vender por %d,Vender por %d,Sell for %d
Vender por %d de oro,Vender por %d de oro,Sell for %d gold
¿Vender %s por %d de oro?,¿Vender %s por %d de oro?,Sell %s for %d gold?
¿Vender %d piezas del botín por %d de oro? Las Épicas y Legendarias se quedan.,¿Vender %d piezas del botín por %d de oro? Las Épicas y Legendarias se quedan.,Sell %d loot pieces for %d gold? Epic and Legendary pieces stay.
```

Run: `--import`

- [ ] **Step 7: Ejecutar y ver que pasa**

Run: la batería. Expected: 0 fallos.

- [ ] **Step 8: Commit**

```bash
git add scripts/ui/EquipmentPanel.gd scripts/ui/HUDMain.gd scripts/autoload/InventoryManager.gd scripts/tests/InventoryGridTests.gd locale/textos.csv
git commit -m "feat: ficha completa, zona de venta, Vender todo e insignia del botín"
```

---

### Task 11: Habilidades legendarias en combate

**Files:**
- Modify: `scripts/gameplay/Hero.gd`, `scripts/gameplay/Enemy.gd`, `scripts/gameplay/CombatController.gd`, `scripts/gameplay/visual/CombatFX.gd`, `locale/textos.csv`
- Test: `scripts/tests/InventoryGridTests.gd`

**Interfaces:**
- Consumes: `LegendaryPowers.effects`, `LegendaryPowers.BURN_TIME`, `InventoryManager.active_legendary_powers()`
- Produces:
  - En `Hero`:
    - `signal hurt(amount: int)`, emitida tras cada golpe o pulso recibido, aunque haga 0;
    - `power: Dictionary` (`LegendaryPowers.effects` de la rejilla; se recalcula en `reset_stats`);
    - `power_roll: Callable` (tirada de 0 a 1 de las habilidades; las pruebas la fuerzan) y `roll_power() -> float`;
    - `last_avoid: StringName` (`&"dodge"`, `&"block"` o `&""`) y `first_strike_ready: bool`.
  - En `Enemy`: `apply_burn(dps: float, duration: float)`, `is_burning() -> bool`, `_tick_burn(delta)` y la constante `BURN_TICK` (0,5 s).
  - En `CombatController`: `_hero_hit(target_level: int, is_second: bool)`.
  - Estilos nuevos de `CombatFX.damage_number`: `&"burn"` y `&"thorns"`.

- [ ] **Step 1: Pruebas que fallan**

```gdscript
# ─── Tarea 11: habilidades legendarias en combate ──────────────────────

## Pasillo de prueba con un enemigo de la sala 5 y Tico con las habilidades dadas, sin críticos y con toda
## tirada de habilidad a favor. Guarda el estado de GameManager para restaurarlo.
func _arena(powers: Array) -> Dictionary:
	var gm := get_node("/root/GameManager")
	var state := {"level": gm.current_enemy_level, "best": gm.best_enemy_level, "deaths": gm.death_count, "dungeon": gm.dungeon_state, "wall": gm.wall_room, "locked": gm.room_locked}
	gm.current_enemy_level = 5
	var corridor: Node2D = load("res://scenes/Corridor.tscn").instantiate()
	add_child(corridor)
	await get_tree().process_frame
	var hero: Node2D = corridor.get_node("Hero")
	hero.power = LegendaryPowers.effects(powers)
	hero.crit_p = 0.0
	hero.power_roll = func() -> float: return 0.0
	return {"corridor": corridor, "hero": hero, "enemy": corridor.get_node("Enemy"), "cc": corridor.get_node("CombatController"), "state": state}


func _close_arena(a: Dictionary) -> void:
	a.corridor.queue_free()
	var gm := get_node("/root/GameManager")
	gm.current_enemy_level = a.state.level
	gm.best_enemy_level = a.state.best
	gm.death_count = a.state.deaths
	gm.dungeon_state = a.state.dungeon  # una caída de Tico en la prueba lo cambia
	gm.wall_room = a.state.wall  # y también deja un muro
	gm.room_locked = a.state.locked
	await get_tree().process_frame
	await _silence_sounds()


## Deja sonar los golpes y el botín y calla las voces de AudioManager: si la suite sale con un sonido a
## medias, Godot avisa de recursos «still in use at exit».
func _silence_sounds() -> void:
	await get_tree().create_timer(0.35).timeout
	var am := get_node_or_null("/root/AudioManager")
	if am:
		for voice in am.get_children():
			if voice is AudioStreamPlayer:
				voice.stop()
	await get_tree().create_timer(0.1).timeout


func test_double_hit_strikes_twice() -> void:
	var a := await _arena([&"sword_advanced"])
	var enemy: Node2D = a.enemy
	enemy.max_hp = 100000
	enemy.hp = 100000
	a.cc._execute_hero_attack()
	check(100000 - enemy.hp == int(a.hero.dmg) * 2, "con la tirada a favor golpea dos veces (%d de daño, golpe de %d)" % [100000 - enemy.hp, int(a.hero.dmg)])
	await _close_arena(a)


func test_double_hit_never_reaches_the_next_enemy() -> void:
	var a := await _arena([&"sword_advanced"])
	var enemy: Node2D = a.enemy
	var deaths := [0]
	enemy.died.connect(func(_drops): deaths[0] += 1)
	enemy.hp = 1
	var level_before: int = enemy.level
	a.cc._execute_hero_attack()
	check(deaths[0] == 1, "el primer golpe mata, una vez (%d)" % deaths[0])
	check(enemy.level == level_before or enemy.hp == enemy.max_hp, "si el nodo ya es el enemigo de la sala siguiente, está intacto (%d/%d)" % [enemy.hp, enemy.max_hp])
	await _close_arena(a)


func test_burn_deals_its_share_over_three_seconds() -> void:
	var a := await _arena([&"sword_masterwork"])
	var enemy: Node2D = a.enemy
	enemy.max_hp = 100000
	enemy.hp = 100000
	a.cc._execute_hero_attack()
	var hit := int(a.hero.dmg)
	var after_hit: int = enemy.hp
	check(enemy.is_burning(), "el golpe deja una quemadura")
	for i in 8:
		enemy._tick_burn(0.5)
	var burned := after_hit - enemy.hp
	check(absi(burned - roundi(hit * 0.4)) <= 1, "la quemadura hace el 40 %% del golpe en 3 s (%d de %d)" % [burned, hit])
	check(not enemy.is_burning(), "y se apaga")
	await _close_arena(a)


func test_burn_does_not_carry_over_to_the_next_enemy() -> void:
	var a := await _arena([])
	var enemy: Node2D = a.enemy
	enemy.apply_burn(50.0, 3.0)
	check(enemy.is_burning(), "quemándose")
	enemy.configure_for_level(6, false)  # el nodo pasa a la sala siguiente, como al morir
	check(not enemy.is_burning(), "el enemigo siguiente no empieza quemado")
	await _close_arena(a)


func test_thorns_kill_counts_once() -> void:
	var a := await _arena([&"shield_master"])
	var hero: Node2D = a.hero
	var enemy: Node2D = a.enemy
	hero.max_hp = 100000
	hero.hp = 100000
	enemy.dmg = 200.0
	enemy.crit_p = 0.0
	enemy.hp = 1
	var deaths := [0]
	enemy.died.connect(func(_drops): deaths[0] += 1)
	a.cc._execute_enemy_attack()
	check(deaths[0] == 1, "las Espinas matan al enemigo durante su propio ataque, una sola vez (%d)" % deaths[0])
	await _close_arena(a)


func test_dodge_and_block_avoid_whole_hits_but_not_pulses() -> void:
	var a := await _arena([&"boots_advanced"])
	var hero: Node2D = a.hero
	var hp: int = hero.hp
	check(hero.take_damage(50) == 0 and hero.last_avoid == &"dodge" and hero.hp == hp, "Esquiva: el golpe no hace nada")
	check(hero.take_damage(5, true) > 0 and hero.last_avoid == &"", "el pulso mágico no se esquiva")
	hero.power = LegendaryPowers.effects([&"shield_advanced"])
	hp = hero.hp
	check(hero.take_damage(50) == 0 and hero.last_avoid == &"block" and hero.hp == hp, "Parada: tampoco")
	hero.power_roll = func() -> float: return 0.99
	check(hero.take_damage(10) > 0, "con la tirada en contra, el golpe entra")
	await _close_arena(a)


func test_second_chance_once_per_duel() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var helmet := _piece(&"helmet_master", 1.0)
	im.add_crafted_item(helmet)
	im.move_item(helmet, &"hero", Vector2i(0, 0), 0)
	var a := await _arena([])
	var hero: Node2D = a.hero
	hero.respawn()  # vuelve a leer la rejilla (la arena le quitó las habilidades)
	hero.prepare_for_combat()  # empieza un duelo: Segunda oportunidad lista
	check(float(hero.power.second_chance) > 0.0, "el casco maestro legendario da Segunda oportunidad")
	hero.take_damage(hero.max_hp * 5, true)
	check(hero.alive and hero.hp == roundi(hero.max_hp * 0.4), "la primera caída del duelo se queda con el 40 %% (%d/%d)" % [hero.hp, hero.max_hp])
	hero.take_damage(hero.max_hp * 5, true)
	check(not hero.alive, "la segunda vez en el mismo duelo cae")
	hero.respawn()
	hero.prepare_for_combat()
	hero.take_damage(hero.max_hp * 5, true)
	check(hero.alive, "en el duelo siguiente vuelve a tenerla")
	await _close_arena(a)
	await _restore_inventory(saved)


func test_regeneration_heals_while_alive() -> void:
	var a := await _arena([&"helmet_advanced"])
	var hero: Node2D = a.hero
	hero.hp = roundi(hero.max_hp * 0.5)
	var before: int = hero.hp
	hero._process(1.0)
	check(hero.hp - before == int(hero.max_hp * 0.015), "recupera el 1,5 %% de la vida máxima en un segundo (%d)" % (hero.hp - before))
	await _close_arena(a)


func test_first_strike_triples_the_first_hit_on_each_enemy() -> void:
	var a := await _arena([&"boots_master"])
	var hero: Node2D = a.hero
	var enemy: Node2D = a.enemy
	enemy.max_hp = 100000
	enemy.hp = 100000
	hero.prepare_for_combat()
	var hit := int(hero.dmg)
	a.cc._execute_hero_attack()
	check(100000 - enemy.hp == int(hero.dmg * 3.0), "primer golpe ×3 (%d)" % (100000 - enemy.hp))
	var mid: int = enemy.hp
	a.cc._execute_hero_attack()
	check(mid - enemy.hp == hit, "el segundo, normal (%d)" % (mid - enemy.hp))
	await _close_arena(a)
```

Run InventoryGridTests. Expected: errores (`power`, `power_roll`, `apply_burn`… no existen).

- [ ] **Step 2: `Hero.gd`**

Señal y variables (junto a las demás):

```gdscript
signal hurt(amount: int)  ## tras cada golpe o pulso recibido (0 si se esquivó o paró): pociones automáticas

## Habilidades legendarias de la rejilla (LegendaryPowers.effects): se recalculan en reset_stats
var power: Dictionary = LegendaryPowers.effects([])
## Tirada de 0 a 1 para las habilidades (esquiva, parada, golpe doble); las pruebas la fuerzan
var power_roll: Callable = Callable()
## &"dodge" o &"block" si el último golpe se esquivó o paró; &"" si no
var last_avoid: StringName = &""
## Ímpetu: el primer golpe contra el enemigo actual aún no se ha dado
var first_strike_ready := false
var _second_chance_ready := false
var _second_chance_used := false  ## en este duelo (se recarga al empezar el siguiente)
var _regen_acc := 0.0
var _regen_shown := 0
var _regen_fx_cd := 0.0
```

`reset_stats()`: después de la línea `var s := CombatMath.hero_stats_with_powers(equipment_stats, powers)` (tarea 6):

```gdscript
	power = LegendaryPowers.effects(powers)
	# Segunda oportunidad: lista si la da la rejilla y aún no se ha usado en este duelo
	_second_chance_ready = float(power.second_chance) > 0.0 and not _second_chance_used
```

`respawn()`: antes de `emit_signal("respawned")`:

```gdscript
	_regen_acc = 0.0
```

`prepare_for_combat()`, que `CombatController` llama al empezar cada duelo (si los rangos le cambiaron la firma, se mantiene la suya), al final:

```gdscript
	first_strike_ready = float(power.first_strike) > 0.0
	# Segunda oportunidad: una por duelo (en el spec de rangos, cada sala es un duelo con la vida llena)
	_second_chance_used = false
	_second_chance_ready = float(power.second_chance) > 0.0
```

Funciones nuevas:

```gdscript
func roll_power() -> float:
	return float(power_roll.call()) if power_roll.is_valid() else randf()


## Segunda oportunidad: destello, anillo y "¡OTRA VEZ!" en la franja.
func _on_second_chance() -> void:
	_materialize = 0.4
	if fx:
		var c := body_center()
		fx.ring(c, Color("ffd76a"), 2.0, 20.0, 0.45, 1.0)
		fx.float_text(c + Vector2(0, -16), tr("¡Otra vez!"), Color("ffd76a"), true, 1.2, 10.0)
```

Sustituye `take_damage`. Parte de la de la base, sin la sala del atacante; si los rangos se la añaden después, la conservan:

```gdscript
## Aplica daño y devuelve el daño real recibido (tras armadura). El pulso mágico ignora la armadura.
## Habilidades legendarias: Esquiva y Parada anulan un golpe (no el pulso) y dejan `last_avoid`;
## Segunda oportunidad deja a Tico con vida la primera vez que iba a caer en cada duelo.
func take_damage(amount: int, is_pulse: bool = false) -> int:
	last_avoid = &""
	if debug_invincible or not alive:
		return 0
	if not is_pulse:
		if float(power.dodge) > 0.0 and roll_power() < float(power.dodge):
			last_avoid = &"dodge"
			hurt.emit(0)
			return 0
		if float(power.block) > 0.0 and roll_power() < float(power.block):
			last_avoid = &"block"
			_block_flash = 1.0
			hurt.emit(0)
			return 0
	var final := amount
	if not is_pulse:
		var mitigation := armor_mitigation()
		final = maxi(1, int(round(float(amount) * (1.0 - mitigation))))
		if final < amount and mitigation >= 0.15:
			_block_flash = 1.0
	_hurt = HURT_TIME
	_ghost_delay = 0.35
	if final >= hp and _second_chance_ready:
		_second_chance_ready = false
		_second_chance_used = true
		hp = maxi(1, roundi(float(max_hp) * float(power.second_chance)))
		_on_second_chance()
	else:
		hp = max(0, hp - final)
		if hp == 0:
			alive = false
			_spawn_death_fx()
			emit_signal("died")
	hurt.emit(final)
	return final
```

En `_process(delta)`, después de actualizar `_hurt` y `_block_flash`:

```gdscript
	# Regeneración (casco avanzado legendario): solo con Tico vivo; un "+N" verde cada 2 s como mucho
	if alive and float(power.regen) > 0.0 and hp < max_hp:
		_regen_acc += float(max_hp) * float(power.regen) * delta
		if _regen_acc >= 1.0:
			var gain := int(_regen_acc)
			_regen_acc -= gain
			hp = mini(max_hp, hp + gain)
			_regen_shown += gain
	_regen_fx_cd = maxf(0.0, _regen_fx_cd - delta)
	if _regen_shown > 0 and _regen_fx_cd <= 0.0 and fx:
		fx.float_text(body_center() + Vector2(0, -16), "+%d" % _regen_shown, Color("7dff8a"), false, 0.8, 8.0)
		_regen_shown = 0
		_regen_fx_cd = 2.0
```

- [ ] **Step 3: Quemadura en `Enemy.gd`**

```gdscript
const BURN_TICK := 0.5  ## la quemadura hace daño cada medio segundo: un número por tic

var _burn_dps := 0.0
var _burn_left := 0.0
var _burn_acc := 0.0
var _burn_tick := 0.0


## Quemadura (Filo ígneo): `dps` de daño por segundo durante `duration` s, sin armadura. No se acumula:
## se queda la que hace más daño por segundo y el tiempo vuelve a empezar.
func apply_burn(dps: float, duration: float) -> void:
	if not alive or dps <= 0.0:
		return
	_burn_dps = maxf(_burn_dps, dps)
	_burn_left = duration


func is_burning() -> bool:
	return alive and _burn_left > 0.0


func _clear_burn() -> void:
	_burn_dps = 0.0
	_burn_left = 0.0
	_burn_acc = 0.0
	_burn_tick = 0.0


func _tick_burn(delta: float) -> void:
	if not is_burning():
		return
	var dt := minf(delta, _burn_left)
	_burn_left -= dt
	_burn_acc += _burn_dps * dt
	_burn_tick += dt
	if _burn_tick >= BURN_TICK or _burn_left <= 0.0:
		_burn_tick = 0.0
		var dmg := int(_burn_acc)
		_burn_acc -= dmg
		if dmg > 0:
			var at := body_center()
			take_damage(dmg, true)
			if fx:
				fx.damage_number(at + Vector2(0, -10), dmg, &"burn")
	if _burn_left <= 0.0:
		_clear_burn()
```

- Al principio de `_process(delta)`, llama a `_tick_burn(delta)`.
- Al principio de `configure_for_level(lv, boss)`, llama a `_clear_burn()`. El nodo se reutiliza para el enemigo de la sala siguiente, que no puede empezar quemado.

- [ ] **Step 4: `CombatController.gd`**

Sustituye `_execute_hero_attack()`. Su cuerpo de siempre pasa a `_hero_hit`, con el Ímpetu al principio y la quemadura y el texto del golpe doble tras el daño:

```gdscript
func _execute_hero_attack():
	var target_level: int = enemy.level
	_hero_hit(target_level, false)
	# Golpe doble (espada avanzada legendaria). Si el primer golpe ha matado, el nodo Enemy ya es el de la
	# sala siguiente (se recoloca al morir) o sigue muerto: el segundo golpe no le llega.
	if float(hero.power.double_hit) > 0.0 and enemy.alive and enemy.level == target_level and hero.roll_power() < float(hero.power.double_hit):
		_hero_hit(target_level, true)


func _hero_hit(target_level: int, is_second: bool) -> void:
	var damage: float = hero.dmg
	# Ímpetu (botas maestras legendarias): el primer golpe contra cada enemigo, ×3
	if hero.first_strike_ready and not is_second:
		damage *= float(hero.power.first_strike)
		hero.first_strike_ready = false
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
	# Filo ígneo (espada maestra legendaria): el golpe deja una quemadura, si el enemigo sigue vivo y es el mismo
	if float(hero.power.burn) > 0.0 and enemy.alive and enemy.level == target_level:
		enemy.apply_burn(float(amount) * float(hero.power.burn) / LegendaryPowers.BURN_TIME, LegendaryPowers.BURN_TIME)
	if fx:
		fx.damage_number(number_pos, amount, &"crit" if crit else &"normal")
		if is_second:
			fx.float_text(number_pos + Vector2(0, -8), tr("¡Doble!"), Color("ffe08a"), false, 0.7, 8.0)
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
```

Lo nuevo de esta tarea son las líneas del Ímpetu, la quemadura y "¡Doble!"; el resto del bloque es el de la base.

En `_execute_enemy_attack()`, desde la línea `var dealt: int = hero.take_damage(raw)` hasta el bloque del texto "Bloqueo" (incluido), sustituye por:

```gdscript
	var dealt: int = hero.take_damage(raw)
	if fx:
		if hero.last_avoid != &"":
			# Esquiva (botas avanzadas) o Parada (escudo avanzado) legendarias
			fx.float_text(hit_pos + Vector2(-9, -4), tr("¡Esquiva!") if hero.last_avoid == &"dodge" else tr("¡Parada!"), Color("b8c4d6"), false, 0.7, 8.0)
		else:
			fx.damage_number(number_pos, dealt, &"hero")
			if dealt < raw and _block_text_cd <= 0.0 and hero.has_method("armor_mitigation") and hero.armor_mitigation() >= 0.2:
				_block_text_cd = 2.5
				fx.float_text(hit_pos + Vector2(-9, -4), tr("Bloqueo"), Color("b8c4d6"), false, 0.7, 8.0)
	# Espinas (escudo maestro legendario): parte del daño recibido vuelve al atacante. Si lo mata, muere
	# una sola vez: Enemy._die no hace nada con el enemigo ya caído.
	if dealt > 0 and float(hero.power.thorns) > 0.0 and enemy.alive:
		var back := maxi(1, int(float(dealt) * float(hero.power.thorns)))
		var at: Vector2 = enemy.body_center()
		enemy.take_damage(back, true)
		if fx:
			fx.damage_number(at + Vector2(0, -14), back, &"thorns")
```

El `match style:` que viene después (polvo y chispas del golpe) se queda como está, dentro de su `if fx:`.

- [ ] **Step 5: Estilos de número en `CombatFX.damage_number`**

En el `match style:`, junto a los demás:

```gdscript
		&"burn":
			color = Color("ff8a3d")
		&"thorns":
			color = Color("c9b37a")
```

Y en el comentario de la función, añade `"burn"` y `"thorns"` a la lista de estilos.

- [ ] **Step 6: Textos**

Filas en `locale/textos.csv`. Son textos de la franja: `TextTests` comprueba que la fuente pixel tiene sus letras en los dos idiomas.

```
¡Doble!,¡Doble!,Double!
¡Parada!,¡Parada!,Parried!
¡Esquiva!,¡Esquiva!,Dodged!
¡Otra vez!,¡Otra vez!,Again!
```

Run: `--import`

- [ ] **Step 7: Ejecutar y ver que pasa**

Run: la batería. Expected: 0 fallos.

- [ ] **Step 8: Commit**

```bash
git add scripts/gameplay/Hero.gd scripts/gameplay/Enemy.gd scripts/gameplay/CombatController.gd scripts/gameplay/visual/CombatFX.gd scripts/tests/InventoryGridTests.gd locale/textos.csv
git commit -m "feat: habilidades legendarias en combate: golpe doble, quemadura, parada, esquiva, espinas, regeneración, segunda oportunidad e ímpetu"
```

---

### Task 12: La rejilla crece al vencer a los jefes (provisional), y el resultado de la forja

Las recetas de ampliación del spec (apartado 7) necesitan los materiales de bioma y el encargo propio de los rangos, que aún no están. Hasta entonces, vencer por primera vez al jefe de la sala 10, 20, 30 o 40 del ciclo I amplía la rejilla directamente. Es una decisión del usuario del 2026-10-01: el sistema va antes que los rangos. Cuando lleguen los rangos, una tarea nueva lo sustituirá por las recetas. La versión con recetas de esta tarea está en el commit 6238cab de la rama, como referencia.

Esta tarea también pone en la pantalla de resultado de la forja las aristas de la pieza y, si es legendaria, su habilidad (spec, apartado 9.3).

**Files:**
- Modify: `scripts/autoload/InventoryManager.gd`, `scripts/autoload/GameManager.gd`, `scripts/ui/HeroViewOverlay.gd`, `scripts/ui/CraftResultScreen.gd` y `locale/textos.csv`
- Test: `scripts/tests/InventoryGridTests.gd`

**Interfaces:**
- Consumes:
  - `GridExpansions.recipe_for_boss_room`, `size_after` e `is_expansion`;
  - de `InventoryManager`: `expansions`, `hero_grid`, `grid_resized` y `_changed`;
  - `GameManager.register_enemy_defeat(level)`, que `CombatController` llama antes de `room_cleared()`: el récord aún no ha pasado de esa sala;
  - `HeroViewOverlay.show_toast(text, color)`;
  - `LegendaryPowers.POWERS` e `is_legendary`.
- Produces:
  - `InventoryManager.apply_grid_expansion(id: StringName) -> bool`;
  - `GameManager.grid_expanded(recipe_id)`, la primera vez que cae el jefe de la sala 10, 20, 30 o 40;
  - `CraftResultScreen._result_line(text, color, font_size) -> Label`.

- [ ] **Step 1: Pruebas que fallan**

```gdscript
# ─── Tarea 12: la rejilla crece al vencer a los jefes ──────────────────

func test_apply_grid_expansion_grows_once() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	check(im.apply_grid_expansion(&"grid_bone_straps") and im.hero_grid_size() == Vector2i(5, 4), "la primera ampliación lleva la rejilla a 5×4")
	check(not im.apply_grid_expansion(&"grid_bone_straps"), "la misma no amplía dos veces")
	check(im.apply_grid_expansion(&"grid_frost_harness") and im.hero_grid_size() == Vector2i(5, 5), "da igual cuál: la siguiente lleva a 5×5")
	check(not im.apply_grid_expansion(&"no_existe"), "algo que no es una ampliación no hace nada")
	await _restore_inventory(saved)


func test_first_boss_kill_grows_the_grid() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var gm := get_node("/root/GameManager")
	var state := {"dungeon": gm.dungeon_state, "best": gm.best_enemy_level, "defeated": gm.enemies_defeated.duplicate()}
	# Niveles ya vencidos: así register_enemy_defeat no desbloquea planos al azar en la prueba
	gm.enemies_defeated[10] = true
	gm.enemies_defeated[60] = true
	var seen := []
	var on_grow := func(id): seen.append(id)
	gm.grid_expanded.connect(on_grow)
	gm.dungeon_state = gm.DungeonState.RUNNING
	gm.best_enemy_level = 10
	gm.register_enemy_defeat(10)
	check(seen == [&"grid_bone_straps"] and im.hero_grid_size() == Vector2i(5, 4), "el jefe de la sala 10 amplía la rejilla (%s)" % [seen])
	gm.best_enemy_level = 11
	gm.register_enemy_defeat(10)
	check(seen.size() == 1 and im.hero_grid_size() == Vector2i(5, 4), "volver a vencerlo no amplía otra vez")
	gm.best_enemy_level = 60
	gm.register_enemy_defeat(60)
	check(seen.size() == 1, "los jefes del ciclo II no amplían")
	gm.grid_expanded.disconnect(on_grow)
	gm.dungeon_state = state.dungeon
	gm.best_enemy_level = state.best
	gm.enemies_defeated = state.defeated
	await _restore_inventory(saved)


func test_result_screen_shows_aristas_and_the_legendary_power() -> void:
	var screen := CraftResultScreen.new()  # sin escena: el script construye la interfaz en _ready
	add_child(screen)
	await get_tree().process_frame
	var rough: Array[Vector2i] = [Vector2i(1, 1)]
	screen._populate_stats({"crafted_item": _piece(&"sword_basic", 0.5, rough)})
	var texts: Array = screen._stats_container.get_children().filter(func(c): return c is Label).map(func(l): return l.text)
	check(texts.has(tr("Aristas: %d") % 1), "dice cuántas aristas trae (%s)" % [texts])
	screen._populate_stats({"crafted_item": _piece(&"sword_basic", 1.0)})
	texts = screen._stats_container.get_children().filter(func(c): return c is Label and not c.is_queued_for_deletion()).map(func(l): return l.text)
	check(texts.has(tr("Sin aristas")), "la legendaria sale sin aristas")
	check(texts.any(func(s): return s.begins_with(tr("Filo perfecto"))), "y con su habilidad (%s)" % [texts])
	screen.queue_free()
	await get_tree().process_frame
```

Run InventoryGridTests. Expected: errores (`apply_grid_expansion`, `grid_expanded` y `_result_line` no existen).

- [ ] **Step 2: `InventoryManager.gd`**

Junto a las funciones de estadísticas:

```gdscript
## Ampliación de la rejilla de Tico: crece al tamaño siguiente, sea cual sea la ampliación. false si ya
## estaba o si `id` no es una ampliación. Hoy la llama GameManager al vencer a los jefes (provisional);
## con los rangos la llamarán las recetas.
func apply_grid_expansion(id: StringName) -> bool:
	if not GridExpansions.is_expansion(id) or id in expansions:
		return false
	expansions.append(id)
	hero_grid.resize(GridExpansions.size_after(expansions.size()))
	grid_resized.emit(hero_grid.size)
	_changed(true)  # las zonas de borde se mueven con la rejilla
	return true
```

- [ ] **Step 3: `GameManager.gd`**

Señal, junto a las demás:

```gdscript
signal grid_expanded(recipe_id)  # la rejilla de Tico crece: primera victoria sobre el jefe 10, 20, 30 o 40
```

Al final de `register_enemy_defeat(level)`, dentro de la función (que ya sale si la partida no está en marcha) y fuera del bloque de la primera victoria:

```gdscript
	# Rejilla de Tico (spec del inventario en rejilla, apartado 7). Provisional hasta que lleguen las
	# recetas con los rangos: la primera vez que cae el jefe de la sala 10, 20, 30 o 40 del ciclo I, la
	# rejilla crece sola. El récord aún no ha pasado de esta sala (room_cleared va después).
	var recipe := GridExpansions.recipe_for_boss_room(level)
	if recipe != &"" and best_enemy_level <= level:
		var inv = get_node_or_null("/root/InventoryManager")
		if inv and inv.has_method("apply_grid_expansion") and inv.apply_grid_expansion(recipe):
			emit_signal("grid_expanded", recipe)
```

- [ ] **Step 4: Aviso en la franja (`HeroViewOverlay.gd`)**

En `_ready()`, dentro del `if _game_manager:`:

```gdscript
		if _game_manager.has_signal("grid_expanded"):
			_game_manager.grid_expanded.connect(func(_id): show_toast(tr("¡La rejilla crece!"), Color("9fe0ff")))
```

- [ ] **Step 5: Pantalla de resultado (`CraftResultScreen.gd`)**

En `_populate_stats(result)`, al final de la función, después del bucle de estadísticas (la variable local `crafted_item` ya existe ahí):

```gdscript
	var aristas_text := tr("Sin aristas") if crafted_item.aristas.is_empty() else tr("Aristas: %d") % crafted_item.aristas.size()
	_stats_container.add_child(_result_line(aristas_text, Color(0.75, 0.7, 0.62), 24))
	var power: Dictionary = LegendaryPowers.POWERS.get(StringName(crafted_item.item_resource.item_id), {})
	if LegendaryPowers.is_legendary(crafted_item) and not power.is_empty():
		_stats_container.add_child(_result_line("%s: %s" % [tr(power.name), tr(power.text)], Color("ffa629"), 26))
```

```gdscript
func _result_line(text: String, color: Color, font_size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 5)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l
```

- [ ] **Step 6: Textos**

Fila en `locale/textos.csv` ("Sin aristas" y "Aristas: %d" ya vienen de la tarea 10):

```
¡La rejilla crece!,¡La rejilla crece!,The grid grows!
```

Run: `bash D:/Proyectos/PetJam-inventario/.superpowers/sdd/2026-09-27-inventario-en-rejilla/godot-run.sh --import`

- [ ] **Step 7: Ejecutar y ver que pasa**

Run: la batería. Expected: 0 fallos.

- [ ] **Step 8: Commit**

```bash
git add scripts/autoload/InventoryManager.gd scripts/autoload/GameManager.gd scripts/ui/HeroViewOverlay.gd scripts/ui/CraftResultScreen.gd scripts/tests/InventoryGridTests.gd locale/textos.csv
git commit -m "feat: la rejilla crece al vencer a los jefes del ciclo I (provisional) y el resultado de la forja enseña aristas y habilidad"
```

---

### Task 13: Consumibles: huecos y pociones que se beben solas

**Files:**
- Create: `scripts/core/Potions.gd`
- Modify:
  - `scripts/autoload/InventoryManager.gd` (huecos y guardado), `scripts/autoload/GameManager.gd` (beber) y `scripts/gameplay/Corridor.gd` (jefe);
  - interfaz: `scripts/ui/ShopPanel.gd` (compra al hueco), `scripts/ui/EquipmentPanel.gd` (huecos) y `scripts/ui/HeroViewOverlay.gd` (cuántas quedan);
  - pruebas y textos: `scripts/tests/GameplayTests.gd` (pruebas de pociones), `scripts/tests/VisualCapture.gd` (plan `potions`), `scripts/tests/TextTests.gd` y `locale/textos.csv`.
- Test: `scripts/tests/InventoryGridTests.gd` y `scripts/tests/GameplayTests.gd`

**Interfaces:**
- Consumes: `GameManager.apply_buff`, `has_buff`, `BUFF_SPEED` y `BUFF_LUCK`; `Hero.hurt` y `Hero.heal`; `Corridor._boss_intro`
- Produces:
  - `Potions` (estática): `SLOTS` (2), `MAX_STACK` (5), `HEAL_BELOW` (0,3) y `CATALOG`. `ShopPanel.POTION_CATALOG` pasa a ser `Potions.CATALOG`;
  - `InventoryManager`:
    - `signal consumables_changed(slots: Array)` y `consumables: Array` (`[{"id": StringName, "count": int}, …]`);
    - `potion_slot_for(id) -> int`, `add_potion(id) -> bool`, `potion_count(id) -> int`, `take_potion(id) -> bool` y `sell_potion_slot(index) -> int`;
  - `GameManager`: `signal potion_drunk(potion_id)`, `drink_potion(id) -> bool` y `on_boss_appeared()`. `register_hero` conecta `Hero.hurt`.

- [ ] **Step 1: Pruebas que fallan**

En `InventoryGridTests.gd`:

```gdscript
# ─── Tarea 13: consumibles ─────────────────────────────────────────────

func test_potion_slots_hold_two_kinds_up_to_five() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	for i in 5:
		check(im.add_potion(&"potion_speed"), "la Velocidad %d entra en su hueco" % (i + 1))
	check(not im.add_potion(&"potion_speed"), "la sexta no cabe (5 como máximo)")
	check(im.add_potion(&"potion_luck"), "la Suerte va al otro hueco")
	check(not im.add_potion(&"potion_heal"), "la Vida no tiene hueco: los dos están ocupados")
	check(im.take_potion(&"potion_luck") and im.potion_count(&"potion_luck") == 0, "al beberse la última, el hueco queda libre")
	check(im.add_potion(&"potion_heal"), "y ya entra la Vida")
	var gold := im.sell_potion_slot(0)
	check(gold == roundi(5 * Potions.CATALOG[&"potion_speed"].price * 0.5) and im.potion_count(&"potion_speed") == 0, "vender un hueco da la mitad de lo que costó (%d)" % gold)
	var data: Dictionary = im.to_save_data()
	im.load_save_data(data, 1)
	check(im.potion_count(&"potion_heal") == 1, "los huecos se guardan")
	await _restore_inventory(saved)


func test_boss_drinks_speed_and_luck_once() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var gm := get_node("/root/GameManager")
	var wall: int = gm.wall_room
	gm.wall_room = 0  # sin muro (la partida del usuario puede tener uno)
	gm.clear_buffs()
	im.add_potion(&"potion_speed")
	im.add_potion(&"potion_speed")
	im.add_potion(&"potion_luck")
	gm.on_boss_appeared()
	check(gm.has_buff(&"speed") and gm.has_buff(&"luck"), "al aparecer un jefe se beben Velocidad y Suerte")
	check(im.potion_count(&"potion_speed") == 1 and im.potion_count(&"potion_luck") == 0, "una de cada")
	gm.on_boss_appeared()
	check(im.potion_count(&"potion_speed") == 1, "con el efecto activo no se bebe otra")
	gm.clear_buffs()
	gm.wall_room = wall
	await _restore_inventory(saved)


func test_boss_potions_wait_in_front_of_the_wall() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var gm := get_node("/root/GameManager")
	var state := {"level": gm.current_enemy_level, "wall": gm.wall_room, "locked": gm.room_locked}
	gm.clear_buffs()
	im.add_potion(&"potion_speed")
	gm.wall_room = 11
	gm.room_locked = false
	gm.current_enemy_level = 10  # farmea el jefe de la sala 10, delante del muro
	gm.on_boss_appeared()
	check(im.potion_count(&"potion_speed") == 1 and gm.current_enemy_level == 10, "delante del muro no se bebe: el jefe no se queda a medias")
	gm.room_locked = true
	gm.on_boss_appeared()
	check(im.potion_count(&"potion_speed") == 0 and gm.current_enemy_level == 10, "con candado sí se bebe, y Tico sigue en su sala")
	gm.clear_buffs()
	gm.current_enemy_level = state.level
	gm.wall_room = state.wall
	gm.room_locked = state.locked
	await _restore_inventory(saved)


func test_heal_potion_drinks_itself_below_30_percent() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var gm := get_node("/root/GameManager")
	var hero: Node2D = load("res://scenes/Hero.tscn").instantiate()
	hero.remove_from_group("hero")
	add_child(hero)
	await get_tree().process_frame
	var prev_hero: Node = gm.get_hero()
	gm.register_hero(hero)
	im.add_potion(&"potion_heal")
	hero.take_damage(roundi(hero.max_hp * 0.5), true)
	check(im.potion_count(&"potion_heal") == 1, "al 50 %% no se bebe")
	hero.take_damage(roundi(hero.max_hp * 0.3), true)
	check(hero.hp == hero.max_hp and im.potion_count(&"potion_heal") == 0, "por debajo del 30 %% se bebe sola y cura al máximo (%d/%d)" % [hero.hp, hero.max_hp])
	im.add_potion(&"potion_heal")
	hero.take_damage(hero.max_hp * 10, true)
	check(not hero.alive and im.potion_count(&"potion_heal") == 1, "con Tico caído no se bebe")
	gm.register_hero(prev_hero)
	hero.queue_free()
	await _restore_inventory(saved)
```

En `GameplayTests.gd`, sustituye las pruebas que compraban y aplicaban a la vez:
- `test_speed_potion_boosts_attack_rate_for_30_seconds`;
- `test_rebuying_an_active_potion_renews_it_without_stacking`;
- `test_heal_potion_only_for_a_wounded_hero_standing`;
- `test_no_potion_is_applied_without_enough_gold`.

Las sustituyen estas:

```gdscript
## Vacía los huecos de consumibles y devuelve cómo estaban.
func _empty_potion_slots() -> Array:
	var im := _im()
	var before: Array = im.consumables.duplicate(true)
	for i in im.consumables.size():
		im.consumables[i] = {"id": &"", "count": 0}
	return before


func test_buying_a_potion_puts_it_in_a_slot() -> void:
	var gm := _gm()
	gm.clear_buffs()
	var had := _set_gold(1000)
	var slots := _empty_potion_slots()
	var shop := _new_shop()
	shop._on_buy_potion(&"potion_speed", _price(&"potion_speed"))
	check(_im().potion_count(&"potion_speed") == 1, "la Velocidad va a su hueco")
	check(not gm.has_buff(&"speed"), "no se bebe al comprarla")
	check(_im().get_quantity(&"gold") == 1000 - _price(&"potion_speed"), "y se cobra")
	var wall: int = gm.wall_room
	gm.wall_room = 0  # sin muro: delante de uno no se bebe
	gm.on_boss_appeared()
	check(gm.has_buff(&"speed") and is_equal_approx(gm.buff_remaining(&"speed"), 30.0), "se bebe sola al aparecer un jefe: 30 s")
	gm.clear_buffs()
	gm.wall_room = wall
	shop.free()
	_im().consumables = slots
	_set_gold(had)


func test_no_slot_means_no_charge() -> void:
	var had := _set_gold(10000)
	var slots := _empty_potion_slots()
	var shop := _new_shop()
	shop._on_buy_potion(&"potion_speed", _price(&"potion_speed"))
	shop._on_buy_potion(&"potion_luck", _price(&"potion_luck"))
	var gold: int = _im().get_quantity(&"gold")
	shop._on_buy_potion(&"potion_heal", _price(&"potion_heal"))
	check(_im().get_quantity(&"gold") == gold, "sin hueco para la Vida no se cobra (%d)" % _im().get_quantity(&"gold"))
	check(shop._toast_label.text.contains(tr("No hay hueco")), "y lo avisa («%s»)" % shop._toast_label.text)
	shop.free()
	_im().consumables = slots
	_set_gold(had)


func test_no_potion_is_bought_without_enough_gold() -> void:
	var had := _set_gold(99)  # menos que la poción más barata
	var slots := _empty_potion_slots()
	var shop := _new_shop()
	for pot_id in ShopPanel.POTION_CATALOG:
		shop._on_buy_potion(pot_id, _price(pot_id))
		check(shop._toast_label.text.contains("Oro insuficiente"), "%s sin oro: lo avisa («%s»)" % [pot_id, shop._toast_label.text])
		check(_im().potion_count(pot_id) == 0, "%s sin oro no entra en ningún hueco" % pot_id)
	check(_im().get_quantity(&"gold") == 99, "no se cobra nada (%d)" % _im().get_quantity(&"gold"))
	shop.free()
	_im().consumables = slots
	_set_gold(had)
```

(`test_effects_tick_on_their_own_every_frame` y `test_hud_shows_each_active_effect_with_its_time_left` se quedan: usan `apply_buff`.)

Run: InventoryGridTests y GameplayTests. Expected: errores (`add_potion`, `on_boss_appeared`… no existen).

- [ ] **Step 2: `scripts/core/Potions.gd`**

```gdscript
class_name Potions
extends RefCounted

## Pociones de la tienda (spec doc/specs/2026-09-27-inventario-en-rejilla.md, apartado 8): se compran
## para llevarlas en los huecos de consumibles y se beben solas. Vida, cuando Tico (vivo) baja de
## HEAL_BELOW; Velocidad y Suerte, al aparecer un jefe si su efecto no está activo. Las de efecto
## temporal llevan el id del efecto en GameManager ("buff") y su duración. Nombres y descripciones son
## el texto base: se enseñan con tr().

const SLOTS := 2
const MAX_STACK := 5
const HEAL_BELOW := 0.3
const CATALOG := {
	&"potion_heal": {"display_name": "Poción de Vida", "short": "Vida", "price": 100, "description": "Se bebe sola si a Tico le queda menos del 30 % de vida: cura al máximo"},
	&"potion_speed": {"display_name": "Poción de Velocidad", "short": "Velocidad", "price": 150, "description": "Se bebe sola al aparecer un jefe: ataca un 50 % más rápido (30 s)", "buff": &"speed", "duration": 30.0},
	&"potion_luck": {"display_name": "Poción de Suerte", "short": "Suerte", "price": 200, "description": "Se bebe sola al aparecer un jefe: botín doble el 20 % de las veces (60 s)", "buff": &"luck", "duration": 60.0},
}
```

En `ShopPanel.gd`, sustituye el diccionario de `POTION_CATALOG` y su comentario por:

```gdscript
## Pociones: el catálogo vive en Potions (se compran para los huecos de consumibles y se beben solas)
const POTION_CATALOG := Potions.CATALOG
```

- [ ] **Step 3: Huecos en `InventoryManager.gd`**

```gdscript
signal consumables_changed(slots: Array)

## Huecos de consumibles: [{"id": StringName, "count": int}, …]; id vacío o count 0 = libre
var consumables: Array = _empty_slots()
```

En `clear()`, `consumables = _empty_slots()` y `consumables_changed.emit(consumables)`.

```gdscript
static func _empty_slots() -> Array:
	var out := []
	for i in Potions.SLOTS:
		out.append({"id": &"", "count": 0})
	return out


## Hueco donde entraría una poción de ese tipo: el suyo si no está lleno, o uno libre. -1 si no hay.
func potion_slot_for(id: StringName) -> int:
	for i in consumables.size():
		if consumables[i].id == id and int(consumables[i].count) > 0:
			return i if int(consumables[i].count) < Potions.MAX_STACK else -1
	for i in consumables.size():
		if int(consumables[i].count) <= 0:
			return i
	return -1


## Guarda una poción comprada. false si no hay hueco: la tienda no la cobra.
func add_potion(id: StringName) -> bool:
	var i := potion_slot_for(id)
	if i < 0:
		return false
	var count := int(consumables[i].count) + 1 if consumables[i].id == id else 1
	consumables[i] = {"id": id, "count": count}
	consumables_changed.emit(consumables)
	return true


func potion_count(id: StringName) -> int:
	var n := 0
	for s in consumables:
		if s.id == id:
			n += int(s.count)
	return n


## Saca una poción para beberla. false si no queda ninguna de ese tipo.
func take_potion(id: StringName) -> bool:
	for i in consumables.size():
		if consumables[i].id == id and int(consumables[i].count) > 0:
			var left := int(consumables[i].count) - 1
			consumables[i] = {"id": id if left > 0 else &"", "count": left}
			consumables_changed.emit(consumables)
			return true
	return false


## Vende las pociones de un hueco a mitad de precio y lo deja libre. Devuelve el oro.
func sell_potion_slot(index: int) -> int:
	if index < 0 or index >= consumables.size() or int(consumables[index].count) <= 0:
		return 0
	var info: Dictionary = Potions.CATALOG.get(consumables[index].id, {})
	var gold := roundi(int(consumables[index].count) * int(info.get("price", 0)) * 0.5)
	consumables[index] = {"id": &"", "count": 0}
	add_item(&"gold", gold)
	consumables_changed.emit(consumables)
	return gold
```

Guardado. En `to_save_data()`, en el diccionario que devuelve:

```gdscript
		"consumables": consumables.map(func(s): return {"id": String(s.id), "count": int(s.count)}),
```

En `load_save_data()`, antes de las señales del final:

```gdscript
	consumables = _empty_slots()
	var saved_slots: Array = data.get("consumables", [])
	for i in mini(saved_slots.size(), Potions.SLOTS):
		var s = saved_slots[i]
		if s is Dictionary and Potions.CATALOG.has(StringName(s.get("id", ""))) and int(s.get("count", 0)) > 0:
			consumables[i] = {"id": StringName(s.id), "count": mini(int(s.count), Potions.MAX_STACK)}
	consumables_changed.emit(consumables)
```

- [ ] **Step 4: Beber solas (`GameManager.gd` y `Corridor.gd`)**

```gdscript
signal potion_drunk(potion_id)  # Una poción de los huecos se ha bebido sola


## Bebe una poción de los huecos si queda y aplica su efecto. true si se ha bebido.
func drink_potion(id: StringName) -> bool:
	var inv = get_node_or_null("/root/InventoryManager")
	if inv == null or not inv.has_method("take_potion") or not inv.take_potion(id):
		return false
	var info: Dictionary = Potions.CATALOG.get(id, {})
	if info.has("buff"):
		apply_buff(info.buff, float(info.duration))
	elif id == &"potion_heal" and is_instance_valid(_hero) and _hero.has_method("heal"):
		_hero.heal(_hero.max_hp)
	emit_signal("potion_drunk", id)
	return true


## Tico ha recibido daño: vivo y por debajo del 30 %, bebe una de Vida si la lleva.
func _on_hero_hurt(_amount: int) -> void:
	if is_instance_valid(_hero) and _hero.alive and _hero.hp < _hero.max_hp * Potions.HEAL_BELOW:
		drink_potion(&"potion_heal")


## Aparece un jefe (lo llama el Corridor): Velocidad y Suerte, si las lleva y su efecto no está activo.
## Delante del muro y sin candado no se beben: una poción de efecto manda a Tico al muro (apply_buff llama
## a retry_wall_now) y dejaría este jefe a medias (spec del inventario, apartado 8).
func on_boss_appeared() -> void:
	if wall_room > 0 and not room_locked and current_enemy_level != wall_room:
		return
	for pair in [[&"potion_speed", BUFF_SPEED], [&"potion_luck", BUFF_LUCK]]:
		if not has_buff(pair[1]):
			drink_potion(pair[0])
```

El muro de los rangos ya está en la rama base (commit 5c05938): `apply_buff` llama a `retry_wall_now()`, así que beber sola una poción de efecto reintenta el muro sin nada más. La de Vida no lo reintenta, igual que antes. Si la tarea 0 anotó otros nombres para `wall_room`, `room_locked` o `retry_wall_now`, usa los suyos.

Sustituye `register_hero`:

```gdscript
func register_hero(hero_node: Node) -> void:
	if is_instance_valid(_hero) and _hero.has_signal("hurt") and _hero.hurt.is_connected(_on_hero_hurt):
		_hero.hurt.disconnect(_on_hero_hurt)
	_hero = hero_node
	if is_instance_valid(_hero) and _hero.has_signal("hurt"):
		_hero.hurt.connect(_on_hero_hurt)
	# Aplicar stats de equipo actual al registrar héroe
	_on_equipment_changed({})
```

En `Corridor._boss_intro()`, al final:

```gdscript
	if _game_manager and _game_manager.has_method("on_boss_appeared"):
		_game_manager.on_boss_appeared()
```

- [ ] **Step 5: La tienda compra para los huecos (`ShopPanel.gd`)**

Sustituye `_on_buy_potion` y borra `_potion_block_reason`, `_apply_potion_effect` y `_find_hero`. Comprueba antes con `grep -n "_find_hero\|_apply_potion_effect\|_potion_block_reason" scripts/ui/ShopPanel.gd` que nadie más las usa.

```gdscript
func _on_buy_potion(pot_id: StringName, price: int) -> void:
	if not _inventory_manager:
		return
	var gold: int = _inventory_manager.get_quantity(&"gold")
	if gold < price:
		_show_toast("❌ %s" % tr("Oro insuficiente"), Color(1.0, 0.3, 0.3))
		return
	# Se compra para llevarla en un hueco de consumibles; si no hay hueco, ni se compra ni se cobra
	if not _inventory_manager.add_potion(pot_id):
		_show_toast(tr("No hay hueco"), Color(1.0, 0.65, 0.3))
		return
	_inventory_manager.consume_materials({&"gold": price})
	var info: Dictionary = POTION_CATALOG.get(pot_id, {})
	_show_toast("✅ %s" % (tr("%s: %d en el hueco") % [tr(info.get("display_name", String(pot_id))), _inventory_manager.potion_count(pot_id)]), Color(0.3, 1.0, 0.3))
	item_purchased.emit(pot_id, 1, price)
	_update_potion_cards()
```

En `_create_potion_card`, después de la descripción:

```gdscript
	var owned := Label.new()
	owned.name = "OwnedLabel"
	owned.add_theme_font_size_override("font_size", 22)
	owned.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(owned)
```

```gdscript
## "En hueco: N" en cada tarjeta de poción.
func _update_potion_cards() -> void:
	if not _potions_grid or not _inventory_manager:
		return
	for card in _potions_grid.get_children():
		if not card.has_meta("pot_id"):
			continue
		var label: Label = card.find_child("OwnedLabel", true, false)
		if label:
			label.text = tr("En hueco: %d") % _inventory_manager.potion_count(card.get_meta("pot_id"))
```

Llama a `_update_potion_cards()` al final de `_populate_potions()`. En `_ready()`:

```gdscript
	if _inventory_manager and _inventory_manager.has_signal("consumables_changed"):
		_inventory_manager.consumables_changed.connect(func(_slots): _update_potion_cards())
```

- [ ] **Step 6: Huecos en el panel de Equipo (`EquipmentPanel.gd`)**

Constantes y variables:

```gdscript
const POTION_SLOT_RECTS := [Rect2(780, 300, 220, 120), Rect2(780, 440, 220, 120)]
var _potion_slots: Array[Label] = []
```

En `_build()`, antes de `_ghost_layer`:

```gdscript
	for r in POTION_SLOT_RECTS:
		var slot := Label.new()
		slot.position = r.position
		slot.size = r.size
		slot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		slot.add_theme_font_size_override("font_size", 28)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.16, 0.11, 0.09, 0.9)
		style.border_color = Color(0.55, 0.41, 0.24)
		style.set_border_width_all(3)
		style.set_corner_radius_all(12)
		slot.add_theme_stylebox_override("normal", style)
		add_child(slot)
		_potion_slots.append(slot)
```

En `_ready()`: `_im.consumables_changed.connect(func(_s): _refresh_if_open())`. En `_refresh()`, `_refresh_potions()`:

```gdscript
func _refresh_potions() -> void:
	for i in _potion_slots.size():
		var s: Dictionary = _im.consumables[i]
		_potion_slots[i].text = "%s ×%d" % [tr(Potions.CATALOG[s.id].short), int(s.count)] if int(s.count) > 0 else tr("Hueco libre")


func _potion_slot_at(pos: Vector2) -> int:
	for i in POTION_SLOT_RECTS.size():
		if POTION_SLOT_RECTS[i].has_point(pos) and int(_im.consumables[i].count) > 0:
			return i
	return -1
```

El dedo sobre un hueco: tocarlo enseña la poción en la ficha y mantenerlo pulsado ofrece venderla.
- En `_on_press`, después de la comprobación de la ficha y la confirmación, y antes de `_piece_at`:

```gdscript
	var potion := _potion_slot_at(pos)
	if potion >= 0:
		_press = {"slot": potion, "item": null, "from": &"slot", "pos": pos, "time": Time.get_ticks_msec(), "long_done": false}
		get_viewport().set_input_as_handled()
		return
```

- En `_on_motion`, justo después de `if _press.is_empty(): return`: `if _press.has("slot"): return`.
- En `_on_release`, justo después de `get_viewport().set_input_as_handled()`:

```gdscript
	if _press.has("slot"):
		if not _press.long_done:
			var s: Dictionary = _im.consumables[_press.slot]
			_ficha_label.text = "%s\n%s" % [tr(Potions.CATALOG[s.id].display_name), tr(Potions.CATALOG[s.id].description)]
		_cancel_press()
		return
```

- `_process` pasa a tener en cuenta los huecos:

```gdscript
func _process(_delta: float) -> void:
	if _press.is_empty() or _dragging or _scrolling or _press.long_done:
		return
	if Time.get_ticks_msec() - int(_press.time) < LONG_PRESS_MS:
		return
	_press.long_done = true
	if _press.has("slot"):
		_ask_sell_potions(_press.slot)
	elif _press.item:
		_selected = _press.item
		_refresh_ficha()
		_open_card(_press.item)


## Pulsación larga en un hueco: vender sus pociones a mitad de precio (la única forma de cambiar de tipo).
func _ask_sell_potions(index: int) -> void:
	var s: Dictionary = _im.consumables[index]
	var info: Dictionary = Potions.CATALOG[s.id]
	var gold := roundi(int(s.count) * int(info.price) * 0.5)
	_confirm(tr("¿Vender %d %s por %d de oro?") % [int(s.count), tr(info.short), gold], func():
		if _im.sell_potion_slot(index) > 0:
			Sfx.play(&"loot_coins")
		_refresh()
	)
```

- [ ] **Step 7: Cuántas quedan, en la franja (`HeroViewOverlay.gd`)**

Variable `_potion_label: Label`. En `_build()` créala como las de efecto: `_make_label(22, Color("ffe7b0"), HORIZONTAL_ALIGNMENT_LEFT)`, añadida al overlay. Al final de `_refresh_buffs()` va debajo de los efectos activos:

```gdscript
	# Pociones que quedan en los huecos (spec del inventario, apartado 8), debajo de los efectos activos
	var parts := []
	if _inventory and "consumables" in _inventory:
		for s in _inventory.consumables:
			if int(s.count) > 0:
				parts.append("%s ×%d" % [tr(Potions.CATALOG[s.id].short).to_upper(), int(s.count)])
	_potion_label.visible = not parts.is_empty()
	_potion_label.text = " · ".join(parts)
	_potion_label.position = BUFF_POS + Vector2(0, BUFF_ROW * row)
```

(`row` es el contador de filas que ya usa `_refresh_buffs`.)

- [ ] **Step 8: Plan de captura `potions`**

En `VisualCapture._run_potions_plan()`, las compras llenan los huecos y la captura provoca que se beban. Sustituye desde `for pot_id in [&"potion_speed", &"potion_luck"]:` hasta el final de la función:

```gdscript
	for pot_id in [&"potion_speed", &"potion_luck"]:
		shop._on_buy_potion(pot_id, int(ShopPanel.POTION_CATALOG[pot_id].price))
	# Aparece un "jefe": se beben Velocidad y Suerte solas (indicadores con su tiempo)
	gm.on_boss_appeared()
	# Poción de Vida con Tico herido: se bebe sola al bajar del 30 %
	await get_tree().create_timer(1.5).timeout
	shop._on_buy_potion(&"potion_heal", int(ShopPanel.POTION_CATALOG[&"potion_heal"].price))
	var hero: Node = gm.get_hero()
	if hero and hero.alive:
		hero.take_damage(int(hero.max_hp * 0.75), true)
	# Adelanta el reloj: a la Velocidad le quedan 4 s (parpadea y luego desaparece)
	await get_tree().create_timer(7.5).timeout
	gm.tick_buffs(gm.buff_remaining(&"speed") - 4.0)
```

Actualiza su línea en la cabecera de planes del fichero: "compra Velocidad y Suerte (a los huecos), las bebe al aparecer un jefe y bebe la Vida al bajar del 30 %".

Si la compra de Suerte no cabe porque la Vida ocupa un hueco, vacía antes los huecos con `inv.consumables = inv._empty_slots()`.

- [ ] **Step 9: Textos**

En `TextTests._code_table_texts()`, junto a las pociones de `ShopPanel`:

```gdscript
	for id in Potions.CATALOG:
		out.append([String(Potions.CATALOG[id].short), "Potions.CATALOG"])
```

Filas en `locale/textos.csv` (comprueba antes "Vida", "Velocidad" y "Suerte": alguna puede existir ya):

```
Se bebe sola si a Tico le queda menos del 30 % de vida: cura al máximo,Se bebe sola si a Tico le queda menos del 30 % de vida: cura al máximo,Drunk automatically when Tico drops below 30 % health: fully heals
Se bebe sola al aparecer un jefe: ataca un 50 % más rápido (30 s),Se bebe sola al aparecer un jefe: ataca un 50 % más rápido (30 s),Drunk automatically when a boss appears: attacks 50 % faster (30 s)
Se bebe sola al aparecer un jefe: botín doble el 20 % de las veces (60 s),Se bebe sola al aparecer un jefe: botín doble el 20 % de las veces (60 s),Drunk automatically when a boss appears: double loot 20 % of the time (60 s)
Vida,Vida,Health
Velocidad,Velocidad,Speed
Suerte,Suerte,Luck
No hay hueco,No hay hueco,No free slot
%s: %d en el hueco,%s: %d en el hueco,%s: %d in the slot
En hueco: %d,En hueco: %d,In slot: %d
Hueco libre,Hueco libre,Empty slot
¿Vender %d %s por %d de oro?,¿Vender %d %s por %d de oro?,Sell %d %s for %d gold?
```

Las filas de las descripciones viejas de las pociones y de los avisos borrados ("Tico ya tiene la vida llena"…) pueden quedarse en el CSV: no molestan. Bórralas solo si `TextTests` protesta.

Run: `--import`

- [ ] **Step 10: Ejecutar y capturar**

Run: la batería. Expected: 0 fallos.

Captura el plan `potions` (copia y restaura `save.json`). Abre con Read los fotogramas y comprueba:
- las compras no aplican nada;
- al "aparecer el jefe" se encienden VELOCIDAD y SUERTE;
- Tico herido bebe la Vida sola (+N verde);
- la línea de pociones restantes se ve debajo de los efectos.

- [ ] **Step 11: Commit**

```bash
git add scripts/core/Potions.gd scripts/core/Potions.gd.uid scripts/autoload/InventoryManager.gd scripts/autoload/GameManager.gd scripts/gameplay/Corridor.gd scripts/ui/ShopPanel.gd scripts/ui/EquipmentPanel.gd scripts/ui/HeroViewOverlay.gd scripts/tests/InventoryGridTests.gd scripts/tests/GameplayTests.gd scripts/tests/VisualCapture.gd scripts/tests/TextTests.gd locale/textos.csv
git commit -m "feat: consumibles: 2 huecos, pociones que se beben solas (Vida bajo el 30 %, Velocidad y Suerte ante un jefe)"
```

---

### Task 14: Arte de las piezas (aplazada)

Aplazada por decisión del usuario (2026-10-01): el arte se decide al final, en la tarjeta "Arte del inventario en rejilla" del tablero. Es un prototipo personal y los estilos pueden mezclarse mientras tanto.

Mientras tanto, las piezas se dibujan con casillas de color (tarea 8). No hay nada que hacer en esta tarea: el ejecutor la marca como completa sin dispatch.

La versión anterior de esta tarea dibujaba las piezas en pixel art con la rampa de la fase 2 pixel. Sirve de referencia para la tarjeta del arte y está en el commit cbcba6d. Ya no aplica: el spec de pegatinas (rama `franja-pegatinas`) dejó la fase 2 pixel sin usar.

---

### Task 15: El arte en el juego (aplazada)

Aplazada con la tarea 14: no hay nada que hacer. Las vistas ya aceptan una textura por pieza (`sprite_for` en `GearGridView` y `LootStripView`, tarea 8) para cuando llegue el arte. La versión anterior (`GearSprites`, casillas, zonas, destello e iconos de pociones) está en el commit cbcba6d.

---

### Task 16: Balance con rejillas llenas (aplazada)

**Aplazada** hasta que estén Balanza y los rangos (decisión del usuario, 2026-10-01). El ejecutor la marca como completa sin dispatch, y se retoma después con lo que hayan dejado. El texto se queda como referencia.

**Files:**
- Modify:
  - `scripts/tests/BalanceSim.gd`;
  - `data/items/*.tres` (estadísticas por casilla);
  - si la calibración lo pide: `scripts/core/GearAuras.gd`, `scripts/core/LegendaryPowers.gd`, `scripts/core/Ranks.gd`, `scripts/core/EnemyScaling.gd` y `scripts/gameplay/Enemy.gd` (tanda de botín);
  - si los rangos se calibraron con Balanza (tarea 0): `balance/` y el enlace de PetJam con Balanza;
  - `doc/specs/2026-09-27-inventario-en-rejilla.md` (valores calibrados).
- Test: `scripts/tests/BalanceSim.gd`

**Interfaces:**
- Consumes:
  - de este plan: `GearGrid`, `GearPacker.find_spot`, `GearAuras.totals/STATS`, `LegendaryPowers.active/effects/BURN_TIME`, `CombatMath.hero_stats_with_powers`, `GridExpansions.size_after/unlocked_for_record/MAX_SIZE` y `PieceShape.aristas_for_tier`;
  - del juego: `CombatMath.hero_stats/expected_dps/armor_mitigation`, `EnemyScaling.enemy_stats`, `Biomes.is_boss_room`, `EnemyArchetypes.get_data/pick_for_room` y, de `Ranks`, `TIERS`, `TIER_*`, `ROOMS_PER_CYCLE`, `MID_CYCLE_OFFSET`, `first_room_of_cycle` y `recipe`;
  - de la `BalanceSim` de los rangos: `CYCLES` y `MAX_ROOM`. Si no existen, créalos con 5 y 400.
- Produces, en `BalanceSim`:
  - las constantes `SLOT_ITEMS`, `MIXES`, `LADDER_QUALITIES`, `QUALITY_MILESTONE`, `LADDER_MAX_STEP`, `PER_CELL_SPREAD`, `LEVEL_PER_CELL`, `LEVEL_PER_CELL_TOLERANCE`, `MAX_VICTORY_RATIO` y `RANKS_DROP_QTY`;
  - `grid_size_at(room, rank) -> Vector2i` y `grid_build(tier, quality, rank, size, mix) -> GearGrid`;
  - `grid_hero(grid) -> Dictionary`, con los efectos de combate en la clave `effects`;
  - `wins_duel_fx(hero, room) -> bool` y `grid_wall(tier, quality, rank, max_room) -> int`;
  - las pruebas `test_report_grid_table`, `test_grid_balance_targets`, `test_grid_ladder`, `test_power_per_cell_is_level_by_level` y `test_filling_the_grid_costs_about_the_same_victories`.

Esta tarea calibra. Los objetivos son los del spec de rangos revisado (apartado 6): hitos con calidad 0,85, cotas con 1,00 y la escalera. La tarea 0 dice con qué herramienta los calibraron los rangos: `BalanceSim` sola o con Balanza. Esta tarea usa la misma.

- [ ] **Step 1: Duelos con rejillas en `BalanceSim`**

Añade al final de `scripts/tests/BalanceSim.gd`:

```gdscript
# ─── Inventario en rejilla (spec doc/specs/2026-09-27-inventario-en-rejilla.md, apartado 6) ────

## Pieza de cada tipo por nivel.
const SLOT_ITEMS := {
	&"basic": {"main_hand": &"sword_basic", "off_hand": &"shield_basic", "head": &"helmet_basic", "feet": &"boots_basic"},
	&"advanced": {"main_hand": &"sword_advanced", "off_hand": &"shield_advanced", "head": &"helmet_advanced", "feet": &"boots_advanced"},
	&"master": {"main_hand": &"sword_masterwork", "off_hand": &"shield_master", "head": &"helmet_master", "feet": &"boots_master"},
}
## Orden en que el llenado intenta meter cada tipo: equilibrada, ofensiva y defensiva.
const MIXES := [
	["main_hand", "off_hand", "head", "feet"],
	["main_hand", "main_hand", "off_hand", "head", "main_hand", "feet"],
	["off_hand", "head", "feet", "main_hand", "off_hand", "head"],
]
## Escalera e hitos del spec de rangos (apartado 6). Si los rangos los dejaron con otros números (tarea 0),
## usa los suyos.
const LADDER_QUALITIES := [0.40, 0.55, 0.70, 0.85, 1.00]
const QUALITY_MILESTONE := 0.85
const LADDER_MAX_STEP := 6
## Poder por casilla (spec del inventario, apartado 6)
const PER_CELL_SPREAD := 1.2  ## a igual nivel, la pieza que más da por casilla no pasa de ×1,2 la que menos
const LEVEL_PER_CELL := {&"advanced": 1.3, &"master": 1.6}  ## frente al básico
const LEVEL_PER_CELL_TOLERANCE := 0.15
## Materiales: llenar la rejilla cuesta como mucho un 25 % más de victorias que las 4 piezas de los rangos
const MAX_VICTORY_RATIO := 1.25
const RANKS_DROP_QTY := 15  ## Enemy.MATERIAL_DROP_QTY tal como lo dejaron los rangos (tarea 0)
const ENEMY_SCRIPT := preload("res://scripts/gameplay/Enemy.gd")

static var _grids := {}


## Tamaño de la rejilla de Tico al llegar a la sala `room` con equipo de rango `rank`. En el ciclo I crece
## una vez por cada jefe de las salas 10 a 40 ya vencido (su receta se forja en cuanto sale). Con equipo de
## rango II o más, el ciclo I ya se acabó: 6×6.
static func grid_size_at(room: int, rank: int) -> Vector2i:
	if rank >= 2:
		return GridExpansions.MAX_SIZE
	return GridExpansions.size_after(GridExpansions.unlocked_for_record(room).size())


## Rejilla llena con piezas de un nivel, calidad y rango, en el orden de la mezcla, hasta que no cabe
## ninguna más. Cada pieza lleva las aristas de su calidad en sus primeros sitios. En caché: con los
## mismos datos sale la misma.
static func grid_build(tier: StringName, quality: float, rank: int, size: Vector2i, mix: Array) -> GearGrid:
	var key := "%s|%.2f|%d|%s|%s" % [tier, quality, rank, size, mix]
	if _grids.has(key):
		return _grids[key]
	var grid := GearGrid.new(size)
	var placed := true
	while placed:
		placed = false
		for slot in mix:
			var res: ItemResource = load("res://data/items/%s.tres" % SLOT_ITEMS[tier][slot])
			var item := CraftedItem.new(res, quality, rank)
			var rough: Array[Vector2i] = []
			rough.assign(res.arista_spots.slice(0, PieceShape.aristas_for_tier(item.get_quality_tier())))
			item.aristas = rough
			var spot := GearPacker.find_spot(grid, item)
			if not spot.is_empty() and grid.place(item, spot.cell, spot.rot):
				placed = true
	_grids[key] = grid
	return grid


## Tico con una rejilla: estadísticas con auras, zonas, tope y habilidades, y en "effects" los efectos de
## combate de sus legendarias.
static func grid_hero(grid: GearGrid) -> Dictionary:
	var powers := LegendaryPowers.active(grid.items)
	var hero := CombatMath.hero_stats_with_powers(GearAuras.totals(grid), powers)
	hero["effects"] = LegendaryPowers.effects(powers)
	return hero


## Daño por segundo del pulso mágico de unas estadísticas, con la fórmula del juego (sin golpes).
static func _pulse_dps(stats: Dictionary) -> float:
	return CombatMath.expected_dps(stats.merged({"aps": 0.0}, true))


## true si Tico gana el duelo de la sala `room` con la vida llena (spec de rangos, apartado 7). Sin azar,
## como los rangos: daño esperado por segundo de cada lado y tiempo hasta matar. Las habilidades
## legendarias cuentan por su valor esperado (spec del inventario, apartado 6).
static func wins_duel_fx(hero: Dictionary, room: int) -> bool:
	var fx: Dictionary = hero.effects
	var boss := Biomes.is_boss_room(room)
	var arch := EnemyArchetypes.get_data(&"boss" if boss else EnemyArchetypes.pick_for_room(room))
	var enemy := EnemyScaling.enemy_stats(room, arch, boss)
	# Lo que recibe Tico: golpes con su armadura, esquiva y parada; el pulso no se esquiva ni se para
	var enemy_pulse := _pulse_dps(enemy)
	var enemy_hits := (CombatMath.expected_dps(enemy, CombatMath.armor_mitigation(int(hero.armor), room)) - enemy_pulse) * (1.0 - float(fx.dodge)) * (1.0 - float(fx.block))
	# Lo que hace Tico: golpes (a veces dobles), pulso, quemadura (una viva como mucho) y espinas
	var hit := float(hero.dmg) * (1.0 + float(hero.crit_p) * (float(hero.crit_m) - 1.0))
	var burn := hit * float(fx.burn) * minf(float(hero.aps), 1.0 / LegendaryPowers.BURN_TIME)
	var dps := float(hero.aps) * hit * (1.0 + float(fx.double_hit)) + _pulse_dps(hero) + burn + enemy_hits * float(fx.thorns)
	# Ímpetu: el primer golpe vale first_strike golpes
	var enemy_hp := maxf(1.0, float(enemy.max_hp) - maxf(0.0, float(fx.first_strike) - 1.0) * hit)
	var time := enemy_hp / maxf(dps, 0.001)
	var drain := enemy_hits + enemy_pulse - float(hero.max_hp) * float(fx.regen)
	return drain * time < float(hero.max_hp) * (1.0 + float(fx.second_chance))


## Muro de un equipo en rejilla (spec de rangos, apartado 6): la primera sala, desde la 1, cuyo duelo no
## gana Tico, con la mejor de las mezclas. En cada sala, la rejilla tiene su tamaño de entonces.
## max_room + 1 si las gana todas.
static func grid_wall(tier: StringName, quality: float, rank: int, max_room: int = MAX_ROOM) -> int:
	var best := 0
	for mix in MIXES:
		var heroes := {}
		var wall := max_room + 1
		for room in range(1, max_room + 1):
			var size := grid_size_at(room, rank)
			if not heroes.has(size):
				heroes[size] = grid_hero(grid_build(tier, quality, rank, size, mix))
			if not wins_duel_fx(heroes[size], room):
				wall = room
				break
		best = maxi(best, wall)
	return best


## Poder de unas estadísticas de equipo: log del daño esperado por la vida efectiva, con la armadura frente
## a la sala `room`. Métrica continua: nota los cambios pequeños.
static func _power(equipment: Dictionary, room: int) -> float:
	var hero := CombatMath.hero_stats(equipment)
	var ehp := float(hero.max_hp) / (1.0 - CombatMath.armor_mitigation(int(hero.armor), room))
	return log(CombatMath.expected_dps(hero) * ehp)


## Poder por casilla limpia de una pieza: lo que sube _power al añadirla a una rejilla básica de 5×4 de su
## rango, a mitad del ciclo de ese rango.
static func _power_per_cell(item_id: StringName, rank: int) -> float:
	var room := Ranks.first_room_of_cycle(rank) + Ranks.MID_CYCLE_OFFSET
	var ref: Dictionary = GearAuras.totals(grid_build(Ranks.TIER_BASIC, QUALITY_MILESTONE, rank, GridExpansions.size_after(1), MIXES[0]))
	var res: ItemResource = load("res://data/items/%s.tres" % item_id)
	var item := CraftedItem.new(res, QUALITY_MILESTONE, rank)
	var with := ref.duplicate()
	for s in GearAuras.STATS:
		with[s] = with[s] + item.calculated_stats.get(s, 0)
	return (_power(with, room) - _power(ref, room)) / float(res.shape_cells.size())


static func _avg_power_per_cell(tier: StringName, rank: int) -> float:
	var sum := 0.0
	for slot in SLOT_ITEMS[tier]:
		sum += _power_per_cell(SLOT_ITEMS[tier][slot], rank)
	return sum / float(SLOT_ITEMS[tier].size())


## Materiales de las piezas de una rejilla de un nivel, con la receta de su rango.
func _grid_materials(grid: GearGrid, tier: StringName, rank: int) -> int:
	var dm := get_node("/root/DataManager")
	var total := 0
	for item in grid.items:
		var recipe := Ranks.recipe(dm.get_blueprint(StringName(item.item_resource.item_id)).materials, tier, rank)
		for m in recipe:
			total += int(recipe[m])
	return total


func test_report_grid_table() -> void:
	print("rango | pieza    | calidad | muro con rejilla")
	for rank in range(1, CYCLES + 1):
		for tier in Ranks.TIERS:
			for q in LADDER_QUALITIES:
				print("%5d | %-8s | %.2f    | %d" % [rank, tier, q, grid_wall(tier, q, rank)])
	check(true, "tabla impresa")


## Hitos y cotas del spec de rangos (apartado 6) con rejillas llenas. "Llega" es la última sala ganada, la
## anterior al muro.
func test_grid_balance_targets() -> void:
	for n in range(1, CYCLES + 1):
		var base := Ranks.ROOMS_PER_CYCLE * (n - 1)
		var rows := [
			[Ranks.TIER_BASIC, 20, 40, "vence al jefe %d", "no vence al jefe %d"],
			[Ranks.TIER_ADVANCED, 40, 50, "vence al jefe %d", "no acaba el ciclo en la sala %d"],
			[Ranks.TIER_MASTER, 50, 60, "acaba el ciclo en la sala %d", "no vence al jefe %d del ciclo siguiente"],
		]
		for row in rows:
			var reach := grid_wall(row[0], QUALITY_MILESTONE, n) - 1
			var reach_top := grid_wall(row[0], 1.0, n) - 1
			check(reach >= base + int(row[1]), "rango %d, %s a 0,85: %s (llega a %d)" % [n, row[0], String(row[3]) % (base + int(row[1])), reach])
			check(reach_top < base + int(row[2]), "rango %d, %s a 1,00: %s (llega a %d)" % [n, row[0], String(row[4]) % (base + int(row[2])), reach_top])


## Escalera del spec de rangos (apartado 6): los 15 estados (nivel × calidad) en orden; de uno al
## siguiente, el muro avanza de 0 a LADDER_MAX_STEP salas.
func test_grid_ladder() -> void:
	for n in range(1, CYCLES + 1):
		var walls := []
		for tier in Ranks.TIERS:
			for q in LADDER_QUALITIES:
				walls.append(grid_wall(tier, q, n))
		for i in range(1, walls.size()):
			var step: int = walls[i] - walls[i - 1]
			check(step >= 0 and step <= LADDER_MAX_STEP, "rango %d: del estado %d al %d el muro avanza %d salas (%s)" % [n, i - 1, i, step, walls])


func test_power_per_cell_is_level_by_level() -> void:
	for tier in Ranks.TIERS:
		var values := {}
		for slot in SLOT_ITEMS[tier]:
			values[slot] = _power_per_cell(SLOT_ITEMS[tier][slot], 1)
		var lo: float = values.values().min()
		var hi: float = values.values().max()
		check(lo > 0.0 and hi / lo <= PER_CELL_SPREAD, "%s: poder por casilla parecido entre piezas (%s)" % [tier, values])
	var basic := _avg_power_per_cell(Ranks.TIER_BASIC, 1)
	for tier in LEVEL_PER_CELL:
		var ratio := _avg_power_per_cell(tier, 1) / basic
		check(absf(ratio - float(LEVEL_PER_CELL[tier])) <= LEVEL_PER_CELL_TOLERANCE, "%s: ×%.2f por casilla frente al básico (objetivo ×%.1f)" % [tier, ratio, LEVEL_PER_CELL[tier]])


## Llenar la rejilla entera cuesta más o menos las victorias que los rangos preveían para 4 piezas:
## materiales entre la tanda de botín de ahora, frente a los de 4 piezas entre la tanda de los rangos.
func test_filling_the_grid_costs_about_the_same_victories() -> void:
	var dm := get_node("/root/DataManager")
	for rank in [1, 3]:
		for tier in Ranks.TIERS:
			var grid := grid_build(tier, QUALITY_MILESTONE, rank, GridExpansions.MAX_SIZE, MIXES[0])
			var four := 0
			for slot in SLOT_ITEMS[tier]:
				var recipe := Ranks.recipe(dm.get_blueprint(SLOT_ITEMS[tier][slot]).materials, tier, rank)
				for m in recipe:
					four += int(recipe[m])
			var ratio := (float(_grid_materials(grid, tier, rank)) / float(ENEMY_SCRIPT.MATERIAL_DROP_QTY)) / (float(four) / float(RANKS_DROP_QTY))
			check(ratio <= MAX_VICTORY_RATIO, "rango %d, %s: llenar la rejilla (%d piezas) cuesta ×%.2f victorias frente a 4 piezas" % [rank, tier, grid.items.size(), ratio])
```

Tres ajustes con lo que anotó la tarea 0:
- `RANKS_DROP_QTY` es el valor de `Enemy.MATERIAL_DROP_QTY` tras los rangos. Si los rangos lo multiplican por el rango (`mat_mult`), la cuenta no cambia: las recetas también lo hacen.
- Si `hero_stats_with_powers` recibe el rango del equipo (tarea 4), `grid_hero` le pasa el de la rejilla. Todas sus piezas tienen el mismo: `grid.items[0].rank`, o 1 si está vacía.
- Si los rangos cambiaron las fórmulas del duelo (el pulso, la armadura o cómo se calcula el muro), `wins_duel_fx` las copia de su función de duelo y solo añade los efectos legendarios.

Con la rejilla, 4 piezas ya no son un equipo. Por eso las pruebas de objetivos y de escalera de los rangos (sus nombres, en la tarea 0) y su tabla se sustituyen por `test_grid_balance_targets`, `test_grid_ladder` y `test_report_grid_table`: quita las suyas. Sus funciones de apoyo se quedan si otra prueba las usa. Por ejemplo, `test_armor_matters_at_high_ranks` usa `hero_for`.

Run: `timeout 300 D:/Software/Godot/godot_ver4.5.exe --headless --path . res://scenes/tests/BalanceSim.tscn`
Expected: la tabla impresa y salida 1. Fallan `test_power_per_cell_is_level_by_level` (hoy el casco da unas tres veces más por casilla que las botas), `test_filling_the_grid_costs_about_the_same_victories` (8-10 piezas con la tanda de siempre) y parte de los hitos, las cotas y la escalera.

- [ ] **Step 2: Estadísticas por casilla (punto de partida)**

Reescribe los rangos de los 12 `data/items/*.tres`. El poder por casilla es parecido entre las piezas de un nivel y crece ×1,3 y ×1,6 con el nivel. Es el poder medio por casilla de hoy, repartido. Por casilla limpia y a calidad 1,0 (el mínimo, a calidad 0, es el 45 % del máximo, redondeado):

| Pieza (casillas) | Básico | Avanzado | Maestro |
|---|---|---|---|
| Espada (2 / 3 / 4) | daño 4, crít 0,02, vel 0,04 | daño 5,2, crít 0,026, vel 0,05 | daño 6,4, crít 0,032, vel 0,065 |
| Escudo (2 / 4 / 6) | vida 25, armadura 2,5 | vida 32, armadura 3,2 | vida 40, armadura 4 |
| Casco (1 / 2 / 4) | vida 25, armadura 2,5 | vida 32, armadura 3,2 | vida 40, armadura 4 |
| Botas (1 / 3 / 4) | vida 25, armadura 2,5 | vida 32, armadura 3,2 | vida 40, armadura 4 |

Ejemplos:
- escudo maestro (6 casillas): `base_hp_max = 240`, `base_hp_min = 108`, `base_armor_max = 24` y `base_armor_min = 11`;
- espada básica (2 casillas): `base_damage_max = 8`, `base_damage_min = 4`, `base_crit_max = 0.04`, `base_crit_min = 0.018`, `base_aps_max = 0.08` y `base_aps_min = 0.036`.

Si los rangos cambiaron las estadísticas de las piezas (tarea 0), escala la tabla con ellos: el mismo poder medio por casilla que dejaron, repartido igual.

Si los rangos se calibraron con Balanza, las estadísticas no se escriben a mano (paso 3).

- [ ] **Step 3: Calibrar**

**Con Balanza** (la tarea 0 encontró `addons/balanza/VERSION` y `balance/balance.json`): sigue el método de la skill `balanza`, con estos cambios en el modelo de PetJam:
- el presupuesto de cada pieza crece con sus casillas limpias. Usa el factor de ranura o por objeto que ofrezca Balanza; si solo hay factor por ranura, pregunta al usuario antes de inventar otro;
- el enlace de PetJam recibe el conjunto de las 4 piezas de un nivel y llena la rejilla con copias con `BalanceSim.grid_build`. En Balanza un conjunto no puede llevar dos piezas de la misma ranura;
- el escenario de duelo del enlace mide con `wins_duel_fx` y el muro con `grid_wall`;
- las 12 habilidades legendarias son efectos, con el precio medido con y sin ellas;
- `import` escribe las estadísticas en los `.tres` y conserva `shape_cells` y `arista_spots`. Compruébalo con `git diff data/items`: solo cambian líneas de estadísticas.

**A mano** (sin Balanza): ejecuta BalanceSim y ajusta un valor cada vez hasta que pasen las pruebas de este paso. La tabla impresa dice cuánto falta:

| Si falla… | Toca | En qué dirección |
|---|---|---|
| el poder por casilla de una pieza se sale del ×1,2 | sus rangos en su `.tres` | hacia la media de su nivel |
| el avanzado o el maestro no dan ×1,3 / ×1,6 por casilla | los rangos de ese nivel | todos a la vez, en proporción |
| un hito (calidad 0,85) no llega | `Ranks.stat_mult`, la base de Tico por rango o las constantes de `EnemyScaling` | como hicieron los rangos |
| una cota (calidad 1,00) se pasa | `GearAuras.CAP` o `ZONE_BONUS`, o `EnemyScaling` | bajar el tope antes que tocar la curva |
| solo se pasa con legendarias | las magnitudes de `LegendaryPowers.POWERS` | bajar la que más pese en la tabla |
| un escalón de la escalera pasa de 6 salas | la diferencia entre calidades (el mínimo al 45 %) o entre niveles | acercarlas |
| llenar la rejilla cuesta demasiadas victorias | `Enemy.MATERIAL_DROP_QTY` | subir |

Run (tras cada cambio): `timeout 300 D:/Software/Godot/godot_ver4.5.exe --headless --path . res://scenes/tests/BalanceSim.tscn`

Hay cosas que no se cambian sin preguntar al usuario:
- los objetivos (hitos, cotas y escalera), que son el spec de rangos;
- `PER_CELL_SPREAD`, `LEVEL_PER_CELL` y `MAX_VICTORY_RATIO`.

Si ninguna combinación cumple, para y explícale al usuario qué choca, con la tabla. El choque más probable es el riesgo del ciclo I (spec del inventario, apartado 6): allí la rejilla crece con los jefes y en los demás ciclos siempre mide 6×6.

- [ ] **Step 4: Anotar los valores calibrados**

Al final del apartado 6 del spec del inventario, con los números reales en lugar de los puntos suspensivos y la fecha del día:

```markdown
- **Valores calibrados (<fecha>, con <BalanceSim o Balanza>):** auras 0/5/10/15/20 % → …; zona …; tope …;
  habilidades …; `Ranks.stat_mult` …; base de Tico por rango …; `EnemyScaling` …;
  `Enemy.MATERIAL_DROP_QTY` …; estadísticas por casilla en `data/items/*.tres` (commit de la
  calibración). Tabla de BalanceSim en ese commit.
```

- [ ] **Step 5: Toda la batería en verde**

Run: la batería. Expected: 0 fallos.

Las pruebas que fijaban números de piezas (`RankTests` con `sword_masterwork`, `GameplayTests` con las botas…) comparan proporciones y siguen valiendo. Si alguna fijaba una estadística exacta, actualízala con el valor nuevo y dilo en el informe.

- [ ] **Step 6: Commit**

```bash
git add scripts/tests/BalanceSim.gd data/items/*.tres scripts/core/GearAuras.gd scripts/core/LegendaryPowers.gd scripts/core/Ranks.gd scripts/core/EnemyScaling.gd scripts/gameplay/Enemy.gd doc/specs/2026-09-27-inventario-en-rejilla.md
git commit -m "feat: balance con rejillas llenas: duelos, estadísticas por casilla y valores calibrados"
```

Quita del `git add` los ficheros que la calibración no haya tocado. Con Balanza, añade `balance/` y el enlace de PetJam.

---

### Task 17: Verificación, capturas y documentación

**Files:**
- Modify: `scripts/tests/VisualCapture.gd` (plan `inventory`), `scripts/tests/InventoryGridTests.gd` (rendimiento), `doc/ARCHITECTURE.md`, `doc/ROADMAP.md`, `doc/specs/2026-09-27-inventario-en-rejilla.md` (estado) y `D:/Proyectos/CONTROL/Tableros/Futuro/PetJam.md` (fuera del repo)

- [ ] **Step 1: Plan de captura `inventory`**

En `VisualCapture.gd`, en la cabecera de planes:

```
##   inventory → rejilla de 6×6 con piezas (una legendaria y una con aristas), mochila y botín; arrastra
##               una pieza del botín hasta Tico con intercambio y abre la ficha de la legendaria
```

En el `match _plan:`, `"inventory": _run_inventory_plan()`, y:

```gdscript
func _run_inventory_plan() -> void:
	await get_tree().create_timer(1.0).timeout
	var hud := _hud()
	var im := get_node_or_null("/root/InventoryManager")
	if hud == null or im == null:
		return
	im.clear()
	for id in GridExpansions.ids():
		im.apply_grid_expansion(id)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	# Pieza nueva con sus aristas. En una rejilla va a `cell` si cabe allí y, si no, al primer sitio libre
	var add := func(id: StringName, quality: float, place: StringName, cell: Vector2i) -> CraftedItem:
		var res: ItemResource = load("res://data/items/%s.tres" % id)
		var item := CraftedItem.new(res, quality)
		item.aristas = PieceShape.roll_aristas(res, item.get_quality_tier(), rng)
		im.add_crafted_item(item)
		var grid: GearGrid = im.grid_for(place)
		if grid:
			var spot: Dictionary = {"cell": cell, "rot": 0} if grid.fits(item, cell, 0) else GearPacker.find_spot(grid, item)
			if not spot.is_empty():
				im.move_item(item, place, spot.cell, spot.rot)
		return item
	add.call(&"sword_masterwork", 1.0, InventoryManager.PLACE_HERO, Vector2i(5, 0))  # legendaria (Filo ígneo), de pie en la columna derecha
	add.call(&"shield_master", 0.95, InventoryManager.PLACE_HERO, Vector2i(0, 2))
	add.call(&"helmet_master", 0.8, InventoryManager.PLACE_HERO, Vector2i(1, 0))  # rara: 1 arista
	add.call(&"boots_master", 0.95, InventoryManager.PLACE_HERO, Vector2i(2, 3))
	add.call(&"shield_basic", 0.6, InventoryManager.PLACE_BAG, Vector2i(0, 0))
	add.call(&"boots_basic", 0.3, InventoryManager.PLACE_LOOT, Vector2i.ZERO)
	add.call(&"helmet_advanced", 1.0, InventoryManager.PLACE_LOOT, Vector2i.ZERO)
	add.call(&"sword_advanced", 0.93, InventoryManager.PLACE_LOOT, Vector2i.ZERO)  # épica, sin aristas: la última añadida va delante
	hud._on_delivery_pressed()
	await get_tree().create_timer(1.5).timeout
	var panel: Node = hud.equipment_panel
	# Arrastre: la espada nueva, del botín a la columna derecha de Tico. Tres giros con la R la ponen de pie
	# y cae encima de la maestra: se intercambian y la maestra vuelve al botín, delante.
	var start: Vector2 = panel._loot_view.global_position + Vector2(60, 165)
	panel._on_press(start)
	var grab: Vector2 = panel._press.origin - panel._press.pos
	var finish: Vector2 = panel._hero_view.global_position + Vector2(5, 0) * GearGridView.CELL - grab + Vector2(0.0, GearGridView.CELL)
	for i in 12:
		panel._on_motion(start.lerp(finish, float(i + 1) / 12.0))
		if i in [4, 6, 8]:
			panel._rotate_drag()
		await get_tree().create_timer(0.12).timeout
	await get_tree().create_timer(1.0).timeout  # destino en verde, intercambio y cambio de estadísticas
	panel._on_release(finish)
	await get_tree().create_timer(1.5).timeout
	# Ficha completa de la maestra legendaria, ya en el botín
	panel._on_press(start)
	await get_tree().create_timer(0.6).timeout
	panel._on_release(start)
```

(La caja de la pieza que se arrastra va una casilla por encima del dedo, con el mismo desplazamiento con que se cogió: `finish` deja su primera casilla en la (5, 0) de Tico.)

Graba copiando antes `save.json` (y restáuralo después):

```bash
timeout 300 D:/Software/Godot/godot_ver4.5.exe --path . --write-movie <scratchpad>/t17/f.png --fixed-fps 10 --quit-after 120 --resolution 810x1440 res://scenes/tests/VisualCapture.tscn -- --plan=inventory
```

Abre con Read varios fotogramas y comprueba:
- la rejilla de 6×6 delante de Tico, con las piezas en casillas de color y la legendaria con su borde naranja;
- la pieza que se arrastra una casilla por encima del destino, con el destino en verde o rojo y el cambio de estadísticas;
- el intercambio al soltar;
- la ficha completa con la habilidad legendaria;
- nada se sale de la pantalla ni se pisa.

Repite con `--resolution 540x960` para ver el panel en una pantalla pequeña. Si las piezas se ven con píxeles irregulares, apúntalo para el spec del tablero y la botonera (tamaño de píxel de la interfaz): no se arregla aquí.

- [ ] **Step 2: Rendimiento del panel**

Spec, apartado 11: el panel se abre en menos de 50 ms. El móvil se prueba con su tarjeta (paso 6). Aquí se mide en el ordenador, con la rejilla de 6×6 llena y el botín con piezas. Añade a `InventoryGridTests`:

```gdscript
func test_panel_opens_fast_with_a_full_inventory() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	for id in GridExpansions.ids():
		im.apply_grid_expansion(id)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 40:
		var res: ItemResource = load("res://data/items/%s.tres" % ITEM_IDS[i % ITEM_IDS.size()])
		var item := CraftedItem.new(res, rng.randf())
		item.aristas = PieceShape.roll_aristas(res, item.get_quality_tier(), rng)
		im.add_crafted_item(item)
		var spot := GearPacker.find_spot(im.hero_grid, item)
		if not spot.is_empty():
			im.move_item(item, InventoryManager.PLACE_HERO, spot.cell, spot.rot)
	var panel: Control = load("res://scenes/UI/EquipmentPanel.tscn").instantiate()
	add_child(panel)
	await get_tree().process_frame
	var t0 := Time.get_ticks_usec()
	panel.open()
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	print("panel de Equipo: %.1f ms (%d piezas en Tico, %d en el botín)" % [ms, im.get_hero_items().size(), im.get_loot_count()])
	check(ms < 50.0, "se abre en menos de 50 ms (%.1f)" % ms)
	panel.queue_free()
	await _restore_inventory(saved)
```

Run InventoryGridTests. Expected: 0 fallos. Si no llega, mira qué pesa con el perfilador de Godot antes de tocar nada. Lo más probable es recalcular las auras pieza a pieza en vez de una vez por refresco.

- [ ] **Step 3: Batería completa y arranque real**

Run: la batería. Expected: 0 fallos en las siete líneas.

Run (copia antes `save.json` y restáuralo después):

```bash
timeout 120 D:/Software/Godot/godot_ver4.5.exe --headless --path . --quit-after 900 res://scenes/Main.tscn 2>&1 | grep -iE "SCRIPT ERROR|Parse Error|InventoryManager:"
```

Expected: sin errores. La partida del usuario carga con todas sus piezas.

- [ ] **Step 4: Documentación**

- `doc/ARCHITECTURE.md`: una sección "Inventario en rejilla" con las clases nuevas (`PieceShape`, `GearGrid`, `GearAuras`, `LegendaryPowers`, `GearPacker`, `GridExpansions`, `Potions`, `GearGridView` y `LootStripView`), qué hace cada una y quién la usa. Añade también los tres sitios de `InventoryManager`, el guardado versión 2 y la ampliación provisional al vencer a los jefes.
- `doc/ROADMAP.md`: el inventario en rejilla, hecho, con enlace al spec.
- Spec: el estado pasa a "implementado (<fecha>)".

- [ ] **Step 5: Commit**

```bash
git add scripts/tests/VisualCapture.gd scripts/tests/InventoryGridTests.gd doc/ARCHITECTURE.md doc/ROADMAP.md doc/specs/2026-09-27-inventario-en-rejilla.md
git commit -m "docs: inventario en rejilla: arquitectura, roadmap, captura, rendimiento y estado del spec"
```

- [ ] **Step 6: Tablero**

En `D:/Proyectos/CONTROL/Tableros/Futuro/PetJam.md`, edítalo a mano (el CLI no encuentra PetJam). Nunca escribas "^" dentro de una tarjeta.
- Tarjeta "Inventario en rejilla estilo Lootbound": añade en Notas los commits de la implementación. Apunta también lo que queda fuera: las recetas de ampliación (con los rangos), el balance con rejillas (con Balanza) y el arte (su tarjeta). Muévela a "🔄 Completada - Pendiente Revisión". El criterio "Implementado después de los rangos" se queda sin marcar, con la nota de que se adelantó por decisión del usuario.
- Tarjeta "Implementar los rangos de plano por ciclo": anota que el inventario en rejilla ya está en la rama base. Sus tareas 5, 6, 8 y 11 tienen que adaptarse a él: piezas con `rank`, guardado (el inventario ocupa la versión 2, los rangos pasan a la 3), tienda y forja, y numerales en el panel nuevo. Tras ellas, las recetas de ampliación sustituyen a la ampliación provisional.
- Tarjeta "Piloto de Balanza: presupuesto de los 12 objetos": anota que el equipo ya es una rejilla. Antes de calibrar, el piloto mira la tarea 16 del plan del inventario: estadísticas por casilla y duelos con la rejilla llena.
- Tarjetas nuevas en el backlog: "Recetas de ampliación de la rejilla" (después de los rangos; referencia: la tarea 12 con recetas, commit 6238cab) y "Balance del inventario en rejilla" (con Balanza; la tarea 16 del plan).
- Tarjeta "Hueco "Pecho" sin objetos en el panel de Equipo": marca sus dos criterios, anota "Resuelta por el inventario en rejilla: sin huecos fijos no hay pecho" y muévela también a "🔄 Completada - Pendiente Revisión".
- Tarjeta "Tutorial de primeros pasos": añade en Notas que con la rejilla "equipar" es arrastrar la primera pieza del botín a la rejilla de Tico, porque nada se coloca solo (spec del inventario, apartado 9.3).
- Tarjeta "Testing y export Android real device": añade en Notas qué hay que mirar del inventario en el móvil (spec del inventario, apartados 11 y 16):
  - que el panel se abre en menos de 50 ms;
  - que el arrastre va a 60 FPS;
  - que las casillas de 110 px se aciertan con el dedo. Si no, la mochila baja a 6×3 y las casillas crecen.

Después ejecuta `node scripts/kanban.js lint` desde `D:/Proyectos/CONTROL`. Nunca muevas nada a Done.
