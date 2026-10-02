# Rangos de plano por ciclo — Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** que cada vuelta a los 5 biomas (50 salas) desbloquee versiones más fuertes de los 12 planos (rango II, III…), con materiales de bioma, dificultad de minijuego por rango, encargo propio y el bucle del muro (cada sala es un duelo; al perder, Tico farmea delante del muro y lo reintenta; selector de sala con candado), sobre una curva de enemigos calibrada con una simulación.

**Architecture:** tres clases estáticas nuevas en `scripts/core/`:
- `EnemyScaling` tiene la curva de enemigos;
- `CombatMath` tiene las fórmulas del combate sin nodos (las usan `Hero`, `Enemy` y la simulación);
- `Ranks` tiene ciclos, hitos, multiplicadores y recetas.

El rango viaja como un entero junto al plano:
- desbloqueo: `DataManager` guarda el rango máximo por plano;
- pedidos (`RequestsManager`) y tareas (`CraftingManager`);
- objeto forjado (`CraftedItem.rank`, que ya existe);
- guardado, que pasa a la versión 3 (la 2 la tomó el inventario en rejilla).

La calibración (tarea 3) está hecha con Balanza: el enlace `scripts/tests/BalanzaBinding.gd` simula los duelos de Tico sala a sala con las fórmulas reales y `bash balance/arnes.sh check` comprueba los objetivos del spec; ver el spec, apartado 6. No se crean ficheros de plano por rango: el rango se aplica al forjar.

El equipo ya es una rejilla (spec `doc/specs/2026-09-27-inventario-en-rejilla.md`, `doc/ARCHITECTURE.md` apartado 4.3): no hay huecos fijos, lo forjado llega al botín y cuenta lo que está en la rejilla de Tico. El rango del equipo es `InventoryManager.equipment_rank()`: el menor entre las mejores piezas de cada tipo de esa rejilla.

**Tech Stack:** Godot 4.5.1 (GDScript con tabuladores), Python 3 + Pillow para los iconos pixel, escenas de pruebas sin ventana sobre `scripts/tests/TestSuite.gd`.

**Spec:** `doc/specs/2026-09-27-rangos-de-plano-por-ciclo.md`

## Orden de ejecución (revisión del 2026-10-02)

- Hechas: las tareas 1, 2, 3 y 12.
  - La 3 (calibración) se hizo con Balanza y está fusionada (commit c1601d8, rama `rangos-calibracion`). El código que trae más abajo es la versión anterior: no lo ejecutes.
  - La 12 (muro, farmeo y selector de sala) se hizo antes que la 3.
- El inventario en rejilla está integrado (commit b1191f7). Las tareas 4 a 11 y 13 están adaptadas a él y a la calibración. La adaptación aprobada está en `.superpowers/sdd/2026-09-27-rangos-de-plano-por-ciclo/adaptacion.md`.
- Quedan, en este orden: **0, 4, 5, 6, 7, 8, 9, 10, 11 y 13.** La 5 y la 6 dependen de la 0. La 9 y la 10 no dependen de nadie, pero tocan `RankTests.gd` como las demás: van en secuencia.
- Dónde: en el worktree `D:/Proyectos/PetJam-rangos`, rama `rangos-continuacion`, con la junction de `art/assets` (ver Global Constraints). Un commit por tarea en esa rama, no en `franja-pixel-fase-1`.
- La 12 dejó sus cambios en `GameManager` (muro, candado, `room_cleared` y las claves `wall_room` y `room_locked` del guardado), `Corridor` (vida llena, viaje) y `HeroViewOverlay` (selector). El código de las tareas 4, 6 y 7 no los muestra: se conservan.
- La rejilla dejó los suyos en `GameManager` (la ampliación provisional `GridExpansions` en `register_enemy_defeat`), `HeroViewOverlay` (aviso «¡La rejilla crece!»), `InventoryManager` (botín, rejillas, guardado versión 2) y `SaveManager` (copia `save.v1.bak.json`). También se conservan.

## Requisitos previos

Antes de la tarea 1 tienen que estar integradas dos tarjetas del tablero de PetJam.

**Pociones de Velocidad y Suerte.** El plan cuenta con:
- en `GameManager`: `apply_buff`, `tick_buffs` y `attack_speed_multiplier()`;
- en `Hero`: `base_aps` / `aps`, `heal()`, y que `reset_stats()` conserve la proporción de vida;
- el botín doble de la Suerte en `Enemy`.

**Textos en español con traducción al inglés.** El plan cuenta con:
- `locale/textos.csv`, con columnas `keys,es,en` y el español como clave;
- `tr()` / `TranslationServer.translate()` en los textos formateados.

Todo texto visible nuevo de este plan va en español en el código o los datos, y además con su fila en `locale/textos.csv`. Tras editar el CSV, ejecuta `D:/Software/Godot/godot_ver4.5.exe --headless --path . --import`.

## Global Constraints

- Godot: usar siempre `D:/Software/Godot/godot_ver4.5.exe` (4.5.1). Nunca `godot.exe` (4.7). Tras crear scripts con `class_name`, recursos o PNG nuevos: `D:/Software/Godot/godot_ver4.5.exe --headless --path . --import`.
- Todas las ejecuciones de Godot van con `timeout 300`: si un script no se analiza, `_ready` no corre y Godot no sale.
- GDScript con tabuladores y comentarios en español. Sin autoloads nuevos ni plugins.
- Ciclo = 50 salas (`Biomes.ROOMS_PER_BIOME` 10 × 5 biomas). El ciclo N (salas 50·(N−1)+1 a 50·N) da los planos de rango N. El rango I son los planos de hoy.
- Escalan con el rango: daño, vida, fuerza y armadura del objeto. No escalan: agilidad, inteligencia, crítico y velocidad de ataque.
- Hitos:
  - los 4 básicos de rango 1 al empezar;
  - los 4 básicos de rango N ≥ 2 al vencer al jefe de la sala 50·(N−1);
  - los 4 avanzados de rango N al vencer al jefe de la sala 50·(N−1)+20;
  - los 4 maestros de rango N al vencer al jefe de la sala 50·(N−1)+40.
- Materiales de bioma, en el orden de `Biomes.LIST`: `bone` (Hueso), `moss` (Musgo), `obsidian` (Obsidiana), `frost` (Escarcha), `void_shard` (Fragmento de vacío).
  - Los pide el básico: bone. El avanzado: moss y obsidian. El maestro: frost y void_shard.
  - Cantidad base 2 × `mat_mult(N)`.
- Botín:
  - tanda de material de siempre: `15 × mat_mult(ciclo)`;
  - 30 % de soltar `3 × mat_mult(ciclo)` del material del bioma;
  - los jefes sueltan siempre `10 × mat_mult(ciclo)` del suyo.
- `mat_mult(N) = 1,6^(N−1)` y `gold_mult = mat_mult`.
- Pedidos: rango máximo desbloqueado del plano con un 80 %, el anterior con un 20 %. Recompensa × `gold_mult`.
- Muro y farmeo (spec, apartado 7):
  - cada sala es un duelo con la vida llena;
  - al perder en la sala X, Tico reaparece en la X−1 y la X es el muro;
  - delante del muro farmea y lo reintenta cada 3 victorias (`WALL_RETRY_WINS`), y al momento con equipo nuevo o una poción de efecto;
  - selector de sala (de la 1 al récord) con candado;
  - el extra de jefe solo cae cuando su muerte sube el récord;
  - no hay vuelta a la sala 1 ni vuelta rápida.
- Guardado versión 3 (la 2 es la del inventario en rejilla), con migración desde la 1 y desde la 2:
  - lo forjado sin rango pasa a rango I (las piezas de la versión 2 ya guardan `rank`, siempre 1);
  - los planos desbloqueados (`unlocked_blueprints`, booleanos) pasan a rango I;
  - después se aplican los hitos del récord;
  - antes de migrar, `SaveManager` copia `save.json` en `save.v<versión de origen>.bak.json` (v1 o v2), solo si esa copia no existe.
- Textos de la franja solo con caracteres de `PixelFont`: A-Z, ÁÉÍÓÚÜÑ, 0-9, ! ¡ ? ¿ . , : ; - + / ( ) % ' · ×.
- `locale/textos.csv` (integrado en 24cde90):
  - columnas `keys,es,en`, con `es` igual a la clave;
  - **sin líneas en blanco**, porque el importador de Godot se para en la primera;
  - tras editarlo, `--import`;
  - `TextTests` comprueba que todas las filas se importan y que los datos visibles están en español con su fila en inglés.
  - Los textos de datos nuevos (nombres y descripciones de material) necesitan su fila o `TextTests` falla.
- Pruebas:
  - las suites extienden `res://scripts/tests/TestSuite.gd`, que protege `user://save.json` y las copias de la partida antigua (`save.v1.bak.json` y, desde la tarea 6, `save.v2.bak.json`);
  - `VisualCapture` y el arranque de `Main.tscn` no las protegen;
  - `<scratchpad>` en los comandos es tu carpeta temporal de la sesión, fuera del repo.
- **Godot nunca toca la partida real.** La partida es una sola (`%APPDATA%/Godot/app_userdata/PetJam/save.json`) y la comparten todos los worktrees y el usuario. Toda ejecución de Godot (pruebas, capturas, arranque de `Main`) va con `APPDATA` apuntando a una carpeta temporal que tiene una copia de esa partida. En Git Bash:

  ```bash
  mkdir -p <scratchpad>/appdata/Godot/app_userdata/PetJam
  cp "$(cygpath -u "$APPDATA")/Godot/app_userdata/PetJam/save.json" <scratchpad>/appdata/Godot/app_userdata/PetJam/save.json
  APPDATA="$(cygpath -w <scratchpad>/appdata)" timeout 300 D:/Software/Godot/godot_ver4.5.exe --headless --path . res://scenes/tests/RankTests.tscn
  ```

  - El `cp` solo lee la partida real. Repítelo antes de cada batería: así el arranque migra cada vez la partida de verdad (hoy, versión 2).
  - En los comandos de este plan, `<appdata>` es `"$(cygpath -w <scratchpad>/appdata)"`, y cada orden de Godot va precedida de `APPDATA=<appdata>`. Las variables de shell no pasan de una orden a otra: escribe la ruta entera cada vez.
  - `bash balance/arnes.sh check` no necesita nada de esto: lanza Godot con `balance/protegido.sh`, que le da un `APPDATA` temporal y vacío y lo borra al acabar.
- Si Godot reescribe `default_bus_layout.tres` y solo cambian sus finales de línea, devuélvelo: `git checkout -- default_bus_layout.tres`.
- Un commit por tarea en la rama `rangos-continuacion` del worktree `D:/Proyectos/PetJam-rangos`, sin Co-Authored-By, añadiendo por ruta (nunca `git add -A`). `art/assets` es una junction a la carpeta del repo principal: no la añadas nunca.

## Review Focus

- **Una partida antigua con récord alto** (versión 1, récord 57, espada equipada) debe cargar con todo en rango I, la espada en la rejilla de Tico (`best_hero_item("main_hand")`) y los hitos del récord aplicados (básicos de rango II). Prueba: `test_v1_save_with_high_record_migrates` (tarea 6).
- **Una partida de la rejilla** (versión 2) debe cargar sin mover ninguna pieza, con los planos en rango I, los hitos del récord aplicados y su copia en `save.v2.bak.json`. Prueba: `test_v2_save_migrates_to_v3` (tarea 6).
- **El rango del equipo llega a Tico:** con 4 piezas de rango II, su base es la del rango II; una pieza de rango I de un tipo que ya lleva no la baja. Prueba: `test_team_rank_reaches_tico_base` (tarea 0).
- **Un hito desbloquea 4 planos a la vez:** la franja muestra un solo aviso y los 4 pergaminos salen escalonados, no apilados. Prueba: `test_milestone_shows_one_notice_and_staggers_scrolls` (tarea 7).
- **Encargo propio con la cola llena, sin materiales o de un rango bloqueado:** no cobra nada. Prueba: `test_own_order_never_charges_when_refused` (tarea 11).
- **Un pedido ya visible cuando se desbloquea un rango nuevo** conserva su rango, su receta y su oro. Prueba: `test_visible_request_keeps_its_rank` (tarea 8).
- **Tocar el selector con Tico caído:** la reaparición lo deja en la sala elegida, sin sala doble ni combate colgado. Prueba: `test_travel_while_fallen_waits_for_the_respawn` (tarea 12).

---

## Mapa de ficheros

| Fichero | Acción | Responsabilidad |
|---|---|---|
| `scripts/core/EnemyScaling.gd` | crear | curva de enemigos y estadísticas de un enemigo |
| `scripts/core/CombatMath.gd` | crear | estadísticas de Tico, daño esperado y mitigación, sin nodos |
| `scripts/core/Ranks.gd` | crear | ciclos, hitos, multiplicadores, recetas y textos de hito |
| `scripts/core/TrialDifficulty.gd` | crear | dificultad de minijuego por rango, con topes |
| `scripts/gameplay/Hero.gd`, `Enemy.gd` | modificar | usar `CombatMath` / `EnemyScaling`; armadura relativa; botín por ciclo y de bioma (el extra de jefe, solo con récord nuevo) |
| `scripts/gameplay/CombatController.gd` | modificar | nivel del atacante al dañar |
| `scripts/gameplay/Corridor.gd` | modificar | botín de bioma (y el doble de la Suerte, que pasa aquí), avisos de hito, vida llena al entrar en cada sala y viaje del selector |
| `scripts/data/CraftedItem.gd` | modificar | constructor con rango y estadísticas escaladas; numeral en el nombre visible (`rank`, `get_name_with_rank`, `get_sell_price` y el guardado del rango ya existen) |
| `scripts/autoload/InventoryManager.gd` | modificar | `equipment_rank()` delega en `Ranks.team_rank` (tarea 0) |
| `scripts/gameplay/Hero.gd` | modificar | `reset_stats` pasa el rango del equipo a `CombatMath` (tarea 0) |
| `scripts/autoload/DataManager.gd` | modificar | rango máximo por plano, tiers y migración |
| `scripts/autoload/GameManager.gd` | modificar | hitos al vencer jefes (con la ampliación provisional detrás) y sin partida; muro, farmeo, candado y selector de sala |
| `scripts/autoload/RequestsManager.gd` | modificar | rango, receta y oro por pedido |
| `scripts/autoload/CraftingManager.gd` | modificar | rango y encargo propio en las tareas; dificultad por rango |
| `scripts/core/SaveManager.gd` | modificar | versión 3, hitos del récord al cargar y copia `save.v<N>.bak.json` por versión de origen |
| `scripts/ForgeMinigame.gd`, `data/blueprints/boots_*.tres` | modificar | claves de dificultad que sí llegan |
| `scripts/RequestSlot.gd`, `scripts/ui/HUDMain.gd`, `scripts/ui/BlueprintLibraryPanel.gd`, `scripts/ui/BlueprintCard.gd`, `scripts/ui/CraftResultScreen.gd`, `scripts/ui/HeroViewOverlay.gd`, `scripts/MaterialIcon.gd` | modificar | numerales, encargo propio, avisos, selector de sala e iconos pixel (`EquipmentPanel` y `ShopPanel` ya enseñan el rango) |
| `data/materials/{bone,moss,obsidian,frost,void_shard}.tres` | crear | materiales de bioma |
| `tools/pixel_art/materials.py`, `tools/pixel_art/tests/test_materials.py`, `tools/pixel_art/export.py` | crear / modificar | iconos 12x12 de los materiales de bioma (provisionales: el arte va al final) |
| `art/sprites/pixel/materials/*.png` | generados | iconos |
| `scripts/tests/RankTests.gd`, `scenes/tests/RankTests.tscn` | modificar | pruebas de las tareas 0 y 4 a 11 (las de 1 y 2 ya están) |
| `scripts/tests/BalanzaBinding.gd`, `balance/` | hecho (tarea 3) | enlace y objetivos de Balanza; `bash balance/arnes.sh check` |
| `scripts/tests/TestSuite.gd` | modificar | protege también `save.v2.bak.json` |
| `scripts/tests/InventoryGridTests.gd` | modificar | textos de la versión del guardado («la versión actual») |
| `scripts/tests/fixtures/save_v1.json` | crear | partida de versión 1 para la migración |
| `scripts/tests/GameplayTests.gd` | modificar | las pruebas de materiales usan la receta con rango; muro, farmeo y selector (tarea 12) |
| `scripts/tests/VisualCapture.gd` | modificar | planes de capturas `unlock`, `inventory` (numeral) y `ranks` |
| `locale/textos.csv` | modificar | filas de los textos nuevos |
| `doc/ARCHITECTURE.md`, `doc/ROADMAP.md`, `doc/specs/2026-09-27-rangos-de-plano-por-ciclo.md` | modificar | documentación (también el apartado 4.3 de la arquitectura) |

Comandos de la batería (todos desde la raíz del worktree, con la copia de la partida recién hecha; ver Global Constraints):

```bash
APPDATA=<appdata> timeout 300 D:/Software/Godot/godot_ver4.5.exe --headless --path . res://scenes/tests/RankTests.tscn
APPDATA=<appdata> timeout 300 D:/Software/Godot/godot_ver4.5.exe --headless --path . res://scenes/tests/InventoryGridTests.tscn
APPDATA=<appdata> timeout 300 D:/Software/Godot/godot_ver4.5.exe --headless --path . res://scenes/tests/GameplayTests.tscn
APPDATA=<appdata> timeout 300 D:/Software/Godot/godot_ver4.5.exe --headless --path . res://scenes/tests/PixelTests.tscn
APPDATA=<appdata> timeout 300 D:/Software/Godot/godot_ver4.5.exe --headless --path . res://scenes/tests/TextTests.tscn
bash balance/arnes.sh check
python -m unittest discover tools/pixel_art/tests
```

Donde una tarea diga "la batería", son las siete órdenes. Donde diga "RankTests, InventoryGridTests, GameplayTests y PixelTests", añade también TextTests si la tarea toca textos o `locale/textos.csv`, y `bash balance/arnes.sh check` si toca combate, estadísticas o equipo.

Cada escena sale con 0 si todo pasa y con 1 si algo falla, e imprime `[Suite] N comprobaciones, M fallos`. `arnes.sh check` imprime `✔ <variante>: 35 de 35 objetivos cumplidos` y sale con 0; si falla alguno, `✘ … objetivos incumplidos`, con su margen, y sale con otro código.

---

### Task 1: Fórmulas del combate sin nodos (sin cambiar el juego)

**Files:**
- Create: `scripts/core/EnemyScaling.gd`, `scripts/core/CombatMath.gd`, `scripts/tests/RankTests.gd`, `scenes/tests/RankTests.tscn`
- Modify: `scripts/gameplay/Hero.gd` (`reset_stats`, `expected_dps`, `armor_mitigation`), `scripts/gameplay/Enemy.gd` (`reset_stats`, `expected_dps`)

**Interfaces:**
- Produces:
  - `EnemyScaling.stat_scale(level: int) -> float`
  - `EnemyScaling.exp_factor(level: int) -> float`
  - `EnemyScaling.boss_mult(level: int) -> float`
  - `EnemyScaling.enemy_stats(level: int, archetype: Dictionary, is_boss: bool) -> Dictionary`, con claves `STR, AGI, INT, max_hp, dmg, aps, crit_p, crit_m`
  - `CombatMath.hero_stats(equipment: Dictionary) -> Dictionary`, con claves `STR, AGI, INT, max_hp, dmg, aps, crit_p, crit_m, armor`; `aps` es el ritmo sin efectos temporales
  - `CombatMath.expected_dps(stats: Dictionary, target_mitigation: float = 0.0) -> float`
  - `CombatMath.armor_mitigation(armor: int) -> float`
  - `CombatMath.PULSE_INTERVAL`

Esta tarea no cambia ningún número del juego: saca las fórmulas de `Hero.reset_stats` y `Enemy.reset_stats` a clases estáticas para que la simulación de la tarea 3 use exactamente las mismas.

- [ ] **Step 1: Crear la suite de pruebas con las pruebas que fallan**

`scenes/tests/RankTests.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/tests/RankTests.gd" id="1"]

[node name="RankTests" type="Node"]
script = ExtResource("1")
```

`scripts/tests/RankTests.gd`:

```gdscript
extends "res://scripts/tests/TestSuite.gd"
## 🧪 Pruebas de los rangos de plano por ciclo (spec doc/specs/2026-09-27-rangos-de-plano-por-ciclo.md),
## solo desarrollo, sin ventana:
##   D:/Software/Godot/godot_ver4.5.exe --headless --path . res://scenes/tests/RankTests.tscn


func _new_hero() -> Node2D:
	var hero: Node2D = load("res://scenes/Hero.tscn").instantiate()
	hero.remove_from_group("hero")  # que no lo confundan con el héroe de la partida
	add_child(hero)
	return hero


func _new_enemy() -> Node2D:
	var e: Node2D = load("res://scenes/Enemy.tscn").instantiate()
	e.remove_from_group("enemy")
	add_child(e)
	return e


# ─── Tarea 1: fórmulas del combate ─────────────────────────────────────

func test_hero_stats_match_the_game_formulas() -> void:
	var bare := CombatMath.hero_stats({})
	check(bare.max_hp == 160, "Tico sin equipo: 160 de vida (60 + fuerza 10 × 10), no %d" % bare.max_hp)
	check(is_equal_approx(bare.dmg, 21.0), "sin equipo: 21 de daño (6 + 10 × 1,5), no %.2f" % bare.dmg)
	check(is_equal_approx(bare.aps, 1.2), "sin equipo: 1,2 ataques por segundo, no %.3f" % bare.aps)
	check(is_equal_approx(bare.crit_p, 0.05), "sin equipo: 5 % de crítico")
	check(is_equal_approx(bare.crit_m, 1.58), "sin equipo: crítico ×1,58")
	var geared := CombatMath.hero_stats({"damage": 27, "hp": 315, "armor": 33, "crit": 0.3375, "aps": 0.5425})
	check(geared.max_hp == 475 and is_equal_approx(geared.dmg, 48.0) and geared.armor == 33,
		"equipo maestro medio: 475 de vida, 48 de daño y 33 de armadura")
	check(is_equal_approx(geared.aps, 1.7425), "equipo maestro medio: 1,7425 ataques por segundo")


func test_enemy_stats_match_the_current_curve() -> void:
	var skel := EnemyScaling.enemy_stats(1, EnemyArchetypes.get_data(&"skeleton"), false)
	check(skel.max_hp == 40 and is_equal_approx(skel.dmg, 11.75),
		"esqueleto de la sala 1: 40 de vida y 11,75 de daño (%d, %.2f)" % [skel.max_hp, skel.dmg])
	var boss10 := EnemyScaling.enemy_stats(10, EnemyArchetypes.get_data(&"boss"), true)
	check(boss10.max_hp == 214, "jefe de la sala 10: 214 de vida (%d)" % boss10.max_hp)
	check(absf(boss10.dmg - 69.5) < 0.1, "jefe de la sala 10: 69,5 de daño (%.2f)" % boss10.dmg)


func test_hero_and_enemy_nodes_use_the_shared_formulas() -> void:
	var hero := _new_hero()
	await get_tree().process_frame
	var inv := get_node("/root/InventoryManager")
	var expected := CombatMath.hero_stats(inv.calculate_total_stats())
	check(hero.max_hp == expected.max_hp and is_equal_approx(hero.dmg, expected.dmg),
		"Hero.reset_stats usa CombatMath.hero_stats (%d/%d, %.1f/%.1f)" % [hero.max_hp, expected.max_hp, hero.dmg, expected.dmg])
	check(is_equal_approx(hero.base_aps, expected.aps), "Hero.base_aps es el ritmo de CombatMath")
	hero.queue_free()
	var enemy := _new_enemy()
	await get_tree().process_frame
	enemy.configure_for_level(10, true)
	var e := EnemyScaling.enemy_stats(10, EnemyArchetypes.get_data(&"boss"), true)
	check(enemy.max_hp == e.max_hp and is_equal_approx(enemy.dmg, e.dmg), "Enemy.reset_stats usa EnemyScaling.enemy_stats")
	check(is_equal_approx(enemy.expected_dps(), CombatMath.expected_dps(e)), "Enemy.expected_dps usa CombatMath")
	enemy.queue_free()
	await get_tree().process_frame
```

- [ ] **Step 2: Ejecutarla y ver que falla**

Run: `timeout 60 D:/Software/Godot/godot_ver4.5.exe --headless --path . res://scenes/tests/RankTests.tscn`
Expected: error de análisis (`Identifier "CombatMath" not declared`) y Godot no sale hasta el `timeout`.

- [ ] **Step 3: Crear `scripts/core/EnemyScaling.gd`**

```gdscript
class_name EnemyScaling
extends RefCounted

## Curva de dificultad de los enemigos (spec de rangos, apartado 6). Una sola fuente para Enemy y BalanceSim.
## escala(sala) = (1 + LIN·(sala−1)) · EXP^(sala−1). Los jefes, ×BOSS_MULT.
## Las constantes las fija la calibración con BalanceSim (tarea 3); de momento son las de siempre.

const LIN := 0.15
const EXP := 1.04
const BOSS_MULT := 1.6
const BASE_HP := 40
const BASE_DMG := 5.0
const BASE_APS := 0.8


static func exp_factor(level: int) -> float:
	return pow(EXP, maxi(1, level) - 1)


static func stat_scale(level: int) -> float:
	return (1.0 + LIN * (maxi(1, level) - 1)) * exp_factor(level)


## Multiplicador de jefe de una sala.
static func boss_mult(_level: int) -> float:
	return BOSS_MULT


## Estadísticas de un enemigo de la sala `level` con los multiplicadores de su arquetipo (EnemyArchetypes.DATA).
static func enemy_stats(level: int, archetype: Dictionary, is_boss: bool) -> Dictionary:
	var lv := maxi(1, level)
	var ef := exp_factor(lv)
	var mult := boss_mult(lv) if is_boss else 1.0
	var str_v := (3.0 + lv * 1.5) * ef
	var agi := (1.5 + lv * 0.8) * sqrt(ef)
	var intel := (1.5 + lv * 0.6) * sqrt(ef)
	return {
		"STR": str_v, "AGI": agi, "INT": intel,
		"max_hp": maxi(1, int(BASE_HP * stat_scale(lv) * mult * float(archetype.get("hp", 1.0)))),
		"dmg": (BASE_DMG + str_v * 1.5) * mult * float(archetype.get("dmg", 1.0)),
		"aps": clampf(BASE_APS + agi * 0.02, 0.3, 4.0) * float(archetype.get("aps", 1.0)),
		"crit_p": minf(0.5, agi * 0.006),
		"crit_m": clampf(1.5 + intel * 0.012, 1.0, 3.0),
	}
```

- [ ] **Step 4: Crear `scripts/core/CombatMath.gd`**

```gdscript
class_name CombatMath
extends RefCounted

## Fórmulas del combate sin nodos. Las usan Hero, Enemy y la simulación de balance (BalanceSim),
## así que un cambio aquí cambia el juego y la simulación a la vez.

const HERO_BASE_HP := 60
const HERO_BASE_DMG := 6.0
const HERO_BASE_APS := 1.0
const HERO_BASE_STR := 10
const HERO_BASE_AGI := 10
const HERO_BASE_INT := 8
const PULSE_INTERVAL := 2.5
const ARMOR_K := 40.0
const MAX_MITIGATION := 0.6


## Estadísticas de Tico a partir de los totales del equipo (InventoryManager.calculate_total_stats()).
## `aps` es el ritmo sin efectos temporales (la Poción de Velocidad la aplica Hero encima).
static func hero_stats(equipment: Dictionary) -> Dictionary:
	var str_v := HERO_BASE_STR + int(equipment.get("str", 0))
	var agi := HERO_BASE_AGI + int(equipment.get("agi", 0))
	var intel := HERO_BASE_INT + int(equipment.get("int", 0))
	return {
		"STR": str_v, "AGI": agi, "INT": intel,
		"max_hp": HERO_BASE_HP + str_v * 10 + int(equipment.get("hp", 0)),
		"dmg": HERO_BASE_DMG + str_v * 1.5 + float(equipment.get("damage", 0)),
		"aps": clampf(HERO_BASE_APS + agi * 0.02 + float(equipment.get("aps", 0.0)), 0.3, 5.0),
		"crit_p": clampf(agi * 0.005 + float(equipment.get("crit", 0.0)), 0.0, 0.75),
		"crit_m": clampf(1.5 + intel * 0.01, 1.0, 3.0),
		"armor": int(equipment.get("armor", 0)),
	}


## Fracción de daño físico que absorbe la armadura (0..MAX_MITIGATION).
static func armor_mitigation(armor: int) -> float:
	if armor <= 0:
		return 0.0
	return minf(MAX_MITIGATION, float(armor) / (float(armor) + ARMOR_K))


## Daño por segundo esperado: golpes con el crítico medio, reducidos por la armadura del objetivo,
## más el pulso mágico (INT × 3 cada PULSE_INTERVAL), que la ignora.
static func expected_dps(stats: Dictionary, target_mitigation: float = 0.0) -> float:
	var hit: float = float(stats.dmg) * (1.0 + float(stats.crit_p) * (float(stats.crit_m) - 1.0))
	var pulse: float = float(stats.INT) * 3.0 / PULSE_INTERVAL
	return float(stats.aps) * hit * (1.0 - target_mitigation) + pulse
```

- [ ] **Step 5: Importar las clases nuevas**

Run: `D:/Software/Godot/godot_ver4.5.exe --headless --path . --import`
Expected: termina sin `SCRIPT ERROR`.

- [ ] **Step 6: Usar las fórmulas en `Hero.gd`**

En `reset_stats()`, sustituye el cálculo desde `STR = BASE_STR + …` hasta `armor = bonus_armor` por la llamada a `CombatMath`. El resto de la función (proporción de vida, temporizadores, `refresh_gear()`, señal y registro) queda igual. La función queda así:

```gdscript
## Recalcula las stats desde el equipo. No cura: conserva la proporción de vida (con Tico caído sigue
## a 0). GameManager la llama en cada cambio de equipo; respawn() llena la vida después.
func reset_stats():
	var hp_ratio := _hp_ratio()
	var equipment_stats := {}
	var inv_manager = get_node_or_null("/root/InventoryManager")
	if inv_manager and inv_manager.has_method("calculate_total_stats"):
		equipment_stats = inv_manager.calculate_total_stats()

	var s := CombatMath.hero_stats(equipment_stats)
	STR = s.STR
	AGI = s.AGI
	INT = s.INT
	max_hp = s.max_hp
	hp = _hp_for_ratio(hp_ratio)
	dmg = s.dmg
	base_aps = s.aps
	aps = base_aps * _attack_speed_multiplier()
	crit_p = s.crit_p
	crit_m = s.crit_m
	armor = s.armor
	atk_timer = 1.0 / aps
	pulse_timer = PULSE_INTERVAL
	# `alive` no se toca aquí: equipar durante la caída no debe resucitarlo (lo hace respawn())
	_hp_ghost = _hp_ratio()
	_strike_time = clampf(0.6 / aps, 0.12, 0.24)
	refresh_gear()

	emit_signal("stats_reset")
	DebugManager.log_msg(&"combat", "Hero stats — HP:%d DMG:%.1f APS:%.2f CRIT:%.0f%% ARM:%d (-%d%%)" % [max_hp, dmg, aps, crit_p * 100, armor, int(armor_mitigation() * 100.0)])
```

