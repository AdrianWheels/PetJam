# PetJam — Arquitectura Técnica

> Documento de referencia sobre la arquitectura del proyecto.  
> **Última actualización**: 2026-10-02

---

## 1. Visión general

PetJam es un juego idle/casual 2D para Android construido en **Godot 4.5.1** con **GDScript**. Resolución portrait **1080x1920** (9:16).

Toda la experiencia ocurre en **una sola pantalla** dividida en 3 zonas: el héroe luchando (arriba), los minijuegos de crafteo (centro) y los controles/requests (abajo).

---

## 2. Flujo de escenas

```
StartScreen.tscn ──(botón Play)──→ Main.tscn
                                       │
                                       ├─ HUDLayer (CanvasLayer)
                                       │    └─ HUD_Main.tscn
                                       │         ├─ HeroViewPanel: panel superior, el héroe (25 % de la pantalla)
                                       │         │    ├─ Corridor.tscn (instancia persistente; sus nodos, en 4.1)
                                       │         │    └─ HeroOverlay (HeroViewOverlay.gd: el HUD de la franja)
                                       │         ├─ MinigamePanel: panel central (50 %), minijuegos dinámicos
                                       │         ├─ ForgeMagiaMeter
                                       │         ├─ BottomLeftPanel: pedidos
                                       │         ├─ BottomRightPanel: botones Planos, Equipo y Tienda
                                       │         ├─ BlueprintLibraryPanel (popup)
                                       │         ├─ EquipmentPanel (popup a pantalla completa: rejilla de Tico, botín y mochila; ver 4.3)
                                       │         └─ ShopPanel (popup)
                                       │
                                       └─ FadeLayer (CanvasLayer)
```

`HUD_Forge.tscn` y `scenes/ForgeUI/` (DeliveryPanel, ItemInfoPanel y ResultPanel) son del diseño anterior a `HUD_Main`: nada los instancia.

---

## 3. AutoLoads (Singletons)

9 autoloads registrados en `project.godot`. **No añadir nuevos.**

### 3.1 Tabla de autoloads

| # | Nombre | Script | Descripción |
|---|--------|--------|-------------|
| 1 | `GameManager` | `scripts/autoload/GameManager.gd` | Estado global del juego |
| 2 | `DataManager` | `scripts/autoload/DataManager.gd` | Catálogo de datos estáticos |
| 3 | `InventoryManager` | `scripts/autoload/InventoryManager.gd` | Inventario del jugador |
| 4 | `CraftingManager` | `scripts/autoload/CraftingManager.gd` | Sistema de crafteo |
| 5 | `DebugManager` | `scripts/autoload/DebugManager.gd` | Herramientas de debug |
| 6 | `AudioManager` | `scripts/autoload/AudioManager.gd` | Audio |
| 7 | `TelemetryManager` | `scripts/autoload/TelemetryManager.gd` | Métricas |
| 8 | `UIManager` | `scripts/autoload/UIManager.gd` | Gestión de UI |
| 9 | `RequestManager` | `scripts/autoload/RequestsManager.gd` | Pedidos |

### 3.2 Detalle por autoload

#### GameManager
- **Señales**: `enemy_spawned`, `hero_died`, `hero_respawned`, `boss_defeated`, `dungeon_state_changed`, `hero_loadout_changed`, `enemy_defeated_first_time`, `enemy_level_changed`, `grid_expanded` (la rejilla de Tico crece), `potion_drunk` (una poción de los huecos se bebe sola)
- **Enum**: `DungeonState { IDLE, RUNNING, HERO_DEAD, COMPLETED, FAILED }`
- **API clave**: `start_run()`, `advance_enemy_level()`, `register_enemy_defeat(level)`, `register_hero_death()`, `request_respawn()`, `deliver_item_to_hero(item_id, slot)`, `register_hero(node)`, `drink_potion(id)`, `on_boss_appeared()`
- **Dependencias**: `DataManager` (para unlock de blueprints), `InventoryManager` (estadísticas de Tico, ampliación de la rejilla y pociones)
- **Guardado**: los cambios de piezas, de equipo y de sala y las caídas de Tico piden un guardado en diferido (`_on_trigger_save()`); los que se piden en un mismo fotograma son una sola escritura (`_save_pending`). `save_writer` cambia quién escribe: las pruebas ponen un contador.
- **Nota**: `MAX_DEATHS` y `DungeonState.FAILED/COMPLETED` son legacy del diseño de jam. En endless mode no hay game over.

