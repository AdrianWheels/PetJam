# PetJam — Arquitectura Técnica

> Documento de referencia sobre la arquitectura del proyecto.  
> **Última actualización**: 2026-02-07

---

## 1. Visión general

PetJam es un juego idle/casual 2D para Android construido en **Godot 4.5.1** con **GDScript**. Resolución portrait **1080x1920** (9:16).

Toda la experiencia ocurre en **una sola pantalla** dividida en 3 zonas: el héroe luchando (arriba), los minijuegos de crafteo (centro) y los controles/requests (abajo).

---

## 2. Flujo de escenas

```
StartScreen.tscn ──(botón Play)──→ Main.tscn
                                       │
                                       ├─ ForgeUI (CanvasLayer)
                                       │    └─ HUD_Forge.tscn
                                       │         ├─ MinigameContainer (minijuegos dinámicos)
                                       │         ├─ RequestSlots (cola de pedidos)
                                       │         ├─ BlueprintLibraryPanel (popup)
                                       │         └─ EquipmentPanel (popup, WIP)
                                       │
                                       ├─ Corridor.tscn (instancia persistente)
                                       │    ├─ Hero.tscn (CharacterBody2D)
                                       │    ├─ Enemy.tscn (CharacterBody2D)
                                       │    ├─ CombatController
                                       │    └─ ParticleManager
                                       │
                                       ├─ ForgeUI/ (paneles modales)
                                       │    ├─ DeliveryPanel.tscn
                                       │    ├─ ItemInfoPanel.tscn
                                       │    └─ ResultPanel.tscn
                                       │
                                       └─ FadeLayer
```

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
- **Señales**: `enemy_spawned`, `hero_died`, `hero_respawned`, `boss_defeated`, `dungeon_state_changed`, `hero_loadout_changed`, `enemy_defeated_first_time`, `enemy_level_changed`
- **Enum**: `DungeonState { IDLE, RUNNING, HERO_DEAD, COMPLETED, FAILED }`
- **API clave**: `start_run()`, `advance_enemy_level()`, `register_enemy_defeat(level)`, `register_hero_death()`, `request_respawn()`, `deliver_item_to_hero(item_id, slot)`, `register_hero(node)`
- **Dependencias**: `DataManager` (para unlock de blueprints)
- **Nota**: `MAX_DEATHS` y `DungeonState.FAILED/COMPLETED` son legacy del diseño de jam. En endless mode no hay game over.

#### DataManager
- **Señales**: `data_ready`
- **API clave**: `get_blueprint(id)`, `get_blueprints()`, `is_blueprint_unlocked(id)`, `unlock_blueprint(id)`, `get_unlocked_blueprints()`, `get_item_resource(item_id)`
- **Dependencias**: Ninguna. Carga `BlueprintLibrary.tres` en `_ready()`.
- **Blueprints iniciales desbloqueados**: `sword_basic`, `shield_basic`, `boots_basic`

#### InventoryManager
- **Señales**: `inventory_changed`, `crafted_items_changed`
- **Estado**: `inventory: Dictionary` (materiales), `crafted_items: Array[CraftedItem]`, `equipped_items: Dictionary` (slot → CraftedItem)
- **API clave**: `add_item(id, qty)`, `has_materials(req)`, `consume_materials(req)`, `add_crafted_item(item)`, `equip_item(item)`, `unequip_item(slot)`, `calculate_total_stats()`, `clear()`
- **Dependencias**: Ninguna. Standalone.
- **Nota**: Todo en memoria. No persiste a disco. Materiales iniciales generosos para testing.

#### CraftingManager
- **Señales**: `craft_enqueued`, `task_started`, `task_updated`, `task_completed`
- **Constantes**: `MAX_SLOTS = 5`, Grados: gold (90%), silver (70%), bronze (40%)
- **API clave**: `enqueue(recipe_id)`, `start_task(slot_idx)`, `cancel(slot_idx)`, `report_trial_result(task_id, result)`, `get_queue_snapshot()`, `has_active_trial()`
- **Dependencias**: `DataManager`, `InventoryManager`

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
   ├─ Hero: pentágono con cara y EQUIPO VISIBLE (arma/escudo/casco/botas por calidad)
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

**Flujo de combate**:
1. Héroe camina (RUN); entra en combate cuando el enemigo está a `reach + half_width` (no por solape de rects)
2. CombatController gestiona intercambio de golpes por cooldowns (FIGHT). La armadura del héroe reduce el daño físico: `armor / (armor + 40)`, máximo 60 %
3. Enemigo muere → rellena `death_info` → CombatController registra la victoria y avanza sala → Corridor muestra botín y celebración
4. Héroe muere → `GameManager.register_hero_death()` → fundido → reaparición en la sala 1 con haz de luz
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

### 4.3 Sistema de inventario

```
InventoryManager
  ├─ inventory: Dict[StringName, int]     # materiales (wood: 40, iron: 40, ...)
  ├─ crafted_items: Array[CraftedItem]    # items producidos
  └─ equipped_items: Dict[String, CraftedItem]  # 7 slots del héroe
```

### 4.4 Minijuegos

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
| `ItemResource` | `data/items/` | 12 | Templates de items (faltan 3) |
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
│   ├── core/          # MinigameBase, launcher, configs
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
| `EquipmentPanel` | UI | No actualiza stats del héroe al equipar |
| `ParticleManager.gd` duplicado | `scripts/` y `scripts/core/` | Verificar cuál usa Corridor |
