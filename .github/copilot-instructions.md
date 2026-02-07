# Copilot — Instrucciones del proyecto PetJam (Godot 4.5)

## TL;DR
- **Engine**: Godot **4.5.1** estable. Lenguaje: **GDScript**. 2D.
- **Plataforma objetivo**: **Android** (Google Play). Testing en desktop con ratón.
- **Concepto**: Juego idle/casual móvil. Eres un herrero que craftea equipo via **4 minijuegos** mientras un héroe IA lucha indefinidamente en una dungeon endless. Escalado infinito. Sin condición de victoria/derrota.
- **Arquitectura fija**: usa **9 AutoLoads** registrados: `GameManager`, `DataManager`, `InventoryManager`, `CraftingManager`, `DebugManager`, `AudioManager`, `TelemetryManager`, `UIManager`, `RequestManager`.
- **Entrega**: todo snippet debe ser **pegable** y referenciar rutas reales `res://...`. Nada de plugins externos ni rework masivo.
- **CRÍTICO - Indentación**: Godot 4.5 usa **TABS** exclusivamente. **NUNCA** uses espacios ni mezcles tabs y espacios.
- **Resolución**: **1080x1920** (portrait 9:16) para móvil. Stretch mode: `canvas_items` con aspect `keep_width`.
- **Skills de referencia**: en `.agents/skills/` hay skills de buenas prácticas (`godot-gdscript-patterns`), mobile (`mobile-android-design`) y game development (`game-development`).

---

## Concepto de juego

### Visión
Un juego idle/casual para Android donde el jugador es un **herrero** que craftea equipamiento via minijuegos de timing. Un **héroe IA** lucha en una dungeon endless en segundo plano. El héroe sigue luchando incluso cuando la app está cerrada (cálculos offline). El jugador craftea mejor equipo → el héroe avanza más lejos.

### Loop principal
1. El héroe pelea automáticamente contra enemigos (endless, escalado infinito)
2. Al morir, el héroe resetea al nivel 1 **con su equipo actual**
3. El jugador acepta **requests** (pedidos) para craftear items
4. Cada item requiere completar una secuencia de **trials** (minijuegos)
5. La calidad del item depende de la precisión en los minijuegos + nivel de forjamagia
6. El jugador equipa items al héroe para que avance más
7. Los enemigos dropean **blueprints** e **infusiones elementales**
8. **No hay condición de victoria ni derrota** — es un juego infinito con leaderboard

### Modelo de sesión
- **No hay "runs" ni "partidas"**. Es una **sesión continua persistente**.
- El jugador juega tantos minijuegos como quiera.
- El héroe combate en segundo plano indefinidamente.
- Progresión = mejor equipo crafteado = héroe llega más lejos.
- El Corridor se instancia una vez y persiste siempre.
- Cuando el jugador cierra la app, el héroe sigue luchando (cálculo offline al volver).

---

## Contexto del repo
- El diseño de juego está en `README.md` (GDD original, parcialmente desactualizado). Las copilot-instructions tienen la **visión actualizada**.
- Documentación del proyecto: `doc/PROJECT_FAQ.md` (preguntas y respuestas), `doc/ARCHITECTURE.md` (arquitectura técnica).
- Proyecto 2D. No intentes migrar a 3D ni a C#.

## Resolución y Display
- **Resolución base**: **1080x1920** (portrait 9:16) — Android
- **Stretch Mode**: `canvas_items` con aspect `keep_width`
- **Input principal**: touch (Android). Para testing: ratón en desktop.
- **Layout**: todo en una única pantalla (ver Layout más abajo)
- Usa anchors y layouts flexibles en UI. No hardcodees posiciones.

