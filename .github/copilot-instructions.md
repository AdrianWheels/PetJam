
# Copilot — Instrucciones del proyecto (Godot 4.5 Jam)

## TL;DR
- **Engine**: Godot **4.5.1** estable. Lenguaje: **GDScript**. 2D minimal.
- **Goal**: Jam MVP. Un corredor con **8 salas + jefe**, héroe en auto‑avance y **4 minijuegos** de crafteo (Forja, Martillo, Coser, Temple/Agua).
- **Arquitectura fija**: usa **9 AutoLoads** registrados: `GameManager`, `DataManager`, `InventoryManager`, `CraftingManager`, `DebugManager`, `AudioManager`, `TelemetryManager`, `UIManager`, `RequestManager`.
- **Entrega**: todo snippet debe ser **pegable** y referenciar rutas reales `res://...`. Nada de plugins externos ni rework masivo.
- **CRÍTICO - Indentación**: Godot 4.5 usa **TABS** exclusivamente. **NUNCA** uses espacios ni mezcles tabs y espacios. Todo el proyecto usa tabs.
- **Resolución**: Base **1280x720** (desktop). Viewport móvil: **1080x1350** (portrait 4:5). Stretch mode: `2d` con aspect `expand`.

---

## Contexto del repo
- El diseño de juego está en `README.md` (GDD resumido). Respétalo.
- Proyecto 2D. No intentes migrar a 3D ni a C#.
- Objetivo de sesión: producir features autocontenidas y probables en ≤90 min.

## Resolución y Display
- **Base de diseño**: 1280x720 (16:9) para desktop
- **Viewport móvil actual**: 1080x1350 (portrait 4:5)
- **Stretch Mode**: `2d` con aspect `expand`
- **Recomendación móvil**: Para portrait óptimo usa 1080x1920 (9:16) o mantén 1080x1350 si prefieres formato cuadrado
- **Nota**: El layout de forja y dungeon debe ser responsive. Usa anchors y layouts flexibles en UI.
- **Testing**: Prueba tanto en 1280x720 como en la resolución móvil configurada

## Estructura REAL del proyecto
```
res://
  scenes/
    Main.tscn                    # Escena principal
    DungeonLayout.tscn           # Layout visual de dungeon (NUEVO)
    Corridor.tscn                # Corredor lineal de salas (lógica Hero/Enemy)
    Room.tscn                    # Sala individual de combate (obsoleto)
    Hero.tscn                    # Héroe jugable
    Enemy.tscn                   # Enemigo base
    Minigames/
      ForgeTemp.tscn            # Minijuego de temperatura/forja
      HammerMinigame.tscn       # Minijuego de martillo (timing)
      SewOSU.tscn               # Minijuego de coser (ritmo OSU-like)
      QuenchWater.tscn          # Minijuego de temple/agua
    UI/
      HUD_Forge.tscn            # HUD principal con MinigameContainer
      BlueprintLibraryPanel.tscn
      TitleScreen.tscn
    ForgeUI/                    # Paneles UI de forja
    HUD/                        # Componentes HUD
    sandboxes/                  # Escenas de prueba
  scripts/
    autoload/
      GameManager.gd            # Estado de partida, flujo de salas
      DataManager.gd            # Blueprints, materiales, items
      InventoryManager.gd       # Sistema de inventario
      CraftingManager.gd        # Cola crafteo, minijuegos, entrega
      DebugManager.gd           # Herramientas debug (*enabled)
      AudioManager.gd           # SFX, bips, contextos de audio
      TelemetryManager.gd       # Logs a user://telemetry.log
      UIManager.gd              # Gestión de paneles UI
      RequestsManager.gd        # Sistema de peticiones
    core/
      MinigameBase.gd           # Clase base para minijuegos
      HUDMinigameLauncher.gd    # Launcher de minijuegos desde blueprints
      TrialConfig.gd            # Configuración de trials
      TrialResult.gd            # Resultado de trials
    gameplay/
      Hero.gd                   # Lógica del héroe
      Enemy.gd                  # Lógica enemigos
      CombatController.gd       # Sistema de combate
      Corridor.gd               # Gestión del corredor
      DungeonLayout.gd          # Layout visual de dungeon (NUEVO)
    data/
      BlueprintResource.gd      # Recurso de blueprint
      TrialResource.gd          # Recurso de trial
      ForgeTrialConfig.gd       # Config específica Forge
      HammerTrialConfig.gd      # Config específica Hammer
      SewTrialConfig.gd         # Config específica Sew
      QuenchTrialConfig.gd      # Config específica Quench
      MinigameDifficultyPreset.gd  # Presets de dificultad
    ui/
      MinigameFX.gd             # Sistema de efectos visuales
      MinigameAudio.gd          # Sistema de audio minijuegos
      MinigameContainer.gd      # Contenedor de minijuegos
    # Scripts raíz (legacy, considerar mover):
    ForgeMinigame.gd
    HammerMinigame.gd / HammerMinigame_NEW.gd
    SewMinigame.gd / SewMinigame_NEW.gd
    QuenchMinigame.gd / QuenchMinigame_NEW.gd
    main.gd
  data/
    blueprints/                 # Archivos .tres de blueprints
      sword_basic.tres
      armor_leather.tres
      bow_simple.tres
      shield_wooden.tres
      (etc... 16 blueprints)
    drops/                      # Configuración de drops
    minigame_sounds_default.tres
  art/
    placeholders/
      forge/                    # Assets forja
      dungeon/                  # Assets dungeon
    sounds/                     # SFX .wav/.mp3
  doc/                          # Documentación técnica
  addons/
    editor_scripts/             # Scripts de editor
```
- **No** añadas nuevos autoloads sin confirmación. Usa los **9 registrados**.
- Nombres de archivos `snake_case`. Clases `PascalCase`. Señales `lower_snake_case`.
- **TABS, no espacios**. Jamás mezcles.