Sustituye también `expected_dps()` y `armor_mitigation()`:

```gdscript
func expected_dps() -> float:
	return CombatMath.expected_dps({"dmg": dmg, "crit_p": crit_p, "crit_m": crit_m, "aps": aps, "INT": INT})


## Fracción de daño físico que absorbe la armadura (0..MAX_MITIGATION).
func armor_mitigation() -> float:
	return CombatMath.armor_mitigation(armor)
```

Las constantes `BASE_HP`, `BASE_DMG`, `ARMOR_K` y `MAX_MITIGATION` de `Hero.gd` se quedan: las usa `set_invincible()`. Pasan a leer de `CombatMath`:

```gdscript
const BASE_HP := CombatMath.HERO_BASE_HP
const BASE_DMG := CombatMath.HERO_BASE_DMG
const BASE_APS := CombatMath.HERO_BASE_APS
const BASE_STR := CombatMath.HERO_BASE_STR
const BASE_AGI := CombatMath.HERO_BASE_AGI
const BASE_INT := CombatMath.HERO_BASE_INT
const PULSE_INTERVAL := CombatMath.PULSE_INTERVAL

# Armadura: reducción con rendimientos decrecientes (CombatMath.armor_mitigation)
const ARMOR_K := CombatMath.ARMOR_K
const MAX_MITIGATION := CombatMath.MAX_MITIGATION
```

- [ ] **Step 7: Usar las fórmulas en `Enemy.gd`**

Sustituye `reset_stats()` y `expected_dps()`:

```gdscript
func reset_stats():
	var d: Dictionary = EnemyArchetypes.get_data(archetype)
	var s := EnemyScaling.enemy_stats(level, d, is_boss)
	STR = s.STR
	AGI = s.AGI
	INT = s.INT
	max_hp = s.max_hp
	hp = max_hp
	dmg = s.dmg
	aps = s.aps
	crit_p = s.crit_p
	crit_m = s.crit_m
	atk_timer = 1.0 / aps
	pulse_timer = PULSE_INTERVAL
	alive = true
	is_attacking = false
	DebugManager.log_msg(&"combat", "Enemy Lv%d %s: HP=%d, DMG=%.1f, APS=%.2f, scale=%.2f" % [level, archetype, max_hp, dmg, aps, EnemyScaling.stat_scale(level)])
	emit_signal("stats_reset")


func expected_dps() -> float:
	return CombatMath.expected_dps({"dmg": dmg, "crit_p": crit_p, "crit_m": crit_m, "aps": aps, "INT": INT})
```

`BOSS_LEVEL_MULTIPLIER` de `Enemy.gd` deja de usarse. Bórrala si `grep -rn "BOSS_LEVEL_MULTIPLIER" scripts` ya no da resultados. `BASE_HP`, `BASE_DMG` y `BASE_APS` se quedan, porque son los valores iniciales de `max_hp`, `hp`, `dmg` y `aps` en sus declaraciones. `STR`, `AGI` e `INT` ya son `float`.

- [ ] **Step 8: Ejecutar la suite y ver que pasa**

Run: `timeout 300 D:/Software/Godot/godot_ver4.5.exe --headless --path . res://scenes/tests/RankTests.tscn`
Expected: `[RankTests] N comprobaciones, 0 fallos`, salida 0.

- [ ] **Step 9: Comprobar que el juego no cambia**

Run: `timeout 300 D:/Software/Godot/godot_ver4.5.exe --headless --path . res://scenes/tests/PixelTests.tscn` y la misma orden con `GameplayTests.tscn`
Expected: ambas con 0 fallos. En la salida de PixelTests, los registros `Enemy Lv10 boss: HP=214, DMG=69.5` y `Enemy Lv20 boss: HP=519, DMG=174.9` salen iguales que antes.

- [ ] **Step 10: Commit**

```bash
git add scripts/core/EnemyScaling.gd scripts/core/CombatMath.gd scripts/gameplay/Hero.gd scripts/gameplay/Enemy.gd scripts/tests/RankTests.gd scenes/tests/RankTests.tscn
git commit -m "refactor: fórmulas del combate en CombatMath y EnemyScaling (sin cambios de juego)"
```

---

### Task 2: `Ranks`: ciclos, hitos, multiplicadores y recetas

**Files:**
- Create: `scripts/core/Ranks.gd`
- Test: `scripts/tests/RankTests.gd` (añadir)

**Interfaces:**
- Consumes: `EnemyScaling.stat_scale`, `Biomes.ROOMS_PER_BIOME`, `Biomes.roman`, `Biomes.biome_index_for_room`
- Produces:
  - Constantes: `Ranks.ROOMS_PER_CYCLE` (50), `Ranks.TIER_BASIC / TIER_ADVANCED / TIER_MASTER` (StringName), `Ranks.TIERS` (Array con los tres), `Ranks.BIOME_MATERIALS` (Array[StringName] en el orden de los biomas), `Ranks.TIER_BIOME_MATERIALS` (Dictionary tier → Array), `Ranks.SCALED_STATS`.
  - Ciclos: `Ranks.cycle_for_room(room: int) -> int` y `Ranks.first_room_of_cycle(cycle: int) -> int`.
  - Multiplicadores: `Ranks.mat_mult(rank: int) -> float`, `Ranks.gold_mult(rank: int) -> float` y `Ranks.stat_mult(rank: int) -> float`.
  - Estadísticas y recetas: `Ranks.scale_stats(stats: Dictionary, rank: int) -> Dictionary` y `Ranks.recipe(base_materials: Dictionary, tier: StringName, rank: int) -> Dictionary`, con claves StringName.
  - Hitos: `Ranks.milestone_for_boss_room(room: int) -> Dictionary` (`{"rank": int, "tier": StringName}` o `{}`) y `Ranks.milestones_up_to_record(record: int) -> Array`.
  - Nombres y textos: `Ranks.tier_from_rarity(rarity: String) -> StringName`, `Ranks.biome_material_for_room(room: int) -> StringName`, `Ranks.numeral(rank: int) -> String` (`""` para el rango 1) y `Ranks.milestone_text(rank: int, tier: StringName) -> String` (ya traducido).

- [ ] **Step 1: Escribir las pruebas que fallan** (al final de `RankTests.gd`)

```gdscript
# ─── Tarea 2: Ranks ────────────────────────────────────────────────────

func test_cycles_are_fifty_rooms() -> void:
	check(Ranks.ROOMS_PER_CYCLE == Biomes.ROOMS_PER_BIOME * Biomes.LIST.size(), "un ciclo son los 5 biomas")
	for pair in [[1, 1], [50, 1], [51, 2], [100, 2], [101, 3]]:
		check(Ranks.cycle_for_room(pair[0]) == pair[1], "la sala %d es del ciclo %d" % pair)
	check(Ranks.first_room_of_cycle(3) == 101, "el ciclo III empieza en la sala 101")


func test_milestones_are_boss_rooms() -> void:
	check(Ranks.milestone_for_boss_room(10).is_empty(), "el jefe de la sala 10 no es hito")
	check(Ranks.milestone_for_boss_room(25).is_empty(), "una sala normal no es hito")
	var cases := [
		[20, 1, Ranks.TIER_ADVANCED], [40, 1, Ranks.TIER_MASTER], [50, 2, Ranks.TIER_BASIC],
		[70, 2, Ranks.TIER_ADVANCED], [90, 2, Ranks.TIER_MASTER], [100, 3, Ranks.TIER_BASIC],
	]
	for c in cases:
		var ms := Ranks.milestone_for_boss_room(c[0])
		check(ms.get("rank") == c[1] and ms.get("tier") == c[2], "sala %d → rango %d %s (%s)" % [c[0], c[1], c[2], ms])


func test_milestones_up_to_record() -> void:
	check(Ranks.milestones_up_to_record(1) == [{"rank": 1, "tier": Ranks.TIER_BASIC}], "al empezar, solo los básicos I")
	check(Ranks.milestones_up_to_record(20).size() == 1, "con récord 20 el jefe de la sala 20 aún no está vencido")
	var at57 := Ranks.milestones_up_to_record(57)
	check(at57.size() == 4, "con récord 57: básicos I, avanzados I, maestros I y básicos II (%s)" % [at57])
	check(at57.has({"rank": 2, "tier": Ranks.TIER_BASIC}), "con récord 57 están los básicos II")


func test_multipliers_grow_with_the_rank() -> void:
	check(is_equal_approx(Ranks.mat_mult(1), 1.0) and is_equal_approx(Ranks.mat_mult(2), 1.6), "mat_mult: 1 y 1,6")
	check(is_equal_approx(Ranks.gold_mult(3), Ranks.mat_mult(3)), "el oro crece como los materiales")
	check(is_equal_approx(Ranks.stat_mult(1), 1.0), "el rango I no cambia las estadísticas")
	for r in range(1, 6):
		check(Ranks.stat_mult(r + 1) > Ranks.stat_mult(r), "stat_mult crece del rango %d al %d" % [r, r + 1])


func test_scale_stats_only_touches_additive_stats() -> void:
	var base := {"damage": 10, "hp": 20, "str": 0, "armor": 3, "agi": 5, "int": 2, "crit": 0.1, "aps": 0.2}
	var m := Ranks.stat_mult(2)
	var s := Ranks.scale_stats(base, 2)
	check(s.damage == roundi(10 * m) and s.hp == roundi(20 * m) and s.armor == roundi(3 * m), "daño, vida y armadura escalan")
	check(s.agi == 5 and s.int == 2 and is_equal_approx(s.crit, 0.1) and is_equal_approx(s.aps, 0.2), "agilidad, inteligencia, crítico y velocidad no")
	check(Ranks.scale_stats(base, 1) == base, "el rango I deja las estadísticas igual")


func test_recipe_adds_biome_materials_by_tier() -> void:
	var sword_master := {"fire": 2, "iron": 8}
	check(Ranks.recipe(sword_master, Ranks.TIER_MASTER, 1) == {&"fire": 2, &"iron": 8, &"frost": 2, &"void_shard": 2}, "maestro I: sus materiales + escarcha y vacío")
	check(Ranks.recipe(sword_master, Ranks.TIER_MASTER, 2) == {&"fire": 4, &"iron": 13, &"frost": 4, &"void_shard": 4}, "maestro II: todo × 1,6 redondeado hacia arriba")
	check(Ranks.recipe({"iron": 3}, Ranks.TIER_BASIC, 1) == {&"iron": 3, &"bone": 2}, "básico I: + hueso")
	check(Ranks.recipe({"iron": 5, "leather": 1}, Ranks.TIER_ADVANCED, 1) == {&"iron": 5, &"leather": 1, &"moss": 2, &"obsidian": 2}, "avanzado I: + musgo y obsidiana")


func test_rank_names() -> void:
	check(Ranks.numeral(1) == "" and Ranks.numeral(2) == "II" and Ranks.numeral(3) == "III", "numerales: nada, II, III")
	check(Ranks.tier_from_rarity("master") == Ranks.TIER_MASTER and Ranks.tier_from_rarity("basic") == Ranks.TIER_BASIC, "tier desde la rareza")
	check(Ranks.biome_material_for_room(5) == &"bone" and Ranks.biome_material_for_room(45) == &"void_shard" and Ranks.biome_material_for_room(55) == &"bone", "material de cada bioma")
	var t := Ranks.milestone_text(2, Ranks.TIER_ADVANCED)
	check(t.contains("II") and not t.is_empty(), "el texto del hito lleva el numeral (%s)" % t)
```

- [ ] **Step 2: Ejecutar y ver que falla**

Run: `timeout 60 D:/Software/Godot/godot_ver4.5.exe --headless --path . res://scenes/tests/RankTests.tscn`
Expected: error de análisis (`Identifier "Ranks" not declared`).

- [ ] **Step 3: Crear `scripts/core/Ranks.gd`**

```gdscript
class_name Ranks
extends RefCounted

## Rangos de plano por ciclo (spec doc/specs/2026-09-27-rangos-de-plano-por-ciclo.md).
## Un ciclo son los 5 biomas (50 salas); el ciclo N da los planos de rango N. El rango I es el de siempre.
## Hitos: los básicos de rango N al entrar en su ciclo (el rango I al empezar; los demás al vencer al
## último jefe del ciclo anterior), los avanzados al vencer al jefe +20 y los maestros al jefe +40.

const ROOMS_PER_CYCLE := 50
const ADVANCED_BOSS_OFFSET := 20
const MASTER_BOSS_OFFSET := 40
const MID_CYCLE_OFFSET := 25

const TIER_BASIC := &"basic"
const TIER_ADVANCED := &"advanced"
const TIER_MASTER := &"master"
const TIERS := [&"basic", &"advanced", &"master"]

## Estadísticas del objeto que escalan con el rango. Agilidad, inteligencia, crítico y velocidad de ataque
## no escalan: tienen tope en Tico (CombatMath.hero_stats).
const SCALED_STATS := ["damage", "hp", "str", "armor"]

## Material de cada bioma, en el orden de Biomes.LIST
const BIOME_MATERIALS := [&"bone", &"moss", &"obsidian", &"frost", &"void_shard"]
## Materiales de bioma que pide cada nivel de pieza (además de los de su plano)
const TIER_BIOME_MATERIALS := {
	&"basic": [&"bone"],
	&"advanced": [&"moss", &"obsidian"],
	&"master": [&"frost", &"void_shard"],
}
const BIOME_MATERIAL_BASE_QTY := 2

## Crecimiento de recetas, botín y oro por rango (spec: 1,6^(N−1))
const MAT_GROWTH := 1.6
## Ajuste del poder por rango sobre la curva de enemigos (lo fija la calibración de la tarea 3)
const RANK_POWER_BONUS := 1.0

## Texto del aviso de cada hito; %s es el numeral con espacio delante (" II") o nada en el rango I
const MILESTONE_TEXTS := {
	&"basic": "¡Planos básicos%s!",
	&"advanced": "¡Planos avanzados%s!",
	&"master": "¡Planos maestros%s!",
}


static func cycle_for_room(room: int) -> int:
	return floori(float(maxi(1, room) - 1) / ROOMS_PER_CYCLE) + 1


static func first_room_of_cycle(cycle: int) -> int:
	return ROOMS_PER_CYCLE * (maxi(1, cycle) - 1) + 1


static func mat_mult(rank: int) -> float:
	return pow(MAT_GROWTH, maxi(1, rank) - 1)


static func gold_mult(rank: int) -> float:
	return mat_mult(rank)


## Cuánto más fuerte es un objeto de rango N que el de rango I. Sigue a la curva de enemigos medida a
## mitad de ciclo, para que el rango N pese contra el ciclo N lo mismo que el I contra el I.
static func stat_mult(rank: int) -> float:
	var r := maxi(1, rank)
	if r == 1:
		return 1.0
	var mid_n := ROOMS_PER_CYCLE * (r - 1) + MID_CYCLE_OFFSET
	return EnemyScaling.stat_scale(mid_n) / EnemyScaling.stat_scale(MID_CYCLE_OFFSET) * pow(RANK_POWER_BONUS, r - 1)


## Aplica el rango a las estadísticas de un objeto (las de ItemResource.calculate_stats).
static func scale_stats(stats: Dictionary, rank: int) -> Dictionary:
	var out := stats.duplicate()
	if rank <= 1:
		return out
	var m := stat_mult(rank)
	for key in SCALED_STATS:
		if out.has(key):
			out[key] = roundi(float(out[key]) * m)
	return out


## Receta de un plano en un rango: sus materiales × mat_mult (hacia arriba) más los de su bioma.
static func recipe(base_materials: Dictionary, tier: StringName, rank: int) -> Dictionary:
	var m := mat_mult(rank)
	var out := {}
	for mat_id in base_materials:
		out[StringName(str(mat_id))] = ceili(float(base_materials[mat_id]) * m - 0.0001)
	for mat_id in TIER_BIOME_MATERIALS.get(tier, []):
		out[mat_id] = ceili(BIOME_MATERIAL_BASE_QTY * m - 0.0001)
	return out


## Hito que desbloquea vencer al jefe de `room`: {"rank": N, "tier": …}, o {} si esa sala no es un hito.
static func milestone_for_boss_room(room: int) -> Dictionary:
	if room <= 0:
		return {}
	var offset := room % ROOMS_PER_CYCLE
	var cycle := cycle_for_room(room)
	if offset == ADVANCED_BOSS_OFFSET:
		return {"rank": cycle, "tier": TIER_ADVANCED}
	if offset == MASTER_BOSS_OFFSET:
		return {"rank": cycle, "tier": TIER_MASTER}
	if offset == 0:
		return {"rank": cycle + 1, "tier": TIER_BASIC}  # el último jefe del ciclo abre el siguiente
	return {}


## Hitos ya superados con un récord (sala más profunda alcanzada): los básicos I siempre y cada
## jefe-hito de una sala menor que el récord (llegar a la sala X+1 implica haber vencido al jefe X).
static func milestones_up_to_record(record: int) -> Array:
	var out: Array = [{"rank": 1, "tier": TIER_BASIC}]
	var boss_room := Biomes.ROOMS_PER_BIOME
	while boss_room < record:
		var ms := milestone_for_boss_room(boss_room)
		if not ms.is_empty():
			out.append(ms)
		boss_room += Biomes.ROOMS_PER_BIOME
	return out


## Nivel de pieza desde ItemResource.rarity ("basic", "advanced", "master").
static func tier_from_rarity(rarity: String) -> StringName:
	match rarity:
		"advanced":
			return TIER_ADVANCED
		"master":
			return TIER_MASTER
	return TIER_BASIC


static func biome_material_for_room(room: int) -> StringName:
	return BIOME_MATERIALS[posmod(Biomes.biome_index_for_room(room), BIOME_MATERIALS.size())]


## "" en el rango I (no se muestra), "II", "III"… a partir del II.
static func numeral(rank: int) -> String:
	return "" if rank <= 1 else Biomes.roman(rank)


## " II" para añadir a un nombre, o "" en el rango I.
static func suffix(rank: int) -> String:
	return "" if rank <= 1 else " " + numeral(rank)


## Aviso de un hito ya traducido: "¡Planos avanzados II!".
static func milestone_text(rank: int, tier: StringName) -> String:
	return String(TranslationServer.translate(MILESTONE_TEXTS.get(tier, MILESTONE_TEXTS[TIER_BASIC]))) % suffix(rank)
```

- [ ] **Step 4: Textos traducibles**

Añade a `locale/textos.csv` (columnas `keys,es,en`):

```
"¡Planos básicos%s!","¡Planos básicos%s!","Basic blueprints%s!"
"¡Planos avanzados%s!","¡Planos avanzados%s!","Advanced blueprints%s!"
"¡Planos maestros%s!","¡Planos maestros%s!","Master blueprints%s!"
```

Run: `D:/Software/Godot/godot_ver4.5.exe --headless --path . --import`

- [ ] **Step 5: Ejecutar y ver que pasa**

Run: `timeout 300 D:/Software/Godot/godot_ver4.5.exe --headless --path . res://scenes/tests/RankTests.tscn`
Expected: 0 fallos.

- [ ] **Step 6: Commit**

```bash
git add scripts/core/Ranks.gd scripts/tests/RankTests.gd locale/textos.csv
git commit -m "feat: Ranks — ciclos, hitos, multiplicadores y recetas por rango"
```

---

### Task 3: Simulación de balance y calibración de la curva

> **Hecha con Balanza (commit c029939 para la curva; los objetos y el cierre, en el commit «feat: objetos de los rangos con Balanza…» que le sigue): ver el spec, apartado 6.** La versión de abajo no es la que se ejecutó: mide carreras sin curarse, que ya no es la regla, y la sustituyeron el motor Balanza y los duelos sala a sala (spec, apartados 6 y 7). No la ejecutes tal cual; el intento anterior está en la rama local `rangos-calibracion-aparcada`.

**Files:**
- Create: `scripts/tests/BalanceSim.gd`, `scenes/tests/BalanceSim.tscn`
- Modify:
  - `scripts/core/EnemyScaling.gd` (daño con la escala, puerta de ciclo y constantes calibradas);
  - `scripts/core/CombatMath.gd` (armadura relativa al nivel del enemigo);
  - `scripts/core/Ranks.gd` (`RANK_POWER_BONUS`);
  - `scripts/gameplay/Hero.gd` (`armor_mitigation`, `take_damage`);
  - `scripts/gameplay/CombatController.gd` (pasa el nivel del enemigo);
  - `scripts/ui/EquipmentPanel.gd` (mitigación en la sala actual);
  - `doc/specs/2026-09-27-rangos-de-plano-por-ciclo.md` (valores calibrados).

**Interfaces:**
- Consumes: `CombatMath`, `EnemyScaling`, `Ranks`, `EnemyArchetypes.pick_for_room`, `ItemResource.calculate_stats`
- Produces:
  - `CombatMath.armor_mitigation(armor: int, enemy_level: int = 1) -> float`, que cambia de firma;
  - `Hero.armor_mitigation(enemy_level: int = 1) -> float`;
  - `Hero.take_damage(amount: int, is_pulse: bool = false, attacker_level: int = 1) -> int`;
  - `EnemyScaling.CYCLE_GATE_MULT` y `EnemyScaling.DMG_AT_ROOM_1`;
  - `BalanceSim.furthest_room(hero: Dictionary, max_room: int) -> int` y `BalanceSim.hero_for(tier, quality, rank) -> Dictionary`.

**Por qué cambia la curva:**
- Con las fórmulas de hoy, el equipo básico de rango I al 55 % (vida 234, daño 27, 1,3 ataques/s) pierde ya contra el jefe de la sala 10. Así, el objetivo "el básico vence al jefe +20" es imposible.
- Además, la armadura escala con el rango y satura enseguida en el 60 % de `armor / (armor + 40)`: en rangos altos dejaría de importar.
- La tarea hace tres cambios:
  1. el daño del enemigo pasa a seguir la misma escala que su vida, para que una sola curva mande;
  2. la armadura se compara con la escala del enemigo;
  3. el primer jefe de cada ciclo desde el II lleva una "puerta" (`CYCLE_GATE_MULT`).
- Después se calibran las constantes hasta que la simulación cumple los objetivos.

- [ ] **Step 1: Escribir la simulación con los objetivos**

`scenes/tests/BalanceSim.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/tests/BalanceSim.gd" id="1"]

[node name="BalanceSim" type="Node"]
script = ExtResource("1")
```

`scripts/tests/BalanceSim.gd`:

```gdscript
extends "res://scripts/tests/TestSuite.gd"
## 🧪 Simulación de balance de los rangos (spec de rangos, apartado 6), sin ventana:
##   D:/Software/Godot/godot_ver4.5.exe --headless --path . res://scenes/tests/BalanceSim.tscn
## Tico hace una carrera desde la sala 1 sin curarse entre salas (como en el juego), con el daño esperado
## por segundo de cada lado (CombatMath) y sin azar. Imprime la tabla de salas alcanzadas y comprueba
## los objetivos para los ciclos I a V.

const QUALITY_MID := 0.55
const MAX_ROOM := 400
const CYCLES := 5
const TIER_ITEMS := {
	&"basic": [&"sword_basic", &"shield_basic", &"helmet_basic", &"boots_basic"],
	&"advanced": [&"sword_advanced", &"shield_advanced", &"helmet_advanced", &"boots_advanced"],
	&"master": [&"sword_masterwork", &"shield_master", &"helmet_master", &"boots_master"],
}


## Totales del equipo de las 4 piezas de un nivel, a una calidad y un rango (como InventoryManager).
static func gear_totals(tier: StringName, quality: float, rank: int) -> Dictionary:
	var totals := {}
	for item_id in TIER_ITEMS[tier]:
		var res: ItemResource = load("res://data/items/%s.tres" % item_id)
		var stats := Ranks.scale_stats(res.calculate_stats(quality), rank)
		for k in stats:
			totals[k] = totals.get(k, 0) + stats[k]
	return totals


static func hero_for(tier: StringName, quality: float, rank: int) -> Dictionary:
	return CombatMath.hero_stats(gear_totals(tier, quality, rank))


## Última sala superada en una carrera desde la sala 1 (0 si muere en la primera).
static func furthest_room(hero: Dictionary, max_room: int = MAX_ROOM) -> int:
	var hp := float(hero.max_hp)
	var hero_dps := CombatMath.expected_dps(hero)
	for room in range(1, max_room + 1):
		var boss := Biomes.is_boss_room(room)
		var arch := EnemyArchetypes.get_data(&"boss" if boss else EnemyArchetypes.pick_for_room(room))
		var enemy := EnemyScaling.enemy_stats(room, arch, boss)
		var time_to_kill: float = float(enemy.max_hp) / maxf(hero_dps, 0.001)
		var incoming := CombatMath.expected_dps(enemy, CombatMath.armor_mitigation(int(hero.armor), room))
		hp -= incoming * time_to_kill
		if hp <= 0.0:
			return room - 1
	return max_room


func test_report_table() -> void:
	print("rango | pieza    | calidad | última sala superada")
	for rank in range(1, CYCLES + 1):
		for tier in Ranks.TIERS:
			for q in [QUALITY_MID, 1.0]:
				print("%5d | %-8s | %.2f    | %d" % [rank, tier, q, furthest_room(hero_for(tier, q, rank))])
	check(true, "tabla impresa")


## Objetivos del apartado 6 del spec, ciclo a ciclo.
func test_balance_targets() -> void:
	for n in range(1, CYCLES + 1):
		var base := Ranks.ROOMS_PER_CYCLE * (n - 1)
		var basic_mid := furthest_room(hero_for(Ranks.TIER_BASIC, QUALITY_MID, n))
		var basic_top := furthest_room(hero_for(Ranks.TIER_BASIC, 1.0, n))
		var adv_mid := furthest_room(hero_for(Ranks.TIER_ADVANCED, QUALITY_MID, n))
		var adv_top := furthest_room(hero_for(Ranks.TIER_ADVANCED, 1.0, n))
		var master_mid := furthest_room(hero_for(Ranks.TIER_MASTER, QUALITY_MID, n))
		var master_top := furthest_room(hero_for(Ranks.TIER_MASTER, 1.0, n))
		check(basic_mid >= base + 20, "rango %d: el básico medio vence al jefe %d (llega a %d)" % [n, base + 20, basic_mid])
		check(basic_top < base + 40, "rango %d: el básico perfecto no vence al jefe %d (llega a %d)" % [n, base + 40, basic_top])
		check(adv_mid >= base + 40, "rango %d: el avanzado medio vence al jefe %d (llega a %d)" % [n, base + 40, adv_mid])
		check(adv_top < base + 50, "rango %d: el avanzado perfecto no acaba el ciclo en la sala %d (llega a %d)" % [n, base + 50, adv_top])
		check(master_mid >= base + 50, "rango %d: el maestro medio acaba el ciclo en la sala %d (llega a %d)" % [n, base + 50, master_mid])
		check(master_top < base + 60, "rango %d: el maestro perfecto no vence al jefe %d del ciclo siguiente (llega a %d)" % [n, base + 60, master_top])


## La armadura sigue importando en rangos altos (no se queda clavada en el tope).
func test_armor_matters_at_high_ranks() -> void:
	var hero := hero_for(Ranks.TIER_MASTER, QUALITY_MID, 4)
	var room := Ranks.first_room_of_cycle(4) + 25
	var mit := CombatMath.armor_mitigation(int(hero.armor), room)
	check(mit > 0.2 and mit < CombatMath.MAX_MITIGATION, "maestro IV en su ciclo mitiga entre el 20 % y el tope (%.2f)" % mit)
```

- [ ] **Step 2: Ejecutar y ver que falla**

Run: `timeout 300 D:/Software/Godot/godot_ver4.5.exe --headless --path . res://scenes/tests/BalanceSim.tscn`
Expected: salida 1. La tabla se imprime y falla al menos `rango 1: el básico medio vence al jefe 20` (con la curva de hoy llega a una sala menor que 10) y `test_armor_matters_at_high_ranks`.

- [ ] **Step 3: Armadura relativa al nivel del enemigo**

En `CombatMath.gd`, sustituye `armor_mitigation`:

```gdscript
## Fracción de daño físico que absorbe la armadura frente a un enemigo de la sala `enemy_level`
## (0..MAX_MITIGATION). La armadura se compara con la escala del enemigo: así sigue contando en los
## rangos altos, donde el equipo multiplica la armadura. En la sala 1 es la fórmula de siempre.
static func armor_mitigation(armor: int, enemy_level: int = 1) -> float:
	if armor <= 0:
		return 0.0
	var k := ARMOR_K * EnemyScaling.stat_scale(enemy_level)
	return minf(MAX_MITIGATION, float(armor) / (float(armor) + k))
```

En `Hero.gd`:

```gdscript
## Fracción de daño físico que absorbe la armadura frente a un enemigo de la sala `enemy_level`.
func armor_mitigation(enemy_level: int = 1) -> float:
	return CombatMath.armor_mitigation(armor, enemy_level)


## Aplica daño y devuelve el daño real recibido (tras armadura). El pulso mágico ignora la armadura.
## `attacker_level` es la sala del enemigo que golpea: la armadura se compara con su escala.
func take_damage(amount: int, is_pulse: bool = false, attacker_level: int = 1) -> int:
	if debug_invincible or not alive:
		return 0
	var final := amount
	if not is_pulse:
		var mitigation := armor_mitigation(attacker_level)
		final = maxi(1, int(round(float(amount) * (1.0 - mitigation))))
		if final < amount and mitigation >= 0.15:
			_block_flash = 1.0
	hp = max(0, hp - final)
	_hurt = HURT_TIME
	_ghost_delay = 0.35
	if hp == 0:
		alive = false
		_spawn_death_fx()
		emit_signal("died")
	return final
```

En `CombatController.gd`, donde el enemigo golpea a Tico (hoy `var dealt: int = hero.take_damage(raw)` y la comprobación `hero.armor_mitigation() >= 0.2`):

```gdscript
	var dealt: int = hero.take_damage(raw, false, enemy.level)
```

```gdscript
		if dealt < raw and _block_text_cd <= 0.0 and hero.has_method("armor_mitigation") and hero.armor_mitigation(enemy.level) >= 0.2:
```

En `EquipmentPanel.gd`, donde se lee `hero.armor_mitigation()` para mostrar la reducción, pasa la sala actual:

```gdscript
		var room := 1
		var gm := get_node_or_null("/root/GameManager")
		if gm and "current_enemy_level" in gm:
			room = int(gm.current_enemy_level)
		var mitigation: float = hero.armor_mitigation(room) if hero.has_method("armor_mitigation") else 0.0
```

- [ ] **Step 4: Una sola curva para vida y daño, y puerta de ciclo**

`EnemyScaling.gd` queda así (las constantes son el punto de partida de la calibración):

