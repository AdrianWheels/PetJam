# Botín con física — Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** que el botín del panel de Equipo sea una caja física con las piezas a media escala (55 px por casilla): las piezas caen, chocan con su forma real, se quedan donde caen (también al cerrar y reabrir, o al reiniciar), se cogen, se mueven y se lanzan, y la pila nunca pasa de un techo invisible gracias al modo fantasma.

**Architecture:** la física 2D de Godot, sin autoloads nuevos.
- `PieceShape` da, sin nodos, los rectángulos de colisión de una pieza (uno por casilla, aristas incluidas) centrados en su centro de masa.
- `LootPiece` (un `RigidBody2D`) es una pieza: sus formas, su dibujo de siempre (`GearGridView.draw_piece_at`) y el modo fantasma. En la caja todo va a media escala: `LootPiece.BOX_CELL` (55 px por casilla) es la única constante de escala del botín. Al coger una pieza el panel la arrastra a tamaño completo (110 px) y al soltarla en la caja vuelve a 55, alrededor de su centro de masa.
- `LootBoxView` (un `Node2D` dentro del panel) es la caja: suelo, paredes y techo; sigue a `InventoryManager.loot`, que sigue siendo la fuente de verdad; decide quién cae, desde dónde y quién no cabe; se congela con el panel cerrado y recoge las poses.
- `CraftedItem.loot_pose` guarda la pose (posición en la caja y ángulo) y viaja en el guardado como `lx`, `ly` y `ang`, opcionales, sin versión nueva.
- `EquipmentPanel` cambia de sitio la mochila y la zona de venta, quita el desplazamiento de la tira y arrastra y suelta con la caja.

**Tech Stack:** Godot 4.5.1 (GDScript con tabuladores), física 2D de Godot (GodotPhysics2D), escenas de pruebas sin ventana sobre `scripts/tests/TestSuite.gd`.

**Spec:** `doc/specs/2026-10-02-botin-con-fisica.md`

## Orden de ejecución

- Las tareas van en orden: 1, 2, 3, 4, 5 y 6. Cada una usa lo que dejó la anterior.
- Dónde: en el worktree `D:/Proyectos/PetJam-botin`, rama `botin-fisico`. Todos los comandos, desde la raíz del worktree.
- El worktree no tiene carpeta `.godot`: antes de la primera ejecución, `--import` (ver Global Constraints).
- El código de este plan se ha probado en una copia del worktree fuera del repo (con la partida copiada): con las seis tareas aplicadas tal cual, `LootBoxTests` pasa entera (280 comprobaciones, 0 fallos, unos 4 s con `--fixed-fps 60`) e `InventoryGridTests` solo falla en `test_older_save_migrates_without_a_warning`, por los avisos de UID de una copia de `art/assets` sin sus `.import` (en el worktree con la junction no pasa).

## Decisiones que el spec deja abiertas

- **«No cabe» (spec, apartado 5), de forma comprobable.** Una pieza no cabe si:
  - ya quieta (dormida, o 3 s después de entrar), alguna de sus casillas, encogida un 8 % de `BOX_CELL` por lado (4,4 px), pisa una pieza que choca, o su punto más alto está a 3 px o menos del techo (está apretada contra él);
  - o, al caer desde arriba, no encuentra sitio libre bajo el techo en 2 s (8 x al azar en cada intento). A partir de ahí, lo que llega prueba una vez y, si no hay sitio, entra como fantasma sin esperar, hasta que se libere sitio.
  - El solape se mira con `PhysicsDirectSpaceState2D.intersect_shape` sobre la capa de las piezas que chocan. Probado: un cuerpo añadido en el mismo fotograma ya sale en la consulta, y uno liberado con `free()` ya no.
- **Salida del modo fantasma.** Cada segundo, un fantasma que ya no solapa ni toca el techo donde está vuelve a chocar ahí. Y cada vez que se libera sitio (se vende o se saca una pieza de la caja), los fantasmas vuelven a la cola: cuando les toca, prueban donde están y, si no, caen otra vez desde arriba como piezas normales. Si arriba no hay sitio en 2 s, siguen de fantasma hasta la siguiente vez que se libere sitio. Así no hay bucles.
- **Poses guardadas.** Se restauran despiertas, no dormidas: una pose recogida en el aire (cerrar el panel con una pieza cayendo) cae al abrir en vez de flotar. Probado: una pila quieta restaurada despierta se mueve menos de 0,1 px. Una pose que solapa a otra pieza ya restaurada entra como fantasma: nada sale despedido.
- **Fuera de la caja se olvida la pose.** `InventoryManager._take_out` vacía `loot_pose`: una pieza que sale del botín y vuelve (un intercambio, «Al botín») cae desde arriba.
- **Guardado de la pose.** `InventoryManager` gana la señal `loot_poses_changed` y la función `note_loot_poses()`. `GameManager` la conecta a su guardado diferido de siempre (`_on_trigger_save`). Es el único cambio en los autoloads.
- **Escala (decisión del usuario, 2026-10-02):** en la caja las piezas se dibujan y chocan a 55 px por casilla (`LootPiece.BOX_CELL = GearGridView.CELL * 0.5`); la caja, el techo y las poses siguen en píxeles de la caja. Al cogerla, la pieza crece a 110 (`EquipmentPanel.DRAG_CELL`) alrededor de su centro de masa, para que la vista previa de la rejilla y de la mochila cuadre; al soltarla en la caja encoge a 55 alrededor del mismo punto.
- **Dónde entra lo que se suelta en la caja:** donde se ve la pieza arrastrada (una casilla de la rejilla por encima del dedo), con su centro de masa ahí. Si solapa, sube a pasos de un cuarto de casilla de la caja (13,75 px) hasta no solapar; si llega al techo y sigue solapando, entra como fantasma donde se soltó. Una pieza de la caja soltada fuera de todo vuelve al punto de la caja más cercano al dedo, sin velocidad.
- **Velocidad del gesto:** lo que se ha movido el dedo en los últimos 0,1 s. Con menos de 0,01 s de muestras, sin velocidad. Tope de 1400 px/s.
- **Pulsar donde la pila tapa la rejilla de Tico:** manda la pieza de la caja (se dibuja encima); un fantasma de la caja pierde frente a una pieza de la rejilla.
- **Orden de `InventoryManager.loot`:** no cambia (lo nuevo entra delante). Ya no se enseña: es solo el de llegada.
- **Capas de colisión:** el juego usa la 1 (Tico, enemigos y salas, y el Tico del panel). La caja usa la 9 (paredes), la 10 (piezas que chocan) y la 11 (fantasmas).
- **Reposo:** `LootBoxView._ready` pone en el espacio del mundo 2D el umbral de reposo (8 px/s y 0,21 rad/s) y el tiempo hasta dormir (0,4 s). El juego no tiene más cuerpos rígidos.
- **Cómo cae desde arriba:** tumbada (el cuarto de vuelta que la deja más baja, como en la tira), con un giro de ±0,3 rad, en una x al azar con la pieza entera entre las paredes y su punto más alto 1 px bajo el techo. Medido a media escala: con 60 piezas variadas (con aristas) chocan 25 y entran 35 como fantasmas; con 40 escudos maestros también hay fantasmas, y al vender los que chocan los fantasmas vuelven a chocar. (A escala completa solo cabían 6 o 7: por eso la media escala.)
- **Valores de física** (probados en un experimento sin ventana con 12, 20, 30 y 60 piezas; quietas a los 630 pasos con 12): fricción 0,8, rebote 0,05, amortiguado lineal 0,5 y angular 2, gravedad ×2, masa 1 por casilla, giro inicial al caer de ±0,3 rad y giro de ±1,5 rad/s.
- **Cómo avanzan las pruebas la física:** esperan pasos de física (`await get_tree().physics_frame`) con un tope de pasos. `LootBoxTests` se lanza con `--fixed-fps 60`: cada paso es 1/60 s de juego y no se espera tiempo real (3000 pasos tardan menos de un segundo).

## Global Constraints

- Godot: usar siempre `D:/Software/Godot/godot_ver4.5.exe` (4.5.1). Nunca `godot.exe` (4.7).
- Todas las ejecuciones de Godot van con `timeout 300`: si un script no se analiza, `_ready` no corre y Godot no sale.
- Tras crear scripts con `class_name` o escenas nuevas: `D:/Software/Godot/godot_ver4.5.exe --headless --path . --import`. También antes de la primera ejecución en el worktree. La primera importación de un proyecto sin `.godot` puede cerrarse con un fallo de segmento (código 139) a medias: repítela hasta que salga con 0.
- **Godot nunca toca la partida real.** La partida es una sola (`%APPDATA%/Godot/app_userdata/PetJam/save.json`) y la comparten todos los worktrees y el usuario. Toda ejecución de Godot (pruebas, `--import`, `--check-only`, capturas) va con `APPDATA` apuntando a una carpeta temporal que tiene una copia de esa partida. En Git Bash:

  ```bash
  mkdir -p <scratchpad>/appdata/Godot/app_userdata/PetJam
  cp "$(cygpath -u "$APPDATA")/Godot/app_userdata/PetJam/save.json" <scratchpad>/appdata/Godot/app_userdata/PetJam/save.json
  APPDATA="$(cygpath -w <scratchpad>/appdata)" timeout 300 D:/Software/Godot/godot_ver4.5.exe --headless --fixed-fps 60 --path . res://scenes/tests/LootBoxTests.tscn
  ```

  - `<scratchpad>` es tu carpeta temporal de la sesión, fuera del repo. El `cp` solo lee la partida real; repítelo antes de cada batería.
  - En los comandos de este plan, `<appdata>` es `"$(cygpath -w <scratchpad>/appdata)"`, y cada orden de Godot va precedida de `APPDATA=<appdata>`. Las variables de shell no pasan de una orden a otra: escribe la ruta entera cada vez.
- Si Godot reescribe ficheros que la tarea no toca, devuélvelos: `git checkout -- default_bus_layout.tres project.godot balance/results.json art/sprites/pixel/materials/`. Mira `git status` antes de cada commit.
- Nunca mates procesos de Godot que no hayas lanzado tú: el usuario puede estar jugando o tener el editor abierto.
- GDScript con tabuladores y comentarios en español. Sin autoloads nuevos ni plugins.
- Todo texto visible nuevo va en español en el código, con su fila en `locale/textos.csv` (columnas `keys,es,en`, `es` igual a la clave, sin líneas en blanco; tras editarlo, `--import`). Este plan no añade textos visibles: si alguna tarea los añade, lleva su fila. No escribas `tr("…")` en comentarios: `TextTests` busca cada `tr(` del código en el CSV.
- Medidas del panel (1080×1920, spec apartado 2): caja del botín en x 60–1020, y 970–1410 (960×440); techo invisible 165 px por encima (y ≈ 805; en coordenadas de la caja, y = −165); icono y título de la mochila en y 1410–1456; mochila 6×4 y zona de venta en y 1460–1900.
- `InventoryManager.loot` sigue siendo la lista del botín: «Vender todo», la venta, la ficha y la migración no cambian. Nunca se pierde una pieza.
- Guardado: `lx`, `ly` y `ang` son opcionales; sin versión nueva de `SaveManager`.
- Commits: uno por tarea, en la rama `botin-fisico` del worktree `D:/Proyectos/PetJam-botin`, añadiendo por ruta (nunca `git add -A`), sin Co-Authored-By. `art/assets` es una junction a la carpeta del repo principal: no la añadas ni la borres nunca. No toques `D:/Proyectos/PetJam`.
- Batería de pruebas (desde la raíz del worktree, con la copia de la partida recién hecha):

  ```bash
  APPDATA=<appdata> timeout 300 D:/Software/Godot/godot_ver4.5.exe --headless --fixed-fps 60 --path . res://scenes/tests/LootBoxTests.tscn
  APPDATA=<appdata> timeout 300 D:/Software/Godot/godot_ver4.5.exe --headless --path . res://scenes/tests/InventoryGridTests.tscn
  APPDATA=<appdata> timeout 300 D:/Software/Godot/godot_ver4.5.exe --headless --path . res://scenes/tests/RankTests.tscn
  APPDATA=<appdata> timeout 300 D:/Software/Godot/godot_ver4.5.exe --headless --path . res://scenes/tests/GameplayTests.tscn
  APPDATA=<appdata> timeout 300 D:/Software/Godot/godot_ver4.5.exe --headless --path . res://scenes/tests/PixelTests.tscn
  APPDATA=<appdata> timeout 300 D:/Software/Godot/godot_ver4.5.exe --headless --path . res://scenes/tests/TextTests.tscn
  ```

  Cada escena sale con 0 si todo pasa y con 1 si algo falla, e imprime `[Suite] N comprobaciones, M fallos`. Donde una tarea diga "la batería", son las seis.
- Para ver que una prueba nueva falla antes de existir el código, se analiza la suite sin ejecutarla (sale al momento):

  ```bash
  APPDATA=<appdata> timeout 300 D:/Software/Godot/godot_ver4.5.exe --headless --path . --check-only --script res://scripts/tests/LootBoxTests.gd
  ```

  Sale con 1 e imprime `SCRIPT ERROR: Parse Error: …` con el nombre que falta.

## Review Focus

- **Vender la pieza que sostiene a otras** (en la caja, o en la tienda con el panel cerrado): las de encima caen al suelo; no se quedan dormidas en el aire. Prueba: `test_taking_out_a_support_lets_the_pile_fall` (tarea 4).
- **Una partida con poses que se solapan** (dos piezas guardadas en el mismo sitio, o un fantasma guardado dentro de la pila): carga sin que nada salga despedido; la segunda entra como fantasma. Prueba: `test_overlapping_saved_poses_do_not_explode` (tarea 4).
- **Cerrar el panel (Atrás) con una pieza de la caja en el dedo:** vuelve a la caja, se recoge su pose y se guarda; no se pierde ni se queda «cogida». Prueba: `test_closing_mid_drag_returns_the_piece_to_the_box` (tarea 5).
- **Llega una pieza forjada mientras se arrastra una de la caja:** la arrastrada no reaparece en la caja y la nueva espera su turno para caer desde arriba. Prueba: `test_new_loot_while_holding_a_box_piece` (tarea 5).
- **Una épica de la caja soltada en la zona de venta:** mientras se pide confirmar, vuelve a la caja (ni invisible ni en el aire); con Sí se vende y su cuerpo desaparece. Prueba: `test_selling_an_epic_from_the_box_waits_in_the_box` (tarea 5).

---

## Mapa de ficheros

| Fichero | Acción | Responsabilidad |
|---|---|---|
| `scripts/core/PieceShape.gd` | modificar | `mass_center()` y `collision_rects()`: centro de masa y rectángulos de colisión de una pieza girada (tarea 1) |
| `scripts/data/CraftedItem.gd` | modificar | `loot_pose`, en `to_dict` y `from_dict`; `pose_from_dict()` descarta valores no numéricos (tarea 2) |
| `scripts/autoload/InventoryManager.gd` | modificar | `_take_out` olvida la pose; señal `loot_poses_changed` y `note_loot_poses()` (tarea 2) |
| `scripts/autoload/GameManager.gd` | modificar | `loot_poses_changed` pide el guardado diferido de siempre (tarea 2) |
| `scripts/ui/LootPiece.gd` | crear | el `RigidBody2D` de una pieza: formas, masa, dibujo, modo fantasma y geometría (tarea 3) |
| `scripts/ui/LootBoxView.gd` | crear | la caja: paredes y techo, cuerpos según el botín, entradas, «no cabe», fantasmas, congelar y poses (tarea 4) |
| `scripts/ui/EquipmentPanel.gd`, `scenes/UI/EquipmentPanel.tscn` | modificar | medidas nuevas, sin desplazamiento, arrastre y lanzamiento con la caja (tarea 5) |
| `scripts/tests/LootBoxTests.gd`, `scenes/tests/LootBoxTests.tscn` | crear | suite nueva (tareas 1 a 6) |
| `scripts/tests/InventoryGridTests.gd` | modificar | las pruebas del panel que usaban la tira (tarea 5); fuera la de la tira (tarea 6) |
| `scripts/tests/VisualCapture.gd` | modificar | el plan `inventory` coge la pieza de la caja (tarea 5); plan nuevo `lootbox` (tarea 6) |
| `scripts/ui/LootStripView.gd` | borrar | ya no lo usa nadie (tarea 6) |
| `scripts/ui/GearArt.gd` | modificar | comentario: es el `sprite_for` de `LootPiece` (tarea 6) |
| `doc/ARCHITECTURE.md` | modificar | apartado 4.3: el botín con física (tarea 6) |

---

### Task 1: Rectángulos de colisión de una pieza (`PieceShape`) y la suite `LootBoxTests`

**Files:**
- Modify: `scripts/core/PieceShape.gd` (al final, tras `check_resource`)
- Create: `scripts/tests/LootBoxTests.gd`, `scenes/tests/LootBoxTests.tscn`

**Interfaces:**
- Consumes: `PieceShape.footprint` / `PieceShape.of_item(item: CraftedItem, rot: int = -1) -> Dictionary` (`{"clean": Array[Vector2i], "aristas": Array[Vector2i], "size": Vector2i}`), `GearGridView.CELL` (110.0).
- Produces:
  - `PieceShape.mass_center(fp: Dictionary, cell_px: float) -> Vector2`: media de los centros de todas las casillas (limpias y aristas), en píxeles desde la esquina de la caja de `fp`.
  - `PieceShape.collision_rects(fp: Dictionary, cell_px: float) -> Array[Rect2]`: un rectángulo de `cell_px` por casilla, primero las limpias (en el orden de `fp.clean`) y después las aristas, centrados en `mass_center`.
  - `LootBoxTests` (suite): constantes `CELL`, `ITEM_IDS`; ayudas `_res(id)`, `_piece(id, quality = 0.95, aristas = [])`, `_same_rects(a, b)`.

- [ ] **Step 1: La suite con las pruebas que fallan**

`scenes/tests/LootBoxTests.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/tests/LootBoxTests.gd" id="1"]

[node name="LootBoxTests" type="Node"]
script = ExtResource("1")
```

`scripts/tests/LootBoxTests.gd`:

