# 🎬 Sistema de Extracción de Animaciones - PetJam

## Resumen

Sistema completo para extraer fotogramas de videos MP4 y convertirlos en spritesheets para Godot 4.5, con eliminación automática de fondo negro y generación de múltiples variantes de FPS.

---

## 📦 Archivos Generados

### Scripts
- **`scripts/tools/extract_animation_frames.ps1`** - Script principal de extracción
- **`scripts/tools/AnimationTestComparison.gd`** - Lógica de la escena de prueba

### Escenas
- **`scenes/sandboxes/AnimationTestComparison.tscn`** - Comparador visual de FPS

### Output
- **`art/assets/Spritesheets/Hero/`** - Spritesheets generados
- **`art/assets/Spritesheets/temp_frames/`** - Frames individuales (temporal)

---

## 🎯 Prueba Realizada: hero_walk_01.mp4

### ✅ Resultados

Se generaron **4 variantes** del video `hero_walk_01.mp4`:

| FPS | Frames | Tamaño | Archivo |
|-----|--------|--------|---------|
| 8   | 41     | 8.5 MB | `hero_walk_01_8fps.png` |
| 10  | 51     | 10.5 MB | `hero_walk_01_10fps.png` |
| 12  | 62     | 12.6 MB | `hero_walk_01_12fps.png` |
| 15  | 77     | 15.4 MB | `hero_walk_01_15fps.png` |

### ✨ Características

- ✅ **Fondo negro removido** (transparencia total)
- ✅ **Loop perfecto** (primer frame duplicado al final)
- ✅ **4 variantes de FPS** para comparación
- ✅ **Formato spritesheet horizontal** (listo para Godot)

---

## 🚀 Cómo Usar

### 1. Comparar Animaciones Visualmente

**Opción A: Desde el juego (F5)**
```
1. Ejecuta el juego (F5 en Godot)
2. Presiona F5 en el juego → Abre el comparador
```

**Opción B: Directo desde Godot**
```
1. Abre: scenes/sandboxes/AnimationTestComparison.tscn
2. Presiona F5 o F6 para ejecutar la escena
```

### 2. Controles del Comparador

| Tecla | Acción |
|-------|--------|
| **1** | Mostrar solo variante 8 FPS |
| **2** | Mostrar solo variante 10 FPS |
| **3** | Mostrar solo variante 12 FPS |
| **4** | Mostrar solo variante 15 FPS |
| **0** | Mostrar todas las variantes (grid 2x2) |
| **ESPACIO** | Pausar/Reanudar animación |
| **O** | Disminuir velocidad de animación (-0.25x) |
| **P** | Aumentar velocidad de animación (+0.25x) |
| **ESC** | Volver a Main |

**Control de Velocidad:**
- Rango: 0.25x (muy lento) a 3.0x (muy rápido)
- Incrementos de 0.25x por cada tecla presionada
- No afecta `Engine.time_scale`, solo las animaciones
- Útil para comparar detalles en cámara lenta o probar velocidad de juego

### 3. Procesar Más Animaciones

**Extraer una animación específica:**
```powershell
.\scripts\tools\extract_animation_frames.ps1 -InputVideo "art/assets/Animaciones/Hero/Attack/hero_attack_01.mp4"
```

**Cambiar FPS generados:**
```powershell
.\scripts\tools\extract_animation_frames.ps1 `
	-InputVideo "art/assets/Animaciones/Hero/Walk/hero_walk_02.mp4" `
	-FPSVariants @(6, 8, 12, 16)
```

**Procesar sin remover fondo:**
```powershell
.\scripts\tools\extract_animation_frames.ps1 `
	-InputVideo "art/assets/Animaciones/Hero/Death/hero_death.mp4" `
	-RemoveBackground:$false
```

---

## 🎨 Integrar en Godot

### Método 1: AnimatedSprite2D (Recomendado para Spritesheets)

```gdscript
# En Hero.tscn, reemplazar Sprite2D por AnimatedSprite2D

extends CharacterBody2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready():
	# Configurar la animación
	sprite.play("walk")  # Nombre de la animación en SpriteFrames

func _process(delta):
	if velocity.x != 0:
		sprite.play("walk")
	else:
		sprite.play("idle")
```

**Configurar en el Inspector:**
1. Selecciona el nodo `AnimatedSprite2D`
2. En Inspector → `Sprite Frames` → Crear nuevo `SpriteFrames`
3. En el panel SpriteFrames (abajo):
   - Agregar animación "walk"
   - Click en "Add frames from sprite sheet"
   - Seleccionar `hero_walk_01_12fps.png`
   - Configurar: `Horizontal: 62, Vertical: 1`
   - FPS: 12
