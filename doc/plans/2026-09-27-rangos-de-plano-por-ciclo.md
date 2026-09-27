# Rangos de plano por ciclo — Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** que cada vuelta a los 5 biomas (50 salas) desbloquee versiones más fuertes de los 12 planos (rango II, III…), con materiales de bioma, dificultad de minijuego por rango, encargo propio y vuelta rápida, sobre una curva de enemigos calibrada con una simulación.

**Architecture:** tres clases estáticas nuevas en `scripts/core/`:
- `EnemyScaling` tiene la curva de enemigos;
- `CombatMath` tiene las fórmulas del combate sin nodos (las usan `Hero`, `Enemy` y la simulación);
- `Ranks` tiene ciclos, hitos, multiplicadores y recetas.

El rango viaja como un entero junto al plano:
- desbloqueo: `DataManager` guarda el rango máximo por plano;
- pedidos (`RequestsManager`) y tareas (`CraftingManager`);
- objeto forjado (`CraftedItem.rank`);
- guardado, que pasa a la versión 2.

Para calibrar hay una escena de pruebas sin ventana, `BalanceSim`, que simula carreras de Tico desde la sala 1 con las fórmulas reales y comprueba los objetivos del spec. No se crean ficheros de plano por rango: el rango se aplica al forjar.

**Tech Stack:** Godot 4.5.1 (GDScript con tabuladores), Python 3 + Pillow para los iconos pixel, escenas de pruebas sin ventana sobre `scripts/tests/TestSuite.gd`.

**Spec:** `doc/specs/2026-09-27-rangos-de-plano-por-ciclo.md`

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
- Al morir, Tico vuelve a la sala 1. Vuelta rápida: si la sala está por debajo del récord y un golpe sin crítico de Tico mata al enemigo, Tico:
  - anda ×3;
  - ataca al llegar;
  - hace la pausa tras matar al 25 %;
  - no provoca hit-stop ni temblor.
- Guardado versión 2 con migración desde la 1: lo forjado pasa a rango I, lo desbloqueado se conserva y se aplican los hitos del récord.
- Textos de la franja solo con caracteres de `PixelFont`: A-Z, ÁÉÍÓÚÜÑ, 0-9, ! ¡ ? ¿ . , : ; - + / ( ) % ' · ×.
- Pruebas:
  - las suites extienden `res://scripts/tests/TestSuite.gd`, que protege `user://save.json`;
  - `VisualCapture` no lo protege: copia `%APPDATA%/Godot/app_userdata/PetJam/save.json` antes de grabar y restáuralo al acabar;
  - `<scratchpad>` en los comandos de captura es tu carpeta temporal de la sesión, fuera del repo.
- Un commit por tarea en la rama `franja-pixel-fase-1`, sin Co-Authored-By, añadiendo por ruta (nunca `git add -A`).

## Review Focus

- **Una partida de hoy con récord alto** (versión 1, récord 57, objetos equipados) debe cargar con todo en rango I, el equipo puesto y los hitos del récord aplicados (básicos de rango II). Prueba: `test_v1_save_with_high_record_migrates` (tarea 6).
- **Un hito desbloquea 4 planos a la vez:** la franja muestra un solo aviso y los 4 pergaminos salen escalonados, no apilados. Prueba: `test_milestone_shows_one_notice_and_staggers_scrolls` (tarea 7).
- **Encargo propio con la cola llena, sin materiales o de un rango bloqueado:** no cobra nada. Prueba: `test_own_order_never_charges_when_refused` (tarea 11).
- **Un pedido ya visible cuando se desbloquea un rango nuevo** conserva su rango, su receta y su oro. Prueba: `test_visible_request_keeps_its_rank` (tarea 8).
- **Vuelta rápida en la sala del récord o ante un enemigo que aguanta un golpe:** no se activa y hay hit-stop normal. Prueba: `test_rush_only_below_record_and_one_shot` (tarea 12).

---

## Mapa de ficheros

| Fichero | Acción | Responsabilidad |
|---|---|---|
| `scripts/core/EnemyScaling.gd` | crear | curva de enemigos y estadísticas de un enemigo |
| `scripts/core/CombatMath.gd` | crear | estadísticas de Tico, daño esperado y mitigación, sin nodos |
| `scripts/core/Ranks.gd` | crear | ciclos, hitos, multiplicadores, recetas y textos de hito |
| `scripts/core/TrialDifficulty.gd` | crear | dificultad de minijuego por rango, con topes |
| `scripts/gameplay/Hero.gd`, `Enemy.gd` | modificar | usar `CombatMath` / `EnemyScaling`; armadura relativa; primer ataque inmediato; botín por ciclo y de bioma |
| `scripts/gameplay/CombatController.gd` | modificar | nivel del atacante al dañar; sin hit-stop en vuelta rápida |
| `scripts/gameplay/Corridor.gd` | modificar | botín de bioma, avisos de hito y vuelta rápida |
| `scripts/data/CraftedItem.gd` | modificar | rango, estadísticas escaladas y numeral |
| `scripts/autoload/DataManager.gd` | modificar | rango máximo por plano, tiers y migración |
| `scripts/autoload/GameManager.gd` | modificar | hitos al vencer jefes y al cargar |
| `scripts/autoload/RequestsManager.gd` | modificar | rango, receta y oro por pedido |
| `scripts/autoload/CraftingManager.gd` | modificar | rango y encargo propio en las tareas; dificultad por rango |
| `scripts/core/SaveManager.gd` | modificar | versión 2 |
| `scripts/ForgeMinigame.gd`, `data/blueprints/boots_*.tres` | modificar | claves de dificultad que sí llegan |
| `scripts/RequestSlot.gd`, `scripts/ui/HUDMain.gd`, `scripts/ui/BlueprintLibraryPanel.gd`, `scripts/ui/BlueprintCard.gd`, `scripts/ui/EquipmentPanel.gd`, `scripts/ui/CraftResultScreen.gd`, `scripts/ui/HeroViewOverlay.gd`, `scripts/ui/ShopPanel.gd`, `scripts/MaterialIcon.gd` | modificar | numerales, encargo propio, avisos, venta por rango e iconos pixel |
| `data/materials/{bone,moss,obsidian,frost,void_shard}.tres` | crear | materiales de bioma |
| `tools/pixel_art/materials.py`, `tools/pixel_art/tests/test_materials.py`, `tools/pixel_art/export.py` | crear / modificar | iconos 12x12 de los materiales de bioma |
| `art/sprites/pixel/materials/*.png` | generados | iconos |
| `scripts/tests/RankTests.gd`, `scenes/tests/RankTests.tscn` | crear | pruebas de las tareas 1, 2 y 4 a 12 |
| `scripts/tests/BalanceSim.gd`, `scenes/tests/BalanceSim.tscn` | crear | simulación y objetivos de balance |
| `scripts/tests/fixtures/save_v1.json` | crear | partida de versión 1 para la migración |
| `scripts/tests/GameplayTests.gd` | modificar | las pruebas de materiales usan la receta con rango |
| `scripts/tests/VisualCapture.gd` | modificar | plan de capturas `ranks` |
| `locale/textos.csv` | modificar | filas de los textos nuevos |
| `doc/ARCHITECTURE.md`, `doc/ROADMAP.md`, `doc/specs/2026-09-27-rangos-de-plano-por-ciclo.md` | modificar | documentación y valores calibrados |

