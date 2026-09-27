# PetJam — FAQ del Proyecto

> Documento generado a partir de una batería exhaustiva de preguntas y respuestas sobre el proyecto.  
> **Última actualización**: 2026-02-07

---

## A — Diseño de juego y visión

### A1. ¿Cuál es el pitch del juego?
Eres un herrero que craftea equipo en tiempo real via minijuegos mientras un héroe IA lucha indefinidamente en una dungeon endless. El héroe muere una y otra vez y tú lo mejoras con equipo para que pueda avanzar más lejos. Es un juego idle/casual para móvil, estilo Candy Crush en cuanto a patrón de sesión.

### A2. ¿Hay condición de victoria o derrota?
**No.** El juego es infinito. El héroe pelea sin parar y los niveles escalan infinitamente. No hay game over, muertes máximas ni boss final que termine la partida. El objetivo es llegar lo más lejos posible (leaderboard).

### A3. ¿Cuántas salas tiene la dungeon?
**Infinitas.** Es un modo endless. El héroe avanza nivel tras nivel sin límite. Se contempla un leaderboard basado en el nivel máximo alcanzado.

### A4. ¿Qué pasa cuando el héroe muere?
Resetea al nivel 1 de enemigos **con todo su equipo intacto**. No pierde items. No hay checkpoints.

### A5. ¿Existe progresión permanente?
Solo existe una "partida" continua. La progresión es el equipo que le des al héroe y las mejoras de la armería. No hay sistema de "runs" ni reinicios totales.

### A6. ¿Qué features del README original están vigentes?
| Feature | Estado |
|---------|--------|
| Consumibles (pociones) | Pendiente — se comprarán con oro en la tienda |
| Infusiones elementales | Pendiente — drops enemigos → dificultad extra → encantamiento |
| Medidor de Forjamagia | Pendiente — siempre visible durante crafteo |
| Heat system + Crit Craft | Pendiente — debe implementarse |
| Entrega QTE | **DEPRECADO** — entrega instantánea por botón |
| MAX_DEATHS / game over | **DEPRECADO** — no hay límite de muertes |
| 8 salas + boss final | **DEPRECADO** — es endless infinito |
| Dual-context forja/dungeon | **DEPRECADO** — todo en una pantalla |

### A7. ¿Cuánto dura una "partida"?
No hay partidas definidas. El jugador juega tantos minijuegos como quiera en cada sesión. El héroe sigue luchando en segundo plano, incluso con la app cerrada (cálculos offline pendientes de implementar).

### A8. ¿Se puede perder un minijuego?
**No.** Siempre se produce un resultado. La calidad mínima es 1%. No hay fallo total.

### A9. ¿Los requests tienen penalización si se ignoran?
De momento no. Los requests dan dirección al crafteo pero ignorarlos no tiene consecuencia negativa.

### A10. ¿Los minijuegos escalan en dificultad?
**Sí.** A medida que se craftean items de mayor nivel, los minijuegos son más rápidos, tienen más eventos y ventanas de timing más estrechas. La dificultad viene parametrizada por el blueprint.

---

## B — Arquitectura y flujo técnico

### B1. ¿Cuál es el flujo de escenas?
```
StartScreen.tscn → Main.tscn (pantalla principal única)
```
Solo dos escenas en el flujo. Main.tscn usa HUD_Main.tscn que contiene el layout unificado: héroe en SubViewport arriba (25%), minijuegos en SubViewport centro (50%), y controles abajo (25%). No hay pantalla de Game Over ni créditos.

### B2. ¿Estructura de Main.tscn?
Main.tscn es un bootstrap simple con `main.gd`. Tiene un HUDLayer (CanvasLayer) con `HUD_Main.tscn` instanciado, y un FadeLayer para transiciones. `HUDMain.gd` gestiona todo: Corridor en SubViewport, minijuegos, requests, blueprints y equipment.