4. Repetir para otras animaciones (attack, death, etc.)

### Método 2: Sprite2D con Animation (Frames individuales)

```gdscript
# Si prefieres frames separados en lugar de spritesheet

extends Sprite2D

var frames: Array[Texture2D] = []
var current_frame: int = 0
var fps: int = 12
var time_accumulator: float = 0.0

func _ready():
	# Cargar frames individuales
	for i in range(62):  # 62 frames para 12fps
		var frame_path = "res://art/assets/Spritesheets/temp_frames/hero_walk_01/fps_12/frame_%04d.png" % (i + 1)
		frames.append(load(frame_path))
	texture = frames[0]

func _process(delta):
	time_accumulator += delta
	var frame_time = 1.0 / fps
	
	if time_accumulator >= frame_time:
		current_frame = (current_frame + 1) % frames.size()
		texture = frames[current_frame]
		time_accumulator = 0.0
```

---

## 📊 Recomendaciones de FPS

### Para Juego 2D Pixel/Retro
- **8 FPS**: Muy retro, similar a juegos NES/SNES
- **10 FPS**: Balance retro-suave, recomendado para Jam
- **12 FPS**: Estándar animación 2D (Disney usaba 12fps)
- **15 FPS**: Más fluido, para movimientos rápidos

### Para Tu Juego (PetJam)
Basado en el estilo:
- **Caminar**: 10-12 FPS ✅
- **Ataque**: 12-15 FPS (más dinámico)
- **Muerte**: 8-10 FPS (más dramático)

**Prueba en el comparador y decide según tu preferencia visual.**

---

## 🔧 Troubleshooting

### FFmpeg no encontrado
```powershell
# Instalar FFmpeg
winget install Gyan.FFmpeg

# Verificar instalación
ffmpeg -version
```

### Mejorar calidad de transparencia
Si el fondo negro no se remueve bien, ajusta el threshold en el script:

```powershell
# Línea 71 del script
$vfilter += ",colorkey=0x000000:0.1:0.2"
#                        ↑     ↑    ↑
#                    color  similarity blend
```

- **Similarity (0.1)**: Aumentar si quedan pixeles negros (ej: 0.15)
- **Blend (0.2)**: Aumentar para bordes más suaves (ej: 0.3)

### Spritesheets muy grandes
Si los archivos son muy pesados:

**Opción 1: Reducir resolución**
```powershell
# Agregar filtro de escala en el script (línea 71)
$vfilter += ",scale=iw*0.5:ih*0.5"  # Reduce a 50%
```

**Opción 2: Usar menos FPS**
```powershell
-FPSVariants @(8, 10)  # Solo 2 variantes
```

---

## 🎮 Próximos Pasos

1. **Probar en el comparador** (F5 en juego)
2. **Elegir FPS favorito** (recomiendo 10 o 12)
3. **Procesar resto de animaciones**:
   ```powershell
   # Hero
   .\scripts\tools\extract_animation_frames.ps1 -InputVideo "art/assets/Animaciones/Hero/Attack/hero_attack_01.mp4"
   .\scripts\tools\extract_animation_frames.ps1 -InputVideo "art/assets/Animaciones/Hero/Death/hero_death.mp4"
   
   # Enemies
   .\scripts\tools\extract_animation_frames.ps1 -InputVideo "art/assets/Animaciones/Enemies/Attack/grunt_attack.mp4"
   .\scripts\tools\extract_animation_frames.ps1 -InputVideo "art/assets/Animaciones/Enemies/Death/tank_death.mp4"
   ```
4. **Integrar en Hero.tscn y Enemy.tscn** (ver sección "Integrar en Godot")

---

## 📝 Notas Técnicas

### Loop Perfecto
El script **duplica automáticamente el primer frame al final** para asegurar que el loop sea suave. Esto es crítico para animaciones cíclicas como caminar.

### Transparencia
Se usa **colorkey** de FFmpeg para remover el fondo negro:
- Detecta negro puro (0x000000)
- Tolerancia del 10% para capturar variaciones
- Blend del 20% para bordes suaves

### Formato Spritesheet
Los spritesheets son **horizontales** (1 fila, N columnas):
```
[Frame1][Frame2][Frame3]...[FrameN]
```

Esto es óptimo para `AnimatedSprite2D` en Godot con `hframes = N`.

---

## ✨ Estado Actual

✅ **Script funcional y probado**  
✅ **4 variantes generadas de hero_walk_01**  
✅ **Comparador visual implementado**  
✅ **Fondo negro removido correctamente**  
✅ **Loop perfecto garantizado**  

**Todo listo para decidir FPS y procesar el resto de animaciones.**