```gdscript
extends "res://scripts/tests/TestSuite.gd"
## 🧪 Pruebas del botín con física (spec doc/specs/2026-10-02-botin-con-fisica.md), solo desarrollo, sin ventana y con la
## física de verdad. Con --fixed-fps 60 cada paso de física es 1/60 s de juego y no se espera tiempo real:
##   D:/Software/Godot/godot_ver4.5.exe --headless --fixed-fps 60 --path . res://scenes/tests/LootBoxTests.tscn

const CELL := GearGridView.CELL
const ITEM_IDS := [&"sword_basic", &"sword_advanced", &"sword_masterwork", &"shield_basic",
	&"shield_advanced", &"shield_master", &"helmet_basic", &"helmet_advanced", &"helmet_master",
	&"boots_basic", &"boots_advanced", &"boots_master"]


func _res(id: StringName) -> ItemResource:
	return load("res://data/items/%s.tres" % id)


## Pieza de prueba con calidad y aristas fijas (sin sorteo). Con 0,95 es épica: sin aristas.
func _piece(id: StringName, quality: float = 0.95, aristas: Array[Vector2i] = []) -> CraftedItem:
	var item := CraftedItem.new(_res(id), quality)
	item.aristas = aristas
	return item


## true si dos listas de rectángulos son las mismas, en cualquier orden (con margen de redondeo).
func _same_rects(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	var left := b.duplicate()
	for r in a:
		var found := -1
		for i in left.size():
			if r.is_equal_approx(left[i]):
				found = i
				break
		if found < 0:
			return false
		left.remove_at(found)
	return true


# ─── Tarea 1: rectángulos de colisión ──────────────────────────────────

func test_collision_rects_cover_the_cells_in_every_turn() -> void:
	for id in ITEM_IDS:
		var aristas: Array[Vector2i] = []
		aristas.assign(_res(id).arista_spots.slice(0, 2))  # una pieza básica: 2 aristas, que también chocan
		var item := _piece(id, 0.3, aristas)
		for rot in 4:
			var fp := PieceShape.of_item(item, rot)
			var com := PieceShape.mass_center(fp, CELL)
			var rects := PieceShape.collision_rects(fp, CELL)
			var want := []
			for c in fp.clean + fp.aristas:
				want.append(Rect2(Vector2(c) * CELL, Vector2(CELL, CELL)))
			var got := []
			var sum := Vector2.ZERO
			for r in rects:
				got.append(Rect2(r.position + com, r.size))
				sum += r.get_center()
			check(_same_rects(got, want), "%s giro %d: un rectángulo por casilla, aristas incluidas (%s)" % [id, rot, rects])
			check(sum.length() < 0.01, "%s giro %d: centrados en su centro de masa (%s)" % [id, rot, sum])
			check(rects[0].is_equal_approx(Rect2(Vector2(fp.clean[0]) * CELL - com, Vector2(CELL, CELL))), "%s giro %d: el primero es la primera casilla limpia" % [id, rot])


## Girar el cuerpo un cuarto de vuelta da la misma pieza que girarla en la rejilla: así, al cogerla de la caja enderezada,
## la vista previa cuadra con lo que se veía.
func test_turning_the_body_matches_the_turned_piece() -> void:
	var item := _piece(&"boots_master", 0.3, [Vector2i(1, 1)])
	var base := PieceShape.collision_rects(PieceShape.of_item(item, 0), CELL)
	for rot in 4:
		var turned := []
		for r in base:
			turned.append(Rect2(r.get_center().rotated(rot * PI / 2.0) - Vector2(CELL, CELL) * 0.5, Vector2(CELL, CELL)))
		check(_same_rects(turned, PieceShape.collision_rects(PieceShape.of_item(item, rot), CELL)), "girar %d cuartos el cuerpo da la pieza girada %d" % [rot, rot])


func test_mass_center_is_the_mean_of_the_cells() -> void:
	var sword := _piece(&"sword_basic")  # 1×2 de pie
	check(PieceShape.mass_center(PieceShape.of_item(sword, 0), CELL).is_equal_approx(Vector2(55, 110)), "espada básica: en medio de sus dos casillas")
	check(PieceShape.mass_center(PieceShape.of_item(sword, 1), CELL).is_equal_approx(Vector2(110, 55)), "tumbada, también")
	var boots := _piece(&"boots_master")  # (0,0) (0,1) (0,2) (1,2)
	check(PieceShape.mass_center(PieceShape.of_item(boots, 0), CELL).is_equal_approx(Vector2(0.75, 1.75) * CELL), "botas en L: la media de sus 4 casillas")
```

- [ ] **Step 2: Ver que falla**

Run: `APPDATA=<appdata> timeout 300 D:/Software/Godot/godot_ver4.5.exe --headless --path . --import` y después `APPDATA=<appdata> timeout 300 D:/Software/Godot/godot_ver4.5.exe --headless --path . --check-only --script res://scripts/tests/LootBoxTests.gd`
Expected: sale con 1 y `SCRIPT ERROR: Parse Error` por `mass_center` o `collision_rects` (no existen en `PieceShape`).

- [ ] **Step 3: `PieceShape.mass_center` y `PieceShape.collision_rects`**

Añade al final de `scripts/core/PieceShape.gd`:

```gdscript


## Centro de masa de una pieza girada (footprint()), en píxeles desde la esquina de su caja: la media de los centros de
## todas sus casillas, limpias y aristas (todas pesan lo mismo y todas chocan en la caja del botín).
static func mass_center(fp: Dictionary, cell_px: float) -> Vector2:
	var cells: Array[Vector2i] = []
	cells.append_array(fp.clean)
	cells.append_array(fp.aristas)
	var sum := Vector2.ZERO
	for c in cells:
		sum += (Vector2(c) + Vector2(0.5, 0.5)) * cell_px
	return sum / float(cells.size())


## Rectángulos de colisión de una pieza girada (footprint()) para el botín con física (spec
## doc/specs/2026-10-02-botin-con-fisica.md, apartado 3): uno por casilla, primero las limpias y después las aristas, en
## píxeles y centrados en su centro de masa.
static func collision_rects(fp: Dictionary, cell_px: float) -> Array[Rect2]:
	var com := mass_center(fp, cell_px)
	var out: Array[Rect2] = []
	for list in [fp.clean, fp.aristas]:
		for c in list:
			out.append(Rect2(Vector2(c) * cell_px - com, Vector2(cell_px, cell_px)))
	return out
```

- [ ] **Step 4: Ver que pasa**

Run: `APPDATA=<appdata> timeout 300 D:/Software/Godot/godot_ver4.5.exe --headless --path . --import` y después `APPDATA=<appdata> timeout 300 D:/Software/Godot/godot_ver4.5.exe --headless --fixed-fps 60 --path . res://scenes/tests/LootBoxTests.tscn`
Expected: `ok` en las 3 pruebas y `[LootBoxTests] N comprobaciones, 0 fallos`, código 0. Después, InventoryGridTests: 0 fallos (no cambia nada de lo que usa).

- [ ] **Step 5: Commit**

```bash
git status --short
git add scripts/core/PieceShape.gd scripts/tests/LootBoxTests.gd scripts/tests/LootBoxTests.gd.uid scenes/tests/LootBoxTests.tscn
git commit -m "feat: rectángulos de colisión y centro de masa de una pieza (PieceShape) y suite LootBoxTests"
```

---

### Task 2: La pose del botín en la pieza y en el guardado

**Files:**
- Modify: `scripts/data/CraftedItem.gd` (variables de sitio, `to_dict`, `from_dict`)
- Modify: `scripts/autoload/InventoryManager.gd` (señales, `_take_out`, una función nueva tras `remove_crafted_item`)
- Modify: `scripts/autoload/GameManager.gd` (`_ready`, junto a las conexiones de guardado)
- Test: `scripts/tests/LootBoxTests.gd`

**Interfaces:**
- Consumes: `CraftedItem.to_dict()`, `CraftedItem.from_dict(data, res)`, `InventoryManager.to_save_data()`, `load_save_data(data, record)`, `move_item`, `GameManager.save_writer` (escritor de pega de las pruebas) y `_on_trigger_save`.
- Produces:
  - `CraftedItem.loot_pose: Dictionary`: `{}` (sin pose) o `{"pos": Vector2, "ang": float}`, en coordenadas de la caja del botín.
  - `to_dict()` escribe `lx`, `ly` y `ang` solo con `place == &"loot"` y pose; `from_dict()` los lee con `CraftedItem.pose_from_dict(data: Dictionary) -> Dictionary` (`{}` si falta alguno o alguno no es un número finito).
  - `InventoryManager.loot_poses_changed` (señal sin argumentos) y `InventoryManager.note_loot_poses() -> void`.
  - `_take_out(item)` deja `item.loot_pose = {}`.
  - `GameManager` guarda en diferido al recibir `loot_poses_changed`.
  - `LootBoxTests`: ayudas `_im()`, `_fresh_inventory() -> Dictionary`, `_restore_inventory(saved)`, `_save_writes` y `_count_save_write()`.

- [ ] **Step 1: Pruebas que fallan**

Añade al final de `scripts/tests/LootBoxTests.gd`:

```gdscript


# ─── Tarea 2: la pose en la pieza y en el guardado ─────────────────────

func _im() -> Node:
	return get_node("/root/InventoryManager")


## Deja el inventario vacío y devuelve lo que había para restaurarlo.
func _fresh_inventory() -> Dictionary:
	var saved: Dictionary = _im().to_save_data()
	_im().clear()
	return saved


func _restore_inventory(saved: Dictionary) -> void:
	_im().load_save_data(saved, int(get_node("/root/GameManager").best_enemy_level))
	await get_tree().process_frame  # deja pasar los guardados diferidos del cambio


var _save_writes := 0


func _count_save_write() -> void:
	_save_writes += 1


func test_loot_pose_goes_in_the_save_only_in_the_loot() -> void:
	var item := _piece(&"boots_master")
	check(item.loot_pose.is_empty() and not item.to_dict().has("lx"), "una pieza nueva no tiene pose ni la escribe")
	item.loot_pose = {"pos": Vector2(412.5, -80.25), "ang": -1.25}
	var d := item.to_dict()
	check(is_equal_approx(float(d.lx), 412.5) and is_equal_approx(float(d.ly), -80.25) and is_equal_approx(float(d.ang), -1.25), "en el botín escribe lx, ly y ang (%s)" % [d])
	var back := CraftedItem.from_dict(JSON.parse_string(JSON.stringify(d)), item.item_resource)
	check(back.loot_pose.get("pos", Vector2.INF).is_equal_approx(Vector2(412.5, -80.25)) and is_equal_approx(float(back.loot_pose.get("ang", 0.0)), -1.25), "y vuelve igual del fichero (%s)" % [back.loot_pose])
	item.place = &"bag"
	check(not item.to_dict().has("lx") and not item.to_dict().has("ang"), "fuera del botín no se escribe")
	var plain := d.duplicate()
	for key in ["lx", "ly", "ang"]:
		plain.erase(key)
	check(CraftedItem.from_dict(plain, item.item_resource).loot_pose.is_empty(), "una partida sin los campos carga sin pose")
	for bad in [{"lx": "a", "ly": 1, "ang": 0}, {"lx": 1.0, "ly": 2.0}, {"lx": 1.0, "ly": null, "ang": 0.0}, {"lx": INF, "ly": 0.0, "ang": 0.0}]:
		var with_bad := plain.duplicate()
		with_bad.merge(bad, true)
		check(CraftedItem.from_dict(with_bad, item.item_resource).loot_pose.is_empty(), "valores que no son números se descartan (%s)" % [bad])
	check(CraftedItem.pose_from_dict({"lx": 3, "ly": 4, "ang": 0}) == {"pos": Vector2(3, 4), "ang": 0.0}, "los enteros valen")


func test_inventory_keeps_loot_poses_and_forgets_them_outside_the_loot() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var a := _piece(&"shield_master")
	var b := _piece(&"helmet_basic")
	im.add_crafted_item(a)
	im.add_crafted_item(b)
	a.loot_pose = {"pos": Vector2(300, 274), "ang": 0.5}
	b.loot_pose = {"pos": Vector2(700, 384), "ang": 0.0}
	var data: Dictionary = JSON.parse_string(JSON.stringify(im.to_save_data()))
	im.load_save_data(data, 1)
	var by_id := {}
	for it in im.get_crafted_items():
		by_id[it.item_resource.item_id] = it
	var shield: CraftedItem = by_id[&"shield_master"]
	var helmet: CraftedItem = by_id[&"helmet_basic"]
	check(shield.loot_pose.get("pos", Vector2.INF).is_equal_approx(Vector2(300, 274)) and is_equal_approx(float(shield.loot_pose.get("ang", 0.0)), 0.5), "la pose vuelve al cargar la partida (%s)" % [shield.loot_pose])
	im.move_item(helmet, &"bag", Vector2i(0, 0), 0)
	check(helmet.loot_pose.is_empty(), "al salir del botín la pieza pierde su pose")
	im.move_item(helmet, &"loot")
	check(helmet.loot_pose.is_empty() and helmet in im.get_loot(), "y vuelve al botín sin pose: caerá desde arriba")
	await _restore_inventory(saved)


## Las poses nuevas piden el guardado diferido de siempre: varios avisos en un fotograma son una sola escritura. Se cambia el
## escritor por uno que solo cuenta: la prueba no escribe ninguna partida.
func test_new_loot_poses_ask_for_one_deferred_save() -> void:
	var gm := get_node("/root/GameManager")
	gm.save_writer = Callable(self, "_count_save_write")
	for i in 2:
		await get_tree().process_frame
	_save_writes = 0
	_im().note_loot_poses()
	_im().note_loot_poses()
	for i in 2:
		await get_tree().process_frame
	check(_save_writes == 1, "dos avisos de poses en un fotograma, una escritura (%d)" % _save_writes)
	gm.save_writer = Callable()
```

- [ ] **Step 2: Ver que falla**

Run: `APPDATA=<appdata> timeout 300 D:/Software/Godot/godot_ver4.5.exe --headless --path . --check-only --script res://scripts/tests/LootBoxTests.gd`
Expected: sale con 1 y `Parse Error` por `pose_from_dict` (no existe en `CraftedItem`).

- [ ] **Step 3: `CraftedItem.loot_pose`**

En `scripts/data/CraftedItem.gd`, tras la línea `var aristas: Array[Vector2i] = []  ## …`, añade:

```gdscript
## Dónde está en la caja del botín con física (LootBoxView): {"pos": Vector2, "ang": float} en coordenadas de la caja, o
## vacío si no tiene pose (al abrir el panel cae desde arriba). InventoryManager la vacía cuando la pieza sale del botín.
var loot_pose: Dictionary = {}
```

Sustituye `to_dict` y `from_dict` por:

```gdscript
## Serialización para inventario persistente. La pose del botín (lx, ly, ang) solo si está en el botín y la tiene.
func to_dict() -> Dictionary:
	var d := {
		"item_id": String(item_resource.item_id) if item_resource else "",
		"quality": quality,
		"stats": calculated_stats.duplicate(),
		"timestamp": crafted_timestamp,
		"rank": rank,
		"place": String(place),
		"x": cell.x,
		"y": cell.y,
		"rot": rot,
		"aristas": aristas.map(func(a): return [a.x, a.y]),
	}
	if place == &"loot" and not loot_pose.is_empty():
		d["lx"] = loot_pose.pos.x
		d["ly"] = loot_pose.pos.y
		d["ang"] = loot_pose.ang
	return d

## Deserialización desde diccionario
static func from_dict(data: Dictionary, item_res: ItemResource) -> CraftedItem:
	var item = CraftedItem.new(item_res, data.get("quality", 0.5), maxi(1, int(data.get("rank", 1))))
	item.calculated_stats = data.get("stats", {}).duplicate()
	item.crafted_timestamp = data.get("timestamp", 0)
	item.place = StringName(data.get("place", "loot"))
	item.cell = Vector2i(int(data.get("x", 0)), int(data.get("y", 0)))
	item.rot = posmod(int(data.get("rot", 0)), 4)
	var ar: Array[Vector2i] = []
	for pair in data.get("aristas", []):
		if pair is Array and pair.size() == 2:
			ar.append(Vector2i(int(pair[0]), int(pair[1])))
	item.aristas = ar
	item.loot_pose = pose_from_dict(data)
	return item

## Pose del botín leída de un guardado (spec del botín con física, apartado 8): {} si falta lx, ly o ang, o si alguno no es
## un número finito. Que quepa en la caja lo mira LootBoxView.pose_is_valid al abrir el panel.
static func pose_from_dict(data: Dictionary) -> Dictionary:
	var values: Array[float] = []
	for key in ["lx", "ly", "ang"]:
		var v = data.get(key)
		if not (v is float or v is int) or not is_finite(float(v)):
			return {}
		values.append(float(v))
	return {"pos": Vector2(values[0], values[1]), "ang": values[2]}
```

- [ ] **Step 4: `InventoryManager` olvida la pose fuera del botín y avisa de poses nuevas**

En `scripts/autoload/InventoryManager.gd`, tras `signal consumables_changed(slots: Array)`, añade:

```gdscript
signal loot_poses_changed  ## la caja del botín ha dejado en sus piezas dónde están (GameManager guarda)
```

Tras la función `remove_crafted_item`, añade:

```gdscript


## Las piezas del botín tienen pose nueva (la caja con física se ha quedado quieta, o se ha cerrado el panel): pide el
## guardado diferido de siempre (spec del botín con física, apartado 8).
func note_loot_poses() -> void:
	loot_poses_changed.emit()
```

Sustituye `_take_out` por:

```gdscript
## Saca una pieza de donde esté, sin avisar. Fuera del botín su pose no vale: si vuelve, cae desde arriba.
func _take_out(item: CraftedItem) -> void:
	hero_grid.remove(item)
	bag_grid.remove(item)
	loot.erase(item)
	item.loot_pose = {}
```

- [ ] **Step 5: `GameManager` guarda al recibir poses nuevas**

En `scripts/autoload/GameManager.gd`, en `_ready`, justo después del bloque que conecta `crafted_items_changed` a `_on_trigger_save`, añade:

```gdscript
	if inv_manager and inv_manager.has_signal("loot_poses_changed"):
		# Save cuando la pila del botín se queda quieta o se cierra el panel (spec del botín con física, apartado 8)
		inv_manager.loot_poses_changed.connect(_on_trigger_save)
```

- [ ] **Step 6: Ver que pasa**

Run: `APPDATA=<appdata> timeout 300 D:/Software/Godot/godot_ver4.5.exe --headless --fixed-fps 60 --path . res://scenes/tests/LootBoxTests.tscn`
Expected: `[LootBoxTests] N comprobaciones, 0 fallos`. Después InventoryGridTests y RankTests: 0 fallos (las partidas sin `lx` cargan igual).

- [ ] **Step 7: Commit**

```bash
git status --short
git add scripts/data/CraftedItem.gd scripts/autoload/InventoryManager.gd scripts/autoload/GameManager.gd scripts/tests/LootBoxTests.gd
git commit -m "feat: pose del botín en la pieza (loot_pose) y en el guardado, opcional y con guardado diferido"
```

---

### Task 3: Una pieza con física (`LootPiece`)

**Files:**
- Create: `scripts/ui/LootPiece.gd`
- Test: `scripts/tests/LootBoxTests.gd`

**Interfaces:**
- Consumes: `PieceShape.of_item`, `PieceShape.mass_center`, `PieceShape.collision_rects` (tarea 1), `GearGridView.CELL`, `GearGridView.draw_piece_at(canvas, item, top_left, rot, cell_px, alpha, sprite_fn)`, `GearArt.texture_for`.
- Produces (`class_name LootPiece extends RigidBody2D`):
  - escala: `BOX_CELL := GearGridView.CELL * 0.5` (55 px por casilla), la única constante de escala del botín: formas, masa por casilla, dibujo, caídas, techo y pruebas la usan;
  - capas: `LAYER_WALLS := 1 << 8`, `LAYER_PIECES := 1 << 9`, `LAYER_GHOSTS := 1 << 10`;
  - física: `FRICTION := 0.8`, `BOUNCE := 0.05`, `LINEAR_DAMP := 0.5`, `ANGULAR_DAMP := 2.0`, `GRAVITY_SCALE := 2.0`, `MASS_PER_CELL := 1.0`; dibujo: `GHOST_ALPHA := 0.45`;
  - estado: `item: CraftedItem`, `is_ghost: bool`, `rects: Array[Rect2]` (en coordenadas del cuerpo; las limpias primero), `sprite_for: Callable`;
  - `setup(it: CraftedItem) -> void` (antes de `add_child`), `set_ghost(on: bool) -> void`;
  - geometría, en coordenadas del padre (la caja): `bounds() -> Rect2`, `top_y() -> float`, `contains_point(p: Vector2) -> bool`;
  - `straight_rot() -> int`: el cuarto de vuelta más cercano a su ángulo (0-3, como `PieceShape`);
  - estáticas: `rects_for(item: CraftedItem) -> Array[Rect2]` y `extent(list: Array[Rect2], angle: float) -> Rect2` (caja de los rectángulos girados alrededor del centro de masa).
  - `LootBoxTests`: ayudas `_physics_until(done: Callable, limit: int) -> int`, `_physics_steps(n: int)`, `_floor_holder() -> Node2D`, `_loot_piece(id, pos, angle = 0.0, aristas = []) -> LootPiece`.