```gdscript
class_name EnemyScaling
extends RefCounted

## Curva de dificultad de los enemigos (spec de rangos, apartado 6). Una sola fuente para Enemy y BalanceSim.
## escala(sala) = (1 + LIN·(sala−1)) · EXP^(sala−1). Vida y daño siguen la misma escala; agilidad e
## inteligencia (ritmo, crítico y pulso) crecen como siempre. Los jefes, ×BOSS_MULT; el primer jefe de
## cada ciclo a partir del II, además, ×CYCLE_GATE_MULT: la puerta que pide el equipo del rango nuevo.
## Valores calibrados con BalanceSim el <fecha de la calibración> (ver el spec, apartado 6).

const LIN := 0.0
const EXP := 1.021
const BOSS_MULT := 1.6
const CYCLE_GATE_MULT := 1.6
const CYCLE_ROOMS := 50  # igual que Ranks.ROOMS_PER_CYCLE (Ranks depende de esta clase, no al revés)
const BASE_HP := 40
const DMG_AT_ROOM_1 := 11.75  # daño de un esqueleto en la sala 1 con la fórmula anterior
const BASE_APS := 0.8


static func exp_factor(level: int) -> float:
	return pow(EXP, maxi(1, level) - 1)


static func stat_scale(level: int) -> float:
	return (1.0 + LIN * (maxi(1, level) - 1)) * exp_factor(level)


## Multiplicador de jefe de una sala: BOSS_MULT, y en el primer jefe de los ciclos II, III… también la puerta.
static func boss_mult(level: int) -> float:
	var m := BOSS_MULT
	if level > CYCLE_ROOMS and level % CYCLE_ROOMS == Biomes.ROOMS_PER_BIOME:
		m *= CYCLE_GATE_MULT
	return m


## Estadísticas de un enemigo de la sala `level` con los multiplicadores de su arquetipo (EnemyArchetypes.DATA).
static func enemy_stats(level: int, archetype: Dictionary, is_boss: bool) -> Dictionary:
	var lv := maxi(1, level)
	var ef := exp_factor(lv)
	var scale := stat_scale(lv)
	var mult := boss_mult(lv) if is_boss else 1.0
	var agi := (1.5 + lv * 0.8) * sqrt(ef)
	var intel := (1.5 + lv * 0.6) * sqrt(ef)
	return {
		"STR": (3.0 + lv * 1.5) * ef, "AGI": agi, "INT": intel,
		"max_hp": maxi(1, int(BASE_HP * scale * mult * float(archetype.get("hp", 1.0)))),
		"dmg": DMG_AT_ROOM_1 * scale * mult * float(archetype.get("dmg", 1.0)),
		"aps": clampf(BASE_APS + agi * 0.02, 0.3, 4.0) * float(archetype.get("aps", 1.0)),
		"crit_p": minf(0.5, agi * 0.006),
		"crit_m": clampf(1.5 + intel * 0.012, 1.0, 3.0),
	}
```

- [ ] **Step 5: Adaptar las pruebas de la tarea 1 a la curva nueva**

`test_enemy_stats_match_the_current_curve` fijaba los números de la curva anterior. Sustitúyela por una que compruebe la forma de la curva:

```gdscript
func test_enemy_curve_shape() -> void:
	var skel := EnemyScaling.enemy_stats(1, EnemyArchetypes.get_data(&"skeleton"), false)
	check(skel.max_hp == 40 and is_equal_approx(skel.dmg, EnemyScaling.DMG_AT_ROOM_1), "la sala 1 no cambia (40 de vida, %.2f de daño)" % skel.dmg)
	var a := EnemyScaling.enemy_stats(30, EnemyArchetypes.get_data(&"skeleton"), false)
	var b := EnemyScaling.enemy_stats(31, EnemyArchetypes.get_data(&"skeleton"), false)
	check(b.max_hp > a.max_hp and b.dmg > a.dmg, "cada sala es más dura que la anterior")
	var gate := EnemyScaling.enemy_stats(60, EnemyArchetypes.get_data(&"boss"), true)
	var plain := EnemyScaling.enemy_stats(70, EnemyArchetypes.get_data(&"boss"), true)
	check(float(gate.max_hp) / EnemyScaling.stat_scale(60) > float(plain.max_hp) / EnemyScaling.stat_scale(70), "el primer jefe del ciclo II lleva la puerta")
```

- [ ] **Step 6: Calibrar**

Ejecuta BalanceSim y ajusta una constante cada vez hasta que `test_balance_targets` y `test_armor_matters_at_high_ranks` pasen. La tabla impresa dice cuánto falta:

| Si falla… | Toca | En qué dirección |
|---|---|---|
| el básico (o avanzado) medio no llega a su jefe | `EnemyScaling.EXP` (o `LIN`) | bajar |
| el básico (o avanzado) perfecto llega demasiado lejos | `EnemyScaling.EXP` (o `LIN`) | subir |
| el maestro medio no acaba el ciclo | `EnemyScaling.CYCLE_GATE_MULT` no influye; baja `EXP` o sube `Ranks.RANK_POWER_BONUS` en rangos ≥ II | — |
| el maestro perfecto vence al primer jefe del ciclo siguiente | `EnemyScaling.CYCLE_GATE_MULT` | subir |
| todo cuadra en el rango I y falla en los altos en la misma dirección | `Ranks.RANK_POWER_BONUS` | subir si el equipo se queda corto, bajar si sobra |
| la armadura se queda en el tope o por debajo del 20 % | `CombatMath.ARMOR_K` | subir si está en el tope, bajar si no llega |

Run (tras cada cambio): `timeout 300 D:/Software/Godot/godot_ver4.5.exe --headless --path . res://scenes/tests/BalanceSim.tscn`

Si ninguna combinación cumple a la vez las cotas inferior y superior de un nivel de pieza, se puede ajustar también la separación entre niveles en los `data/items/*.tres` (los máximos del básico o del avanzado). Documenta qué se tocó. No cambies las cotas de `test_balance_targets`: son el spec.

- [ ] **Step 7: Anotar los valores calibrados**

En `EnemyScaling.gd`, sustituye `<fecha de la calibración>` por la fecha. En el spec, al final del apartado 6, añade una línea con los valores:

```markdown
- **Valores calibrados (<fecha>):** `EnemyScaling.LIN` = …, `EXP` = …, `CYCLE_GATE_MULT` = …, `Ranks.RANK_POWER_BONUS` = …, `CombatMath.ARMOR_K` = … Tabla de BalanceSim en el commit de la calibración.
```

(con los números reales en lugar de los puntos suspensivos).

- [ ] **Step 8: Toda la batería en verde**

Run: RankTests, BalanceSim, GameplayTests y PixelTests (comandos de la cabecera).
Expected: las cuatro con 0 fallos.

- [ ] **Step 9: Commit**

```bash
git add scripts/core/EnemyScaling.gd scripts/core/CombatMath.gd scripts/core/Ranks.gd scripts/gameplay/Hero.gd scripts/gameplay/CombatController.gd scripts/ui/EquipmentPanel.gd scripts/tests/BalanceSim.gd scenes/tests/BalanceSim.tscn scripts/tests/RankTests.gd doc/specs/2026-09-27-rangos-de-plano-por-ciclo.md
git commit -m "feat: curva de enemigos calibrada para los rangos (BalanceSim), armadura relativa y puerta de ciclo"
```

(Añade también los `data/items/*.tres` si la calibración los tocó.)

---

### Task 0: Rango del equipo en la base de Tico

Es lo que conecta la calibración con el juego. Hoy el rango de las piezas no tiene ningún efecto: `Hero.reset_stats` no pasa ningún rango a `CombatMath`, y el panel de Equipo tampoco. La regla del rango del equipo está dos veces: `Ranks.team_rank(piece_ranks)` (calibración, la usa `BalanzaBinding`) e `InventoryManager.equipment_rank()` (rejilla). Esta tarea deja la regla solo en `Ranks.team_rank`.

**Files:**
- Modify: `scripts/autoload/InventoryManager.gd` (`best_hero_item`, `equipment_rank`), `scripts/gameplay/Hero.gd` (`reset_stats`), `scripts/ui/EquipmentPanel.gd` (`_refresh_stats`, `_show_target`)
- Test: `scripts/tests/RankTests.gd`

**Interfaces:**
- Consumes: `Ranks.team_rank(piece_ranks: Array) -> int`, `CombatMath.hero_stats_with_powers(equipment, powers, team_rank)`, `EnemyScaling.cycle_mult(cycle)`
- Produces:
  - `InventoryManager.best_item_in(grid: GearGrid, slot: String) -> CraftedItem` (static), y `best_hero_item(slot)` la usa con la rejilla de Tico;
  - `InventoryManager.grid_rank(grid: GearGrid) -> int` (static): el rango del equipo de una rejilla cualquiera (la de Tico o una simulada del arrastre);
  - `InventoryManager.equipment_rank()`, que pasa a ser `grid_rank(hero_grid)`;
  - la vista previa del arrastre de `EquipmentPanel` lleva `"rank"`.

- [ ] **Step 0: Comprobar el punto de partida**

En el worktree `D:/Proyectos/PetJam-rangos` (rama `rangos-continuacion`, con la junction de `art/assets`), comprueba que la fusión de la calibración dejó estas firmas:

```bash
grep -n "static func hero_stats\|static func hero_stats_with_powers\|static func armor_mitigation\|static var ARMOR_K" scripts/core/CombatMath.gd
grep -n "static var EXP\|static var STEP\|static var BOSS_MULT\|static func cycle_mult" scripts/core/EnemyScaling.gd
grep -n "static func team_rank" scripts/core/Ranks.gd
grep -n "func take_damage" scripts/gameplay/Hero.gd
grep -n "take_damage(raw, false, enemy.level)" scripts/gameplay/CombatController.gd
grep -c "shape_cells\|arista_spots" data/items/*.tres
```

Expected:
- `hero_stats(equipment: Dictionary, team_rank: int = 1)` y `hero_stats_with_powers(equipment: Dictionary, powers: Array, team_rank: int = 1)`;
- `armor_mitigation(armor: int, enemy_level: int = 1)` y `ARMOR_K := 60.0`;
- `EXP := 1.0455`, `STEP := 10.5`, `BOSS_MULT := 1.15`;
- `take_damage(amount: int, is_pulse: bool = false, attacker_level: int = 1)` y la llamada del `CombatController` con `enemy.level`;
- los 12 `.tres` de objeto con `shape_cells` y `arista_spots` (2 en cada uno).

Pasa la batería entera (cabecera). Expected: todo en verde, y `arnes.sh check` con 35 de 35. Si algo falla aquí, para y avisa: es de la fusión, no de esta tarea.

- [ ] **Step 1: Pruebas que fallan** (en `RankTests.gd`)

En `test_hero_and_enemy_nodes_use_the_shared_formulas`, el esperado pasa a llevar el rango del equipo:

```gdscript
	var expected := CombatMath.hero_stats_with_powers(inv.calculate_total_stats(), inv.active_legendary_powers(), inv.equipment_rank())
```

Al final de la sección de la tarea 1 (antes de `# ─── Tarea 2`), las ayudas del inventario y la prueba nueva. Las ayudas copian las de `InventoryGridTests` (`_fresh_inventory` y `_restore_inventory`): vacían el inventario y lo devuelven tal cual al acabar.

```gdscript
# ─── Tarea 0: rango del equipo en la base de Tico ──────────────────────

func _im() -> Node:
	return get_node("/root/InventoryManager")


## Deja el inventario vacío (rejilla de 4×4) y devuelve lo que había para restaurarlo (como InventoryGridTests).
func _fresh_inventory() -> Dictionary:
	var saved: Dictionary = _im().to_save_data()
	_im().clear()
	return saved


func _restore_inventory(saved: Dictionary) -> void:
	_im().load_save_data(saved, int(get_node("/root/GameManager").best_enemy_level))
	await get_tree().process_frame  # deja pasar los guardados diferidos del cambio de equipo


## Pieza de rango `rank` en la casilla `cell` de la rejilla de Tico, sin girar. Calidad media: no es legendaria (sin
## habilidades) y no lleva aristas (CraftedItem.new no las sortea).
func _hero_piece(id: StringName, rank: int, cell: Vector2i) -> CraftedItem:
	var item := CraftedItem.new(load("res://data/items/%s.tres" % id), 0.5)
	item.rank = rank
	_im().add_crafted_item(item)
	_im().move_item(item, InventoryManager.PLACE_HERO, cell, 0)
	return item


## Base de Tico por el rango del equipo (spec de rangos, apartado 6, «Base de Tico»): Hero.reset_stats y el panel de
## Equipo pasan el rango de la rejilla de Tico a CombatMath, así que su vida base es × cycle_mult(rango).
func test_team_rank_reaches_tico_base() -> void:
	var saved := _fresh_inventory()
	var im := _im()
	var hero := _new_hero()
	await get_tree().process_frame
	check(im.equipment_rank() == 1 and hero.max_hp == CombatMath.hero_stats(im.calculate_total_stats()).max_hp, "rejilla vacía: rango I y la base de siempre (%d)" % hero.max_hp)
	var cells := {&"sword_basic": Vector2i(0, 0), &"shield_basic": Vector2i(1, 0), &"helmet_basic": Vector2i(2, 0), &"boots_basic": Vector2i(3, 0)}
	for id in cells:
		_hero_piece(id, 2, cells[id])
	check(im.get_hero_items().size() == 4 and im.equipment_rank() == 2, "4 piezas de rango II en Tico: rango II (%d piezas)" % im.get_hero_items().size())
	hero.reset_stats()  # el héroe de prueba no está en el grupo "hero": GameManager no lo recalcula solo
	var base_one: int = CombatMath.hero_stats({}).max_hp
	var gear_hp: int = CombatMath.hero_stats(im.calculate_total_stats()).max_hp - base_one  # lo que suman las piezas
	check(hero.max_hp == roundi(base_one * EnemyScaling.cycle_mult(2)) + gear_hp, "la vida base de Tico es × cycle_mult(2) (%d)" % hero.max_hp)
	check(hero.max_hp == CombatMath.hero_stats_with_powers(im.calculate_total_stats(), im.active_legendary_powers(), 2).max_hp, "Hero.reset_stats usa el rango del equipo")
	var panel: Control = load("res://scenes/UI/EquipmentPanel.tscn").instantiate()
	add_child(panel)
	panel.open()
	await get_tree().process_frame
	check((tr("Vida %d") % hero.max_hp) in panel._stats_label.text, "el panel de Equipo enseña la misma vida que Tico (%s)" % panel._stats_label.text)
	panel.queue_free()
	var base_two: int = hero.max_hp - gear_hp
	var extra := _hero_piece(&"sword_basic", 1, Vector2i(0, 2))
	check(extra.place == InventoryManager.PLACE_HERO and im.equipment_rank() == 2, "otra espada de rango I no baja el rango: cuenta la mejor espada")
	hero.reset_stats()
	var gear_hp_now: int = CombatMath.hero_stats(im.calculate_total_stats()).max_hp - base_one
	check(hero.max_hp - gear_hp_now == base_two, "y la base de Tico sigue siendo la del rango II (%d)" % (hero.max_hp - gear_hp_now))
	var helmet_one := CraftedItem.new(load("res://data/items/helmet_advanced.tres"), 0.5)
	im.add_crafted_item(helmet_one)
	var sim: GearGrid = im.simulate_hero_grid(im.best_hero_item("head"), InventoryManager.PLACE_LOOT, Vector2i.ZERO, 0)
	check(InventoryManager.grid_rank(sim) == 2, "sin casco en la vista previa: el tipo que falta no cuenta")
	sim = im.simulate_hero_grid(helmet_one, InventoryManager.PLACE_HERO, Vector2i(1, 2), 0)
	check(InventoryManager.grid_rank(sim) == 2, "un casco avanzado de rango I no baja el rango: el mejor casco sigue siendo el básico II")
	hero.queue_free()
	await _restore_inventory(saved)
```

La última comprobación sigue la regla de `gear_score`: el mejor casco es el de mayor rango (el básico II gana al avanzado I), así que el rango sigue en II. Si da 1, el fallo está en `best_item_in`.

Run: `APPDATA=<appdata> timeout 300 D:/Software/Godot/godot_ver4.5.exe --headless --path . res://scenes/tests/RankTests.tscn`
Expected: error de análisis (`InventoryManager.grid_rank` no existe) y Godot no sale hasta el `timeout`. Con el Step 2 hecho y sin el 3, falla `test_team_rank_reaches_tico_base`: la vida de Tico es la del rango I.

- [ ] **Step 2: La regla en un solo sitio (`InventoryManager.gd`)**

Sustituye `best_hero_item` y `equipment_rank`:

```gdscript
## La mejor pieza de un tipo ("main_hand", "off_hand", "head" o "feet") en la rejilla de Tico: primero
## el rango, después el nivel y después la calidad. Es la que dibuja su sprite.
func best_hero_item(slot: String) -> CraftedItem:
	return best_item_in(hero_grid, slot)


## La mejor pieza de un tipo en una rejilla cualquiera (la de Tico o una copia simulada), con gear_score.
static func best_item_in(grid: GearGrid, slot: String) -> CraftedItem:
	var best: CraftedItem = null
	for item in grid.items:
		if item.get_equipment_slot() != slot:
			continue
		if best == null or gear_score(item) > gear_score(best):
			best = item
	return best
```

```gdscript
## Rango del equipo (spec de rangos, apartado 6, "Base de Tico"; spec del inventario, apartado 6) de una rejilla: el
## menor rango entre sus mejores piezas de cada tipo. La regla vive en Ranks.team_rank; aquí solo se juntan los rangos.
## Un tipo que no lleva no cuenta, y añadir una pieza de un tipo que ya lleva nunca lo baja. Sin piezas, rango I.
static func grid_rank(grid: GearGrid) -> int:
	var ranks: Array = []
	for slot in ["main_hand", "off_hand", "head", "feet"]:
		var best := best_item_in(grid, slot)
		if best:
			ranks.append(best.rank)
	return Ranks.team_rank(ranks)


## Rango del equipo de Tico: el de su rejilla.
func equipment_rank() -> int:
	return grid_rank(hero_grid)
```

- [ ] **Step 3: Tico usa el rango (`Hero.gd`)**

En `reset_stats()` (hacia la línea 208), el bloque de las habilidades y la llamada a `CombatMath` pasan a:

```gdscript
	var powers: Array = []
	if inv_manager and inv_manager.has_method("active_legendary_powers"):
		powers = inv_manager.active_legendary_powers()
	# Rango del equipo (spec de rangos, apartado 6, «Base de Tico»): la base de vida, daño y pulso crece con él
	var team_rank := 1
	if inv_manager and inv_manager.has_method("equipment_rank"):
		team_rank = inv_manager.equipment_rank()
	var s := CombatMath.hero_stats_with_powers(equipment_stats, powers, team_rank)
```

El resto de la función no cambia.

- [ ] **Step 4: El panel de Equipo usa el rango (`EquipmentPanel.gd`)**

`_refresh_stats` enseña las estadísticas de Tico y, durante el arrastre, cómo quedarían. Las dos pasan a llevar el rango:

```gdscript
## Estadísticas de Tico. `preview` ({"totals", "powers", "rank"}, del arrastre) añade el cambio en verde o rojo.
func _refresh_stats(preview: Dictionary) -> void:
	var now := CombatMath.hero_stats_with_powers(_im.calculate_total_stats(), _im.active_legendary_powers(), _im.equipment_rank())
	var after: Dictionary = now if preview.is_empty() else CombatMath.hero_stats_with_powers(preview.totals, preview.powers, int(preview.get("rank", 1)))
```

En `_show_target()`, los dos diccionarios `preview` llevan el rango de su rejilla simulada:

```gdscript
			preview = {"totals": GearAuras.totals(sim), "powers": LegendaryPowers.active(sim.items), "rank": InventoryManager.grid_rank(sim)}
```

```gdscript
		preview = {"totals": GearAuras.totals(sim2), "powers": LegendaryPowers.active(sim2.items), "rank": InventoryManager.grid_rank(sim2)}
```

- [ ] **Step 5: Ejecutar y ver que pasa**

Run: RankTests, InventoryGridTests, GameplayTests y PixelTests, y `bash balance/arnes.sh check`.
Expected: 0 fallos en las cuatro y 35 de 35. `InventoryGridTests` ya prueba `equipment_rank()` (`test_equipment_rank_is_the_weakest_best_piece`) y sigue en verde sin tocarla.

- [ ] **Step 6: Commit**

```bash
git add scripts/autoload/InventoryManager.gd scripts/gameplay/Hero.gd scripts/ui/EquipmentPanel.gd scripts/tests/RankTests.gd
git commit -m "feat: el rango del equipo sube la base de Tico (Ranks.team_rank como única regla)"
```

---

### Task 4: Materiales de bioma: datos, iconos y botín

**Files:**
- Create:
  - `tools/pixel_art/materials.py` y `tools/pixel_art/tests/test_materials.py`;
  - `data/materials/bone.tres`, `moss.tres`, `obsidian.tres`, `frost.tres` y `void_shard.tres`.
- Modify:
  - `tools/pixel_art/export.py`, `scripts/MaterialIcon.gd`;
  - `scripts/gameplay/Enemy.gd` (botín), `scripts/gameplay/Corridor.gd` (presenta los tres botines), `scripts/gameplay/CombatController.gd` (deja de presentar el botín doble);
  - `scripts/tests/GameplayTests.gd`, `scripts/tests/RankTests.gd`, `locale/textos.csv`.
- Generated: `art/sprites/pixel/materials/{bone,moss,obsidian,frost,void_shard}.png`

**Interfaces:**
- Consumes: `Ranks.BIOME_MATERIALS`, `Ranks.biome_material_for_room`, `Ranks.mat_mult`, `Ranks.cycle_for_room` y `GameManager.best_enemy_level` (el extra de jefe solo con récord nuevo; spec, apartado 7)
- Produces:
  - `Enemy.BIOME_DROP_CHANCE` (0,3), `Enemy.BIOME_DROP_QTY` (3), `Enemy.BOSS_BIOME_QTY` (10);
  - `Enemy.biome_drop_chance: float`, que las pruebas pueden forzar;
  - `Enemy.last_biome_drop: Dictionary` (`{"item_id", "quantity"}` o `{}`);
  - `death_info["biome_material"]`.

**Iconos provisionales.** El pixel art se dejó para los personajes y el arte va al final (sistemas primero). Los iconos de abajo ya están diseñados y cuestan poco, así que se hacen, pero son provisionales: la tarjeta de arte puede cambiarlos.

**Lo que no cambió con la rejilla:** los materiales siguen en `InventoryManager.inventory` (`add_item`), `Enemy._drop_random_materials` sigue igual y el botín doble de la Suerte sigue en `CombatController._show_bonus_loot`. `GridExpansions` ya usa los nombres hueso, musgo, obsidiana y escarcha en sus recetas, pero esta tarea solo crea los materiales: las recetas de ampliación son de otra tarjeta.

- [ ] **Step 1: Pruebas de la herramienta (fallan)**

`tools/pixel_art/tests/test_materials.py`:

```python
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
```

Run: `python -m unittest discover tools/pixel_art/tests`
Expected: `ModuleNotFoundError: No module named 'materials'`.

- [ ] **Step 2: Dibujar los iconos**

`tools/pixel_art/materials.py`:

```python
"""Iconos de los materiales de bioma (12x12, con contorno de 1 px): botín de la franja e interfaz.

Lo llama export.py. Escribe art/sprites/pixel/materials/<id>.png a escala 1.
"""
from pathlib import Path

from pixel_kit import Sprite

REPO = Path(__file__).resolve().parents[2]
OUT = REPO / "art" / "sprites" / "pixel" / "materials"


def _icon(lines):
    s = Sprite(12, 12)
    s.rows(1, 1, lines)
    s.outline()
    return s


def bone():  # Catacumbas: dos huesos cruzados
    return _icon([
        "ee......ee",
        "eEe....eEe",
        ".eEe..eEe.",
        "..eEeeEe..",
        "...eEEe...",
        "...eEEe...",
        "..eEuuEe..",
        ".eEu..uEe.",
        "eEu....uEe",
        "ee......ee",
    ])


def moss():  # Cripta Musgosa: mata de musgo
    return _icon([
        "....aa....",
        "..aaAAa...",
        ".aAAcAAa..",
        "aAcAAcAAa.",
        "aAAcAAAcAa",
        "AcAAAcAAcA",
        "cAAcAAAcAc",
        ".cCcAcCcC.",
        "..CCcCCC..",
        "...CCCC...",
    ])


def obsidian():  # Caverna de Magma: piedra negra con veta de lava
    return _icon([
        "...UU.....",
        "..UoTU....",
        ".UooTTU...",
        "UooKo3TU..",
        "UoKK32oTU.",
        "UoKK3ooTU.",
        ".UKKooTU..",
        "..UKoTU...",
        "...UUU....",
        "..........",
    ])


def frost():  # Glaciar Olvidado: racimo de cristales de hielo
    return _icon([
        "....F.....",
        "...FfF....",
        "...FfF..F.",
        "..FFfFF.fF",
        "..FfYfF.fF",
        "F.FfffF.Ff",
        "fFFfffFFff",
        "fyyFfFyyFy",
        "yQQyyyQQyy",
        ".QQQQQQQQ.",
    ])


def void_shard():  # Santuario del Vacío: esquirla morada
    return _icon([
        ".....p....",
        "....pPp...",
        "....pPp...",
        "...pPYPp..",
        "...pPPPp..",
        "..pPPzPPp.",
        "..pPzzzPp.",
        "...PzZzP..",
        "....zZz...",
        ".....Z....",
    ])


ICONS = {"bone": bone, "moss": moss, "obsidian": obsidian, "frost": frost, "void_shard": void_shard}


def export_icons():
    OUT.mkdir(parents=True, exist_ok=True)
    for key, draw in ICONS.items():
        draw().image().save(OUT / f"{key}.png")
    return OUT


if __name__ == "__main__":
    from pixel_kit import preview
    preview([draw() for draw in ICONS.values()], "out/materiales.png", scale=10)
```

Al final de `tools/pixel_art/export.py`, junto a las otras exportaciones del juego:

```python
import materials
materials.export_icons()
print("iconos de materiales en", materials.OUT)
```

Run: `python -m unittest discover tools/pixel_art/tests` y después `python tools/pixel_art/export.py`
Expected: pruebas en verde; `art/sprites/pixel/materials/` con 5 PNG de 12x12.

Abre `tools/pixel_art/out/materiales.png` (desde `tools/pixel_art`: `python materials.py`) con la herramienta Read y retoca el dibujo si algún icono no se lee. Deben reconocerse a 12 px el hueso, el musgo, la piedra con veta, el hielo y la esquirla.

- [ ] **Step 3: Recursos de material**

`data/materials/bone.tres` (los otros cuatro igual, cambiando id, nombre, descripción e icono):

```
[gd_resource type="Resource" script_class="MaterialResource" load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/data/MaterialResource.gd" id="1"]
[ext_resource type="Texture2D" path="res://art/sprites/pixel/materials/bone.png" id="2"]

[resource]
script = ExtResource("1")
material_id = &"bone"
display_name = "Hueso"
description = "Hueso viejo de las Catacumbas."
icon = ExtResource("2")
```

| Fichero | material_id | display_name | description |
|---|---|---|---|
| `moss.tres` | `&"moss"` | Musgo | Musgo húmedo de la Cripta Musgosa. |
| `obsidian.tres` | `&"obsidian"` | Obsidiana | Roca volcánica de la Caverna de Magma. |
| `frost.tres` | `&"frost"` | Escarcha | Hielo eterno del Glaciar Olvidado. |
| `void_shard.tres` | `&"void_shard"` | Fragmento de vacío | Esquirla del Santuario del Vacío. |

Filas nuevas en `locale/textos.csv`:

```
"Hueso","Hueso","Bone"
"Hueso viejo de las Catacumbas.","Hueso viejo de las Catacumbas.","Old bone from the Catacombs."
"Musgo","Musgo","Moss"
"Musgo húmedo de la Cripta Musgosa.","Musgo húmedo de la Cripta Musgosa.","Damp moss from the Mossy Crypt."
"Obsidiana","Obsidiana","Obsidian"
"Roca volcánica de la Caverna de Magma.","Roca volcánica de la Caverna de Magma.","Volcanic rock from the Magma Cavern."
"Escarcha","Escarcha","Frost"
"Hielo eterno del Glaciar Olvidado.","Hielo eterno del Glaciar Olvidado.","Everlasting ice from the Forgotten Glacier."
"Fragmento de vacío","Fragmento de vacío","Void shard"
"Esquirla del Santuario del Vacío.","Esquirla del Santuario del Vacío.","A shard from the Void Sanctum."
```

(Si la tarjeta de idioma tradujo los nombres de los biomas de otra forma, usa sus nombres en inglés.)

Run: `D:/Software/Godot/godot_ver4.5.exe --headless --path . --import`

- [ ] **Step 4: Iconos pixel nítidos en la interfaz**

En `scripts/MaterialIcon.gd`, en `_update_texture()`, justo después de asignar `_texture_rect.texture = material_res.icon`:

```gdscript
			# Los iconos pixel (materiales de bioma) se amplían sin suavizar
			var pixel_icon: bool = material_res.icon.resource_path.begins_with("res://art/sprites/pixel/")
			_texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if pixel_icon else CanvasItem.TEXTURE_FILTER_PARENT_NODE
```

- [ ] **Step 5: Pruebas del botín (fallan)** (en `RankTests.gd`)

```gdscript
# ─── Tarea 4: materiales de bioma ──────────────────────────────────────

func test_biome_materials_exist_with_pixel_icons() -> void:
	for mat_id in Ranks.BIOME_MATERIALS:
		var path := "res://data/materials/%s.tres" % mat_id
		check(ResourceLoader.exists(path), "existe " + path)
		var res = load(path)
		check(res != null and res.icon != null and res.icon.get_width() == 12, "%s tiene icono pixel de 12x12" % mat_id)


func test_enemy_loot_grows_with_the_cycle_and_drops_its_biome_material() -> void:
	var inv := get_node("/root/InventoryManager")
	var e := _new_enemy()
	await get_tree().process_frame
	e.configure_for_level(5, false)  # Catacumbas, ciclo I
	e.biome_drop_chance = 1.0
	var bone_before: int = inv.get_quantity(&"bone")
	e.generate_drops()
	check(int(e.last_material_drop.get("quantity", 0)) == 15, "ciclo I: tanda de 15 (%s)" % [e.last_material_drop])
	check(e.last_biome_drop.get("item_id") == &"bone" and int(e.last_biome_drop.get("quantity", 0)) == 3, "Catacumbas suelta 3 de hueso (%s)" % [e.last_biome_drop])
	check(inv.get_quantity(&"bone") == bone_before + 3, "el hueso llega al inventario")
	e.configure_for_level(55, false)  # Catacumbas II, ciclo II
	e.generate_drops()
	check(int(e.last_material_drop.get("quantity", 0)) == ceili(15 * Ranks.mat_mult(2) - 0.0001), "ciclo II: la tanda crece con mat_mult")
	e.biome_drop_chance = 0.0
	e.configure_for_level(45, false)
	e.generate_drops()
	check(e.last_biome_drop.is_empty(), "sin la tirada no hay material de bioma")
	var gm := get_node("/root/GameManager")
	var best_before: int = gm.best_enemy_level
	gm.best_enemy_level = 40  # la primera vez: su muerte sube el récord
	e.configure_for_level(40, true)  # jefe del Glaciar: suelta el suyo aunque la probabilidad sea 0
	e.generate_drops()
	check(e.last_biome_drop.get("item_id") == &"frost" and int(e.last_biome_drop.get("quantity", 0)) == 10, "el jefe del Glaciar suelta 10 de escarcha (%s)" % [e.last_biome_drop])
	gm.best_enemy_level = 41  # ya vencido: al repetirlo, como un enemigo normal
	e.generate_drops()
	check(e.last_biome_drop.is_empty(), "repetir un jefe no da su tanda de bioma (%s)" % [e.last_biome_drop])
	gm.best_enemy_level = best_before
	e.queue_free()
	await get_tree().process_frame
```