## Layout de pantalla (1080x1920)
```
┌─────────────────────────────────────┐ 0px
│       ESCENA DEL HÉROE (25%)        │ ← Héroe peleando + HP encima
│       Muertes centradas arriba      │    480px
├─────────────────────────────────────┤ 480px
│                                     │
│       ZONA IDLE / MINIJUEGOS (50%)  │ ← Minijuegos se lanzan aquí
│       (MinigameContainer)           │    960px
│                                     │
├───────────────────────┬─────────────┤ 1440px
│  REQUESTS ACTIVOS     │  BOTONES    │
│  (cola de pedidos)    │  Blueprints │ ← Controles (25%)
│                       │  Inventario │    480px
│                       │  Tienda     │
└───────────────────────┴─────────────┘ 1920px
     70% ancho            30% ancho
```

## Estructura REAL del proyecto
```
res://
  scenes/
    Main.tscn                    # Escena principal (HUDLayer + FadeLayer, usa main.gd)
    Corridor.tscn                # Corredor endless (Hero/Enemy/Combat)
    DungeonLayout.tscn           # Layout visual posiciones enemigos
    Hero.tscn                    # Héroe (CharacterBody2D)
    Enemy.tscn                   # Enemigo base (grunt/tank)
    Minigames/
      ForgeTemp.tscn            # Minijuego de temperatura/forja (timing)
      HammerMinigame.tscn       # Minijuego de martillo (rhythm)
      SewOSU.tscn               # Minijuego de coser (timing/patrones)
      QuenchWater.tscn          # Minijuego de temple/agua (hold&release)
    UI/
      StartScreen.tscn          # Pantalla de inicio
      HUD_Main.tscn             # Layout unificado (héroe+minijuegos+controles)
      HUD_Forge.tscn            # HUD legacy de forja (deprecated)
      BlueprintLibraryPanel.tscn # Catálogo de blueprints
      BlueprintCard.tscn        # Card individual de blueprint
      BlueprintQueueSlot.tscn   # Slot de cola de crafteo
      EquipmentPanel.tscn       # Panel equipamiento héroe
      DungeonHUD.tscn           # HUD de dungeon
      TitleScreen.tscn          # Overlay de título minijuego
      MaterialIcon.tscn         # Icono de material
      RequestSlot.tscn          # Slot de request
    ForgeUI/
      DeliveryPanel.tscn        # Panel de entrega de items
      ItemInfoPanel.tscn        # Info de item crafteado
      ResultPanel.tscn          # Panel resultado crafteo
    HUD/
      DungeonStatus.tscn        # Status del corredor (unificar con héroe)
    sandboxes/                  # Escenas de prueba para development
  scripts/
    main.gd                      # Script bootstrap (Main.tscn)
    autoload/
      GameManager.gd            # Estado global, enemigos, respawn, loadout
      DataManager.gd            # Catálogo blueprints, materiales, items
      InventoryManager.gd       # Inventario materiales + items crafteados + equipo
      CraftingManager.gd        # Cola crafteo (5 slots), trials, scoring
      DebugManager.gd           # Debug tools (*=autorun)
      AudioManager.gd           # SFX y música unificado
      TelemetryManager.gd       # Logs a user://telemetry.log
      UIManager.gd              # Gestión de paneles UI
      RequestsManager.gd        # Sistema de pedidos (timer + eventos)
    core/
      MinigameBase.gd           # Clase base para minijuegos
      HUDMinigameLauncher.gd    # Launcher de minijuegos desde HUD
      TrialConfig.gd            # Configuración base de trials
      TrialResult.gd            # Resultado de trials
      QualityHelper.gd          # Helper cálculo calidad
      ParticleManager.gd        # Gestor de partículas
    gameplay/
      Hero.gd                   # Lógica del héroe
      Enemy.gd                  # Lógica enemigos (grunt/tank, drops)
      CombatController.gd       # Sistema de combate
      Corridor.gd               # Gestión del corredor endless
      DungeonLayout.gd          # Posiciones de spawn
      FloatingNumber.gd         # Números de daño flotantes
      CorridorParallax.gd       # Parallax visual
    data/
      BlueprintResource.gd      # Recurso blueprint (trial_sequence, materials, stats)
      BlueprintLibrary.gd       # Colección de blueprints
      ItemResource.gd           # Template de item
      CraftedItem.gd            # Instancia de item con calidad
      MaterialResource.gd       # Recurso de material
      TrialResource.gd          # Recurso de trial individual
      ForgeTrialConfig.gd       # Config específica Forge
      HammerTrialConfig.gd      # Config específica Hammer
      SewTrialConfig.gd         # Config específica Sew
      QuenchTrialConfig.gd      # Config específica Quench
      MinigameDifficultyPreset.gd  # Presets de dificultad
      MinigameSoundSet.gd       # Set de sonidos por minijuego
    ui/                          # Scripts de UI (~24 scripts)
    forge/                       # Scripts de paneles de forja
    # Scripts en raíz de scripts/ (legacy, pendiente organizar):
    ForgeMinigame.gd             # Minijuego Forge (extiende MinigameBase)
    HammerMinigame.gd            # Minijuego Hammer (extiende MinigameBase)
    SewMinigame.gd               # Minijuego Sew (extiende MinigameBase)
    QuenchMinigame.gd            # Minijuego Quench (extiende MinigameBase)
  data/
    blueprints/                 # 15 BlueprintResource .tres + BlueprintLibrary.tres
    items/                      # 12 ItemResource .tres (faltan 3)
    materials/                  # 9 MaterialResource .tres
    drops/                      # DropTable configs
    minigame_sounds_*.tres      # Sound sets por minijuego
  art/
    placeholders/               # Iconos, fondos, dungeon background
    sounds/                     # SFX: sfx/{combat,minigames/}, ambient/
    font/                       # Fuentes (PirataOne)
    assets/                     # Subrepo de arte (spritesheets, imágenes raw)
  doc/                          # Documentación técnica
  addons/editor_scripts/        # Scripts de editor (gestión blueprints)
  shaders/circular_mask.gdshader # Shader para MinigameContainer
```