Comandos de la batería (todos desde la raíz del repo):

```bash
timeout 300 D:/Software/Godot/godot_ver4.5.exe --headless --path . res://scenes/tests/RankTests.tscn
timeout 300 D:/Software/Godot/godot_ver4.5.exe --headless --path . res://scenes/tests/BalanceSim.tscn
timeout 300 D:/Software/Godot/godot_ver4.5.exe --headless --path . res://scenes/tests/GameplayTests.tscn
timeout 300 D:/Software/Godot/godot_ver4.5.exe --headless --path . res://scenes/tests/PixelTests.tscn
python -m unittest discover tools/pixel_art/tests
```

Cada escena sale con 0 si todo pasa y con 1 si algo falla, e imprime `[Suite] N comprobaciones, M fallos`.

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

### Task 4: Materiales de bioma: datos, iconos y botín

**Files:**
- Create:
  - `tools/pixel_art/materials.py` y `tools/pixel_art/tests/test_materials.py`;
  - `data/materials/bone.tres`, `moss.tres`, `obsidian.tres`, `frost.tres` y `void_shard.tres`.
- Modify:
  - `tools/pixel_art/export.py`, `scripts/MaterialIcon.gd`;
  - `scripts/gameplay/Enemy.gd` (botín), `scripts/gameplay/Corridor.gd` (aviso del botín de bioma);
  - `scripts/tests/GameplayTests.gd`, `scripts/tests/RankTests.gd`, `locale/textos.csv`.
- Generated: `art/sprites/pixel/materials/{bone,moss,obsidian,frost,void_shard}.png`

**Interfaces:**
- Consumes: `Ranks.BIOME_MATERIALS`, `Ranks.biome_material_for_room`, `Ranks.mat_mult`, `Ranks.cycle_for_room`
- Produces:
  - `Enemy.BIOME_DROP_CHANCE` (0,3), `Enemy.BIOME_DROP_QTY` (3), `Enemy.BOSS_BIOME_QTY` (10);
  - `Enemy.biome_drop_chance: float`, que las pruebas pueden forzar;
  - `Enemy.last_biome_drop: Dictionary` (`{"item_id", "quantity"}` o `{}`);
  - `death_info["biome_material"]`.

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
	e.configure_for_level(40, true)  # jefe del Glaciar: siempre suelta el suyo aunque la probabilidad sea 0
	e.generate_drops()
	check(e.last_biome_drop.get("item_id") == &"frost" and int(e.last_biome_drop.get("quantity", 0)) == 10, "el jefe del Glaciar suelta 10 de escarcha (%s)" % [e.last_biome_drop])
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

Run: `timeout 300 D:/Software/Godot/godot_ver4.5.exe --headless --path . res://scenes/tests/RankTests.tscn`
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


## Material del bioma de la sala: con probabilidad biome_drop_chance, o siempre si es un jefe.
func _drop_biome_material() -> void:
	var chance := 1.0 if is_boss else biome_drop_chance
	if _rng.randf() >= chance:
		return
	var im := get_node_or_null("/root/InventoryManager")
	if im == null or not im.has_method("add_item"):
		return
	var mat_id := Ranks.biome_material_for_room(level)
	var qty := ceili((BOSS_BIOME_QTY if is_boss else BIOME_DROP_QTY) * Ranks.mat_mult(Ranks.cycle_for_room(level)) - 0.0001)
	im.add_item(mat_id, qty)
	last_biome_drop = {"item_id": mat_id, "quantity": qty}


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

Donde `_die()` rellena `death_info` (hoy `"material": last_material_drop.duplicate()`), añade:

```gdscript
		"biome_material": last_biome_drop.duplicate(),
```

- [ ] **Step 7: Aviso del botín de bioma en la franja**

El botín de siempre lo pinta `Corridor._on_enemy_died_fx()` y el doble de la Suerte, `CombatController._show_bonus_loot()`, con el mismo retraso. El de bioma lo pinta el `Corridor`, un poco después y más arriba, para que no se tapen. En `Corridor._on_enemy_died_fx()`, tras el bloque del material de siempre (`loot_pop` + `loot_dropped` + tintineo), añade:

```gdscript
	var bd: Dictionary = info.get("biome_material", {})
	if not bd.is_empty():
		var bmat := _material_info(StringName(bd.get("item_id", "")))
		var bdelay := (0.3 if was_boss else 0.12) + 0.18
		fx.loot_pop(pos + Vector2(8, -8), bmat.get("icon"), "+%d %s" % [int(bd.get("quantity", 0)), bmat.get("name", "")], Color(0.8, 0.95, 1.0), bdelay, FLOOR_Y)
		loot_dropped.emit(&"material", pos, {"id": bd.get("item_id", ""), "quantity": bd.get("quantity", 0)})
```

`_material_info()` ya lee el nombre y el icono de `data/materials/<id>.tres`. Si la tarjeta de idioma lo cambió para traducir el nombre, el material de bioma usa el mismo camino.

El orden de materiales de `HUDMinigameLauncher.gd` (que cita el spec, apartado 11) es de escenas sin uso (`HUD.tscn` y `HUD_Forge.tscn`, en la tarjeta de limpieza), así que no se toca. En la interfaz viva, los materiales se ven en las tarjetas de pedido (`MaterialIcon`) y en la tienda. La tienda no vende los de bioma.

- [ ] **Step 8: Ejecutar y ver que pasa**

Run: RankTests, GameplayTests y PixelTests.
Expected: 0 fallos en las tres.

- [ ] **Step 9: Commit**

```bash
git add tools/pixel_art/materials.py tools/pixel_art/tests/test_materials.py tools/pixel_art/export.py art/sprites/pixel/materials data/materials/bone.tres data/materials/moss.tres data/materials/obsidian.tres data/materials/frost.tres data/materials/void_shard.tres scripts/MaterialIcon.gd scripts/gameplay/Enemy.gd scripts/gameplay/Corridor.gd scripts/tests/RankTests.gd scripts/tests/GameplayTests.gd locale/textos.csv
git commit -m "feat: materiales de bioma (hueso, musgo, obsidiana, escarcha y vacío) y botín por ciclo"
```

---

### Task 5: Rango en el objeto forjado

**Files:**
- Modify: `scripts/data/CraftedItem.gd`
- Test: `scripts/tests/RankTests.gd`

**Interfaces:**
- Consumes: `Ranks.scale_stats`, `Ranks.suffix`
- Produces:
  - `CraftedItem.rank: int`
  - `CraftedItem.new(item_res: ItemResource, craft_quality: float, craft_rank: int = 1)`
  - `CraftedItem.get_name_with_rank() -> String`, ya traducido: "Espada maestra III"
  - `CraftedItem.get_display_name()`, que devuelve "Espada maestra III (93%)"
  - `to_dict()` con `"rank"` y `from_dict()`, que lo lee (1 si falta)

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
	var back := CraftedItem.from_dict(item.to_dict(), res)
	check(back.rank == 2 and back.calculated_stats == item.calculated_stats, "rango y estadísticas vuelven igual")
	var old := item.to_dict()
	old.erase("rank")
	check(CraftedItem.from_dict(old, res).rank == 1, "un objeto de la versión 1 (sin rango) es de rango I")
```

Run RankTests. Expected: error de análisis o fallos (`CraftedItem.new` con tres argumentos, `get_name_with_rank` no existe).

- [ ] **Step 2: Implementar en `CraftedItem.gd`**

Añade la variable junto a `quality`:

```gdscript
var rank: int = 1  # rango del plano con que se forjó (1 = rango I)
```

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

Nombres. Conserva la traducción que haya puesto la tarjeta de idioma. Si `get_display_name()` ya traduce `item_resource.display_name`, usa esa misma llamada en `get_name_with_rank()`:

```gdscript
## Nombre con el numeral del rango, ya traducido: "Espada maestra III" (sin numeral en el rango I).
func get_name_with_rank() -> String:
	if item_resource == null:
		return tr("Objeto desconocido")
	return tr(item_resource.display_name) + Ranks.suffix(rank)


## Retorna el nombre del item con rango y calidad: "Espada maestra III (93%)"
func get_display_name() -> String:
	if item_resource:
		return "%s (%d%%)" % [get_name_with_rank(), get_quality_percent()]
	return tr("Objeto desconocido")
```

(Si la tarjeta de idioma usó otro texto para "objeto desconocido", usa el suyo y no añadas fila nueva al CSV.)

Serialización:

```gdscript
func to_dict() -> Dictionary:
	return {
		"item_id": String(item_resource.item_id) if item_resource else "",
		"quality": quality,
		"rank": rank,
		"stats": calculated_stats.duplicate(),
		"timestamp": crafted_timestamp,
		"equipped": is_equipped
	}


static func from_dict(data: Dictionary, item_res: ItemResource) -> CraftedItem:
	var item = CraftedItem.new(item_res, data.get("quality", 0.5), int(data.get("rank", 1)))
	item.calculated_stats = data.get("stats", {}).duplicate()
	item.crafted_timestamp = data.get("timestamp", 0)
	item.is_equipped = data.get("equipped", false)
	return item
```

- [ ] **Step 3: Ejecutar y ver que pasa**

Run: RankTests, GameplayTests y PixelTests. Expected: 0 fallos.

- [ ] **Step 4: Commit**

```bash
git add scripts/data/CraftedItem.gd scripts/tests/RankTests.gd
git commit -m "feat: el objeto forjado guarda su rango y escala sus estadísticas"
```

---

### Task 6: Desbloqueo por rango y guardado versión 2

**Files:**
- Modify: `scripts/autoload/DataManager.gd`, `scripts/autoload/GameManager.gd` (solo `_on_data_ready_load_save`), `scripts/core/SaveManager.gd`
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
  - Guardado: `SaveManager.SAVE_VERSION`, que pasa a 2.
- Se quita `DataManager.DEFAULT_UNLOCKED`. `unlock_blueprint(id)` se conserva como `unlock_rank(id, 1)` por compatibilidad.

- [ ] **Step 1: Partida de versión 1 para la prueba**

`scripts/tests/fixtures/save_v1.json` (una partida de hoy: récord 57, espada maestra equipada, planos del sistema antiguo):

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

- [ ] **Step 2: Pruebas que fallan**

```gdscript
# ─── Tarea 6: desbloqueo por rango y guardado v2 ───────────────────────

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
	var newly: Array = dm.apply_milestones([{"rank": 2, "tier": Ranks.TIER_BASIC}])
	check(newly.size() == 3, "los otros 3 básicos suben a II (%s)" % [newly])
	dm.unlocked_ranks = saved


