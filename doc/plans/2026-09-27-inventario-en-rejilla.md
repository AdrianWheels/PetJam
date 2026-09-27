# Inventario en rejilla — Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** que el equipo de Tico sea una rejilla como la de Lootbound. Sus rasgos:
- piezas con forma que se giran y se colocan donde quepan, y todo lo que está en la rejilla cuenta;
- aristas según la calidad;
- auras entre vecinas y zonas del cuerpo;
- habilidades de combate en las legendarias;
- botín sin límite y mochila;
- 2 consumibles que se beben solos;
- una rejilla que crece de 4×4 a 6×6 con 4 recetas únicas.

**Architecture:** las reglas van en clases estáticas o `RefCounted`, sin nodos, en `scripts/core/`:
- `PieceShape`: formas, giros y aristas;
- `GearGrid`: una rejilla (caber, colocar y vecinas);
- `GearAuras`: auras, zonas y tope;
- `LegendaryPowers`: habilidades;
- `GearPacker`: colocación automática, solo para la migración y la simulación;
- `GridExpansions`: recetas de ampliación;
- `Potions`: catálogo de pociones.

`InventoryManager` guarda los tres sitios de las piezas (rejilla de Tico, mochila y botín) y mantiene `calculate_total_stats()`, así que `Hero`, `CombatMath` y `BalanceSim` no cambian de interfaz. El panel de Equipo se rehace a pantalla completa. Cada rejilla es un control que se dibuja a sí mismo (`GearGridView`), el botín es una tira (`LootStripView`), y el panel lleva el dedo en `_input`.

**Tech Stack:** Godot 4.5.1 (GDScript con tabuladores), Python 3 + Pillow para el pixel art, suites sin ventana sobre `scripts/tests/TestSuite.gd`.

**Spec:** `doc/specs/2026-09-27-inventario-en-rejilla.md`

## Requisitos previos

- **Orden: Balanza, rangos e inventario.** La calibración de los rangos está en pausa hasta que esté el motor Balanza (otra sesión, `D:/Proyectos/Balanza`).
- **Rangos terminados.** La implementación empieza cuando la tarjeta "Implementar los rangos de plano por ciclo" está en "🔄 Completada - Pendiente Revisión" (`D:/Proyectos/CONTROL/Tableros/Futuro/PetJam.md`). La tarea 0 rebasa esta rama sobre `franja-pixel-fase-1` actualizada.
- **Lo que este plan usa de los rangos.** Lo que ya está en su plan (`doc/plans/2026-09-27-rangos-de-plano-por-ciclo.md`) va con su nombre:
  - `CraftedItem.rank`, `CraftedItem.new(res, quality, rank)` y `CraftedItem.get_name_with_rank()`;
  - de `Ranks`: `stat_mult`, `gold_mult`, `scale_stats`, `suffix`, `ROOMS_PER_CYCLE`, `BIOME_MATERIALS` y `recipe`;
  - el guardado versión 2;
  - `CraftingManager.enqueue(recipe_id, gold_reward, rank, own_order)` y `CraftingManager.place_own_order`;
  - `BlueprintLibraryPanel.own_order_requested`, `BlueprintLibraryPanel.reject` y `HUDMain._start_first_queued_task()`;
  - `Hero.take_damage(amount, is_pulse, attacker_level)` y `Hero.prepare_for_combat()`, que `CombatController` llama al empezar cada duelo;
  - `CombatMath.armor_mitigation(armor, enemy_level)`;
  - los materiales de bioma `bone`, `moss`, `obsidian` y `frost`.
- **Lo que añadió la revisión del spec de rangos (2026-09-27, apartados 6 y 7),** que su plan aún no tiene. La tarea 0 anota el nombre real de cada cosa:
  - la función que da el rango del equipo, que la tarea 6 redefine para la rejilla, y cómo se aplica la base de Tico por rango;
  - los duelos: Tico entra en cada sala con la vida llena;
  - el reintento del muro al cambiar de equipo o beber una poción;
  - la simulación de duelos (`BalanceSim`, o el enlace de Balanza en `balance/` y `addons/balanza/`) con sus objetivos: hitos, cotas y escalera.
- **Fase 2 del pixel art (Tico por capas, rama `franja-pixel-fase-2`):** no hace falta, pero si está integrada el plan usa lo suyo:
  - `recolor.py`: la rampa de acento `+ * #`, las rampas de calidad y la fuerza del destello (tarea 14);
  - `Hero.read_equipped_gear()`: la única lectura del equipo para el dibujo (tarea 6);
  - `HeroPreview`: el Tico grande y tenue del panel (tarea 9).
- **Si al rebasar algo de esto se llama distinto,** la tarea 0 lo anota en "Equivalencias tras los rangos" y cada tarea usa el nombre real.

## Global Constraints

- **Godot:** usar siempre `D:/Software/Godot/godot_ver4.5.exe` (4.5.1), nunca `godot.exe` (4.7).
  - Tras crear scripts con `class_name`, recursos o PNG nuevos: `D:/Software/Godot/godot_ver4.5.exe --headless --path . --import`.
  - Todas las ejecuciones de Godot van con `timeout 300`: si un script no se analiza, `_ready` no corre y Godot no sale.
- **Código:** GDScript con tabuladores y comentarios en español. Sin autoloads nuevos ni plugins.
- **Textos:** todo texto visible nuevo va en español en el código o en los datos, con su fila en `locale/textos.csv`, y con `tr()` en los textos formateados.
  - Columnas `keys,es,en`, sin líneas en blanco.
  - Las filas van sin comillas, salvo las que llevan comas: esas van entre comillas dobles (Ruling R7 del plan de rangos).
  - Antes de añadir una fila, comprueba con `grep -n "^<texto>," locale/textos.csv` que no existe.
  - Tras editar el CSV: `D:/Software/Godot/godot_ver4.5.exe --headless --path . --import`.
  - Los textos de la franja (scripts de `TextTests.STRIP_SCRIPTS`) usan solo caracteres de `PixelFont`: A-Z, ÁÉÍÓÚÜÑ, cifras y ! ¡ ? ¿ . , : ; - + / ( ) % ' · ×.
- **Partida del usuario:** ejecutar el juego o `--write-movie` escribe `%APPDATA%/Godot/app_userdata/PetJam/save.json`. Cópialo antes y restáuralo después; las suites ya lo hacen solas (`TestSuite`).
- **Commits:** sin Co-Authored-By, añadiendo los ficheros por su ruta (nunca `git add -A`).
- **Medidas:** casilla de 22×22 píxeles de arte, pintada a ×5 (110 px de pantalla).
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
- **Recetas de ampliación:** la tabla del spec, apartado 7.
  - Se desbloquean al vencer por primera vez al jefe de las salas 10, 20, 30 y 40 del ciclo I.
  - Siempre salen, no dan oro y son únicas.

## Review Focus

- **Llega una pieza nueva de la forja mientras se arrastra otra.** El arrastre sigue, la pieza que se arrastra no se pierde y la nueva aparece en el botín. Prueba: `test_new_loot_while_dragging_is_not_lost` (tarea 9).
- **Golpe doble cuando el primer golpe mata.** El nodo `Enemy` se recoloca en la sala siguiente al morir, así que el segundo golpe no puede llegar al enemigo nuevo. Prueba: `test_double_hit_never_reaches_the_next_enemy` (tarea 11).
- **Quemadura que sigue viva cuando el enemigo muere.** Por el mismo motivo, el enemigo de la sala siguiente no puede empezar quemado. Prueba: `test_burn_does_not_carry_over_to_the_next_enemy` (tarea 11).
- **Las Espinas matan al enemigo durante su propio ataque.** Muere una sola vez, sin botín doble ni errores. Prueba: `test_thorns_kill_counts_once` (tarea 11).
- **Partida con una posición imposible,** por ejemplo tras cambiar una forma en los datos: la pieza pasa al botín y nunca se pierde. Prueba: `test_impossible_saved_position_goes_to_loot` (tarea 7).

---

## Equivalencias tras los rangos

(Las rellena la tarea 0: los nombres del plan de rangos que hayan cambiado y lo que añadió la revisión de su spec.)

## Mapa de ficheros

| Fichero | Acción | Responsabilidad |
|---|---|---|
| `scripts/core/PieceShape.gd` | crear | formas, giros, caja y aristas |
| `scripts/core/GearGrid.gd` | crear | una rejilla: caber, colocar, quitar, vecinas y copia |
| `scripts/core/GearAuras.gd` | crear | auras, zonas, tope y totales de la rejilla de Tico |
| `scripts/core/LegendaryPowers.gd` | crear | tabla de habilidades, activas, multiplicadores y efectos |
| `scripts/core/GearPacker.gd` | crear | colocación automática (migración y BalanceSim) |
| `scripts/core/GridExpansions.gd` | crear | recetas de ampliación: tamaños, jefes, planos |
| `scripts/core/Potions.gd` | crear | catálogo de pociones y reglas de los huecos |
| `scripts/core/GearSprites.gd` | crear | textura de cada pieza: pixel art girado, recoloreado y con aristas |
| `scripts/data/ItemResource.gd`, `data/items/*.tres` | modificar | forma y sitios de arista; estadísticas por casilla (tarea 16) |
| `scripts/data/CraftedItem.gd` | modificar | sitio, casilla, giro, aristas y precio de venta |
| `scripts/autoload/InventoryManager.gd` | modificar | tres sitios, mover/intercambiar/vender, totales, ampliaciones, consumibles, guardado v3 |
| `scripts/autoload/CraftingManager.gd` | modificar | aristas al forjar; recetas de ampliación |
| `scripts/autoload/GameManager.gd` | modificar | aviso de receta; pociones automáticas |
| `scripts/core/SaveManager.gd` | modificar | versión 3 y récord para la migración |
| `scripts/core/CombatMath.gd` | modificar | `hero_stats_with_powers` |
| `scripts/gameplay/Hero.gd`, `Enemy.gd`, `CombatController.gd`, `Corridor.gd`, `visual/CombatFX.gd` | modificar | mejor pieza por tipo, habilidades en combate, quemadura, jefe → pociones |
| `scripts/ui/GearGridView.gd`, `scripts/ui/LootStripView.gd` | crear | vistas de rejilla y botín |
| `scenes/UI/EquipmentPanel.tscn`, `scripts/ui/EquipmentPanel.gd` | rehacer | panel a pantalla completa y el dedo |
| `scripts/ui/HUDMain.gd`, `ShopPanel.gd`, `CraftResultScreen.gd`, `BlueprintLibraryPanel.gd`, `HeroViewOverlay.gd` | modificar | insignia, venta, pociones, resultado, recetas y avisos |
| `tools/pixel_art/gear.py`, `tools/pixel_art/tests/test_gear.py`, `tools/pixel_art/export.py` | crear / modificar | pixel art de piezas, aristas, pociones, zonas e interfaz |
| `art/sprites/pixel/gear/*` | generados | sprites de piezas e interfaz |
| `scripts/tests/InventoryGridTests.gd`, `scenes/tests/InventoryGridTests.tscn` | crear | pruebas de este plan (la partida de la versión 2 se genera en la propia prueba) |
| `scripts/tests/GameplayTests.gd`, `RankTests.gd`, `TextTests.gd`, `BalanceSim.gd`, `VisualCapture.gd` | modificar | pruebas y capturas afectadas; duelos con rejillas en `BalanceSim` |
| `balance/` y el enlace de PetJam con Balanza | modificar, si los rangos se calibraron con Balanza | calibración con rejillas (tarea 16) |
| `locale/textos.csv` | modificar | filas nuevas |
| `doc/ARCHITECTURE.md`, `doc/ROADMAP.md`, `doc/specs/2026-09-27-inventario-en-rejilla.md` | modificar | documentación y valores calibrados |

Comandos de la batería (todos desde la raíz del worktree, `D:/Proyectos/PetJam-inventario`):

```bash
timeout 300 D:/Software/Godot/godot_ver4.5.exe --headless --path . res://scenes/tests/InventoryGridTests.tscn
timeout 300 D:/Software/Godot/godot_ver4.5.exe --headless --path . res://scenes/tests/RankTests.tscn
timeout 300 D:/Software/Godot/godot_ver4.5.exe --headless --path . res://scenes/tests/BalanceSim.tscn
timeout 300 D:/Software/Godot/godot_ver4.5.exe --headless --path . res://scenes/tests/GameplayTests.tscn
timeout 300 D:/Software/Godot/godot_ver4.5.exe --headless --path . res://scenes/tests/PixelTests.tscn
timeout 300 D:/Software/Godot/godot_ver4.5.exe --headless --path . res://scenes/tests/TextTests.tscn
python -m unittest discover tools/pixel_art/tests
```

- **Salida:** cada escena sale con 0 si todo pasa y con 1 si algo falla, e imprime `[Suite] N comprobaciones, M fallos`.
- **"Run: la batería"** en una tarea quiere decir las siete líneas.
- **"Run: InventoryGridTests"** quiere decir solo la primera.

---

### Task 0: Rebasar la rama y comprobar lo que dejan los rangos

**Files:** ninguno. Si algo no cuadra, se corrige este plan (sección "Equivalencias tras los rangos") en un commit `docs:` antes de seguir.

- [ ] **Step 1: La tarjeta de rangos está terminada**

Abre `D:/Proyectos/CONTROL/Tableros/Futuro/PetJam.md` y busca "Implementar los rangos de plano por ciclo". Tiene que estar bajo "🔄 Completada - Pendiente Revisión" (o en Done). Si sigue en "In Progress", para y avisa al usuario.

- [ ] **Step 2: Rebasar**

```bash
cd D:/Proyectos/PetJam-inventario
git status --short
git rebase franja-pixel-fase-1
git log --oneline -3
```

Expected: `git status` vacío antes de rebasar. El rebase aplica los commits de esta rama (solo `doc/specs` y `doc/plans`) sin conflictos. El primer commit del log es el de este plan.