- [ ] **Step 1: Pruebas que fallan**

Añade al final de `scripts/tests/LootBoxTests.gd`:

```gdscript


# ─── Tarea 3: una pieza con física ─────────────────────────────────────

## Avanza la física paso a paso hasta que `done` dé true. Devuelve los pasos que hicieron falta, o -1 si pasan `limit`.
func _physics_until(done: Callable, limit: int) -> int:
	for i in limit:
		await get_tree().physics_frame
		if done.call():
			return i + 1
	return -1


func _physics_steps(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## Soporte con un suelo de pega en y = 440 (coordenadas del soporte), en la capa de las paredes de la caja.
func _floor_holder() -> Node2D:
	var holder := Node2D.new()
	holder.position = Vector2(60, 970)
	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = LootPiece.LAYER_WALLS
	floor_body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(2000, 400)
	cs.shape = shape
	cs.position = Vector2(480, 640)
	floor_body.add_child(cs)
	holder.add_child(floor_body)
	add_child(holder)
	return holder


func _loot_piece(id: StringName, pos: Vector2, angle: float = 0.0, aristas: Array[Vector2i] = []) -> LootPiece:
	var body := LootPiece.new()
	body.setup(_piece(id, 0.95, aristas))
	body.transform = Transform2D(angle, pos)
	return body


func test_loot_piece_has_one_shape_per_cell_and_its_mass() -> void:
	var holder := _floor_holder()
	var body := _loot_piece(&"shield_master", Vector2(300, 100), 0.0, [Vector2i(2, 1)])  # 6 casillas y 1 arista
	holder.add_child(body)
	var shapes := body.get_children().filter(func(n): return n is CollisionShape2D)
	check(shapes.size() == 7 and body.rects.size() == 7, "un rectángulo por casilla, la arista incluida (%d)" % shapes.size())
	check(is_equal_approx(body.mass, 7.0 * LootPiece.MASS_PER_CELL), "masa proporcional a las casillas (%.1f)" % body.mass)
	check(is_equal_approx(LootPiece.BOX_CELL, 55.0) and body.rects.all(func(r): return r.size == Vector2(55, 55)), "en la caja, cada casilla choca a media escala: 55 px")
	check(body.collision_layer == LootPiece.LAYER_PIECES and body.collision_mask == LootPiece.LAYER_WALLS | LootPiece.LAYER_PIECES, "choca con la caja y con las demás piezas")
	check(not body.is_ghost and is_equal_approx(body.modulate.a, 1.0), "empieza sin ser fantasma")
	holder.queue_free()
	await get_tree().physics_frame


func test_loot_piece_falls_and_sleeps_on_the_floor() -> void:
	var holder := _floor_holder()
	var body := _loot_piece(&"helmet_master", Vector2(300, 0), 0.4)
	holder.add_child(body)
	var frames: int = await _physics_until(func(): return body.sleeping, 900)
	check(frames > 0, "cae y se queda quieta en menos de 15 s (%d pasos)" % frames)
	check(absf(body.bounds().end.y - 440.0) < 4.0, "apoyada en el suelo (fondo en %.1f)" % body.bounds().end.y)
	holder.queue_free()
	await get_tree().physics_frame


func test_a_ghost_falls_through_pieces_but_not_the_floor() -> void:
	var holder := _floor_holder()
	var below := _loot_piece(&"shield_advanced", Vector2(300, 384))  # 2×2 a 55 px: centro a 55 px del suelo
	var ghost := _loot_piece(&"shield_advanced", Vector2(300, 0))
	holder.add_child(below)
	holder.add_child(ghost)
	ghost.set_ghost(true)
	check(ghost.is_ghost and ghost.collision_layer == LootPiece.LAYER_GHOSTS and ghost.collision_mask == LootPiece.LAYER_WALLS, "el fantasma solo choca con la caja")
	check(is_equal_approx(ghost.modulate.a, LootPiece.GHOST_ALPHA), "y se dibuja semitransparente")
	var frames: int = await _physics_until(func(): return ghost.sleeping and below.sleeping, 900)
	check(frames > 0, "los dos se quedan quietos (%d pasos)" % frames)
	check(ghost.position.distance_to(below.position) < 10.0, "el fantasma atraviesa la pieza y se queda solapado con ella (%s, %s)" % [ghost.position, below.position])
	check(ghost.bounds().end.y <= 444.0 and below.position.distance_to(Vector2(300, 384)) < 3.0, "sin atravesar el suelo ni empujar a la otra")
	ghost.set_ghost(false)
	check(not ghost.is_ghost and ghost.collision_layer == LootPiece.LAYER_PIECES and is_equal_approx(ghost.modulate.a, 1.0), "al salir del modo fantasma vuelve a chocar y a verse entera")
	holder.queue_free()
	await get_tree().physics_frame


func test_points_bounds_and_the_nearest_quarter_turn() -> void:
	var holder := _floor_holder()
	var sword := _loot_piece(&"sword_basic", Vector2(200, 200), PI / 2.0)  # tumbada a 55 px: 110 de ancho (145 a 255) y 55 de alto (172,5 a 227,5)
	holder.add_child(sword)
	check(sword.contains_point(Vector2(150, 200)) and sword.contains_point(Vector2(250, 200)), "tumbada, ocupa de lado")
	check(not sword.contains_point(Vector2(200, 150)) and not sword.contains_point(Vector2(100, 200)), "y no por arriba ni más allá de su media escala")
	check(sword.bounds().is_equal_approx(Rect2(145, 172.5, 110, 55)), "su caja girada, a media escala (%s)" % sword.bounds())
	check(is_equal_approx(sword.top_y(), 172.5), "su punto más alto")
	for pair in [[0.2, 0], [1.3, 1], [-0.1, 0], [3.0, 2], [-1.6, 3], [4.6, 3], [6.2, 0]]:
		sword.rotation = pair[0]
		check(sword.straight_rot() == pair[1], "ángulo %.1f → %d cuartos (%d)" % [pair[0], pair[1], sword.straight_rot()])
	check(LootPiece.extent(sword.rects, 0.0).is_equal_approx(Rect2(-27.5, -55, 55, 110)), "de pie, su caja alrededor del centro de masa (%s)" % LootPiece.extent(sword.rects, 0.0))
	holder.queue_free()
	await get_tree().physics_frame
```

- [ ] **Step 2: Ver que falla**

Run: `APPDATA=<appdata> timeout 300 D:/Software/Godot/godot_ver4.5.exe --headless --path . --check-only --script res://scripts/tests/LootBoxTests.gd`
Expected: sale con 1 y `Parse Error: Identifier "LootPiece" not declared`.

- [ ] **Step 3: `scripts/ui/LootPiece.gd`**

```gdscript
class_name LootPiece
extends RigidBody2D

## Una pieza del botín con física (spec doc/specs/2026-10-02-botin-con-fisica.md, apartados 3 y 5): un cuerpo rígido con
## un rectángulo de colisión por casilla de su silueta (aristas incluidas), centrado en su centro de masa, y su dibujo de
## siempre (GearGridView.draw_piece_at), que gira con el cuerpo, todo a media escala (BOX_CELL, 55 px por casilla). Su
## forma es la del giro 0; el ángulo lo da el cuerpo.
## La caja (LootBoxView) la crea, la quita y decide cuándo pasa a modo fantasma: choca con la caja pero no con las demás
## piezas y se dibuja semitransparente.

## Escala de la caja (decisión del usuario, 2026-10-02): en el botín las piezas se dibujan y chocan a media escala, 55 px
## por casilla. Al cogerlas vuelven a 110 (el panel arrastra a tamaño completo) y al soltarlas en la caja vuelven a 55.
## Es la única constante de escala del botín: LootBoxView y las pruebas la leen de aquí.
const BOX_CELL := GearGridView.CELL * 0.5
## Capas propias del botín: el juego usa la 1 (Tico, enemigos, salas y el Tico del panel) y no debe tocar la caja
const LAYER_WALLS := 1 << 8
const LAYER_PIECES := 1 << 9
const LAYER_GHOSTS := 1 << 10
const FRICTION := 0.8
const BOUNCE := 0.05
const LINEAR_DAMP := 0.5
const ANGULAR_DAMP := 2.0
const GRAVITY_SCALE := 2.0
const MASS_PER_CELL := 1.0
const GHOST_ALPHA := 0.45

var item: CraftedItem
var is_ghost := false
var rects: Array[Rect2] = []  ## en coordenadas del cuerpo, de BOX_CELL (giro 0, centradas en su centro de masa); las limpias primero
var sprite_for: Callable = Callable(GearArt, "texture_for")  ## (pieza, giro) → Texture2D; sin textura, casillas de color
var _com := Vector2.ZERO  ## centro de masa desde la esquina de su caja, en el giro 0 y a BOX_CELL


## Rectángulos de colisión de una pieza en el giro 0, centrados en su centro de masa.
static func rects_for(it: CraftedItem) -> Array[Rect2]:
	return PieceShape.collision_rects(PieceShape.of_item(it, 0), BOX_CELL)


## Caja que ocupan unos rectángulos girados `angle` alrededor del centro de masa (el origen).
static func extent(list: Array[Rect2], angle: float) -> Rect2:
	var xf := Transform2D(angle, Vector2.ZERO)
	var out := Rect2(xf * list[0].position, Vector2.ZERO)
	for r in list:
		for corner: Vector2 in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
			out = out.expand(xf * corner)
	return out


## Formas, masa y material. Se llama antes de añadirla a la caja.
func setup(it: CraftedItem) -> void:
	item = it
	var fp := PieceShape.of_item(it, 0)
	_com = PieceShape.mass_center(fp, BOX_CELL)
	rects = PieceShape.collision_rects(fp, BOX_CELL)
	for r in rects:
		var cs := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = r.size
		cs.shape = shape
		cs.position = r.get_center()
		add_child(cs)
	mass = MASS_PER_CELL * rects.size()
	var mat := PhysicsMaterial.new()
	mat.friction = FRICTION
	mat.bounce = BOUNCE
	physics_material_override = mat
	gravity_scale = GRAVITY_SCALE
	linear_damp = LINEAR_DAMP
	angular_damp = ANGULAR_DAMP
	can_sleep = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_ghost(false)


## Modo fantasma (spec, apartado 5): choca con el suelo, las paredes y el techo, pero no con las demás piezas, y se dibuja
## semitransparente. Al cambiar se despierta, para que vuelva a caer o a apoyarse.
func set_ghost(on: bool) -> void:
	is_ghost = on
	collision_layer = LAYER_GHOSTS if on else LAYER_PIECES
	collision_mask = LAYER_WALLS if on else LAYER_WALLS | LAYER_PIECES
	modulate.a = GHOST_ALPHA if on else 1.0
	sleeping = false
	queue_redraw()


## Caja que ocupa ahora, girada, en coordenadas del padre (la caja del botín).
func bounds() -> Rect2:
	var e := extent(rects, rotation)
	return Rect2(e.position + position, e.size)


## Su punto más alto, en coordenadas del padre.
func top_y() -> float:
	return bounds().position.y


## true si un punto (coordenadas del padre) cae en alguna de sus casillas, aristas incluidas.
func contains_point(p: Vector2) -> bool:
	var local := transform.affine_inverse() * p
	for r in rects:
		if r.has_point(local):
			return true
	return false


## Cuarto de vuelta más cercano a su ángulo (0-3, en el sentido de las agujas del reloj, como PieceShape.rotate_raw).
func straight_rot() -> int:
	return posmod(roundi(rotation / (PI / 2.0)), 4)


func _draw() -> void:
	GearGridView.draw_piece_at(self, item, -_com, 0, BOX_CELL, 1.0, sprite_for)
```

- [ ] **Step 4: Ver que pasa**

Run: `APPDATA=<appdata> timeout 300 D:/Software/Godot/godot_ver4.5.exe --headless --path . --import` y después `APPDATA=<appdata> timeout 300 D:/Software/Godot/godot_ver4.5.exe --headless --fixed-fps 60 --path . res://scenes/tests/LootBoxTests.tscn`
Expected: `[LootBoxTests] N comprobaciones, 0 fallos`.
Si `test_loot_piece_falls_and_sleeps_on_the_floor` no llega a dormirse: sin `LootBoxView` (tarea 4) el espacio tiene el umbral de reposo por defecto; sube el tope a 1800 pasos antes de tocar la física.

- [ ] **Step 5: Commit**

```bash
git status --short
git add scripts/ui/LootPiece.gd scripts/ui/LootPiece.gd.uid scripts/tests/LootBoxTests.gd
git commit -m "feat: pieza del botín con física (LootPiece): formas por casilla, masa, dibujo y modo fantasma"
```

---

### Task 4: La caja del botín (`LootBoxView`)

**Files:**
- Create: `scripts/ui/LootBoxView.gd`
- Test: `scripts/tests/LootBoxTests.gd`

**Interfaces:**
- Consumes: todo `LootPiece` (tarea 3), `CraftedItem.loot_pose` (tarea 2), `InventoryManager.PLACE_LOOT`, `GearArt.texture_for`.
- Produces (`class_name LootBoxView extends Node2D`; coordenadas: las de este nodo, con la esquina de arriba a la izquierda de la caja en 0,0):
  - `signal poses_settled`: la pila se ha quedado quieta tras un cambio y sus poses ya están en las piezas (como mucho una vez cada `SAVE_EVERY` pasos);
  - constantes: `SIZE := Vector2(960, 440)`, `CEIL_Y := -165.0`, `MAX_THROW_SPEED := 1400.0`, `SPAWN_INTERVAL := 9`, `SPAWN_PATIENCE := 120`, `SETTLE_CHECK := 180`, `CEIL_TOUCH := 3.0`, `BOX_CELL := LootPiece.BOX_CELL` (55), `OVERLAP_MARGIN := BOX_CELL * 0.08`, `LIFT_STEP := BOX_CELL * 0.25`, `GHOST_CHECK := 60`, `SAVE_EVERY := 60` y las demás del fichero;
  - estado: `active: bool`, `sprite_for: Callable`, `rng: RandomNumberGenerator`; privados que leen las pruebas: `_bodies: Dictionary` (pieza → `LootPiece`) y `_queue: Array[CraftedItem]`;
  - `set_active(on: bool) -> void`: con `false`, la caja y sus cuerpos salen de la física (`PROCESS_MODE_DISABLED`);
  - `sync(list: Array) -> void`: los cuerpos siguen a la lista del botín;
  - `hold(item: CraftedItem) -> void`, `is_held(item: CraftedItem) -> bool`;
  - `drop_at(item: CraftedItem, local_pos: Vector2, velocity: Vector2, rot: int) -> void`: `local_pos` es el centro de masa en coordenadas de la caja (el mismo punto a 110 que a 55: la pieza encoge alrededor de él); solo actúa si `item.place == &"loot"` y no tiene cuerpo;
  - `piece_at(local: Vector2) -> LootPiece`, `body_of(item: CraftedItem) -> LootPiece`, `piece_global_point(item: CraftedItem) -> Vector2` (centro de su primera casilla limpia, en coordenadas globales), `rect_global() -> Rect2`;
  - `fits(body: LootPiece) -> bool`, `is_settled() -> bool`, `collect_poses() -> void`;
  - estáticas: `pose_is_valid(pose: Dictionary) -> bool`, `cap_throw(v: Vector2) -> Vector2`;
  - privada usada por las pruebas: `_overlaps(rects: Array[Rect2], xform: Transform2D, exclude: Array[RID] = []) -> bool`.
  - `LootBoxTests`: ayudas `_new_box() -> LootBoxView`, `_free_box(box)`, `_items(ids: Array) -> Array[CraftedItem]`, `_inside(body: LootPiece) -> bool`, `_highest_top(box, list) -> float`.

- [ ] **Step 1: Pruebas que fallan**

Añade al final de `scripts/tests/LootBoxTests.gd`:

```gdscript


# ─── Tarea 4: la caja ──────────────────────────────────────────────────

## Caja en su sitio del panel (60, 970), activa y con el azar fijo.
func _new_box() -> LootBoxView:
	var box := LootBoxView.new()
	box.position = Vector2(60, 970)
	box.rng.seed = 11
	add_child(box)
	box.set_active(true)
	return box


func _free_box(box: LootBoxView) -> void:
	box.queue_free()
	await get_tree().physics_frame


func _items(ids: Array) -> Array[CraftedItem]:
	var out: Array[CraftedItem] = []
	for id in ids:
		out.append(_piece(id))
	return out


## true si la pieza está dentro de la caja y por debajo del techo (con 2 px de margen).
func _inside(body: LootPiece) -> bool:
	var r := body.bounds()
	return r.position.x >= -2.0 and r.end.x <= LootBoxView.SIZE.x + 2.0 and r.position.y >= LootBoxView.CEIL_Y - 2.0 and r.end.y <= LootBoxView.SIZE.y + 2.0


## El punto más alto de la pila (el menor top_y).
func _highest_top(box: LootBoxView, list: Array) -> float:
	var top := INF
	for item in list:
		top = minf(top, box.body_of(item).top_y())
	return top


func test_pieces_without_a_pose_fall_one_after_another() -> void:
	var box := _new_box()
	var list := _items([&"helmet_basic", &"boots_basic", &"sword_basic"])
	box.sync(list)
	check(box._bodies.is_empty() and box._queue.size() == 3, "sin pose, esperan su turno para caer (%d en cola)" % box._queue.size())
	var frames: int = await _physics_until(func(): return box._bodies.size() == 1, 3 * LootBoxView.SPAWN_INTERVAL)
	check(frames >= LootBoxView.SPAWN_INTERVAL - 1 and box._queue.size() == 2, "la primera entra al cabo de %d pasos (%d)" % [LootBoxView.SPAWN_INTERVAL, frames])
	var first := box.body_of(list[0])
	check(first != null and first.position.y < 0.0, "y cae desde arriba de la caja (y %.0f)" % (first.position.y if first else INF))
	frames = await _physics_until(func(): return box._bodies.size() == 3, 6 * LootBoxView.SPAWN_INTERVAL)  # con margen por si la de arriba aún tapa un intento
	check(frames > 0 and box._queue.is_empty(), "las otras, una tras otra")
	await _free_box(box)


func test_pieces_fall_and_rest_inside_the_box() -> void:
	var box := _new_box()
	var list := _items([&"shield_master", &"sword_masterwork", &"helmet_master", &"boots_master", &"shield_advanced", &"boots_advanced", &"helmet_basic", &"sword_basic"])
	box.sync(list)
	var frames: int = await _physics_until(func(): return box.is_settled(), 1500)
	check(frames > 0, "8 piezas se quedan quietas en menos de 25 s (%d pasos)" % frames)
	check(list.all(func(it): return box.body_of(it) != null and _inside(box.body_of(it))), "todas dentro de la caja y por debajo del techo")
	await _free_box(box)


## Con la caja llena entran fantasmas; al vender las que chocan, los fantasmas vuelven a chocar y se recolocan.
func test_a_full_box_makes_ghosts_and_selling_brings_them_back() -> void:
	var box := _new_box()
	var list: Array[CraftedItem] = []
	for i in 40:
		list.append(_piece(&"shield_master"))  # 2×3 a 55 px: 240 casillas en una caja de unas 190 (con lo de encima del borde)
	box.sync(list)
	var frames: int = await _physics_until(func(): return box.is_settled(), 3000)
	check(frames > 0, "la caja llena se queda quieta (%d pasos)" % frames)
	var ghosts: Array = list.filter(func(it): return box.body_of(it).is_ghost)
	check(ghosts.size() > 0, "con la caja llena hay fantasmas (%d)" % ghosts.size())
	check(_highest_top(box, list) >= LootBoxView.CEIL_Y - 2.0, "nada pasa del techo (%.1f)" % _highest_top(box, list))
	check(ghosts.all(func(it): return is_equal_approx(box.body_of(it).modulate.a, LootPiece.GHOST_ALPHA)), "los fantasmas se ven semitransparentes")
	var keep: Array = ghosts.slice(0, 3)  # se vende todo lo que choca: con 3 escudos sobra sitio
	box.sync(keep)
	frames = await _physics_until(func(): return box.is_settled(), 3000)
	check(frames > 0, "después de vender, la pila vuelve a quedarse quieta (%d pasos)" % frames)
	check(keep.all(func(it): return not box.body_of(it).is_ghost), "los fantasmas vuelven a chocar")
	check(keep.all(func(it): return box.fits(box.body_of(it)) and _inside(box.body_of(it))), "y se recolocan sin solapes, dentro de la caja")
	await _free_box(box)


func test_poses_come_back_where_they_were() -> void:
	var box := _new_box()
	var list := _items([&"shield_master", &"helmet_master", &"boots_advanced", &"sword_masterwork"])
	box.sync(list)
	var frames: int = await _physics_until(func(): return box.is_settled(), 2000)
	check(frames > 0, "la pila se queda quieta (%d pasos)" % frames)
	box.collect_poses()
	check(list.all(func(it): return LootBoxView.pose_is_valid(it.loot_pose)), "cada pieza tiene su pose")
	var copies: Array[CraftedItem] = []
	for it in list:
		copies.append(CraftedItem.from_dict(JSON.parse_string(JSON.stringify(it.to_dict())), it.item_resource))
	await _free_box(box)
	var again := _new_box()
	again.sync(copies)
	check(again._queue.is_empty() and again._bodies.size() == 4, "con pose, todas entran a la vez, sin caer desde arriba")
	await _physics_steps(60)
	var worst := 0.0
	for it in copies:
		worst = maxf(worst, again.body_of(it).position.distance_to(it.loot_pose.pos))
	check(worst < 3.0, "y se quedan donde estaban (lo que más se ha movido: %.2f px)" % worst)
	await _free_box(again)


func test_impossible_poses_fall_from_the_top() -> void:
	var out := _piece(&"helmet_basic")
	out.loot_pose = {"pos": Vector2(5000, 100), "ang": 0.0}  # fuera de la caja
	var high := _piece(&"boots_basic")
	high.loot_pose = {"pos": Vector2(400, -400), "ang": 0.0}  # por encima del techo
	var good := _piece(&"sword_basic")
	good.loot_pose = {"pos": Vector2(200, 384), "ang": 0.0}  # de pie en el suelo (a 55 px: de y 329 a 439)
	check(not LootBoxView.pose_is_valid(out.loot_pose) and not LootBoxView.pose_is_valid(high.loot_pose), "fuera de la caja o por encima del techo no vale")
	check(not LootBoxView.pose_is_valid({}) and not LootBoxView.pose_is_valid({"pos": Vector2(NAN, 0), "ang": 0.0}) and not LootBoxView.pose_is_valid({"pos": Vector2(10, 10), "ang": "x"}), "vacía o sin números tampoco")
	check(LootBoxView.pose_is_valid(good.loot_pose), "dentro sí")
	var box := _new_box()
	box.sync([out, high, good])
	check(box.body_of(good) != null and box.body_of(out) == null and box.body_of(high) == null, "la buena entra en su pose; las imposibles, no")
	check(box._queue.size() == 2 and box._queue[0] == out and box._queue[1] == high, "las imposibles esperan para caer desde arriba")
	var frames: int = await _physics_until(func(): return box._queue.is_empty(), 200)
	check(frames > 0 and [out, high, good].all(func(it): return box.body_of(it) != null and _inside(box.body_of(it))), "y ninguna se pierde")
	await _free_box(box)


func test_overlapping_saved_poses_do_not_explode() -> void:
	var a := _piece(&"shield_advanced")
	var b := _piece(&"shield_advanced")
	for it in [a, b]:
		it.loot_pose = {"pos": Vector2(480, 384), "ang": 0.0}  # las dos en el mismo sitio
	var box := _new_box()
	box.sync([a, b])
	check(not box.body_of(a).is_ghost and box.body_of(b).is_ghost, "la segunda, encima de la primera, entra como fantasma")
	await _physics_steps(120)
	check(_inside(box.body_of(a)) and _inside(box.body_of(b)), "las dos siguen dentro de la caja")
	check(box.body_of(a).position.distance_to(Vector2(480, 384)) < 3.0, "y nadie sale despedido (%s)" % box.body_of(a).position)
	await _free_box(box)


func test_taking_out_a_support_lets_the_pile_fall() -> void:
	var below := _piece(&"shield_advanced")
	var above := _piece(&"helmet_basic")
	below.loot_pose = {"pos": Vector2(480, 384), "ang": 0.0}  # 2×2 en el suelo (a 55 px): de y 329 a 439
	above.loot_pose = {"pos": Vector2(480, 300), "ang": 0.0}  # 1×1 encima: de y 272,5 a 327,5
	var box := _new_box()
	box.sync([below, above])
	var frames: int = await _physics_until(func(): return box.is_settled(), 600)
	check(frames > 0, "la pila de dos se queda quieta (%d pasos)" % frames)
	box.sync([above])  # se vende la de abajo
	frames = await _physics_until(func(): return box.is_settled(), 900)
	check(frames > 0 and box.body_of(above).bounds().end.y > LootBoxView.SIZE.y - 4.0, "la de arriba cae al suelo (fondo en %.1f)" % box.body_of(above).bounds().end.y)
	await _free_box(box)


func test_a_piece_dropped_on_the_pile_rises_until_it_fits() -> void:
	var base := _piece(&"shield_advanced")
	base.loot_pose = {"pos": Vector2(480, 384), "ang": 0.0}
	var dropped := _piece(&"helmet_basic")
	var box := _new_box()
	box.sync([base, dropped])
	box.hold(dropped)
	check(box.is_held(dropped) and box.body_of(dropped) == null and box._queue.is_empty(), "cogida: sin cuerpo y fuera de la cola")
	box.drop_at(dropped, Vector2(480, 384), Vector2.ZERO, 0)  # justo encima del escudo: solaparía
	var body := box.body_of(dropped)
	check(body != null and not box.is_held(dropped), "soltada, vuelve a tener cuerpo")
	check(not body.is_ghost and not box._overlaps(body.rects, body.transform, [body.get_rid()]), "sube hasta no solapar")
	check(body.position.y < 320.0 and is_equal_approx(body.position.x, 480.0), "en la misma columna, encima del escudo (%s)" % body.position)
	await _free_box(box)


func test_a_throw_is_capped_and_keeps_its_turn() -> void:
	check(LootBoxView.cap_throw(Vector2(5000, 0)).is_equal_approx(Vector2(LootBoxView.MAX_THROW_SPEED, 0)), "un gesto rápido se queda en el tope")
	check(LootBoxView.cap_throw(Vector2(100, -50)) == Vector2(100, -50), "uno suave no se toca")
	var sword := _piece(&"sword_advanced")
	var box := _new_box()
	box.sync([sword])
	box.hold(sword)
	box.drop_at(sword, Vector2(480, 200), Vector2(0, -9000), 1)
	var body := box.body_of(sword)
	check(body != null and body.position.is_equal_approx(Vector2(480, 200)), "aparece donde se suelta")
	check(body.linear_velocity.length() <= LootBoxView.MAX_THROW_SPEED + 0.01 and body.linear_velocity.length() > LootBoxView.MAX_THROW_SPEED - 1.0, "con la velocidad del gesto, con tope (%.0f)" % body.linear_velocity.length())
	check(is_equal_approx(body.rotation, PI / 2.0), "y con el giro con que se soltó")
	await _free_box(box)


func test_a_closed_box_does_not_move() -> void:
	var helmet := _piece(&"helmet_basic")
	var box := _new_box()
	box.sync([helmet])
	box.hold(helmet)
	box.drop_at(helmet, Vector2(480, 0), Vector2.ZERO, 0)  # en el aire
	var body := box.body_of(helmet)
	box.set_active(false)
	var p0 := body.position
	await _physics_steps(60)
	check(body.position == p0, "con la caja cerrada no cae (%s → %s)" % [p0, body.position])
	box.set_active(true)
	await _physics_steps(60)
	check(body.position.y > p0.y + 50.0, "al abrirla sigue cayendo (%s)" % body.position)
	await _free_box(box)


func test_a_still_pile_reports_its_poses_at_most_once_a_second() -> void:
	var box := _new_box()
	var at: Array[int] = []
	box.poses_settled.connect(func(): at.append(Engine.get_physics_frames()))
	var list := _items([&"shield_advanced", &"helmet_basic"])
	box.sync(list)
	await _physics_until(func(): return at.size() == 1, 1200)
	check(at.size() == 1, "quieta tras el cambio, avisa una vez (%d)" % at.size())
	check(list.all(func(it): return it.loot_pose.get("pos", Vector2.INF).is_equal_approx(box.body_of(it).position)), "con las poses ya en las piezas")
	box.hold(list[1])
	box.drop_at(list[1], Vector2(700, 300), Vector2.ZERO, 0)
	await _physics_until(func(): return at.size() == 2, 1200)
	check(at.size() == 2 and at[1] - at[0] >= LootBoxView.SAVE_EVERY, "tras otro cambio avisa otra vez, como mucho una vez por segundo (%s)" % [at])
	await _physics_steps(120)
	check(at.size() == 2, "quieta y sin cambios, no avisa más")
	await _free_box(box)


func test_piece_under_a_point_and_its_place_on_screen() -> void:
	var sword := _piece(&"sword_basic")
	sword.loot_pose = {"pos": Vector2(200, 384), "ang": 0.0}  # de pie a 55 px: de x 172,5 a 227,5 y de y 329 a 439
	var box := _new_box()
	box.sync([sword])
	check(box.piece_at(Vector2(200, 400)) == box.body_of(sword) and box.piece_at(Vector2(600, 400)) == null and box.piece_at(Vector2(240, 400)) == null, "dice qué pieza hay bajo un punto, a media escala")
	check(box.rect_global() == Rect2(60, 970, 960, 440), "la caja en la pantalla (%s)" % box.rect_global())
	check(box.piece_global_point(sword).is_equal_approx(box.to_global(Vector2(200, 356.5))), "su primera casilla en la pantalla (%s)" % box.piece_global_point(sword))
	await _free_box(box)
```

- [ ] **Step 2: Ver que falla**

Run: `APPDATA=<appdata> timeout 300 D:/Software/Godot/godot_ver4.5.exe --headless --path . --check-only --script res://scripts/tests/LootBoxTests.gd`
Expected: sale con 1 y `Parse Error: Identifier "LootBoxView" not declared`.

- [ ] **Step 3: `scripts/ui/LootBoxView.gd`**