func test_v1_save_with_high_record_migrates() -> void:
	var dm := _dm()
	var gm := get_node("/root/GameManager")
	var inv := get_node("/root/InventoryManager")
	var fixture := FileAccess.get_file_as_string("res://scripts/tests/fixtures/save_v1.json")
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(fixture)
	f.close()
	check(SaveManager.load_game(), "la partida v1 carga")
	gm.apply_record_milestones()
	check(dm.get_unlocked_rank(&"sword_advanced") >= 1 and dm.get_unlocked_rank(&"sword_masterwork") >= 1, "lo ya desbloqueado se conserva")
	check(dm.get_unlocked_rank(&"helmet_basic") == 2, "el récord 57 aplica los básicos II (casco básico: %d)" % dm.get_unlocked_rank(&"helmet_basic"))
	check(dm.get_unlocked_rank(&"helmet_master") == 1, "el récord 57 aplica los maestros I")
	var items: Array = inv.get_crafted_items()
	check(items.size() == 1 and items[0].rank == 1 and items[0].calculated_stats.damage == 34, "la espada pasa a rango I con sus estadísticas")
	check(inv.get_equipped_item("main_hand") == items[0], "y sigue equipada")
	check(SaveManager.save_game(), "se guarda en la versión nueva")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	check(int(data.version) == 2 and data.data.has("unlocked_ranks"), "guardado versión 2 con unlocked_ranks")
	# TestSuite restaura el fichero al terminar; aquí se vuelve a cargar la partida previa para que las
	# pruebas siguientes no vean el estado de la de prueba
	if _had_save:
		var back := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		back.store_buffer(_save_backup)
		back.close()
		SaveManager.load_game()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	gm.apply_record_milestones()
```

Run RankTests. Expected: fallan (`blueprint_tier`, `unlocked_ranks` y `apply_record_milestones` no existen).

- [ ] **Step 3: `DataManager.gd` por rangos**

Sustituye `unlocked_blueprints` y `DEFAULT_UNLOCKED` y las funciones de desbloqueo. El estado inicial es todo a 0: los básicos I los da `GameManager.apply_record_milestones()` al cargar o al empezar.

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

Guardado, compatible con la versión 1:

```gdscript
func to_save_data() -> Dictionary:
	var ranks := {}
	for bp_id in unlocked_ranks:
		ranks[String(bp_id)] = unlocked_ranks[bp_id]
	return {"unlocked_ranks": ranks}


func load_save_data(data: Dictionary) -> void:
	if data.has("unlocked_ranks"):
		var saved: Dictionary = data.get("unlocked_ranks", {})
		for bp_id_str in saved:
			var bp_id := StringName(bp_id_str)
			if bp_id in unlocked_ranks:
				unlocked_ranks[bp_id] = maxi(0, int(saved[bp_id_str]))
	else:
		# Versión 1: planos desbloqueados como bool → rango I
		var old: Dictionary = data.get("unlocked_blueprints", {})
		for bp_id_str in old:
			var bp_id := StringName(bp_id_str)
			if bp_id in unlocked_ranks and bool(old[bp_id_str]):
				unlocked_ranks[bp_id] = 1
	print("DataManager: Loaded %d unlocked blueprints from save" % get_unlocked_blueprints().size())
```

- [ ] **Step 4: Hitos del récord al cargar (`GameManager.gd`)**

```gdscript
## Aplica en silencio los hitos que ya supera el récord (los básicos I siempre). Se llama al cargar la
## partida o al empezar una nueva, y tras migrar una partida de la versión 1.
func apply_record_milestones() -> Array:
	var dm = get_node_or_null("/root/DataManager")
	if dm == null or not dm.has_method("apply_milestones"):
		return []
	return dm.apply_milestones(Ranks.milestones_up_to_record(best_enemy_level))
```

En `_on_data_ready_load_save()`, al final (con o sin partida):

```gdscript
	apply_record_milestones()
```

`GameManager` está antes que `RequestsManager` en los autoloads y conecta `data_ready` en su `_ready`, así que los básicos ya están desbloqueados cuando `RequestsManager` genera los primeros pedidos. Compruébalo en el Step 6.

- [ ] **Step 5: `SaveManager.gd` versión 2**

```gdscript
const SAVE_VERSION := 2
```

En `load_game()`, sustituye el aviso de versión por:

```gdscript
	var version: int = int(save_data.get("version", 0))
	if version < SAVE_VERSION:
		print("SaveManager: partida de la versión %d; se migra a la %d al cargar" % [version, SAVE_VERSION])
	elif version > SAVE_VERSION:
		push_warning("SaveManager: partida de una versión más nueva (%d > %d). Se intenta cargar igualmente." % [version, SAVE_VERSION])
```

(Si la tarjeta de guardado robusto ya cambió `SaveManager`, aplica estos cambios sobre su versión.)

- [ ] **Step 6: Ejecutar y ver que pasa, y arranque real**

Run: RankTests, GameplayTests y PixelTests. Expected: 0 fallos.

Run: `timeout 120 D:/Software/Godot/godot_ver4.5.exe --headless --path . --quit-after 600 res://scenes/Main.tscn 2>&1 | grep -iE "SCRIPT ERROR|Parse Error|DataManager: Loaded|RequestsManager: Generados"`
Expected: sin errores. Hay pedidos generados de planos desbloqueados. Restaura `save.json` después (Global Constraints).

- [ ] **Step 7: Commit**