#### DataManager
- **Señales**: `data_ready`
- **API clave**: `get_blueprint(id)`, `get_blueprints()`, `is_blueprint_unlocked(id)`, `unlock_blueprint(id)`, `get_unlocked_blueprints()`, `get_item_resource(item_id)`
- **Dependencias**: Ninguna. Carga `BlueprintLibrary.tres` en `_ready()`.
- **Blueprints iniciales desbloqueados**: `sword_basic`, `shield_basic`, `boots_basic`

#### InventoryManager
- **Señales**: `inventory_changed`, `crafted_items_changed`, `equipment_changed` (cambia la rejilla de Tico), `loot_changed`, `grid_resized`, `consumables_changed`
- **Estado**: `inventory: Dictionary` (materiales), `crafted_items: Array[CraftedItem]` (todas las piezas), `hero_grid` y `bag_grid` (`GearGrid`), `loot: Array[CraftedItem]`, `expansions` y `consumables` (2 huecos de pociones). Ver 4.3
- **API clave**: `add_item(id, qty)`, `has_materials(req)`, `consume_materials(req)`, `add_crafted_item(item)` (la pieza va al botín), `move_item(item, place, cell, rot)`, `rotate_in_place(item)`, `sell_item(item)`, `sell_all_loot()`, `calculate_total_stats()`, `simulate_hero_grid(item, place, cell, rot)` (la rejilla de Tico como quedaría, para la vista previa del arrastre), `preview_stats(item, place, cell, rot)` (envoltorio fino: `GearAuras.totals()` de esa simulación; el panel hace lo mismo por su cuenta), `apply_grid_expansion(id)`, `add_potion(id)`, `take_potion(id)`, `clear()`
- **Dependencias**: `DataManager` (resuelve las piezas al cargar el guardado) y las clases de reglas de `scripts/core/` (ver 4.3).
- **Nota**: Guarda y carga su parte de la partida (`to_save_data()` / `load_save_data()`, versión 3). `equip_item`/`unequip_item` y los huecos fijos de equipo ya no existen: lo que cuenta para Tico es lo que hay en su rejilla. Materiales iniciales generosos si no hay partida guardada.

#### CraftingManager
- **Señales**: `craft_enqueued`, `task_started`, `task_updated`, `task_completed`
- **Constantes**: `MAX_SLOTS = 5`, Grados: gold (90%), silver (70%), bronze (40%)
- **API clave**: `enqueue(recipe_id)`, `start_task(slot_idx)`, `cancel(slot_idx)`, `report_trial_result(task_id, result)`, `get_queue_snapshot()`, `has_active_trial()`
- **Dependencias**: `DataManager`, `InventoryManager`
- **Nota**: al terminar una pieza sortea sus aristas según su calidad (`PieceShape.roll_aristas`) y la manda al botín (`InventoryManager.add_crafted_item`); nada se coloca solo.

#### RequestManager (RequestsManager)
- **Señales**: `requests_refreshed`, `request_accepted`, `request_rejected_no_materials`
- **Constantes**: `MAX_ACTIVE = 4`, `MIN_ACTIVE = 2`, delay entre 3-8s, 2 requests gratis al inicio
- **API clave**: `accept_request(index)`, `refresh_all_requests()`, `get_active_requests()`
- **Dependencias**: `DataManager`, `InventoryManager`, `CraftingManager`
- **Flujo**: Genera requests de blueprints desbloqueados → timer para llenar pool → jugador acepta → consume materiales → encola en CraftingManager

#### UIManager
- **Señales**: `area_changed` (legacy), `delivery_opened`, `delivery_closed`
- **API clave**: `register_nodes(config)`, `present_delivery(result)`, `deliver_item_to_hero(item_id, slot)`
- **Dependencias**: `GameManager`, `CraftingManager`, `InventoryManager`, `DataManager`
- **Nota**: `show_forge()`/`show_dungeon()` y area switching son **legacy deprecado**.