### B3. ¿El Corridor se crea y destruye?
**No.** El Corridor se instancia una vez y persiste siempre. No hay "runs" que lo reinicien. Para resetear progresión completa se necesitará un botón "borrar todos los datos".

### B4. ¿Cómo comunican la Forja y la Dungeon?
No hay dos contextos separados. Todo se ejecuta en la misma pantalla a la vez. La comunicación es via los autoloads compartidos (GameManager, CraftingManager, InventoryManager). El sistema deprecado `switch_area()` ya no se usa.

### B5. Responsabilidades de cada AutoLoad

| AutoLoad | Responsabilidad actual | Notas |
|----------|----------------------|-------|
| **GameManager** | Estado global, nivel enemigos, respawn, loadout héroe, desbloqueo blueprints | Gestiona muertes y reseteo a nivel 1. Tiene `MAX_DEATHS=50` que habría que eliminar |
| **DataManager** | Carga `BlueprintLibrary.tres`, catálogo de blueprints, estado de unlock, resolución de ItemResource | Emite `data_ready`. Solo lectura en su mayoría, podría necesitar mutabilidad para persistencia |
| **InventoryManager** | Materiales (add/consume), items crafteados, equipment slots (7 slots), cálculo stats totales | Todo en memoria. Persiste entre muertes del héroe. No hay save/load a disco aún |
| **CraftingManager** | Cola de 5 slots, secuenciador de trials, scoring, calidad final | Debe estar bien separado de RequestManager (son sistemas distintos) |
| **DebugManager** | Logging por categorías, botón de toggle | Ya no hay escenas separadas, debería unificarse |
| **AudioManager** | SFX y música | El dual-context FORGE/DUNGEON está deprecado. Todo funciona en un solo contexto |
| **TelemetryManager** | Logs JSON a `user://telemetry.log` | De momento no loguea eventos de gameplay |
| **UIManager** | Gestión de paneles, delivery, registro de nodos | El area switching ya no es necesario |
| **RequestManager** | Generación de pedidos por timer (3-8s), máx 4 activos, validación materiales | A futuro: eventos prefijados para narrativa |

### B6. ¿Hay diagrama de señales entre autoloads?
```
DataManager ──(data_ready)──→ RequestsManager, CraftingManager
        │
        └── get_blueprint() ←── GameManager (unlock)
                            ←── CraftingManager (resolve)
                            ←── RequestsManager (generate)

RequestsManager ──(request_accepted)──→ CraftingManager.enqueue()
        │                              InventoryManager.consume_materials()
        └──(requests_refreshed)──→ UI

CraftingManager ──(task_completed)──→ InventoryManager.add_crafted_item()
        │                           UIManager (delivery)
        └──(task_started/updated)──→ UI

GameManager ──(enemy_defeated_first_time)──→ DataManager.unlock_blueprint()
        │── (hero_died)──→ Corridor reset
        └── (hero_loadout_changed)──→ UI

InventoryManager ──(inventory_changed)──→ UI
                 ──(crafted_items_changed)──→ UI
```

### B7. ¿Cómo es el ciclo de vida de un minijuego?
1. `HUDMinigameLauncher` obtiene el trial actual de `CraftingManager`
2. Instancia la escena del minijuego dentro de `MinigameContainer`
3. Llama a `minigame.start_trial(config)` (la config viene del `TrialResource`)
4. El jugador juega. El minijuego emite `trial_completed(result)`
5. `HUDMinigameLauncher` recoge el resultado y lo pasa a `CraftingManager.report_trial_result()`
6. Si quedan trials → siguiente minijuego. Si no → finalización con pantalla de resultado
7. El minijuego se destruye via `queue_free()` (con fade-out)

### B8. ¿Room.tscn está obsoleto?
**Sí.** Es un vestigio del diseño original de 8 salas + boss. El corredor endless no lo usa. Eliminable.

---

## C — Sistema de combate y dungeon

