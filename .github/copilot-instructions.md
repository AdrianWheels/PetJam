
# Copilot — Instrucciones del proyecto (Godot 4.5 Jam)

## TL;DR
- **Engine**: Godot **4.5** estable. Lenguaje: **GDScript**. 2D minimal.
- **Goal**: Jam MVP. Un corredor con **8 salas + jefe**, héroe en auto‑avance y **4 minijuegos** de crafteo (Forja, Martillo, Coser, Agua).
- **Arquitectura fija**: usa **AutoLoads**: `GameManager`, `DataManager`, `CraftingManager`, `AudioManager`, `TelemetryManager`.
- **Entrega**: todo snippet debe ser **pegable** y referenciar rutas reales `res://...`. Nada de plugins externos ni rework masivo.

---

## Contexto del repo
- El diseño de juego está en `README.md` (GDD resumido). Respétalo.
- Proyecto 2D. No intentes migrar a 3D ni a C#.
- Objetivo de sesión: producir features autocontenidas y probables en ≤90 min.

## Estructura esperada
```
res://
  scenes/            # Main.tscn, HUD, Corridor, CombatRoom
  minigames/         # forge/, hammer/, sew/, quench/
  scripts/
    autoload/        # GameManager.gd, DataManager.gd, CraftingManager.gd, AudioManager.gd, TelemetryManager.gd
    gameplay/        # Hero.gd, Enemy.gd, CombatController.gd
    ui/              # Paneles, HUD
```
- **No** añadas nuevos autoloads. Usa los cinco listados.
- Nombres de archivos `snake_case`. Clases `PascalCase`. Señales `lower_snake_case`.

## AutoLoads (Single­tons)
Registrar en Project → Project Settings → AutoLoad:
- `res://scripts/autoload/GameManager.gd`  (estado de partida, flujo de salas, respawn)
- `res://scripts/autoload/DataManager.gd`  (datos estáticos, tablas de balance, blueprints)
- `res://scripts/autoload/CraftingManager.gd` (cola de crafteo, minijuegos, entrega)
- `res://scripts/autoload/AudioManager.gd`   (bips, sfx cortos, ducking leve)
- `res://scripts/autoload/TelemetryManager.gd` (trazas a `user://telemetry.log`)

## Reglas de implementación
- Escribe **GDScript** idiomático. Señales > polling. `await` en vez de temporizadores manuales cuando cuadre.
- Los minijuegos son **scenes independientes** con API común mínima:
  - `func start(config: Dictionary) -> void`
  - `func get_result() -> Dictionary` devuelve `{ "grade": "Perfect|Bien|Regular|Miss", "score": int }`
  - Deben emitir `finished(result: Dictionary)` al cerrar.
- UI: minimal, legible, sin fuentes custom. Nada de dependencias de AssetLib.
- Input: teclado y ratón; accesos rápidos: Espacio confirma en minijuegos.
- Persistencia temporal: `DataManager` en memoria durante la run; nada de escribir a disco salvo Telemetry.
- Export objetivo: Desktop. No metas plataformas móviles.

## Loop y escenas core
- `Main.tscn` orquesta: muestra HUD, corredor y gestiona transición de salas.
- `CombatRoom.tscn` resuelve combates del héroe con 1 grupo. Sin pathfinding complejo.
- El **héroe** avanza solo; al morir, respawn en Sala 1 tras 3 s.
- Tras 8 salas, spawnea **Jefe**; victoria termina la run.

## Crafting y minijuegos
- `CraftingManager` mantiene **cola (3)**, inicia scenes de minijuegos y agrega resultados a la **calidad** del ítem.
- Minijuegos MVP:
  1) **Forja (temperatura)**: cursor senoidal; 3 aciertos.  
  2) **Martillo (timing)**: 5 golpes a BPM fijo.  
  3) **Coser (OSU)**: anillo + círculo colapsando; 8 eventos; media ≥ Bien concede **Evasión**.  
  4) **Agua (temple)**: suelta en **ventana óptima**; si hay catalizador, ventana +20% y etiqueta “Elemento fijado”.
- Normaliza escalas de “ventanas” y timing dentro de cada scene. Devuelve `grade` consistente.

## Estilo de respuesta que espero de Copilot
- **Idioma**: español técnico. **Salida**: snippet listo para pegar, con **ruta** y **archivo** destino al inicio.
- Cambios en **parches pequeños**: si algo afecta a varias escenas, devuelve un listado de diffs por archivo.
- No propongas reestructurar el proyecto. Trabaja con lo que hay.
- Cuando generes un minijuego, crea la scene completa bajo `res://minigames/<name>/` y cita su `*.tscn` de entrada.

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
- [ ] Un minijuego expone `start(config)` y `finished(result)`.
- [ ] No hay dependencias externas ni cambios al engine.
- [ ] El héroe sigue el loop: salas → jefe; respawn correcto.

## Pitfalls frecuentes
- Escribir en `res://` en runtime. Usa `user://`.
- Minijuegos sin API común. Estandariza `start`/`finished`/`get_result`.
- Señales no desconectadas y quedan escuchas colgantes en escenas recargadas.
- Fugas por timers manuales: usa `await get_tree().create_timer(...)` cuando aporte claridad.

## Referencias internas
- GDD resumido: `README.md` del repo.
- AutoLoads: `res://scripts/autoload/*.gd` (registrar manualmente en Godot 4.5).