### Convenciones de nombres
- Archivos: `snake_case` (.gd, .tscn, .tres)
- Clases: `PascalCase`
- Señales: `lower_snake_case`
- **TABS, no espacios**. Jamás mezcles.
- Archivos `.uid` acompañan cada `.gd` — internos de Godot 4.5, no borrar.
- **No** añadas nuevos autoloads sin confirmación.

## AutoLoads (Singletons) — YA REGISTRADOS
**NO AÑADAS NUEVOS**. Los siguientes ya están en `project.godot`:

| # | Singleton | Script | Responsabilidad |
|---|-----------|--------|-----------------|
| 1 | `GameManager` | `res://scripts/autoload/GameManager.gd` | Estado global, nivel enemigos (infinito), muertes, respawn, loadout héroe, desbloqueo blueprints |
| 2 | `DataManager` | `res://scripts/autoload/DataManager.gd` | Catálogo blueprints, unlock state, resolución ItemResource. Emite `data_ready` |
| 3 | `InventoryManager` | `res://scripts/autoload/InventoryManager.gd` | Materiales (add/consume), items crafteados, equipment slots (7), cálculo stats totales |
| 4 | `CraftingManager` | `res://scripts/autoload/CraftingManager.gd` | Cola de crafteo (5 slots), secuenciador trials, scoring, calidad final |
| 5 | `DebugManager` | `*res://scripts/autoload/DebugManager.gd` | Debug tools, logging por categorías (* = autorun) |
| 6 | `AudioManager` | `res://scripts/autoload/AudioManager.gd` | SFX y música. Contexto unificado |
| 7 | `TelemetryManager` | `res://scripts/autoload/TelemetryManager.gd` | Logs JSON a `user://telemetry.log` |
| 8 | `UIManager` | `res://scripts/autoload/UIManager.gd` | Gestión paneles UI, delivery, registro de nodos |
| 9 | `RequestManager` | `res://scripts/autoload/RequestsManager.gd` | Pedidos por timer (3-8s), máx 4 activos, validación materiales |