En `GameplayTests.gd`, las dos pruebas de materiales comprueban contra la receta con rango (el hueso ya lo pide un plano, aunque no esté en su `.tres`). Sustituye `_materials_used_by_blueprints()`:

```gdscript
## Materiales que pide algún plano de la librería en su receta de rango I (incluye los de bioma).
func _materials_used_by_blueprints() -> Dictionary:
	var used := {}
	var dm := get_node("/root/DataManager")
	for bp_id in dm.get_all_blueprints():
		var bp: BlueprintResource = dm.get_all_blueprints()[bp_id]
		var item: ItemResource = dm.get_item_resource(bp.result_item)
		var tier := Ranks.tier_from_rarity(item.rarity if item else "basic")
		for mat_id in Ranks.recipe(bp.materials, tier, 1):
			used[StringName(mat_id)] = true
	return used
```

Run: `APPDATA=<appdata> timeout 300 D:/Software/Godot/godot_ver4.5.exe --headless --path . res://scenes/tests/RankTests.tscn`
Expected: fallan las dos pruebas nuevas (`biome_drop_chance` no existe y la tanda del ciclo II sigue en 15).

- [ ] **Step 6: Botín por ciclo y de bioma en `Enemy.gd`**

Constantes y variables nuevas, junto a `MATERIAL_DROP_QTY`:

```gdscript
const BIOME_DROP_CHANCE := 0.3  # probabilidad de soltar además el material del bioma
const BIOME_DROP_QTY := 3
const BOSS_BIOME_QTY := 10  # los jefes siempre sueltan el suyo
## Probabilidad efectiva (las pruebas la fuerzan a 0 o 1)
var biome_drop_chance: float = BIOME_DROP_CHANCE
var last_biome_drop: Dictionary = {}  # {"item_id", "quantity"} del último material de bioma
```

La tarjeta de pociones dejó `_drop_random_materials()`, `_give_material()` y `_rolls_double_loot()` (botín doble de la Suerte, con `last_bonus_drop` y `luck_roll`). Cambian dos cosas:
1. La tanda usa la cantidad del ciclo, en las dos tandas.
2. Al final se añade el material de bioma.

```gdscript
## Tanda de material de siempre en esta sala: 15 × mat_mult del ciclo (spec de rangos, apartado 4).
func _material_drop_qty() -> int:
	return ceili(MATERIAL_DROP_QTY * Ranks.mat_mult(Ranks.cycle_for_room(level)) - 0.0001)


## Botín de materiales: una tanda de un material al azar de los que piden los planos (con la Poción de
## Suerte, a veces una segunda de OTRO material) y, a veces, el material de este bioma (los jefes siempre).
func _drop_random_materials() -> void:
	last_material_drop = {}
	last_bonus_drop = {}
	last_biome_drop = {}
	_drop_biome_material()
	var all_materials := _blueprint_materials()
	if all_materials.is_empty():
		return
	var random_material: StringName = all_materials[_rng.randi() % all_materials.size()]
	last_material_drop = _give_material(random_material)
	if last_material_drop.is_empty() or not _rolls_double_loot():
		return
	var others: Array[StringName] = []
	for mat_id in all_materials:
		if mat_id != random_material:
			others.append(mat_id)
	if others.is_empty():
		others = all_materials
	last_bonus_drop = _give_material(others[_rng.randi() % others.size()])


## Material del bioma de la sala: con probabilidad biome_drop_chance. Un jefe lo suelta seguro, y en tanda
## de jefe, la vez que su muerte sube el récord (spec de rangos, apartado 7); si se repite, como un enemigo
## normal. Así, el candado del selector en un jefe no multiplica el material de bioma.
func _drop_biome_material() -> void:
	var boss_reward := is_boss and _raises_record()
	var chance := 1.0 if boss_reward else biome_drop_chance
	if _rng.randf() >= chance:
		return
	var im := get_node_or_null("/root/InventoryManager")
	if im == null or not im.has_method("add_item"):
		return
	var mat_id := Ranks.biome_material_for_room(level)
	var qty := ceili((BOSS_BIOME_QTY if boss_reward else BIOME_DROP_QTY) * Ranks.mat_mult(Ranks.cycle_for_room(level)) - 0.0001)
	im.add_item(mat_id, qty)
	last_biome_drop = {"item_id": mat_id, "quantity": qty}


## true si vencer a este enemigo sube el récord: su sala es la del récord, la primera sin vencer.
func _raises_record() -> bool:
	var gm := get_node_or_null("/root/GameManager")
	return gm == null or level >= int(gm.best_enemy_level)


## Mete una tanda en el inventario y la devuelve ({} si no hay inventario).
func _give_material(mat_id: StringName) -> Dictionary:
	var im := get_node_or_null("/root/InventoryManager")
	if im == null or not im.has_method("add_item"):
		return {}
	var qty := _material_drop_qty()
	im.add_item(mat_id, qty)
	return {"item_id": mat_id, "quantity": qty}
```

`_blueprint_materials()` sigue leyendo los materiales del `.tres` de cada plano: los de bioma no entran en la tanda de siempre, porque solo salen por `_drop_biome_material()`.

Donde `_die()` rellena `death_info` (hoy con `"material": last_material_drop.duplicate()` y `"bonus_material": last_bonus_drop.duplicate()`), añade detrás:

```gdscript
		"biome_material": last_biome_drop.duplicate(),
```

- [ ] **Step 7: Aviso del botín de bioma en la franja**

Hoy, tras integrar la tarjeta de pociones y la rejilla:
- el botín de siempre lo pinta `Corridor._on_enemy_died_fx()` (hacia la línea 379);
- el doble de la Suerte lo pinta `CombatController._show_bonus_loot()` (hacia la línea 318), que pasa por `CombatController._material_info()` al método privado `Corridor._material_info()`, emite desde fuera la señal `loot_dropped` del pasillo y la emite antes que la del primer botín (`_on_enemy_died` la llama antes de que el `Corridor` reciba la muerte).

**Ruling (integración de pociones):** los tres botines (el de siempre, el doble y el de bioma) los presenta el `Corridor`, en un solo sitio y en orden.
- Mueve `_show_bonus_loot()` y sus constantes (`BONUS_LOOT_AHEAD`, `BONUS_LOOT_SPEED` y `BONUS_LOOT_SOUND_LAG`) de `CombatController` a `Corridor`. En el `Corridor` queda así (usa su `fx`, su `FLOOR_Y`, su `_material_info` y su señal):

```gdscript
## Segunda tanda de la Poción de Suerte, igual que la primera: icono con "+15 material" que sale del enemigo,
## aviso loot_dropped para el HUD ("bonus": true) y tintineo. El material ya está en el inventario (lo mete Enemy).
func _show_bonus_loot(info: Dictionary) -> void:
	var md: Dictionary = info.get("bonus_material", {})
	if md.is_empty():
		return
	var pos: Vector2 = info.get("pos", Vector2.ZERO)
	var delay: float = 0.3 if info.get("boss", false) else 0.12  # el mismo que el primer botín
	var mat := _material_info(StringName(md.get("item_id", "")))
	var vx := randf_range(BONUS_LOOT_SPEED.x, BONUS_LOOT_SPEED.y)
	fx.loot_pop(pos + Vector2(2.0 + BONUS_LOOT_AHEAD, -4), mat.get("icon"), "+%d %s" % [int(md.get("quantity", 0)), tr(mat.get("name", ""))], Color(1, 0.93, 0.7), delay, FLOOR_Y, vx, 1)
	loot_dropped.emit(&"material", pos, {"id": md.get("item_id", ""), "quantity": md.get("quantity", 0), "bonus": true})
	get_tree().create_timer(delay + BONUS_LOOT_SOUND_LAG).timeout.connect(func(): Sfx.play(&"loot_coins"))
```

- En `CombatController`, borra `_show_bonus_loot()`, sus tres constantes, `_material_info()` y la llamada `if enemy: _show_bonus_loot(enemy.death_info)` de `_on_enemy_died` (con su comentario). Antes, comprueba con `grep -n "_material_info\|BONUS_LOOT" scripts/gameplay/CombatController.gd` que nada más los usa.
- En `Corridor._on_enemy_died_fx()`, tras el bloque del material de siempre (`loot_pop` + `loot_dropped` + tintineo), añade (el nombre del material pasa por `tr()`, como en el bloque de siempre):

```gdscript
	_show_bonus_loot(info)
	var bd: Dictionary = info.get("biome_material", {})
	if not bd.is_empty():
		var bmat := _material_info(StringName(bd.get("item_id", "")))
		var bdelay := (0.3 if was_boss else 0.12) + 0.18
		# Fila 2 de etiqueta: el de siempre usa la 0 y el doble de la Suerte la 1, así no se pisan
		fx.loot_pop(pos + Vector2(8, -8), bmat.get("icon"), "+%d %s" % [int(bd.get("quantity", 0)), tr(bmat.get("name", ""))], Color(0.8, 0.95, 1.0), bdelay, FLOOR_Y, NAN, 2)
		loot_dropped.emit(&"material", pos, {"id": bd.get("item_id", ""), "quantity": bd.get("quantity", 0), "biome": true})
		get_tree().create_timer(bdelay + 0.1).timeout.connect(func(): Sfx.play(&"loot_coins"))
```

Comprueba antes la firma de `loot_pop` (`grep -n "func loot_pop" scripts -r`): el plan cuenta con `(pos, icon, text, color, delay, floor_y, vx, row)`, como la usa hoy `_show_bonus_loot`. Las pruebas de GameplayTests que miran el botín doble tienen que seguir en verde sin tocarlas; si alguna llamaba a `CombatController._show_bonus_loot`, apúntala al `Corridor`.

`_material_info()` ya lee el nombre y el icono de `data/materials/<id>.tres`. Si la tarjeta de idioma lo cambió para traducir el nombre, el material de bioma usa el mismo camino.

El orden de materiales de `HUDMinigameLauncher.gd` (que cita el spec, apartado 11) es de escenas sin uso (`HUD.tscn` y `HUD_Forge.tscn`, en la tarjeta de limpieza), así que no se toca. En la interfaz viva, los materiales se ven en las tarjetas de pedido (`MaterialIcon`) y en la tienda. La tienda no vende los de bioma.

- [ ] **Step 8: Ejecutar y ver que pasa**

Run: RankTests, InventoryGridTests, GameplayTests, PixelTests y TextTests, y `python -m unittest discover tools/pixel_art/tests`.
Expected: 0 fallos en todas.

- [ ] **Step 9: Commit**

```bash
git add tools/pixel_art/materials.py tools/pixel_art/tests/test_materials.py tools/pixel_art/export.py art/sprites/pixel/materials data/materials/bone.tres data/materials/moss.tres data/materials/obsidian.tres data/materials/frost.tres data/materials/void_shard.tres scripts/MaterialIcon.gd scripts/gameplay/Enemy.gd scripts/gameplay/Corridor.gd scripts/gameplay/CombatController.gd scripts/tests/RankTests.gd scripts/tests/GameplayTests.gd locale/textos.csv
git commit -m "feat: materiales de bioma (hueso, musgo, obsidiana, escarcha y vacío) y botín por ciclo"
```

---

### Task 5: Rango en el objeto forjado

**Ya hecho** (con la rejilla y la calibración): `CraftedItem.rank`, `get_name_with_rank()`, `get_sell_price()` con `Ranks.gold_mult(rank)`, y `rank` en `to_dict()` y `from_dict()`, junto a los campos de la rejilla (`place`, `x`, `y`, `rot` y `aristas`). Falta que el rango cambie las estadísticas al forjar y que se vea en el nombre visible.

**Files:**
- Modify: `scripts/data/CraftedItem.gd`
- Test: `scripts/tests/RankTests.gd`

**Interfaces:**
- Consumes: `Ranks.scale_stats`, `Ranks.suffix`
- Produces:
  - `CraftedItem.new(item_res: ItemResource, craft_quality: float, craft_rank: int = 1)`, con `calculated_stats` ya escaladas por el rango;
  - `CraftedItem.get_display_name()`, que devuelve "Espada maestra III (93%)";
  - `from_dict()` pasa el rango al constructor (1 si falta).

- [ ] **Step 1: Pruebas que fallan**

```gdscript
# ─── Tarea 5: objeto forjado con rango ─────────────────────────────────

func test_crafted_item_has_rank_and_scaled_stats() -> void:
	var res: ItemResource = load("res://data/items/sword_masterwork.tres")
	var one := CraftedItem.new(res, 0.9)
	var three := CraftedItem.new(res, 0.9, 3)
	check(one.rank == 1 and three.rank == 3, "el rango se guarda en el objeto")
	check(three.calculated_stats.damage == roundi(one.calculated_stats.damage * Ranks.stat_mult(3)), "el daño escala con el rango")
	check(is_equal_approx(three.calculated_stats.crit, one.calculated_stats.crit), "el crítico no escala")
	check(three.get_name_with_rank().ends_with(" III") and not one.get_name_with_rank().ends_with(" I"), "numeral solo desde el II (%s / %s)" % [one.get_name_with_rank(), three.get_name_with_rank()])
	check(three.get_display_name().contains("III") and three.get_display_name().contains("90%"), "el nombre visible lleva numeral y calidad (%s)" % three.get_display_name())


func test_crafted_item_rank_survives_save() -> void:
	var res: ItemResource = load("res://data/items/helmet_master.tres")
	var item := CraftedItem.new(res, 0.7, 2)
	item.place = InventoryManager.PLACE_BAG
	item.cell = Vector2i(2, 1)
	item.rot = 3
	var ar: Array[Vector2i] = [Vector2i(3, 0)]
	item.aristas = ar
	var back := CraftedItem.from_dict(JSON.parse_string(JSON.stringify(item.to_dict())), res)  # como desde el fichero
	check(back.rank == 2 and back.calculated_stats.hp == item.calculated_stats.hp and back.calculated_stats.armor == item.calculated_stats.armor, "rango y estadísticas vuelven igual")
	check(back.place == item.place and back.cell == item.cell and back.rot == item.rot and back.aristas == item.aristas, "y su sitio, casilla, giro y aristas (%s %s %d %s)" % [back.place, back.cell, back.rot, back.aristas])
	var old := item.to_dict()
	old.erase("rank")
	check(CraftedItem.from_dict(old, res).rank == 1, "un objeto sin rango (versión 1) es de rango I")
```

El viaje por `JSON` es el del fichero: los enteros vuelven como decimales y las aristas como pares.

Run RankTests. Expected: error de análisis (`CraftedItem.new` con tres argumentos).

- [ ] **Step 2: Implementar en `CraftedItem.gd`**

`_init`:

```gdscript
func _init(item_res: ItemResource, craft_quality: float, craft_rank: int = 1) -> void:
	item_resource = item_res
	quality = clampf(craft_quality, 0.0, 1.0)
	rank = maxi(1, craft_rank)
	crafted_timestamp = Time.get_ticks_msec()

	if item_resource:
		calculated_stats = Ranks.scale_stats(item_resource.calculate_stats(quality), rank)
```

`get_display_name()` usa el nombre con numeral (la traducción ya la hace `get_name_with_rank()`):

```gdscript
## Nombre del objeto con su rango y su calidad, en el idioma del jugador ("Espada maestra III (93%)")
func get_display_name() -> String:
	if item_resource:
		return "%s (%d%%)" % [get_name_with_rank(), get_quality_percent()]
	return tr("Objeto desconocido")
```

En `from_dict()`, el rango va al constructor y sobra la línea que lo asignaba después. El principio queda así (lo demás, igual):

```gdscript
static func from_dict(data: Dictionary, item_res: ItemResource) -> CraftedItem:
	var item = CraftedItem.new(item_res, data.get("quality", 0.5), maxi(1, int(data.get("rank", 1))))
	item.calculated_stats = data.get("stats", {}).duplicate()
	item.crafted_timestamp = data.get("timestamp", 0)
	item.place = StringName(data.get("place", "loot"))
```

(Las estadísticas guardadas mandan: una pieza ya forjada no se recalcula al cargar.)

`to_dict()` no cambia: ya guarda `"rank"`.

Quien cree hoy piezas con `CraftedItem.new(res, q)` y les ponga el rango después (`InventoryGridTests`, la prueba de la tarea 0) sigue funcionando: el rango sin escalar las estadísticas solo se usa en pruebas.

- [ ] **Step 3: Ejecutar y ver que pasa**

Run: RankTests, InventoryGridTests, GameplayTests y PixelTests. Expected: 0 fallos.

- [ ] **Step 4: Commit**

```bash
git add scripts/data/CraftedItem.gd scripts/tests/RankTests.gd
git commit -m "feat: el objeto forjado escala sus estadísticas con su rango y lo enseña en su nombre"
```

---

### Task 6: Desbloqueo por rango y guardado versión 3

La versión 2 la tomó el inventario en rejilla, así que los rangos pasan a la 3. Hay dos orígenes:
- **Versión 1** (antes de la rejilla): `InventoryManager` migra el inventario como siempre (rejilla, aristas y `GearPacker`), y los planos desbloqueados pasan a rango I.
- **Versión 2** (la rejilla): el inventario ya está en rejilla y sus piezas guardan `rank` (siempre 1). Solo se migran los planos: `unlocked_blueprints` pasa a `unlocked_ranks` con rango I.
- Desde las dos, después, se aplican los hitos del récord.

`SaveManager` no necesita código por versión: cada autoload reconoce la forma de sus datos (`InventoryManager`, si falta `hero_grid`; `DataManager`, si falta `unlocked_ranks`). Lo que sí cambia es la copia de la partida antigua: hoy va siempre a `save.v1.bak.json`, y una partida de la versión 2 acabaría con el nombre de la 1. Pasa a `save.v<versión de origen>.bak.json`, solo si esa copia no existe.

No hay rango de pedidos ni de tareas que guardar: `CraftingManager` no se guarda y `RequestsManager` solo guarda `free_requests_remaining`.

**Files:**
- Modify:
  - `scripts/autoload/DataManager.gd`, `scripts/autoload/GameManager.gd` (`apply_record_milestones`, `_on_data_ready_load_save`), `scripts/core/SaveManager.gd`;
  - `scripts/tests/TestSuite.gd` (protege también `save.v2.bak.json`), `scripts/tests/InventoryGridTests.gd` (textos de la versión);
  - `doc/specs/2026-09-27-rangos-de-plano-por-ciclo.md` (apartados 8 y 10).
- Create: `scripts/tests/fixtures/save_v1.json`
- Test: `scripts/tests/RankTests.gd`

**Interfaces:**
- Consumes: `Ranks.tier_from_rarity`, `Ranks.milestones_up_to_record`, `Ranks.TIERS`
- Produces:
  - Estado: `DataManager.unlocked_ranks: Dictionary` (id → int, con 0 = bloqueado).
  - Consultas: `DataManager.get_unlocked_rank(bp_id: StringName) -> int`, `DataManager.is_blueprint_unlocked(bp_id)` (rango ≥ 1) y `DataManager.get_unlocked_blueprints() -> Array` (ids con rango ≥ 1).
  - Cambios: `DataManager.unlock_rank(bp_id: StringName, rank: int) -> bool`, que da true si sube.
  - Niveles de pieza: `DataManager.blueprint_tier(bp_id: StringName) -> StringName` y `DataManager.get_blueprint_ids_for_tier(tier: StringName) -> Array[StringName]`.
  - Hitos: `DataManager.apply_milestones(milestones: Array) -> Array`, que devuelve los desbloqueos nuevos (`{"id": StringName, "rank": int}`) sin emitir nada, y `GameManager.apply_record_milestones() -> Array`.
  - Guardado: `SaveManager.SAVE_VERSION`, que pasa a 3; `SaveManager.backup_path(version: int) -> String` (`"user://save.v1.bak.json"`, `"user://save.v2.bak.json"`…), que sustituye a `BACKUP_V1_PATH`.
  - Pruebas: `TestSuite.V2_BACKUP_PATH` y `TestSuite.OLD_SAVE_BACKUPS` (las dos copias).
- Se quita `DataManager.DEFAULT_UNLOCKED`. `unlock_blueprint(id)` se conserva como `unlock_rank(id, 1)` por compatibilidad.

- [ ] **Step 1: Partida de versión 1 para la prueba**

`scripts/tests/fixtures/save_v1.json` (una partida anterior a la rejilla: récord 57, espada maestra equipada, planos del sistema antiguo). El cargador de la versión 1 de `InventoryManager` la acepta tal cual: sin `hero_grid`, con `equipped` y `equipped_slots`, y con las estadísticas guardadas.

```json
{
	"version": 1,
	"timestamp": 1790000000.0,
	"game": {
		"current_enemy_level": 12,
		"best_enemy_level": 57,
		"death_count": 3,
		"enemies_defeated": {"1": true, "2": true, "3": true},
		"hero_loadout": {"weapon": "", "armor": "", "shield": "", "trinket": ""}
	},
	"data": {
		"unlocked_blueprints": {
			"sword_basic": true, "shield_basic": true, "boots_basic": true, "helmet_basic": false,
			"sword_advanced": true, "shield_advanced": false, "helmet_advanced": false, "boots_advanced": false,
			"sword_masterwork": true, "shield_master": false, "helmet_master": false, "boots_master": false
		}
	},
	"inventory": {
		"materials": {"iron": 50, "wood": 20, "gold": 300},
		"crafted_items": [
			{"item_id": "sword_masterwork", "quality": 0.93, "stats": {"damage": 34, "str": 0, "agi": 0, "int": 0, "hp": 0, "armor": 0, "crit": 0.4325, "aps": 0.6755}, "timestamp": 1000, "equipped": true}
		],
		"equipped_slots": {"main_hand": 0}
	},
	"requests": {"free_requests_remaining": 0}
}
```

Con el récord 57, la migración del inventario da las 4 ampliaciones (rejilla de 6×6) y `GearPacker` coloca la espada en Tico.

- [ ] **Step 2: Pruebas que fallan**

```gdscript
# ─── Tarea 6: desbloqueo por rango y guardado v3 ───────────────────────

func _dm() -> Node:
	return get_node("/root/DataManager")


func test_blueprint_tiers() -> void:
	var dm := _dm()
	check(dm.blueprint_tier(&"sword_masterwork") == Ranks.TIER_MASTER and dm.blueprint_tier(&"boots_basic") == Ranks.TIER_BASIC, "nivel de pieza de cada plano")
	for tier in Ranks.TIERS:
		check(dm.get_blueprint_ids_for_tier(tier).size() == 4, "4 planos de nivel %s" % tier)


func test_unlock_rank_only_goes_up() -> void:
	var dm := _dm()
	var saved: Dictionary = dm.unlocked_ranks.duplicate()
	dm.unlocked_ranks[&"sword_basic"] = 0
	check(not dm.is_blueprint_unlocked(&"sword_basic"), "rango 0 = bloqueado")
	check(dm.unlock_rank(&"sword_basic", 2) and dm.get_unlocked_rank(&"sword_basic") == 2, "sube a II")
	check(not dm.unlock_rank(&"sword_basic", 1) and dm.get_unlocked_rank(&"sword_basic") == 2, "no baja")
	for id in dm.get_blueprint_ids_for_tier(Ranks.TIER_BASIC):
		if id != &"sword_basic":
			dm.unlocked_ranks[id] = 1
	var newly: Array = dm.apply_milestones([{"rank": 2, "tier": Ranks.TIER_BASIC}])
	check(newly.size() == 3, "los otros 3 básicos suben a II (%s)" % [newly])
	dm.unlocked_ranks = saved


## Copias de la partida antigua que había antes de una prueba (ruta → bytes, o null si no había). Las pruebas de
## migración las crean al cargar una partida vieja; al acabar se dejan como estaban (TestSuite lo repite al final).
func _snapshot_backups() -> Dictionary:
	var out := {}
	for path in OLD_SAVE_BACKUPS:
		out[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
	return out


func _restore_backups(snap: Dictionary) -> void:
	for path in snap:
		if snap[path] == null:
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		else:
			var f := FileAccess.open(path, FileAccess.WRITE)
			f.store_buffer(snap[path])
			f.close()


## Escribe `bytes` como save.json y lo carga, sin copias de la partida antigua delante (para ver la que hace esta carga).
func _load_save_bytes(bytes: PackedByteArray) -> bool:
	for path in OLD_SAVE_BACKUPS:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_buffer(bytes)
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


func test_v1_save_with_high_record_migrates() -> void:
	var dm := _dm()
	var inv := _im()
	var backups := _snapshot_backups()
	var original := FileAccess.get_file_as_bytes("res://scripts/tests/fixtures/save_v1.json")
	check(_load_save_bytes(original), "la partida v1 carga")
	check(dm.get_unlocked_rank(&"sword_advanced") >= 1 and dm.get_unlocked_rank(&"sword_masterwork") >= 1, "lo ya desbloqueado se conserva")
	check(dm.get_unlocked_rank(&"helmet_basic") == 2, "el récord 57 aplica los básicos II (casco básico: %d)" % dm.get_unlocked_rank(&"helmet_basic"))
	check(dm.get_unlocked_rank(&"helmet_master") == 1, "el récord 57 aplica los maestros I")
	var items: Array = inv.get_crafted_items()
	check(items.size() == 1 and items[0].rank == 1 and items[0].calculated_stats.damage == 34, "la espada pasa a rango I con sus estadísticas")
	check(items.size() == 1 and items[0].place == InventoryManager.PLACE_HERO and inv.best_hero_item("main_hand") == items[0], "y la que estaba equipada va a la rejilla de Tico")
	check(FileAccess.file_exists(V1_BACKUP_PATH) and FileAccess.get_file_as_bytes(V1_BACKUP_PATH) == original, "la copia save.v1.bak.json guarda la partida original")
	check(not FileAccess.file_exists(V2_BACKUP_PATH), "y no hace la de la versión 2")
	check(SaveManager.save_game(), "se guarda en la versión nueva")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	check(int(data.version) == 3 and data.data.has("unlocked_ranks") and not data.data.has("unlocked_blueprints"), "guardado versión 3 con unlocked_ranks")
	await _reload_user_save()
	_restore_backups(backups)


## Partida de la versión 2 (la rejilla, antes de los rangos), con la forma que escriben InventoryManager.to_save_data() y
## DataManager: récord 25, una ampliación (rejilla de 5×4), una espada con una arista en Tico y un casco en el botín.
func _v2_save() -> Dictionary:
	var sword := CraftedItem.new(load("res://data/items/sword_advanced.tres"), 0.8).to_dict()
	sword.merge({"place": "hero", "x": 2, "y": 1, "rot": 0, "aristas": [[1, 0]], "timestamp": 2001}, true)
	var helmet := CraftedItem.new(load("res://data/items/helmet_basic.tres"), 0.4).to_dict()
	helmet.merge({"place": "loot", "timestamp": 2002}, true)
	return {
		"version": 2,
		"timestamp": 1790000000.0,
		"game": {"current_enemy_level": 24, "best_enemy_level": 25, "wall_room": 0, "room_locked": false, "death_count": 1, "enemies_defeated": {}, "hero_loadout": {}},
		"data": {"unlocked_blueprints": {"sword_basic": true, "shield_basic": true, "boots_basic": true, "helmet_basic": false, "sword_advanced": true}},
		"inventory": {
			"materials": {"iron": 40, "gold": 120},
			"crafted_items": [helmet, sword],
			"hero_grid": [5, 4],
			"expansions": ["grid_bone_straps"],
			"consumables": [],
		},
		"requests": {"free_requests_remaining": 0},
	}


func test_v2_save_migrates_to_v3() -> void:
	var dm := _dm()
	var inv := _im()
	var backups := _snapshot_backups()
	var original := JSON.stringify(_v2_save()).to_utf8_buffer()
	check(_load_save_bytes(original), "la partida v2 carga")
	check(inv.hero_grid_size() == Vector2i(5, 4) and inv.get_crafted_items().size() == 2, "rejilla de 5×4 y las dos piezas (%s, %d)" % [inv.hero_grid_size(), inv.get_crafted_items().size()])
	var sword: CraftedItem = inv.best_hero_item("main_hand")
	check(sword != null and sword.cell == Vector2i(2, 1) and sword.rot == 0 and sword.aristas == [Vector2i(1, 0)], "la espada sigue en Tico, en su casilla, con su arista")
	check(inv.get_loot().size() == 1 and inv.get_loot()[0].item_resource.item_id == &"helmet_basic", "el casco sigue en el botín")
	check(inv.get_crafted_items().all(func(it): return it.rank == 1), "las piezas siguen en rango I")
	check(dm.get_unlocked_rank(&"sword_advanced") == 1 and dm.get_unlocked_rank(&"shield_basic") == 1, "los planos desbloqueados pasan a rango I")
	check(dm.get_unlocked_rank(&"helmet_basic") == 1, "los básicos I, siempre")
	check(dm.get_unlocked_rank(&"helmet_advanced") == 1 and dm.get_unlocked_rank(&"helmet_master") == 0, "récord 25: los avanzados I sí (jefe 20) y los maestros aún no (%d, %d)" % [dm.get_unlocked_rank(&"helmet_advanced"), dm.get_unlocked_rank(&"helmet_master")])
	check(FileAccess.file_exists(V2_BACKUP_PATH) and FileAccess.get_file_as_bytes(V2_BACKUP_PATH) == original, "la copia save.v2.bak.json guarda la partida original")
	check(not FileAccess.file_exists(V1_BACKUP_PATH), "y no hace la de la versión 1")
	check(SaveManager.save_game(), "se guarda")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	check(int(data.version) == 3 and data.data.has("unlocked_ranks") and data.inventory.has("hero_grid"), "versión 3, con unlocked_ranks y la rejilla")
	await _reload_user_save()
	_restore_backups(backups)
```

`helmet_master == 0` pide que cargar una partida bloquee antes todo lo que ella no trae (Step 3): si no, quedarían los rangos de la partida que hubiera cargada.

Run RankTests. Expected: error de análisis (`V2_BACKUP_PATH` y `OLD_SAVE_BACKUPS` no existen). Con el Step 6 hecho y sin los demás, fallan (`blueprint_tier`, `unlocked_ranks` y la versión 3 no existen).