### C1. ¿Cómo funciona el combate actual?
Sistema **cooldown-based**: Hero y Enemy se representan como formas geométricas (`_draw()` con pentágono/diamante/hexágono). Cuando el timer de ataque llega a 0, emiten `attack_triggered` y el `CombatController` aplica daño. Feedback visual por color flash (blanco al atacar, rojo al recibir daño). Sin dependencia de spritesheets.

### C2. ¿Cómo se calculan las stats?
- **Héroe**: stats base + suma de stats de items equipados (7 slots). `InventoryManager.calculate_total_stats()` hace el cálculo.
- **Enemigos**: necesitan fórmulas de escalado exponencial por nivel (pendiente). Actualmente escalado básico.

### C3. ¿Hay tipos de daño?
**Pendiente.** Se planea un sistema tipo Warcraft 3:
- **Armaduras**: fortificada, pesada, ligera, héroe, divina
- **Tipos de daño**: siege, perforante, cortante, caos
- Cada combinación tiene un multiplicador de efectividad.

### C4. ¿Qué dropean los enemigos?
- **Blueprints**: al eliminar un tipo de enemigo por primera vez (desbloqueo automático)
- **Infusiones elementales**: drops que al pulsarlos el jugador los recoge. Añaden dificultad a las recetas pero encantamientos al arma
- Los enemigos **no dropean materiales** comunes. Los materiales se obtienen por la tienda (oro).

### C5. ¿Los bosses tienen mecánicas especiales?
Stats multiplicadas + una pasiva de un pool predefinido. Cuando se agotan las pasivas del pool → combinaciones de 2 pasivas. Cuando se agotan las combinaciones de 2 → 3 pasivas, etc. Escalado combinatorio infinito.

### C6. ¿Qué animaciones tiene el héroe?
IDLE, WALK, ATTACK, DEATH via spritesheets (14 strips). **Se planea simplificar a formas geométricas**, eliminando la complejidad de spritesheets y usando ataques por cooldown.

### C7. ¿El parallax del corredor afecta gameplay?
**No.** Es puramente visual para dar sensación de avance del héroe.

---

## D — Sistema de crafteo

### D1. Flujo completo de crafteo
```
Request aparece → jugador acepta (consume materiales) → se encola (1 de 5 slots)
→ jugador inicia crafteo → trial 1 (minijuego) → trial 2 → ... → trial N
→ finalize → CraftedItem con calidad calculada → jugador equipa al héroe
```
Durante todo el proceso el medidor de **Forjamagia** está activo (pendiente implementar).

### D2. ¿Cuántos trials tiene cada blueprint?
**Varía por blueprint.** Cada blueprint define su propia `trial_sequence` con los minijuegos y configuraciones específicas. Un blueprint simple puede tener 2 trials, uno complejo puede tener 6+.

### D3. ¿Cómo se calcula la calidad final?
Puntuación total acumulada de todos los trials / puntuación máxima posible del blueprint. Si el blueprint tiene 2 trials con máximo 50 puntos cada uno (100 total) y el jugador saca 80, la calidad es 80%. A más trials, más secuencias hay que acertar.

### D4. ¿Los materiales afectan al tipo de prueba?
**Sí.** Metal pasa por la prueba de forja. Telas/cueros pasan por la de coser. Un blueprint puede combinar varios tipos de materiales y por tanto varias pruebas distintas.

### D5. ¿Los grados son consistentes entre minijuegos?
Deben serlo. Thresholds actuales en código:
- `Perfect`: > 90%
- `Bien`: > 70%
- `Regular`: > 40%
- `Miss`: < 40% o sin input

### D6. ¿Cómo se entrega un item al héroe?
**Instantáneo.** Hay un botón que abre el panel de equipamiento (EquipmentPanel) donde el jugador puede arrastrar/pulsar para equipar items en los 7 slots del héroe.