### Dependencias entre AutoLoads
```
DataManager ──(data_ready)──→ RequestsManager, CraftingManager
RequestsManager ──→ DataManager, InventoryManager, CraftingManager
CraftingManager ──→ DataManager, InventoryManager
UIManager ──→ GameManager, CraftingManager, InventoryManager, DataManager
GameManager ──→ DataManager (desbloqueo blueprints)
```

## Reglas de implementación
- Escribe **GDScript** idiomático. Señales > polling. `await` en vez de temporizadores manuales.
- **TABS (\t)** para indentación, **nunca espacios**. Sin excepciones.
- Los minijuegos **extienden `MinigameBase`** (`res://scripts/core/MinigameBase.gd`):
  - `func start_trial(config: TrialConfig)` — inicia trial. Subclases llaman `super()`.
  - `signal trial_completed(result: TrialResult)` — emite resultado.
  - Pantalla de título animada al inicio (solo texto, ej: "Hammer Time!").
  - Sin pantalla de fin por trial individual. Al completar TODOS los trials → resultado con barra de calidad animada.
  - Siempre produce resultado (mínimo 1% calidad), nunca fallo total.
- **Arquitectura de trials**:
  - Cada blueprint tiene `trial_sequence: Array[TrialResource]` (varía por blueprint)
  - `TrialResource`: `trial_id`, `display_name`, `minigame_id`, `minigame_scene`, `config`, `min_score`
  - Configs tipadas: `ForgeTrialConfig`, `HammerTrialConfig`, `SewTrialConfig`, `QuenchTrialConfig`
  - `TrialResult`: `score`, `grade`, `quality_label`, `normalized_score`
  - Calidad final = puntuación total / puntuación máxima posible del blueprint
- **Input**: touch (Android) + ratón (testing). No hace falta teclado.
- **Persistencia**: a futuro guardar en disco (`user://`). Actualmente en memoria.
- **Export**: Android (Google Play). Desktop solo para desarrollo.

## Sistema de combate
- Escalado **infinito**: enemigos suben stats con fórmula exponencial por nivel.
- Héroe escala por equipo: stats sumadas de items en 7 slots.
- **Equipment slots**: `main_hand`, `off_hand`, `helmet`, `chest`, `boots`, `trinket_1`, `trinket_2`.
- Al morir → resetea a nivel 1 con equipo intacto. Al reemplazar item, el anterior se pierde.
- Enemies dropean **blueprints** (primer kill) e **infusiones elementales**.
- Sistema de tipos de daño previsto: armaduras (fortificada/pesada/ligera/héroe/divina) × daño (siege/perforante/cortante/caos).
- Boss cada X niveles: stats × multiplicador + pasivas de un pool. Escalado combinatorio al agotar pool.
- **Dirección visual**: simplificar a formas geométricas + ataques por cooldown.

## Crafting y minijuegos
- `CraftingManager` mantiene **cola de 5 slots**, gestiona trials, calcula calidad.
- `HUDMinigameLauncher` orquesta el flujo desde el HUD.
- **Flujo**: Request → accept (consume materiales) → enqueue → start → trials secuenciales → finalize → CraftedItem → equip
- **Forjamagia**: medidor siempre presente durante crafteo. Heat + Crit Craft activos.
- Minijuegos:
  1) **Forja (ForgeTemp)**: timing — cursor senoidal, tap en zona target
  2) **Martillo (HammerMinigame)**: rhythm — notas acercándose, tap en timing. Cantidad parametrizable
  3) **Coser (SewOSU)**: timing con patrones predefinidos (simplificar a timing puro)
  4) **Agua (QuenchWater)**: hold & release — pulsar, mantener, soltar en ventana óptima
- Calificación: `Perfect` / `Bien` / `Regular` / `Miss` con thresholds numéricos consistentes.
- Dificultad escala: minijuegos más rápidos, más eventos, ventanas más estrectas.
- Materiales influyen en tipo de prueba (metal → forja, tela/cuero → coser).

