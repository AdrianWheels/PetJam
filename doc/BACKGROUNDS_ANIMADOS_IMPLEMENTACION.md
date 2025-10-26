# Integración de Backgrounds Animados en Minijuegos (SPRITESHEET)
**Fecha**: 26 octubre 2025  
**Objetivo**: Añadir backgrounds animados desde MP4 usando **spritesheets únicos** (mucho más eficiente)

---

## ✅ Completado

### 1. Extracción y Generación de Spritesheets
Se extrajeron 3 videos y se generaron **spritesheets horizontales únicos** (24 FPS):

- **heat_background.mp4** → `res://art/assets/Spritesheets/Other/heat_background_24fps.png` (127 frames, ~95 MB)
- **steel_bar_background.mp4** → `res://art/assets/Spritesheets/Other/steel_bar_background_24fps.png` (123 frames, ~58 MB)  
- **workshop.webm** → `res://art/assets/Spritesheets/Other/workshop_background_24fps.png` (123 frames, ~14 MB)

**Ventajas del spritesheet único vs frames individuales**:
- ✅ **1 archivo** en lugar de 120+ archivos PNG
- ✅ Carga **instantánea** en memoria (1 textura vs 120+ texturas)
- ✅ Menos operaciones de I/O en disco
- ✅ Mejor para el garbage collector de Godot
- ✅ Más fácil de versionar en Git (1 commit vs 120+)

### 2. Scripts de Animación Optimizados
Se crearon 3 clases GDScript que usan **Sprite2D** con spritesheets:

- `res://scripts/forge/AnimatedHeatBackground.gd` → Para ForgeTemp
- `res://scripts/forge/AnimatedSteelBarBackground.gd` → Para QuenchWater
- `res://scripts/forge/AnimatedWorkshopBackground.gd` → Para Main/ForgeArea

Características:
- Extend `Sprite2D` (NO AnimatedSprite2D)
- Cargan **1 solo spritesheet** via `texture`
- Usan `hframes` para dividir el spritesheet horizontalmente
- Animación manual en `_process()` con acumulador de tiempo
- 24 FPS nativo, loop automático
- **Mucho más eficiente** que cargar frames individuales

### 3. Fix ForgeTemp.tscn
Se arregló la escena `ForgeTemp.tscn` que había perdido la referencia al script `ForgeMinigame.gd`.

---

## 🔨 Pendiente: Editar Escenas en Godot

### A. ForgeTemp.tscn (`res://scenes/Minigames/ForgeTemp.tscn`)

**Objetivo**: Añadir background animado de temperatura desde spritesheet

**Pasos**:
1. Abre `res://scenes/Minigames/ForgeTemp.tscn` en Godot
2. Selecciona el nodo `GameArea`
3. Añade un hijo tipo `Sprite2D` (NO AnimatedSprite2D)
4. Renombra a `AnimatedHeatBackground`
5. Asigna el script: `res://scripts/forge/AnimatedHeatBackground.gd`
6. En Inspector → **Texture**: Arrastra/asigna `res://art/assets/Spritesheets/Other/heat_background_24fps.png`
7. Configura posición:
   - **Centered**: ON (checkbox marcado)
   - **Position**: `Vector2(450, 350)` (centro del GameArea de 900x700)
   - **Scale**: Ajustar según necesidad visual, prueba con `Vector2(0.8, 3)` para stretch vertical
8. **Ordering → Z-Index**: -10 (para que esté detrás de TODO)
9. Mueve el nodo al **principio** de la lista de hijos de GameArea (arrastra hacia arriba)
10. Guarda la escena (Ctrl+S)

**IMPORTANTE**: 
- El script configurará automáticamente `region_enabled = true` y `region_rect` en `_ready()`
- Esto mostrará **solo 1 frame** (1080x125) en lugar del spritesheet completo gigante
- La animación será automática a 24 FPS moviendo la región horizontalmente

---

### B. QuenchWater.tscn (`res://scenes/Minigames/QuenchWater.tscn`)

**Objetivo**: Añadir background animado de steel bar desde spritesheet