### D7. ¿Equipment slots del héroe?
| Slot | Tipo |
|------|------|
| `main_hand` | Arma principal |
| `off_hand` | Escudo / arma secundaria |
| `helmet` | Casco |
| `chest` | Armadura de torso |
| `boots` | Botas |
| `trinket_1` | Abalorio 1 |
| `trinket_2` | Abalorio 2 |

### D8. ¿Se puede reemplazar un item equipado?
Sí. Al reemplazar un item **el anterior se pierde**. No vuelve al inventario.

---

## E — Minijuegos

### E1. ¿Cada minijuego tiene config tipada?
Sí: `ForgeTrialConfig`, `HammerTrialConfig`, `SewTrialConfig`, `QuenchTrialConfig`. Parámetros como velocidad, punto dulce, cantidad de eventos, ventanas de timing son configurables por blueprint/dificultad.

### E2. Forge (ForgeTemp)
Timing puro. Un cursor se mueve en patrón senoidal. El jugador debe hacer tap cuando el cursor está en la zona target. Varios aciertos necesarios por trial.

### E3. Hammer (HammerMinigame)
Rhythm game. Notas se acercan y el jugador hace tap en el momento correcto. La **cantidad de notas es parametrizable** y varía por blueprint/dificultad.

### E4. Sew (SewOSU)
Timing con patrones predefinidos. Tiene posiciones predefinidas para generar patrones de cosido. **Se planea simplificar** eliminando el click en puntos específicos y convirtiéndolo en prueba de timing puro.

### E5. Quench (QuenchWater)
Hold & release. El jugador **pulsa y mantiene** mientras la temperatura baja. Debe **soltar** en la ventana óptima. Tiene sus propios parámetros de dificultad.

### E6. ¿Pantallas de título y fin?
- **Título**: Sí, solo texto animado (ej: "Hammer Time!") que se desvanece suavemente.
- **Fin por trial**: No hay pantalla de fin por trial individual.
- **Fin de todo el crafteo**: Al completar TODOS los trials del blueprint → pantalla de resultado con barra de calidad vertical animada (feature visualmente potente, pendiente).

### E7. ¿Hay sistema anti-spam?
Existe en `MinigameBase` (cooldown 150ms + burst detection). El input es **touch** porque es juego Android. El ratón se usa solo para testing en desktop.

### E8. ¿La dificultad se genera automáticamente?
Actualmente se edita a mano los `TrialConfig`. Se planea un sistema de cálculo automático de dificultad.

---

## F — Interfaz de usuario

### F1. ¿Cuál es la resolución target?
**1080x1920** (portrait 9:16) para móvil Android. Stretch mode: `canvas_items`, aspect: `keep_width`.

### F2. Layout del HUD principal
```
┌─────────────────────────────────┐ 0px
│  HÉROE LUCHANDO + HP encima    │  25%  (480px)
│  Muertes centradas arriba      │
├─────────────────────────────────┤ 480px
│                                 │
│  ZONA IDLE / MINIJUEGOS        │  50%  (960px)
│  (MinigameContainer)           │
│                                 │
├──────────────────┬──────────────┤ 1440px
│ REQUESTS ACTIVOS │ BOTONES:     │  25%  (480px)
│ (cola pedidos)   │ · Blueprints │
│                  │ · Inventario │
│                  │ · Tienda     │
└──────────────────┴──────────────┘ 1920px
      70%               30%
```

### F3. ¿Qué muestra DungeonStatus.tscn?
Debería **unificarse** con la escena del héroe. La vida del héroe aparece encima de él. Las muertes totales centradas arriba. No hay "nivel de héroe" como tal, solo nivel de enemigo.

### F4. ¿Cómo funciona MinigameContainer?
Es un contenedor con un shader (`circular_mask.gdshader`) que oculta los bordes para una apariencia más suave. Los minijuegos se instancian dentro de él.

### F5. ¿BlueprintLibraryPanel muestra blueprints bloqueados?
**Sí.** Los bloqueados aparecen con candado y en escala de grises hasta que se desbloquean. Los desbloqueados son seleccionables.