- [ ] **Step 3: `DataManager.gd` por rangos**

Sustituye `unlocked_blueprints` y `DEFAULT_UNLOCKED` y las funciones de desbloqueo. El estado inicial es todo a 0: los básicos I los dan los hitos del récord al cargar o al empezar (Steps 4 y 5).

```gdscript
var blueprints: Dictionary = {}
var unlocked_ranks: Dictionary = {}  # blueprint_id -> rango máximo desbloqueado (0 = bloqueado)
var _tiers: Dictionary = {}  # blueprint_id -> Ranks.TIER_* (desde la rareza de su objeto)
```

En `_load_blueprint_library()`, en lugar de inicializar `unlocked_blueprints`:

```gdscript
		blueprints[key] = blueprint
		unlocked_ranks[key] = 0
		var item := get_item_resource(blueprint.result_item)
		_tiers[key] = Ranks.tier_from_rarity(item.rarity if item else "basic")
```

Funciones (sustituyen a `is_blueprint_unlocked`, `unlock_blueprint`, `get_unlocked_blueprints` y `get_locked_blueprints`):

```gdscript
func get_unlocked_rank(bp_id: StringName) -> int:
	return int(unlocked_ranks.get(bp_id, 0))


func is_blueprint_unlocked(bp_id: StringName) -> bool:
	return get_unlocked_rank(bp_id) >= 1


## Sube el rango desbloqueado de un plano. true si ha subido (nunca baja).
func unlock_rank(bp_id: StringName, rank: int) -> bool:
	if bp_id not in blueprints:
		push_warning("DataManager: Cannot unlock unknown blueprint '%s'" % bp_id)
		return false
	if rank <= get_unlocked_rank(bp_id):
		return false
	unlocked_ranks[bp_id] = rank
	return true


## Compatibilidad: desbloquear sin rango es desbloquear el rango I.
func unlock_blueprint(bp_id: StringName) -> bool:
	return unlock_rank(bp_id, 1)


func get_unlocked_blueprints() -> Array:
	var result := []
	for bp_id in unlocked_ranks:
		if unlocked_ranks[bp_id] >= 1:
			result.append(bp_id)
	return result


func get_locked_blueprints() -> Array:
	var result := []
	for bp_id in unlocked_ranks:
		if unlocked_ranks[bp_id] <= 0:
			result.append(bp_id)
	return result


func blueprint_tier(bp_id: StringName) -> StringName:
	return _tiers.get(bp_id, Ranks.TIER_BASIC)


func get_blueprint_ids_for_tier(tier: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for bp_id in blueprints:
		if blueprint_tier(bp_id) == tier:
			out.append(bp_id)
	return out


## Aplica hitos ({"rank", "tier"}) sin emitir señales. Devuelve los desbloqueos nuevos: [{"id", "rank"}].
func apply_milestones(milestones: Array) -> Array:
	var newly := []
	for ms in milestones:
		for bp_id in get_blueprint_ids_for_tier(ms.tier):
			if unlock_rank(bp_id, int(ms.rank)):
				newly.append({"id": bp_id, "rank": int(ms.rank)})
	return newly
```

Guardado, compatible con las versiones 1 y 2. Cargar una partida la sustituye entera: primero todo bloqueado y después lo suyo.

```gdscript
func to_save_data() -> Dictionary:
	var ranks := {}
	for bp_id in unlocked_ranks:
		ranks[String(bp_id)] = unlocked_ranks[bp_id]
	return {"unlocked_ranks": ranks}


func load_save_data(data: Dictionary) -> void:
	# La partida sustituye a lo que hubiera; los hitos de su récord los aplica SaveManager después
	for bp_id in unlocked_ranks:
		unlocked_ranks[bp_id] = 0
	if data.has("unlocked_ranks"):
		var saved: Dictionary = data.get("unlocked_ranks", {})
		for bp_id_str in saved:
			var bp_id := StringName(bp_id_str)
			if bp_id in unlocked_ranks:
				unlocked_ranks[bp_id] = maxi(0, int(saved[bp_id_str]))
	else:
		# Versiones 1 y 2: planos desbloqueados como bool → rango I
		var old: Dictionary = data.get("unlocked_blueprints", {})
		for bp_id_str in old:
			var bp_id := StringName(bp_id_str)
			if bp_id in unlocked_ranks and bool(old[bp_id_str]):
				unlocked_ranks[bp_id] = 1
	print("DataManager: Loaded %d unlocked blueprints from save" % get_unlocked_blueprints().size())
```

Antes de cerrar el paso, `grep -rn "unlocked_blueprints\|DEFAULT_UNLOCKED" scripts`. Quedan dos usos, y ninguno se toca aquí:
- `VisualCapture._run_unlock_plan` (lo reescribe la tarea 7);
- la partida de la versión 1 de `InventoryGridTests._v1_save()` (`"data": {"unlocked_blueprints": {}}`), que `load_save_data` sigue leyendo.

- [ ] **Step 4: Hitos del récord sin partida (`GameManager.gd`)**

```gdscript
## Aplica en silencio los hitos que ya supera el récord (los básicos I siempre). Lo llama SaveManager.load_game() al
## cargar una partida (también al migrarla) y _on_data_ready_load_save() cuando no hay partida.
func apply_record_milestones() -> Array:
	var dm = get_node_or_null("/root/DataManager")
	if dm == null or not dm.has_method("apply_milestones"):
		return []
	return dm.apply_milestones(Ranks.milestones_up_to_record(best_enemy_level))
```

En `_on_data_ready_load_save()`, al final:

```gdscript
	# Sin partida (o si no se pudo leer) no hay nada desbloqueado: los hitos del récord dan al menos los básicos I.
	# Con partida ya los ha aplicado SaveManager.load_game().
	if not _save_loaded:
		apply_record_milestones()
```

`GameManager` va antes que `RequestsManager` en los autoloads, y los dos conectan `data_ready` en su `_ready` (que `DataManager` emite en diferido). Así los básicos ya están desbloqueados cuando `RequestsManager` genera los primeros pedidos. Compruébalo en el Step 8.

- [ ] **Step 5: `SaveManager.gd` versión 3**

Constantes (sustituyen a `BACKUP_V1_PATH`; `grep -rn "BACKUP_V1_PATH" scripts` solo da `SaveManager`):

```gdscript
const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 3


## Copia de la partida tal como estaba antes de migrarla desde la versión `version`: save.v1.bak.json, save.v2.bak.json…
## Una partida sin versión cuenta como de la 1.
static func backup_path(version: int) -> String:
	return "user://save.v%d.bak.json" % maxi(1, version)
```

En `load_game()`, la copia pasa a saber la versión de origen:

```gdscript
	var version: int = int(save_data.get("version", 0))
	if version < SAVE_VERSION:
		print("SaveManager: partida de la versión %d; se migra a la %d al cargar" % [version, SAVE_VERSION])
		_back_up_old_save(version)
	elif version > SAVE_VERSION:
		push_warning("SaveManager: partida de una versión más nueva (%d > %d). Se intenta cargar igualmente." % [version, SAVE_VERSION])
```

Y después de `gm.load_save_data(...)` (antes de `RequestsManager`):

```gdscript
	# Hitos de rango que ya supera el récord (spec de rangos, apartado 3). Van después de GameManager, que deja el récord
	# en el mayor entre el guardado y la sala actual. En una partida anterior a los rangos convierten el récord en planos.
	if gm and gm.has_method("apply_record_milestones"):
		gm.apply_record_milestones()
```

`_back_up_old_save`:

```gdscript
## Copia save.json en save.v<versión>.bak.json antes de que el guardado diferido de después de cargar lo reescriba en la
## versión nueva: la partida es una sola y la comparten todas las compilaciones del juego, así que esa escritura no se
## deshace. Una copia por versión de origen, y solo la primera vez: una migración posterior nunca la pisa.
static func _back_up_old_save(version: int) -> void:
	var path := backup_path(version)
	if FileAccess.file_exists(path):
		return
	var err := DirAccess.copy_absolute(SAVE_PATH, path)
	if err != OK:
		push_warning("SaveManager: no se pudo copiar la partida antigua a %s (error %d)" % [path, err])
		return
	print("SaveManager: copia de la partida antigua en %s" % path)
```

- [ ] **Step 6: `TestSuite` protege las dos copias y textos de `InventoryGridTests`**

En `TestSuite.gd`, las constantes y el estado de la copia pasan a cubrir las dos versiones:

```gdscript
const SAVE_PATH := "user://save.json"
const V1_BACKUP_PATH := "user://save.v1.bak.json"
const V2_BACKUP_PATH := "user://save.v2.bak.json"
## Copias que SaveManager hace al migrar, una por versión de origen (SaveManager.backup_path). Una prueba que carga una
## partida antigua las crearía con datos de pega: la suite las deja como estaban.
const OLD_SAVE_BACKUPS := [V1_BACKUP_PATH, V2_BACKUP_PATH]
const TEST_LOCALE := "es"

var _checks := 0
var _failures := 0
var _had_save := false
var _save_backup := PackedByteArray()
var _old_backups := {}  # ruta → bytes de cada copia que había al empezar (sin la ruta si no había)
```

```gdscript
func _backup_save() -> void:
	_had_save = FileAccess.file_exists(SAVE_PATH)
	if _had_save:
		_save_backup = FileAccess.get_file_as_bytes(SAVE_PATH)
	_old_backups.clear()
	for path in OLD_SAVE_BACKUPS:
		if FileAccess.file_exists(path):
			_old_backups[path] = FileAccess.get_file_as_bytes(path)


func _restore_save() -> void:
	if _had_save:
		var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		f.store_buffer(_save_backup)
		f.close()
	elif FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	# Las copias de la partida antigua quedan como estaban: con la que hubiera (la buena, hecha al arrancar) o sin ninguna
	for path in OLD_SAVE_BACKUPS:
		if _old_backups.has(path):
			var b := FileAccess.open(path, FileAccess.WRITE)
			b.store_buffer(_old_backups[path])
			b.close()
		elif FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
```

En la cabecera del fichero, «y la copia save.v1.bak.json que SaveManager hace al migrar» pasa a «y las copias save.v1.bak.json y save.v2.bak.json que SaveManager hace al migrar». `grep -rn "_had_v1_backup\|_v1_backup_bytes" scripts` no debe dar nada.

En `InventoryGridTests.gd`, solo textos (las comprobaciones ya usan `SaveManager.SAVE_VERSION`):
- en `test_v1_save_migrates_without_losing_pieces`: `"guardado versión 2, sin huecos fijos"` pasa a `"guardado en la versión actual, sin huecos fijos"`; el comentario `# El fichero de la versión 2 también se carga: …` pasa a `# El fichero de la versión actual también se carga: …`; y `"se carga el fichero de la versión 2"` pasa a `"se carga el fichero de la versión actual"`;
- en el comentario de `test_loading_an_old_save_keeps_a_backup_of_it`: «la reescriba en la versión 2» pasa a «la reescriba en la versión actual», y «Con la partida ya en la versión 2 no hace copia» pasa a «Con la partida ya en la versión actual no hace copia».

Esa prueba sigue con `V1_BACKUP_PATH` y la partida de la versión 1: la copia de la 1 no cambia de nombre. Al final llama a `_reload_user_save()`, que carga la partida de la sesión; si esa partida es de la versión 2, la carga crea `save.v2.bak.json`, y `TestSuite` la deja como estaba al acabar.

- [ ] **Step 7: El spec dice «versión 3»**

En `doc/specs/2026-09-27-rangos-de-plano-por-ciclo.md`, apartado 8, sustituye la lista de «Datos que ganan rango» y el punto «Guardado versión 2»:

```markdown
- **Datos que ganan rango:**
  - `CraftedItem.rank` (1 por defecto): se guarda en `to_dict` y se lee en `from_dict`. Las estadísticas calculadas ya incluyen el multiplicador.
  - `DataManager`: rango máximo desbloqueado por plano.
  - `RequestsManager`: el rango de cada pedido activo. No se guarda: hoy `RequestsManager` solo guarda `free_requests_remaining` y los pedidos se rehacen al arrancar.
  - `CraftingManager`: el rango y el origen de cada tarea. Tampoco se guarda: la cola no se guarda.
- **Guardado versión 3** (`SaveManager.SAVE_VERSION`; la 2 es la del inventario en rejilla), con migración desde la 1 y desde la 2:
  - desde la 1, el inventario se migra a la rejilla como dice el spec del inventario (apartado 10) y los objetos forjados pasan a rango I;
  - desde la 2, las piezas ya guardan su rango (1) y no se mueven;
  - en las dos, los planos desbloqueados se conservan como rango I;
  - después se aplican los hitos que ya supera el récord (apartado 3);
  - antes de migrar, `SaveManager` copia la partida en `save.v<versión de origen>.bak.json`, solo si esa copia no existe.
```

En el apartado 10, la línea de la prueba de guardado pasa a:

```markdown
  - Guardado: una partida de versión 1 (fichero de prueba) y otra de versión 2 cargan en la versión 3 sin perder objetos ni planos, con los hitos del récord aplicados y la copia de cada una.
```

- [ ] **Step 8: Ejecutar y ver que pasa, y arranque real**

Run: RankTests, InventoryGridTests, GameplayTests y PixelTests. Expected: 0 fallos.

Arranque real. Cualquier ejecución anterior ya migró la partida de la carpeta temporal (la carga del arranque la reescribe en la versión 3), así que antes vuelve a copiar la partida real (Global Constraints) y borra las copias que haya allí:

```bash
cp "$(cygpath -u "$APPDATA")/Godot/app_userdata/PetJam/save.json" <scratchpad>/appdata/Godot/app_userdata/PetJam/save.json
rm -f <scratchpad>/appdata/Godot/app_userdata/PetJam/save.v1.bak.json <scratchpad>/appdata/Godot/app_userdata/PetJam/save.v2.bak.json
APPDATA=<appdata> timeout 120 D:/Software/Godot/godot_ver4.5.exe --headless --path . --quit-after 600 res://scenes/Main.tscn 2>&1 | grep -iE "SCRIPT ERROR|Parse Error|SaveManager|DataManager: Loaded|RequestsManager: Generados"
ls <scratchpad>/appdata/Godot/app_userdata/PetJam/
grep -m1 '"version"' <scratchpad>/appdata/Godot/app_userdata/PetJam/save.json
```

Expected:
- sin errores;
- «partida de la versión 2; se migra a la 3» y «copia de la partida antigua en user://save.v2.bak.json»;
- `DataManager: Loaded …` y pedidos generados (`RequestsManager: Generados`) de planos desbloqueados;
- `save.v2.bak.json` en la carpeta, y `"version": 3` en `save.json`.

- [ ] **Step 9: Commit**

```bash
git add scripts/autoload/DataManager.gd scripts/autoload/GameManager.gd scripts/core/SaveManager.gd scripts/tests/TestSuite.gd scripts/tests/InventoryGridTests.gd scripts/tests/RankTests.gd scripts/tests/fixtures/save_v1.json doc/specs/2026-09-27-rangos-de-plano-por-ciclo.md
git commit -m "feat: desbloqueo por rango, hitos del récord y guardado versión 3 con migración desde la 1 y la 2"
```

---

### Task 7: Hitos al vencer a los jefes y avisos en la franja

**Files:**
- Modify: `scripts/autoload/GameManager.gd` (`register_enemy_defeat`, señales), `scripts/gameplay/Corridor.gd` (`_on_blueprint_unlocked`, hito), `scripts/ui/HeroViewOverlay.gd` (cartel), `scripts/tests/VisualCapture.gd` (plan `unlock`)
- Test: `scripts/tests/RankTests.gd`

**Interfaces:**
- Consumes: `Ranks.milestone_for_boss_room`, `Ranks.milestone_text`, `DataManager.apply_milestones`, `Biomes.is_boss_room`
- Produces:
  - `signal blueprints_milestone(rank: int, tier: StringName, ids: Array)` en `GameManager`. Se emite **antes** que los `blueprint_unlocked` del mismo hito.
  - `signal blueprint_unlocked(blueprint_id: StringName, rank: int)`, que ahora lleva el rango.
  - `Corridor.UNLOCK_STAGGER` (0,15 s entre pergaminos de un mismo hito).

**Cambios:**
- Se quita el desbloqueo de un plano al azar por la primera victoria en cada sala.
- `enemies_defeated` y `enemy_defeated_first_time` se conservan: son estadística y no desbloquean nada.
- Detrás de los hitos se conserva tal cual el bloque de la ampliación provisional de la rejilla (`GridExpansions.recipe_for_boss_room`, `_growing_grid` y la señal `grid_expanded`).
- **Jefes 20 y 40:** sale el cartel del hito y, la primera vez, también el aviso «¡La rejilla crece!». No chocan: el de la rejilla es un toast (`show_toast`) y los toasts esperan en cola a que acabe el cartel (`_banner_until`). La captura `unlock` (Step 5) lo comprueba.

- [ ] **Step 1: Pruebas que fallan**

```gdscript
# ─── Tarea 7: hitos al vencer jefes ────────────────────────────────────

func test_boss_milestones_unlock_once_with_signals() -> void:
	var gm := get_node("/root/GameManager")
	var dm := _dm()
	var saved_ranks: Dictionary = dm.unlocked_ranks.duplicate()
	var saved_state: int = gm.dungeon_state
	var saved_best: int = gm.best_enemy_level
	var saved_defeated: Dictionary = gm.enemies_defeated.duplicate()
	for id in dm.unlocked_ranks:
		dm.unlocked_ranks[id] = 0
	dm.apply_milestones([{"rank": 1, "tier": Ranks.TIER_BASIC}])
	gm.dungeon_state = gm.DungeonState.RUNNING
	gm.best_enemy_level = 999  # récord ya pasado: los jefes 20 y 40 no amplían la rejilla de la partida (GridExpansions)
	var milestones := []
	var unlocked := []
	var on_ms := func(rank, tier, ids): milestones.append([rank, tier, ids.size()])
	var on_bp := func(id, rank): unlocked.append([id, rank, milestones.size()])
	gm.blueprints_milestone.connect(on_ms)
	gm.blueprint_unlocked.connect(on_bp)
	gm.register_enemy_defeat(19)
	check(milestones.is_empty() and unlocked.is_empty(), "una sala normal no desbloquea nada")
	gm.register_enemy_defeat(20)
	check(milestones == [[1, Ranks.TIER_ADVANCED, 4]], "el jefe 20 da los 4 avanzados I (%s)" % [milestones])
	check(unlocked.size() == 4 and unlocked.all(func(u): return u[2] == 1), "4 planos, anunciados después del hito")
	gm.register_enemy_defeat(20)
	check(milestones.size() == 1 and unlocked.size() == 4, "volver a vencerlo no repite nada")
	gm.register_enemy_defeat(50)
	check(milestones.back() == [2, Ranks.TIER_BASIC, 4] and dm.get_unlocked_rank(&"sword_basic") == 2, "el jefe 50 abre los básicos II")
	gm.blueprints_milestone.disconnect(on_ms)
	gm.blueprint_unlocked.disconnect(on_bp)
	gm.dungeon_state = saved_state
	gm.best_enemy_level = saved_best
	gm.enemies_defeated = saved_defeated
	dm.unlocked_ranks = saved_ranks


## La ampliación provisional de la rejilla sigue detrás de los hitos: el jefe 20 da a la vez su hito y, la primera vez,
## su ampliación.
func test_boss_20_gives_its_milestone_and_its_grid_expansion() -> void:
	var gm := get_node("/root/GameManager")
	var dm := _dm()
	var saved_inv := _fresh_inventory()
	var saved_ranks: Dictionary = dm.unlocked_ranks.duplicate()
	var saved_state: int = gm.dungeon_state
	var saved_best: int = gm.best_enemy_level
	var saved_defeated: Dictionary = gm.enemies_defeated.duplicate()
	for id in dm.get_blueprint_ids_for_tier(Ranks.TIER_ADVANCED):
		dm.unlocked_ranks[id] = 0
	gm.dungeon_state = gm.DungeonState.RUNNING
	gm.best_enemy_level = 20  # la primera vez que cae el jefe 20
	var events := []
	var on_ms := func(_rank, _tier, _ids): events.append(&"milestone")
	var on_grid := func(_id): events.append(&"grid")
	gm.blueprints_milestone.connect(on_ms)
	gm.grid_expanded.connect(on_grid)
	gm.register_enemy_defeat(20)
	check(events == [&"milestone", &"grid"], "el jefe 20 da el hito y después la ampliación (%s)" % [events])
	check(_im().hero_grid_size() == GridExpansions.size_after(1), "la rejilla crece (%s)" % _im().hero_grid_size())
	gm.blueprints_milestone.disconnect(on_ms)
	gm.grid_expanded.disconnect(on_grid)
	gm.dungeon_state = saved_state
	gm.best_enemy_level = saved_best
	gm.enemies_defeated = saved_defeated
	dm.unlocked_ranks = saved_ranks
	await _restore_inventory(saved_inv)


func test_milestone_shows_one_notice_and_staggers_scrolls() -> void:
	var corridor: Node2D = load("res://scenes/Corridor.tscn").instantiate()
	add_child(corridor)
	await get_tree().process_frame
	var scrolls := []
	corridor.loot_dropped.connect(func(kind, _pos, _payload): if kind == &"blueprint": scrolls.append(Time.get_ticks_msec()))
	var fx: Node = corridor.fx
	var count_texts := func() -> int: return fx._parts.filter(func(p): return p.kind == fx.Kind.TEXT).size()
	var texts_before: int = count_texts.call()
	corridor._on_blueprints_milestone(2, Ranks.TIER_ADVANCED, [&"sword_advanced", &"shield_advanced", &"helmet_advanced", &"boots_advanced"])
	for id in [&"sword_advanced", &"shield_advanced", &"helmet_advanced", &"boots_advanced"]:
		corridor._on_blueprint_unlocked(id, 2)
	check(count_texts.call() == texts_before, "sin un texto flotante por plano (el aviso es el cartel del HUD)")
	await get_tree().create_timer(0.8).timeout
	check(scrolls.size() == 4, "salen los 4 pergaminos (%d)" % scrolls.size())
	check(scrolls.size() == 4 and scrolls[3] - scrolls[0] >= 400, "escalonados, no a la vez (%s ms)" % (scrolls[3] - scrolls[0] if scrolls.size() == 4 else -1))
	corridor.queue_free()
	await get_tree().process_frame
```

`CombatFX` guarda cada efecto en `_parts` con su `kind`; los textos flotantes son `Kind.TEXT`.

Run RankTests. Expected: fallan (`blueprints_milestone` no existe; `_on_blueprint_unlocked` no acepta el rango).

- [ ] **Step 2: `GameManager.gd`**

Señales:

```gdscript
signal blueprint_unlocked(blueprint_id, rank)  # Plano desbloqueado (o subido de rango) por un hito
signal blueprints_milestone(rank, tier, ids)  # Hito de rangos: se emite antes que los blueprint_unlocked
```

En `register_enemy_defeat(level)`, sustituye el bloque que desbloqueaba un plano al azar (desde `# Si es la primera vez que se derrota este nivel` hasta `emit_signal("blueprint_unlocked", StringName(random_bp))`) por el de abajo. El bloque de la rejilla que va detrás (`# Rejilla de Tico …` hasta `emit_signal("grid_expanded", recipe)`) no se toca. La función queda así:

```gdscript
func register_enemy_defeat(level: int) -> void:
	if dungeon_state != DungeonState.RUNNING:
		return
	DebugManager.log_msg(&"game", "Enemy level %d defeated (current: %d)" % [level, current_enemy_level])
	if not enemies_defeated.has(level):
		enemies_defeated[level] = true
		emit_signal("enemy_defeated_first_time", level)
	# Hitos de rango: vencer a ciertos jefes desbloquea un nivel de pieza (spec de rangos, apartado 3)
	if Biomes.is_boss_room(level):
		var ms := Ranks.milestone_for_boss_room(level)
		var dm = get_node_or_null("/root/DataManager")
		if not ms.is_empty() and dm and dm.has_method("apply_milestones"):
			var newly: Array = dm.apply_milestones([ms])
			if not newly.is_empty():
				var ids := newly.map(func(n): return n.id)
				emit_signal("blueprints_milestone", int(ms.rank), ms.tier, ids)
				for n in newly:
					emit_signal("blueprint_unlocked", n.id, n.rank)
				_on_trigger_save()

	# Rejilla de Tico (spec del inventario en rejilla, apartado 7). Provisional hasta que lleguen las
	# … (el bloque de hoy, sin cambios: GridExpansions.recipe_for_boss_room, _growing_grid y grid_expanded)
```

`Biomes.is_boss_room` existe (`scripts/gameplay/visual/Biomes.gd`; ya lo usa el `Corridor`).

- [ ] **Step 3: `Corridor.gd`: un aviso por hito y pergaminos escalonados**

Constante y variable:

```gdscript
const UNLOCK_STAGGER := 0.15  # segundos entre los pergaminos de un mismo hito
var _unlock_burst := 0
```

Conexión en `_ready()`, junto a la de `blueprint_unlocked`:

```gdscript
		if _game_manager.has_signal("blueprints_milestone"):
			_game_manager.blueprints_milestone.connect(_on_blueprints_milestone)
```

Sustituye `_on_blueprint_unlocked`:

```gdscript
## Hito de rangos: un solo destello y un sonido; el cartel lo pone HeroViewOverlay.
func _on_blueprints_milestone(_rank: int, _tier: StringName, _ids: Array) -> void:
	_unlock_burst = 0
	var pos: Vector2 = enemy.death_info.get("pos", hero.position + Vector2(24, 0))
	fx.star(pos + Vector2(0, -16), Color("ffe08a"), 14.0, 0.4)
	Sfx.play(&"blueprint_found", 1.0)


## Cada plano del hito vuela a su botón, escalonado para que no salgan apilados.
func _on_blueprint_unlocked(bp_id: StringName, rank: int = 1) -> void:
	var pos: Vector2 = enemy.death_info.get("pos", hero.position + Vector2(24, 0))
	var dm := get_node_or_null("/root/DataManager")
	var bp = dm.blueprints.get(bp_id) if dm and "blueprints" in dm else null
	var bp_name := String(bp_id)
	var icon: Texture2D = null
	if bp:
		bp_name = tr(bp.display_name) + Ranks.suffix(rank)
		icon = bp.get_blueprint_icon()  # el arte del plano; bp.icon no llega a cargarse
	var payload := {"id": bp_id, "name": bp_name, "icon": icon, "rank": rank}
	var delay := UNLOCK_STAGGER * _unlock_burst
	_unlock_burst += 1
	if delay <= 0.0:
		loot_dropped.emit(&"blueprint", pos + Vector2(0, -16), payload)
	else:
		get_tree().create_timer(delay).timeout.connect(func(): loot_dropped.emit(&"blueprint", pos + Vector2(0, -16), payload))
```

(El texto flotante "¡Nuevo plano!" desaparece: el aviso del hito es el cartel.)

- [ ] **Step 4: Cartel del hito en `HeroViewOverlay.gd`**

En `_ready()`, dentro de `if _game_manager:` y junto a la conexión de `grid_expanded`, conecta:

```gdscript
		if _game_manager.has_signal("blueprints_milestone"):
			_game_manager.blueprints_milestone.connect(_on_blueprints_milestone)
```

```gdscript
## Hito de rangos (spec de rangos, apartado 3): cartel con el grupo desbloqueado. Llega al vencer a un
## jefe, antes que su aviso "X ha caído", que es un toast y espera en cola mientras dure el cartel.
func _on_blueprints_milestone(rank: int, tier: StringName, _ids: Array) -> void:
	show_banner(Ranks.milestone_text(rank, tier), tr("Nuevos planos en la biblioteca"), Color("ffe08a"), 1.6)
```

`show_banner` sustituye al cartel en curso (no encola). En la muerte de un jefe hoy no hay otro cartel, solo los toasts («X ha caído», «¡La rejilla crece!» en los jefes 10 a 40 la primera vez, y quizá el del récord) y el texto "¡JEFE DERROTADO!" de la franja, así que el del hito puede salir enseguida. Los toasts esperan en su cola (hasta 4) a que acabe el cartel.

En `_on_loot_dropped()`, quita el toast `"¡Nuevo plano: %s!"` de los pergaminos (`kind == &"blueprint"`). Con los hitos llegan 4 a la vez y, con los de la rejilla y el jefe, llenarían la cola de 4 avisos; el cartel del hito ya los anuncia. La rama del botín doble (`payload.bonus`, que hace latir SUERTE) se queda como está. Las filas «¡Nuevo plano!» y «¡Nuevo plano: %s!» de `locale/textos.csv` se quedan: no estorban.

Fila en `locale/textos.csv`:

```
"Nuevos planos en la biblioteca","Nuevos planos en la biblioteca","New blueprints in the library"
```

- [ ] **Step 5: Plan de captura `unlock` con hitos**

`VisualCapture._run_unlock_plan()` (hacia la línea 137) bloquea planos con `dm.unlocked_blueprints`, que ya no existe. Pasa a preparar el hito de los avanzados I y dejar que Tico venza al jefe de la sala 20 por primera vez. Con la rejilla vacía y sin ampliaciones, esa muerte da también la ampliación provisional: se ven el cartel del hito y, después, el aviso «¡La rejilla crece!».

```gdscript
func _run_unlock_plan() -> void:
	# Hito de rangos (spec de rangos, apartado 3): bloquea los avanzados, vacía la rejilla de Tico (sin ampliaciones) y
	# lleva a Tico (invencible) al jefe de la sala 20 con el récord en ella. Su muerte da el cartel del hito y, en cola
	# detrás de él, el aviso «¡La rejilla crece!» de la ampliación provisional.
	await get_tree().create_timer(1.0).timeout
	var dm := get_node_or_null("/root/DataManager")
	var gm := get_node_or_null("/root/GameManager")
	var im := get_node_or_null("/root/InventoryManager")
	if dm == null or gm == null or im == null:
		return
	for id in dm.get_blueprint_ids_for_tier(Ranks.TIER_ADVANCED):
		dm.unlocked_ranks[id] = 0
	im.clear()
	var hero: Node = gm.get_hero()
	if hero:
		hero.set_invincible(true)
	gm.wall_room = 0
	gm.room_locked = false
	gm.best_enemy_level = 19
	gm.current_enemy_level = 19
	gm.advance_enemy_level()  # sala 20, récord 20: su jefe aún no ha caído
```

Añade su línea a la cabecera de planes del fichero (hoy no la tiene):

```gdscript
##   unlock → hito de rango en el jefe de la sala 20: cartel «¡Planos avanzados!», 4 pergaminos escalonados y, detrás, «¡La rejilla crece!»
```

Graba el plan `unlock` (con la copia de la partida en `<appdata>`, Global Constraints):

`APPDATA=<appdata> timeout 300 D:/Software/Godot/godot_ver4.5.exe --path . --write-movie <scratchpad>/t7/f.png --fixed-fps 10 --quit-after 200 res://scenes/tests/VisualCapture.tscn -- --plan=unlock`