## AutoLoads (Singletons) — YA REGISTRADOS
**NO AÑADAS NUEVOS**. Los siguientes ya están en `project.godot`:
1. `GameManager` — `res://scripts/autoload/GameManager.gd` (estado de partida, flujo de salas, respawn)
2. `DataManager` — `res://scripts/autoload/DataManager.gd` (blueprints, materiales, items, balance)
3. `InventoryManager` — `res://scripts/autoload/InventoryManager.gd` (inventario del jugador)
4. `CraftingManager` — `res://scripts/autoload/CraftingManager.gd` (cola crafteo, trials, resultados)
5. `DebugManager` — `*res://scripts/autoload/DebugManager.gd` (debug tools, *=autorun enabled)
6. `AudioManager` — `res://scripts/autoload/AudioManager.gd` (SFX, contextos DUNGEON/FORGE)
7. `TelemetryManager` — `res://scripts/autoload/TelemetryManager.gd` (logs a `user://telemetry.log`)
8. `UIManager` — `res://scripts/autoload/UIManager.gd` (gestión de UI, paneles)
9. `RequestManager` — `res://scripts/autoload/RequestsManager.gd` (sistema de pedidos/requests)

## Reglas de implementación
- Escribe **GDScript** idiomático. Señales > polling. `await` en vez de temporizadores manuales cuando cuadre.
- **TABS**: usa **tabs (\\t)** para indentación, **nunca espacios**. Godot 4.5 requiere tabs exclusivamente.
- Los minijuegos **extienden `MinigameBase`** (`res://scripts/core/MinigameBase.gd`):
  - `func start_trial(config: TrialConfig) -> void` — inicia el trial con configuración
  - `signal trial_completed(result: TrialResult)` — emite resultado al finalizar
  - Tienen pantallas de título y fin integradas
  - Soportan fade-in/out y sistema anti-spam
- **Arquitectura de trials**:
  - Cada blueprint tiene `trial_sequence: Array[TrialResource]`
  - `TrialResource` contiene: `trial_id`, `display_name`, `minigame_id`, `minigame_scene`, `config`, `min_score`
  - Configs específicas: `ForgeTrialConfig`, `HammerTrialConfig`, `SewTrialConfig`, `QuenchTrialConfig`
  - `TrialResult` devuelve: `score`, `grade`, `quality_label`, `normalized_score`
- UI: minimal, legible, sin fuentes custom. Nada de dependencias de AssetLib.
- Input: teclado y ratón; accesos rápidos: Espacio confirma en minijuegos.
- Persistencia temporal: `DataManager` en memoria durante la run; nada de escribir a disco salvo Telemetry.
- Export objetivo: Desktop. No metas plataformas móviles.