```gdscript
class_name LootBoxView
extends Node2D

## El botín con física (spec doc/specs/2026-10-02-botin-con-fisica.md): una caja de 960×440 con suelo, paredes y un techo
## invisible 165 px por encima de su borde, y un cuerpo (LootPiece), a media escala (BOX_CELL, 55 px por casilla), por pieza de InventoryManager.loot, que sigue siendo la
## fuente de verdad: sync() crea y quita cuerpos según la lista. Coordenadas: las de este nodo (la esquina de arriba a la
## izquierda de la caja es 0,0; el techo está en y = CEIL_Y). El dedo lo lleva el panel de Equipo, que pasa sus puntos a
## estas coordenadas (to_local), pregunta qué pieza hay debajo (piece_at), la coge (hold) y la suelta (drop_at).
## Entrar en la caja:
##  - con pose guardada válida: aparece en ella, despierta (si la pose solapa a otra, como fantasma);
##  - soltada por el jugador: con su centro de masa en ese punto, con la velocidad del gesto (con tope) y subida lo justo
##    para no solapar;
##  - lo demás (forjado, «Al botín», intercambios, lo que llegó con el panel cerrado): cae desde arriba, una pieza tras otra,
##    tumbada, en una x al azar y con un pequeño giro.
## No cabe (apartado 5): una pieza que, ya quieta, solapa a otra o está apretada contra el techo, o que no encuentra sitio
## bajo el techo para caer, pasa a modo fantasma. Cada segundo, un fantasma que ya no solapa vuelve a chocar donde está; y
## cuando se libera sitio, los fantasmas vuelven a la cola para probar donde están o caer otra vez desde arriba.
## Cerrada (set_active(false)), la caja y sus cuerpos salen de la física: no se mueven ni cuestan nada.

signal poses_settled  ## la pila se ha quedado quieta tras un cambio y sus poses ya están en las piezas

const BOX_CELL := LootPiece.BOX_CELL  ## 55 px por casilla: la escala de las piezas en la caja
const SIZE := Vector2(960, 440)
const CEIL_Y := -165.0  ## techo invisible: 1,5 casillas por encima del borde de la caja
const WALL := 400.0  ## grosor del suelo, las paredes y el techo: que nada los atraviese
const COLOR_BG := Color(0.12, 0.08, 0.07, 0.85)  ## el fondo de la tira de antes; el techo no se dibuja
const MAX_THROW_SPEED := 1400.0  ## px/s: tope de la velocidad del gesto al soltar en la caja
const SPAWN_TILT := 0.3  ## rad: giro inicial máximo de lo que cae desde arriba
const SPAWN_SPIN := 1.5  ## rad/s: velocidad de giro máxima de lo que cae desde arriba
const SPAWN_INTERVAL := 9  ## pasos de física (0,15 s) entre un intento de caída desde arriba y el siguiente
const SPAWN_TRIES := 8  ## x al azar que se prueban en cada intento
const SPAWN_PATIENCE := 120  ## pasos (2 s) esperando sitio bajo el techo antes de entrar como fantasma
const SETTLE_CHECK := 180  ## pasos (3 s): si una pieza que ha entrado aún no se ha dormido, se mira igual si cabe
const CEIL_TOUCH := 3.0  ## px: una pieza quieta así de cerca del techo está apretada contra él
const OVERLAP_MARGIN := BOX_CELL * 0.08  ## px (4,4) que se encoge cada casilla al buscar solapes: el contacto normal no cuenta
const LIFT_STEP := BOX_CELL * 0.25  ## px (un cuarto de casilla de la caja) que sube una pieza soltada sobre otras hasta que no solapa
const GHOST_CHECK := 60  ## pasos (1 s) entre comprobaciones de los fantasmas
const SAVE_EVERY := 60  ## pasos (1 s) como mínimo entre dos avisos de poses
const SLEEP_LINEAR := 8.0  ## px/s: por debajo, una pieza puede dormirse
const SLEEP_ANGULAR := 0.21  ## rad/s (12°)
const SLEEP_TIME := 0.4  ## s quieta antes de dormirse

var active := false
var sprite_for: Callable = Callable(GearArt, "texture_for")
var rng := RandomNumberGenerator.new()
var _bodies: Dictionary = {}  # CraftedItem → LootPiece
var _held: CraftedItem = null  ## la pieza que lleva el dedo: está en el botín pero sin cuerpo
var _queue: Array[CraftedItem] = []  ## esperan para caer desde arriba (o, si ya tienen cuerpo fantasma, para volver a probar)
var _since_spawn := 0
var _blocked := 0  ## pasos que lleva la primera de la cola sin sitio bajo el techo
var _top_full := false  ## no hay sitio bajo el techo: lo que llega entra como fantasma sin esperar, hasta que se libere sitio
var _checks: Dictionary = {}  # LootPiece → pasos desde que entró: falta mirar si cabe
var _space_freed := false
var _ghost_clock := 0
var _dirty := false  ## ha cambiado algo desde el último aviso de poses
var _last_settled_frame := -1000000


func _ready() -> void:
	_build_walls()
	# Reposo: el juego no tiene más cuerpos rígidos, así que el umbral se pone en el espacio del mundo 2D
	var space := get_world_2d().space
	PhysicsServer2D.space_set_param(space, PhysicsServer2D.SPACE_PARAM_BODY_LINEAR_VELOCITY_SLEEP_THRESHOLD, SLEEP_LINEAR)
	PhysicsServer2D.space_set_param(space, PhysicsServer2D.SPACE_PARAM_BODY_ANGULAR_VELOCITY_SLEEP_THRESHOLD, SLEEP_ANGULAR)
	PhysicsServer2D.space_set_param(space, PhysicsServer2D.SPACE_PARAM_BODY_TIME_TO_SLEEP, SLEEP_TIME)
	set_active(active)


func _build_walls() -> void:
	var walls := StaticBody2D.new()
	walls.collision_layer = LootPiece.LAYER_WALLS
	walls.collision_mask = 0
	var tall := SIZE.y - CEIL_Y + 2.0 * WALL
	for r: Rect2 in [
		Rect2(-WALL, SIZE.y, SIZE.x + 2.0 * WALL, WALL),  # suelo
		Rect2(-WALL, CEIL_Y - WALL, WALL, tall),  # pared izquierda
		Rect2(SIZE.x, CEIL_Y - WALL, WALL, tall),  # pared derecha
		Rect2(-WALL, CEIL_Y - WALL, SIZE.x + 2.0 * WALL, WALL),  # techo invisible
	]:
		var cs := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = r.size
		cs.shape = shape
		cs.position = r.get_center()
		walls.add_child(cs)
	add_child(walls)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SIZE), COLOR_BG)

# ═══════════════════════════════════════════════════════════════════
#  LO QUE USA EL PANEL
# ═══════════════════════════════════════════════════════════════════

## Abierta, la caja simula; cerrada, la caja y sus cuerpos salen de la física (spec, apartado 7).
func set_active(on: bool) -> void:
	active = on
	process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED


## Los cuerpos siguen a la lista del botín: quita los de las piezas que ya no están y da entrada a las nuevas (con pose
## válida, en ella; si no, a la cola para caer desde arriba). La pieza cogida no tiene cuerpo.
func sync(list: Array) -> void:
	var changed := false
	for item: CraftedItem in _bodies.keys():
		if not (item in list):
			_remove_body(item)
			changed = true
	if _held and not (_held in list):
		_held = null
		changed = true
	var kept: Array[CraftedItem] = []
	for item in _queue:
		if item in list:
			kept.append(item)
	if kept.size() != _queue.size():
		changed = true
	_queue = kept
	for item: CraftedItem in list:
		if item == _held or _bodies.has(item) or item in _queue:
			continue
		if pose_is_valid(item.loot_pose):
			_restore(item)
		else:
			_queue.append(item)
		changed = true
	if changed:
		_dirty = true


## La coge el dedo: sale de la física (spec, apartado 6). Sigue en el botín.
func hold(item: CraftedItem) -> void:
	if _bodies.has(item):
		_remove_body(item)
	_queue.erase(item)
	_held = item
	_dirty = true


func is_held(item: CraftedItem) -> bool:
	return item != null and item == _held


## Suelta una pieza del botín en la caja: su centro de masa en `local_pos` (coordenadas de la caja, o el punto de la caja
## más cercano), con el giro `rot` (cuartos de vuelta) y la velocidad del gesto, con tope. No hace nada si la pieza no está
## en el botín o ya tiene cuerpo.
func drop_at(item: CraftedItem, local_pos: Vector2, velocity: Vector2, rot: int) -> void:
	if item == _held:
		_held = null
	if item == null or item.place != InventoryManager.PLACE_LOOT or _bodies.has(item):
		return
	_queue.erase(item)
	_enter_at(item, local_pos, velocity, rot)
	_dirty = true


## Pieza bajo un punto (coordenadas de la caja): primero las que chocan (la de más arriba en el dibujo); si no, un fantasma.
func piece_at(local: Vector2) -> LootPiece:
	var ghost: LootPiece = null
	for i in range(get_child_count() - 1, -1, -1):
		var body := get_child(i) as LootPiece
		if body == null or not body.contains_point(local):
			continue
		if not body.is_ghost:
			return body
		if ghost == null:
			ghost = body
	return ghost


func body_of(item: CraftedItem) -> LootPiece:
	return _bodies.get(item)


## Centro de la primera casilla limpia de una pieza, en coordenadas globales (pruebas y capturas). Vector2.INF sin cuerpo.
func piece_global_point(item: CraftedItem) -> Vector2:
	var body := body_of(item)
	return body.to_global(body.rects[0].get_center()) if body else Vector2.INF


## La caja dibujada, en coordenadas globales: donde soltar una pieza la devuelve al botín.
func rect_global() -> Rect2:
	return Rect2(global_position, SIZE)


## true si la pieza cabe donde está (spec, apartado 5): no solapa a ninguna que choca y no está apretada contra el techo.
func fits(body: LootPiece) -> bool:
	var me: Array[RID] = [body.get_rid()]
	return body.top_y() > CEIL_Y + CEIL_TOUCH and not _overlaps(body.rects, body.transform, me)


## true si no queda nada por entrar ni por mirar y todas las piezas duermen.
func is_settled() -> bool:
	if not _queue.is_empty() or not _checks.is_empty():
		return false
	for body: LootPiece in _bodies.values():
		if not body.sleeping:
			return false
	return true


## Deja en cada pieza con cuerpo su pose de ahora (spec, apartado 8).
func collect_poses() -> void:
	for item: CraftedItem in _bodies:
		var body: LootPiece = _bodies[item]
		item.loot_pose = {"pos": body.position, "ang": wrapf(body.rotation, -PI, PI)}


## Una pose guardada vale si sus números son finitos y su centro está dentro de la caja, sin pasar del techo (spec,
## apartado 8). Si no, la pieza cae desde arriba.
static func pose_is_valid(pose: Dictionary) -> bool:
	if not (pose.get("pos") is Vector2) or not (pose.get("ang") is float):
		return false
	var p: Vector2 = pose.pos
	var a: float = pose.ang
	return p.is_finite() and is_finite(a) and p.x >= 0.0 and p.x <= SIZE.x and p.y >= CEIL_Y and p.y <= SIZE.y


## Velocidad del gesto con tope, para que la pieza no salga disparada (spec, apartado 4).
static func cap_throw(v: Vector2) -> Vector2:
	return v.limit_length(MAX_THROW_SPEED)

# ═══════════════════════════════════════════════════════════════════
#  CADA PASO DE FÍSICA
# ═══════════════════════════════════════════════════════════════════

func _physics_process(_delta: float) -> void:
	if _space_freed:
		# Se ha liberado sitio: los fantasmas vuelven a probar, por turno
		_space_freed = false
		for item: CraftedItem in _bodies:
			if _bodies[item].is_ghost and not (item in _queue):
				_queue.append(item)
	_feed_queue()
	_run_checks()
	_ghost_clock += 1
	if _ghost_clock >= GHOST_CHECK:
		_ghost_clock = 0
		for body: LootPiece in _bodies.values():
			if body.is_ghost and fits(body):
				_unghost(body)
	_report_if_settled()


## La primera de la cola entra, cada SPAWN_INTERVAL pasos: cae desde arriba si hay sitio bajo el techo. Un fantasma que
## vuelve a probar se queda donde está si ya cabe ahí. Sin sitio durante SPAWN_PATIENCE pasos (o con la caja ya llena), lo
## nuevo entra como fantasma y el fantasma que probaba sigue de fantasma.
func _feed_queue() -> void:
	_since_spawn += 1
	if _queue.is_empty() or _since_spawn < SPAWN_INTERVAL:
		return
	_since_spawn = 0
	var item: CraftedItem = _queue[0]
	var ghost: LootPiece = _bodies.get(item)
	if ghost and (not ghost.is_ghost or fits(ghost)):
		if ghost.is_ghost:
			_unghost(ghost)
		_next_in_queue()
		return
	var rects := LootPiece.rects_for(item)
	var spot := _find_top_spot(rects)
	if not spot.is_empty():
		if ghost:
			_free_body(item)
		var body := _make_body(item, spot.xform, false)
		body.angular_velocity = rng.randf_range(-SPAWN_SPIN, SPAWN_SPIN)
		_top_full = false
		_next_in_queue()
		return
	_blocked += SPAWN_INTERVAL
	if not _top_full and _blocked < SPAWN_PATIENCE:
		return
	_top_full = true
	if ghost == null:
		_make_body(item, _top_xform(rects, _flat_angle(rects)), true)
	_next_in_queue()


func _next_in_queue() -> void:
	_queue.pop_front()
	_blocked = 0
	_dirty = true


## Cada pieza que ha entrado, ya quieta (o a los SETTLE_CHECK pasos): si no cabe, pasa a modo fantasma.
func _run_checks() -> void:
	for body: LootPiece in _checks.keys():
		_checks[body] = int(_checks[body]) + 1
		if not body.sleeping and int(_checks[body]) < SETTLE_CHECK:
			continue
		_checks.erase(body)
		if not body.is_ghost and not fits(body):
			body.set_ghost(true)
			_dirty = true


func _unghost(body: LootPiece) -> void:
	body.set_ghost(false)
	_checks[body] = 0
	_dirty = true


## Quieta tras un cambio, y como mucho una vez cada SAVE_EVERY pasos: deja las poses en las piezas y avisa.
func _report_if_settled() -> void:
	if not _dirty or not is_settled():
		return
	var frame := Engine.get_physics_frames()
	if frame - _last_settled_frame < SAVE_EVERY:
		return
	_last_settled_frame = frame
	_dirty = false
	collect_poses()
	poses_settled.emit()

# ═══════════════════════════════════════════════════════════════════
#  CUERPOS (privado)
# ═══════════════════════════════════════════════════════════════════

func _make_body(item: CraftedItem, xform: Transform2D, ghost: bool) -> LootPiece:
	var body := LootPiece.new()
	body.setup(item)
	body.sprite_for = sprite_for
	body.transform = xform
	body.set_ghost(ghost)
	add_child(body)
	_bodies[item] = body
	_checks[body] = 0
	return body


## Quita el cuerpo ya: free() lo saca del espacio en el acto, y las consultas de solape de este mismo paso no lo ven.
func _free_body(item: CraftedItem) -> void:
	var body: LootPiece = _bodies[item]
	_bodies.erase(item)
	_checks.erase(body)
	remove_child(body)
	body.free()


## La pieza sale de la caja (vendida, sacada o cogida): queda sitio, y las que se apoyaban en ella se despiertan para caer.
func _remove_body(item: CraftedItem) -> void:
	_free_body(item)
	_space_freed = true
	_top_full = false
	for body: LootPiece in _bodies.values():
		body.sleeping = false


## Pose guardada: aparece en ella, despierta (si se guardó en el aire, cae). Si solapa a otra ya puesta, como fantasma.
func _restore(item: CraftedItem) -> void:
	var xform := Transform2D(float(item.loot_pose.ang), item.loot_pose.pos)
	_make_body(item, xform, _overlaps(LootPiece.rects_for(item), xform))


## Soltada por el jugador: dentro de la caja (el punto más cercano), subida a pasos de LIFT_STEP hasta no solapar. Si
## llega al techo y sigue solapando, entra como fantasma donde se soltó.
func _enter_at(item: CraftedItem, local_pos: Vector2, velocity: Vector2, rot: int) -> void:
	var rects := LootPiece.rects_for(item)
	var angle := float(posmod(rot, 4)) * PI / 2.0
	var ext := LootPiece.extent(rects, angle)
	var start := _clamp_inside(ext, local_pos)
	var top := CEIL_Y - ext.position.y
	var p := start
	while _overlaps(rects, Transform2D(angle, p)) and p.y - LIFT_STEP >= top:
		p.y -= LIFT_STEP
	var ghost := _overlaps(rects, Transform2D(angle, p))
	var body := _make_body(item, Transform2D(angle, start if ghost else p), ghost)
	body.linear_velocity = cap_throw(velocity)


## Centro de masa más cercano a `p` con el que la pieza (de caja girada `ext`) queda entera entre las paredes, el suelo y
## el techo.
func _clamp_inside(ext: Rect2, p: Vector2) -> Vector2:
	return Vector2(clampf(p.x, -ext.position.x, SIZE.x - ext.end.x), clampf(p.y, CEIL_Y - ext.position.y, SIZE.y - ext.end.y))


## Sitio bajo el techo para caer: SPAWN_TRIES intentos, tumbada (_flat_angle) con un giro pequeño y una x al azar, con la
## pieza entera entre las paredes y pegada al techo. {"xform": Transform2D}, o {} si no hay.
func _find_top_spot(rects: Array[Rect2]) -> Dictionary:
	var flat := _flat_angle(rects)
	for i in SPAWN_TRIES:
		var xform := _top_xform(rects, flat + rng.randf_range(-SPAWN_TILT, SPAWN_TILT))
		if not _overlaps(rects, xform):
			return {"xform": xform}
	return {}


## Cuarto de vuelta (en radianes) con el que la pieza es más baja, como se tumbaba en la tira: así cae ocupando poca altura
## bajo el techo y cabe mientras la pila no llega arriba. El primero si empatan.
static func _flat_angle(rects: Array[Rect2]) -> float:
	var best := 0.0
	var best_h := INF
	for k in 4:
		var h := LootPiece.extent(rects, float(k) * PI / 2.0).size.y
		if h < best_h - 0.5:
			best_h = h
			best = float(k) * PI / 2.0
	return best


## Pose de caída desde arriba con giro `angle`: x al azar sin tocar las paredes y el punto más alto 1 px bajo el techo.
func _top_xform(rects: Array[Rect2], angle: float) -> Transform2D:
	var ext := LootPiece.extent(rects, angle)
	return Transform2D(angle, Vector2(rng.randf_range(-ext.position.x, SIZE.x - ext.end.x), CEIL_Y - ext.position.y + 1.0))


## true si unas casillas (rects de LootPiece) en `xform` (coordenadas de la caja) pisan alguna pieza que choca. Cada casilla
## se encoge OVERLAP_MARGIN por lado: tocarse no cuenta.
func _overlaps(rects: Array[Rect2], xform: Transform2D, exclude: Array[RID] = []) -> bool:
	var space := get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(BOX_CELL, BOX_CELL) - Vector2.ONE * 2.0 * OVERLAP_MARGIN
	query.shape = shape
	query.collision_mask = LootPiece.LAYER_PIECES
	query.exclude = exclude
	for r in rects:
		query.transform = global_transform * xform * Transform2D(0.0, r.get_center())
		if not space.intersect_shape(query, 1).is_empty():
			return true
	return false
```

- [ ] **Step 4: Ver que pasa**

Run: `APPDATA=<appdata> timeout 300 D:/Software/Godot/godot_ver4.5.exe --headless --path . --import` y después `APPDATA=<appdata> timeout 300 D:/Software/Godot/godot_ver4.5.exe --headless --fixed-fps 60 --path . res://scenes/tests/LootBoxTests.tscn`
Expected: `[LootBoxTests] N comprobaciones, 0 fallos`, código 0.
Si una prueba de «quieta a tiempo» falla por poco, mira primero si alguna pieza tiembla (imprime `linear_velocity` de las despiertas): sube `LINEAR_DAMP` o `ANGULAR_DAMP` de `LootPiece` antes de subir los topes de pasos.

- [ ] **Step 5: Commit**

```bash
git status --short
git add scripts/ui/LootBoxView.gd scripts/ui/LootBoxView.gd.uid scripts/tests/LootBoxTests.gd
git commit -m "feat: caja del botín con física (LootBoxView): entradas, techo, modo fantasma, congelar y poses"
```

---

### Task 5: El panel de Equipo con la caja

**Files:**
- Modify: `scenes/UI/EquipmentPanel.tscn` (nodos `BagIcon`, `BagTitle` y `SellZone`)
- Modify: `scripts/ui/EquipmentPanel.gd` (cabecera, constantes, variables, `_build`, `open`, `close`, `_refresh`, el dedo y `_drop`)
- Modify: `scripts/tests/InventoryGridTests.gd` (pruebas del panel que usaban la tira)
- Modify: `scripts/tests/VisualCapture.gd` (`_run_inventory_plan`)
- Test: `scripts/tests/LootBoxTests.gd`

**Interfaces:**
- Consumes: todo `LootBoxView` (tarea 4); `LootPiece.straight_rot()`, `LootPiece.item`, `LootPiece.is_ghost`; `PieceShape.mass_center`; `InventoryManager.note_loot_poses()` (tarea 2).
- Produces (las pruebas y la tarea 6 los usan):
  - `EquipmentPanel.LOOT_RECT := Rect2(60, 970, 960, 440)`, `BAG_POS := Vector2(60, 1460)`, `DRAG_CELL := CELL` (110: tamaño de la pieza arrastrada), `THROW_WINDOW_US := 100000`, `THROW_MIN_US := 10000`;
  - `_loot_box: LootBoxView` (sustituye a `_loot_view`; ya no existen `_loot_view`, `_scrolling` ni `_scroll_start`);
  - `_drag_trail: Array` (`[[posición: Vector2, µs: int], …]`), `_throw_velocity() -> Vector2`, `_box_hit(body: LootPiece) -> Dictionary`;
  - `_press` de una pieza de la caja: `{"item", "from": &"loot", "rot": straight_rot(), "origin"}`, con `origin + mass_center(of_item(item, rot), DRAG_CELL)` = centro del cuerpo en pantalla: la pieza crece a 110 alrededor de su centro de masa.
  - `InventoryGridTests`: ayudas `_in_box(item, x, angle = 0.0)` y `_box_point(panel, item) -> Vector2`.
  - `LootBoxTests`: ayudas `_new_panel()`, `_mouse()`, `_move()`, `_finger_for()`, `_in_box()`, `_long_press()`, `_silence_sounds()`.

- [ ] **Step 1: Pruebas del panel que fallan (LootBoxTests)**

Añade al final de `scripts/tests/LootBoxTests.gd`:

```gdscript


# ─── Tarea 5: el panel de Equipo con la caja ───────────────────────────

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


## Dónde poner el dedo para que la pieza cogida caiga con su caja en `cell` de `view` (va una casilla por encima del dedo).
func _finger_for(panel: Control, view: Control, cell: Vector2i) -> Vector2:
	var grab: Vector2 = panel._press.origin - panel._press.pos
	return view.global_position + Vector2(cell) * CELL - grab + Vector2(0, CELL)


## Deja una pieza del botín apoyada en el suelo de la caja, en la x dada (px de la caja) y con ese ángulo: con pose, la
## caja la pone ahí al abrir el panel, sin esperar a que caiga desde arriba.
func _in_box(item: CraftedItem, x: float, angle: float = 0.0) -> void:
	var fp := PieceShape.of_item(item, posmod(roundi(angle / (PI / 2.0)), 4))
	var com := PieceShape.mass_center(fp, LootBoxView.BOX_CELL)
	item.loot_pose = {"pos": Vector2(x, LootBoxView.SIZE.y - float(fp.size.y) * LootBoxView.BOX_CELL + com.y - 1.0), "ang": angle}


func _long_press(panel: Control, pos: Vector2) -> void:
	_mouse(panel, pos, true)
	panel._press.time = Time.get_ticks_msec() - 1000  # como si llevara 1 s pulsada
	panel._process(0.0)


## Calla las voces de AudioManager: el clinc de colocar una pieza en Tico seguiría sonando al acabar la suite.
func _silence_sounds() -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am:
		for voice in am.get_children():
			if voice is AudioStreamPlayer:
				voice.stop()
	await get_tree().create_timer(0.1).timeout


func test_the_panel_makes_room_for_the_box() -> void:
	var panel := _new_panel()
	check(panel._loot_box.rect_global() == Rect2(60, 970, 960, 440), "la caja mide 960×440 desde y = 970 (%s)" % panel._loot_box.rect_global())
	check(panel._bag_view.global_position == Vector2(60, 1460), "la mochila baja a y = 1460 (%s)" % panel._bag_view.global_position)
	check(panel.sell_zone.get_global_rect() == Rect2(760, 1460, 260, 440), "y la zona de venta con ella (%s)" % panel.sell_zone.get_global_rect())
	check(panel.get_node("BagIcon").position.y == 1410.0 and panel.get_node("BagTitle").position.y == 1416.0, "el título de la mochila, con su icono, entre la caja y la mochila")
	check(not ("_scrolling" in panel) and not ("_loot_view" in panel), "sin la tira ni su desplazamiento")
	panel.queue_free()
	await get_tree().process_frame


func test_grabbing_a_box_piece_straightens_it() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var sword := _piece(&"sword_advanced")  # 1×3
	im.add_crafted_item(sword)
	sword.loot_pose = {"pos": Vector2(480, 200), "ang": 1.3}  # torcida, casi tumbada
	var panel := _new_panel()
	var box: LootBoxView = panel._loot_box
	check(box.body_of(sword) != null and is_equal_approx(box.body_of(sword).rotation, 1.3), "la espada está en la caja con su ángulo")
	var start := box.piece_global_point(sword)
	_mouse(panel, start, true)
	check(panel._press.get("item") == sword and panel._press.get("rot") == 1, "al cogerla se endereza al cuarto de vuelta más cercano (%s)" % [panel._press.get("rot")])
	check(box.body_of(sword).rects.all(func(r): return r.size == Vector2(55, 55)), "en la caja choca a media escala: 55 px por casilla")
	var com := PieceShape.mass_center(PieceShape.of_item(sword, 1), panel.DRAG_CELL)
	check(is_equal_approx(panel.DRAG_CELL, 110.0) and (panel._press.origin + com).is_equal_approx(box.to_global(Vector2(480, 200))), "cogida, crece a 110 px por casilla alrededor de su centro de masa")
	_move(panel, start + Vector2(0, -40))
	check(panel._dragging and panel._drag_rot == 1 and box.is_held(sword) and box.body_of(sword) == null, "arrastrada, sale de la física y la lleva el dedo")
	var full: Vector2 = Vector2(PieceShape.of_item(sword, 1).size) * panel.DRAG_CELL
	check(full == Vector2(330, 110), "la pieza arrastrada mide lo que en la rejilla (%s)" % full)
	_move(panel, Vector2(540, 60))  # arriba del todo, fuera de las rejillas y de la caja
	_mouse(panel, Vector2(540, 60), false)
	var back := box.body_of(sword)
	check(sword.place == &"loot" and back != null and not box.is_held(sword), "soltada fuera de todo, vuelve a la caja")
	check(back.position.is_equal_approx(Vector2(480, LootBoxView.CEIL_Y + 27.5)) and is_equal_approx(back.rotation, PI / 2.0), "al punto de la caja más cercano al dedo, bajo el techo (%s)" % back.position)
	check(back.rects.all(func(r): return r.size == Vector2(55, 55)), "y vuelve a media escala")
	panel.queue_free()
	await _restore_inventory(saved)


func test_dropping_in_the_box_throws_with_the_gesture() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var helmet := _piece(&"helmet_basic")
	im.add_crafted_item(helmet)
	_in_box(helmet, 200.0)
	var panel := _new_panel()
	var box: LootBoxView = panel._loot_box
	var start := box.piece_global_point(helmet)
	_mouse(panel, start, true)
	_move(panel, start + Vector2(0, -40))
	var finger := box.to_global(Vector2(600, 300))
	_move(panel, finger)
	check(panel._target.get("place") == &"loot", "sobre la caja, el destino es el botín (%s)" % [panel._target])
	var center: Vector2 = panel._ghost_origin() + PieceShape.mass_center(PieceShape.of_item(helmet, 0), panel.DRAG_CELL)
	var now := Time.get_ticks_usec()
	panel._drag_trail = [[finger - Vector2(300, 0), now - 50000], [finger, now]]  # 6000 px/s hacia la derecha
	_mouse(panel, finger, false)
	var body := box.body_of(helmet)
	check(body != null and body.position.is_equal_approx(box.to_local(center)), "entra donde se veía la pieza, una casilla por encima del dedo")
	check(body.linear_velocity.x > 1000.0 and body.linear_velocity.length() <= LootBoxView.MAX_THROW_SPEED + 0.5, "con la inercia del gesto, con tope (%s)" % body.linear_velocity)
	panel.queue_free()
	await _restore_inventory(saved)


func test_a_piece_from_the_grid_lands_where_it_is_dropped() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var helmet := _piece(&"helmet_basic")
	im.add_crafted_item(helmet)
	im.move_item(helmet, &"hero", Vector2i(0, 0), 0)
	var panel := _new_panel()
	var box: LootBoxView = panel._loot_box
	var start: Vector2 = panel._hero_view.global_position + Vector2(55, 55)
	_mouse(panel, start, true)
	_move(panel, start + Vector2(30, 30))
	var finger := box.to_global(Vector2(480, 300))
	_move(panel, finger)
	_mouse(panel, finger, false)
	var body := box.body_of(helmet)
	check(helmet.place == &"loot" and body != null and box._queue.is_empty(), "sale de Tico y entra en la caja sin caer desde arriba")
	check(body.position.is_equal_approx(Vector2(480, 190)), "donde se soltó: una casilla por encima del dedo (%s)" % body.position)
	panel.queue_free()
	await _restore_inventory(saved)


func test_a_swap_sends_the_other_piece_from_the_top() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var old_sword := _piece(&"sword_basic", 0.5)
	var new_sword := _piece(&"sword_basic", 0.95)
	im.add_crafted_item(old_sword)
	im.move_item(old_sword, &"hero", Vector2i(3, 0), 0)  # de pie en (3,0)-(3,1)
	im.add_crafted_item(new_sword)
	_in_box(new_sword, 300.0, PI / 2.0)  # tumbada en la caja
	var panel := _new_panel()
	var box: LootBoxView = panel._loot_box
	var start := box.piece_global_point(new_sword)
	_mouse(panel, start, true)
	_move(panel, start + Vector2(0, -30))
	var finger := _finger_for(panel, panel._hero_view, Vector2i(2, 0))  # tumbada: (2,0)-(3,0), encima de la vieja
	_move(panel, finger)
	_mouse(panel, finger, false)
	check(new_sword.place == &"hero" and old_sword.place == &"loot", "se intercambian")
	check(box.body_of(old_sword) == null and box._queue.has(old_sword), "la vieja espera su turno para caer desde arriba")
	var frames: int = await _physics_until(func(): return box.body_of(old_sword) != null, 3 * LootBoxView.SPAWN_INTERVAL)
	check(frames > 0 and box.body_of(old_sword).position.y < 0.0, "y cae desde arriba de la caja")
	await _silence_sounds()
	panel.queue_free()
	await _restore_inventory(saved)


func test_tap_and_long_press_on_a_box_piece() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var helmet := _piece(&"helmet_advanced", 1.0)
	im.add_crafted_item(helmet)
	_in_box(helmet, 400.0)
	var panel := _new_panel()
	var box: LootBoxView = panel._loot_box
	var p := box.piece_global_point(helmet)
	_mouse(panel, p, true)
	_mouse(panel, p, false)
	check(panel._selected == helmet and box.body_of(helmet) != null and not box.is_held(helmet), "tocarla la enseña en la ficha, sin sacarla de la caja")
	_long_press(panel, p)
	check(panel._card.visible and panel._card_item == helmet and box.body_of(helmet) != null, "mantenerla pulsada abre su ficha completa")
	_mouse(panel, p, false)
	panel.queue_free()
	await _restore_inventory(saved)


func test_closing_mid_drag_returns_the_piece_to_the_box() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var gm := get_node("/root/GameManager")
	var helmet := _piece(&"helmet_basic")
	im.add_crafted_item(helmet)
	_in_box(helmet, 200.0)
	var panel := _new_panel()
	var box: LootBoxView = panel._loot_box
	var start := box.piece_global_point(helmet)
	_mouse(panel, start, true)
	_move(panel, start + Vector2(0, -40))
	_move(panel, box.to_global(Vector2(700, 300)))
	check(box.is_held(helmet), "el casco va en el dedo")
	gm.save_writer = Callable(self, "_count_save_write")
	_save_writes = 0
	panel.close()  # Atrás con la pieza en el dedo
	var body := box.body_of(helmet)
	check(not box.active and not box.is_held(helmet) and body != null, "vuelve a la caja, que se congela")
	check(body.position.is_equal_approx(Vector2(700, 300)) and LootBoxView.pose_is_valid(helmet.loot_pose), "al punto más cercano al dedo, con su pose recogida (%s)" % body.position)
	var p0 := body.position
	await _physics_steps(30)
	check(body.position == p0, "con el panel cerrado no se mueve")
	for i in 2:
		await get_tree().process_frame
	check(_save_writes >= 1, "y la pose se guarda (%d)" % _save_writes)
	gm.save_writer = Callable()
	panel.queue_free()
	await _restore_inventory(saved)


func test_new_loot_while_holding_a_box_piece() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var helmet := _piece(&"helmet_basic")
	im.add_crafted_item(helmet)
	_in_box(helmet, 200.0)
	var panel := _new_panel()
	var box: LootBoxView = panel._loot_box
	var start := box.piece_global_point(helmet)
	_mouse(panel, start, true)
	_move(panel, start + Vector2(0, -40))
	var fresh := _piece(&"boots_basic")
	im.add_crafted_item(fresh)  # llega de la forja a mitad del arrastre
	check(box.is_held(helmet) and box.body_of(helmet) == null, "la pieza cogida no reaparece en la caja")
	check(box._queue.has(fresh) and not box._queue.has(helmet), "la nueva espera para caer desde arriba")
	_move(panel, Vector2(540, 60))
	_mouse(panel, Vector2(540, 60), false)
	var frames: int = await _physics_until(func(): return box.body_of(fresh) != null, 6 * LootBoxView.SPAWN_INTERVAL)
	check(frames > 0 and box.body_of(helmet) != null and box._bodies.size() == 2, "al final, un cuerpo cada una")
	panel.queue_free()
	await _restore_inventory(saved)


func test_selling_an_epic_from_the_box_waits_in_the_box() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var epic := _piece(&"helmet_basic", 0.95)
	im.add_crafted_item(epic)
	_in_box(epic, 800.0)
	var panel := _new_panel()
	var box: LootBoxView = panel._loot_box
	var start := box.piece_global_point(epic)
	_mouse(panel, start, true)
	_move(panel, start + Vector2(0, 40))
	var sell_point: Vector2 = panel.sell_zone.get_global_rect().get_center()
	_move(panel, sell_point)
	_mouse(panel, sell_point, false)
	check(panel._confirm_box.visible and epic in im.get_crafted_items(), "la épica pide confirmación")
	check(box.body_of(epic) != null and not box.is_held(epic), "mientras, vuelve a la caja")
	panel._on_confirm_yes()
	check(not (epic in im.get_crafted_items()) and box.body_of(epic) == null, "al confirmar se vende y su cuerpo se va")
	await _silence_sounds()
	panel.queue_free()
	await _restore_inventory(saved)
```

- [ ] **Step 2: Ver que fallan**

Run: `APPDATA=<appdata> timeout 300 D:/Software/Godot/godot_ver4.5.exe --headless --fixed-fps 60 --path . res://scenes/tests/LootBoxTests.tscn`
Expected: código 1. Fallan las pruebas nuevas: `_loot_box` no existe en el panel (`Invalid access to property or key '_loot_box'`, que `TestSuite` cuenta como fallo de cada prueba).

- [ ] **Step 3: Escena: mochila y zona de venta más abajo**

En `scenes/UI/EquipmentPanel.tscn` sustituye los nodos `BagIcon`, `BagTitle` y `SellZone` (no toques el resto, ni el uid de la cabecera) por:

```
[node name="BagIcon" type="TextureRect" parent="."]
offset_left = 56.0
offset_top = 1410.0
offset_right = 108.0
offset_bottom = 1462.0
mouse_filter = 2
texture = ExtResource("bag_icon")

[node name="BagTitle" type="Label" parent="."]
offset_left = 112.0
offset_top = 1416.0
offset_right = 700.0
offset_bottom = 1456.0
theme_override_font_sizes/font_size = 30
text = "Mochila"

[node name="SellZone" type="Panel" parent="."]
offset_left = 760.0
offset_top = 1460.0
offset_right = 1020.0
offset_bottom = 1900.0
mouse_filter = 2
```

- [ ] **Step 4: `EquipmentPanel.gd`: cabecera, constantes y variables**

Sustituye las líneas 4 a 18 (el comentario de cabecera, de `## Panel de Equipo a pantalla completa` a `## confirmación, si no la ficha y, si no, el panel (ver _back).`) por:

```gdscript
## Panel de Equipo a pantalla completa (spec doc/specs/2026-09-27-inventario-en-rejilla.md, apartado 9, y
## doc/specs/2026-10-02-botin-con-fisica.md). De arriba abajo: estadísticas de Tico, ficha de la última pieza tocada, rejilla
## de Tico delante de su sprite (con los consumibles al lado), la caja del botín con física, mochila y zona de venta.
## El dedo lo lleva este panel, en _input:
##  - tocar una pieza de una rejilla la gira (si girada no cabe, tiembla); en la caja solo la enseña;
##  - mantener pulsado abre su ficha completa, con los botones A la mochila, Al botín, Vender y Cerrar;
##  - arrastrar la mueve: la pieza va una casilla por encima del dedo y un segundo dedo la gira. Una pieza de la caja sale
##    de la física al cogerla, enderezada al cuarto de vuelta más cercano;
##  - soltarla en la zona de venta la vende (las Épicas y Legendarias piden confirmación);
##  - soltarla en la caja la devuelve a la física donde se ve, con la inercia del gesto. Una pieza de la caja soltada fuera
##    de todo (o con la venta por confirmar, o al cerrar el panel) vuelve a la caja, al punto más cercano al dedo;
##  - en un hueco de consumibles, tocar enseña la poción en la ficha y mantener pulsado ofrece venderla (la pulsación larga
##    termina la pulsación, como la de una pieza).
## En el ordenador el ratón hace lo mismo, y la rueda o la tecla R giran la pieza que se arrastra.
## Atrás (Android) llega como NOTIFICATION_WM_GO_BACK_REQUEST, no como tecla, y el árbol cierra el juego si
## quit_on_go_back es true: mientras el panel está abierto lo apaga. Atrás y Escape cierran lo de más arriba: la
## confirmación, si no la ficha y, si no, el panel (ver _back).
## Con el panel cerrado la caja se congela; al cerrarlo se recogen las poses del botín y se guardan.
```

Sustituye las constantes `BAG_POS` y `LOOT_RECT` por:

```gdscript
const BAG_POS := Vector2(60, 1460)
## La caja del botín (LootBoxView.SIZE); su techo invisible queda 165 px más arriba
const LOOT_RECT := Rect2(60, 970, 960, 440)
```

Tras `const LONG_PRESS_MS := 400`, añade:

```gdscript
## La pieza que se arrastra va siempre a tamaño completo (110 px por casilla), también la que sale de la caja, donde está a
## media escala (LootBoxView.BOX_CELL): al cogerla crece alrededor de su centro de masa y al soltarla en la caja encoge
const DRAG_CELL := CELL
const THROW_WINDOW_US := 100000  ## el gesto que lanza la pieza: lo que se ha movido el dedo en los últimos 0,1 s
const THROW_MIN_US := 10000  ## con menos de 0,01 s de gesto no se mide la velocidad: se suelta sin lanzar
```

Sustituye `var _loot_view: LootStripView` por `var _loot_box: LootBoxView`.

Sustituye el comentario de `_press` y las variables de la pulsación (de `## Pulsación en curso:` a `var _drag_pos := Vector2.ZERO`) por:

```gdscript
## Pulsación en curso: {"item", "from", "rot", "origin", "pos", "time"}; {} si no hay.
## "origin" es la esquina de la caja de la pieza en la pantalla al pulsar (en la caja, ya enderezada: ver _box_hit). La
## pulsación larga la termina (abre la ficha).
## En un hueco de consumibles: {"slot", "item": null, "from": &"slot", "pos", "time"}.
var _press := {}
var _dragging := false
var _drag_rot := 0
var _drag_pos := Vector2.ZERO
var _drag_trail: Array = []  ## [[posición, µs], …] del dedo durante el arrastre: la inercia del gesto al soltar en la caja
```

- [ ] **Step 5: `_build`, `open`, `close` y `_refresh`**

En `_build`, sustituye las cinco líneas de `_loot_view = LootStripView.new()` a `add_child(_loot_view)` por:

```gdscript
	_loot_box = LootBoxView.new()
	_loot_box.position = LOOT_RECT.position
	add_child(_loot_box)  # después de la rejilla de Tico: la pila que rebosa se dibuja encima de sus últimas filas
	_loot_box.poses_settled.connect(_on_poses_settled)
```

Sustituye `open` y `close` por:

```gdscript
func open() -> void:
	if is_node_ready():
		_loot_box.set_active(true)  # antes de cancelar: una pieza de la caja que se arrastraba vuelve a la física
		# Por si algo ocultó el panel sin pasar por close(): ni arrastre, ni ficha, ni confirmación de la vez anterior
		_cancel_press()
		_close_card()
		_close_confirm()
	visible = true
	_hold_go_back()
	_refresh()
	if _puppet:
		_puppet.process_mode = Node.PROCESS_MODE_INHERIT
		_puppet.respawn(_puppet.position)


func close() -> void:
	_cancel_press()  # una pieza de la caja que iba en el dedo vuelve a ella
	_close_card()
	_close_confirm()
	# La caja se congela con el panel cerrado; antes, cada pieza guarda su pose (spec del botín con física, apartados 7 y 8)
	_loot_box.collect_poses()
	_loot_box.set_active(false)
	if _im:
		_im.note_loot_poses()
	visible = false
	_release_go_back()
	if _puppet:
		_puppet.process_mode = Node.PROCESS_MODE_DISABLED
	emit_signal("panel_closed")


## La pila se ha quedado quieta: sus poses ya están en las piezas y se guardan con el guardado diferido de siempre.
func _on_poses_settled() -> void:
	if _im:
		_im.note_loot_poses()
```

En `_refresh`, sustituye `_loot_view.set_items(_im.get_loot())` por `_loot_box.sync(_im.get_loot())`.

- [ ] **Step 6: El dedo: coger de la caja, sin desplazamiento, lanzar y volver a la caja**

En `_on_press`, borra las dos líneas `_scrolling = false` y `_scroll_start = _loot_view.scroll`.

Sustituye `_piece_at` por:

```gdscript
## Pieza bajo un punto de la pantalla: {"item", "from", "rot", "origin"}, o {} si no hay nada que coger. Manda la pieza de la
## caja que choca (se dibuja encima de las últimas filas de Tico cuando la pila rebosa); después las rejillas; un fantasma
## de la caja, el último.
func _piece_at(pos: Vector2) -> Dictionary:
	var body := _loot_box.piece_at(_loot_box.to_local(pos))
	if body and not body.is_ghost:
		return _box_hit(body)
	for view in [_hero_view, _bag_view]:
		var local: Vector2 = pos - view.global_position
		if Rect2(Vector2.ZERO, view.size).has_point(local):
			var item: CraftedItem = view.item_at_local(local)
			if item:
				return {"item": item, "from": item.place, "rot": item.rot, "origin": view.global_position + view.item_origin(item)}
	if body:
		return _box_hit(body)
	return {}


## Una pieza de la caja como pulsación: enderezada al cuarto de vuelta más cercano y a tamaño completo (spec, apartado 6),
## con la esquina de su caja (a DRAG_CELL) donde queda su centro de masa ahora mismo: crece alrededor de él.
func _box_hit(body: LootPiece) -> Dictionary:
	var rot := body.straight_rot()
	var com := PieceShape.mass_center(PieceShape.of_item(body.item, rot), DRAG_CELL)
	return {"item": body.item, "from": InventoryManager.PLACE_LOOT, "rot": rot, "origin": _loot_box.to_global(body.position) - com}
```

Sustituye `_on_motion` por:

```gdscript
func _on_motion(pos: Vector2) -> void:
	if _press.is_empty():
		return
	if _press.has("slot"):
		return  # un hueco solo se toca o se mantiene: el dedo no lo arrastra
	get_viewport().set_input_as_handled()
	if _dragging:
		_drag_pos = pos
		_note_trail(pos)
		_update_target()
		return
	var moved: Vector2 = pos - _press.pos
	if moved.length() < DRAG_THRESHOLD:
		return
	_dragging = true
	_drag_rot = int(_press.rot)
	_drag_pos = pos
	_drag_trail.clear()
	_note_trail(pos)
	if _press.from == InventoryManager.PLACE_LOOT:
		_loot_box.hold(_press.item)  # sale de la física: la lleva el dedo
	_set_hidden(_press.item)
	_update_target()


## Guarda por dónde pasa el dedo, solo lo de los últimos THROW_WINDOW_US.
func _note_trail(pos: Vector2) -> void:
	var now := Time.get_ticks_usec()
	_drag_trail.append([pos, now])
	while _drag_trail.size() > 2 and now - int(_drag_trail[0][1]) > THROW_WINDOW_US:
		_drag_trail.pop_front()


## Velocidad del gesto al soltar (px/s, coordenadas del panel = de la caja): lo que se movió el dedo en los últimos 0,1 s.
## Sin muestras suficientes, cero: la pieza se suelta sin lanzarla. El tope lo pone la caja.
func _throw_velocity() -> Vector2:
	if _drag_trail.size() < 2:
		return Vector2.ZERO
	var first: Array = _drag_trail[0]
	var last: Array = _drag_trail[-1]
	var dt_us := int(last[1]) - int(first[1])
	if dt_us < THROW_MIN_US:
		return Vector2.ZERO
	return (Vector2(last[0]) - Vector2(first[0])) / (float(dt_us) / 1000000.0)
```

En `_on_release`, sustituye `elif not _scrolling and item:` por `elif item:`.

En `_process`, sustituye `if _press.is_empty() or _dragging or _scrolling:` por `if _press.is_empty() or _dragging:`, y `elif _press.item:  # el botín vacío no tiene ficha: solo se desplaza` por `elif _press.item:` (ya no hay pulsaciones del botín vacío).

Sustituye `_cancel_press` por:

```gdscript
func _cancel_press() -> void:
	# Una pieza de la caja soltada fuera de todo, con la venta por confirmar o al cerrar el panel vuelve a la caja, al
	# punto más cercano al dedo (spec, apartado 6)
	var held: CraftedItem = _press.get("item")
	if held and _loot_box.is_held(held):
		_loot_box.drop_at(held, _loot_box.to_local(_drag_pos), Vector2.ZERO, _drag_rot)
	_press = {}
	_dragging = false
	_target = {}
	_drag_trail.clear()
	_set_hidden(null)
	_clear_highlights()
	sell_label.text = tr("Suelta aquí para vender")
	sell_zone.modulate = Color.WHITE
	if _im and is_node_ready():
		_refresh_stats({})
	_ghost_layer.queue_redraw()
```

Sustituye `_set_hidden` por:

```gdscript
## La pieza que se arrastra no se dibuja en su rejilla (en la caja ya no tiene cuerpo).
func _set_hidden(item: CraftedItem) -> void:
	_hero_view.hidden_item = item
	_bag_view.hidden_item = item
	_hero_view.queue_redraw()
	_bag_view.queue_redraw()
```

En `_draw_ghost`, sustituye `_ghost_origin(), _drag_rot, CELL, 0.85` por `_ghost_origin(), _drag_rot, DRAG_CELL, 0.85`: la pieza arrastrada se dibuja a 110 px por casilla, venga de donde venga.

En `_update_target`, sustituye `if t.is_empty() and _loot_view.get_global_rect().has_point(_drag_pos):` por `if t.is_empty() and _loot_box.rect_global().has_point(_drag_pos):`, y en su comentario `Si no hay ninguna, el botín, por el dedo.` por `Si no hay ninguna, la caja del botín, por el dedo.`

Sustituye `_drop` por:

```gdscript
func _drop(item: CraftedItem) -> void:
	if _target.is_empty() or not _target.get("ok", false):
		return  # vuelve a su sitio (una pieza de la caja, a la caja: _cancel_press)
	if _target.place == &"sell":
		_sell(item)
		return
	var place: StringName = _target.place
	var from_place := item.place
	var from_cell := item.cell
	var from_rot := item.rot
	if _im.move_item(item, place, _target.get("cell", Vector2i.ZERO), _drag_rot):
		if place == InventoryManager.PLACE_LOOT:
			# Entra en la caja donde se ve la pieza (una casilla por encima del dedo), con la inercia del gesto; su centro de masa
			# se queda ahí y la caja la encoge a media escala alrededor de él
			var center := _ghost_origin() + PieceShape.mass_center(PieceShape.of_item(item, _drag_rot), DRAG_CELL)
			_loot_box.drop_at(item, _loot_box.to_local(center), _throw_velocity(), _drag_rot)
		_selected = item
		_refresh_ficha()  # el aviso del movimiento llega antes de elegirla
		# Soltarla donde ya estaba vale, pero no mueve nada: ni clinc ni materialización
		var moved := item.place != from_place or item.cell != from_cell or item.rot != from_rot
		if moved and place == InventoryManager.PLACE_HERO:
			Sfx.play(&"equip_clink")
			if _puppet:
				_puppet.set("_materialize", 0.55)
```

Comprueba que no queda ninguna referencia a la tira: `git grep -n "_loot_view\|_scrolling\|_scroll_start\|LootStripView" scripts/ui/EquipmentPanel.gd` no imprime nada.

- [ ] **Step 7: Ver que pasan las del panel**

Run: `APPDATA=<appdata> timeout 300 D:/Software/Godot/godot_ver4.5.exe --headless --fixed-fps 60 --path . res://scenes/tests/LootBoxTests.tscn`
Expected: `[LootBoxTests] N comprobaciones, 0 fallos`.

- [ ] **Step 8: Adaptar `InventoryGridTests` a la caja**

Run antes: `APPDATA=<appdata> timeout 300 D:/Software/Godot/godot_ver4.5.exe --headless --path . res://scenes/tests/InventoryGridTests.tscn`
Expected: código 1, con fallos en las pruebas que usaban `_loot_view`.

En `scripts/tests/InventoryGridTests.gd`, tras la función `_finger_for`, añade:

```gdscript


## Deja una pieza del botín apoyada en el suelo de la caja, en la x dada (px de la caja) y con ese ángulo: con pose, la
## caja la pone ahí al abrir el panel, sin esperar a que caiga desde arriba.
func _in_box(item: CraftedItem, x: float, angle: float = 0.0) -> void:
	var fp := PieceShape.of_item(item, posmod(roundi(angle / (PI / 2.0)), 4))
	var com := PieceShape.mass_center(fp, LootBoxView.BOX_CELL)
	item.loot_pose = {"pos": Vector2(x, LootBoxView.SIZE.y - float(fp.size.y) * LootBoxView.BOX_CELL + com.y - 1.0), "ang": angle}


## Dónde pulsar una pieza de la caja: el centro de su primera casilla limpia.
func _box_point(panel: Control, item: CraftedItem) -> Vector2:
	return panel._loot_box.piece_global_point(item)
```

Sustituye estas pruebas enteras por las de abajo (mismo nombre salvo la tercera, que se renombra):

```gdscript
func test_drag_from_loot_places_and_swaps() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var old_sword := _piece(&"sword_basic", 0.5)
	var new_sword := _piece(&"sword_basic", 0.95)
	im.add_crafted_item(old_sword)
	im.move_item(old_sword, &"hero", Vector2i(3, 0), 0)  # de pie en (3,0)-(3,1)
	im.add_crafted_item(new_sword)
	_in_box(new_sword, 300.0, PI / 2.0)  # tumbada en el suelo de la caja
	var panel := _new_panel()
	var start := _box_point(panel, new_sword)
	_mouse(panel, start, true)
	check(panel._press.get("item") == new_sword and panel._press.get("rot") == 1, "se coge la espada nueva, tumbada como está en la caja")
	_move(panel, start + Vector2(0, -30))
	check(panel._dragging, "empieza el arrastre")
	var finger := _finger_for(panel, panel._hero_view, Vector2i(2, 0))  # tumbada: (2,0)-(3,0), encima de la vieja
	_move(panel, finger)
	check(panel._target.get("ok", false) and panel._target.get("swap") == old_sword, "encima de la vieja: intercambio (%s)" % [panel._target])
	_mouse(panel, finger, false)
	check(new_sword.place == &"hero" and new_sword.cell == Vector2i(2, 0) and old_sword.place == &"loot", "la nueva en Tico y la vieja al botín")
	check(not panel._dragging and panel._press.is_empty(), "el arrastre termina")
	await _silence_sounds()
	panel.queue_free()
	await _restore_inventory(saved)


func test_new_loot_while_dragging_is_not_lost() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var dragged := _piece(&"helmet_basic")
	im.add_crafted_item(dragged)
	_in_box(dragged, 300.0)
	var panel := _new_panel()
	var start := _box_point(panel, dragged)
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
	await _silence_sounds()
	panel.queue_free()
	await _restore_inventory(saved)


## En la caja no hay desplazamiento: arrastrar de lado también coge la pieza (spec del botín con física, apartado 6).
func test_dragging_sideways_in_the_box_takes_the_piece() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var shield := _piece(&"shield_master")
	im.add_crafted_item(shield)
	_in_box(shield, 600.0)
	var panel := _new_panel()
	var start := _box_point(panel, shield)
	_mouse(panel, start, true)
	_move(panel, start + Vector2(-300, 5))
	check(panel._dragging and panel._press.get("item") == shield, "de lado se coge la pieza")
	_mouse(panel, start + Vector2(-300, 5), false)
	check(shield.place == &"loot" and panel._loot_box.body_of(shield) != null, "soltada en la caja, sigue en el botín con su cuerpo")
	panel.queue_free()
	await _restore_inventory(saved)


## Soltar una pieza donde ya estaba vale, pero no mueve nada: ni suena el clinc ni Tico se materializa de nuevo.
## Soltar cualquier pieza deja su ficha en pantalla, se mueva o no.
func test_dropping_a_piece_on_its_own_place_does_not_rematerialize_tico() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var sword := _piece(&"sword_advanced")  # 1×3
	var helmet := _piece(&"helmet_basic")
	im.add_crafted_item(sword)
	im.add_crafted_item(helmet)
	im.move_item(sword, &"hero", Vector2i(1, 0), 0)
	_in_box(helmet, 300.0)
	var panel := _new_panel()
	var puppet: Node = panel._puppet
	puppet.set("_materialize", 1.0)  # Tico ya está entero
	var tap := _box_point(panel, helmet)
	_mouse(panel, tap, true)
	_mouse(panel, tap, false)
	check(panel._selected == helmet and "Casco básico" in panel._ficha_label.text, "un toque en el casco de la caja lo enseña en la ficha")
	var start := _cell_center(panel._hero_view, Vector2i(1, 1))
	_mouse(panel, start, true)
	_move(panel, start + Vector2(30, 0))
	check(panel._dragging, "se coge la espada de Tico")
	var finger := _finger_for(panel, panel._hero_view, Vector2i(1, 0))  # su casilla y su giro
	_move(panel, finger)
	check(panel._target.get("ok", false) and panel._target.get("swap") == null and panel._target.get("cell") == Vector2i(1, 0), "el destino es su propio sitio (%s)" % [panel._target])
	_mouse(panel, finger, false)
	check(sword.place == &"hero" and sword.cell == Vector2i(1, 0) and sword.rot == 0, "la espada sigue donde estaba")
	check(is_equal_approx(puppet.get("_materialize"), 1.0), "soltarla ahí no vuelve a materializar a Tico (%s)" % puppet.get("_materialize"))
	check(panel._selected == sword and "Espada avanzada" in panel._ficha_label.text, "pero la ficha pasa a la espada soltada (%s)" % panel._ficha_label.text)
	tap = _box_point(panel, helmet)
	_mouse(panel, tap, true)  # otra vez el casco, y luego la espada a otra casilla de verdad
	_mouse(panel, tap, false)
	check(panel._selected == helmet and "Casco básico" in panel._ficha_label.text, "la ficha vuelve al casco")
	_mouse(panel, start, true)
	_move(panel, start + Vector2(30, 0))
	finger = _finger_for(panel, panel._hero_view, Vector2i(2, 0))
	_move(panel, finger)
	_mouse(panel, finger, false)
	check(sword.cell == Vector2i(2, 0), "la espada se mueve a otra casilla (%s)" % sword.cell)
	check(is_equal_approx(puppet.get("_materialize"), 0.55), "y ahí sí se materializa de nuevo (%s)" % puppet.get("_materialize"))
	check(panel._selected == sword and "Espada avanzada" in panel._ficha_label.text, "y la ficha enseña la espada, no el casco (%s)" % panel._ficha_label.text)
	await _silence_sounds()
	panel.queue_free()
	await _restore_inventory(saved)


## Manda la pieza, no el dedo: con la rejilla de 6×6, una pieza sobre su última fila, con el dedo ya dentro de la
## caja del botín, cae en la rejilla.
func test_dropping_on_the_last_row_of_a_full_grid_places_the_piece() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var data: Dictionary = im.to_save_data()
	data["expansions"] = GridExpansions.ids().map(func(id): return String(id))
	im.load_save_data(data, 1)  # las cuatro ampliaciones forjadas: 6×6
	check(im.hero_grid_size() == Vector2i(6, 6), "Tico tiene la rejilla de 6×6 (%s)" % im.hero_grid_size())
	var helmet := _piece(&"helmet_basic")  # 1×1
	im.add_crafted_item(helmet)
	_in_box(helmet, 300.0)
	var panel := _new_panel()
	var start := _box_point(panel, helmet)
	_mouse(panel, start, true)
	_move(panel, start + Vector2(0, -30))
	var finger := _finger_for(panel, panel._hero_view, Vector2i(2, 5))
	check(panel._loot_box.rect_global().has_point(finger), "el dedo ya está dentro de la caja del botín (%s)" % finger)
	_move(panel, finger)
	check(panel._target.get("place") == &"hero" and panel._target.get("cell") == Vector2i(2, 5) and panel._target.get("ok", false), "el destino es la casilla de Tico bajo la pieza (%s)" % [panel._target])
	_mouse(panel, finger, false)
	check(helmet.place == &"hero" and helmet.cell == Vector2i(2, 5), "y al soltar la pieza queda ahí")
	await _silence_sounds()
	panel.queue_free()
	await _restore_inventory(saved)


## En una rejilla pequeña, las filas punteadas (aún sin abrir) no se llevan lo que se suelta sobre la caja del botín.
func test_dashed_rows_do_not_steal_a_drop_meant_for_the_loot() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var helmet := _piece(&"helmet_basic")  # 1×1
	im.add_crafted_item(helmet)
	im.move_item(helmet, &"hero", Vector2i(0, 0), 0)
	var panel := _new_panel()
	var start := _cell_center(panel._hero_view, Vector2i(0, 0))
	_mouse(panel, start, true)
	_move(panel, start + Vector2(30, 30))
	var finger := _finger_for(panel, panel._hero_view, Vector2i(2, 5))  # la pieza sobre la fila 5, que en 4×4 aún no existe
	check(panel._loot_box.rect_global().has_point(finger), "el dedo está dentro de la caja del botín (%s)" % finger)
	_move(panel, finger)
	check(panel._target.get("place") == &"loot", "sobre una casilla que no existe manda el botín (%s)" % [panel._target])
	_mouse(panel, finger, false)
	check(helmet.place == &"loot" and panel._loot_box.body_of(helmet) != null, "y la pieza sale de Tico a la caja del botín")
	panel.queue_free()
	await _restore_inventory(saved)


## Si llega una pieza a mitad de un arrastre, la vista previa del cambio no se pierde.
func test_new_loot_while_dragging_keeps_the_stats_preview() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var sword := _piece(&"sword_advanced")
	im.add_crafted_item(sword)
	_in_box(sword, 300.0)
	var panel := _new_panel()
	var start := _box_point(panel, sword)
	_mouse(panel, start, true)
	_move(panel, start + Vector2(0, -30))
	var finger := _finger_for(panel, panel._hero_view, Vector2i(0, 0))
	_move(panel, finger)
	check(panel._target.get("ok", false) and "[color=" in panel._stats_label.text, "sobre Tico vacío, la barra enseña el cambio (%s)" % panel._stats_label.text)
	im.add_crafted_item(_piece(&"boots_basic"))  # llega una pieza de la forja a mitad del arrastre
	check(panel._dragging and panel._target.get("ok", false) and "[color=" in panel._stats_label.text, "y la barra sigue enseñándolo (%s)" % panel._stats_label.text)
	_move(panel, Vector2(540, 60))
	_mouse(panel, Vector2(540, 60), false)
	panel.queue_free()
	await _restore_inventory(saved)


## Si crece la rejilla a mitad de un arrastre, el destino y sus casillas se calculan de nuevo.
func test_grid_growing_while_dragging_recalculates_the_target() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var shield := _piece(&"shield_advanced")  # 2×2
	im.add_crafted_item(shield)
	_in_box(shield, 300.0)
	var panel := _new_panel()
	var start := _box_point(panel, shield)
	_mouse(panel, start, true)
	_move(panel, start + Vector2(0, -30))
	var finger := _finger_for(panel, panel._hero_view, Vector2i(3, 0))  # en 4×4 se sale por la derecha
	_move(panel, finger)
	check(not panel._target.get("ok", true) and panel._hero_view.drop_cells.size() == 2 and panel._hero_view.drop_cells.values().all(func(c): return c == GearGridView.COLOR_BAD), "en 4×4 no cabe: dos casillas en rojo (%s)" % [panel._hero_view.drop_cells])
	im.hero_grid.resize(Vector2i(5, 4))
	im.grid_resized.emit(Vector2i(5, 4))  # la ampliación llega a mitad del arrastre
	check(panel._target.get("ok", false), "con la columna nueva ya cabe (%s)" % [panel._target])
	check(panel._hero_view.drop_cells.size() == 4 and panel._hero_view.drop_cells.values().all(func(c): return c == GearGridView.COLOR_OK), "y las cuatro casillas pasan a verde (%s)" % [panel._hero_view.drop_cells])
	_move(panel, Vector2(540, 60))
	_mouse(panel, Vector2(540, 60), false)
	panel.queue_free()
	await _restore_inventory(saved)


## Si algo oculta el panel sin pasar por close() en mitad de un arrastre, al abrirlo otra vez no queda nada a medias.
func test_open_cancels_a_drag_left_over() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var helmet := _piece(&"helmet_basic")
	im.add_crafted_item(helmet)
	_in_box(helmet, 300.0)
	var panel := _new_panel()
	var start := _box_point(panel, helmet)
	_mouse(panel, start, true)
	_move(panel, start + Vector2(0, -40))
	check(panel._dragging and panel._loot_box.is_held(helmet) and panel._loot_box.body_of(helmet) == null, "se arrastra el casco y sale de la física de la caja")
	panel.visible = false  # algo lo oculta sin pasar por close()
	panel.open()
	check(not panel._dragging and panel._press.is_empty() and not panel._loot_box.is_held(helmet) and panel._loot_box.body_of(helmet) != null, "al abrirlo otra vez el arrastre queda cancelado y el casco vuelve a la caja")
	panel.queue_free()
	await _restore_inventory(saved)
```

Borra la prueba `test_loot_strip_scrolls_sideways` entera (la sustituye `test_dragging_sideways_in_the_box_takes_the_piece`). `test_loot_strip_lays_pieces_flat_and_scrolls` se queda hasta la tarea 6: `LootStripView` aún existe.