**Pasos**:
1. Abre `res://scenes/Minigames/QuenchWater.tscn` en Godot
2. Selecciona el nodo `GameArea`
3. Añade un hijo tipo `Sprite2D` (NO AnimatedSprite2D)
4. Renombra a `AnimatedSteelBarBackground`
5. Asigna el script: `res://scripts/forge/AnimatedSteelBarBackground.gd`
6. En Inspector → **Texture**: Arrastra/asigna `res://art/assets/Spritesheets/Other/steel_bar_background_24fps.png`
7. Configura posición:
   - **Centered**: ON
   - **Position**: `Vector2(450, 350)` (centro del GameArea de 900x700)
   - **Scale**: Ajustar según necesidad visual, prueba con `Vector2(0.8, 3)` para stretch vertical
8. **Ordering → Z-Index**: -10 (para que esté detrás de TODO)
9. Mueve el nodo al **principio** de la lista de hijos de GameArea
10. Guarda la escena (Ctrl+S)

**IMPORTANTE**: 
- El script configurará automáticamente `region_enabled = true` y `region_rect` en `_ready()`
- Esto mostrará **solo 1 frame** (1080x121) en lugar del spritesheet completo
- La animación será automática a 24 FPS

---

### C. Main.tscn - ForgeArea (PENDIENTE DECISIÓN)

**Contexto**: Ya existe un `AnimatedForgeBackground` en `Main.tscn` → `ForgeArea/AnimatedForgeBackground` que usa el sistema viejo de frames individuales.

**Opción 1 - Reemplazar con Workshop Background (RECOMENDADO)**:
1. Abre `res://scenes/Main.tscn` en Godot
2. Selecciona `ForgeArea/AnimatedForgeBackground`
3. Cámbiale el tipo a `Sprite2D` (click derecho → Change Type → Sprite2D)
4. En Inspector → Script: Cambia a `res://scripts/forge/AnimatedWorkshopBackground.gd`
5. En Inspector → **Texture**: Asigna `res://art/assets/Spritesheets/Other/workshop_background_24fps.png`
6. Verifica posición y escala
7. Guarda la escena

**Opción 2 - Crear Nuevo Nodo Workshop**:
Si quieres mantener el background original de forge:
1. Añade un nuevo hijo `Sprite2D` a `ForgeArea`
2. Nómbralo `AnimatedWorkshopBackground`
3. Asigna script `AnimatedWorkshopBackground.gd`
4. Asigna texture del spritesheet
5. Controla visibilidad según necesites

**Nota**: El sistema viejo de `AnimatedForgeBackground.gd` funciona pero es menos eficiente (carga 121 PNGs individuales).

---

## 📊 Información Técnica

### Spritesheets Generados

| Video | Frames | Resolución Frame | Tamaño Archivo | Ubicación |
|-------|--------|-----------------|----------------|-----------|
| heat_background.mp4 | 127 | 1080x125 | ~95 MB | `art/assets/Spritesheets/Other/heat_background_24fps.png` |
| steel_bar_background.mp4 | 123 | 1080x121 | ~58 MB | `art/assets/Spritesheets/Other/steel_bar_background_24fps.png` |
| workshop.webm | 123 | 624x121 | ~14 MB | `art/assets/Spritesheets/Other/workshop_background_24fps.png` |

**Dimensiones de Spritesheet**: `ancho_frame * num_frames` x `altura_frame`
- heat: 137,160 x 125 px
- steel_bar: 132,840 x 121 px
- workshop: 76,752 x 121 px

### Arquitectura de los Scripts (CON REGION)

Todos los scripts usan el mismo patrón eficiente con **Region**:

```gdscript
extends Sprite2D

const SPRITESHEET_PATH := "res://..."
const FRAME_COUNT := 127
const FRAME_WIDTH := 1080  # Ancho de 1 frame
const FRAME_HEIGHT := 125  # Alto de 1 frame
const FPS := 24.0

var _current_frame := 0
var _time_accumulator := 0.0
var _frame_duration := 1.0 / FPS

func _ready() -> void:
	texture = load(SPRITESHEET_PATH)
	
	# CLAVE: Habilitar region para mostrar solo 1 frame
	region_enabled = true
	region_rect = Rect2(0, 0, FRAME_WIDTH, FRAME_HEIGHT)

func _process(delta: float) -> void:
	_time_accumulator += delta
	while _time_accumulator >= _frame_duration:
		_time_accumulator -= _frame_duration
		_current_frame = (_current_frame + 1) % FRAME_COUNT
		
		# Mover la región horizontalmente para el siguiente frame
		region_rect.position.x = _current_frame * FRAME_WIDTH
```