## Loop y escenas core
- `Main.tscn` orquesta: muestra HUD, corredor y gestiona transición de salas.
- `Room.tscn` resuelve combates del héroe con 1 grupo. Sin pathfinding complejo.
- El **héroe** avanza solo; al morir, respawn en Sala 1 tras 3 s.
- Tras 8 salas, spawnea **Jefe**; victoria termina la run.

## Crafting y minijuegos
- `CraftingManager` mantiene **cola de trials**, inicia scenes de minijuegos y procesa resultados.
- `HUDMinigameLauncher` (`HUD_Forge.tscn`) gestiona el flujo:
  - Lanza trials desde blueprints en `MinigameContainer`
  - Procesa resultados con `TrialResult`
  - Actualiza UI de cola y blueprints
- Minijuegos MVP implementados:
  1) **Forja (ForgeTemp)**: cursor senoidal de temperatura; 3 aciertos en zona target.  
  2) **Martillo (HammerMinigame)**: timing de golpes; precisión en ventanas temporales.  
  3) **Coser (SewOSU)**: anillos colapsantes tipo OSU; 8 eventos; media ≥ Bien concede bonus.  
  4) **Agua (QuenchWater)**: suelta en ventana óptima; catalizador amplía ventana +20%.
- Sistema de calificación consistente:
  - `Perfect` (>90% ventana perfecta)
  - `Bien` (>70% ventana buena)
  - `Regular` (>40% ventana regular)
  - `Miss` (fuera de ventana o sin input)
- **Difficulty presets**: `MinigameDifficultyPreset.gd` genera configs balanceadas por blueprint.

## Estilo de respuesta que espero de Copilot
- **Idioma**: español técnico. **Salida**: snippet listo para pegar, con **ruta** y **archivo** destino al inicio.
- Cambios en **parches pequeños**: si algo afecta a varias escenas, devuelve un listado de diffs por archivo.
- **INDENTACIÓN CON TABS**: Godot 4.5.1 usa **tabs exclusivamente**. Nunca uses espacios. No mezcles tabs y espacios bajo ninguna circunstancia.
- No propongas reestructurar el proyecto. Trabaja con lo que hay.
- Al generar código, respeta la estructura existente y los nombres de archivos reales.

## No hagas (hard limits)
- Nada de plugins, paquetes de terceros ni migración de versión de Godot.
- No añadas sistemas de ECS, jobs o “task runners” inventados.
- No muevas autoloads ni renombres rutas existentes.
- No uses `res://` para escribir archivos en runtime; usa `user://` para Telemetry.

## Calidad y pruebas
- Cada PR feature debe incluir: 1) scene nueva o script editado, 2) acceso desde `Main.tscn` o botón oculto de debug.
- Log mínimo desde `TelemetryManager`: `{ event, data }` en `user://telemetry.log`.
- FPS objetivo 60; no utilices `await` encadenados largos si generan stutter.

## Checklists rápidas
- [ ] El código es GDScript y referencia rutas `res://...` reales.
- [ ] Los autoloads declarados existen y se usan, no se añaden nuevos.
- [ ] Un minijuego expone `start_trial(config)` y emite `trial_completed(result)`.
- [ ] No hay dependencias externas ni cambios al engine.
- [ ] El héroe sigue el loop: salas → jefe; respawn correcto.
- [ ] **CRÍTICO**: El código usa **tabs** para indentación, nunca espacios, y no mezcla ambos.

## Pitfalls frecuentes
- Escribir en `res://` en runtime. Usa `user://`.
- Minijuegos sin API común. Estandariza extendiendo `MinigameBase` con `start_trial`/`trial_completed`.
- Señales no desconectadas y quedan escuchas colgantes en escenas recargadas.
- Fugas por timers manuales: usa `await get_tree().create_timer(...)` cuando aporte claridad.
- **Usar espacios en lugar de tabs**: Godot 4.5 no acepta código con espacios. Siempre usa tabs.

## Referencias internas
- GDD resumido: `README.md` del repo.
- AutoLoads: `res://scripts/autoload/*.gd` (registrar manualmente en Godot 4.5).