- [ ] **Step 9: El plan `inventory` de `VisualCapture` coge la pieza de la caja**

En `scripts/tests/VisualCapture.gd`, en `_run_inventory_plan`, sustituye la línea `add.call(&"sword_advanced", 0.93, InventoryManager.PLACE_LOOT, Vector2i.ZERO)  # épica, sin aristas: la última añadida va delante` por:

```gdscript
	var fresh: CraftedItem = add.call(&"sword_advanced", 0.93, InventoryManager.PLACE_LOOT, Vector2i.ZERO)  # épica, sin aristas
```

Sustituye de `hud._on_delivery_pressed()` hasta el final de la función por:

```gdscript
	hud._on_delivery_pressed()
	await get_tree().create_timer(2.5).timeout  # las tres del botín caen en la caja, una tras otra
	var panel: Node = hud.equipment_panel
	var box: LootBoxView = panel._loot_box
	# Arrastre: la espada nueva, de la caja a la columna derecha de Tico. Al cogerla se endereza; con la R se pone de pie
	# y cae encima de la maestra: se intercambian y la maestra vuelve al botín, cayendo desde arriba.
	var start: Vector2 = box.piece_global_point(fresh)
	panel._on_press(start)
	var turns := (4 - int(panel._press.rot)) % 4  # giros de R hasta dejarla de pie: la espada avanzada (1×3) lo está en el giro 0
	var grab: Vector2 = panel._press.origin - panel._press.pos
	var finish: Vector2 = panel._hero_view.global_position + Vector2(5, 0) * GearGridView.CELL - grab + Vector2(0.0, GearGridView.CELL)
	for i in 12:
		panel._on_motion(start.lerp(finish, float(i + 1) / 12.0))
		if i in [4, 6, 8] and turns > 0:
			panel._rotate_drag()
			turns -= 1
		await get_tree().create_timer(0.12).timeout
	await get_tree().create_timer(1.0).timeout  # destino en verde, intercambio y cambio de estadísticas
	panel._on_release(finish)
	await get_tree().create_timer(2.0).timeout  # la maestra cae en la caja
	# Ficha completa de la maestra legendaria, ya en la caja. La pulsación larga mide tiempo real (Time.get_ticks_msec) y
	# la grabación va más deprisa que el reloj: se adelanta la hora de la pulsación en vez de esperarla
	var legend_point: Vector2 = box.piece_global_point(legend)
	panel._on_press(legend_point)
	panel._press.time = Time.get_ticks_msec() - 1000
	await get_tree().create_timer(0.6).timeout
	panel._on_release(legend_point)
```

- [ ] **Step 10: Ver que pasa la batería**

Run: `--import` y después la batería (las seis órdenes).
Expected: todas con `0 fallos` y código 0. Mira `git status`: devuelve lo que Godot haya reescrito sin querer.
Al salir, `InventoryGridTests` puede avisar alguna vez de `ObjectDB instances leaked` / `resources still in use` con `ui_tap.wav`: es una voz de `AudioManager` que aún suena al cerrar Godot y no cuenta como fallo. Si sale en todas las ejecuciones, alarga la espera de `_silence_sounds` en la última prueba que suena.

- [ ] **Step 11: Commit**

```bash
git status --short
git add scenes/UI/EquipmentPanel.tscn scripts/ui/EquipmentPanel.gd scripts/tests/LootBoxTests.gd scripts/tests/InventoryGridTests.gd scripts/tests/VisualCapture.gd
git commit -m "feat: panel de Equipo con la caja del botín: sin desplazamiento, coger enderezado, lanzar y volver a la caja; mochila más abajo"
```

---

### Task 6: Rendimiento, capturas, fuera la tira y documentación

**Files:**
- Test: `scripts/tests/LootBoxTests.gd` (rendimiento con 60 piezas)
- Modify: `scripts/tests/VisualCapture.gd` (plan `lootbox`)
- Delete: `scripts/ui/LootStripView.gd`, `scripts/ui/LootStripView.gd.uid`
- Modify: `scripts/tests/InventoryGridTests.gd` (fuera `test_loot_strip_lays_pieces_flat_and_scrolls`)
- Modify: `scripts/ui/GearArt.gd` (comentario), `doc/ARCHITECTURE.md` (apartado 4.3)

**Interfaces:**
- Consumes: `EquipmentPanel` (`open`, `close`, `_loot_box`, `_on_press`, `_on_motion`, `_on_release`, `_press`, `_hero_view`), `LootBoxView` (`is_settled`, `body_of`, `_bodies`, `_queue`, `piece_global_point`), `LootPiece.top_y()`, `LootPiece.is_ghost`.
- Produces: el plan de captura `lootbox` (`VisualCapture.gd --plan=lootbox`) y la prueba `test_sixty_pieces_settle_under_the_ceiling_and_the_panel_opens_fast`.

- [ ] **Step 1: La prueba de rendimiento**

Añade al final de `scripts/tests/LootBoxTests.gd`:

```gdscript


# ─── Tarea 6: rendimiento ──────────────────────────────────────────────

## Spec, apartado 10: 60 piezas se quedan quietas, sin pasar del techo, y abrir el panel con ellas (cada una vuelve a su pose:
## 60 cuerpos nuevos) cabe en 50 ms, el presupuesto del panel de siempre. Se mide en el ordenador; el móvil, con su tarjeta.
func test_sixty_pieces_settle_under_the_ceiling_and_the_panel_opens_fast() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	for i in 60:
		var res := _res(ITEM_IDS[i % ITEM_IDS.size()])
		var item := CraftedItem.new(res, rng.randf())
		item.aristas = PieceShape.roll_aristas(res, item.get_quality_tier(), rng)
		im.add_crafted_item(item)
	var panel := _new_panel()
	var box: LootBoxView = panel._loot_box
	var frames: int = await _physics_until(func(): return box.is_settled(), 4000)
	check(frames > 0, "las 60 piezas se quedan quietas (%d pasos, %.1f s de juego)" % [frames, frames / 60.0])
	check(box._bodies.size() == 60, "todas tienen cuerpo (%d)" % box._bodies.size())
	check(_highest_top(box, im.get_loot()) >= LootBoxView.CEIL_Y - 2.0, "ninguna pasa del techo (%.1f)" % _highest_top(box, im.get_loot()))
	check(im.get_loot().all(func(it): return _inside(box.body_of(it))), "todas dentro de la caja")
	var ghosts: int = im.get_loot().filter(func(it): return box.body_of(it).is_ghost).size()
	print("botín con física: 60 piezas quietas en %d pasos, %d fantasmas" % [frames, ghosts])
	check(60 - ghosts >= 20 and ghosts <= 40, "a media escala caben unas 25 que chocan; el resto, fantasmas (%d que chocan, %d fantasmas; medido: 25 y 35)" % [60 - ghosts, ghosts])
	panel.close()  # recoge las poses
	panel.queue_free()
	await get_tree().physics_frame
	# Tres paneles nuevos, cada uno crea los 60 cuerpos desde las poses; se mira la apertura más rápida
	var samples: Array[float] = []
	for i in 3:
		var fresh: Control = load("res://scenes/UI/EquipmentPanel.tscn").instantiate()
		add_child(fresh)
		await get_tree().process_frame
		var t0 := Time.get_ticks_usec()
		fresh.open()
		samples.append((Time.get_ticks_usec() - t0) / 1000.0)
		check(fresh._loot_box._bodies.size() == 60 and fresh._loot_box._queue.is_empty(), "al abrir, todas vuelven a su pose sin caer")
		fresh.close()
		fresh.queue_free()
		await get_tree().physics_frame
	var ms: float = samples.min()
	print("panel de Equipo con 60 piezas en la caja: %.1f ms, la más rápida de 3 (%.1f / %.1f / %.1f)" % [ms, samples[0], samples[1], samples[2]])
	check(ms < 50.0, "abrir el panel con 60 piezas cabe en 50 ms (%.1f)" % ms)
	await _restore_inventory(saved)
```

- [ ] **Step 2: Ver que pasa**

Run: `APPDATA=<appdata> timeout 300 D:/Software/Godot/godot_ver4.5.exe --headless --fixed-fps 60 --path . res://scenes/tests/LootBoxTests.tscn`
Expected: `[LootBoxTests] N comprobaciones, 0 fallos`, y las dos líneas `botín con física: …` y `panel de Equipo con 60 piezas …` en la salida. Esta prueba se escribe sobre código ya hecho: si falla, el fallo es del código de las tareas 4 o 5 (tope de pasos, fantasmas que no entran o una apertura lenta), no de la prueba. Apunta los números en el informe de la tarea.

- [ ] **Step 3: Plan de captura `lootbox`**

En `scripts/tests/VisualCapture.gd`, en el comentario de cabecera, tras las dos líneas del plan `inventory`, añade:

```gdscript
##   lootbox → botín con física: caen varias piezas forjadas, la caja se llena hasta que entran fantasmas y se arrastra
##             una pieza de la caja a la rejilla de Tico
```

En `_ready`, dentro del `match _plan`, tras `"inventory": _run_inventory_plan()`, añade:

```gdscript
		"lootbox":
			_run_lootbox_plan()
```

Añade al final del fichero:

```gdscript


func _run_lootbox_plan() -> void:
	# Botín con física (spec doc/specs/2026-10-02-botin-con-fisica.md): con el panel abierto llegan piezas forjadas y caen
	# una tras otra; después se llena la caja hasta que entran fantasmas (semitransparentes) y, por último, se arrastra una
	# pieza de la caja a la rejilla de Tico, vacía
	await get_tree().create_timer(1.0).timeout
	var hud := _hud()
	var im := get_node_or_null("/root/InventoryManager")
	if hud == null or im == null:
		return
	im.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var add := func(id: StringName) -> CraftedItem:
		var res: ItemResource = load("res://data/items/%s.tres" % id)
		var item := CraftedItem.new(res, rng.randf_range(0.2, 1.0))
		item.aristas = PieceShape.roll_aristas(res, item.get_quality_tier(), rng)
		im.add_crafted_item(item)
		return item
	hud._on_delivery_pressed()
	await get_tree().create_timer(0.5).timeout
	for id in [&"sword_basic", &"shield_advanced", &"helmet_master", &"boots_advanced", &"sword_advanced", &"boots_master"]:
		add.call(id)  # forjada con el panel abierto: cae desde arriba
		await get_tree().create_timer(0.4).timeout
	await get_tree().create_timer(2.0).timeout
	for i in 12:
		add.call(&"shield_master")  # se llena: las últimas entran como fantasmas
		await get_tree().create_timer(0.2).timeout
	await get_tree().create_timer(4.0).timeout
	var panel: Node = hud.equipment_panel
	var box: LootBoxView = panel._loot_box
	var target: CraftedItem = null
	for item in im.get_loot():
		var body: LootPiece = box.body_of(item)
		if body and not body.is_ghost and item.item_resource.item_id != &"shield_master":
			target = item
			break
	if target == null:
		return
	var start: Vector2 = box.piece_global_point(target)
	panel._on_press(start)
	var grab: Vector2 = panel._press.origin - panel._press.pos
	var finish: Vector2 = panel._hero_view.global_position - grab + Vector2(0.0, GearGridView.CELL)  # caja de la pieza en (0,0)
	for i in 12:
		panel._on_motion(start.lerp(finish, float(i + 1) / 12.0))
		await get_tree().create_timer(0.12).timeout
	await get_tree().create_timer(1.0).timeout  # destino en verde y cambio de estadísticas
	panel._on_release(finish)
	await get_tree().create_timer(2.0).timeout  # la pila se recoloca y algún fantasma vuelve a chocar
```

- [ ] **Step 4: Grabar y mirar las capturas**

```bash
APPDATA=<appdata> timeout 300 D:/Software/Godot/godot_ver4.5.exe --path . --write-movie <scratchpad>/lootbox540/f.png --fixed-fps 10 --quit-after 230 --resolution 540x960 res://scenes/tests/VisualCapture.tscn -- --plan=lootbox
APPDATA=<appdata> timeout 300 D:/Software/Godot/godot_ver4.5.exe --path . --write-movie <scratchpad>/lootbox810/f.png --fixed-fps 10 --quit-after 230 --resolution 810x1440 res://scenes/tests/VisualCapture.tscn -- --plan=lootbox
```

Abre con Read unos fotogramas de cada grabación (por ejemplo `f00000040.png`, `f00000090.png`, `f00000150.png`, `f00000180.png` y `f00000225.png`) y comprueba:
- las piezas caen dentro de la caja, chocan y se quedan torcidas, con su arte o sus casillas de color y el borde de calidad;
- con la caja llena, la pila sube por encima del borde sin pasar de la última fila y media de la rejilla de Tico, y hay piezas semitransparentes;
- el título de la mochila, la mochila y la zona de venta están debajo de la caja, sin solaparse y dentro de la pantalla;
- la pieza arrastrada va enderezada, una casilla por encima del dedo, y la rejilla enseña el destino en verde.

Si algo se ve mal y es de la física (tiembla, se sale, no se duerme), ajusta las constantes de `LootPiece` o `LootBoxView`, vuelve a pasar `LootBoxTests` y graba otra vez. Si es de colocación (se solapa algo), ajusta las medidas del panel sin salirte del spec y apúntalo en el informe. Devuelve con `git checkout` lo que Godot reescriba (ver Global Constraints).

- [ ] **Step 5: Fuera `LootStripView`**

```bash
git rm scripts/ui/LootStripView.gd scripts/ui/LootStripView.gd.uid
```

En `scripts/tests/InventoryGridTests.gd`, borra la prueba `test_loot_strip_lays_pieces_flat_and_scrolls` entera y cambia el título de su sección de `# ─── Tarea 8: vistas de rejilla y botín ───` a `# ─── Tarea 8: vista de la rejilla ───`.

En `scripts/ui/GearArt.gd`, sustituye la línea `## Es el `sprite_for` de GearGridView y LootStripView: las piezas sin arte siguen con casillas de color.` por:

```gdscript
## Es el `sprite_for` de GearGridView, LootBoxView y LootPiece: las piezas sin arte siguen con casillas de color.
```

Comprueba: `git grep -n "LootStripView" -- scripts scenes` no imprime nada.

- [ ] **Step 6: `doc/ARCHITECTURE.md`, apartado 4.3**

En el bloque de `InventoryManager`, sustituye la línea de `loot` por:

```
  ├─ loot: Array[CraftedItem]             # botín (&"loot"): sin límite, en orden de llegada. En el panel es una caja con física; cada pieza guarda su loot_pose
```

En la tabla de clases:
- en la fila de `PieceShape`, al final de «Qué hace», añade: `. También el centro de masa y los rectángulos de colisión de una pieza girada (`mass_center()`, `collision_rects()`) para el botín con física`;
- en la fila de `GearGridView`, sustituye `y `LootStripView` (casilla y dibujo de piezas)` por `y `LootPiece` (dibujo de piezas)`;
- sustituye la fila de `LootStripView` por estas dos:

```
| `LootBoxView` | `Node2D` con la caja del botín (960×440, techo invisible 165 px por encima): suelo, paredes y techo estáticos y un `LootPiece` por pieza de `InventoryManager.loot` (`sync()`). Decide quién entra y desde dónde (pose guardada, punto donde se suelta o caída desde arriba), quién no cabe (modo fantasma) y cuándo vuelve a chocar; se congela con el panel cerrado; recoge las poses y avisa cuando la pila se queda quieta (`poses_settled`) | `EquipmentPanel` |
| `LootPiece` | `RigidBody2D` de una pieza, a media escala (`BOX_CELL`, 55 px por casilla): un rectángulo por casilla (aristas incluidas) centrado en su centro de masa, masa por casillas, su dibujo de siempre girado con el cuerpo y el modo fantasma (choca con la caja, no con las piezas; semitransparente). Capas propias: 9 paredes, 10 piezas, 11 fantasmas | `LootBoxView` |
```

En el párrafo **Panel de Equipo**, sustituye `el botín con «Vender todo»` por `la caja del botín con «Vender todo»`, y tras el punto `- soltar en la zona de venta la vende;` añade:

```
- en la caja (`LootBoxView`) las piezas van a media escala; coger una la saca de la física enderezada al cuarto de vuelta más cercano y a tamaño completo (`DRAG_CELL`); soltarla en la caja la devuelve donde se ve, con la inercia del gesto (tope de 1400 px/s); soltada fuera de todo vuelve a la caja, al punto más cercano al dedo. No hay desplazamiento;
```

Tras el párrafo **Pociones.**, añade:

```
**Botín con física.** Spec: `doc/specs/2026-10-02-botin-con-fisica.md`. `InventoryManager.loot` sigue siendo la fuente de verdad: la caja crea y quita cuerpos según la lista. Lo forjado, lo que manda «Al botín» y lo que saca un intercambio cae desde arriba, una pieza tras otra, en una x al azar; lo que suelta el jugador entra donde se suelta. Las piezas van a media escala (`LootPiece.BOX_CELL`, 55 px por casilla); al cogerlas crecen a 110 y al soltarlas en la caja vuelven a 55. Una pieza no cabe si, ya quieta, solapa a otra (casillas encogidas 4,4 px) o está apretada contra el techo, o si no encuentra sitio bajo el techo para caer en 2 s: pasa a modo fantasma. Cuando se libera sitio, los fantasmas prueban de nuevo, donde están o cayendo desde arriba. Con el panel cerrado la caja sale de la física; al cerrarlo, y cuando la pila se queda quieta (como mucho una vez por segundo), las poses van a las piezas y `InventoryManager.note_loot_poses()` pide el guardado diferido de `GameManager`. Una pieza que sale del botín pierde su pose.
```

En el párrafo **Guardado versión 2**, tras `de cada pieza, `place`, `x`, `y`, `rot` y `aristas`)`, añade: `y, en el botín, `lx`, `ly` y `ang` si tiene pose (opcionales: sin ellos la pieza cae al abrir el panel; una pose fuera de la caja, por encima del techo o sin números se descarta)`.

En el párrafo **Pruebas.**, sustituye su texto por:

```
**Pruebas.** `InventoryGridTests` (`scenes/tests/InventoryGridTests.tscn`), que incluye la medida de lo que tarda en abrirse el panel con la rejilla llena; `LootBoxTests` (`scenes/tests/LootBoxTests.tscn`, con `--fixed-fps 60`), con la física real: caídas, techo, fantasmas, poses, lanzamiento y 60 piezas; y los planes `inventory` y `lootbox` de `VisualCapture` para capturar el panel.
```

- [ ] **Step 7: La batería entera**

Run: `--import` y después la batería (las seis órdenes).
Expected: todas con `0 fallos` y código 0. `git status` sin ficheros reescritos por Godot que no sean de la tarea.

- [ ] **Step 8: Commit**

```bash
git status --short
git add scripts/tests/LootBoxTests.gd scripts/tests/VisualCapture.gd scripts/tests/InventoryGridTests.gd scripts/ui/GearArt.gd doc/ARCHITECTURE.md
git commit -m "feat: botín con física: prueba con 60 piezas, plan de captura lootbox, fuera LootStripView y arquitectura 4.3"
```

(El `git rm` del paso 5 ya deja el borrado de `LootStripView` preparado para este commit.)