Abre con Read los fotogramas de la muerte del jefe y los 4 s siguientes, y comprueba:
- un solo cartel "¡Planos avanzados!";
- 4 pergaminos que salen escalonados hacia el botón de Planos;
- el aviso «¡La rejilla crece!» sale cuando se va el cartel, no encima de él.

- [ ] **Step 6: Ejecutar y ver que pasa**

Run: RankTests, InventoryGridTests, GameplayTests, PixelTests y TextTests. Expected: 0 fallos.

- [ ] **Step 7: Commit**

```bash
git add scripts/autoload/GameManager.gd scripts/gameplay/Corridor.gd scripts/ui/HeroViewOverlay.gd scripts/tests/RankTests.gd scripts/tests/VisualCapture.gd locale/textos.csv
git commit -m "feat: hitos de rango al vencer a los jefes, con un cartel por hito y pergaminos escalonados"
```

---

### Task 8: Pedidos, crafteo, oro y venta por rango

**Files:**
- Modify:
  - autoloads: `scripts/autoload/RequestsManager.gd`, `scripts/autoload/CraftingManager.gd`;
  - interfaz: `scripts/RequestSlot.gd`, `scripts/ui/HUDMain.gd` (clave de tarjeta), `scripts/ui/CraftResultScreen.gd` (nombre).
- Test: `scripts/tests/RankTests.gd`

**Ya hecho:** la venta por rango. `ShopPanel._get_sell_price(item)` devuelve `item.get_sell_price()`, que ya multiplica por `Ranks.gold_mult(rank)`, y lo mismo usan la zona de venta, «Vender todo» y la ficha del panel de Equipo. La tienda vende el botín y la mochila (`InventoryManager.get_unequipped_items()`), nunca lo que lleva Tico. Aquí solo se añade una prueba que lo guarde.

**Interfaces:**
- Consumes: `Ranks.recipe`, `Ranks.gold_mult`, `Ranks.suffix`, `DataManager.get_unlocked_rank`, `DataManager.blueprint_tier`, `CraftedItem.new(res, q, rank)`, `CraftedItem.get_name_with_rank()`
- Produces:
  - `RequestsManager.PREVIOUS_RANK_CHANCE` (0,2) y `RequestsManager.rng: RandomNumberGenerator`, que las pruebas pueden sembrar.
  - `RequestsManager.make_request(bp_id: StringName) -> Dictionary`, con claves `blueprint_id, blueprint, rank, materials, gold_reward` y las del cliente de `_generate_client()` (`client_name`, `client_first`, `client_title`).
  - `CraftingManager.enqueue(recipe_id, gold_reward: int = 0, rank: int = 1, own_order: bool = false) -> bool`.
  - `CraftingManager.CraftingTask`: campos `rank` y `own_order`.
  - El resultado de `_finalize_task` lleva `"rank"` y `"own_order"`, y el oro es 0 si es un encargo propio.

- [ ] **Step 1: Pruebas que fallan**

```gdscript
# ─── Tarea 8: pedidos y crafteo por rango ──────────────────────────────

func test_request_rank_is_mostly_the_highest() -> void:
	var rm := get_node("/root/RequestsManager")
	var dm := _dm()
	var saved: Dictionary = dm.unlocked_ranks.duplicate()
	dm.unlocked_ranks[&"sword_basic"] = 3
	rm.rng.seed = 12345
	var counts := {1: 0, 2: 0, 3: 0}
	for i in 1000:
		counts[rm.make_request(&"sword_basic").rank] += 1
	check(counts[3] > 750 and counts[3] < 850 and counts[2] > 150 and counts[1] == 0, "80 % rango III, 20 % rango II (%s)" % [counts])
	dm.unlocked_ranks[&"sword_basic"] = 1
	check(rm.make_request(&"sword_basic").rank == 1, "con solo el rango I, siempre I")
	dm.unlocked_ranks = saved


func test_request_carries_recipe_and_gold_of_its_rank() -> void:
	var rm := get_node("/root/RequestsManager")
	var dm := _dm()
	var saved: Dictionary = dm.unlocked_ranks.duplicate()
	dm.unlocked_ranks[&"sword_masterwork"] = 2
	rm.rng.seed = 1
	var req: Dictionary = rm.make_request(&"sword_masterwork")
	while req.rank != 2:
		req = rm.make_request(&"sword_masterwork")
	var bp: BlueprintResource = dm.get_blueprint(&"sword_masterwork")
	check(req.materials == Ranks.recipe(bp.materials, Ranks.TIER_MASTER, 2), "el pedido lleva la receta de su rango")
	dm.unlocked_ranks[&"sword_masterwork"] = 1
	var req1: Dictionary = rm.make_request(&"sword_masterwork")
	check(req.gold_reward == roundi(req1.gold_reward * Ranks.gold_mult(2)), "el oro crece con el rango (%d y %d)" % [req1.gold_reward, req.gold_reward])
	dm.unlocked_ranks = saved


func test_visible_request_keeps_its_rank() -> void:
	var rm := get_node("/root/RequestsManager")
	var dm := _dm()
	var saved: Dictionary = dm.unlocked_ranks.duplicate()
	dm.unlocked_ranks[&"shield_basic"] = 1
	var req: Dictionary = rm.make_request(&"shield_basic")
	var before := req.duplicate()
	dm.unlock_rank(&"shield_basic", 2)
	check(req.rank == before.rank and req.materials == before.materials and req.gold_reward == before.gold_reward, "un pedido ya creado no cambia al subir de rango")
	dm.unlocked_ranks = saved


func test_crafting_a_rank_makes_an_item_of_that_rank() -> void:
	var cm := get_node("/root/CraftingManager")
	var inv := get_node("/root/InventoryManager")
	var items_before: int = inv.get_crafted_items().size()
	var queue_before: Array = cm.queue.duplicate()  # _finalize_task vacía su hueco y compacta la cola
	for i in cm.MAX_SLOTS:
		cm.queue[i] = null
	check(cm.enqueue(&"helmet_basic", 100, 3), "se encola el casco básico III")
	var task = null
	for t in cm.queue:
		if t != null and t.blueprint.blueprint_id == &"helmet_basic" and t.rank == 3:
			task = t
	check(task != null, "la tarea guarda el rango")
	if task:
		var result: Dictionary = cm._finalize_task(task)
		var item: CraftedItem = result.crafted_item
		check(result.rank == 3 and item.rank == 3, "el objeto sale de rango III")
		var base: Dictionary = item.item_resource.calculate_stats(item.quality)
		check(item.calculated_stats == Ranks.scale_stats(base, 3), "con las estadísticas del rango III (%s)" % [item.calculated_stats])
		check(item.place == InventoryManager.PLACE_LOOT and inv.get_loot()[0] == item, "y llega al botín, delante, como todo lo forjado")
		check(item.aristas.size() == PieceShape.aristas_for_tier(item.get_quality_tier()), "con sus aristas sorteadas (%d)" % item.aristas.size())
		check(result.gold_reward > 0 and not result.own_order, "un pedido sí da oro")
		check(inv.remove_crafted_item(item) and not (item in inv.get_loot()), "remove_crafted_item lo saca también del botín")
	check(inv.get_crafted_items().size() == items_before, "la prueba deja el inventario como estaba")
	cm.queue = queue_before


## La venta ya va por rango (CraftedItem.get_sell_price, que usan la tienda y el panel de Equipo). Esta prueba lo guarda.
func test_sell_price_grows_with_the_rank() -> void:
	var res: ItemResource = load("res://data/items/shield_basic.tres")
	var one := CraftedItem.new(res, 0.75)
	var two := CraftedItem.new(res, 0.75, 2)
	check(two.get_sell_price() == roundi(one.get_sell_price() * Ranks.gold_mult(2)) and two.get_sell_price() > one.get_sell_price(), "el precio de venta crece con el rango (%d y %d)" % [one.get_sell_price(), two.get_sell_price()])
```

Run RankTests. Expected: fallan (`rng`, `make_request` y `enqueue` con rango no existen). `test_sell_price_grows_with_the_rank` ya pasa.

- [ ] **Step 2: `RequestsManager.gd`**

Constante y generador:

```gdscript
const PREVIOUS_RANK_CHANCE := 0.2  # probabilidad de que un pedido sea del rango anterior al máximo
var rng := RandomNumberGenerator.new()
```

En `_ready()`, `rng.randomize()`.

Pedido completo en un solo sitio:

```gdscript
## Crea un pedido de un plano desbloqueado con su rango, su receta y su oro (spec de rangos, apartado 5).
func make_request(blueprint_id: StringName) -> Dictionary:
	var blueprint: BlueprintResource = _data_manager.get_blueprint(blueprint_id)
	var rank := _pick_rank(blueprint_id)
	var tier: StringName = _data_manager.blueprint_tier(blueprint_id)
	return {
		"blueprint_id": blueprint_id,
		"blueprint": blueprint,
		"rank": rank,
		"materials": Ranks.recipe(blueprint.materials, tier, rank),
		"gold_reward": _calculate_reward(blueprint, rank),
	}.merged(_generate_client())  # client_name, client_first y client_title (la tarjeta lo traduce al enseñarlo)


func _pick_rank(blueprint_id: StringName) -> int:
	var top: int = maxi(1, _data_manager.get_unlocked_rank(blueprint_id))
	if top >= 2 and rng.randf() < PREVIOUS_RANK_CHANCE:
		return top - 1
	return top
```

`_calculate_reward` recibe el rango y multiplica al final:

```gdscript
func _calculate_reward(blueprint: BlueprintResource, rank: int = 1) -> int:
	"""Recompensa base según el plano (materiales y pruebas), por el multiplicador de oro del rango"""
	var base_reward := 50
	base_reward += blueprint.materials.size() * 10
	var num_trials := blueprint.trial_sequence.size() if blueprint.has_trials() else 1
	base_reward += num_trials * 15
	return roundi(base_reward * Ranks.gold_mult(rank))
```

En `_generate_initial_requests()` y `_add_new_request()`, sustituye la construcción del diccionario del pedido por `active_requests.append(make_request(blueprint_id))`. Conserva el resto: el barajado, el filtro de repetidos y los `print`.

En `accept_request(index)`:
- usa `request.get("materials", blueprint.materials)` en lugar de `blueprint.materials` para comprobar, consumir y emitir `request_rejected_no_materials`;
- encola con el rango:

```gdscript
		var success: bool = cm.enqueue(blueprint_id, gold_reward, int(request.get("rank", 1)))
```

- [ ] **Step 3: `CraftingManager.gd`**

`CraftingTask`:

```gdscript
	var gold_reward: int = 0  ## Recompensa base del request (calculado por RequestsManager)
	var rank: int = 1  ## Rango del plano (spec de rangos)
	var own_order: bool = false  ## Encargo propio desde la biblioteca: no da oro

	func _init(task_id: int, blueprint_res: BlueprintResource, slot: int, reward: int = 0, task_rank: int = 1, is_own_order: bool = false) -> void:
		id = task_id
		blueprint = blueprint_res
		slot_index = slot
		gold_reward = reward
		rank = maxi(1, task_rank)
		own_order = is_own_order
```

`enqueue`:

```gdscript
func enqueue(recipe_id, gold_reward: int = 0, rank: int = 1, own_order: bool = false) -> bool:
```

Dentro, la creación de la tarea pasa a `CraftingTask.new(_generate_task_id(), blueprint, i, gold_reward, rank, own_order)`.

En `_finalize_task` (lo demás se conserva: el bonus de Forjamagia sobre la calidad, el sorteo de aristas con `rng` y `add_crafted_item`, que deja la pieza en el botín):
- `crafted_item = CraftedItem.new(item_res, quality_normalized, task.rank)` (la línea siguiente, `crafted_item.aristas = PieceShape.roll_aristas(...)`, no cambia);
- el oro final:

```gdscript
	var final_gold := 0
	if not task.own_order:
		final_gold = int(task.gold_reward * gold_multiplier) if task.gold_reward > 0 else int(50 * gold_multiplier)
```

- en el diccionario `result`, añade `"rank": task.rank` y `"own_order": task.own_order`;
- en `get_queue_snapshot()` y `_emit_task_update()`, añade `"rank": task.rank`.

- [ ] **Step 4: Interfaz**

`RequestSlot.set_request(request)`: nombre con numeral y receta del pedido. El cliente se sigue traduciendo con `RequestsManager.client_display_name` (tarjeta de idioma); solo cambian el nombre y los materiales.

```gdscript
## Configura la tarjeta con el diccionario del pedido (blueprint, rank, materials, gold_reward y el cliente).
func set_request(request: Dictionary) -> void:
	var blueprint: BlueprintResource = request.get("blueprint")
	set_blueprint(blueprint)
	if blueprint:
		set_blueprint_name((tr(blueprint.display_name) if blueprint.display_name != "" else String(blueprint.blueprint_id)) + Ranks.suffix(int(request.get("rank", 1))))
		# La receta del rango del pedido (materiales de bioma incluidos), no la del .tres
		set_materials(request.get("materials", blueprint.materials))
	var reward := int(request.get("gold_reward", 0))
	reward_label.text = str(reward) if reward > 0 else "—"
	var rm := get_node_or_null("/root/RequestsManager")
	# El cliente se traduce al enseñarlo ("Brenna la Guerrera" / "Brenna the Warrior")
	var client := String(request.get("client_name", ""))
	if rm and rm.has_method("client_display_name"):
		client = rm.client_display_name(request)
	client_label.text = client
	client_label.visible = client != ""
	var free: bool = rm != null and rm.has_method("get_free_requests_remaining") and rm.get_free_requests_remaining() > 0
	free_tag.visible = free
	_refresh_material_colors()
```

`HUDMain._on_requests_refreshed`: la clave de la tarjeta incluye el rango, para que una tarjeta nueva de otro rango se anime:

```gdscript
		var key := "%s|%s|%s|%s" % [request.get("blueprint_id", ""), request.get("rank", 1), request.get("client_name", ""), request.get("gold_reward", 0)]
```

`ShopPanel` no se toca: la venta ya va por rango (ver arriba).

`CraftResultScreen` (hacia la línea 124): el nombre sale del objeto, con su numeral; el del plano queda de respaldo. El bloque de textos e icono queda así (`_fit_to_window` y lo demás no cambian):

```gdscript
	var crafted_item = result.get("crafted_item")
	if crafted_item is CraftedItem:
		icon = crafted_item.get_icon()
		item_name = crafted_item.get_name_with_rank()
	var dm = get_node_or_null("/root/DataManager")
	if dm:
		var bp = dm.get_blueprint(StringName(bp_id))
		if bp:
			if item_name == "" and bp.display_name != "":
				item_name = tr(bp.display_name)
			if icon == null:
				icon = bp.get_icon()  # resuelve icon_path (bp.icon queda vacío al cargar)
```

Sin el `item_name == ""`, el nombre del plano pisaría al del objeto.

- [ ] **Step 5: Ejecutar y ver que pasa**

Run: RankTests, InventoryGridTests, GameplayTests y PixelTests. Expected: 0 fallos.

Captura: `APPDATA=<appdata> timeout 300 D:/Software/Godot/godot_ver4.5.exe --path . --write-movie <scratchpad>/t8/f.png --fixed-fps 10 --quit-after 120 res://scenes/tests/VisualCapture.tscn -- --plan=main`. Abre 2 o 3 fotogramas con Read: las tarjetas de pedido muestran los materiales de la receta, con el de bioma incluido.

Captura también el plan `result` (misma orden con `--plan=result` y `<scratchpad>/t8r/f.png`) y comprueba que la pantalla de resultado enseña el nombre del objeto y sigue cabiendo en la ventana.

- [ ] **Step 6: Commit**

```bash
git add scripts/autoload/RequestsManager.gd scripts/autoload/CraftingManager.gd scripts/RequestSlot.gd scripts/ui/HUDMain.gd scripts/ui/CraftResultScreen.gd scripts/tests/RankTests.gd
git commit -m "feat: pedidos y crafteo por rango, con su receta y su oro"
```

---

### Task 9: Claves de dificultad que sí llegan a los minijuegos

**Files:**
- Modify: `scripts/ForgeMinigame.gd`, `data/blueprints/boots_basic.tres`, `data/blueprints/boots_advanced.tres`, `data/blueprints/boots_master.tres`
- Test: `scripts/tests/RankTests.gd`

**Qué falla hoy:**
- La forja lee `difficulty`, pero sus planos le pasan `precision`: la ventana es igual en todos los niveles.
- Los planos de botas pasan `circles` y `difficulty`, que el minijuego de coser no lee: se cosen igual en básico y en maestro.
- En coser, más `precision` = ventanas más **grandes**, es decir, más fácil. Por eso las botas maestras llevan una precisión menor.

Comprobado el 2026-10-02 sobre la rama con la rejilla: nada de esto cambió. `ForgeMinigame.start_trial` lee `difficulty` (hacia la línea 69), los tres `boots_*.tres` siguen con `TrialConfig.gd` (`uid://csfs6pe4ark4v`) y `circles`/`difficulty`, y `SewTrialConfig.gd` tiene `uid://dumvodck0w3no`. `boots_leather.tres` no está en la biblioteca de planos: no se toca.

- [ ] **Step 1: Pruebas que fallan**

```gdscript
# ─── Tarea 9: claves de dificultad ─────────────────────────────────────

## Claves que cada minijuego lee de verdad
const MINIGAME_KEYS := {
	"ForgeTemp.tscn": ["forge_speed", "precision"],
	"HammerMinigame.tscn": ["hammer_speed", "precision"],
	"SewOSU.tscn": ["stitch_speed", "precision"],
	"QuenchWater.tscn": ["quench_speed", "time_window"],
}


func test_every_trial_passes_the_keys_its_minigame_reads() -> void:
	var dm := _dm()
	var cm := get_node("/root/CraftingManager")
	for bp_id in dm.get_all_blueprints():
		var bp: BlueprintResource = dm.get_blueprint(bp_id)
		for trial in bp.trial_sequence:
			var config: TrialConfig = cm._resolve_trial_config(trial, bp)
			var scene_file: String = config.minigame_scene.resource_path.get_file() if config.minigame_scene else ""
			check(MINIGAME_KEYS.has(scene_file), "%s: minijuego conocido (%s)" % [bp_id, scene_file])
			for key in MINIGAME_KEYS.get(scene_file, []):
				check(config.parameters.has(key), "%s / %s: %s lee «%s» y el plano no lo pasa" % [bp_id, trial.trial_id, scene_file, key])


func test_boots_sewing_gets_harder_with_the_tier() -> void:
	var dm := _dm()
	var cm := get_node("/root/CraftingManager")
	var p := {}
	for id in [&"boots_basic", &"boots_advanced", &"boots_master"]:
		var bp: BlueprintResource = dm.get_blueprint(id)
		for trial in bp.trial_sequence:
			var config: TrialConfig = cm._resolve_trial_config(trial, bp)
			if config.minigame_scene and config.minigame_scene.resource_path.ends_with("SewOSU.tscn"):
				p[id] = config.parameters
	check(p.size() == 3, "las tres botas se cosen")
	if p.size() == 3:
		check(p[&"boots_basic"].stitch_speed < p[&"boots_advanced"].stitch_speed and p[&"boots_advanced"].stitch_speed < p[&"boots_master"].stitch_speed, "la aguja va más rápida del básico al maestro")
		check(p[&"boots_basic"].precision > p[&"boots_advanced"].precision and p[&"boots_advanced"].precision > p[&"boots_master"].precision, "las ventanas se estrechan del básico al maestro")


func test_forge_reads_precision() -> void:
	var forge = load("res://scenes/Minigames/ForgeTemp.tscn").instantiate()
	add_child(forge)
	await get_tree().process_frame
	var config := TrialConfig.new()
	config.parameters = {"forge_speed": 1.0, "precision": 0.7, "trials": 3}
	forge.start_trial(config)
	check(is_equal_approx(forge._tolerance, lerpf(0.25, 0.08, 0.7)), "la forja estrecha su ventana con la precisión del plano (%.3f)" % forge._tolerance)
	forge.queue_free()
	await get_tree().process_frame
```

Run RankTests. Expected: fallan las botas (sin `stitch_speed` ni `precision`) y la forja (`_tolerance` de 0,5).

- [ ] **Step 2: La forja lee `precision`**

En `ForgeMinigame.start_trial`:

```gdscript
	# La dificultad de la ventana viene como `precision` en los planos (antes `difficulty`, que ninguno pasaba)
	var difficulty: float = clamp(float(config.get_parameter(&"precision", config.get_parameter(&"difficulty", 0.5))), 0.0, 1.0)
```

- [ ] **Step 3: Botas con `SewTrialConfig`**

En cada `boots_*.tres`:
1. La línea `[ext_resource type="Script" uid="uid://csfs6pe4ark4v" path="res://scripts/data/TrialConfig.gd" id="3"]` pasa a:
   ```
   [ext_resource type="Script" uid="uid://dumvodck0w3no" path="res://scripts/data/SewTrialConfig.gd" id="3"]
   ```
2. El bloque `[sub_resource type="Resource" id="1"]` que hoy tiene `parameters = { "circles": …, "difficulty": … }` pasa a (valores por fichero en la tabla):
   ```
   [sub_resource type="Resource" id="1"]
   resource_name = "sew_sequence"
   script = ExtResource("3")
   stitch_speed = 0.9
   precision = 0.6
   label = "Botas"
   minigame_id = "SewOSU"
   minigame_scene = ExtResource("4")
   ```

| Fichero | stitch_speed | precision |
|---|---|---|
| `boots_basic.tres` | 0.9 | 0.6 |
| `boots_advanced.tres` | 1.05 | 0.45 |
| `boots_master.tres` | 1.2 | 0.3 |

Antes de editar, comprueba con `grep -n "TrialConfig.gd\|circles" data/blueprints/boots_*.tres` que el `id="3"` solo lo usa ese sub_resource. Si la tarjeta de idioma cambió `display_name` o `description`, no los toques. `CraftingManager._resolve_trial_config` llama a `prepare()`, que rellena `parameters` desde estas propiedades.

- [ ] **Step 4: Ejecutar y ver que pasa**

Run: RankTests, InventoryGridTests, GameplayTests y PixelTests. Expected: 0 fallos.

- [ ] **Step 5: Commit**

```bash
git add scripts/ForgeMinigame.gd data/blueprints/boots_basic.tres data/blueprints/boots_advanced.tres data/blueprints/boots_master.tres scripts/tests/RankTests.gd
git commit -m "fix: la forja usa la precisión de sus planos y las botas se cosen más difícil según el nivel"
```

---

### Task 10: Dificultad de los minijuegos por rango

**Files:**
- Create: `scripts/core/TrialDifficulty.gd`
- Modify: `scripts/autoload/CraftingManager.gd` (`_resolve_trial_config`, `_start_next_trial`)
- Test: `scripts/tests/RankTests.gd`

**Interfaces:**
- Consumes: `CraftingTask.rank`
- Produces: `TrialDifficulty.apply(config: TrialConfig, rank: int) -> void` (modifica `config.parameters`) y `CraftingManager._resolve_trial_config(trial, blueprint, rank: int = 1) -> TrialConfig`.

Comprobado el 2026-10-02: la rejilla no tocó los minijuegos ni `CraftingManager._resolve_trial_config` (hacia la línea 352) ni `_start_next_trial` (hacia la 328); el código de abajo parte del de hoy.

`TrialDifficulty` actúa según las claves que lleva la configuración, no según el id del minijuego (los planos usan ids como `Forge`, `hammer`, `Hammer`, `SewOSU` y `quench`).

| Clave presente | Por cada rango por encima del I | Tope |
|---|---|---|
| `forge_speed` | ×1,1 | 2,0 |
| `precision` (forja y martillo) | +0,06 forja, +0,05 martillo | 0,85 |
| `hammer_speed` (y `tempo_bpm`) | ×1,08, redondeado | 160 |
| `stitch_speed` | ×1,08 | 1,6 |
| `precision` (coser: con `stitch_speed`) | −0,05 | 0,0 |
| `quench_speed` | ×1,08 | 2,0 |
| `time_window` | ×0,92 | 0,12 |

Si el valor de partida ya supera el tope, no se toca: el tope no rebaja lo que ya estaba.

- [ ] **Step 1: Pruebas que fallan**

```gdscript
# ─── Tarea 10: dificultad por rango ────────────────────────────────────

func _config(params: Dictionary) -> TrialConfig:
	var c := TrialConfig.new()
	c.parameters = params.duplicate()
	return c


func test_rank_one_leaves_trials_unchanged() -> void:
	var c := _config({"forge_speed": 1.0, "precision": 0.4})
	TrialDifficulty.apply(c, 1)
	check(c.parameters == {"forge_speed": 1.0, "precision": 0.4}, "el rango I no cambia nada")


func test_difficulty_grows_with_rank_and_respects_caps() -> void:
	var forge := _config({"forge_speed": 1.0, "precision": 0.4})
	TrialDifficulty.apply(forge, 3)
	check(is_equal_approx(forge.parameters.forge_speed, 1.21) and is_equal_approx(forge.parameters.precision, 0.52), "forja III: ×1,21 y +0,12 (%s)" % [forge.parameters])
	var hammer := _config({"hammer_speed": 110, "tempo_bpm": 110, "precision": 0.7})
	TrialDifficulty.apply(hammer, 20)
	check(hammer.parameters.hammer_speed == 160 and hammer.parameters.tempo_bpm == 160 and is_equal_approx(hammer.parameters.precision, 0.85), "martillo XX: topes 160 y 0,85")
	var sew := _config({"stitch_speed": 1.2, "precision": 0.3})
	TrialDifficulty.apply(sew, 4)
	check(sew.parameters.stitch_speed > 1.2 and is_equal_approx(sew.parameters.precision, 0.15), "coser IV: más rápido y ventanas menores (precisión 0,15)")
	TrialDifficulty.apply(sew, 20)
	check(sew.parameters.stitch_speed <= 1.6 and sew.parameters.precision >= 0.0, "coser: topes 1,6 y 0,0")
	var quench := _config({"quench_speed": 1.0, "time_window": 0.3})
	TrialDifficulty.apply(quench, 30)
	check(is_equal_approx(quench.parameters.time_window, 0.12) and quench.parameters.quench_speed <= 2.0, "temple: ventana mínima 0,12 y velocidad máxima 2")


func test_crafting_uses_the_task_rank() -> void:
	var dm := _dm()
	var cm := get_node("/root/CraftingManager")
	var bp: BlueprintResource = dm.get_blueprint(&"sword_basic")
	var c1: TrialConfig = cm._resolve_trial_config(bp.trial_sequence[0], bp, 1)
	var c3: TrialConfig = cm._resolve_trial_config(bp.trial_sequence[0], bp, 3)
	check(c3.parameters.forge_speed > c1.parameters.forge_speed, "la espada básica III se forja más rápido que la I")
```

Run RankTests. Expected: error de análisis (`TrialDifficulty` no existe).

- [ ] **Step 2: Crear `scripts/core/TrialDifficulty.gd`**

```gdscript
class_name TrialDifficulty
extends RefCounted

## Dificultad de los minijuegos por rango (spec de rangos, apartado 5). Ajusta la copia de la
## configuración de una prueba según las claves que lleva (los ids de minijuego no son uniformes).
## Topes jugables en móvil; si el valor ya pasaba el tope, se respeta.

const FORGE_SPEED_STEP := 1.1
const FORGE_SPEED_CAP := 2.0
const FORGE_PRECISION_STEP := 0.06
const HAMMER_SPEED_STEP := 1.08
const HAMMER_SPEED_CAP := 160
const HAMMER_PRECISION_STEP := 0.05
const PRECISION_CAP := 0.85
const SEW_SPEED_STEP := 1.08
const SEW_SPEED_CAP := 1.6
const SEW_PRECISION_STEP := 0.05  # en coser se resta: menos precisión = ventanas menores
const QUENCH_SPEED_STEP := 1.08
const QUENCH_SPEED_CAP := 2.0
const QUENCH_WINDOW_STEP := 0.92
const QUENCH_WINDOW_MIN := 0.12


static func apply(config: TrialConfig, rank: int) -> void:
	var k := maxi(1, rank) - 1
	if config == null or k == 0:
		return
	var p := config.parameters
	if p.has("forge_speed"):
		p["forge_speed"] = _up(float(p.forge_speed), pow(FORGE_SPEED_STEP, k), FORGE_SPEED_CAP)
		if p.has("precision"):
			p["precision"] = _add_up(float(p.precision), FORGE_PRECISION_STEP * k, PRECISION_CAP)
	elif p.has("hammer_speed"):
		var bpm := roundi(_up(float(p.hammer_speed), pow(HAMMER_SPEED_STEP, k), HAMMER_SPEED_CAP))
		p["hammer_speed"] = bpm
		if p.has("tempo_bpm"):
			p["tempo_bpm"] = bpm
		if p.has("precision"):
			p["precision"] = _add_up(float(p.precision), HAMMER_PRECISION_STEP * k, PRECISION_CAP)
	elif p.has("stitch_speed"):
		p["stitch_speed"] = _up(float(p.stitch_speed), pow(SEW_SPEED_STEP, k), SEW_SPEED_CAP)
		if p.has("precision"):
			p["precision"] = maxf(0.0, float(p.precision) - SEW_PRECISION_STEP * k)
	elif p.has("quench_speed"):
		p["quench_speed"] = _up(float(p.quench_speed), pow(QUENCH_SPEED_STEP, k), QUENCH_SPEED_CAP)
		if p.has("time_window"):
			var w := float(p.time_window)
			p["time_window"] = w if w <= QUENCH_WINDOW_MIN else maxf(QUENCH_WINDOW_MIN, w * pow(QUENCH_WINDOW_STEP, k))


## Multiplica sin pasar del tope (si ya lo pasaba, lo deja).
static func _up(value: float, factor: float, cap: float) -> float:
	return value if value >= cap else minf(cap, value * factor)


static func _add_up(value: float, delta: float, cap: float) -> float:
	return value if value >= cap else minf(cap, value + delta)
```

Run: `D:/Software/Godot/godot_ver4.5.exe --headless --path . --import`

- [ ] **Step 3: `CraftingManager` aplica el rango de la tarea**

```gdscript
func _resolve_trial_config(trial: TrialResource, blueprint: BlueprintResource, rank: int = 1) -> TrialConfig:
	if trial == null:
		return null
	var config: TrialConfig = null
	if trial.config != null:
		# Preparar config para sincronizar parámetros desde propiedades @export
		if trial.config.has_method("prepare"):
			trial.config.prepare()
		config = trial.config.duplicate_config()
	else:
		config = TrialConfig.new()
	if config.minigame_id == StringName():
		config.minigame_id = trial.get_effective_minigame()
	if config.trial_id == StringName():
		config.trial_id = trial.trial_id
	if config.blueprint_id == StringName() and blueprint != null:
		config.blueprint_id = blueprint.blueprint_id
	if config.minigame_scene == null:
		config.minigame_scene = trial.minigame_scene
	if config.parameters == null:
		config.parameters = {}
	if config.max_score <= 0.0:
		config.max_score = 100.0
	# Dificultad del rango sobre la copia (el recurso del plano no cambia)
	TrialDifficulty.apply(config, rank)
	return config
```

