# Posibles problemas y mejoras sugeridas

## Visión general
- El proyecto mantiene versiones duplicadas y obsoletas de varios sistemas (combate, partículas, gestor de salas) que chocan con la implementación actual basada en escenas `CharacterBody2D`, generando llamadas rotas y mantenimiento difícil.
- Numerosos scripts incluyen lógica de depuración intrusiva (impresiones, escrituras a disco, timers desechables) que impactan el rendimiento y complican seguir el flujo de juego real.
- Tras el último merge, el HUD busca texturas específicas por material; `MaterialIcon.gd` introduce un setter recursivo y lecturas en disco repetidas para cada material desconocido.

## Autoloads
### AudioManager
- `duck_music` resta el volumen actual y lo vuelve a sumar más tarde; varias llamadas apiladas degradan progresivamente el volumen real y dejan timers sueltos en el árbol.
- **Sugerencia**: almacenar el volumen objetivo en una variable y reutilizar un único `Timer` o `Tween` para restaurarlo.

### CraftingManager
- En `_ready` llena los tres huecos con recetas por defecto y dispara señales inmediatamente, lo que causa que HUD y minijuegos arranquen antes de que el jugador intervenga.
- `_start_next_trial` asume que cada `BlueprintResource` tiene una secuencia válida; al encontrar `null` vuelve a llamarse de forma recursiva y puede saltarse pruebas sin registrar el fallo.
- El cálculo final de la nota usa `score_accumulated / max_score_accumulated` sin validar divisiones por cero ni normalizar por número de pruebas, generando rangos inconsistentes para recetas con pocas pruebas.
- **Sugerencia**: introducir una cola real con estados persistentes, validar recursos antes de iniciar la prueba y convertir el cálculo de grado en un helper reutilizable que acepte pesos por prueba.

### GameManager
- `start_run` reinicia la mazmorra a la sala 1 cada vez que `main.gd` registra al héroe, aunque el `Corridor` ya haya establecido su propio progreso, duplicando mensajes y dejando estados desincronizados.
- `RoomController` aún invoca `GameManager.win()`, método inexistente; hoy `register_boss_defeat()` es quien emite `boss_defeated`/`game_over`, por lo que el flujo antiguo nunca se cumple.
- **Sugerencia**: eliminar el controlador antiguo o adaptar sus llamadas al nuevo API (`register_boss_defeat`, `register_enemy_defeat`, etc.) y exponer funciones explícitas para “reset run”.

### UIManager
- Al registrar nodos, activa/desactiva `process_mode` de `Corridor` pero no espera a que el árbol esté listo; si `main.gd` invoca `register_nodes` antes de que el héroe exista, el `GameManager` no recibe la referencia y los bonus no se aplican.
- `present_delivery` resuelve el `BlueprintResource` cada vez desde `DataManager`, implicando IO y posibles `null` si el recurso fue descargado; conviene cachear la referencia que ya viene en el `payload` del CraftingManager.
- **Sugerencia**: introducir colas diferidas (`call_deferred`) para la inscripción inicial y cachear las referencias a blueprint e iconos.

### DataManager
- `_load_json_file` prueba múltiples rutas, escribe logs extensos a disco y vuelve a parsear el JSON aunque ya haya fallado, ralentizando el arranque y produciendo ruido cuando los archivos no existen en `user://`.
- **Sugerencia**: limitarse a `res://`/`user://`, usar `JSON.parse_string` una sola vez y registrar errores con el `Logger` sin volcar archivos manualmente salvo en modo debug.

### TelemetryManager y Logger
- `TelemetryManager.log_event` abre y reescribe un archivo por cada evento; en hardware lento bloqueará el hilo principal. Centralizar la escritura usando el `Logger` o un `FileAccess` persistente.
- `Logger.flush_now` reabre el fichero cada vez y mezcla salidas estándar con `push_error/push_warning`, duplicando mensajes en consola.
- **Sugerencia**: usar colas en memoria y un hilo/timer dedicado a flush con tamaño máximo configurable.

### InventoryManager
- Funcional pero podría validar acumulaciones negativas; ahora cualquier llamada con `quantity < 0` no hace nada, ocultando bugs.
- **Sugerencia**: añadir un flujo explícito para retirar ítems y registrar cambios.