```bash
git add scripts/autoload/DataManager.gd scripts/autoload/GameManager.gd scripts/core/SaveManager.gd scripts/tests/RankTests.gd scripts/tests/fixtures/save_v1.json
git commit -m "feat: desbloqueo por rango, hitos del récord y guardado versión 2 con migración"
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

- [ ] **Step 1: Pruebas que fallan**

```gdscript
# ─── Tarea 7: hitos al vencer jefes ────────────────────────────────────

func test_boss_milestones_unlock_once_with_signals() -> void:
	var gm := get_node("/root/GameManager")
	var dm := _dm()
	var saved_ranks: Dictionary = dm.unlocked_ranks.duplicate()
	var saved_state: int = gm.dungeon_state
	for id in dm.unlocked_ranks:
		dm.unlocked_ranks[id] = 0
	dm.apply_milestones([{"rank": 1, "tier": Ranks.TIER_BASIC}])
	gm.dungeon_state = gm.DungeonState.RUNNING
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
	dm.unlocked_ranks = saved_ranks


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

En `register_enemy_defeat(level)`, sustituye el bloque que desbloqueaba un plano al azar (`get_locked_blueprints()` … `emit_signal("blueprint_unlocked", …)`) por:

```gdscript
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
```

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

En `bind_corridor()` (o en `_ready()`, donde el overlay coge `_game_manager`), conecta:

```gdscript
	if _game_manager and _game_manager.has_signal("blueprints_milestone"):
		_game_manager.blueprints_milestone.connect(_on_blueprints_milestone)
```

```gdscript
## Hito de rangos (spec de rangos, apartado 3): cartel con el grupo desbloqueado. Llega al vencer a un
## jefe, antes que su aviso "X ha caído", que es un toast y espera en cola mientras dure el cartel.
func _on_blueprints_milestone(rank: int, tier: StringName, _ids: Array) -> void:
	show_banner(Ranks.milestone_text(rank, tier), tr("Nuevos planos en la biblioteca"), Color("ffe08a"), 1.6)
```

`show_banner` sustituye al cartel en curso (no encola). En la muerte de un jefe hoy no hay otro cartel, solo el toast del jefe y el texto "¡JEFE DERROTADO!" de la franja, así que el del hito puede salir enseguida.

Fila en `locale/textos.csv`:

```
"Nuevos planos en la biblioteca","Nuevos planos en la biblioteca","New blueprints in the library"
```

- [ ] **Step 5: Plan de captura `unlock` con hitos**

`VisualCapture._run_unlock_plan()` bloqueaba planos con `dm.unlocked_blueprints`, que ya no existe. Pasa a preparar el hito de los avanzados I y dejar que Tico venza al jefe de la sala 20:

```gdscript
func _run_unlock_plan() -> void:
	# Hito de rangos: bloquea los avanzados y lleva a Tico (invencible) al jefe de la sala 20
	await get_tree().create_timer(1.0).timeout
	var dm := get_node_or_null("/root/DataManager")
	var gm := get_node_or_null("/root/GameManager")
	if dm == null or gm == null:
		return
	for id in dm.get_blueprint_ids_for_tier(Ranks.TIER_ADVANCED):
		dm.unlocked_ranks[id] = 0
	var hero: Node = gm.get_hero()
	if hero:
		hero.set_invincible(true)
	gm.current_enemy_level = 19
	gm.advance_enemy_level()
```

Actualiza también su línea en la cabecera de planes del fichero.

Graba el plan `unlock`, con `save.json` copiado antes y restaurado después:

`timeout 300 D:/Software/Godot/godot_ver4.5.exe --path . --write-movie <scratchpad>/t7/f.png --fixed-fps 10 --quit-after 150 res://scenes/tests/VisualCapture.tscn -- --plan=unlock`

Abre con Read los fotogramas de la muerte del jefe y comprueba:
- un solo cartel "¡Planos avanzados!";
- 4 pergaminos que salen escalonados hacia el botón de Planos.

- [ ] **Step 6: Ejecutar y ver que pasa**

Run: RankTests, GameplayTests y PixelTests. Expected: 0 fallos.

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
  - interfaz: `scripts/RequestSlot.gd`, `scripts/ui/HUDMain.gd` (clave de tarjeta), `scripts/ui/ShopPanel.gd` (venta), `scripts/ui/CraftResultScreen.gd` (nombre).
- Test: `scripts/tests/RankTests.gd`

**Interfaces:**
- Consumes: `Ranks.recipe`, `Ranks.gold_mult`, `Ranks.suffix`, `DataManager.get_unlocked_rank`, `DataManager.blueprint_tier`, `CraftedItem.new(res, q, rank)`
- Produces:
  - `RequestsManager.PREVIOUS_RANK_CHANCE` (0,2) y `RequestsManager.rng: RandomNumberGenerator`, que las pruebas pueden sembrar.
  - `RequestsManager.make_request(bp_id: StringName) -> Dictionary`, con claves `blueprint_id, blueprint, rank, materials, gold_reward, client_name`.
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
	check(cm.enqueue(&"helmet_basic", 100, 3), "se encola el casco básico III")
	var task = null
	for t in cm.queue:
		if t != null and t.blueprint.blueprint_id == &"helmet_basic" and t.rank == 3:
			task = t
	check(task != null, "la tarea guarda el rango")
	if task:
		var result: Dictionary = cm._finalize_task(task)
		check(result.rank == 3 and result.crafted_item.rank == 3, "el objeto sale de rango III")
		check(result.gold_reward > 0 and not result.own_order, "un pedido sí da oro")
		inv.remove_crafted_item(result.crafted_item)
	check(inv.get_crafted_items().size() == items_before, "la prueba deja el inventario como estaba")