#### AudioManager
- **Enum**: `AudioContext { GLOBAL, FORGE, DUNGEON }` (simplificar a GLOBAL)
- **API clave**: `play_sfx(stream, vol, ctx)`, `play_sfx_pitched(stream, vol, pitch, variance)`, `play_music(stream, loop, vol, ctx)`, `stop_music(ctx)`, `duck_music(db, time)`
- **Voces**: pool de 10 `AudioStreamPlayer` en el bus `SFX` (los sonidos ya no se cortan entre sí). `default_bus_layout.tres` añade un limitador en Master.
- **SFX generados**: `scripts/core/Sfx.gd` → `Sfx.play(&"enemy_shatter")`. Catálogo de diseño en `doc/sfx/petjam_sfx_events.json`.
- **Dependencias**: Ninguna

### 3.3 Diagrama de dependencias

```
                    ┌──────────────┐
                    │  DataManager │ (data_ready)
                    └──────┬───────┘
                           │
              ┌────────────┼────────────┐
              ▼            ▼            ▼
     ┌────────────┐ ┌─────────────┐ ┌──────────────┐
     │ GameManager│ │RequestMgr   │ │CraftingMgr   │
     │(unlock bp) │ │(gen requests)│ │(resolve bp)  │
     └─────┬──────┘ └──────┬──────┘ └──────┬───────┘
           │               │               │
           │               ▼               ▼
           │        ┌─────────────┐ ┌─────────────┐
           │        │InventoryMgr │ │InventoryMgr │
           │        │(materials)  │ │(crafted item)│
           │        └─────────────┘ └─────────────┘
           ▼
     ┌──────────┐
     │ UIManager│ ← escucha señales de todos
     └──────────┘
```

---

## 4. Sistemas principales

### 4.1 Sistema de combate (Dungeon)

```
Corridor (state machine: RUN → FIGHT → DEAD → RUN)        [SubViewport 1080x480 de HUD_Main]
   │
   ├─ Backdrop (DungeonBackdrop): Parallax2D por capas + biomas cada 10 salas + viñeta/destellos
   ├─ GateA / GateB (RoomGate): arco con el número de la sala; cruzarlo = entrar en la sala
   ├─ Camera2D (CorridorCamera): héroe al 30 % del ancho, shake por trauma, punch de zoom
   ├─ Hero: pentágono con cara y EQUIPO VISIBLE (la mejor pieza de cada tipo de su rejilla: arma, escudo, casco y botas)
   ├─ Enemy: arquetipo por sala (Limo, Esqueleto, Murciélago, Gólem, Espectro) o jefe del bioma
   ├─ CombatFX: partículas, números de daño, cortes, anillos y botín en espacio de mundo
   └─ CombatController: daño por cooldowns (attack_triggered) + feedback de cada golpe
```

**Sistema**: formas geométricas (`_draw()`) + ataques por cooldown, con dirección de arte "geometría iluminada"
(ver `doc/specs/2026-09-27-mejora-visual-y-feeling.md`). Sin spritesheets. Utilidades en `scripts/gameplay/visual/`
(`Biomes`, `EnemyArchetypes`, `ShapeKit`…). La anticipación de los ataques se calcula a partir del temporizador del
cooldown, así que no cambia el DPS. El HUD de la franja (oro, muertes, sala, récord, carteles) es `scripts/ui/HeroViewOverlay.gd`.

**Señal de ataque**: `attack_triggered` — emitida cuando el timer de ataque llega a 0. CombatController escucha y ejecuta daño.
El pulso mágico emite `pulse_hit(amount, target_pos)` (posición tomada antes del daño).
Los temporizadores del golpe y del pulso se llenan al empezar cada duelo (`prepare_for_combat()`). Recalcular a Tico a mitad de duelo (`reset_stats()`, en cada cambio de su rejilla, con el juego en marcha detrás del panel) no los reinicia: el golpe conserva su avance con la velocidad nueva y el pulso sigue su cuenta.

**Habilidades legendarias** (ver 4.3): `CombatMath.hero_stats_with_powers()` aplica sus multiplicadores después de `hero_stats()`. `Hero` guarda las de su rejilla en `power` (`reset_stats()`) y hace la regeneración, la esquiva, la parada, la segunda oportunidad (una por duelo) y arma el Ímpetu; `CombatController` hace el golpe doble, el Ímpetu (el primer golpe contra cada enemigo), la quemadura y las espinas; `Enemy` lleva la quemadura (`apply_burn()`: daño por segundo sin armadura).

