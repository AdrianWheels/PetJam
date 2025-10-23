
---
applyTo: "**"
---
# Logger — Godot 4.5 (Reglas para Copilot)

## Objetivo
Establecer un **logger** consistente y ligero con escritura en `user://logs/` y salida opcional a consola. Evitar bloqueos de frame usando **buffer + flush periódico**. Todo en **GDScript** y como **AutoLoad** único `Logger`.

## Reglas
- Escriturar únicamente en `user://logs/`. Nunca escribir en `res://` durante runtime.
- Niveles soportados: `DEBUG`, `INFO`, `WARN`, `ERROR`.
- Formato de línea: `YYYY-MM-DD HH:MM:SS [LEVEL] mensaje {json_context_opcional}`
- Salida opcional a consola: `print` para INFO/DEBUG, `push_warning` para WARN, `push_error` para ERROR.
- Flush mediante `Timer` cada `flush_interval_ms` (default 250 ms). Buffer interno para minimizar IO.
- Rotación por **fecha + tamaño**: archivo `user://logs/app-YYYYMMDD.log`, si supera `max_size_kb`, continuar en `app-YYYYMMDD-1.log`, `-2.log`, etc.
- API estable del autoload `Logger` (ver contrato). No crear más autoloads.

## Autoload `Logger`
Crear `res://scripts/autoload/Logger.gd` y registrarlo en Project → Project Settings → AutoLoad como **Logger**.

### Contrato de API (obligatorio)
```gdscript
# res://scripts/autoload/Logger.gd
extends Node
class_name Logger

enum Level { DEBUG, INFO, WARN, ERROR }

var level:int
var to_file:bool
var to_stdout:bool
var flush_interval_ms:int
var max_size_kb:int

func set_level(new_level:int) -> void
func debug(msg:String, ctx:Dictionary = {}) -> void
func info(msg:String, ctx:Dictionary = {}) -> void
func warn(msg:String, ctx:Dictionary = {}) -> void
func error(msg:String, ctx:Dictionary = {}) -> void
func trace(event:String, data:Dictionary = {}, lvl:int = Level.INFO) -> void  # JSON-line
func flush_now() -> void
```

### Uso esperado
```gdscript
Logger.info("Run started", {"seed": randi()})
Logger.debug("Player stats", {"hp": 42, "agi": 7})
Logger.warn("Low FPS", {"fps": Engine.get_frames_per_second()})
Logger.error("Boss script failed", {"room": 8})
Logger.trace("craft_result", {"item":"sword_1","grade":"Bien"})
```

## Project Settings (sugeridos)
Definir claves opcionales para controlar el logger sin tocar código:
```
application/log/level = 1            # 0 DEBUG, 1 INFO, 2 WARN, 3 ERROR
application/log/to_file = true
application/log/to_stdout = true
application/log/flush_interval_ms = 250
application/log/max_size_kb = 512
```
Copilot debe leer estos valores con `ProjectSettings.get_setting(...)` y aplicar defaults si no existen.

## Exportación
- Los logs se generan en `user://logs/`. No exportar ni versionar esos archivos.
- Verificar con `ProjectSettings.globalize_path("user://logs")` la ruta real en cada plataforma.

## Calidad y rendimiento
- No bloquear el hilo principal con escrituras sin buffer.
- Evitar concatenaciones costosas en bucles; reutilizar strings cuando sea viable.
- Llamar a `flush_now()` en `_notification(WM_CLOSE_REQUEST)` si se requiere asegurar volcado final.

## Aceptación (debe cumplirse)
- Existe autoload `Logger` con el contrato de API anterior.
- El logger escribe en `user://logs/` y rota por tamaño y fecha.
- Loggea en consola según el nivel y no contamina con spam en `ERROR`.
- `trace(event, data)` produce **JSON-line** por registro para telemetría simple.
- Snippets entregados por Copilot son pegables y respetan rutas `res://...`/`user://...`.

## Pitfalls comunes
- Escribir en `res://` durante export. Prohibido.
- No rotar y terminar con archivos de 50 MB. Fija `max_size_kb`.
- Olvidar `flush` al salir en sesiones largas.