- [ ] **Step 3: Las interfaces de los rangos existen**

```bash
grep -n "var rank" scripts/data/CraftedItem.gd
grep -n "func get_name_with_rank" scripts/data/CraftedItem.gd
grep -n "static func stat_mult\|static func gold_mult\|static func scale_stats\|static func suffix\|const ROOMS_PER_CYCLE\|BIOME_MATERIALS\|static func recipe" scripts/core/Ranks.gd
grep -n "const SAVE_VERSION" scripts/core/SaveManager.gd
grep -n "func enqueue\|func place_own_order\|var rng\|func _finalize_task" scripts/autoload/CraftingManager.gd
grep -n "signal own_order_requested\|func reject" scripts/ui/BlueprintLibraryPanel.gd
grep -n "func _start_first_queued_task\|func _on_own_order_requested" scripts/ui/HUDMain.gd
grep -n "func take_damage\|func prepare_for_combat" scripts/gameplay/Hero.gd
grep -n "static func armor_mitigation\|static func hero_stats" scripts/core/CombatMath.gd
ls data/materials/bone.tres data/materials/moss.tres data/materials/obsidian.tres data/materials/frost.tres
```

Expected:
- cada `grep` encuentra su línea y `ls` lista los 4 ficheros;
- `SAVE_VERSION := 2`;
- `enqueue(recipe_id, gold_reward: int = 0, rank: int = 1, own_order: bool = false)`;
- `take_damage(amount: int, is_pulse: bool = false, attacker_level: int = 1)`.

`var rng` en `CraftingManager` puede no existir (lo crea la tarea 6). Si otro nombre ha cambiado, anota en "Equivalencias tras los rangos" el nombre del plan de rangos y el real, y úsalo en todas las tareas.

- [ ] **Step 3 bis: Lo que añadió la revisión de los rangos**

```bash
grep -rn "rango del equipo" scripts/
grep -rn "WALL_RETRY_WINS\|vida llena" scripts/
grep -n "func " scripts/tests/BalanceSim.gd
ls addons/balanza/VERSION balance/balance.json
grep -n "const MATERIAL_DROP_QTY" scripts/gameplay/Enemy.gd
```

Anota en "Equivalencias tras los rangos":
- **Rango del equipo:** la función que lo da (spec de rangos, apartado 6, "Base de Tico") y dónde se usa para la base de Tico. Si `CombatMath.hero_stats` recibe ahora ese rango, anótalo: la tarea 4 lo añade a `hero_stats_with_powers`.
- **Duelos:** dónde se llena la vida de Tico al empezar cada sala. Comprueba que `CombatController` sigue llamando a `hero.prepare_for_combat()` al empezar cada combate: la tarea 11 recarga ahí la Segunda oportunidad y el Ímpetu.
- **Muro:** la función que reintenta el muro al beber una poción y la que lo hace al cambiar de equipo, y qué señal escucha esta última (la tarea 13 llama a la primera al beber; la tarea 6 conserva `equipment_changed`).
- **Simulación:** con qué funciones mide `BalanceSim` los duelos, qué números tienen sus objetivos y su escalera, y si `ls` encuentra Balanza (entonces la tarea 16 calibra con ella).
- **Tanda de botín:** el valor de `Enemy.MATERIAL_DROP_QTY` tras los rangos (la tarea 16 lo usa de referencia).

```bash
ls tools/pixel_art/recolor.py scripts/ui/HeroPreview.gd
grep -n "func read_equipped_gear" scripts/gameplay/Hero.gd
```

- **Fase 2 del pixel art:** anota si está integrada. Si lo está, la tarea 6 cambia `read_equipped_gear()` y la tarea 9 usa `HeroPreview`. La tarea 14 lo detecta sola.

- [ ] **Step 4: La batería está en verde antes de empezar**

Run: `D:/Software/Godot/godot_ver4.5.exe --headless --path . --import` y después la batería. En ella, `InventoryGridTests` aún no existe: su línea falla con "scene not found" y se ignora en este paso.
Expected: las demás, con 0 fallos. Si algo falla ya antes de empezar, no es de este plan: avisa al usuario con la salida y para.

- [ ] **Step 5: Commit de las equivalencias**

```bash
git add doc/plans/2026-09-27-inventario-en-rejilla.md
git commit -m "docs: equivalencias del plan del inventario tras integrar los rangos"
```

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
  - campos de `CraftedItem`: `place: StringName` (`&"loot"` por defecto), `cell: Vector2i`, `rot: int` y `aristas: Array[Vector2i]`. `to_dict()` los guarda como `place`, `x`, `y`, `rot` y `aristas`, y `from_dict()` los lee. `to_dict()` deja de escribir `equipped`.

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
	var data := item.to_dict()
	var back := CraftedItem.from_dict(data, item.item_resource)
	check(back.place == &"hero" and back.cell == Vector2i(2, 3) and back.rot == 3, "sitio, casilla y giro vuelven igual")
	check(back.aristas == [Vector2i(1, 2)], "las aristas vuelven igual (%s)" % [back.aristas])
	check(not data.has("equipped"), "ya no se guarda equipped")
	var old := data.duplicate()
	for k in ["place", "x", "y", "rot", "aristas"]:
		old.erase(k)
	var v2 := CraftedItem.from_dict(old, item.item_resource)
	check(v2.place == &"loot" and v2.aristas.is_empty(), "una pieza de la versión 2 empieza en el botín y sin aristas")
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
## InventoryManager, las vistas, GearSprites y BalanceSim.

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

Variables, junto a `rank` (de los rangos):

```gdscript
# Sitio en el inventario (spec del inventario en rejilla, apartado 3). Lo mantiene InventoryManager.
var place: StringName = &"loot"  ## &"hero" (rejilla de Tico), &"bag" (mochila) o &"loot" (botín)
var cell: Vector2i = Vector2i.ZERO  ## esquina de arriba a la izquierda de su caja en la rejilla
var rot: int = 0  ## cuartos de vuelta en el sentido de las agujas del reloj (0-3)
var aristas: Array[Vector2i] = []  ## casillas de más, en coordenadas de la pieza sin girar (PieceShape)
```

`to_dict()`: sustituye la clave `"equipped": is_equipped` por las del sitio (el resto de claves, `rank` incluido, se queda):

```gdscript
		"place": String(place),
		"x": cell.x,
		"y": cell.y,
		"rot": rot,
		"aristas": aristas.map(func(a): return [a.x, a.y]),
```

`from_dict()`: quita la línea `item.is_equipped = data.get("equipped", false)` y añade antes del `return`:

```gdscript
	item.place = StringName(data.get("place", "loot"))
	item.cell = Vector2i(int(data.get("x", 0)), int(data.get("y", 0)))
	item.rot = posmod(int(data.get("rot", 0)), 4)
	var ar: Array[Vector2i] = []
	for pair in data.get("aristas", []):
		if pair is Array and pair.size() == 2:
			ar.append(Vector2i(int(pair[0]), int(pair[1])))
	item.aristas = ar
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

En `_ready()`, `rng.randomize()`. En `_finalize_task`, después de `crafted_item = CraftedItem.new(item_res, quality_normalized, task.rank)` y antes de `inv.add_crafted_item(crafted_item)`:

```gdscript
				# Aristas según la calidad (spec del inventario en rejilla, apartado 2.3)
				crafted_item.aristas = PieceShape.roll_aristas(item_res, crafted_item.get_quality_tier(), rng)
```

- [ ] **Step 6: `Hero.gd`: la mejor pieza de cada tipo y las habilidades**

Si la fase 2 del pixel art está integrada (tarea 0), la lectura del equipo para el dibujo vive en `read_equipped_gear()`. En ese caso, esa función devuelve, con su misma forma, la mejor pieza de cada tipo (`inv_manager.best_hero_item(slot)`) y `refresh_gear()` se queda como esté. Si no está integrada, sustituye `refresh_gear()`:

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

### Task 7: Guardado versión 3

**Files:**
- Modify: `scripts/core/SaveManager.gd`, `scripts/tests/RankTests.gd` (versión)
- Test: `scripts/tests/InventoryGridTests.gd`

**Interfaces:**
- Consumes: `InventoryManager.load_save_data(data, record)`, `InventoryManager.to_save_data()`
- Produces: `SaveManager.SAVE_VERSION` = 3. `SaveManager.load_game()` pasa el récord de la partida (`game.best_enemy_level`) al inventario.

- [ ] **Step 1: Pruebas que fallan**

```gdscript
# ─── Tarea 7: guardado versión 3 y migración ───────────────────────────