**Flujo de combate**:
1. Héroe camina (RUN); entra en combate cuando el enemigo está a `reach + half_width` (no por solape de rects)
2. CombatController gestiona intercambio de golpes por cooldowns (FIGHT). La armadura del héroe reduce el daño físico: `armor / (armor + ARMOR_K · escala del enemigo)` con `ARMOR_K` 60 (`CombatMath`), máximo 60 %
3. Enemigo muere → rellena `death_info` → CombatController registra la victoria y avanza sala → Corridor muestra botín y celebración
4. Héroe muere → `GameManager.register_hero_death()`: la sala donde cae pasa a ser el muro → fundido → reaparición en la sala anterior con haz de luz. Delante del muro farmea y lo reintenta cada 3 victorias, o al momento con equipo nuevo (colocar, quitar, girar o intercambiar una pieza de la rejilla de Tico: `equipment_changed`) o una poción de efecto (`GameManager.room_cleared()`, `retry_wall_now()`). La ampliación de la rejilla al vencer por primera vez a un jefe (sala 10, 20, 30 o 40 del ciclo I, provisional) recalcula a Tico pero no prueba el muro: `register_enemy_defeat()` la aplica con `_growing_grid` puesto, porque el viaje en mitad de la victoria descuadraría la sala. Cada sala es un duelo: al cruzar su puerta, Tico recupera toda la vida. Selector de sala con candado en `HeroViewOverlay` (`GameManager.travel_to_room()`, `set_room_locked()`); spec de rangos, apartado 7
5. Hit-stop: `Corridor.hitstop(s)` congela héroe, enemigo y combate (nunca los minijuegos)

### 4.2 Sistema de crafteo

```
RequestManager         CraftingManager          MinigameBase
  │                        │                        │
  ├─ genera requests       ├─ cola 5 slots          ├─ start_trial(config)
  ├─ valida materiales     ├─ secuencia trials      ├─ trial_completed(result)
  └─ encola en crafting    ├─ scoring/calidad       └─ fade in/out + anti-spam
                           └─ finaliza → CraftedItem
```

**Data flow**:
```
BlueprintResource.trial_sequence → Array[TrialResource]
TrialResource.config → ForgeTrialConfig / HammerTrialConfig / SewTrialConfig / QuenchTrialConfig
TrialResult → score, grade, quality_label, normalized_score
CraftedItem → item con calidad calculada a partir de los trial results
```

### 4.3 Inventario en rejilla

El equipo de Tico es una rejilla estilo Lootbound: cada pieza forjada ocupa una forma, se gira y se coloca donde quepa, sin huecos fijos. Todo lo que está en la rejilla de Tico cuenta para sus estadísticas, y dónde está cambia cuánto rinde. Spec: `doc/specs/2026-09-27-inventario-en-rejilla.md`.

```
InventoryManager
  ├─ inventory: Dict[StringName, int]     # materiales (wood: 40, iron: 40, ...)
  ├─ crafted_items: Array[CraftedItem]    # todas las piezas; cada una está en un solo sitio (item.place)
  ├─ hero_grid: GearGrid                  # Tico (&"hero"): 4×4, crece hasta 6×6. Solo esto cuenta para sus estadísticas
  ├─ bag_grid: GearGrid                   # mochila (&"bag"): 6×4 fija. Guarda sin contar
  ├─ loot: Array[CraftedItem]             # botín (&"loot"): sin límite, lo más nuevo delante. Aquí llega todo lo forjado
  ├─ expansions: Array[StringName]        # ampliaciones ya aplicadas (GridExpansions)
  └─ consumables: Array                   # 2 huecos de pociones: {"id", "count"}
```

Nada se coloca solo: lo forjado va siempre al botín. La única excepción es la migración de partidas antiguas.

**Clases nuevas.** Las reglas son clases sin nodos (`RefCounted`, en `scripts/core/`) y cada rejilla es un control que se dibuja a sí mismo (`scripts/ui/`). Ninguna es un autoload.