En `_start_next_trial(task)`: `var config := _resolve_trial_config(trial, task.blueprint, task.rank)`.

- [ ] **Step 4: Ejecutar y ver que pasa**

Run: RankTests, InventoryGridTests, GameplayTests y PixelTests. Expected: 0 fallos.

- [ ] **Step 5: Commit**

```bash
git add scripts/core/TrialDifficulty.gd scripts/autoload/CraftingManager.gd scripts/tests/RankTests.gd
git commit -m "feat: los minijuegos se vuelven más difíciles con el rango, con topes"
```

---

### Task 11: Encargo propio desde la biblioteca y numerales en la interfaz

**Files:**
- Modify:
  - `scripts/autoload/CraftingManager.gd` (`place_own_order`);
  - `scripts/ui/BlueprintCard.gd` y `scripts/ui/BlueprintLibraryPanel.gd` (selector y botón);
  - `scripts/ui/HUDMain.gd` (lanzar la tarea);
  - `scripts/tests/VisualCapture.gd` (plan `inventory`: una pieza de rango II para ver el numeral);
  - `locale/textos.csv`.
- Test: `scripts/tests/RankTests.gd`

**Interfaces:**
- Consumes: `CraftingManager.enqueue(…, rank, own_order)`, `Ranks.recipe`, `DataManager.get_unlocked_rank`, `CraftedItem.get_name_with_rank`
- Produces:
  - `CraftingManager.place_own_order(bp_id: StringName, rank: int) -> StringName`: `&""` si se encola, `&"locked"`, `&"queue_full"` o `&"no_materials"`, y nunca cobra si falla;
  - `BlueprintCard` emite `signal forge_requested(bp_id: StringName, rank: int)`;
  - `BlueprintLibraryPanel` emite `signal own_order_requested(bp_id: StringName, rank: int)` y tiene `func reject(bp_id: StringName, reason: StringName)`;
  - `HUDMain._start_first_queued_task()`.

- [ ] **Step 1: Pruebas que fallan**

```gdscript
# ─── Tarea 11: encargo propio ──────────────────────────────────────────

func test_own_order_never_charges_when_refused() -> void:
	var cm := get_node("/root/CraftingManager")
	var inv := get_node("/root/InventoryManager")
	var dm := _dm()
	var saved_ranks: Dictionary = dm.unlocked_ranks.duplicate()
	var saved_inv: Dictionary = inv.inventory.duplicate()
	var saved_queue: Array = cm.queue.duplicate()
	dm.unlocked_ranks[&"sword_basic"] = 1
	check(cm.place_own_order(&"sword_basic", 2) == &"locked" and inv.inventory == saved_inv, "un rango bloqueado no se encarga ni cobra")
	inv.inventory = {}
	check(cm.place_own_order(&"sword_basic", 1) == &"no_materials" and inv.inventory.is_empty(), "sin materiales no se encarga")
	var bp: BlueprintResource = dm.get_blueprint(&"sword_basic")
	var recipe := Ranks.recipe(bp.materials, Ranks.TIER_BASIC, 1)
	for mat_id in recipe:
		inv.add_item(mat_id, recipe[mat_id] * 10)
	var Task = cm.get_script().CraftingTask  # clase interna del autoload (no tiene class_name)
	for i in cm.MAX_SLOTS:
		cm.queue[i] = Task.new(9000 + i, bp, i)
	var before: Dictionary = inv.inventory.duplicate()
	check(cm.place_own_order(&"sword_basic", 1) == &"queue_full" and inv.inventory == before, "con la cola llena no cobra")
	cm.queue = saved_queue
	inv.inventory = saved_inv
	dm.unlocked_ranks = saved_ranks


func test_own_order_charges_recipe_and_gives_no_gold() -> void:
	var cm := get_node("/root/CraftingManager")
	var inv := get_node("/root/InventoryManager")
	var dm := _dm()
	var saved_ranks: Dictionary = dm.unlocked_ranks.duplicate()
	var saved_inv: Dictionary = inv.inventory.duplicate()
	var saved_queue: Array = cm.queue.duplicate()
	for i in cm.MAX_SLOTS:
		cm.queue[i] = null
	dm.unlocked_ranks[&"helmet_basic"] = 2
	var bp: BlueprintResource = dm.get_blueprint(&"helmet_basic")
	var recipe := Ranks.recipe(bp.materials, Ranks.TIER_BASIC, 2)
	inv.inventory = {}
	for mat_id in recipe:
		inv.add_item(mat_id, recipe[mat_id])
	check(cm.place_own_order(&"helmet_basic", 2) == &"", "se encarga el casco básico II")
	check(inv.inventory.is_empty(), "cobra exactamente la receta del rango II")
	var task = cm.queue[0]
	check(task != null and task.own_order and task.rank == 2, "la tarea es un encargo propio de rango II")
	if task:
		var result: Dictionary = cm._finalize_task(task)
		check(result.gold_reward == 0 and result.crafted_item.rank == 2, "no da oro y el objeto es de rango II")
		inv.remove_crafted_item(result.crafted_item)
	cm.queue = saved_queue
	inv.inventory = saved_inv
	dm.unlocked_ranks = saved_ranks
```

Run RankTests. Expected: error (`place_own_order` no existe).

- [ ] **Step 2: `CraftingManager.place_own_order`**

```gdscript
## Encargo propio desde la biblioteca (spec de rangos, apartado 5): cobra la receta del rango y encola
## sin recompensa de oro. Devuelve &"" si se encola, o el motivo: &"locked", &"queue_full" o &"no_materials".
## Si falla, no cobra nada.
func place_own_order(bp_id: StringName, rank: int) -> StringName:
	var dm = get_node_or_null("/root/DataManager")
	var inv = get_node_or_null("/root/InventoryManager")
	if dm == null or inv == null:
		return &"locked"
	if rank < 1 or rank > dm.get_unlocked_rank(bp_id):
		return &"locked"
	if not queue.has(null):
		return &"queue_full"
	var bp: BlueprintResource = dm.get_blueprint(bp_id)
	if bp == null:
		return &"locked"
	var recipe := Ranks.recipe(bp.materials, dm.blueprint_tier(bp_id), rank)
	if not inv.has_materials(recipe):
		return &"no_materials"
	if not inv.consume_materials(recipe):
		return &"no_materials"
	if not enqueue(bp_id, 0, rank, true):
		# No debería pasar (se comprobó el hueco): devolver lo cobrado
		for mat_id in recipe:
			inv.add_item(mat_id, recipe[mat_id])
		return &"queue_full"
	return &""
```

- [ ] **Step 3: Tarjeta y panel de la biblioteca**

`BlueprintCard.gd`: selector de rango y botón, creados por código bajo el `VBox` de la escena.

```gdscript
signal forge_requested(bp_id: StringName, rank: int)

var max_rank: int = 0
var selected_rank: int = 1
var _rank_label: Label
var _forge_btn: Button


func set_blueprint_data(bp_id: StringName, blueprint: BlueprintResource, unlocked: bool, unlocked_rank: int = 1) -> void:
	blueprint_id = bp_id
	blueprint_data = blueprint
	is_unlocked = unlocked
	max_rank = unlocked_rank if unlocked else 0
	selected_rank = maxi(1, max_rank)

	# Obtener ItemResource para las estadísticas
	var dm = get_node_or_null("/root/DataManager")
	if dm and blueprint.result_item != &"":
		item_resource = dm.get_item_resource(blueprint.result_item)

	# Configurar Visuales
	if blueprint_data:
		var icon_tex = blueprint_data.get_icon()
		if icon_tex:
			icon_rect.texture = icon_tex

	# Estado de bloqueo
	if is_unlocked:
		lock_overlay.visible = false
		modulate = Color.WHITE
	else:
		lock_overlay.visible = true
		modulate = Color(0.7, 0.7, 0.7)

	_build_forge_row()
	_refresh_rank()  # pone el nombre, con numeral desde el rango II
	_update_tooltip()


func _build_forge_row() -> void:
	if _forge_btn or max_rank < 1:
		return
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var prev := Button.new()
	prev.text = "◀"
	prev.pressed.connect(func(): selected_rank = maxi(1, selected_rank - 1); _refresh_rank())
	_rank_label = Label.new()
	_rank_label.custom_minimum_size = Vector2(36, 0)
	_rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var next := Button.new()
	next.text = "▶"
	next.pressed.connect(func(): selected_rank = mini(max_rank, selected_rank + 1); _refresh_rank())
	_forge_btn = Button.new()
	_forge_btn.text = tr("Forjar")
	_forge_btn.pressed.connect(func(): forge_requested.emit(blueprint_id, selected_rank))
	for n in [prev, _rank_label, next, _forge_btn]:
		row.add_child(n)
	$VBox.add_child(row)


func _refresh_rank() -> void:
	if _rank_label:
		_rank_label.text = Biomes.roman(selected_rank)
	name_label.text = (_blueprint_name() if blueprint_data else str(blueprint_id)) + Ranks.suffix(selected_rank)


## Sacudida cuando el encargo no se puede hacer
func reject_feedback() -> void:
	var base_x := position.x
	var tw := create_tween()
	for i in 4:
		tw.tween_property(self, "position:x", base_x + (8.0 if i % 2 == 0 else -8.0), 0.045)
	tw.tween_property(self, "position:x", base_x, 0.05)
```

El selector muestra el numeral también en el rango I, para que se vea qué se elige. El nombre, en cambio, solo lleva numeral desde el II. `custom_minimum_size` de la tarjeta pasa de `(160, 180)` a `(160, 230)` en `BlueprintCard.tscn`, para que quepa la fila.

`BlueprintLibraryPanel.gd`: pasa el rango a la tarjeta, reenvía la petición y muestra el motivo si se rechaza.

```gdscript
signal own_order_requested(bp_id: StringName, rank: int)

var _cards: Dictionary = {}  # bp_id -> tarjeta
```

En `populate_blueprints()`:

```gdscript
		var rank: int = dm.get_unlocked_rank(bp_id) if dm.has_method("get_unlocked_rank") else (1 if is_unlocked else 0)
		if card.has_method("set_blueprint_data"):
			card.set_blueprint_data(bp_id, blueprint, is_unlocked, rank)
		if card.has_signal("forge_requested"):
			card.forge_requested.connect(func(id, r): own_order_requested.emit(id, r))
		_cards[bp_id] = card
```

(Vacía `_cards` al principio de `populate_blueprints()`.)

```gdscript
const REJECT_TEXTS := {
	&"no_materials": "Faltan materiales",
	&"queue_full": "La forja está llena",
	&"locked": "Rango bloqueado",
}


## El encargo no se ha podido hacer: la tarjeta tiembla y el motivo se ve en su nombre un momento.
func reject(bp_id: StringName, reason: StringName) -> void:
	var card = _cards.get(bp_id)
	if card == null:
		return
	card.reject_feedback()
	var label: Label = card.name_label
	var old := label.text
	label.text = tr(REJECT_TEXTS.get(reason, "Faltan materiales"))
	label.add_theme_color_override("font_color", Color(1.0, 0.42, 0.36))
	get_tree().create_timer(1.4).timeout.connect(func():
		if is_instance_valid(label):
			label.text = old
			label.remove_theme_color_override("font_color"))
```

- [ ] **Step 4: `HUDMain` lanza el encargo**

Extrae de `_on_request_slot_clicked` el bucle que busca la primera tarea `queued` y la arranca:

```gdscript
## Arranca la primera tarea en cola (pedido aceptado o encargo propio).
func _start_first_queued_task() -> void:
	if not (_crafting_manager and _crafting_manager.has_method("start_task")):
		return
	var queue = _crafting_manager.get_queue_snapshot() if _crafting_manager.has_method("get_queue_snapshot") else []
	for slot_info in queue:
		if slot_info.get("status") == "queued":
			_crafting_manager.start_task(slot_info.get("slot_index", 0))
			return
```

En `_on_request_slot_clicked`, el bloque que busca y arranca la tarea se sustituye por `_start_first_queued_task()`.

En `_ready()`:

```gdscript
	if blueprint_library and blueprint_library.has_signal("own_order_requested"):
		blueprint_library.own_order_requested.connect(_on_own_order_requested)
```

```gdscript
## Encargo propio desde la biblioteca: cobra la receta y lanza los minijuegos, o explica por qué no.
func _on_own_order_requested(bp_id: StringName, rank: int) -> void:
	var reason: StringName = _crafting_manager.place_own_order(bp_id, rank) if _crafting_manager else &"locked"
	if reason == &"":
		Sfx.play(&"request_accept")
		if blueprint_library and blueprint_library.has_method("close"):
			blueprint_library.close()
		_start_first_queued_task()
	else:
		Sfx.play(&"ui_tap", 0.0, 0.55)  # "tunc" grave: no se puede
		if blueprint_library and blueprint_library.has_method("reject"):
			blueprint_library.reject(bp_id, reason)
```

- [ ] **Step 5: Numeral en el panel de Equipo (comprobarlo)**

Ya está hecho con la rejilla: `EquipmentPanel._ficha_text` usa `get_name_with_rank()`, la ficha completa (`_open_card`) la reutiliza y la confirmación de venta también. La tira del botín (`LootStripView`) no enseña nombres ni tooltip, y la tienda usa `get_display_name()`, que lleva el numeral desde la tarea 5. Solo queda verlo.

En `VisualCapture._run_inventory_plan()`, la espada maestra legendaria (la primera `add.call`, cuya ficha completa abre el plan al final) pasa a ser de rango II:

```gdscript
	var legend: CraftedItem = add.call(&"sword_masterwork", 1.0, InventoryManager.PLACE_HERO, Vector2i(5, 0))  # legendaria (Filo ígneo), de pie en la columna derecha
	legend.rank = 2  # rango II: la ficha enseña «… II» (solo el nombre: la captura no mira sus números)
```

y en la cabecera, la línea del plan `inventory` añade «(la maestra, de rango II)».

- [ ] **Step 6: Textos**

Filas en `locale/textos.csv`:

```
"Forjar","Forjar","Forge"
"Faltan materiales","Faltan materiales","Missing materials"
"La forja está llena","La forja está llena","The forge is full"
"Rango bloqueado","Rango bloqueado","Rank locked"
```

(Si la tarjeta de idioma ya creó "Faltan materiales" para las tarjetas de pedido, no dupliques la fila.)

Run: `D:/Software/Godot/godot_ver4.5.exe --headless --path . --import`

- [ ] **Step 7: Ejecutar, capturar y ver que pasa**

Run: RankTests, InventoryGridTests, GameplayTests y PixelTests. Expected: 0 fallos.

Run: TextTests (filas nuevas del CSV). Expected: 0 fallos.

Captura el plan `panels` de VisualCapture (`APPDATA=<appdata> timeout 300 D:/Software/Godot/godot_ver4.5.exe --path . --write-movie <scratchpad>/t11/f.png --fixed-fps 10 --quit-after 120 res://scenes/tests/VisualCapture.tscn -- --plan=panels`) y abre los fotogramas de la biblioteca con Read. Las tarjetas muestran el selector y el botón sin salirse, y el nombre lleva el numeral desde el II.

Captura el plan `inventory` (misma orden con `--plan=inventory`, `<scratchpad>/t11i/f.png` y `--quit-after 150`) y abre los últimos fotogramas: la ficha completa de la espada maestra lleva el numeral II tras su nombre. Como la ficha completa es la breve (`_ficha_text`) más las aristas, con eso quedan vistas las dos.

- [ ] **Step 8: Commit**

```bash
git add scripts/autoload/CraftingManager.gd scripts/ui/BlueprintCard.gd scenes/UI/BlueprintCard.tscn scripts/ui/BlueprintLibraryPanel.gd scripts/ui/HUDMain.gd scripts/tests/VisualCapture.gd scripts/tests/RankTests.gd locale/textos.csv
git commit -m "feat: encargo propio desde la biblioteca y numeral de rango en la interfaz"
```

---

### Task 12: Muro, farmeo y selector de sala

Se ejecuta **antes que la tarea 3**: no depende del balance. Parte de la rama con las tareas 1 y 2 hechas.

**Files:**
- Modify:
  - `scripts/autoload/GameManager.gd` (récord, muro, candado, reintentos, viaje y guardado);
  - `scripts/gameplay/Corridor.gd` (vida llena al entrar, sala siguiente y viaje);
  - `scripts/ui/HeroViewOverlay.gd` (selector, candado, muro y fundido del viaje);
  - `scripts/tests/VisualCapture.gd` (plan `wall`), `locale/textos.csv`.
- Test: `scripts/tests/GameplayTests.gd`

**Interfaces:**
- Consumes:
  - `GameManager.current_enemy_level`, `best_enemy_level`, `register_hero_death()`, `request_respawn()`, `advance_enemy_level()`, `apply_buff()`, `to_save_data()`, `load_save_data()`;
  - `InventoryManager.equipment_changed`;
  - `Corridor.reset_combat()`, `_enter_room()`, `advance_enemy()`, `_on_enemy_level_changed()`;
  - `Hero.heal(amount: int) -> int`;
  - `Biomes.room_in_biome(room)` (1..10) y `Biomes.ROOMS_PER_BIOME` (10).
- Produces:
  - `GameManager.WALL_RETRY_WINS` (3), `GameManager.wall_room: int` (0 = sin muro) y `GameManager.room_locked: bool`;
  - señales `GameManager.room_travel(room: int)`, `GameManager.wall_changed(wall_room: int)` y `GameManager.room_lock_changed(locked: bool)`;
  - `GameManager.room_cleared()`, `travel_to_room(room: int)`, `set_room_locked(locked: bool)`, `retry_wall_now()` y `selector_target(from_room: int, dir: int, by_biome: bool) -> int`;
  - señal `Corridor.room_traveled(room: int)`;
  - en el guardado, las claves `wall_room` y `room_locked` de `GameManager.to_save_data()`.
  - `GameManager.advance_enemy_level()` no cambia: sigue pasando a la sala siguiente sin mirar muro ni candado. Lo usan los planes de `VisualCapture` para saltar de sala.

**Reglas** (spec, apartado 7):
- El récord (`best_enemy_level`) es la sala más profunda que Tico ha alcanzado y aún no ha vencido. Vencerla lo sube aunque Tico se quede, con el candado puesto.
- **Al perder en la sala X:** X pasa a ser el muro y Tico reaparece en la X−1 (la 1 como mínimo). Con candado, el candado baja con él, porque su sala es la actual.
- **Al vencer:**
  - con candado, repite la sala;
  - en la sala anterior al muro, farmea: repite la sala y a la tercera victoria (`WALL_RETRY_WINS`) pasa al muro;
  - vencer el muro, o cualquier sala más honda, lo quita;
  - si no, avanza.
- **Reintento al momento:** con muro, sin candado y con la partida en marcha, Tico viaja al muro en cuanto cambia su equipo (`InventoryManager.equipment_changed`) o bebe una poción de efecto (`apply_buff`). La poción de Vida no cuenta: se gasta en el duelo en curso.
- **Selector:**
  - `travel_to_room` lleva a Tico a una sala entre la 1 y el récord;
  - elegir una sala por debajo del récord pone el candado, salvo que sea el muro (elegir el muro o el récord es probarlo);
  - elegir la sala en la que ya está solo cambia el candado.
  - Quitar el candado lleva a la sala anterior al muro (o al récord si no hay muro), salvo que Tico ya esté ahí.
- **Viaje:**
  - lo hace el pasillo al recibir `room_travel`: abandona el combate a medias sin premio ni castigo y pone a Tico con la vida llena en la sala nueva;
  - con Tico caído no hace nada, porque la reaparición ya usa la sala nueva;
  - `GameManager` emite `room_travel` antes que `enemy_level_changed`, así el pasillo, ya recolocado, ignora la segunda señal.
- **Duelos:** al cruzar la puerta de una sala (`Corridor._enter_room`), Tico recupera toda la vida con `Hero.heal()`.

**Orden de los eventos al matar** (comentario de `Corridor._ready`):
1. `CombatController._on_enemy_died` llama a `Corridor.advance_enemy()`, que ahora llama a `GameManager.room_cleared()`.
2. Si la sala se repite, `room_cleared` emite `enemy_level_changed` con la misma sala. Todavía dentro de la señal `died`, el enemigo sigue muerto, así que `Corridor._on_enemy_level_changed` coloca otro enemigo de esa sala por delante, con su puerta.
3. Después llega `Corridor._on_enemy_died_fx`, que presenta el botín.

- [ ] **Step 1: Pruebas que fallan**

Añade al final de `scripts/tests/GameplayTests.gd`:

```gdscript
# ─── Muro, farmeo y selector de sala (spec de rangos, apartado 7) ─────

## Estado de la partida en GameManager, para devolverlo al acabar cada prueba (las pruebas del muro lo
## cambian con load_save_data, la misma entrada que usa el guardado).
func _gm_snapshot() -> Dictionary:
	var gm := _gm()
	var snap: Dictionary = gm.to_save_data()
	snap["_dungeon_state"] = gm.dungeon_state
	return snap


func _gm_restore(snap: Dictionary) -> void:
	var gm := _gm()
	gm.dungeon_state = snap["_dungeon_state"]  # antes de cargar: sin partida en marcha no se mueve ningún pasillo
	gm.load_save_data(snap)
	gm.clear_buffs()


## Partida de prueba con su sala, su récord y, si se dan, muro y candado. La deja en marcha.
func _gm_setup(current: int, best: int, wall: int = 0, locked: bool = false) -> void:
	var gm := _gm()
	gm.load_save_data({"current_enemy_level": current, "best_enemy_level": best, "wall_room": wall, "room_locked": locked})
	gm.dungeon_state = gm.DungeonState.RUNNING


## Pasillo de prueba sobre la partida de GameManager (empieza en su sala actual).
func _new_corridor() -> Node2D:
	var corridor: Node2D = load("res://scenes/Corridor.tscn").instantiate()
	add_child(corridor)
	return corridor


func test_losing_leaves_a_wall_and_farms_the_room_before() -> void:
	var gm := _gm()
	var snap := _gm_snapshot()
	_gm_setup(12, 12)
	gm.register_hero_death()
	check(gm.current_enemy_level == 11 and gm.wall_room == 12, "cae en la 12: reaparece en la 11 y la 12 es el muro (%d, %d)" % [gm.current_enemy_level, gm.wall_room])
	gm.request_respawn()
	gm.room_cleared()
	gm.room_cleared()
	check(gm.current_enemy_level == 11, "las dos primeras victorias farmea la 11 (%d)" % gm.current_enemy_level)
	gm.room_cleared()
	check(gm.current_enemy_level == 12, "a la tercera vuelve al muro (%d)" % gm.current_enemy_level)
	gm.register_hero_death()
	gm.request_respawn()
	gm.room_cleared()
	gm.room_cleared()
	check(gm.current_enemy_level == 11, "tras otra caída la cuenta vuelve a empezar (%d)" % gm.current_enemy_level)
	_im().equipment_changed.emit({})
	check(gm.current_enemy_level == 12, "con equipo nuevo prueba el muro al momento (%d)" % gm.current_enemy_level)
	gm.register_hero_death()
	gm.request_respawn()
	gm.apply_buff(&"luck", 60.0)
	check(gm.current_enemy_level == 12, "y también al beber una poción de efecto (%d)" % gm.current_enemy_level)
	gm.room_cleared()
	check(gm.wall_room == 0 and gm.current_enemy_level == 13 and gm.best_enemy_level == 13, "vencer el muro lo quita y sube el récord (muro %d, sala %d, récord %d)" % [gm.wall_room, gm.current_enemy_level, gm.best_enemy_level])
	_gm_restore(snap)
	await _flush_deferred_saves()


func test_a_wall_in_room_one_is_retried_on_every_respawn() -> void:
	var gm := _gm()
	var snap := _gm_snapshot()
	_gm_setup(1, 1)
	gm.register_hero_death()
	check(gm.current_enemy_level == 1 and gm.wall_room == 1, "cae en la 1: reaparece en la 1, delante del muro (%d, %d)" % [gm.current_enemy_level, gm.wall_room])
	gm.request_respawn()
	gm.room_cleared()
	check(gm.wall_room == 0 and gm.current_enemy_level == 2 and gm.best_enemy_level == 2, "al vencerlo sigue a la 2 (muro %d, sala %d, récord %d)" % [gm.wall_room, gm.current_enemy_level, gm.best_enemy_level])
	_gm_restore(snap)
	await _flush_deferred_saves()


func test_room_selector_and_lock() -> void:
	var gm := _gm()
	var snap := _gm_snapshot()
	_gm_setup(30, 30)
	gm.travel_to_room(99)
	check(gm.current_enemy_level == 30 and not gm.room_locked, "no pasa del récord, y el récord no pone el candado (%d)" % gm.current_enemy_level)
	gm.travel_to_room(5)
	check(gm.current_enemy_level == 5 and gm.room_locked, "una sala por debajo del récord pone el candado (%d)" % gm.current_enemy_level)
	gm.room_cleared()
	check(gm.current_enemy_level == 5, "con candado repite la sala (%d)" % gm.current_enemy_level)
	gm.register_hero_death()
	gm.request_respawn()
	check(gm.current_enemy_level == 4 and gm.wall_room == 5 and gm.room_locked, "si cae con candado, el candado baja con él (sala %d, muro %d)" % [gm.current_enemy_level, gm.wall_room])
	gm.room_cleared()
	gm.room_cleared()
	gm.room_cleared()
	check(gm.current_enemy_level == 4, "con candado no reintenta el muro (%d)" % gm.current_enemy_level)
	gm.set_room_locked(false)
	check(gm.current_enemy_level == 4 and not gm.room_locked, "sin candado sigue delante del muro (%d)" % gm.current_enemy_level)
	gm.travel_to_room(0)
	check(gm.current_enemy_level == 1, "tampoco baja de la sala 1 (%d)" % gm.current_enemy_level)
	gm.travel_to_room(5)
	check(gm.current_enemy_level == 5 and not gm.room_locked, "elegir el muro es probarlo, sin candado (%d)" % gm.current_enemy_level)
	_gm_setup(7, 30, 0, true)
	gm.set_room_locked(false)
	check(gm.current_enemy_level == 29, "sin muro, quitar el candado lo lleva delante del récord (%d)" % gm.current_enemy_level)
	_gm_setup(30, 30)
	gm.set_room_locked(true)
	gm.room_cleared()
	check(gm.current_enemy_level == 30 and gm.best_enemy_level == 31, "vencer el récord con candado lo sube aunque Tico se quede (sala %d, récord %d)" % [gm.current_enemy_level, gm.best_enemy_level])
	check(gm.selector_target(25, -1, true) == 11, "mantener atrás desde la 25: principio del bioma anterior (%d)" % gm.selector_target(25, -1, true))
	check(gm.selector_target(25, 1, true) == 31, "mantener adelante: principio del siguiente (%d)" % gm.selector_target(25, 1, true))
	check(gm.selector_target(5, -1, true) == 1, "desde el primer bioma, la 1 (%d)" % gm.selector_target(5, -1, true))
	check(gm.selector_target(31, 1, false) == 31, "sin pasar del récord (%d)" % gm.selector_target(31, 1, false))
	_gm_restore(snap)
	await _flush_deferred_saves()


func test_wall_and_lock_are_saved() -> void:
	var gm := _gm()
	var snap := _gm_snapshot()
	_gm_setup(11, 12, 12, true)
	var data: Dictionary = gm.to_save_data()
	check(int(data.get("wall_room", 0)) == 12 and bool(data.get("room_locked", false)), "el guardado lleva el muro y el candado (%s)" % data)
	gm.load_save_data({"current_enemy_level": 3, "best_enemy_level": 9})
	check(gm.wall_room == 0 and not gm.room_locked, "una partida sin esos campos carga sin muro ni candado")
	gm.load_save_data({"current_enemy_level": 3, "best_enemy_level": 9, "wall_room": 50})
	check(gm.wall_room == 9, "un muro más allá del récord se queda en el récord (%d)" % gm.wall_room)
	_gm_restore(snap)
	await _flush_deferred_saves()


func test_each_room_starts_with_full_health_and_travel_abandons_the_fight() -> void:
	var gm := _gm()
	var snap := _gm_snapshot()
	_gm_setup(3, 12)
	var start: Dictionary = _im().get_materials()
	var corridor := _new_corridor()
	var hero: Node2D = corridor.get_node("Hero")
	var enemy: Node2D = corridor.get_node("Enemy")
	hero.hp = maxi(1, hero.max_hp / 2)
	corridor._enter_room(3)
	check(hero.hp == hero.max_hp, "al entrar en una sala, Tico tiene la vida llena (%d/%d)" % [hero.hp, hero.max_hp])
	corridor._begin_fight()
	hero.hp = maxi(1, hero.max_hp / 2)
	gm.travel_to_room(7)
	check(not corridor.combat_controller.combat_active, "viajar abandona el combate a medias")
	check(corridor.level == 7 and enemy.level == 7 and enemy.alive, "el pasillo pasa a la sala 7 con su enemigo (%d, %d)" % [corridor.level, enemy.level])
	check(hero.alive and hero.hp == hero.max_hp, "Tico llega con la vida llena (%d/%d)" % [hero.hp, hero.max_hp])
	check(_gained_since(start).is_empty(), "sin premio: no entra botín (%s)" % _gained_since(start))
	corridor.queue_free()
	_gm_restore(snap)
	await _flush_deferred_saves()
	await _silence_loot_sounds()


func test_farming_puts_another_enemy_of_the_same_room_ahead() -> void:
	var gm := _gm()
	var snap := _gm_snapshot()
	_gm_setup(11, 12, 12)
	gm.enemies_defeated[11] = true  # sin plano de primera victoria
	var start: Dictionary = _im().get_materials()
	var corridor := _new_corridor()
	var enemy: Node2D = corridor.get_node("Enemy")
	enemy.take_damage(enemy.hp)
	check(gm.current_enemy_level == 11, "tras vencer delante del muro sigue en la 11 (%d)" % gm.current_enemy_level)
	check(enemy.alive and enemy.level == 11, "el pasillo pone otro enemigo de la 11 por delante (%d)" % enemy.level)
	check(corridor._next_gate_room == 11, "con su puerta de la sala 11 (%d)" % corridor._next_gate_room)
	corridor.queue_free()
	_gm_restore(snap)
	_im().consume_materials(_gained_since(start))  # devuelve el botín de prueba
	await _flush_deferred_saves()
	await _silence_loot_sounds()


func test_losing_in_the_corridor_respawns_in_the_room_before() -> void:
	var gm := _gm()
	var snap := _gm_snapshot()
	_gm_setup(12, 12)
	var corridor := _new_corridor()
	var hero: Node2D = corridor.get_node("Hero")
	hero.take_damage(hero.hp * 10, true)  # el pulso no mira la armadura
	check(gm.wall_room == 12 and gm.current_enemy_level == 11, "cae en la 12: muro en la 12 y vuelta a la 11 (%d, %d)" % [gm.wall_room, gm.current_enemy_level])
	corridor._respawn_timer.stop()
	corridor._on_respawn_timeout()  # sin esperar el segundo y medio de la reaparición
	check(corridor.level == 11 and corridor.enemy.level == 11, "reaparece en la 11 con su enemigo (%d, %d)" % [corridor.level, corridor.enemy.level])
	check(hero.alive and hero.hp == hero.max_hp, "con la vida llena (%d/%d)" % [hero.hp, hero.max_hp])
	corridor.queue_free()
	_gm_restore(snap)
	await _flush_deferred_saves()
	await _silence_loot_sounds()


func test_travel_while_fallen_waits_for_the_respawn() -> void:
	var gm := _gm()
	var snap := _gm_snapshot()
	_gm_setup(12, 12)
	var corridor := _new_corridor()
	var hero: Node2D = corridor.get_node("Hero")
	hero.take_damage(hero.hp * 10, true)
	gm.travel_to_room(5)
	check(corridor.state == corridor.State.DEAD and not hero.alive, "con Tico caído, el viaje espera a la reaparición")
	corridor._respawn_timer.stop()
	corridor._on_respawn_timeout()
	check(corridor.level == 5 and corridor.enemy.level == 5 and hero.alive, "reaparece en la sala elegida (%d, %d)" % [corridor.level, corridor.enemy.level])
	check(gm.room_locked, "con el candado de haberla elegido")
	corridor.queue_free()
	_gm_restore(snap)
	await _flush_deferred_saves()
	await _silence_loot_sounds()


func test_room_selector_in_the_strip() -> void:
	var gm := _gm()
	var snap := _gm_snapshot()
	_gm_setup(11, 12, 12)
	var overlay: Control = load("res://scripts/ui/HeroViewOverlay.gd").new()
	add_child(overlay)
	check(overlay._record_label.text == "Muro: sala 12", "con muro, el indicador dice «Muro: sala 12» (%s)" % overlay._record_label.text)
	for b in [overlay._prev_button, overlay._lock_button, overlay._next_button]:
		check(b.size.x >= 88.0 and b.size.y >= 88.0, "botón del selector con tamaño de dedo (%s)" % b.size)
	overlay._on_arrow_down(1)
	overlay._on_arrow_up(1)
	check(gm.current_enemy_level == 12 and not gm.room_locked, "toque corto adelante: la 12, probar el muro sin candado (%d)" % gm.current_enemy_level)
	check(overlay._next_button.disabled, "en el récord, la flecha adelante se apaga")
	_gm_setup(25, 40)
	overlay._on_arrow_down(-1)
	overlay._process(overlay.LONG_PRESS + 0.05)
	check(gm.current_enemy_level == 11 and gm.room_locked, "mantener pulsado atrás: principio del bioma anterior, con candado (%d)" % gm.current_enemy_level)
	overlay._on_arrow_up(-1)
	check(gm.current_enemy_level == 11, "soltar tras el salto no mueve otra sala (%d)" % gm.current_enemy_level)
	overlay._on_lock_pressed()
	check(not gm.room_locked and gm.current_enemy_level == 39, "quitar el candado lo lleva delante del récord (%d)" % gm.current_enemy_level)
	check(overlay._record_label.text == "Récord: sala 40", "sin muro vuelve a decir el récord (%s)" % overlay._record_label.text)
	overlay.queue_free()
	_gm_restore(snap)
	await _flush_deferred_saves()
```