```

Run RankTests. Expected: fallan (`rng`, `make_request` y `enqueue` con rango no existen).

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
		"client_name": _generate_client_name(),
	}


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

En `_finalize_task`:
- `crafted_item = CraftedItem.new(item_res, quality_normalized, task.rank)`;
- el oro final:

```gdscript
	var final_gold := 0
	if not task.own_order:
		final_gold = int(task.gold_reward * gold_multiplier) if task.gold_reward > 0 else int(50 * gold_multiplier)
```

- en el diccionario `result`, añade `"rank": task.rank` y `"own_order": task.own_order`;
- en `get_queue_snapshot()` y `_emit_task_update()`, añade `"rank": task.rank`.

- [ ] **Step 4: Interfaz**

`RequestSlot.set_request(request)`: nombre con numeral y receta del pedido.

```gdscript
## Configura la tarjeta con el diccionario del pedido (blueprint, rank, materials, gold_reward, client_name).
func set_request(request: Dictionary) -> void:
	var blueprint: BlueprintResource = request.get("blueprint")
	set_blueprint(blueprint)
	var rank := int(request.get("rank", 1))
	if blueprint:
		set_blueprint_name(tr(blueprint.display_name) + Ranks.suffix(rank))
	# La receta del rango del pedido (materiales de bioma incluidos), no la del .tres
	set_materials(request.get("materials", blueprint.materials if blueprint else {}))
	var reward := int(request.get("gold_reward", 0))
	reward_label.text = str(reward) if reward > 0 else "—"
	var client := String(request.get("client_name", ""))
	client_label.text = client
	client_label.visible = client != ""
	var rm := get_node_or_null("/root/RequestsManager")
	var free: bool = rm != null and rm.has_method("get_free_requests_remaining") and rm.get_free_requests_remaining() > 0
	free_tag.visible = free
	_refresh_material_colors()
```

Si la tarjeta de idioma cambió cómo se escribe el cliente o el texto de "GRATIS", conserva sus líneas y cambia solo el nombre y los materiales.

`HUDMain._on_requests_refreshed`: la clave de la tarjeta incluye el rango, para que una tarjeta nueva de otro rango se anime:

```gdscript
		var key := "%s|%s|%s|%s" % [request.get("blueprint_id", ""), request.get("rank", 1), request.get("client_name", ""), request.get("gold_reward", 0)]
```

`ShopPanel._get_sell_price(item)`: el precio de venta crece con el rango del objeto.

```gdscript
func _get_sell_price(item: CraftedItem) -> int:
	var tier := item.get_quality_tier()
	return roundi(SELL_PRICE_BY_TIER.get(tier, 25) * Ranks.gold_mult(item.rank))
```

`CraftResultScreen`: donde se decide `item_name` desde el plano, usa el objeto si existe:

```gdscript
	if crafted_item is CraftedItem:
		item_name = crafted_item.get_name_with_rank()
```

(antes del bloque que lo lee de `bp.display_name`, que queda de respaldo).

- [ ] **Step 5: Ejecutar y ver que pasa**

Run: RankTests, GameplayTests y PixelTests. Expected: 0 fallos.

Captura: `timeout 300 D:/Software/Godot/godot_ver4.5.exe --path . --write-movie <scratchpad>/t8/f.png --fixed-fps 10 --quit-after 120 res://scenes/tests/VisualCapture.tscn -- --plan=main`. Copia antes `save.json` y restáuralo después. Abre 2 o 3 fotogramas con Read: las tarjetas de pedido muestran los materiales de la receta, con el de bioma incluido.

- [ ] **Step 6: Commit**

```bash
git add scripts/autoload/RequestsManager.gd scripts/autoload/CraftingManager.gd scripts/RequestSlot.gd scripts/ui/HUDMain.gd scripts/ui/ShopPanel.gd scripts/ui/CraftResultScreen.gd scripts/tests/RankTests.gd
git commit -m "feat: pedidos, crafteo, oro y venta por rango"
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

Run: RankTests, GameplayTests y PixelTests. Expected: 0 fallos.

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

Run: RankTests, GameplayTests y PixelTests. Expected: 0 fallos.

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
  - `scripts/ui/HUDMain.gd` (lanzar la tarea) y `scripts/ui/EquipmentPanel.gd` (numeral);
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
	name_label.text = (tr(blueprint_data.display_name) if blueprint_data else str(blueprint_id)) + Ranks.suffix(selected_rank)


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

- [ ] **Step 5: Numeral en el panel de Equipo**

En `EquipmentPanel.gd`, donde la tarjeta de la mochila pone `name_label.text = item.item_resource.display_name …`:

```gdscript
	name_label.text = item.get_name_with_rank() if item.item_resource else "???"
```

(`tooltip_text = equipped_item.get_display_name()` ya lleva el numeral por la tarea 5.)

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

Run: RankTests, GameplayTests y PixelTests. Expected: 0 fallos.

Captura el plan `panels` de VisualCapture (copia y restaura `save.json`) y abre los fotogramas de la biblioteca con Read. Las tarjetas muestran el selector y el botón sin salirse, y el nombre lleva el numeral desde el II.

- [ ] **Step 8: Commit**

```bash
git add scripts/autoload/CraftingManager.gd scripts/ui/BlueprintCard.gd scenes/UI/BlueprintCard.tscn scripts/ui/BlueprintLibraryPanel.gd scripts/ui/HUDMain.gd scripts/ui/EquipmentPanel.gd scripts/tests/RankTests.gd locale/textos.csv
git commit -m "feat: encargo propio desde la biblioteca y numeral de rango en la interfaz"
```

---

### Task 12: Vuelta rápida

**Files:**
- Modify: `scripts/gameplay/Corridor.gd`, `scripts/gameplay/Hero.gd` (`prepare_for_combat`), `scripts/gameplay/CombatController.gd` (`start_combat`, hit-stop y temblor)
- Test: `scripts/tests/RankTests.gd`

**Interfaces:**
- Consumes: `GameManager.best_enemy_level`, `Hero.dmg`, `Enemy.max_hp`
- Produces:
  - Constantes: `Corridor.RUSH_SPEED_MULT` (3,0) y `Corridor.RUSH_PAUSE_MULT` (0,25).
  - Consultas del pasillo: `Corridor.is_rushing() -> bool` y `Corridor.rush_for(room: int) -> bool`.
  - Primer ataque inmediato: `Hero.prepare_for_combat(instant_first_attack: bool = false)` y `CombatController.start_combat(instant_first_attack: bool = false)`.

**Orden de los eventos al matar** (comentario de `Corridor._ready`):
1. `CombatController._on_enemy_died` hace avanzar la sala.
2. `Corridor._on_enemy_level_changed` coloca al enemigo siguiente.
3. Después llega `Corridor._on_enemy_died_fx`.

Por eso el estado de la sala recién vencida se guarda en `_rush_kill` antes de calcular el de la siguiente.

- [ ] **Step 1: Pruebas que fallan**

```gdscript
# ─── Tarea 12: vuelta rápida ───────────────────────────────────────────