| Clase | Qué hace | Quién la usa |
|-------|----------|--------------|
| `PieceShape` | Forma limpia de cada pieza (`ItemResource.shape_cells`), giros de 90° normalizados y aristas: casillas de más que no dan nada y estorban (2 en Básico y Bueno, 1 en Raro, 0 desde Épico) | `GearGrid`, `InventoryManager`, `CraftingManager` (las sortea al forjar), `EquipmentPanel` y las vistas |
| `GearGrid` | Una rejilla de casillas: dice si una pieza cabe, la coloca o la quita, da sus vecinas por los lados y hace copias (`duplicate_grid()`) para simular sin tocar nada | `InventoryManager` (Tico y mochila), `GearAuras`, `GearPacker`, `EquipmentPanel` y `GearGridView` |
| `GearAuras` | Auras entre vecinas (la espada da daño a las armas, el escudo armadura a las armaduras, el casco vida a todas y las botas velocidad de ataque a las armas; 0, 5, 10, 15 o 20 % según la calidad de quien la emite), zonas (+10 % en todo a la pieza con alguna casilla limpia en la suya) y tope (+50 % por estadística y pieza): `totals(grid)` y `bonuses(grid)` | `InventoryManager` (`calculate_total_stats()` y `preview_stats()`), `GearPacker`, `EquipmentPanel` (ficha y brillos) y `GearGridView` (zonas) |
| `LegendaryPowers` | Las 12 habilidades de las piezas legendarias (una por pieza; las maestras con precio), sus multiplicadores y sus efectos de combate. Dos iguales cuentan como una | `InventoryManager.active_legendary_powers()`, `CombatMath`, `Hero`, `CombatController`, `CraftResultScreen` y `EquipmentPanel` |
| `GearPacker` | Colocación automática y determinista (`find_spot()`, `pack()`) | La migración de partidas antiguas (`InventoryManager`) y «A la mochila» (`EquipmentPanel`) |
| `GridExpansions` | Las 4 ampliaciones (una por jefe de las salas 10, 20, 30 y 40 del ciclo I) y los tamaños 4×4 → 5×4 → 5×5 → 6×5 → 6×6 | `InventoryManager.apply_grid_expansion()`, `GameManager` y `EquipmentPanel` (dice qué jefe toca) |
| `Potions` | Catálogo de las pociones, los 2 huecos, el tope de 5 por hueco y el umbral del 30 % de vida | `InventoryManager`, `GameManager`, `ShopPanel`, `EquipmentPanel` y `HeroViewOverlay` |
| `GearGridView` | Control que dibuja una rejilla (casillas de 110 px, piezas, aristas, zonas, destino del arrastre y brillos). Las casillas que aún no existen salen punteadas | `EquipmentPanel` (la de Tico y la mochila) y `LootStripView` (casilla y dibujo de piezas) |
| `LootStripView` | Control que dibuja el botín: una tira con desplazamiento lateral y las piezas tumbadas | `EquipmentPanel` |

**Panel de Equipo** (`EquipmentPanel`, pantalla completa). De arriba abajo: estadísticas de Tico, ficha de la última pieza tocada, su rejilla delante de su sprite (con los 2 huecos de consumibles al lado), el botín con «Vender todo», la mochila y la zona de venta. El dedo lo lleva el panel en `_input`:
- tocar gira la pieza (en el botín solo la enseña);
- arrastrar la coloca o la intercambia: la pieza va una casilla por encima del dedo, y un segundo dedo, la rueda o la tecla R la giran;
- mantener pulsado 0,4 s abre la ficha completa;
- soltar en la zona de venta la vende;
- durante el arrastre, la vista previa de estadísticas (`EquipmentPanel._show_target()`: `InventoryManager.simulate_hero_grid()` y `GearAuras.totals()`) solo se recalcula cuando cambia la casilla de destino o el giro;
- Atrás (Android) cierra lo de más arriba: la confirmación, la ficha o el panel;
- la insignia del botón Equipo (`HUDMain`) cuenta las piezas del botín.

**Pociones.** Las de la tienda van a un hueco (`add_potion()`; sin hueco no se cobra) y `GameManager` las bebe solas. La de Vida, cuando Tico, vivo, baja del 30 % de su vida (señal `hurt` de `Hero` → `drink_potion()`). Velocidad y Suerte, al aparecer un jefe (`on_boss_appeared()`, que llama `Corridor`) si su efecto no está activo; delante de un muro sin candado esperan, porque una poción de efecto manda a Tico a probar el muro.