## Gameplay y núcleo
- `scripts/core` mantiene versiones “de prototipo” del héroe, enemigo, combate y partículas que no coinciden con las escenas reales (`CharacterBody2D`). Estas versiones carecen de señales y propiedades usadas por el HUD; deberían eliminarse o migrarse a `scripts/gameplay` para evitar confusión.
- `ParticleManager.gd` existe dos veces (en raíz y en `core`) con el mismo código; unificarlo como recurso compartido y exponerlo vía autoload.
- `Corridor.spawn_enemy` requiere que el nodo `Enemy` ya exista en escena; si se instancia después, la función retorna sin efecto y la partida queda bloqueada. Conviene instanciar la escena desde `PackedScene` o emitir una señal que gestione el spawn.
- `Corridor.reset_room(true)` fuerza nivel 1 aunque `GameManager` reporta sala >1; la lógica de progreso debe venir del autoload para mantener sincronía.
- `HUDMinigameLauncher` depende de rutas de nodos frágiles y carga escenas fallback aunque ya vienen en el `TrialConfig`. Extraer esa lógica a un mapa configurable y usar `NodePath` exportables.

## UI y HUD
- `BlueprintQueueSlot` convierte los ids a `String`, pero su `MaterialIcon` puede entrar en bucle infinito porque el setter vuelve a escribir la misma propiedad; crear un campo privado (`_material_name`) para evitar recursión.
- `DeliveryPanel` y `ResultPanel` invocan `Logger` condicionalmente; si el autoload no existe, el flujo sigue silenciosamente. Estandarizar una capa de logging para evitar `has_node` repetidos.
- `DungeonStatus.update_combat_info` asume que héroe y enemigo exponen `expected_dps`; si llega la versión “core” sin este método, la UI se rompe. Añadir comprobaciones de tipo o usar interfaces.
- `MinigameBase` fuerza `hud._set_forge_panels_visible(true)` si encuentra el HUD como hijo directo del padre, acoplando jerarquía. Usar señales (`minigame_closed`) que escuche el HUD.

## Minijuegos
- **ForgeMinigame**: ajusta `_progress` con `delta`, pero nunca resetea `closing` ni bloquea entradas tras el final; tras completar una vez, clics extra reabren el panel. Añadir flag de estado y desconectar `input` al cerrar.
- **HammerMinigame**: replica lógica de ritmo en diccionarios; faltan señales de audio y feedback visual (usa `print`). Extraer la simulación a una clase reutilizable y emitir señales.
- **QuenchMinigame**: evalúa resultados en caliente pero guarda `bp` como `null` si alguien llama `start_game` antes de `start_trial`. Validar `bp` y evitar duplicar el resumen en `setup_end_screen`.
- **SewMinigame**: múltiples variables globales (`state`, `running`, `paused`) podrían agruparse; la colisión de tiempo usa `INTER_NOTE_MS` fijo. Parametrizar por dificultad e introducir señales de progreso.
- **TempMinigame**: resetea `freq_hz` y `phase`, pero no detiene `_process` tras `finish`; la animación sigue corriendo. Añadir `set_process(false)` y evitar puntuaciones negativas tras fallos consecutivos.

## Scripts de datos
- `BlueprintResource.get_icon` recarga la textura cada vez si no hay caché; con las rutas movidas a listas de petición conviene precargar iconos en `DataManager` y servir referencias compartidas.
- `TrialResource` añadió `notes`, pero ningún consumidor lo usa. Decidir si se mostrará en UI o eliminarlo.
- `TrialConfig.duplicate_config` crea copias profundas pero `CraftingManager` vuelve a duplicar al lanzar la prueba; centralizar la duplicación en un solo lugar.

## Cambios recientes respecto al estado anterior
- La migración de `MaterialIcon` a un diccionario de texturas permite reemplazar placeholders, pero el setter recursivo y la carga dinámica pueden causar bloqueos y microparones si se piden materiales nuevos en cadena.
- `BlueprintQueueSlot` ahora fuerza los ids a `String`, corrigiendo el problema de `StringName` → textura; sigue limpiando el contenedor completo cada actualización, provocando recreación constante de nodos. Considera reciclar filas o usar `Control` reutilizable.
- `TrialResource` añadió `notes`, lo que exige actualizar cualquier UI que muestre la configuración de la prueba para evitar referencias vacías.

## Recomendaciones clave
1. **Depurar y podar duplicados**: eliminar los scripts del paquete `scripts/core` que ya tienen equivalentes en `scripts/gameplay`, y centralizar `ParticleManager` como recurso compartido.
2. **Refactorizar autoloads**: simplificar `DataManager`, `AudioManager` y `TelemetryManager` para reducir IO y dependencias circulares; adoptar colas/tareas diferidas en lugar de timers anónimos.
3. **Robustecer Crafting/Minijuegos**: añadir validaciones de recursos, normalizar el cálculo de notas y usar señales tipadas para comunicar resultados, evitando acceso directo a HUD y GameManager.
4. **Optimizar HUD/Materiales**: corregir el setter de `MaterialIcon`, cachear iconos en memoria y actualizar el HUD sin recrear nodos cada tick.