## Partida de la versión 2 (antes de la rejilla): 4 piezas equipadas y 40 sueltas, con récord 35.
func _v2_save() -> Dictionary:
	var items := []
	var equipped := {"main_hand": 0, "off_hand": 1, "head": 2, "feet": 3}
	var gear := [[&"sword_masterwork", 0.93], [&"shield_master", 0.5], [&"helmet_advanced", 0.6], [&"boots_master", 0.3]]
	for i in 44:
		var id: StringName = gear[i][0] if i < 4 else ITEM_IDS[i % ITEM_IDS.size()]
		var q: float = gear[i][1] if i < 4 else 0.2 + 0.018 * i
		var d := CraftedItem.new(_res(id), q).to_dict()
		for k in ["place", "x", "y", "rot", "aristas"]:
			d.erase(k)
		d["equipped"] = i < 4
		d["timestamp"] = 1000 + i
		items.append(d)
	return {
		"version": 2,
		"timestamp": 1790000000.0,
		"game": {"current_enemy_level": 7, "best_enemy_level": 35, "death_count": 2, "enemies_defeated": {}, "hero_loadout": {}},
		"data": {"unlocked_ranks": {}},
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


func test_v2_save_migrates_without_losing_pieces() -> void:
	var im := _im()
	check(_load_save_dict(_v2_save()), "la partida de la versión 2 carga")
	check(im.get_crafted_items().size() == 44, "ninguna pieza perdida (%d de 44)" % im.get_crafted_items().size())
	check(im.hero_grid_size() == Vector2i(6, 5) and im.expansions.size() == 3, "récord 35: jefes 10, 20 y 30 vencidos, 3 ampliaciones y rejilla de 6×5 (%s)" % im.hero_grid_size())
	var hero_ids: Array = im.get_hero_items().map(func(it): return it.item_resource.item_id)
	check(&"sword_masterwork" in hero_ids and &"shield_master" in hero_ids, "lo que estaba equipado entra en la rejilla, las mejores primero (%s)" % [hero_ids])
	check(im.get_hero_items().size() + im.get_loot().size() == 44 and im.get_bag_items().is_empty(), "lo demás, al botín")
	var first: CraftedItem = im.get_loot()[0]
	check(im.get_loot().all(func(it): return InventoryManager.gear_score(it) <= InventoryManager.gear_score(first)), "el botín empieza por la mejor pieza")
	var aristas_a: Array = im.get_crafted_items().map(func(it): return it.aristas)
	check(_load_save_dict(_v2_save()), "se vuelve a cargar la misma partida")
	var aristas_b: Array = im.get_crafted_items().map(func(it): return it.aristas)
	check(aristas_a == aristas_b, "las aristas migradas salen siempre iguales")
	check(SaveManager.save_game(), "se guarda en la versión nueva")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	check(int(data.version) == 3 and data.inventory.has("hero_grid") and not data.inventory.has("equipped_slots"), "guardado versión 3, sin huecos fijos")
	await _reload_user_save()


func test_v3_save_round_trip() -> void:
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

Run InventoryGridTests. Expected: falla `test_v2_save_migrates_without_losing_pieces`: el récord no llega al inventario, así que la rejilla sale de 4×4, y la versión guardada es 2.

- [ ] **Step 2: `SaveManager.gd`**

```gdscript
const SAVE_VERSION := 3
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

- [ ] **Step 3: La prueba de los rangos acepta versiones más nuevas**

En `RankTests.test_v1_save_with_high_record_migrates`, la línea `check(int(data.version) == 2 and data.data.has("unlocked_ranks"), …)` pasa a:

```gdscript
	check(int(data.version) >= 2 and data.data.has("unlocked_ranks"), "guardado versión 2 o posterior con unlocked_ranks")
```

- [ ] **Step 4: Ejecutar y ver que pasa**

Run: la batería. Expected: 0 fallos.

- [ ] **Step 5: Commit**

```bash
git add scripts/core/SaveManager.gd scripts/tests/InventoryGridTests.gd scripts/tests/RankTests.gd
git commit -m "feat: guardado versión 3 con la rejilla; la migración usa el récord de la partida"
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
- Sin `sprite_for` dibujan las piezas con casillas de color: coral las armas, verde las armaduras, con el borde del color de la calidad y las aristas en gris. La tarea 15 le da el pixel art.

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
## el botín y la pieza que se arrastra. Con `sprite_fn` válido pinta su pixel art; si no, casillas de color.
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
## ampliarla). Las piezas se dibujan encima. La tarea 15 le añade el icono del tipo.
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


## Tico a gran tamaño y tenue detrás de su rejilla (el mismo dibujo que en la mazmorra). Con la fase 2 del
## pixel art integrada, usa HeroPreview (ver la nota después de este bloque).
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
	var room := int(_gm.current_enemy_level) if _gm and "current_enemy_level" in _gm else 1
	var mitigation := roundi(CombatMath.armor_mitigation(int(now.armor), room) * 100.0)
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


## Receta de la siguiente ampliación (la primera sin forjar, por orden de jefe).
func _refresh_next() -> void:
	_next_label.text = ""
	for id in GridExpansions.ids():
		if id in _im.expansions:
			continue
		var r: Dictionary = GridExpansions.RECIPES[id]
		_next_label.text = tr("Próxima ampliación: %s (jefe de la sala %d)") % [tr(r.name), int(r.room)]
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

**Con la fase 2 del pixel art integrada** (tarea 0), el Tico grande es un `HeroPreview` en lugar de la marioneta, en el mismo sitio del árbol (detrás de las rejillas):
- `_puppet` pasa a ser `CanvasItem`, y `_puppet_setup()` crea `HeroPreview.new(18)`;
- va centrado en la rejilla, con los pies al fondo: `position = HERO_GRID_POS + Vector2((660.0 - 32.0 * 18.0) / 2.0, 660.0 - HeroPreview.FEET.y * 18.0)`;
- lleva `modulate.a = 0.35` y `mouse_filter = Control.MOUSE_FILTER_IGNORE`;
- `open()` y `close()` llaman a `set_active(true)` y `set_active(false)`, en lugar de tocar `process_mode` y `respawn`;
- donde se llama a `refresh_gear()` va `refresh()`, y donde se pone `_materialize` va `play_materialize()`.

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
Próxima ampliación: %s (jefe de la sala %d),Próxima ampliación: %s (jefe de la sala %d),Next expansion: %s (boss of room %d)
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
- Modify: `scripts/ui/EquipmentPanel.gd`, `scripts/ui/HUDMain.gd` (insignia), `scripts/autoload/InventoryManager.gd` (se quita la compatibilidad), `scripts/tests/RankTests.gd`, `locale/textos.csv`
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
- Comprueba que nadie más las usa: `grep -rn "equip_item\|unequip_item\|get_equipped_item" scripts --include=*.gd`. Solo pueden salir `DungeonHUD.gd`, que no se usa, las llama con `has_method` y no rompe, y la prueba de los rangos. En esa prueba, `RankTests.test_v1_save_with_high_record_migrates`, la línea `check(inv.get_equipped_item("main_hand") == items[0], "y sigue equipada")` pasa a:

```gdscript
	check(items[0].place == InventoryManager.PLACE_HERO, "y sigue equipada: está en la rejilla de Tico")
```

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
git add scripts/ui/EquipmentPanel.gd scripts/ui/HUDMain.gd scripts/autoload/InventoryManager.gd scripts/tests/InventoryGridTests.gd scripts/tests/RankTests.gd locale/textos.csv
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
	var state := {"level": gm.current_enemy_level, "best": gm.best_enemy_level, "deaths": gm.death_count, "dungeon": gm.dungeon_state}
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
	check(hero.take_damage(50, false, 5) == 0 and hero.last_avoid == &"dodge" and hero.hp == hp, "Esquiva: el golpe no hace nada")
	check(hero.take_damage(5, true, 5) > 0 and hero.last_avoid == &"", "el pulso mágico no se esquiva")
	hero.power = LegendaryPowers.effects([&"shield_advanced"])
	hp = hero.hp
	check(hero.take_damage(50, false, 5) == 0 and hero.last_avoid == &"block" and hero.hp == hp, "Parada: tampoco")
	hero.power_roll = func() -> float: return 0.99
	check(hero.take_damage(10, false, 5) > 0, "con la tirada en contra, el golpe entra")
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
	hero.take_damage(hero.max_hp * 5, true, 5)
	check(hero.alive and hero.hp == roundi(hero.max_hp * 0.4), "la primera caída del duelo se queda con el 40 %% (%d/%d)" % [hero.hp, hero.max_hp])
	hero.take_damage(hero.max_hp * 5, true, 5)
	check(not hero.alive, "la segunda vez en el mismo duelo cae")
	hero.respawn()
	hero.prepare_for_combat()
	hero.take_damage(hero.max_hp * 5, true, 5)
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

Sustituye `take_damage` (parte de la versión de los rangos, con `attacker_level`):

```gdscript
## Aplica daño y devuelve el daño real recibido (tras armadura). El pulso mágico ignora la armadura.
## `attacker_level` es la sala del enemigo que golpea: la armadura se compara con su escala.
## Habilidades legendarias: Esquiva y Parada anulan un golpe (no el pulso) y dejan `last_avoid`;
## Segunda oportunidad deja a Tico con vida la primera vez que iba a caer en cada duelo.
func take_damage(amount: int, is_pulse: bool = false, attacker_level: int = 1) -> int:
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
		var mitigation := armor_mitigation(attacker_level)
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

Si la tarea 12 de los rangos (vuelta rápida) cambió el hit-stop o el temblor de este bloque, conserva su versión dentro de `_hero_hit`. Lo nuevo de esta tarea son las líneas del Ímpetu, la quemadura y "¡Doble!".

En `_execute_enemy_attack()`, desde la línea `var dealt: int = hero.take_damage(raw, false, enemy.level)` hasta el bloque del texto "Bloqueo" (incluido), sustituye por:

```gdscript
	var dealt: int = hero.take_damage(raw, false, enemy.level)
	if fx:
		if hero.last_avoid != &"":
			# Esquiva (botas avanzadas) o Parada (escudo avanzado) legendarias
			fx.float_text(hit_pos + Vector2(-9, -4), tr("¡Esquiva!") if hero.last_avoid == &"dodge" else tr("¡Parada!"), Color("b8c4d6"), false, 0.7, 8.0)
		else:
			fx.damage_number(number_pos, dealt, &"hero")
			if dealt < raw and _block_text_cd <= 0.0 and hero.has_method("armor_mitigation") and hero.armor_mitigation(enemy.level) >= 0.2:
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

### Task 12: Recetas de ampliación de la rejilla

**Files:**
- Modify:
  - datos y autoloads: `scripts/core/GridExpansions.gd` (materiales, pruebas y `blueprint()`), `scripts/autoload/InventoryManager.gd`, `scripts/autoload/CraftingManager.gd` y `scripts/autoload/GameManager.gd`;
  - interfaz: `scripts/ui/HeroViewOverlay.gd`, `scripts/ui/BlueprintLibraryPanel.gd`, `scripts/ui/HUDMain.gd` y `scripts/ui/CraftResultScreen.gd`;
  - `locale/textos.csv`.
- Test: `scripts/tests/InventoryGridTests.gd`

**Interfaces:**
- Consumes: `CraftingManager.enqueue(id, 0, 1, true)` (encargo propio sin oro), `HUDMain._start_first_queued_task()` y `BlueprintLibraryPanel.REJECT_TEXTS` (de los rangos)
- Produces:
  - `GridExpansions.RECIPES[id]` gana `materials` y `trials`, y aparece `GridExpansions.blueprint(id) -> BlueprintResource`, construido en código. No hay `.tres`: así no se escriben uids a mano. Es el único cambio frente al spec (apartado 7), y el resultado es el mismo;
  - `InventoryManager.available_grid_recipes(record: int) -> Array[StringName]` y `InventoryManager.apply_grid_expansion(id: StringName) -> bool`;
  - `CraftingManager.place_grid_recipe(id: StringName) -> StringName`: `&""`, `&"locked"`, `&"queue_full"` o `&"no_materials"`, sin cobrar si falla. El resultado de `_finalize_task` de una receta lleva `grid_expansion` y `grid_size`;
  - `GameManager.grid_recipe_unlocked(recipe_id)`, la primera vez que cae el jefe de la sala 10, 20, 30 o 40;
  - `BlueprintLibraryPanel.grid_recipe_requested(recipe_id)` y `BlueprintLibraryPanel.reject_grid(recipe_id, reason)`.

- [ ] **Step 1: Pruebas que fallan**

```gdscript
# ─── Tarea 12: recetas de ampliación ───────────────────────────────────

func test_grid_recipe_blueprints_are_forgeable() -> void:
	for id in GridExpansions.ids():
		var bp := GridExpansions.blueprint(id)
		check(bp != null and bp.blueprint_id == id and bp.has_trials(), "%s tiene plano con pruebas" % id)
		check(bp.result_item == &"", "%s no crea pieza" % id)
		for mat in bp.materials:
			check(ResourceLoader.exists("res://data/materials/%s.tres" % mat), "%s pide «%s», que existe" % [id, mat])
		for trial in bp.trial_sequence:
			check(trial.minigame_scene != null and trial.config != null and trial.min_score == 0.0, "%s: sus pruebas no se pueden suspender" % id)


func test_boss_unlocks_the_recipe_once() -> void:
	var gm := get_node("/root/GameManager")
	var saved := {"state": gm.dungeon_state, "best": gm.best_enemy_level}
	var seen := []
	var on_recipe := func(id): seen.append(id)
	gm.grid_recipe_unlocked.connect(on_recipe)
	gm.dungeon_state = gm.DungeonState.RUNNING
	gm.best_enemy_level = 10
	gm.register_enemy_defeat(10)
	check(seen == [&"grid_bone_straps"], "el jefe de la sala 10 da las Correas de hueso (%s)" % [seen])
	gm.best_enemy_level = 11
	gm.register_enemy_defeat(10)
	check(seen.size() == 1, "volver a vencerlo no repite el aviso")
	gm.best_enemy_level = 60
	gm.register_enemy_defeat(60)
	check(seen.size() == 1, "los jefes del ciclo II no dan recetas")
	gm.grid_recipe_unlocked.disconnect(on_recipe)
	gm.dungeon_state = saved.state
	gm.best_enemy_level = saved.best


func test_forging_a_recipe_grows_the_grid_once() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var cm := get_node("/root/CraftingManager")
	var gm := get_node("/root/GameManager")
	var best_before: int = gm.best_enemy_level
	var saved_queue: Array = cm.queue.duplicate()
	for i in cm.MAX_SLOTS:
		cm.queue[i] = null
	gm.best_enemy_level = 11
	check(im.available_grid_recipes(11) == [&"grid_bone_straps"], "con récord 11 se puede forjar la primera")
	check(cm.place_grid_recipe(&"grid_bone_straps") == &"no_materials", "sin materiales no se encarga")
	var mats: Dictionary = GridExpansions.RECIPES[&"grid_bone_straps"].materials
	for mat in mats:
		im.add_item(mat, mats[mat])
	check(cm.place_grid_recipe(&"grid_bone_straps") == &"", "con materiales se encarga")
	check(im.get_quantity(&"bone") == 0, "y los cobra")
	check(cm.place_grid_recipe(&"grid_bone_straps") == &"locked", "no se puede encargar dos veces")
	var result: Dictionary = cm._finalize_task(cm.queue[0])
	check(result.get("grid_expansion") == &"grid_bone_straps" and result.get("crafted_item") == null and result.gold_reward == 0, "no crea pieza ni da oro")
	check(im.hero_grid_size() == Vector2i(5, 4) and im.available_grid_recipes(11).is_empty(), "la rejilla pasa a 5×4 y la receta ya no está")
	check(not im.apply_grid_expansion(&"grid_bone_straps"), "la misma receta no amplía dos veces")
	cm.queue = saved_queue
	gm.best_enemy_level = best_before
	await _restore_inventory(saved)
```

Run InventoryGridTests. Expected: errores (`blueprint`, `grid_recipe_unlocked`, `place_grid_recipe`… no existen).

- [ ] **Step 2: Materiales, pruebas y plano en `GridExpansions.gd`**

Sustituye `RECIPES` y añade `blueprint()`:

```gdscript
## Receta → jefe que la desbloquea (sala del ciclo I), nombre (texto base, con tr()), materiales y
## minijuegos, en el orden de los jefes. Los materiales de bioma son los del spec de rangos.
const RECIPES := {
	&"grid_bone_straps": {"room": 10, "name": "Correas de hueso", "materials": {&"bone": 10, &"leather": 20}, "trials": [&"sew"]},
	&"grid_moss_pouches": {"room": 20, "name": "Bolsas de musgo", "materials": {&"moss": 10, &"cloth": 20}, "trials": [&"sew"]},
	&"grid_obsidian_buckles": {"room": 30, "name": "Hebillas de obsidiana", "materials": {&"obsidian": 10, &"iron": 20}, "trials": [&"forge", &"hammer"]},
	&"grid_frost_harness": {"room": 40, "name": "Arnés de escarcha", "materials": {&"frost": 10, &"leather": 20}, "trials": [&"sew", &"quench"]},
}
const DESCRIPTION := "Amplía la rejilla de Tico"


## Plano de una receta, construido en código (sin .tres). Sus pruebas no se pueden suspender
## (min_score 0): forjarla siempre sale, sea cual sea la calidad.
static func blueprint(id: StringName) -> BlueprintResource:
	if not RECIPES.has(id):
		return null
	var r: Dictionary = RECIPES[id]
	var bp := BlueprintResource.new()
	bp.blueprint_id = id
	bp.display_name = r.name
	bp.description = DESCRIPTION
	bp.materials = r.materials.duplicate()
	bp.tags = PackedStringArray(["ampliacion"])
	var trials := []
	for kind in r.trials:
		trials.append(_trial(id, kind, r.name))
	bp.trial_sequence = trials
	return bp


static func _trial(id: StringName, kind: StringName, label: String) -> TrialResource:
	var cfg: TrialConfig
	var scene: PackedScene
	var minigame: StringName
	match kind:
		&"sew":
			var c := SewTrialConfig.new()
			c.stitch_speed = 1.0
			c.precision = 0.5
			c.label = label
			cfg = c
			scene = load("res://scenes/Minigames/SewOSU.tscn")
			minigame = &"SewOSU"
		&"forge":
			var c := ForgeTrialConfig.new()
			c.forge_speed = 1.0
			c.precision = 0.5
			c.label = label
			cfg = c
			scene = load("res://scenes/Minigames/ForgeTemp.tscn")
			minigame = &"Forge"
		&"hammer":
			var c := HammerTrialConfig.new()
			c.tempo_bpm = 90
			c.hammer_speed = 90
			c.precision = 0.5
			c.label = label
			cfg = c
			scene = load("res://scenes/Minigames/HammerMinigame.tscn")
			minigame = &"hammer"
		&"quench":
			var c := QuenchTrialConfig.new()
			c.quench_speed = 1.0
			c.time_window = 0.3
			c.label = label
			cfg = c
			scene = load("res://scenes/Minigames/QuenchWater.tscn")
			minigame = &"quench"
	cfg.minigame_id = minigame
	cfg.minigame_scene = scene
	cfg.trial_id = StringName("%s_%s" % [id, kind])
	cfg.blueprint_id = id
	if cfg.has_method("prepare"):
		cfg.prepare()
	var t := TrialResource.new()
	t.trial_id = cfg.trial_id
	t.display_name = label
	t.minigame_id = minigame
	t.minigame_scene = scene
	t.min_score = 0.0
	t.config = cfg
	return t
```

- [ ] **Step 3: `InventoryManager.gd`**

Junto a las funciones de estadísticas:

```gdscript
## Recetas de ampliación que se pueden forjar: desbloqueadas por el récord y aún sin forjar.
func available_grid_recipes(record: int) -> Array[StringName]:
	var out: Array[StringName] = []
	for id in GridExpansions.unlocked_for_record(record):
		if not (id in expansions):
			out.append(id)
	return out


## Receta de ampliación terminada: la rejilla de Tico crece al tamaño siguiente. false si ya estaba.
func apply_grid_expansion(id: StringName) -> bool:
	if not GridExpansions.is_expansion(id) or id in expansions:
		return false
	expansions.append(id)
	hero_grid.resize(GridExpansions.size_after(expansions.size()))
	grid_resized.emit(hero_grid.size)
	_changed(true)  # las zonas de borde se mueven con la rejilla
	return true
```

- [ ] **Step 4: `CraftingManager.gd`**

`_resolve_blueprint`: las recetas de ampliación no están en la biblioteca de planos.

```gdscript
func _resolve_blueprint(recipe_id: StringName) -> BlueprintResource:
	if GridExpansions.is_expansion(recipe_id):
		return GridExpansions.blueprint(recipe_id)
	if not has_node('/root/DataManager'):
		push_warning("CraftingManager: DataManager unavailable when resolving blueprint %s" % String(recipe_id))
		return null
	return get_node('/root/DataManager').get_blueprint(recipe_id)
```

Encargo de una receta, junto a `place_own_order`:

```gdscript
## Encarga una receta de ampliación de la rejilla (spec del inventario en rejilla, apartado 7): cobra
## sus materiales y la encola sin oro. Devuelve &"" si se encola, o el motivo: &"locked" (no
## desbloqueada, ya forjada o ya en la cola), &"queue_full" o &"no_materials". Si falla, no cobra nada.
func place_grid_recipe(id: StringName) -> StringName:
	var inv = get_node_or_null("/root/InventoryManager")
	var gm = get_node_or_null("/root/GameManager")
	if inv == null or not GridExpansions.is_expansion(id):
		return &"locked"
	var record: int = int(gm.best_enemy_level) if gm else 1
	if not (id in inv.available_grid_recipes(record)) or _is_queued(id):
		return &"locked"
	if not queue.has(null):
		return &"queue_full"
	var mats: Dictionary = GridExpansions.RECIPES[id].materials
	if not inv.has_materials(mats) or not inv.consume_materials(mats):
		return &"no_materials"
	if not enqueue(id, 0, 1, true):
		for mat_id in mats:
			inv.add_item(mat_id, mats[mat_id])
		return &"queue_full"
	return &""


func _is_queued(recipe_id: StringName) -> bool:
	for task in queue:
		if task != null and task.blueprint and task.blueprint.blueprint_id == recipe_id:
			return true
	return false
```

En `_finalize_task`, justo después de construir el diccionario `result` y antes de emitirlo o devolverlo:

```gdscript
	# Receta de ampliación: siempre sale, no crea pieza (su plano no tiene result_item) ni da oro
	# (es un encargo propio). La rejilla de Tico crece.
	if task.blueprint and GridExpansions.is_expansion(task.blueprint.blueprint_id):
		var inv_x = get_node_or_null("/root/InventoryManager")
		if inv_x and inv_x.has_method("apply_grid_expansion"):
			inv_x.apply_grid_expansion(task.blueprint.blueprint_id)
			result["grid_expansion"] = task.blueprint.blueprint_id
			result["grid_size"] = inv_x.hero_grid_size()
```

- [ ] **Step 5: Aviso al vencer al jefe (`GameManager.gd`)**

Señal, junto a las demás:

```gdscript
signal grid_recipe_unlocked(recipe_id)  # Receta de ampliación: primera victoria sobre el jefe 10, 20, 30 o 40
```

Al final de `register_enemy_defeat(level)`, dentro de la función (que ya sale si la partida no está en marcha):

```gdscript
	# Recetas de ampliación de la rejilla (spec del inventario en rejilla, apartado 7): la primera vez que
	# cae el jefe de la sala 10, 20, 30 o 40 del ciclo I. El récord aún no ha pasado de esta sala.
	var recipe := GridExpansions.recipe_for_boss_room(level)
	if recipe != &"" and best_enemy_level <= level:
		emit_signal("grid_recipe_unlocked", recipe)
```

- [ ] **Step 6: Aviso en la franja (`HeroViewOverlay.gd`)**

En `_ready()`, dentro del `if _game_manager:`:

```gdscript
		if _game_manager.has_signal("grid_recipe_unlocked"):
			_game_manager.grid_recipe_unlocked.connect(_on_grid_recipe_unlocked)
```

```gdscript
## Receta de ampliación desbloqueada: aviso en cola (sale tras el cartel del jefe o del hito).
func _on_grid_recipe_unlocked(recipe_id: StringName) -> void:
	var r: Dictionary = GridExpansions.RECIPES.get(recipe_id, {})
	show_toast(tr("¡Nueva receta: %s!") % tr(String(r.get("name", ""))), Color("9fe0ff"))
	Sfx.play(&"blueprint_found", 1.0)
```

- [ ] **Step 7: Las recetas en la biblioteca (`BlueprintLibraryPanel.gd` y `HUDMain.gd`)**

En `BlueprintLibraryPanel.gd`:

```gdscript
signal grid_recipe_requested(recipe_id: StringName)

var _grid_cards: Dictionary = {}  # receta → tarjeta
var _grid_status: Dictionary = {}  # receta → Label con los materiales (o el motivo del rechazo)
```

En `populate_blueprints()`, justo después de vaciar la lista (y de vaciar `_cards`, de los rangos), las recetas van primero:

```gdscript
	_grid_cards.clear()
	_grid_status.clear()
	var inv = get_node_or_null("/root/InventoryManager")
	var gm = get_node_or_null("/root/GameManager")
	if inv and gm and inv.has_method("available_grid_recipes"):
		for recipe_id in inv.available_grid_recipes(int(gm.best_enemy_level)):
			blueprint_list.add_child(_grid_recipe_card(recipe_id))
```

```gdscript
## Tarjeta de una receta de ampliación: nombre, qué hace, materiales y el botón Forjar.
func _grid_recipe_card(recipe_id: StringName) -> Control:
	var r: Dictionary = GridExpansions.RECIPES[recipe_id]
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(160, 230)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(box)
	for spec in [[tr(r.name), Color("9fe0ff"), 26], [tr(GridExpansions.DESCRIPTION), Color(0.85, 0.8, 0.72), 20]]:
		var l := Label.new()
		l.text = spec[0]
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_color_override("font_color", spec[1])
		l.add_theme_font_size_override("font_size", spec[2])
		box.add_child(l)
	var mats := Label.new()
	mats.text = _materials_text(r.materials)
	mats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mats.add_theme_font_size_override("font_size", 18)
	box.add_child(mats)
	var btn := Button.new()
	btn.text = tr("Forjar")
	btn.pressed.connect(func(): grid_recipe_requested.emit(recipe_id))
	box.add_child(btn)
	_grid_cards[recipe_id] = card
	_grid_status[recipe_id] = mats
	return card


func _materials_text(mats: Dictionary) -> String:
	var parts := []
	for mat_id in mats:
		var res = load("res://data/materials/%s.tres" % mat_id)
		var mat_name: String = tr(res.display_name) if res and "display_name" in res else String(mat_id)
		parts.append("%d %s" % [int(mats[mat_id]), mat_name])
	return " · ".join(parts)


## La receta no se ha podido encargar: la tarjeta tiembla y el motivo se ve un momento.
func reject_grid(recipe_id: StringName, reason: StringName) -> void:
	var card: Control = _grid_cards.get(recipe_id)
	var status: Label = _grid_status.get(recipe_id)
	if card == null or status == null:
		return
	var base_x := card.position.x
	var tw := create_tween()
	for i in 4:
		tw.tween_property(card, "position:x", base_x + (8.0 if i % 2 == 0 else -8.0), 0.045)
	tw.tween_property(card, "position:x", base_x, 0.05)
	var old := status.text
	status.text = tr(REJECT_TEXTS.get(reason, "Faltan materiales"))
	status.add_theme_color_override("font_color", Color(1.0, 0.42, 0.36))
	get_tree().create_timer(1.4).timeout.connect(func():
		if is_instance_valid(status):
			status.text = old
			status.remove_theme_color_override("font_color"))
```

Si el motivo es `&"locked"`, `REJECT_TEXTS` enseña "Rango bloqueado". Para una receta eso quiere decir que ya está en la cola; como el aviso es igual de claro, no se añade texto nuevo.

En `HUDMain.gd`, en `_ready()`:

```gdscript
	if blueprint_library and blueprint_library.has_signal("grid_recipe_requested"):
		blueprint_library.grid_recipe_requested.connect(_on_grid_recipe_requested)
```

```gdscript
## Receta de ampliación desde la biblioteca: la cobra y lanza los minijuegos, o explica por qué no.
func _on_grid_recipe_requested(recipe_id: StringName) -> void:
	var reason: StringName = _crafting_manager.place_grid_recipe(recipe_id) if _crafting_manager else &"locked"
	if reason == &"":
		Sfx.play(&"request_accept")
		if blueprint_library and blueprint_library.has_method("close"):
			blueprint_library.close()
		_start_first_queued_task()
	else:
		Sfx.play(&"ui_tap", 0.0, 0.55)  # "tunc" grave: no se puede
		if blueprint_library and blueprint_library.has_method("reject_grid"):
			blueprint_library.reject_grid(recipe_id, reason)
```

- [ ] **Step 8: Pantalla de resultado (`CraftResultScreen.gd`)**

En `show_result`, justo después del bloque que decide `item_name` (antes de `_item_name_label.text = item_name`):

```gdscript
	if result.has("grid_expansion"):
		item_name = tr(String(GridExpansions.RECIPES[result.grid_expansion].name))
```

En `_populate_stats(result)`, después de vaciar `_stats_container`. Con una receta sale "¡La rejilla crece!" y el tamaño nuevo; con una pieza, además de sus estadísticas, las aristas y la habilidad si es legendaria:

```gdscript
	if result.has("grid_expansion"):
		var grid_size: Vector2i = result.get("grid_size", Vector2i.ZERO)
		for text in [tr("¡La rejilla crece!"), tr("Rejilla de %d×%d") % [grid_size.x, grid_size.y]]:
			_stats_container.add_child(_result_line(text, Color("9fe0ff"), 34))
		return
```

Y al final de la función, después del bucle de estadísticas:

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

- [ ] **Step 9: Textos**

Filas en `locale/textos.csv` ("Forjar" ya viene de los rangos):

```
Amplía la rejilla de Tico,Amplía la rejilla de Tico,Expands Tico's grid
¡Nueva receta: %s!,¡Nueva receta: %s!,New recipe: %s!
¡La rejilla crece!,¡La rejilla crece!,The grid grows!
Rejilla de %d×%d,Rejilla de %d×%d,Grid %d×%d
```

En `TextTests._code_table_texts()`, junto a las recetas, añade la descripción:

```gdscript
	out.append([GridExpansions.DESCRIPTION, "GridExpansions.DESCRIPTION"])
```

Run: `--import`

- [ ] **Step 10: Ejecutar y ver que pasa**

Run: la batería. Expected: 0 fallos.

- [ ] **Step 11: Commit**

```bash
git add scripts/core/GridExpansions.gd scripts/autoload/InventoryManager.gd scripts/autoload/CraftingManager.gd scripts/autoload/GameManager.gd scripts/ui/HeroViewOverlay.gd scripts/ui/BlueprintLibraryPanel.gd scripts/ui/HUDMain.gd scripts/ui/CraftResultScreen.gd scripts/tests/InventoryGridTests.gd scripts/tests/TextTests.gd locale/textos.csv
git commit -m "feat: recetas de ampliación de la rejilla: aviso del jefe, encargo en la biblioteca y rejilla que crece"
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
	gm.on_boss_appeared()
	check(gm.has_buff(&"speed") and is_equal_approx(gm.buff_remaining(&"speed"), 30.0), "se bebe sola al aparecer un jefe: 30 s")
	gm.clear_buffs()
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
func on_boss_appeared() -> void:
	for pair in [[&"potion_speed", BUFF_SPEED], [&"potion_luck", BUFF_LUCK]]:
		if not has_buff(pair[1]):
			drink_potion(pair[0])
```

Beber sola cuenta para el muro (spec del inventario, apartado 8). En `drink_potion`, justo después de `emit_signal("potion_drunk", id)`, llama a la función de los rangos que reintenta el muro al beber (tarea 0). Si los rangos la llamaban desde la compra de `ShopPanel`, esa llamada desaparece con la compra nueva (paso 5) y solo queda esta.

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

### Task 14: Pixel art de las piezas, las aristas, las pociones y el panel (herramienta)

**Files:**
- Create: `tools/pixel_art/gear.py`, `tools/pixel_art/tests/test_gear.py`
- Modify: `tools/pixel_art/export.py`
- Generated: `art/sprites/pixel/gear/*.png`, `art/sprites/pixel/gear/gear.json` y `tools/pixel_art/out/gear_review.png` (este último, ignorado por git)

**Interfaces:**
- Consumes:
  - de la fase 2 del pixel art, si está integrada: `recolor.ACCENT`, `recolor.QUALITY_RAMPS` y `recolor.SHINE`;
  - si no lo está, los mismos valores, copiados en `gear.py`. `gear.py` no toca `pixel_kit.py`: sin la fase 2, añade a `pixel_kit.PALETTE` en memoria las letras de acento que le faltan, con los colores de la fase 2. Así las dos ramas no chocan al integrarse.
- Produces (consume la tarea 15):
  - `gear/<item_id>.png`: las 12 piezas con su forma limpia (22 px por casilla), sin girar, con el acento en la rampa reservada de la fase 2: `+` claro (`#ff80ff`), `*` base (`#ff00ff`) y `#` oscuro (`#800080`);
  - `gear/arista_metal_{0,1,2}.png` y `gear/arista_leather_{0,1,2}.png`: rebabas de 22×22 pegadas a su borde izquierdo;
  - `gear/potion_heal.png`, `potion_speed.png` y `potion_luck.png` (22×22);
  - `gear/zone_head.png`, `zone_feet.png`, `zone_off_hand.png` y `zone_main_hand.png`: iconos de las zonas (11×11);
  - `gear/ui_cell.png` y `gear/ui_cell_locked.png` (22×22), y `gear/ui_frame.png`: un marco de 12×12 para 9 partes, con bordes de 4 px;
  - `gear/gear.json`: `shapes`, `accent` (los 3 colores reservados), `accent_px` (pieza → sus píxeles de acento como `[x, y, tono]`, con el tono 0 claro, 1 base y 2 oscuro), `quality_ramps` (calidad → claro, base y oscuro) y `shine` (calidad → fuerza del destello). Los colores van en hexadecimal sin `#`, como en el `hero.json` de la fase 2. Con `accent_px`, el juego recolorea sin recorrer cada píxel.
- Las piezas se dibujan con primitivas del kit (`put`, `rect`, `fill_poly`, `fill_ellipse` y `line`) a partir del tamaño de su forma, y al final se recortan a sus casillas. Es un punto de partida: la hoja de revisión sirve para retocarlas a mano en sus funciones, igual que el resto del elenco.

- [ ] **Step 1: Pruebas de la herramienta (fallan)**

`tools/pixel_art/tests/test_gear.py`:

```python
import json
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import gear  # noqa: E402


class GearArtTest(unittest.TestCase):
    def test_every_piece_fits_its_shape(self):
        for item_id, cells in gear.SHAPES.items():
            s = gear.PIECES[item_id]()
            w = (max(x for x, _ in cells) + 1) * gear.CELL
            h = (max(y for _, y in cells) + 1) * gear.CELL
            self.assertEqual((s.w, s.h), (w, h), item_id)
            painted = set()
            for y in range(s.h):
                for x in range(s.w):
                    if s.px[y][x] != ".":
                        self.assertIn((x // gear.CELL, y // gear.CELL), cells, f"{item_id}: píxel fuera de la forma en {(x, y)}")
                        painted.add((x // gear.CELL, y // gear.CELL))
            self.assertEqual(painted, set(cells), f"{item_id}: cada casilla de la forma lleva dibujo")

    def test_every_piece_has_its_accent(self):
        for item_id in gear.SHAPES:
            chars = [c for row in gear.PIECES[item_id]().px for c in row]
            self.assertGreaterEqual(sum(c in gear.ACCENT for c in chars), 4, f"{item_id}: sin acento no se vería la calidad")

    def test_shapes_match_the_game_data(self):
        for item_id, cells in gear.SHAPES.items():
            self.assertEqual(sorted(cells), sorted(gear.tres_shape(item_id)), item_id)

    def test_arista_tiles_hang_from_their_left_edge(self):
        for name, draw in gear.ARISTAS.items():
            s = draw()
            self.assertEqual((s.w, s.h), (gear.CELL, gear.CELL), name)
            self.assertTrue(any(s.px[y][0] != "." for y in range(s.h)), f"{name}: no toca su borde izquierdo")

    def test_ui_sizes(self):
        for name, draw in gear.ZONES.items():
            self.assertEqual((draw().w, draw().h), (11, 11), name)
        for name, draw in gear.UI.items():
            size = (12, 12) if name == "ui_frame" else (gear.CELL, gear.CELL)
            self.assertEqual((draw().w, draw().h), size, name)

    def test_export_writes_everything(self):
        out = gear.export_gear()
        for name in list(gear.PIECES) + list(gear.ARISTAS) + list(gear.POTIONS) + list(gear.ZONES) + list(gear.UI):
            self.assertTrue((out / f"{name}.png").exists(), name)
        data = json.loads((out / "gear.json").read_text(encoding="utf-8"))
        self.assertEqual(len(data["accent"]), 3)
        self.assertEqual(data["quality_ramps"]["legendary"][1], "ffa629")
        self.assertEqual(sorted(data["shapes"]), sorted(gear.SHAPES))
        for item_id in gear.PIECES:
            px = gear.PIECES[item_id]().px
            listed = data["accent_px"][item_id]
            self.assertGreaterEqual(len(listed), 4, item_id)
            for x, y, tone in listed:
                self.assertEqual(px[y][x], gear.ACCENT[tone], f"{item_id}: ({x}, {y}) no es acento de tono {tone}")


if __name__ == "__main__":
    unittest.main()
```

Run: `python -m unittest discover tools/pixel_art/tests`
Expected: `ModuleNotFoundError: No module named 'gear'`.

- [ ] **Step 2: `tools/pixel_art/gear.py`**

```python
"""Pixel art del inventario en rejilla (spec doc/specs/2026-09-27-inventario-en-rejilla.md, apartado 9.5).

Lo llama export.py. Escribe a escala 1 en art/sprites/pixel/gear/ (el juego lo pinta a ×5):
  <item_id>.png                                  las 12 piezas con su forma limpia, 22 px por casilla
  arista_metal_<n>.png, arista_leather_<n>.png   rebabas de 22×22 pegadas a su borde izquierdo
  potion_heal.png, potion_speed.png, potion_luck.png
  zone_<tipo>.png                                iconos de 11×11 de las 4 zonas
  ui_cell.png, ui_cell_locked.png, ui_frame.png  casilla, casilla por abrir y marco de 12×12 (9 partes)
  gear.json                                      formas, colores de acento, rampas de calidad y destello
y la hoja de revisión tools/pixel_art/out/gear_review.png (a ×4, con el acento en naranja legendario).

El acento de cada pieza (acanalado, banda, emblema, penacho) va en la rampa reservada de la fase 2 del
pixel art (recolor.ACCENT: claro, base y oscuro). El juego la cambia por la rampa de la calidad
(GearSprites, con las rampas de gear.json). Todo se dibuja con margen para el contorno y al final se
borra lo que se salga de las casillas de la forma.
"""
import json
import re
from pathlib import Path

from PIL import Image

from pixel_kit import PALETTE, Sprite, hex_to_rgba

try:  # fase 2 del pixel art: rampas reservadas y de calidad
    from recolor import ACCENT, QUALITY_RAMPS, SHINE
except ImportError:  # sin la fase 2: los mismos valores (su plan, tarea 1)
    ACCENT = ("+", "*", "#")
    QUALITY_RAMPS = {
        "common": ("#f4f7fa", "#cfd6dc", "#8a93a3"),
        "uncommon": ("#b8f5a0", "#6ad16a", "#2f8a4a"),
        "rare": ("#a8e0ff", "#4ea3ff", "#2a5cc2"),
        "epic": ("#e0b8ff", "#b46bff", "#6a35b8"),
        "legendary": ("#ffe08a", "#ffa629", "#c2581c"),
    }
    SHINE = {"epic": 0.6, "legendary": 1.0}
    for _letter, _hex in zip(ACCENT, ("#ff80ff", "#ff00ff", "#800080")):
        PALETTE.setdefault(_letter, _hex)

LIGHT, BASE, DARK = ACCENT

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
OUT = REPO / "art" / "sprites" / "pixel" / "gear"
ITEMS = REPO / "data" / "items"
REVIEW = HERE / "out" / "gear_review.png"
CELL = 22

# Casillas limpias de cada pieza, sin girar (las mismas que data/items/*.tres)
SHAPES = {
    "sword_basic": [(0, 0), (0, 1)],
    "sword_advanced": [(0, 0), (0, 1), (0, 2)],
    "sword_masterwork": [(0, 0), (0, 1), (0, 2), (0, 3)],
    "shield_basic": [(0, 0), (0, 1)],
    "shield_advanced": [(0, 0), (1, 0), (0, 1), (1, 1)],
    "shield_master": [(0, 0), (1, 0), (0, 1), (1, 1), (0, 2), (1, 2)],
    "helmet_basic": [(0, 0)],
    "helmet_advanced": [(0, 0), (1, 0)],
    "helmet_master": [(1, 0), (0, 1), (1, 1), (2, 1)],
    "boots_basic": [(0, 0)],
    "boots_advanced": [(0, 0), (0, 1), (1, 1)],
    "boots_master": [(0, 0), (0, 1), (0, 2), (1, 2)],
}


def blank(item_id):
    cells = SHAPES[item_id]
    return Sprite((max(x for x, _ in cells) + 1) * CELL, (max(y for _, y in cells) + 1) * CELL)


def finish(s, item_id):
    """Contorno de 1 px y fuera todo lo que se salga de las casillas de la pieza."""
    s.outline()
    cells = SHAPES[item_id]
    for y in range(s.h):
        for x in range(s.w):
            if (x // CELL, y // CELL) not in cells:
                s.px[y][x] = "."
    return s


def ramp(t):
    """Tono de acento para una fracción 0..1: claro al principio, oscuro al final."""
    return LIGHT if t < 0.34 else BASE if t < 0.67 else DARK


def shade(s, base, light, dark, left, right):
    """Luz a la izquierda de `left` y sombra a la derecha de `right` sobre los píxeles `base`."""
    for y in range(s.h):
        for x in range(s.w):
            if s.px[y][x] == base:
                s.px[y][x] = light if x < left else dark if x > right else base


# ── Espadas ────────────────────────────────────────────────────────────
# Nivel → hoja (luz, medio, sombra), guarda (claro, oscuro), empuñadura (claro, oscuro) y pomo
SWORD_LOOK = {
    "basic": ("M", "i", "I", "i", "I", "W", "v", "i"),
    "advanced": ("m", "M", "i", "M", "i", "L", "d", "M"),
    "master": ("m", "M", "i", "g", "G", "L", "d", "G"),
}


def sword(item_id, level):
    """De pie: punta arriba, hoja con el acanalado de acento, guarda, empuñadura y pomo en la última casilla."""
    light, mid, dark, guard, guard_d, grip, grip_d, pommel = SWORD_LOOK[level]
    s = blank(item_id)
    h = s.h
    gy = h - 17  # fila de la guarda
    s.put(2, 10, light + mid)
    s.put(3, 9, light + light + mid + dark)
    for y in range(4, gy):
        s.put(y, 9, light + ramp((y - 4) / max(1, gy - 5)) + mid + dark)
    s.put(gy, 4, guard * 14)
    s.put(gy + 1, 3, guard_d + guard * 14 + guard_d)
    s.put(gy + 2, 4, guard_d * 14)
    for y in range(gy + 3, h - 6):
        s.put(y, 9, grip * 3 + grip_d if y % 2 else grip_d + grip * 2 + grip_d)
    for y in range(h - 6, h - 2):
        s.put(y, 8, pommel * 6)
    if level == "master":
        s.put(h - 5, 10, "bb")  # gema en el pomo
    return finish(s, item_id)


# ── Escudos ────────────────────────────────────────────────────────────
def shield_basic(item_id):
    """Escudo de tablas: madera con canto de hierro y una banda pintada de acento."""
    s = blank(item_id)
    for y in range(3, 41):
        for x in range(3, 19):
            s.px[y][x] = "v" if (x - 3) % 4 == 0 and x > 3 else ("w" if (x - 3) // 4 % 2 == 0 else "W")
    for x in range(3, 19):
        s.px[3][x] = "i"
        s.px[40][x] = "I"
    for y in range(3, 41):
        s.px[y][3] = "i"
        s.px[y][18] = "I"
    for y, ch in ((19, LIGHT), (20, BASE), (21, BASE), (22, DARK)):
        s.put(y, 4, ch * 14)
    for x, y in ((3, 3), (18, 3), (3, 40), (18, 40)):
        s.px[y][x] = "."  # esquinas redondeadas
    return finish(s, item_id)


def shield_advanced(item_id):
    """Escudo redondo de acero: canto oscuro, cruz de acento y umbo."""
    s = blank(item_id)

    def steel(x, y, nx, ny):
        if nx * nx + ny * ny > 0.8:
            return "I"
        return "m" if nx + ny < -0.6 else "i" if nx + ny > 0.7 else "M"

    s.fill_ellipse(21.5, 21.5, 19, 19, steel)
    for i in range(9, 35):
        c = ramp((i - 9) / 25)
        for d in (20, 21, 22, 23):
            if s.px[d][i] != "I":
                s.px[d][i] = c
            if s.px[i][d] != "I":
                s.px[i][d] = c
    s.fill_ellipse(21.5, 21.5, 3, 3, "m")
    return finish(s, item_id)


def shield_master(item_id):
    """Escudo torre de acero con ribete de oro y un chevrón de acento."""
    s = blank(item_id)
    s.fill_poly([(4, 3), (39, 3), (39, 50), (21.5, 62), (4, 50)], "M")
    shade(s, "M", "m", "i", 9, 34)
    s.line([(4, 3), (39, 3), (39, 50), (21, 62), (4, 50), (4, 3)], "G")
    s.fill_poly([(12, 20), (21.5, 29), (31, 20), (31, 27), (21.5, 37), (12, 27)], BASE)
    s.line([(12, 20), (21, 29), (31, 20)], LIGHT)
    s.line([(12, 27), (21, 37), (31, 27)], DARK)
    return finish(s, item_id)


# ── Cascos ─────────────────────────────────────────────────────────────
def helmet_basic(item_id):
    """Gorro de cuero con banda de acento."""
    s = blank(item_id)
    s.fill_ellipse(10.5, 13, 8, 9, lambda x, y, nx, ny: None if y > 14 else ("l" if nx < -0.4 else "d" if nx > 0.5 else "L"))
    s.put(13, 3, BASE * 16)
    s.put(14, 3, DARK * 16)
    s.put(15, 2, "d" * 18)
    return finish(s, item_id)


def helmet_advanced(item_id):
    """Yelmo de hierro con cuernos de hueso, banda de acento y visera."""
    s = blank(item_id)
    s.fill_ellipse(21.5, 15, 11, 11, lambda x, y, nx, ny: None if y > 18 else ("m" if nx < -0.5 else "i" if nx > 0.5 else "M"))
    s.put(11, 11, LIGHT * 22)
    s.put(12, 11, BASE * 22)
    s.put(16, 13, "K" * 18)
    s.fill_poly([(11, 12), (3, 3), (6, 2), (13, 9)], "e")
    s.fill_poly([(32, 12), (40, 3), (37, 2), (30, 9)], "e")
    for y in (17, 18):
        s.put(y, 12, "iiii")
        s.put(y, 28, "iiii")
    return finish(s, item_id)


def helmet_master(item_id):
    """Gran yelmo: penacho de acento en la casilla de arriba (forma en T) y alas en las de los lados."""
    s = blank(item_id)
    s.fill_poly([(27, 21), (25, 8), (29, 3), (37, 4), (40, 11), (36, 21)], BASE)
    s.line([(26, 20), (25, 9), (29, 4)], LIGHT)
    s.line([(37, 5), (39, 11), (35, 20)], DARK)
    for y in (19, 20, 21):
        s.put(y, 30, "GGGG")
    s.fill_poly([(9, 25), (56, 25), (59, 32), (56, 41), (9, 41), (6, 32)], "M")
    for y in range(22, 44):
        for x in range(s.w):
            if s.px[y][x] == "M":
                s.px[y][x] = "m" if y < 29 else "i" if y > 37 else "M"
    s.put(27, 9, "G" * 48)
    for y in (32, 33):
        s.put(y, 16, "K" * 13)
        s.put(y, 37, "K" * 13)
    return finish(s, item_id)


# ── Botas ──────────────────────────────────────────────────────────────
def boots_basic(item_id):
    """Bota de cuero con banda de acento."""
    s = blank(item_id)
    for y in range(3, 15):
        s.put(y, 7, "lLLLLd")
    s.put(15, 7, "lLLLLLLLLLd")
    s.put(16, 7, "LLLLLLLLLLL")
    s.put(17, 7, "LLLLLLLLLLd")
    s.put(18, 7, "ddddddddddd")
    s.put(6, 7, BASE * 6)
    s.put(7, 7, DARK * 6)
    return finish(s, item_id)


def boots_advanced(item_id):
    """Bota alta con placas de hierro (L de 3: caña en la columna izquierda, pie hacia la derecha)."""
    s = blank(item_id)
    for y in range(3, 41):
        s.put(y, 5, "mMMMMMMMMMMi")
    for y in range(30, 41):
        s.put(y, 17, "M" * 21 + "i")
    s.put(41, 5, "I" * 34)
    for y in (8, 24):
        s.put(y, 5, BASE * 12)
        s.put(y + 1, 5, DARK * 12)
    s.put(14, 5, LIGHT * 12)
    return finish(s, item_id)


def boots_master(item_id):
    """Greba de acero con rodillera de acento y puntera de oro (L de 4)."""
    s = blank(item_id)
    for y in range(3, 63):
        s.put(y, 5, "mmMMMMMMMMii")
    for y in range(52, 63):
        s.put(y, 17, "M" * 16 + "GGGGGG")
    s.put(63, 5, "I" * 34)
    for y, ch in ((22, LIGHT), (23, BASE), (24, BASE), (25, BASE), (26, DARK)):
        s.put(y, 4, ch * 14)
    return finish(s, item_id)


PIECES = {
    "sword_basic": lambda: sword("sword_basic", "basic"),
    "sword_advanced": lambda: sword("sword_advanced", "advanced"),
    "sword_masterwork": lambda: sword("sword_masterwork", "master"),
    "shield_basic": lambda: shield_basic("shield_basic"),
    "shield_advanced": lambda: shield_advanced("shield_advanced"),
    "shield_master": lambda: shield_master("shield_master"),
    "helmet_basic": lambda: helmet_basic("helmet_basic"),
    "helmet_advanced": lambda: helmet_advanced("helmet_advanced"),
    "helmet_master": lambda: helmet_master("helmet_master"),
    "boots_basic": lambda: boots_basic("boots_basic"),
    "boots_advanced": lambda: boots_advanced("boots_advanced"),
    "boots_master": lambda: boots_master("boots_master"),
}


# ── Aristas: rebaba pegada al borde izquierdo (el juego la gira hacia la pieza) ──
def _arista(poly, base, light, dark):
    s = Sprite(CELL, CELL)
    s.fill_poly(poly, base)
    for y in range(CELL):
        for x in range(CELL):
            if s.px[y][x] == base:
                up = y > 0 and s.px[y - 1][x] == "."
                down = y < CELL - 1 and s.px[y + 1][x] == "."
                s.px[y][x] = light if up else dark if down else base
    return s.outline()


ARISTAS = {
    "arista_metal_0": lambda: _arista([(0, 5), (8, 3), (13, 7), (10, 11), (15, 15), (7, 17), (0, 16)], "I", "i", "U"),
    "arista_metal_1": lambda: _arista([(0, 8), (11, 6), (16, 10), (9, 13), (12, 17), (0, 15)], "I", "i", "U"),
    "arista_metal_2": lambda: _arista([(0, 4), (6, 6), (14, 4), (11, 10), (16, 14), (5, 18), (0, 17)], "I", "i", "U"),
    "arista_leather_0": lambda: _arista([(0, 8), (10, 8), (13, 11), (10, 14), (0, 13)], "L", "l", "d"),
    "arista_leather_1": lambda: _arista([(0, 7), (12, 7), (17, 12), (14, 14), (11, 10), (0, 10)], "L", "l", "d"),
    "arista_leather_2": lambda: _arista([(0, 10), (8, 9), (11, 12), (8, 15), (0, 14)], "L", "l", "d"),
}


# ── Pociones ───────────────────────────────────────────────────────────
def _potion(body, body_dark):
    s = Sprite(CELL, CELL)
    s.put(2, 9, "WWWW")
    s.put(3, 9, "vvvv")
    for y in range(4, 8):
        s.put(y, 9, "ffff")
    s.fill_ellipse(10.5, 13.5, 7, 6, lambda x, y, nx, ny: body_dark if nx + ny > 0.6 else body)
    s.put(10, 7, "Y")
    s.put(11, 7, "Y")
    return s.outline()


POTIONS = {
    "potion_heal": lambda: _potion("r", "R"),
    "potion_speed": lambda: _potion("b", "B"),
    "potion_luck": lambda: _potion("A", "c"),
}


# ── Iconos de las zonas (11×11, en hueso: se leen sobre la casilla oscura) ──
def zone_head():
    s = Sprite(11, 11)
    s.fill_ellipse(5.5, 6.5, 4.5, 5, lambda x, y, nx, ny: None if y > 6 else ("e" if nx < -0.3 else "E"))
    s.put(7, 1, "uuuuuuuuu")
    return s.outline()


def zone_feet():
    s = Sprite(11, 11)
    s.rect(3, 1, 4, 6, "E")
    s.rect(3, 7, 7, 2, "E")
    s.put(1, 3, "eeee")
    s.put(9, 3, "uuuuuuu")
    return s.outline()


def zone_off_hand():
    s = Sprite(11, 11)
    s.fill_poly([(1.5, 1.5), (9.5, 1.5), (9.5, 6), (5.5, 10), (1.5, 6)], "E")
    s.line([(5, 2), (5, 8)], "u")
    return s.outline()


def zone_main_hand():
    s = Sprite(11, 11)
    s.line([(2, 8), (8, 2)], "e")
    s.line([(3, 8), (9, 2)], "E")
    s.line([(1, 6), (4, 9)], "u")
    s.put(9, 1, "u")
    return s.outline()


ZONES = {
    "zone_head": zone_head,
    "zone_feet": zone_feet,
    "zone_off_hand": zone_off_hand,
    "zone_main_hand": zone_main_hand,
}


# ── Interfaz del panel ─────────────────────────────────────────────────
def ui_cell():
    """Casilla de la rejilla: fondo oscuro hundido, con la sombra arriba a la izquierda."""
    s = Sprite(CELL, CELL)
    s.rect(0, 0, CELL, CELL, "O")
    s.rect(1, 1, CELL - 2, CELL - 2, "9")
    s.put(1, 1, "V" * (CELL - 2))
    for y in range(1, CELL - 1):
        s.put(y, 1, "V")
        s.put(y, CELL - 2, "N")
    s.put(CELL - 2, 1, "N" * (CELL - 2))
    return s


def ui_cell_locked():
    """Casilla por abrir: borde discontinuo sobre fondo transparente."""
    s = Sprite(CELL, CELL)
    for i in range(2, CELL - 2):
        if (i // 3) % 2 == 0:
            for x, y in ((i, 2), (i, CELL - 3), (2, i), (CELL - 3, i)):
                s.put(y, x, "D")
    return s


def ui_frame():
    """Marco de madera de 12×12 para 9 partes (bordes de 4 px): huecos de consumible y zona de venta."""
    s = Sprite(12, 12)
    s.rect(0, 0, 12, 12, "O")
    s.rect(1, 1, 10, 10, "W")
    s.put(1, 1, "w" * 10)
    s.rect(2, 2, 8, 8, "v")
    s.rect(3, 3, 6, 6, "9")
    return s


UI = {"ui_cell": ui_cell, "ui_cell_locked": ui_cell_locked, "ui_frame": ui_frame}


def tres_shape(item_id):
    """Forma que guarda data/items/<item_id>.tres (shape_cells), como lista de (x, y)."""
    text = (ITEMS / f"{item_id}.tres").read_text(encoding="utf-8")
    m = re.search(r"shape_cells = Array\[Vector2i\]\(\[(.*?)\]\)", text)
    if not m:
        return []
    return [(int(a), int(b)) for a, b in re.findall(r"Vector2i\((-?\d+), (-?\d+)\)", m.group(1))]


def accent_pixels(sprite):
    """Píxeles de acento de un sprite: [x, y, tono], con el tono 0 claro, 1 base y 2 oscuro."""
    return [[x, y, ACCENT.index(ch)] for y, row in enumerate(sprite.px) for x, ch in enumerate(row) if ch in ACCENT]


def gear_data():
    """Lo que necesita GearSprites.gd: formas, colores y píxeles de acento, rampas de calidad y destello."""
    return {
        "shapes": {k: [list(c) for c in v] for k, v in SHAPES.items()},
        "accent": [PALETTE[ch].lstrip("#") for ch in ACCENT],
        "accent_px": {k: accent_pixels(draw()) for k, draw in PIECES.items()},
        "quality_ramps": {tier: [c.lstrip("#") for c in r] for tier, r in QUALITY_RAMPS.items()},
        "shine": SHINE,
    }


def _review_sheet(scale=4, pad=6):
    """Todo lo exportado en una tira, con el acento en la rampa legendaria."""
    legendary = {hex_to_rgba(PALETTE[ch])[:3]: hex_to_rgba(c)[:3] for ch, c in zip(ACCENT, QUALITY_RAMPS["legendary"])}
    ims = []
    for draw in list(PIECES.values()) + list(ARISTAS.values()) + list(POTIONS.values()) + list(ZONES.values()) + list(UI.values()):
        im = draw().image()
        px = im.load()
        for y in range(im.height):
            for x in range(im.width):
                r, g, b, a = px[x, y]
                if a and (r, g, b) in legendary:
                    px[x, y] = legendary[(r, g, b)] + (a,)
        ims.append(im)
    w = sum(i.width for i in ims) + pad * (len(ims) + 1)
    h = max(i.height for i in ims) + pad * 2
    sheet = Image.new("RGBA", (w, h), (52, 38, 44, 255))
    x = pad
    for im in ims:
        sheet.alpha_composite(im, (x, pad))
        x += im.width + pad
    REVIEW.parent.mkdir(parents=True, exist_ok=True)
    sheet.resize((w * scale, h * scale), Image.NEAREST).save(REVIEW)


def export_gear():
    """Escribe los PNG del inventario, gear.json y la hoja de revisión. Devuelve la carpeta de salida."""
    OUT.mkdir(parents=True, exist_ok=True)
    for name, draw in {**PIECES, **ARISTAS, **POTIONS, **ZONES, **UI}.items():
        draw().save(OUT / f"{name}.png")
    (OUT / "gear.json").write_text(json.dumps(gear_data(), indent=1, sort_keys=True), encoding="utf-8")
    _review_sheet()
    return OUT
```

- [ ] **Step 3: `export.py`**

Añade `import gear` junto a los demás imports y, al final, después de `fonts.export_fonts()`:

```python
gear.export_gear()
print("piezas del inventario en", gear.OUT)
```

- [ ] **Step 4: Ejecutar, exportar y revisar**

Run: `python -m unittest discover tools/pixel_art/tests` y después `python tools/pixel_art/export.py`
Expected: pruebas en verde. En `art/sprites/pixel/gear/` hay 12 piezas, 6 aristas, 3 pociones, 4 iconos de zona, 3 piezas de interfaz y `gear.json`.

Si la fase 2 está integrada, sus pruebas de colores reservados también pasan. Ninguna letra nueva entra en la paleta: las piezas solo usan las suyas.

Abre con Read `tools/pixel_art/out/gear_review.png` y comprueba:
- que cada pieza se reconoce: espada, escudo, casco y botas en sus tres niveles;
- que el acento (naranja en la hoja) queda en el acanalado, la banda, el emblema y el penacho;
- que las botas en L apoyan el pie en su casilla de abajo a la derecha;
- que los iconos de zona se leen a ese tamaño.

Si algo se ve mal, retoca su función (no las pruebas) y vuelve a exportar.

Run: `D:/Software/Godot/godot_ver4.5.exe --headless --path . --import` para importar los PNG y el JSON.

- [ ] **Step 5: Commit**

```bash
git add tools/pixel_art/gear.py tools/pixel_art/tests/test_gear.py tools/pixel_art/export.py art/sprites/pixel/gear
git commit -m "feat: pixel art del inventario: piezas, rebabas, pociones, zonas y casillas (tools/pixel_art/gear.py)"
```

(`art/sprites/pixel/gear` incluye los `.import` que genera Godot, como el resto de `art/sprites/pixel`.)

---

### Task 15: El pixel art dentro del juego (`GearSprites`)

**Files:**
- Create: `scripts/core/GearSprites.gd`
- Modify: `scripts/ui/GearGridView.gd`, `scripts/ui/LootStripView.gd` (casillas, zonas y destello), `scripts/ui/EquipmentPanel.gd` (arte, pociones y marcos), `scripts/ui/HeroViewOverlay.gd` (iconos de pociones en la franja) y `scripts/ui/CraftResultScreen.gd` (pieza en el medallón)
- Test: `scripts/tests/InventoryGridTests.gd`

**Interfaces:**
- Consumes: `PieceShape.of_item`, `CraftedItem.get_quality_tier()`, `GearAuras.ZONES` y lo que exporta la tarea 14 (`art/sprites/pixel/gear/`)
- Produces (`class_name GearSprites`, estática):
  - constantes `ART_CELL` (22), `SCALE` (5), `SHINE_FRAMES`, `SHINE_SWEEP` y `SHINE_PERIOD`;
  - `data() -> Dictionary`, con `accent` (3 `Color`), `accent_px` (pieza → `[x, y, tono]`), `quality_ramps` (calidad → 3 `Color`) y `shine` (calidad → fuerza);
  - `compose(item: CraftedItem, rot: int, shine_frame: int = -1) -> Image`, sin caché;
  - `texture(item: CraftedItem, rot: int, shine_frame: int = -1) -> Texture2D`, con caché;
  - `shine_frame(item: CraftedItem) -> int`: el fotograma del destello ahora, o -1;
  - `is_shiny(item: CraftedItem) -> bool`;
  - `potion_icon(id: StringName) -> Texture2D` y `zone_icon(slot: String) -> Texture2D`;
  - `ui_texture(name: String) -> Texture2D` (`ui_cell` y `ui_cell_locked`) y `frame_style() -> StyleBoxTexture` (el marco a ×5, para huecos y zona de venta).
- En `GearGridView` y `LootStripView`: `sprite_for` pasa a llamarse con el destello del momento, y el dibujo se repite mientras haya una pieza que brilla. `GearGridView` gana `cell_texture`, `locked_texture` y `zone_icon_for` (tarea 8: `show_zones`).

- [ ] **Step 1: Pruebas que fallan**

```gdscript
# ─── Tarea 15: el pixel art en el juego ────────────────────────────────

func _has_color(img: Image, c: Color) -> bool:
	var want := Color(c.r, c.g, c.b).to_rgba32()
	for y in img.get_height():
		for x in img.get_width():
			var p := img.get_pixel(x, y)
			if p.a > 0.0 and Color(p.r, p.g, p.b).to_rgba32() == want:
				return true
	return false


func _count_color(img: Image, c: Color) -> int:
	var want := Color(c.r, c.g, c.b).to_rgba32()
	var n := 0
	for y in img.get_height():
		for x in img.get_width():
			var p := img.get_pixel(x, y)
			if p.a > 0.0 and Color(p.r, p.g, p.b).to_rgba32() == want:
				n += 1
	return n


func test_every_piece_has_its_sprite() -> void:
	for id in ITEM_IDS:
		var item := _piece(id, 0.95)
		var img := GearSprites.compose(item, 0)
		var fp := PieceShape.of_item(item, 0)
		check(img != null and img.get_size() == fp.size * GearSprites.ART_CELL, "%s: sprite del tamaño de su caja (%s)" % [id, img.get_size() if img else "nada"])


func test_quality_recolors_the_accent() -> void:
	var d := GearSprites.data()
	var legend := GearSprites.compose(_piece(&"sword_basic", 1.0), 0)
	var common := GearSprites.compose(_piece(&"sword_basic", 0.2), 0)
	check(_has_color(legend, d.quality_ramps["legendary"][1]) and not _has_color(legend, d.accent[1]), "la legendaria lleva el naranja de su calidad y nada de la rampa reservada")
	check(_has_color(common, d.quality_ramps["common"][1]), "la básica lleva el acero de la suya")
	check(d.quality_ramps["legendary"][1].to_html(false) == "ffa629", "la rampa sale de gear.json (%s)" % d.quality_ramps["legendary"][1].to_html(false))


func test_rotation_and_aristas_shape_the_texture() -> void:
	var rough: Array[Vector2i] = [Vector2i(1, 1)]
	var item := _piece(&"sword_masterwork", 0.8, rough)
	var img := GearSprites.compose(item, 1)
	check(img.get_size() == Vector2i(4, 2) * GearSprites.ART_CELL, "tumbada y con su arista: 4×2 casillas (%s)" % img.get_size())
	check(img.get_pixel(2 * GearSprites.ART_CELL + 11, GearSprites.ART_CELL + 1).a > 0.0, "la casilla de la arista lleva su rebaba pegada a la hoja")
	check(GearSprites.texture(item, 1) == GearSprites.texture(item, 1), "la misma pieza y giro salen de la caché")


func test_shine_lights_only_epic_and_legendary() -> void:
	var d := GearSprites.data()
	var legend := _piece(&"sword_basic", 1.0)
	var rare := _piece(&"sword_basic", 0.8)
	check(GearSprites.is_shiny(legend) and not GearSprites.is_shiny(rare), "brillan las Épicas y las Legendarias")
	var base_px := _count_color(GearSprites.compose(legend, 0), d.quality_ramps["legendary"][1])
	var lit := 0
	for f in GearSprites.SHINE_FRAMES:
		var img := GearSprites.compose(legend, 0, f)
		lit = maxi(lit, base_px - _count_color(img, d.quality_ramps["legendary"][1]))
	check(lit > 0, "el barrido aclara parte del acento en algún fotograma (%d píxeles)" % lit)
	check(GearSprites.compose(rare, 0, 3).get_data() == GearSprites.compose(rare, 0).get_data(), "una Rara no brilla aunque se le pida")
```

(En `test_rotation_and_aristas_shape_the_texture`, la arista queda en la casilla (2,1), debajo de la hoja tumbada. La rebaba gira un cuarto de vuelta para pegarse por arriba, hacia la hoja: la prueba mira el píxel del centro de la fila de arriba de esa casilla.)

Run InventoryGridTests. Expected: error de análisis (`GearSprites` no existe).

- [ ] **Step 2: `scripts/core/GearSprites.gd`**

```gdscript
class_name GearSprites
extends RefCounted

## Dibujo del inventario en rejilla (spec doc/specs/2026-09-27-inventario-en-rejilla.md, apartado 9.5).
## Parte del pixel art de tools/pixel_art/gear.py (art/sprites/pixel/gear/, 22 px por casilla):
##  - cambia la rampa de acento por la de la calidad de la pieza (gear.json, las rampas de la fase 2);
##  - gira la pieza y le pega sus aristas, giradas hacia ella;
##  - en Épicas y Legendarias, un destello recorre el acento: SHINE_FRAMES fotogramas en SHINE_SWEEP
##    segundos, cada SHINE_PERIOD segundos.
## Cada combinación se compone una vez y se guarda en caché. Las vistas la pintan a ×SCALE con Nearest.

const ART_CELL := 22
const SCALE := 5
const DIR := "res://art/sprites/pixel/gear/"
const ARISTA_VARIANTS := 3
const SHINE_FRAMES := 8
const SHINE_SWEEP := 0.6
const SHINE_PERIOD := 3.0
const SHINE_HALF_WIDTH := 1.5  ## medio ancho de la franja de luz, en píxeles de arte
const CACHE_LIMIT := 512

static var _cache: Dictionary = {}
static var _images: Dictionary = {}
static var _data: Dictionary = {}
static var _frame_style: StyleBoxTexture = null


## gear.json con los colores como Color: {"accent": [claro, base, oscuro], "accent_px": {pieza: [[x, y,
## tono], …]}, "quality_ramps": {calidad: [claro, base, oscuro]}, "shine": {calidad: fuerza}}. Vacío si
## falta (ejecuta tools/pixel_art/export.py).
static func data() -> Dictionary:
	if _data.is_empty():
		var res := load(DIR + "gear.json") as JSON
		if res == null:
			push_error("GearSprites: falta %sgear.json (ejecuta python tools/pixel_art/export.py)" % DIR)
			return {}
		var raw: Dictionary = res.data
		var ramps := {}
		for tier in raw.quality_ramps:
			ramps[tier] = raw.quality_ramps[tier].map(func(h): return Color(h))
		_data = {"accent": raw.accent.map(func(h): return Color(h)), "accent_px": raw.accent_px, "quality_ramps": ramps, "shine": raw.shine}
	return _data


static func is_shiny(item: CraftedItem) -> bool:
	return float(data().get("shine", {}).get(item.get_quality_tier(), 0.0)) > 0.0


## Fotograma del destello de una pieza ahora mismo, o -1 entre barridos (y en las que no brillan). Cada
## pieza empieza su ciclo en un momento distinto.
static func shine_frame(item: CraftedItem) -> int:
	if not is_shiny(item):
		return -1
	var t := fmod(Time.get_ticks_msec() / 1000.0 + float(item.crafted_timestamp % 997) / 997.0 * SHINE_PERIOD, SHINE_PERIOD)
	return int(t / SHINE_SWEEP * SHINE_FRAMES) if t < SHINE_SWEEP else -1


static func texture(item: CraftedItem, rot: int, shine: int = -1) -> Texture2D:
	var key := "%s|%s|%s|%d|%d" % [item.item_resource.item_id, item.get_quality_tier(), str(item.aristas), posmod(rot, 4), shine]
	if not _cache.has(key):
		if _cache.size() >= CACHE_LIMIT:
			_cache.clear()
		var img := compose(item, rot, shine)
		_cache[key] = ImageTexture.create_from_image(img) if img else null
	return _cache[key]


static func potion_icon(id: StringName) -> Texture2D:
	return _texture(String(id))


static func zone_icon(slot: String) -> Texture2D:
	return _texture("zone_" + slot)


static func ui_texture(file_name: String) -> Texture2D:
	return _texture(file_name)


## Marco de madera (ui_frame.png, 12×12 con bordes de 4 px) ampliado a ×SCALE para 9 partes: huecos de
## consumible y zona de venta.
static func frame_style() -> StyleBoxTexture:
	if _frame_style == null:
		var img := _image("ui_frame")
		if img == null:
			return null
		var big: Image = img.duplicate()
		big.resize(img.get_width() * SCALE, img.get_height() * SCALE, Image.INTERPOLATE_NEAREST)
		_frame_style = StyleBoxTexture.new()
		_frame_style.texture = ImageTexture.create_from_image(big)
		_frame_style.set_texture_margin_all(4 * SCALE)
		_frame_style.set_content_margin_all(4 * SCALE)
	return _frame_style


static func compose(item: CraftedItem, rot: int, shine: int = -1) -> Image:
	var base := _image(String(item.item_resource.item_id))
	if base == null or data().is_empty():
		return null
	var fp := PieceShape.of_item(item, rot)
	var piece: Image = base.duplicate()
	_recolor(piece, String(item.item_resource.item_id), item.get_quality_tier(), shine)
	for i in posmod(rot, 4):
		piece.rotate_90(CLOCKWISE)
	var out := Image.create_empty(fp.size.x * ART_CELL, fp.size.y * ART_CELL, false, Image.FORMAT_RGBA8)
	out.blend_rect(piece, Rect2i(Vector2i.ZERO, piece.get_size()), _min_cell(fp.clean) * ART_CELL)
	var leather: bool = GearAuras.ZONES.get(item.get_equipment_slot(), &"") == &"bottom"  # botas: rebaba de cuero
	for i in fp.aristas.size():
		var a: Vector2i = fp.aristas[i]
		var tile := _image("arista_%s_%d" % ["leather" if leather else "metal", posmod(i + hash(item.item_resource.item_id), ARISTA_VARIANTS)])
		if tile == null:
			continue
		var t: Image = tile.duplicate()
		for r in _turns_toward_piece(a, fp.clean):
			t.rotate_90(CLOCKWISE)
		out.blend_rect(t, Rect2i(0, 0, ART_CELL, ART_CELL), a * ART_CELL)
	return out


static func _texture(file_name: String) -> Texture2D:
	var path := DIR + file_name + ".png"
	return load(path) if ResourceLoader.exists(path) else null


## PNG de la carpeta como Image RGBA8 (en caché); null si no existe.
static func _image(file_name: String) -> Image:
	if not _images.has(file_name):
		var tex := _texture(file_name)
		var img: Image = null
		if tex:
			img = tex.get_image()
			if img.is_compressed():
				img.decompress()
			img.convert(Image.FORMAT_RGBA8)
		_images[file_name] = img
	return _images[file_name]


## Cambia la rampa de acento por la de la calidad, solo en los píxeles de acento de la pieza (accent_px de
## gear.json: no recorre la imagen entera). Con `shine` (0..SHINE_FRAMES−1) y una calidad que brilla, la
## franja de luz de ese fotograma aclara el acento que pisa: recorre la pieza en diagonal.
static func _recolor(img: Image, item_id: String, tier: String, shine: int) -> void:
	var d := data()
	var ramp: Array = d.quality_ramps.get(tier, d.quality_ramps["common"])
	var strength := float(d.shine.get(tier, 0.0)) if shine >= 0 else 0.0
	var band := (float(shine) + 0.5) / SHINE_FRAMES * float(img.get_width() + img.get_height())
	for px in d.accent_px.get(item_id, []):
		var x := int(px[0])
		var y := int(px[1])
		var c: Color = ramp[int(px[2])]
		if strength > 0.0 and absf(float(x + y) - band) <= SHINE_HALF_WIDTH:
			c = c.lerp(Color.WHITE, 0.7 * strength)
		img.set_pixel(x, y, c)


static func _min_cell(cells: Array) -> Vector2i:
	var m := Vector2i(999, 999)
	for c in cells:
		m = Vector2i(mini(m.x, c.x), mini(m.y, c.y))
	return m


## Cuartos de vuelta para que el borde izquierdo de la rebaba mire a una casilla limpia vecina: la de la
## izquierda, 0; la de arriba, 1; la de la derecha, 2; la de abajo, 3.
static func _turns_toward_piece(a: Vector2i, clean: Array) -> int:
	var sides := [Vector2i.LEFT, Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN]
	for i in sides.size():
		if (a + sides[i]) in clean:
			return i
	return 0
```

- [ ] **Step 3: Las vistas: casillas, zonas y destello**

En `GearGridView.gd`, variables nuevas (junto a `sprite_for`):

```gdscript
var cell_texture: Texture2D = null  ## casilla en pixel art (GearSprites); sin ella, rectángulos de color
var locked_texture: Texture2D = null  ## casilla por abrir en pixel art
var zone_icon_for: Callable = Callable()  ## tipo de pieza → icono de su zona (GearSprites.zone_icon)
```

En `_draw()`, sustituye el bucle de casillas por:

```gdscript
	for y in max_size.y:
		for x in max_size.x:
			var c := Vector2i(x, y)
			if grid.in_bounds(c):
				if cell_texture:
					draw_texture_rect(cell_texture, cell_rect(c), false)
				else:
					var r := cell_rect(c).grow(-1.0)
					draw_rect(r, COLOR_CELL)
					draw_rect(r, COLOR_LINE, false, 2.0)
			elif locked_texture:
				draw_texture_rect(locked_texture, cell_rect(c), false)
			else:
				_draw_dashed(cell_rect(c).grow(-7.0), COLOR_LOCKED)
```

En `_draw_zone` (tarea 8), renombra el parámetro `_slot` a `slot` y añade, después de la franja:

```gdscript
	var icon: Texture2D = zone_icon_for.call(slot) if zone_icon_for.is_valid() else null
	if icon:
		var icon_size := Vector2(icon.get_size()) * GearSprites.SCALE
		draw_texture_rect(icon, Rect2(r.get_center() - icon_size * 0.5, icon_size), false, Color(1, 1, 1, 0.8))
```

`sprite_for` se llama con el destello del momento: su comentario pasa a «(pieza, giro, destello) → Texture2D». En `draw_piece_at`, sustituye `var tex: Texture2D = sprite_fn.call(item, rot)` por:

```gdscript
		var tex: Texture2D = sprite_fn.call(item, rot, GearSprites.shine_frame(item))
```

Y en `_process` de `GearGridView`, para que el destello se mueva, al final:

```gdscript
	if sprite_for.is_valid() and is_visible_in_tree() and grid and grid.items.any(func(it): return GearSprites.is_shiny(it)):
		queue_redraw()
```

En `LootStripView.gd`, lo mismo con sus piezas:

```gdscript
func _process(_delta: float) -> void:
	if sprite_for.is_valid() and is_visible_in_tree() and items.any(func(it): return GearSprites.is_shiny(it)):
		queue_redraw()
```

- [ ] **Step 4: El panel y el resultado de la forja**

En `EquipmentPanel._build()`, después de crear las vistas:

```gdscript
	var art := func(item: CraftedItem, rot: int, shine: int) -> Texture2D: return GearSprites.texture(item, rot, shine)
	for view in [_hero_view, _bag_view]:
		view.sprite_for = art
		view.cell_texture = GearSprites.ui_texture("ui_cell")
		view.locked_texture = GearSprites.ui_texture("ui_cell_locked")
	_hero_view.zone_icon_for = func(slot: String) -> Texture2D: return GearSprites.zone_icon(slot)
	_loot_view.sprite_for = art
```

(La pieza que se arrastra ya usa `_hero_view.sprite_for` en `_draw_ghost`.)

Marcos de madera en los huecos de pociones y en la zona de venta. En el bucle de `_build()` que crea los huecos (tarea 13), sustituye `slot.add_theme_stylebox_override("normal", style)` por:

```gdscript
		var frame := GearSprites.frame_style()
		slot.add_theme_stylebox_override("normal", frame.duplicate() if frame else style)
```

Después de `add_child(slot)`, el icono:

```gdscript
		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.position = Vector2(5, 5)
		icon.size = Vector2(110, 110)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(icon)
```

Sustituye `_refresh_potions()`: el pixel art de la poción a la izquierda y cuántas quedan a la derecha.

```gdscript
func _refresh_potions() -> void:
	for i in _potion_slots.size():
		var s: Dictionary = _im.consumables[i]
		var full := int(s.count) > 0
		var icon: TextureRect = _potion_slots[i].get_node("Icon")
		icon.texture = GearSprites.potion_icon(s.id) if full else null
		_potion_slots[i].text = ("×%d" % int(s.count)) if full else tr("Hueco libre")
		# Con poción, el número va a la derecha del icono; libre, el texto va centrado en todo el hueco
		var style: StyleBox = _potion_slots[i].get_theme_stylebox("normal")
		style.content_margin_left = 116.0 if full else float(GearSprites.SCALE * 4)
```

El nombre de la poción sigue en la ficha al tocar el hueco (tarea 13).

La zona de venta (`SellZone`, tarea 10): en `_build()`, si `GearSprites.frame_style()` no es nulo, `sell_zone.add_theme_stylebox_override("panel", GearSprites.frame_style())`.

En la franja (`HeroViewOverlay`, tarea 13), cada hueco con pociones enseña su icono y su número, como pide el spec (apartado 8). `_potion_label` se sustituye por un icono y un número por hueco, creados una vez:

```gdscript
var _potion_icons: Array[TextureRect] = []
var _potion_counts: Array[Label] = []
```

En `_build()`, donde se creaba `_potion_label`:

```gdscript
	for i in Potions.SLOTS:
		var icon := TextureRect.new()
		icon.size = Vector2(44, 44)  # 22 px de arte a ×2
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(icon)
		_potion_icons.append(icon)
		_potion_counts.append(_make_label(22, Color("ffe7b0"), HORIZONTAL_ALIGNMENT_LEFT))
```

En `_refresh_buffs()`, el bloque de pociones de la tarea 13 pasa a:

```gdscript
	# Pociones que quedan en los huecos (spec del inventario, apartado 8): icono y número, en una fila
	var x := 0.0
	for i in _potion_icons.size():
		var s: Dictionary = _inventory.consumables[i] if _inventory and "consumables" in _inventory else {}
		var full := int(s.get("count", 0)) > 0
		_potion_icons[i].visible = full
		_potion_counts[i].visible = full
		if not full:
			continue
		var at := BUFF_POS + Vector2(x, BUFF_ROW * row)
		_potion_icons[i].texture = GearSprites.potion_icon(s.id)
		_potion_icons[i].position = at
		_potion_counts[i].text = "×%d" % int(s.count)
		_potion_counts[i].position = at + Vector2(48, 0)
		_potion_counts[i].size = Vector2(60, 44)
		x += 116.0
```

En `CraftResultScreen.show_result`, sustituye la elección del icono (`if crafted_item is CraftedItem: icon = crafted_item.get_icon()`) por:

```gdscript
	var pixel := false
	if crafted_item is CraftedItem:
		icon = GearSprites.texture(crafted_item, 0)
		pixel = icon != null
		if icon == null:
			icon = crafted_item.get_icon()
```

Y, junto a `_item_icon.texture = icon`:

```gdscript
	_item_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if pixel else CanvasItem.TEXTURE_FILTER_PARENT_NODE
```

- [ ] **Step 5: Ejecutar y capturar**

Run: la batería. Expected: 0 fallos.

Captura los planes `panels`, `result` (con `--quality=1.0`, legendaria) y `potions`, copiando y restaurando `save.json`, y ábrelos con Read. Comprueba:
- las piezas en pixel art en la rejilla, el botín y la mochila, sobre casillas de pixel art;
- las aristas pegadas a su pieza;
- el color de calidad en el acento, y el destello en la legendaria (en varios fotogramas seguidos);
- los iconos de las 4 zonas en los bordes de la rejilla de Tico;
- los marcos de madera de los huecos y de la zona de venta;
- en la franja (plan `potions` de la tarea 13), el icono de cada poción con su número;
- la espada en el medallón del resultado con "Sin aristas" y su habilidad.

- [ ] **Step 6: Commit**

```bash
git add scripts/core/GearSprites.gd scripts/core/GearSprites.gd.uid scripts/ui/GearGridView.gd scripts/ui/LootStripView.gd scripts/ui/EquipmentPanel.gd scripts/ui/HeroViewOverlay.gd scripts/ui/CraftResultScreen.gd scripts/tests/InventoryGridTests.gd
git commit -m "feat: el inventario en pixel art: piezas, destello, casillas, zonas y marcos (GearSprites)"
```

---

### Task 16: Balance con rejillas llenas

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
- la rejilla de 6×6 delante de Tico, con piezas en pixel art y la legendaria con su color;
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
	panel.open()  # en frío: compone las texturas de todas las piezas
	var cold := (Time.get_ticks_usec() - t0) / 1000.0
	panel.close()
	t0 = Time.get_ticks_usec()
	panel.open()  # con las texturas en caché
	var warm := (Time.get_ticks_usec() - t0) / 1000.0
	print("panel de Equipo: %.1f ms en frío, %.1f ms con caché (%d piezas en Tico, %d en el botín)" % [cold, warm, im.get_hero_items().size(), im.get_loot_count()])
	check(warm < 50.0, "con caché se abre en menos de 50 ms (%.1f)" % warm)
	check(cold < 150.0, "en frío, en menos de 150 ms (%.1f)" % cold)
	panel.queue_free()
	await _restore_inventory(saved)
```

Run InventoryGridTests. Expected: 0 fallos. Si no llega, mira qué pesa con el perfilador de Godot antes de tocar nada. Lo más probable es el recoloreado (debe recorrer solo `accent_px`) o recalcular auras en cada pieza.

- [ ] **Step 3: Batería completa y arranque real**

Run: la batería. Expected: 0 fallos en las siete líneas.

Run (copia antes `save.json` y restáuralo después):

```bash
timeout 120 D:/Software/Godot/godot_ver4.5.exe --headless --path . --quit-after 900 res://scenes/Main.tscn 2>&1 | grep -iE "SCRIPT ERROR|Parse Error|InventoryManager:"
```

Expected: sin errores. La partida del usuario carga con todas sus piezas.

- [ ] **Step 4: Documentación**

- `doc/ARCHITECTURE.md`: una sección "Inventario en rejilla" con las clases nuevas (`PieceShape`, `GearGrid`, `GearAuras`, `LegendaryPowers`, `GearPacker`, `GridExpansions`, `Potions`, `GearSprites`, `GearGridView` y `LootStripView`), qué hace cada una y quién la usa. Añade también los tres sitios de `InventoryManager` y el guardado versión 3.
- `doc/ROADMAP.md`: el inventario en rejilla, hecho, con enlace al spec.
- Spec: el estado pasa a "implementado (<fecha>)".

- [ ] **Step 5: Commit**

```bash
git add scripts/tests/VisualCapture.gd scripts/tests/InventoryGridTests.gd doc/ARCHITECTURE.md doc/ROADMAP.md doc/specs/2026-09-27-inventario-en-rejilla.md
git commit -m "docs: inventario en rejilla: arquitectura, roadmap, captura, rendimiento y estado del spec"
```

- [ ] **Step 6: Tablero**

En `D:/Proyectos/CONTROL/Tableros/Futuro/PetJam.md`, edítalo a mano (el CLI no encuentra PetJam). Nunca escribas "^" dentro de una tarjeta.
- Tarjeta "Inventario en rejilla estilo Lootbound": marca "Implementado después de los rangos", añade en Notas los commits de la implementación y los valores calibrados, y muévela a "🔄 Completada - Pendiente Revisión".
- Tarjeta "Hueco "Pecho" sin objetos en el panel de Equipo": marca sus dos criterios, anota "Resuelta por el inventario en rejilla: sin huecos fijos no hay pecho" y muévela también a "🔄 Completada - Pendiente Revisión".
- Tarjeta "Tutorial de primeros pasos": añade en Notas que con la rejilla "equipar" es arrastrar la primera pieza del botín a la rejilla de Tico, porque nada se coloca solo (spec del inventario, apartado 9.3).
- Tarjeta "Testing y export Android real device": añade en Notas qué hay que mirar del inventario en el móvil (spec del inventario, apartados 11 y 16):
  - que el panel se abre en menos de 50 ms;
  - que el arrastre va a 60 FPS;
  - que las casillas de 110 px se aciertan con el dedo. Si no, la mochila baja a 6×3 y las casillas crecen.

Después ejecuta `node scripts/kanban.js lint` desde `D:/Proyectos/CONTROL`. Nunca muevas nada a Done.