**Ampliación de la rejilla (provisional).** Hasta que las recetas lleguen con los rangos, `GameManager.register_enemy_defeat()` llama a `InventoryManager.apply_grid_expansion()` la primera vez que cae el jefe de la sala 10, 20, 30 o 40 del ciclo I. La rejilla crece (una columna a la derecha o una fila abajo, alternando), ninguna pieza se mueve y la señal `grid_expanded` hace salir «¡La rejilla crece!» en la franja. Ampliar no manda a Tico al muro (ver 4.1).

**Guardado versión 2 (la 3 es la de los rangos).** `to_save_data()` guarda en `inventory`: los materiales, las piezas (`crafted_items`, con el botín primero y en su orden; de cada pieza, `place`, `x`, `y`, `rot` y `aristas`), `hero_grid` (ancho y alto), `expansions` y `consumables`. Ya no guarda `equipped` ni `equipped_slots`. La versión 3 (apartado 4.4) no cambia esta forma: solo añade el rango de cada pieza (`rank`, 1 si falta). Una partida anterior (sin `hero_grid`) se migra al cargar:
1. da por forjadas las ampliaciones de los jefes que su récord ya supera (el mismo récord que toma `GameManager.load_save_data()`: el mayor entre `best_enemy_level` y `current_enemy_level`, porque una partida más antigua puede no traer el primero);
2. sortea las aristas de cada pieza con una semilla fija: la misma partida da siempre el mismo resultado;
3. coloca con `GearPacker` lo que estaba equipado, las mejores primero, y manda el resto al botín.

Una posición imposible al cargar (fuera de la rejilla o pisando otra pieza) también acaba en el botín: nunca se pierde una pieza.

**Copia de la partida antigua.** La partida es una sola, la comparten todas las compilaciones del juego y el guardado de después de cargar la reescribe en la versión actual. Por eso `SaveManager.load_game()` copia `save.json` en `save.v<versión de origen>.bak.json` (la misma carpeta `user://`) antes de repartir los datos, cuando la versión guardada es anterior a la actual. Solo la primera vez de cada versión: una migración posterior nunca pisa su copia.

**Rango del equipo.** `InventoryManager.grid_rank(grid)` toma la mejor pieza de cada tipo (arma, escudo, casco y botas) y delega en `Ranks.team_rank()`: el menor de esos rangos, o el I sin piezas. `equipment_rank()` es el de la rejilla de Tico. Lo usan `Hero.reset_stats()` (la base de Tico sube con él: `CombatMath.hero_stats(equipment, team_rank)`) y las estadísticas del panel de Equipo, para que lo que enseña coincida con lo que lucha. Añadir una pieza de un tipo que ya lleva nunca baja el rango.

**Pruebas.** `InventoryGridTests` (`scenes/tests/InventoryGridTests.tscn`), que incluye la medida de lo que tarda en abrirse el panel con la rejilla llena, y el plan `inventory` de `VisualCapture` para capturar el panel.

### 4.4 Rangos por ciclo

Los planos suben de rango sin límite: un ciclo son los 5 biomas (50 salas) y el ciclo N da los planos de rango N. Spec: `doc/specs/2026-09-27-rangos-de-plano-por-ciclo.md`. Las reglas son clases sin nodos en `scripts/core/`:

| Clase | Qué hace | Quién la usa |
|-------|----------|--------------|
| `Ranks` | Ciclo de una sala, hitos de jefe (`milestone_for_boss_room()`, `milestones_up_to_record()`), crecimiento de recetas, botín y oro (`mat_mult()` = 1,6^(N−1)), multiplicador de estadísticas (`stat_mult()`, sigue a la curva de enemigos a mitad de ciclo), `team_rank()`, `scale_stats()`, `recipe()`, los 5 materiales de bioma, numerales y textos de aviso | `DataManager`, `GameManager`, `RequestsManager`, `CraftingManager`, `CraftedItem`, `InventoryManager`, `Enemy` y la interfaz |
| `EnemyScaling` | Curva de los enemigos: `EXP` 1,0455 por sala dentro del ciclo, `STEP` 10,5 al empezar cada ciclo y `BOSS_MULT` 1,15 (valores de la calibración con Balanza) | `Enemy`, `Ranks`, `CombatMath` |
| `CombatMath` | Estadísticas de Tico (`hero_stats()`, con la base multiplicada por `EnemyScaling.cycle_mult` del rango del equipo), habilidades legendarias, mitigación de armadura (`ARMOR_K` 60) y DPS esperado | `Hero`, `InventoryManager`, `EquipmentPanel` y el enlace de Balanza |
| `TrialDifficulty` | Sube con el rango la velocidad y la precisión de cada minijuego, con topes: `apply(config, rank)` | `CraftingManager` al arrancar cada prueba |