func test_rush_only_below_record_and_one_shot() -> void:
	var gm := get_node("/root/GameManager")
	var saved_best: int = gm.best_enemy_level
	gm.best_enemy_level = 30
	var corridor: Node2D = load("res://scenes/Corridor.tscn").instantiate()
	add_child(corridor)
	await get_tree().process_frame
	var hero: Node2D = corridor.get_node("Hero")
	hero.dmg = 1.0e9
	corridor.spawn_enemy(5, hero.position.x + 160.0)
	check(corridor.is_rushing(), "sala 5 con récord 30 y un golpe basta: a la carrera")
	corridor._pause = 0.0  # el pasillo arranca con una pausa en la que Tico no anda
	corridor.update_run(0.1)
	check(is_equal_approx(hero.walk_speed, corridor.HERO_SPEED * corridor.RUSH_SPEED_MULT), "anda ×3 (%.1f)" % hero.walk_speed)
	corridor.spawn_enemy(30, hero.position.x + 160.0)
	check(not corridor.is_rushing(), "en la sala del récord, no")
	hero.dmg = 1.0
	corridor.spawn_enemy(5, hero.position.x + 160.0)
	check(not corridor.is_rushing(), "si un golpe no basta, no")
	corridor._pause = 0.0
	corridor.update_run(0.1)
	check(is_equal_approx(hero.walk_speed, corridor.HERO_SPEED), "anda normal (%.1f)" % hero.walk_speed)
	corridor.queue_free()
	await get_tree().process_frame
	gm.best_enemy_level = saved_best


func test_rush_kill_skips_hitstop_and_first_attack_is_instant() -> void:
	var hero := _new_hero()
	await get_tree().process_frame
	hero.prepare_for_combat(true)
	check(hero.atk_timer <= 0.0, "a la carrera, el primer golpe sale al llegar")
	hero.prepare_for_combat()
	check(hero.atk_timer > 0.0, "normalmente, espera su ritmo")
	hero.queue_free()
	var corridor: Node2D = load("res://scenes/Corridor.tscn").instantiate()
	add_child(corridor)
	await get_tree().process_frame
	corridor._rush_kill = true
	corridor.enemy.death_info = {"pos": Vector2(100, 80), "boss": false, "level": 3, "name": "Limo"}
	corridor._on_enemy_died_fx([])
	check(corridor._hitstop <= 0.0, "una muerte a la carrera no congela el pasillo")
	corridor.queue_free()
	await get_tree().process_frame
```

Run RankTests. Expected: fallan (`is_rushing` no existe; `prepare_for_combat` no acepta argumentos).

- [ ] **Step 2: `Hero.prepare_for_combat`**

```gdscript
## `instant_first_attack`: en la vuelta rápida el primer golpe sale nada más llegar.
func prepare_for_combat(instant_first_attack: bool = false) -> void:
	atk_timer = 0.0 if instant_first_attack else 1.0 / aps
	pulse_timer = PULSE_INTERVAL
	is_attacking = false
```

- [ ] **Step 3: `CombatController`**

```gdscript
func start_combat(instant_first_attack: bool = false):
	if combat_active:
		return
	combat_active = true
	if hero and hero.has_method("prepare_for_combat"):
		hero.prepare_for_combat(instant_first_attack)
	if enemy and enemy.has_method("prepare_for_combat"):
		enemy.prepare_for_combat()
	emit_signal("combat_started")
```

En la vuelta rápida, los golpes de Tico no hacen temblar ni congelan el pasillo. El enemigo no llega a atacar, porque muere del primer golpe. Añade:

```gdscript
## Vuelta rápida en curso (Corridor.is_rushing): sin temblor ni hit-stop en los golpes de Tico.
func _rushing() -> bool:
	return corridor != null and corridor.has_method("is_rushing") and corridor.is_rushing()
```

En `_execute_hero_attack()`, sustituye el bloque de feedback tras `fx.damage_number(…)` (desde `if crit:` hasta el `camera.add_trauma(0.07)` del final) por:

```gdscript
	var rushing := _rushing()
	if crit:
		if fx:
			fx.ring(hit_pos, COLOR_CRIT, 2.0, 13.0, 0.24, 1.0)
		if _crit_fx_cd <= 0.0:
			_crit_fx_cd = CRIT_FX_COOLDOWN
			if camera and not rushing:
				camera.add_trauma(0.3)
			if corridor.has_method("hitstop") and not rushing:
				corridor.hitstop(0.06)
			_play(CRIT_SFX, -11.0, 1.2, 0.05)
		elif camera and not rushing:
			camera.add_trauma(0.1)
	elif camera and not rushing:
		camera.add_trauma(0.07)
```

(La línea `_play_random(HIT_SFX, …)` que sigue no cambia.)

- [ ] **Step 4: `Corridor`**

Constantes y estado:

```gdscript
const RUSH_SPEED_MULT := 3.0  # vuelta rápida: anda ×3
const RUSH_PAUSE_MULT := 0.25  # y apenas se detiene tras matar
var _rush := false  # la sala actual se cruza a la carrera
var _rush_kill := false  # la sala que se acaba de vencer iba a la carrera (sin hit-stop ni temblor)