**Cómo funciona Region**:
- `region_enabled = true` → Activa el recorte de región
- `region_rect = Rect2(x, y, w, h)` → Define qué parte del spritesheet mostrar
- Moviendo `region_rect.position.x` avanzamos por los frames horizontalmente
- Solo se dibuja la región visible (1 frame), no el spritesheet completo

**Ventajas**:
- ✅ En editor se ve **tamaño real** del frame (1080x125), no el spritesheet gigante
- ✅ Carga **1 textura única** vs 120+ texturas individuales
- ✅ Animación manual con acumulador de tiempo (precisión perfecta)
- ✅ Loop automático con operador módulo `%`
- ✅ Sin dependencias de AnimatedSprite2D ni SpriteFrames

---

## 🧪 Testing

### Checklist de Verificación

- [ ] **ForgeTemp**: Background animado heat visible y en loop
- [ ] **QuenchWater**: Background animado steel bar visible y en loop
- [ ] **Main/ForgeArea**: Background animado workshop visible y en loop
- [ ] Los controles de UI están **encima** del background (z-index correcto)
- [ ] No hay errores en consola sobre frames faltantes
- [ ] La animación loopea sin saltos visibles
- [ ] El rendimiento es aceptable (60 FPS mantenido)

### Comandos de Testing

```gdscript
# En script de minijuego, para verificar que se carga:
func _ready():
	var bg = $GameArea/AnimatedHeatBackground
	print("Background cargado: ", bg != null)
	print("Animación activa: ", bg.is_playing())
	print("Frames totales: ", bg.sprite_frames.get_frame_count("heat_loop"))
```

---

## 🐛 Troubleshooting

### Error: "No se pudo cargar frame"
- **Causa**: Godot no ha importado los PNG en los nuevos directorios
- **Solución**: 
  1. Abre Godot
  2. Ve a FileSystem → Click derecho en carpeta → "Reimport"
  3. O reinicia Godot para forzar reimport

### Background no se ve
- **Causa**: Z-index incorrecto o posición fuera de pantalla
- **Solución**: 
  - Verifica Z-Index = -1
  - Verifica Position centrada en GameArea
  - Verifica que el nodo AnimatedSprite2D esté activo (visible)

### Animación muy lenta/rápida
- **Causa**: `frame_skip` incorrecto o FPS mal ajustado
- **Solución**:
  - Ajusta `frame_skip` en Inspector (1-10)
  - Menor valor = más frames = más rápido

### Saltos en el loop
- **Causa**: Primer y último frame no coinciden perfectamente
- **Solución**: El script ya duplica el primer frame, pero si persiste:
  - Revisar que el video original tenga buen loop
  - Aumentar `frame_skip` para reducir visibilidad de saltos

---

## 📝 Notas Adicionales

- Los frames originales están en `art/assets/Spritesheets/temp_frames/` pero se copiaron a `art/placeholders/` para mantener consistencia con el patrón existente
- Si quieres cambiar la resolución o calidad, re-extrae con el script de PowerShell `extract_animation_frames.ps1`
- Formato de nombres de frame: `frame_0001.png`, `frame_0002.png`, etc. (4 dígitos con padding)
- **TABS**: Los scripts creados usan tabs para indentación (Godot 4.5 estándar)

---

## ✨ Siguiente Paso

**AHORA**: Abre Godot y aplica los cambios en las 3 escenas siguiendo las instrucciones de este documento.

Una vez completado, verifica que:
1. Los 3 backgrounds animen correctamente
2. No hay errores en consola
3. El gameplay de los minijuegos no se ve afectado
4. Los frames se cargan y reproducen en loop