**Flujo del rango:**
```
jefe vencido → GameManager.register_enemy_defeat() → Ranks.milestone_for_boss_room()
   → DataManager.apply_milestones()  (unlocked_ranks: plano → rango máximo; 0 = bloqueado)
   → blueprints_milestone (cartel «¡Planos avanzados II!») y un blueprint_unlocked por plano (pergaminos escalonados)
RequestsManager: pedido con rango (80 % el más alto desbloqueado, 20 % uno menor) y receta Ranks.recipe()
   → accept_request() consume materiales (los del plano × mat_mult y los de bioma) → CraftingManager.enqueue(rank)
   → minijuegos con TrialDifficulty.apply() → CraftedItem(rank): estadísticas × Ranks.stat_mult()
   → botín → rejilla de Tico → InventoryManager.equipment_rank() → base de Tico
Enemy: al morir suelta el material del bioma de su sala (Ranks.biome_material_for_room()); un jefe lo suelta seguro
```

Al cargar, `GameManager.apply_record_milestones()` aplica los hitos que el récord ya supera. El encargo propio (`CraftingManager.place_own_order(bp_id, rank)`, desde `BlueprintCard`: selector de rango y «Forjar») cobra la receta y no da oro.

**Guardado versión 3.** `SaveManager.SAVE_VERSION` = 3. Migra desde la 1 (inventario a la rejilla, objetos y planos a rango I) y desde la 2 (las piezas ya guardan su rango, 1). `DataManager` guarda `unlocked_ranks` (una partida sin él lo toma de los planos desbloqueados, como rango I) y `GameManager` el candado y la sala del muro. Después se aplican los hitos del récord. Antes de migrar se copia la partida en `save.v<versión de origen>.bak.json` (ver 4.3).

**Muro y farmeo** (`GameManager` y `Corridor`):
- `GameManager` lleva el récord (`best_enemy_level`), el muro (`wall_room`: la sala donde cayó Tico; 0 si no hay), el candado (`room_locked`) y el contador de reintentos. `room_cleared()` decide tras cada victoria si Tico avanza, repite sala o prueba el muro (cada `WALL_RETRY_WINS` = 3 victorias en la sala anterior); `retry_wall_now()` lo prueba al momento con equipo nuevo.
- Selector de sala: `travel_to_room()`, `set_room_locked()` y `selector_target()` (la sala o el bioma de al lado, entre la 1 y el récord). Por debajo del récord pone el candado.
- El viaje es instantáneo: `GameManager` emite `room_travel` y `Corridor._on_room_travel()` abandona el combate a medias, recoloca las puertas y pone a Tico en la sala nueva con la vida llena. Cada sala es un duelo (ver 4.1). Las señales `wall_changed` y `room_lock_changed` las pinta `HeroViewOverlay` («Muro: sala N», candado y flechas).

**Pruebas.** `RankTests` (`scenes/tests/RankTests.tscn`) y los planes `unlock`, `wall` y `ranks` de `VisualCapture`; `bash balance/arnes.sh check` mide los 35 objetivos de balance.

### 4.5 Minijuegos

Todos extienden `MinigameBase` (Control):

| Minijuego | Escena | Config | Mecánica |
|-----------|--------|--------|----------|
| Forja | `ForgeTemp.tscn` | `ForgeTrialConfig` | Cursor senoidal, tap en zona target |
| Martillo | `HammerMinigame.tscn` | `HammerTrialConfig` | Rhythm, notas acercándose |
| Costura | `SewOSU.tscn` | `SewTrialConfig` | Timing con patrones |
| Temple | `QuenchWater.tscn` | `QuenchTrialConfig` | Hold & release |

**Ciclo de vida**:
```
_ready() → fade_in → setup_title_screen("Hammer Time!") → start_game()
→ gameplay → complete_trial(result) → fade_out → queue_free()
```

---

## 5. Datos y recursos (.tres)

### 5.1 Recursos del proyecto