- [ ] **Step 2: Ejecutar y ver que fallan**

Run: `timeout 300 D:/Software/Godot/godot_ver4.5.exe --headless --path . res://scenes/tests/GameplayTests.tscn`
Expected: las 9 pruebas nuevas fallan: `room_cleared`, `travel_to_room` y `_prev_button` no existen, y al morir Tico vuelve a la sala 1. Las pruebas que ya había pasan.

- [ ] **Step 3: Muro, candado y selector en `GameManager.gd`**

Señales nuevas, tras `buffs_changed`:

```gdscript
signal room_travel(room: int)  # el selector o un reintento mandan a Tico a otra sala (viaje instantáneo)
signal wall_changed(wall_room: int)  # aparece o cae el muro (0 = sin muro)
signal room_lock_changed(locked: bool)  # candado del selector de sala
```

Cambia el comentario de `best_enemy_level` y añade, justo debajo:

```gdscript
var best_enemy_level: int = 1  # Récord: la sala más profunda alcanzada que Tico aún no ha vencido

## Muro, farmeo y selector de sala (spec de rangos, apartado 7)
const WALL_RETRY_WINS := 3  # delante del muro, Tico lo reintenta cada 3 victorias
var wall_room: int = 0  # sala donde Tico perdió por última vez, hasta que la vence (0 = sin muro)
var room_locked: bool = false  # candado: Tico repite su sala y no reintenta el muro
var _wins_since_retry: int = 0
```

En `apply_buff`, tras emitir `buffs_changed`:

```gdscript
	retry_wall_now()  # una poción de efecto manda a Tico a probar el muro
```

Sustituye `register_hero` y `_on_equipment_changed`:

```gdscript
func register_hero(hero_node: Node) -> void:
	_hero = hero_node
	# Aplicar stats de equipo actual al registrar héroe
	_refresh_hero_stats()

func _on_equipment_changed(_equipment_stats: Dictionary) -> void:
	"""Cuando cambia el equipamiento, recalcular stats del héroe y, delante de un muro, probarlo ya"""
	_refresh_hero_stats()
	retry_wall_now()

func _refresh_hero_stats() -> void:
	if is_instance_valid(_hero) and _hero.has_method("reset_stats"):
		_hero.reset_stats()
		DebugManager.log_msg(&"game", "Hero stats recalculated after equipment change")
```

En `start_run`, dentro de `if not _save_loaded:`, añade:

```gdscript
		_set_wall(0)
		_set_room_locked(false)
```

y, fuera del `if`, `_wins_since_retry = 0`.

Sustituye `register_hero_death`:

```gdscript
func register_hero_death():
	if dungeon_state != DungeonState.RUNNING:
		return
	death_count += 1
	dungeon_state = DungeonState.HERO_DEAD
	var fell_at := current_enemy_level
	DebugManager.log_msg(&"game", "Hero died (total: %d) at room %d - it becomes the wall" % [death_count, fell_at])
	emit_signal("hero_died", death_count)
	# La sala donde cae es el muro y reaparece en la anterior (spec de rangos, apartado 7). Con candado,
	# el candado baja con él: su sala es la actual.
	current_enemy_level = maxi(1, fell_at - 1)
	_wins_since_retry = 0
	_set_wall(fell_at)
```

Añade, tras `advance_enemy_level`:

```gdscript
## Tico ha vencido al enemigo de su sala: decide adónde va (spec de rangos, apartado 7).
## - Vencer la sala del récord lo sube, aunque Tico se quede (con el candado puesto).
## - Vencer el muro, o una sala más honda, lo quita.
## - Con candado repite la sala. En la sala anterior al muro la farmea y a las WALL_RETRY_WINS
##   victorias pasa al muro. Si no, avanza.
func room_cleared() -> void:
	var cleared := current_enemy_level
	if cleared >= best_enemy_level:
		best_enemy_level = cleared + 1
		emit_signal("record_changed", best_enemy_level)
	if wall_room > 0 and cleared >= wall_room:
		_set_wall(0)
	var repeat := room_locked
	if not repeat and wall_room > 0 and cleared + 1 == wall_room:
		_wins_since_retry += 1
		repeat = _wins_since_retry < WALL_RETRY_WINS
		if not repeat:
			_wins_since_retry = 0
	if repeat:
		# Otro enemigo de la misma sala: el pasillo lo pone por delante, como al avanzar
		emit_signal("enemy_level_changed", current_enemy_level)
		emit_signal("enemy_spawned", current_enemy_level)
	else:
		advance_enemy_level()


## Selector de sala: manda a Tico a una sala entre la 1 y el récord. Por debajo del récord pone el
## candado, salvo en el muro: elegir el muro o el récord es probarlo. Si ya está en esa sala, solo
## cambia el candado.
func travel_to_room(room: int) -> void:
	var target := clampi(room, 1, best_enemy_level)
	_set_room_locked(target < best_enemy_level and target != wall_room)
	if target != current_enemy_level:
		_travel(target)


## Candado del selector. Quitarlo lleva a Tico a la sala anterior al muro (o al récord si no hay muro).
func set_room_locked(locked: bool) -> void:
	if locked == room_locked:
		return
	_set_room_locked(locked)
	if locked:
		return
	var front := maxi(1, (wall_room if wall_room > 0 else best_enemy_level) - 1)
	if front != current_enemy_level:
		_travel(front)


## Con muro y sin candado, Tico lo prueba ya (equipo nuevo o poción de efecto). Solo con la partida en marcha.
func retry_wall_now() -> void:
	if wall_room <= 0 or room_locked or dungeon_state != DungeonState.RUNNING:
		return
	if current_enemy_level != wall_room:
		_travel(wall_room)


## Sala a la que lleva el selector desde `from_room`: la de al lado (dir = −1 o 1) o, con by_biome, el
## principio del bioma anterior o del siguiente. Siempre entre la 1 y el récord.
func selector_target(from_room: int, dir: int, by_biome: bool) -> int:
	var target := from_room + dir
	if by_biome:
		var biome_start := from_room - Biomes.room_in_biome(from_room) + 1
		target = biome_start + Biomes.ROOMS_PER_BIOME * dir
	return clampi(target, 1, best_enemy_level)


## Viaje instantáneo. El pasillo (room_travel) abandona el combate a medias, sin premio ni castigo, y pone
## a Tico en la sala nueva con la vida llena; con Tico caído, la reaparición ya lo deja ahí. room_travel va
## antes que enemy_level_changed: el pasillo ya recolocado ignora la segunda.
func _travel(room: int) -> void:
	current_enemy_level = room
	_wins_since_retry = 0
	emit_signal("room_travel", room)
	emit_signal("enemy_level_changed", room)


func _set_wall(room: int) -> void:
	if wall_room == room:
		return
	wall_room = room
	emit_signal("wall_changed", wall_room)


func _set_room_locked(locked: bool) -> void:
	if room_locked == locked:
		return
	room_locked = locked
	emit_signal("room_lock_changed", room_locked)
	_on_trigger_save()
```

En `to_save_data`, añade al diccionario:

```gdscript
		"wall_room": wall_room,
		"room_locked": room_locked,
```

En `load_save_data`, tras leer `best_enemy_level`:

```gdscript
	wall_room = clampi(int(data.get("wall_room", 0)), 0, best_enemy_level)
	room_locked = bool(data.get("room_locked", false))
	_wins_since_retry = 0
```

(Sin señales: el HUD relee todo con `progress_loaded`, como la sala y el récord.)

- [ ] **Step 4: Sala siguiente, vida llena y viaje en `Corridor.gd`**

Señal nueva, tras `hero_returned`:

```gdscript
signal room_traveled(room: int)  # viaje del selector o reintento del muro (el HUD funde desde negro)
```

En `_ready`, dentro de `if _game_manager:`:

```gdscript
		if _game_manager.has_signal("room_travel"):
			_game_manager.room_travel.connect(_on_room_travel)
```

Sustituye `advance_enemy`:

```gdscript
func advance_enemy():
	# La sala siguiente la decide GameManager: avanzar, repetir la sala o volver al muro
	if _game_manager and _game_manager.has_method("room_cleared"):
		_game_manager.room_cleared()
	else:
		level += 1
		spawn_enemy(level, hero.position.x + SPAWN_AHEAD)
		state = State.RUN
		dist_ref = enemy.position.x - hero.position.x
```

Sustituye `_enter_room`:

```gdscript
func _enter_room(room: int) -> void:
	# Cada sala es un duelo: Tico entra con la vida llena (spec de rangos, apartado 7)
	if hero.alive:
		hero.heal(hero.max_hp - hero.hp)
	backdrop.set_room(room, true)
	room_entered.emit(room, Biomes.is_boss_room(room))
```

Añade en la sección de muerte y reaparición:

```gdscript
## Selector de sala o reintento del muro (GameManager.room_travel): viaje instantáneo. Un combate a medias
## se abandona sin premio ni castigo. Con Tico caído no hace nada: la reaparición ya usa la sala nueva.
func _on_room_travel(room: int) -> void:
	if state == State.DEAD:
		return
	_set_frozen(false)
	_hitstop = 0.0
	reset_combat(false)
	room_traveled.emit(room)
```

Actualiza el comentario de cabecera: "…botín visible, transiciones de muerte/reaparición y viajes del selector de sala."

- [ ] **Step 5: Selector, candado y muro en `HeroViewOverlay.gd`**

En la cabecera, tras la línea de las pociones, añade:

```gdscript
## Selector de sala (spec de rangos, apartado 7), bajo la banda superior, a la derecha: flecha atrás,
## candado y flecha adelante, con tamaño de dedo. Toque corto: la sala de al lado; mantener pulsado
## LONG_PRESS: el principio del bioma anterior o del siguiente. Con muro, el récord dice "Muro: sala N".
```

Constantes, tras las de las pociones:

```gdscript
const SELECTOR_POS := Vector2(776, 100)
const SELECTOR_BUTTON := Vector2(96, 96)
const SELECTOR_GAP := 4.0
const LONG_PRESS := 0.45
```

Variables:

```gdscript
var _prev_button: Button
var _lock_button: Button
var _next_button: Button
var _held_dir := 0  # flecha que se mantiene pulsada (−1, 1 o 0)
var _held_time := 0.0
var _held_jumped := false  # ya saltó de bioma en esta pulsación
```

En `_ready`, dentro de `if _game_manager:`:

```gdscript
		if _game_manager.has_signal("wall_changed"):
			_game_manager.wall_changed.connect(func(_w): _refresh_room())
			_game_manager.room_lock_changed.connect(func(_l): _refresh_room())
		_game_manager.enemy_level_changed.connect(func(_l): _refresh_selector())
```

En `bind_corridor`:

```gdscript
	corridor.room_traveled.connect(_on_room_traveled)
```

En `_build()`, antes de crear `_fade` (el fundido tiene que quedar por encima de los botones):

```gdscript
	_prev_button = _make_selector_button(0)
	_lock_button = _make_selector_button(1)
	_next_button = _make_selector_button(2)
	_prev_button.button_down.connect(_on_arrow_down.bind(-1))
	_prev_button.button_up.connect(_on_arrow_up.bind(-1))
	_next_button.button_down.connect(_on_arrow_down.bind(1))
	_next_button.button_up.connect(_on_arrow_up.bind(1))
	_lock_button.pressed.connect(_on_lock_pressed)
```

Y la función que los crea (botones planos: el icono lo pinta `_draw`):

```gdscript
func _make_selector_button(index: int) -> Button:
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.position = SELECTOR_POS + Vector2((SELECTOR_BUTTON.x + SELECTOR_GAP) * index, 0)
	b.size = SELECTOR_BUTTON
	add_child(b)
	return b
```

En `_process`, antes de `queue_redraw()`:

```gdscript
	# Selector: mantener pulsada una flecha salta de bioma, una sola vez por pulsación
	if _held_dir != 0 and not _held_jumped:
		_held_time += delta
		if _held_time >= LONG_PRESS:
			_held_jumped = true
			_travel_selector(_held_dir, true)
```

Sustituye `_refresh_room` y añade `_refresh_selector`:

```gdscript
func _refresh_room() -> void:
	_room_label.text = tr("Sala %d") % _room
	var idx := Biomes.biome_index_for_room(_room)
	_biome_label.text = Biomes.display_name(idx)  # ya traducido
	_record = maxi(_record, _room)
	var wall: int = int(_game_manager.wall_room) if _game_manager and "wall_room" in _game_manager else 0
	_record_label.text = tr("Muro: sala %d") % wall if wall > 0 else tr("Récord: sala %d") % _record
	_refresh_selector()


## Flechas apagadas en los extremos (la sala 1 y el récord). El candado siempre se puede tocar.
func _refresh_selector() -> void:
	if _prev_button == null or _game_manager == null or not ("room_locked" in _game_manager):
		return
	var room: int = int(_game_manager.current_enemy_level)
	_prev_button.disabled = room <= 1
	_next_button.disabled = room >= int(_game_manager.best_enemy_level)
```

En `_on_record_changed`, cambia la línea que pone el texto por `_refresh_room()` (así respeta el muro):

```gdscript
func _on_record_changed(best: int) -> void:
	var was := _record
	_record = maxi(_record, best)
	_refresh_room()
	if best > was and best > 2 and not _record_announced:
		_record_announced = true
		show_toast(tr("¡Nuevo récord de profundidad!"), Color("ffd76a"))
```

En `_draw()`, tras `_draw_boss_pips()`, llama a `_draw_selector()`:

```gdscript
func _draw_selector() -> void:
	_draw_arrow(_prev_button, -1)
	_draw_lock(_lock_button)
	_draw_arrow(_next_button, 1)


func _selector_color(button: Button, lit: bool) -> Color:
	if button.disabled:
		return Color(0.5, 0.45, 0.42, 0.45)
	return Color("fff2c9") if lit else Color("f3d9a4")


func _draw_arrow(button: Button, dir: int) -> void:
	var c := button.position + button.size * 0.5
	draw_colored_polygon(SK.ellipse_pts(c, 40.0, 40.0, 24), Color(0, 0, 0, 0.45))
	var s := 20.0 * float(dir)
	var tri := PackedVector2Array([c + Vector2(s, 0), c + Vector2(-s * 0.7, 20), c + Vector2(-s * 0.7, -20)])
	if dir < 0:
		tri.reverse()  # el mismo sentido de giro en las dos flechas
	SK.outlined_poly(self, tri, _selector_color(button, _held_dir == dir), SK.OUTLINE, 3.0)


## Candado: cerrado y dorado con el candado puesto; abierto (el arco levantado a un lado) sin él.
func _draw_lock(button: Button) -> void:
	var c := button.position + button.size * 0.5
	draw_colored_polygon(SK.ellipse_pts(c, 40.0, 40.0, 24), Color(0, 0, 0, 0.45))
	var locked: bool = _game_manager != null and "room_locked" in _game_manager and bool(_game_manager.room_locked)
	var col := Color("ffd76a") if locked else Color("c9b8a0")
	var arc_c := c + (Vector2(0, -8) if locked else Vector2(-10, -14))
	draw_arc(arc_c, 11.0, PI, TAU, 16, SK.OUTLINE, 9.0, true)
	draw_arc(arc_c, 11.0, PI, TAU, 16, col, 5.0, true)
	var body := PackedVector2Array([c + Vector2(-16, -8), c + Vector2(16, -8), c + Vector2(16, 18), c + Vector2(-16, 18)])
	SK.outlined_poly(self, body, col, SK.OUTLINE, 3.0)
```

Controles y fundido del viaje, en la sección de señales:

```gdscript
func _on_arrow_down(dir: int) -> void:
	_held_dir = dir
	_held_time = 0.0
	_held_jumped = false


func _on_arrow_up(dir: int) -> void:
	if _held_dir != dir:
		return
	_held_dir = 0
	if not _held_jumped:
		_travel_selector(dir, false)


func _travel_selector(dir: int, by_biome: bool) -> void:
	if _game_manager == null or not _game_manager.has_method("travel_to_room"):
		return
	_game_manager.travel_to_room(_game_manager.selector_target(_game_manager.current_enemy_level, dir, by_biome))


func _on_lock_pressed() -> void:
	if _game_manager and _game_manager.has_method("set_room_locked"):
		_game_manager.set_room_locked(not _game_manager.room_locked)


## Fundido desde negro: tapa el salto de sala del selector o del reintento del muro.
func _on_room_traveled(_room_num: int) -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade.color.a = 0.9
	_fade.visible = true
	_fade_to(0.0, 0.3)
```

En `_on_hero_fell`, el subtítulo pasa a nombrar el muro:

```gdscript
	show_banner(tr("El héroe ha caído"), tr("Muro en la sala %d") % room, Color("ff8a7a"), 0.7)
```

- [ ] **Step 6: Textos**

En `locale/textos.csv`:
- añade, sin comillas y sin líneas en blanco:

```
Muro: sala %d,Muro: sala %d,Wall: room %d
Muro en la sala %d,Muro en la sala %d,Wall at room %d
```

- quita la fila de `Llegó a la sala %d · vuelve con su equipo`, que deja de usarse. Antes, confirma con `grep -rn "vuelve con su equipo" scripts scenes` que no la usa nadie más.

Run: `timeout 300 D:/Software/Godot/godot_ver4.5.exe --headless --path . --import`

- [ ] **Step 7: Ejecutar y ver que pasan**

Run: GameplayTests, RankTests, PixelTests y TextTests (comandos de la cabecera; BalanceSim aún no existe en la rama).
Expected: 0 fallos en las cuatro.

- [ ] **Step 8: Plan de capturas `wall` y revisión visual**

En `VisualCapture.gd`:
- en la cabecera de planes, añade:

```
##   wall   → muro y farmeo: cae en la sala 14, farmea la 13 con «Muro: sala 14» y el selector lo lleva a la 4
```

- añade `"wall": _run_wall_plan()` al `match` de `_ready()`;
- añade la función:

```gdscript
func _run_wall_plan() -> void:
	# Muro y farmeo (spec de rangos, apartado 7): Tico cae en la sala 14 y farmea la 13 con el candado
	# abierto; después el selector lo lleva a la 4, con el candado cerrado
	await get_tree().create_timer(1.5).timeout
	var gm := get_node_or_null("/root/GameManager")
	var hero: Node = gm.get_hero() if gm else null
	if gm == null or hero == null:
		return
	gm.best_enemy_level = maxi(gm.best_enemy_level, 14)
	gm.travel_to_room(14)
	await get_tree().create_timer(2.5).timeout
	hero.take_damage(hero.hp * 10, true)
	await get_tree().create_timer(3.5).timeout
	gm.set_room_locked(false)
	await get_tree().create_timer(4.0).timeout
	gm.travel_to_room(4)
```

Graba tras copiar `save.json`, y restáuralo después:

`timeout 300 D:/Software/Godot/godot_ver4.5.exe --path . --write-movie <scratchpad>/wall/f.png --fixed-fps 10 --quit-after 150 res://scenes/tests/VisualCapture.tscn -- --plan=wall`

Abre con Read los fotogramas de 3 s, 5 s, 9 s y 13 s (`f00000030.png`, `f00000050.png`, `f00000090.png` y `f00000130.png`). Comprueba:
- a los 3 s, Tico está en la sala 14 tras el fundido;
- a los 5 s sale el cartel "El héroe ha caído" con "Muro en la sala 14";
- a los 9 s farmea la sala 13; el indicador dice "Muro: sala 14" y se ven las dos flechas y el candado abierto, legibles sobre el fondo, sin tapar a Tico ni al enemigo;
- a los 13 s está en la sala 4 con el candado cerrado.

Repite con `--resolution 720x1280` para ver el selector a escala no entera. Si algo se tapa o no se lee, ajusta `SELECTOR_POS` o los colores y vuelve a grabar.

- [ ] **Step 9: Commit**

```bash
git add scripts/autoload/GameManager.gd scripts/gameplay/Corridor.gd scripts/ui/HeroViewOverlay.gd scripts/tests/GameplayTests.gd scripts/tests/VisualCapture.gd locale/textos.csv
git commit -m "feat: muro y farmeo (duelos, reintentos y selector de sala con candado)"
```

---

### Task 13: Capturas, verificación y documentación

**Files:**
- Modify: `scripts/tests/VisualCapture.gd` (plan `ranks`), `doc/ARCHITECTURE.md` (apartado nuevo y apartado 4.3), `doc/ROADMAP.md`, `doc/specs/2026-09-27-rangos-de-plano-por-ciclo.md` (estado)

- [ ] **Step 1: Plan de capturas `ranks`**

En `VisualCapture.gd`, añade `"ranks": _run_ranks_plan()` al `match` de `_ready()`, su línea a la cabecera de planes y la función:

```gdscript
func _run_ranks_plan() -> void:
	# Rangos (spec de rangos): pedidos con numeral y materiales de bioma, biblioteca con el selector de
	# rango y, en el Santuario del Vacío, botín con fragmento de vacío y el cartel de un hito
	await get_tree().create_timer(1.0).timeout
	var dm := get_node_or_null("/root/DataManager")
	var gm := get_node_or_null("/root/GameManager")
	var rm := get_node_or_null("/root/RequestsManager")
	var inv := get_node_or_null("/root/InventoryManager")
	var hud := _hud()
	if dm == null or gm == null or rm == null or inv == null or hud == null:
		return
	for id in dm.get_blueprint_ids_for_tier(Ranks.TIER_BASIC):
		dm.unlock_rank(id, 2)
	dm.unlock_rank(&"sword_advanced", 2)
	var mats: Array = ["wood", "iron", "leather", "cloth", "fire", "water", "ice", "poison"]
	for mat_id in Ranks.BIOME_MATERIALS:
		mats.append(String(mat_id))
	for mat in mats:
		inv.add_item(StringName(mat), 60)
	rm.refresh_all_requests()
	await get_tree().create_timer(2.0).timeout
	hud._on_blueprints_pressed()
	await get_tree().create_timer(3.0).timeout
	if hud.blueprint_library and hud.blueprint_library.has_method("close"):
		hud.blueprint_library.close()
	var hero: Node = gm.get_hero()
	if hero:
		hero.set_invincible(true)
	hud.get_corridor().enemy.biome_drop_chance = 1.0
	gm.wall_room = 0
	gm.room_locked = false
	gm.current_enemy_level = 44
	gm.advance_enemy_level()  # sala 45, Santuario del Vacío
	await get_tree().create_timer(2.0).timeout
	gm.blueprints_milestone.emit(2, Ranks.TIER_ADVANCED, [])
```

Graba (con la copia de la partida en `<appdata>`, Global Constraints):

`APPDATA=<appdata> timeout 300 D:/Software/Godot/godot_ver4.5.exe --path . --write-movie <scratchpad>/ranks/f.png --fixed-fps 10 --quit-after 120 res://scenes/tests/VisualCapture.tscn -- --plan=ranks`

Abre con Read los fotogramas de 1 s, 4 s, 7 s y 9 s y comprueba:
- las tarjetas de pedido llevan numeral y los materiales de bioma, con sus iconos pixel nítidos;
- la biblioteca muestra el selector y el botón «Forjar» sin salirse de la tarjeta;
- en la franja salen el botín con el material de bioma y el cartel "¡Planos avanzados II!".

Repite con 720x1280 (`--resolution 720x1280`) para ver la franja a escala no entera.

- [ ] **Step 2: Batería completa**

Vuelve a copiar la partida real a `<scratchpad>/appdata` (Global Constraints) y borra allí `save.v1.bak.json` y `save.v2.bak.json`, para que la batería arranque desde la partida de verdad.

Run: la batería de la cabecera (RankTests, InventoryGridTests, GameplayTests, PixelTests, TextTests, `bash balance/arnes.sh check` y las pruebas de Python).
Expected: todo en verde; `arnes.sh check` con 35 de 35.

Run (con la partida recién copiada otra vez): `APPDATA=<appdata> timeout 120 D:/Software/Godot/godot_ver4.5.exe --headless --path . --quit-after 600 res://scenes/Main.tscn 2>&1 | grep -iE "SCRIPT ERROR|Parse Error|ERROR:" | grep -v "resources still in use at exit"`
Expected: sin resultados.

Revisa `git status`: solo deben salir los ficheros de la tarea. Si sale `default_bus_layout.tres` con solo finales de línea, `git checkout -- default_bus_layout.tres`.

El aviso `1 resources still in use at exit` (el ambiente de la forja, `amb_forge_market_base.wav`) ya existía antes de este plan. Sale al cerrar desde la línea de órdenes, porque el servidor de audio del motor no suelta la reproducción en el mismo fotograma. Por eso se filtra.

- [ ] **Step 3: Documentación**

- `doc/ARCHITECTURE.md`:
  - apartado "Rangos por ciclo" con las clases nuevas (`Ranks`, `EnemyScaling`, `CombatMath`, `TrialDifficulty`), el flujo del rango (hito → `DataManager` → pedido → tarea → objeto → botín), el rango del equipo en la base de Tico, el guardado versión 3 y el bucle del muro (`GameManager`: récord, muro, candado y reintentos; `Corridor`: duelos y viaje del selector);
  - apartado 4.3 (inventario en rejilla): el rango del equipo (`InventoryManager.grid_rank` / `equipment_rank`, que delegan en `Ranks.team_rank`; lo usan `Hero.reset_stats` y las estadísticas del panel de Equipo); «Guardado versión 2» pasa a contar que la versión 3 es la de los rangos (el inventario no cambia de forma), y la copia de la partida antigua pasa a `save.v<versión de origen>.bak.json`;
  - en el detalle de `InventoryManager` (apartado 3.2), «versión 2» pasa a «versión 3».
- `doc/ROADMAP.md`:
  - en la fase 3, los rangos por ciclo sustituyen a "Más blueprints" y a la dificultad automática;
  - la decisión de publicación (gratis primero, sin anuncios al principio, medir la retención).
- Spec de rangos: `**Estado:** implementado (pendiente de revisión humana)`, conservando la fecha y lo que dice de la calibración con Balanza. El apartado 8 ya dice «versión 3» desde la tarea 6: compruébalo.
- Spec del inventario en rejilla, apartado 10: «(la base guarda la 1; los rangos pasarán a la 3)» pasa a «(la base guarda la 1; los rangos la pasaron a la 3)», y la copia de la partida antigua, a `save.v<versión de origen>.bak.json`.

- [ ] **Step 4: Commit**

```bash
git add scripts/tests/VisualCapture.gd doc/ARCHITECTURE.md doc/ROADMAP.md doc/specs/2026-09-27-rangos-de-plano-por-ciclo.md doc/specs/2026-09-27-inventario-en-rejilla.md
git commit -m "docs: rangos por ciclo en la arquitectura y el roadmap, y plan de capturas ranks"
```

---

## Cobertura del spec

| Spec | Tareas |
|---|---|
| 2. Ciclos y rangos (qué escala, numeral, `Ranks`) | 2, 5 |
| 3. Desbloqueo por jefes (hitos, estado, aviso, al cargar) | 2, 6, 7 |
| 4. Materiales de bioma (datos, iconos, receta, botín, Suerte) | 2, 4, 8 |
| 5. Pedidos, oro, crafteo, dificultad, arreglo de claves, encargo propio | 8, 9, 10, 11 |
| 6. Balance (objetivos, curva, Balanza, armadura) y base de Tico por el rango del equipo | 1, 3, 0 |
| 7. Muro, farmeo y selector de sala | 12, y 4 (extra de jefe con récord nuevo) |
| 8. Datos y guardado versión 3 (migración desde la 1 y la 2, copia por versión) | 5, 6, 8 |
| 9. Textos e idioma | 2, 4, 7, 11 |
| 10. Pruebas | todas; capturas en 7, 8, 11 y 13; `arnes.sh check` en 0 y 13 |
| 11. Qué cambia en el código | mapa de ficheros |
| 12. Fases | tareas 1-3 (fase 1), 0 y 5-6 (fase 2), 7-8 (fase 3), 4 (fase 4), 9-10 (fase 5), 11 (fase 6), 12 (fase 7), 13 (fase 8) |