### F6. ¿Cómo funciona el panel de equipamiento?
Un botón abre un modal (EquipmentPanel) donde se ven los 7 slots del héroe y los items crafteados. El jugador puede equipar items al héroe cuando quiera. **Actualmente WIP** — muchas funciones no están conectadas (ej: actualizar stats del héroe al equipar).

### F7. ¿Controles soportados?
- **Principal**: Touch (Android)
- **Testing**: Ratón (desktop)
- **No se necesita**: teclado, gamepad ni hover

### F8. ¿UIManager gestiona todos los paneles?
Debería registrar y controlar todos los paneles con un sistema robusto. Actualmente gestiona: delivery panel, item info panel, dungeon status, result panel, fade layer.

### F9. ¿EquipmentPanel es funcional?
**WIP.** Visualmente existe pero no actualiza stats del héroe correctamente al equipar items.

---

## G — Audio y efectos

### G1. ¿Cómo funciona el audio?
**Contexto único.** El dual-context FORGE/DUNGEON del diseño original está deprecado. Todo suena a la vez ya que la forja y dungeon están en la misma pantalla. El `AudioManager` tiene 3 contextos (GLOBAL, FORGE, DUNGEON) en código pero deben simplificarse a uno.

### G2. ¿Qué SFX hay por minijuego?
Cada minijuego tiene su propio set de SFX (actualmente `minigame_sounds_default.tres` y `minigame_sounds_hammer.tres`). Además hay SFX comunes para Perfect/Bien/Regular/Miss que son compartidos.

### G3. ¿MinigameAudio y MinigameFX trabajan juntos?
Deberían trabajar juntos. `MinigameAudio` maneja el audio y `MinigameFX` los efectos visuales como partículas y feedbacks.

### G4. ¿Hay voces?
Solo SFX. En el futuro se podría añadir un narrador para tutoriales y explicaciones.

---

## H — Datos y recursos

### H1. Estructura de un BlueprintResource
Campos principales: `trial_sequence` (Array de TrialResource), `materials_required` (Dictionary), `icon`, `equipment_slot`, `stats` (estadísticas del item resultante). Las stats necesitan estar implementadas para aplicarse al héroe.

### H2. ¿ItemResource vs CraftedItem?
- **ItemResource**: template del item (nombre, slot, stats base, tipo)
- **CraftedItem**: instancia concreta con calidad calculada a partir de los resultados de los trials. La calidad modifica el multiplicador de stats.

### H3. ¿Cómo se desbloquean blueprints?
Automáticamente al eliminar un tipo de enemigo por primera vez. `GameManager.register_enemy_defeat()` → `DataManager.unlock_blueprint()`. Blueprints iniciales: `sword_basic`, `shield_basic`, `boots_basic`.

### H4. ¿Por qué 15 blueprints pero 12 ItemResources?
**Faltan 3 ItemResources por crear.** Cada blueprint referencia un `result_item` y esos 3 no tienen su `.tres` correspondiente.

### H5. ¿MaterialResource tiene propiedades especiales?
Los materiales base son nombre + icono + cantidad. Las **infusiones** (fuego, hielo, veneno) son especiales: añaden dificultad extra a las recetas pero otorgan encantamientos a los items resultantes.

---

## I — Convenciones de desarrollo

### I1. Nomenclatura
| Elemento | Convención | Ejemplo |
|----------|-----------|---------|
| Archivos | `snake_case` | `forge_minigame.gd` |
| Clases | `PascalCase` | `ForgeMinigame` |
| Señales | `lower_snake_case` | `trial_completed` |
| Variables privadas | `_prefijo` | `_health` |
| Exports | `@export` | `@export var speed: float` |
| Indentación | **TABS** exclusivamente | — |