| Tipo | Ubicación | Cantidad | Descripción |
|------|-----------|----------|-------------|
| `BlueprintResource` | `data/blueprints/` | 15 | Recetas de items con trial_sequence |
| `BlueprintLibrary` | `data/blueprints/` | 1 | Colección de todos los blueprints |
| `ItemResource` | `data/items/` | 12 | Templates de items, con su forma en la rejilla (`shape_cells`, `arista_spots`) (faltan 3) |
| `MaterialResource` | `data/materials/` | 9 | cloth, fire, herb, ice, iron, leather, poison, water, wood |
| `DropTable` | `data/drops/` | 1 | Config de drops de enemigos |
| `MinigameSoundSet` | `data/` | 2 | Sets de sonido por minijuego |

### 5.2 Blueprints disponibles

4 tipos × 3-4 niveles: swords (basic/advanced/masterwork), shields (basic/advanced/master), helmets (basic/advanced/master), boots (basic/advanced/masterwork). 15 en total.

---

## 6. Estructura de carpetas

```
res://
├── scenes/            # Escenas .tscn
│   ├── Main.tscn      # Escena principal
│   ├── Corridor.tscn  # Corredor endless
│   ├── Minigames/     # 4 minijuegos
│   ├── UI/            # HUD, paneles, popups
│   ├── ForgeUI/       # Paneles de forja (delivery, result, info)
│   ├── HUD/           # DungeonStatus
│   └── sandboxes/     # Escenas de test (dev only)
├── scripts/           # GDScript
│   ├── autoload/      # 9 singletons
│   ├── core/          # MinigameBase, launcher, configs, reglas del inventario (PieceShape, GearGrid, GearAuras…)
│   ├── gameplay/      # Hero, Enemy, Combat, Corridor
│   ├── data/          # Resources (Blueprint, Item, Material, Trial)
│   ├── ui/            # UI controllers (24+ scripts)
│   ├── forge/         # Delivery, ResultPanel, animated backgrounds
│   └── tools/         # Dev tools (PS1, PY, debug GD)
├── data/              # .tres resources
│   ├── blueprints/    # 15 + library
│   ├── items/         # 12 ItemResources
│   ├── materials/     # 9 materials
│   └── drops/         # DropTables
├── art/
│   ├── placeholders/  # Iconos, fondos, dungeon bg
│   ├── sounds/        # SFX organizados
│   ├── font/          # PirataOne
│   └── assets/        # Subrepo de arte (spritesheets, raw)
├── doc/               # Documentación
├── addons/            # Editor scripts
└── shaders/           # circular_mask.gdshader
```

---

## 7. Convenciones técnicas

| Aspecto | Regla |
|---------|-------|
| Indentación | **TABS** exclusivamente. Nunca espacios. |
| Archivos | `snake_case.gd`, `.tscn`, `.tres` |
| Clases | `PascalCase` |
| Señales | `lower_snake_case` |
| Variables privadas | Prefijo `_` |
| Archivos .uid | Internos de Godot 4.5, no borrar |
| Nuevos autoloads | Prohibido sin confirmación |
| Runtime write | Solo `user://`, nunca `res://` |
| Input | Touch + ratón. Sin teclado. |

---

## 8. Problemas técnicos conocidos

| Problema | Ubicación | Impacto |
|----------|-----------|---------|
| `duck_music()` crea Timer sin limpiar | `AudioManager.gd` | Leak de nodos si se llama frecuentemente |
| `MAX_DEATHS = 50` + `DungeonState.FAILED` | `GameManager.gd` | Legacy — no debe haber game over en endless |
| `ITEM_BONUSES` hardcodeado | `GameManager.gd` | No lee de DataManager dinámicamente |
| Dual-context audio | `AudioManager.gd` | FORGE/DUNGEON separados pero ya no aplica |
| `show_forge()`/`show_dungeon()` | `UIManager.gd` | Area switching legacy, deprecado |
| `_enqueue_defaults()` | `CraftingManager.gd` | Dead code (legacy) |
| `get_blueprints()` == `get_all_blueprints()` | `DataManager.gd` | Métodos duplicados |
| Prints excesivos | Varios autoloads | Ruido en consola |
| `DungeonHUD` | `scripts/ui/DungeonHUD.gd` | Sin uso (ninguna escena lo instancia) y llama a `equip_item` y `get_equipped_item`, que ya no existen: borrarlo en la limpieza |
| `ParticleManager.gd` duplicado | `scripts/` y `scripts/core/` | Verificar cuál usa Corridor |