## Vuelta rápida (spec de rangos, apartado 7): la sala está por debajo del récord y un golpe sin crítico
## de Tico mata a su enemigo.
func rush_for(room: int) -> bool:
	if _game_manager == null or not ("best_enemy_level" in _game_manager) or not hero.alive:
		return false
	return room < int(_game_manager.best_enemy_level) and hero.dmg >= float(enemy.max_hp)


func is_rushing() -> bool:
	return _rush
```

En `spawn_enemy`, tras configurar al enemigo:

```gdscript
	_rush = rush_for(lv)
```

En `update_run`, la velocidad:

```gdscript
	if hero.alive:
		var speed := HERO_SPEED * (RUSH_SPEED_MULT if _rush else 1.0)
		hero.position.x += speed * delta
		hero.walking = true
		hero.walk_speed = speed
		ground_offset += speed * delta
```

En `_begin_fight`: `combat_controller.start_combat(_rush)`.

En `_on_enemy_level_changed`, antes de `spawn_enemy`, guarda si la sala vencida iba a la carrera, y usa la pausa corta:

```gdscript
	level = new_level
	if state == State.RUN or state == State.FIGHT:
		_rush_kill = _rush
		spawn_enemy(level, hero.position.x + SPAWN_AHEAD)
		state = State.RUN
		_pause = POST_KILL_PAUSE * (RUSH_PAUSE_MULT if _rush_kill else 1.0)
```

En `_on_enemy_died_fx`, el temblor y el hit-stop solo si no iba a la carrera:

```gdscript
	if not _rush_kill:
		camera.add_trauma(0.8 if was_boss else 0.32)
		camera.punch(0.06 if was_boss else 0.025)
		hitstop(0.22 if was_boss else 0.08)
```

En `reset_combat`: `_rush_kill = false` (al reaparecer, la primera sala se decide en `spawn_enemy`).

- [ ] **Step 5: Ejecutar y ver que pasa**

Run: RankTests, GameplayTests y PixelTests. Expected: 0 fallos.

- [ ] **Step 6: Commit**

```bash
git add scripts/gameplay/Corridor.gd scripts/gameplay/Hero.gd scripts/gameplay/CombatController.gd scripts/tests/RankTests.gd
git commit -m "feat: vuelta rápida por debajo del récord (anda ×3, ataca al llegar y sin hit-stop)"
```

---

### Task 13: Capturas, verificación y documentación

**Files:**
- Modify: `scripts/tests/VisualCapture.gd` (plan `ranks`), `doc/ARCHITECTURE.md`, `doc/ROADMAP.md`, `doc/specs/2026-09-27-rangos-de-plano-por-ciclo.md` (estado)

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
	gm.current_enemy_level = 44
	gm.advance_enemy_level()  # sala 45, Santuario del Vacío
	await get_tree().create_timer(2.0).timeout
	gm.blueprints_milestone.emit(2, Ranks.TIER_ADVANCED, [])
```

Graba (copia antes `save.json` y restáuralo después):

`timeout 300 D:/Software/Godot/godot_ver4.5.exe --path . --write-movie <scratchpad>/ranks/f.png --fixed-fps 10 --quit-after 120 res://scenes/tests/VisualCapture.tscn -- --plan=ranks`

Abre con Read los fotogramas de 1 s, 4 s, 7 s y 9 s y comprueba:
- las tarjetas de pedido llevan numeral y los materiales de bioma, con sus iconos pixel nítidos;
- la biblioteca muestra el selector y el botón «Forjar» sin salirse de la tarjeta;
- en la franja salen el botín con el material de bioma y el cartel "¡Planos avanzados II!".

Repite con 720x1280 (`--resolution 720x1280`) para ver la franja a escala no entera.

- [ ] **Step 2: Batería completa**

Run: los cinco comandos de la cabecera.
Expected: todo en verde.

Run: `timeout 120 D:/Software/Godot/godot_ver4.5.exe --headless --path . --quit-after 600 res://scenes/Main.tscn 2>&1 | grep -iE "SCRIPT ERROR|Parse Error|ERROR:"`
Expected: sin resultados. Restaura `save.json`.

- [ ] **Step 3: Documentación**

- `doc/ARCHITECTURE.md`: apartado "Rangos por ciclo" con las clases nuevas (`Ranks`, `EnemyScaling`, `CombatMath`, `TrialDifficulty`), el flujo del rango (hito → `DataManager` → pedido → tarea → objeto) y el guardado versión 2.
- `doc/ROADMAP.md`:
  - en la fase 3, los rangos por ciclo sustituyen a "Más blueprints" y a la dificultad automática;
  - la decisión de publicación (gratis primero, sin anuncios al principio, medir la retención).
- Spec: `**Estado:** implementado (pendiente de revisión humana)`.

- [ ] **Step 4: Commit**

```bash
git add scripts/tests/VisualCapture.gd doc/ARCHITECTURE.md doc/ROADMAP.md doc/specs/2026-09-27-rangos-de-plano-por-ciclo.md
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
| 6. Balance (objetivos, curva, simulación, armadura) | 1, 3 |
| 7. Muerte y vuelta rápida | 12 |
| 8. Datos y guardado versión 2 | 5, 6, 8 |
| 9. Textos e idioma | 2, 4, 7, 11 |
| 10. Pruebas | todas; capturas en 8, 11 y 13 |
| 11. Qué cambia en el código | mapa de ficheros |
| 12. Fases | tareas 1-3 (fase 1), 5-6 (fase 2), 7-8 (fase 3), 4 (fase 4), 9-10 (fase 5), 11 (fase 6), 12 (fase 7), 13 (fase 8) |