### I2. ¿Cómo empezar a trabajar?
1. Clonar el repo
2. Abrir en **Godot 4.5.1**
3. Los 9 autoloads ya están registrados en `project.godot`
4. La escena principal es `StartScreen.tscn` (configurada como `run/main_scene`)
5. Documentación en `doc/`, skills en `.agents/skills/`

### I3. ¿Cómo añadir un nuevo blueprint?
Actualmente se crean `.tres` a mano. Se necesita crear una escena de editor para facilitar la creación de blueprints con buen flujo de trabajo. Hay editor scripts en `addons/editor_scripts/` que ayudan.

### I4. ¿Cómo añadir un nuevo minijuego?
1. Extender `MinigameBase` (`res://scripts/core/MinigameBase.gd`)
2. Implementar `start_trial(config)` llamando `super()` 
3. Emitir `trial_completed(result)` al finalizar
4. Crear escena `.tscn` en `scenes/Minigames/`
5. Crear un `TrialConfig` tipado si tiene parámetros específicos
6. Referenciar la escena en los `TrialResource` de los blueprints que lo utilicen

### I5. ¿Cómo probar un minijuego aislado?
Ejecutando sus escenas individuales (`scenes/Minigames/*.tscn`) directamente. Las escenas sandbox en `scenes/sandboxes/` también sirven. Se necesita un sistema para probar minijuegos con distintos tipos de trials de forma fácil.

### I6. ¿Qué hace DebugManager?
Logging por categorías (forge, dungeon, minigame, audio, crafting, combat). Tiene un botón para activar/desactivar. El prefijo `*` en project.godot indica autorun enabled.

### I7. ¿Flujo de export?
`export_build.ps1` + `export_presets.cfg`. Target es **Android (Google Play)**. Desktop solo para desarrollo y testing.

---

## J — Estado actual y roadmap

### J1. ¿Estado real del proyecto?
**Fundamentos en construcción.** El roadmap previo (Fases 0-2) reflejaba un plan paralelo a la jam. Realmente se está en fase de **crear los fundamentos del juego** y continuar sobre el desarrollo de la JAM. No hay nada "completado" en sentido de producción.

### J2. ¿MainNew.tscn se usa?
**Eliminado.** Su contenido se integró en `Main.tscn`. Ahora Main.tscn usa directamente `HUD_Main.tscn` como layout unificado.

### J3. Features no implementadas para el actual estado

| Feature | Estado | Prioridad |
|---------|--------|-----------|
| Persistencia a disco (save/load) | No implementado | Alta |
| Cálculos offline del héroe | No implementado | Alta |
| Tipos de daño (armadura × daño) | No implementado | Media |
| Pool de pasivas para bosses | No implementado | Media |
| Leaderboard | No implementado | Media |
| Fórmulas escalado infinito | Parcial (básico) | Alta |
| Tienda materiales/pociones | No implementado | Media |
| Infusiones elementales | No implementado | Baja |
| Medidor de Forjamagia | No implementado | Media |
| Heat + Crit Craft | No implementado | Media |
| Simplificar combate a geometría | No implementado | Alta |
| Simplificar Sew a timing | No implementado | Media |
| Pantalla resultado con barra animada | No implementado | Media |
| Export Android | No hecho | Alta |
| Eventos narrativos en RequestManager | No implementado | Baja |
| Items faltantes (3) | No creados | Baja |
| EquipmentPanel funcional | WIP, parcial | Alta |
| Borrar save data (reset) | No implementado | Media |

### J4. Bugs conocidos
Hay bastantes bugs, principalmente relacionados con:
- El héroe y su sistema de sprites/animaciones (que se quiere simplificar a formas geométricas)
- La conexión entre equipar items y actualizar stats del héroe
- Flujos de UI incompletos

### J5. ¿Se ha probado en móvil?
**No.** Ni siquiera se ha compilado para Android. Necesita fundamentos más sólidos primero.

### J6. ¿Plataformas de distribución?
**Google Play** (Android). Esa es la única plataforma objetivo.