## Estilo de respuesta
- **Idioma**: español técnico.
- **Salida**: snippet listo para pegar, con ruta y archivo destino.
- Cambios en **parches pequeños**; si afecta varias escenas, lista de diffs.
- **TABS exclusivamente** en todo código GDScript.
- No propongas reestructurar el proyecto. Trabaja con lo que hay.
- Consulta las skills en `.agents/skills/` para patrones Godot y diseño móvil.

## No hagas (hard limits)
- Nada de plugins, paquetes de terceros ni migración de versión de Godot.
- No añadas sistemas de ECS, jobs o "task runners" inventados.
- No muevas autoloads ni renombres rutas existentes.
- No uses `res://` para escribir en runtime; usa `user://`.
- No diseñes para "runs" o "partidas". Es una sesión persistente continua.
- No diseñes UI con hover o interacciones solo de desktop; todo debe ser touch-friendly.

## Sistemas deprecados (NO usar)
- `switch_area()` / dual-context forge/dungeon — todo en una pantalla
- `Room.tscn` — obsoleto
- `HUD_Forge.tscn` — reemplazado por `HUD_Main.tscn`
- `GameOverScreen` / `MAX_DEATHS` — no hay game over en endless
- Entrega QTE — deprecado, entrega instantánea por botón

## Features por implementar
- [ ] Persistencia a disco (save/load inventario, equipo, progreso)
- [ ] Cálculos offline (combate del héroe mientras app cerrada)
- [ ] Sistema tipos de daño (armadura × daño estilo Warcraft 3)
- [ ] Pool de pasivas para bosses (escalado combinatorio)
- [ ] Leaderboard (nivel máximo alcanzado)
- [ ] Fórmulas escalado infinito enemigos
- [ ] Tienda materiales + pociones (gastar oro)
- [ ] Infusiones elementales (drops → dificultad extra → encantamiento)
- [ ] Medidor de Forjamagia + Heat + Crit Craft
- [ ] Simplificar combate a formas geométricas + CD attacks
- [ ] Simplificar Sew a timing puro
- [ ] Pantalla resultado crafteo con barra calidad animada
- [ ] Export + testing Android
- [ ] Eventos prefijados en RequestManager para narrativa
- [ ] Items faltantes (3 ItemResource por crear)

## Checklists rápidas
- [ ] GDScript con rutas `res://...` reales
- [ ] Autoloads existentes, no se añaden nuevos
- [ ] Minijuegos: `start_trial(config)` + `trial_completed(result)`
- [ ] Sin dependencias externas
- [ ] Héroe pelea endless, resetea nivel 1 al morir con equipo
- [ ] **TABS** para indentación, nunca espacios
- [ ] UI funciona en 1080x1920 portrait
- [ ] Input touch-friendly (botones grandes, sin hover)

## Pitfalls frecuentes
- Escribir en `res://` en runtime → usa `user://`
- Minijuegos sin API común → extiende `MinigameBase`
- Señales no desconectadas → listeners colgantes al recargar
- Timers manuales → usa `await get_tree().create_timer()`
- **Espacios en vez de tabs** → Godot 4.5 requiere tabs
- Mentalidad de "runs/partidas" → sesión continua
- Hardcodear resolución desktop → target es 1080x1920
- Usar `area_switch` deprecado → todo en una pantalla
- `duck_music()` crea Timer sin limpiar → potencial leak

## Referencias internas
- GDD original: `README.md` (parcialmente desactualizado)
- FAQ completo: `doc/PROJECT_FAQ.md`
- Arquitectura: `doc/ARCHITECTURE.md`
- Layout spec: `doc/LAYOUT_SPEC.md`
- Roadmap: `doc/ROADMAP.md`
- Skills: `.agents/skills/` (godot-gdscript-patterns, mobile-android-design, game-development)
- AutoLoads: `res://scripts/autoload/*.gd`
