# 🎨 MINIGAME VISUAL THEME - Guía de Diseño

> **Sistema visual estandarizado para los 4 minijuegos de PetJam**  
> Fecha: Octubre 2025 | Engine: Godot 4.5

---

## 📋 Índice

1. [Paleta de Colores](#paleta-de-colores)
2. [Sistema de Feedback](#sistema-de-feedback)
3. [Efectos Visuales](#efectos-visuales)
4. [Sistema de Audio](#sistema-de-audio)
5. [Cómo Añadir Arte](#cómo-añadir-arte)
6. [Cómo Añadir Sonidos](#cómo-añadir-sonidos)
7. [Gestión de Sonidos con MinigameSoundSet](#-gestión-de-sonidos-con-minigamesoundset)
8. [Checklist de Integración](#-checklist-de-integración)
9. [Ejemplos de Uso](#ejemplos-de-uso)

---

## 🎨 Paleta de Colores

Todos los minijuegos usan la paleta estandarizada definida en `MinigameFX.COLORS`:

### Colores de Feedback (Calidad)

| Calidad   | Hex       | Color Preview | Uso                                  |
|-----------|-----------|---------------|--------------------------------------|
| **Perfect** | `#22c55e` | 🟢 Verde      | Aciertos perfectos, <5% error       |
| **Bien**    | `#38bdf8` | 🔵 Azul Cielo | Aciertos buenos, 5-25% error        |
| **Regular** | `#f59e0b` | 🟠 Naranja    | Aciertos regulares, 25-50% error    |
| **Miss**    | `#ef4444` | 🔴 Rojo       | Fallos, >50% error                  |

### Colores de UI

| Nombre       | Hex       | Uso                                  |
|--------------|-----------|--------------------------------------|
| **Background** | `#0b0f14` | Fondo principal de minijuegos       |
| **Surface**    | `#111827` | Paneles, barras, contenedores       |
| **Border**     | `#1e293b` | Bordes, separadores                 |
| **Accent**     | `#8b5cf6` | Elementos destacados, títulos       |
| **Warning**    | `#facc15` | Cursores, indicadores, alertas      |
| **Success**    | `#10b981` | Zonas objetivo, ventanas óptimas    |
| **Neutral**    | `#94a3b8` | Textos secundarios, hints           |

### Acceso en Código

```gdscript
const MinigameFX = preload("res://scripts/ui/MinigameFX.gd")

# Usar colores
var perfect_color = MinigameFX.COLORS["Perfect"]
var bg_color = MinigameFX.COLORS["Background"]

# Helper
var quality_color = MinigameFX.get_quality_color("Bien")
```

---

## 💫 Sistema de Feedback

### Tipos de Feedback

El sistema `MinigameFX` proporciona 4 tipos de feedback visual:

#### 1. **Flash de Pantalla**
```gdscript
MinigameFX.create_flash("Perfect", self)
```
- Llena la pantalla con un destello de color
- Intensidad varía según calidad
- Duración: 0.3s

#### 2. **Partículas Explosivas**
```gdscript
MinigameFX.create_particles(position, "Bien", self)
```
- Genera partículas que salen del punto de impacto
- Cantidad y velocidad según calidad
- Perfect: 24 partículas | Miss: 3 partículas

#### 3. **Pulso Visual**
```gdscript
MinigameFX.create_pulse(position, "Regular", self)
```
- Efecto de onda expansiva desde el punto
- Escala y duración según calidad

#### 4. **Label Flotante**
```gdscript
MinigameFX.create_floating_label(position, "PERFECT!", "Perfect", self)
```
- Texto que flota hacia arriba y se desvanece
- Color según calidad
- Duración: 0.8s

### Feedback Completo (Recomendado)

```gdscript
# Aplica flash + partículas + pulso de una sola vez
MinigameFX.full_feedback(position, quality, self)
```

---

## 🎆 Efectos Visuales

### Screen Shake

```gdscript
# Sacudir cámara o nodo según calidad
MinigameFX.apply_shake(node, "Perfect")
```

**Intensidades:**
- Perfect: 0.15 (fuerte)
- Bien: 0.08 (medio)
- Regular: 0.04 (leve)
- Miss: 0.12 (moderado-fuerte)

### Glow Pulsante

```gdscript
MinigameFX.create_glow_pulse(position, color, self)
```
- Efecto de brillo que pulsa 3 veces
- Útil para zonas objetivo animadas

### Trail / Estela

```gdscript
MinigameFX.create_trail(from_pos, to_pos, color, self)
```
- Dibuja una línea que se desvanece
- Ideal para objetos en movimiento

---

## 🔊 Sistema de Audio

### Estructura de Archivos (Esperados)

```
res://art/sounds/
├── minigame_perfect.wav   # Acierto perfecto
├── minigame_good.wav      # Acierto bueno
├── minigame_ok.wav        # Acierto regular
├── minigame_miss.wav      # Fallo
├── minigame_hit.wav       # Golpe genérico
├── minigame_start.wav     # Inicio de minijuego
└── minigame_finish.wav    # Final de minijuego
```

### Uso en Código

```gdscript
const MinigameAudio = preload("res://scripts/ui/MinigameAudio.gd")

# Feedback por calidad
MinigameAudio.play_feedback("Perfect")  # Auto-selecciona sonido

# Sonidos especiales
MinigameAudio.play_start()              # Al comenzar
MinigameAudio.play_finish(success)      # Al terminar
MinigameAudio.play_combo(combo_count)   # Combo >= 3
MinigameAudio.play_hit()                # Impacto genérico
```

### Volúmenes por Defecto (dB)

| Calidad | Volumen |
|---------|---------|
| Perfect | +3 dB   |
| Bien    | 0 dB    |
| Regular | -3 dB   |
| Miss    | -6 dB   |

### Contexto de Audio

Todos los sonidos de minijuegos se reproducen en el **contexto FORGE**:
- Activado automáticamente por `MinigameBase.start_trial()`
- Independiente del audio del dungeon
- Gestionado por `AudioManager`

---

## 🖼️ Cómo Añadir Arte

### 1. Preparar Assets

**Formatos recomendados:**
- **Texturas:** PNG con transparencia, 512x512 o 1024x1024
- **Sprites:** PNG, múltiplo de 32px (32, 64, 128...)
- **Backgrounds:** PNG/JPG, 1920x1080 o proporcional

### 2. Importar a Godot

```
res://art/minigames/
├── forge/
│   ├── background.png
│   ├── cursor.png
│   └── target_zone.png
├── hammer/
│   ├── note.png
│   ├── impact_zone.png
│   └── track.png
├── sew/
│   ├── ring.png
│   └── needle.png
└── quench/
    └── thermometer.png
```

### 3. Integrar en Minijuego

**Ejemplo: ForgeMinigame**

```gdscript
# Cargar texture
var cursor_texture = preload("res://art/minigames/forge/cursor.png")

# En _draw()
func _draw():
    # Dibujar sprite
    draw_texture(cursor_texture, position - cursor_texture.get_size() / 2)
    
    # O usar con Sprite2D
    var sprite = Sprite2D.new()
    sprite.texture = cursor_texture
    add_child(sprite)
```

### 4. Reemplazar Placeholders

**Antes (código actual):**
```gdscript
draw_rect(cursor_rect, cursor_color)  # Rectángulo simple
```

**Después (con arte):**
```gdscript
draw_texture_rect(cursor_texture, cursor_rect, false, cursor_color)
```

---

## 🎵 Cómo Añadir Sonidos

### 1. Preparar Assets

**Especificaciones:**
- **Formato:** WAV (sin comprimir) o OGG (comprimido)
- **Sample Rate:** 44100 Hz
- **Channels:** Mono o Estéreo
- **Duración:**
  - SFX: 0.1-0.5 segundos
  - Feedback: 0.2-0.8 segundos
  - Música: Loop seamless

### 2. Importar a Godot

Coloca los archivos en `res://art/sounds/` y Godot generará `.import` automáticamente.

**Configuración de importación (Inspector):**
- **Loop:** Desactivado para SFX, Activado para música
- **Compress:** Activado para OGG, Desactivado para WAV

### 3. Conectar con MinigameAudio usando SoundSet Resource

**Opción A: Editar el Resource Default** (Recomendado)

1. Abre `res://data/minigame_sounds_default.tres` en el Inspector
2. Arrastra tus AudioStreams a cada propiedad:
   - `sound_perfect` → minigame_perfect.wav
   - `sound_bien` → minigame_good.wav
   - `sound_regular` → minigame_ok.wav
   - `sound_miss` → minigame_miss.wav
   - etc.
3. Guarda el Resource (Ctrl+S)
4. ¡Listo! Todos los minijuegos usan este SoundSet automáticamente

**Opción B: Crear un SoundSet Personalizado**

1. Crea un nuevo Resource: `res://data/my_custom_sounds.tres`
2. Asigna el script: `res://scripts/data/MinigameSoundSet.gd`
3. Arrastra tus sonidos
4. En `main.gd` o autoload:

```gdscript
func _ready():
    var custom_sounds = load("res://data/my_custom_sounds.tres")
    MinigameAudio.set_sound_set(custom_sounds)
```

**Ventajas del SoundSet:**
- ✅ Reutilizar sonidos comunes entre minijuegos
- ✅ Cambiar todos los sonidos desde un solo archivo .tres
- ✅ Fácil crear variantes (sonidos navideños, halloween, etc.)

### 4. Precargar Sonidos (Opcional)

Para evitar lag en el primer uso:

```gdscript
func _ready():
    MinigameAudio.preload_sounds()
```

---

## 🧪 Ejemplos de Uso

### Ejemplo 1: Nuevo Minijuego Básico

```gdscript
extends "res://scripts/core/MinigameBase.gd"

const MinigameFX = preload("res://scripts/ui/MinigameFX.gd")
const MinigameAudio = preload("res://scripts/ui/MinigameAudio.gd")

func _ready():
    setup_title_screen("🎯 MI MINIJUEGO", "Descripción", "Instrucciones")

func _finish_attempt():
    var quality := "Perfect"  # Determinar según lógica
    var feedback_pos := Vector2(size.x / 2, size.y / 2)
    
    # Feedback completo
    MinigameFX.full_feedback(feedback_pos, quality, self)
    MinigameFX.create_floating_label(feedback_pos, quality, quality, self)
    MinigameAudio.play_feedback(quality)
    
    # Completar trial
    complete_trial(get_result())

func _draw():
    # Fondo
    draw_rect(Rect2(Vector2.ZERO, size), MinigameFX.COLORS["Background"])
    
    # Elemento visual
    var target_color = MinigameFX.COLORS["Success"]
    draw_circle(Vector2(size.x / 2, size.y / 2), 50, target_color)
```

### Ejemplo 2: Barra de Progreso Temática

```gdscript
func _draw():
    var bar_rect := Rect2(100, 200, 600, 40)
    var progress := 0.75  # 75%
    
    # Usar helper de MinigameFX
    MinigameFX.draw_progress_bar(
        self,
        bar_rect,
        progress,
        MinigameFX.COLORS["Success"],
        MinigameFX.COLORS["Surface"]
    )
```

### Ejemplo 3: Zona Objetivo Animada

```gdscript
func _draw():
    var target_pos := Vector2(400, 300)
    var target_radius := 50.0
    
    # Glow pulsante
    var glow_alpha := 0.3 + sin(Time.get_ticks_msec() * 0.003) * 0.15
    draw_circle(target_pos, target_radius + 8, Color(MinigameFX.COLORS["Accent"], glow_alpha))
    
    # Círculo principal
    MinigameFX.draw_circle_outline(self, target_pos, target_radius, MinigameFX.COLORS["Accent"], 3)
```

---

## 🔊 Gestión de Sonidos con MinigameSoundSet

### ¿Por qué un Resource?

El `MinigameSoundSet` centraliza todos los AudioStreams en un solo archivo `.tres` que puedes editar desde el Inspector. **Ventajas:**

- **Reutilización**: Un sonido "perfect" compartido por todos los minijuegos
- **Variantes fáciles**: Crea `sounds_halloween.tres` y cámbialo en runtime
- **Sin código**: Arrastra archivos desde el Inspector, no edites paths en GDScript
- **Fallback automático**: Si un sonido es `null`, MinigameAudio usa placeholders

### Estructura del Resource

```gdscript
# scripts/data/MinigameSoundSet.gd
class_name MinigameSoundSet extends Resource

@export var sound_perfect: AudioStream
@export var sound_bien: AudioStream
@export var sound_regular: AudioStream
@export var sound_miss: AudioStream
@export var sound_hit: AudioStream
@export var sound_start: AudioStream
@export var sound_finish_success: AudioStream
@export var sound_finish_fail: AudioStream
@export var sound_combo: AudioStream
@export var sound_ambient: AudioStream
@export var sound_countdown: AudioStream
```

### Workflow: Asignar Sonidos

1. **Navegar al Resource**:  
   `FileSystem` → `res://data/minigame_sounds_default.tres` → Doble clic

2. **En el Inspector**:  
   - Verás 11 propiedades `AudioStream`
   - Arrastra `.wav`, `.ogg`, `.mp3` desde `res://art/sounds/`
   - Ejemplo:
     ```
     sound_perfect → forge_perfect.wav
     sound_bien    → hammer_good.wav
     sound_regular → generic_ok.wav
     sound_miss    → error_buzz.wav
     ```

3. **Guardar**: Ctrl+S o `Resource → Save`

### Workflow: Cambiar SoundSet en Runtime

Si quieres sonidos temáticos (navidad, terror, etc.):

```gdscript
# main.gd o autoload
func _ready():
    if current_season == "halloween":
        var spooky: MinigameSoundSet = load("res://data/sounds_halloween.tres")
        MinigameAudio.set_sound_set(spooky)
```

### Estructura de Fallback

```
MinigameAudio.play_feedback("Perfect")
  ↓
1. ¿Existe SoundSet.sound_perfect?  → Sí → Reproducir
  ↓ No
2. ¿Existe SOUND_PATHS["Perfect"]? → Sí → Cargar y reproducir
  ↓ No
3. load_placeholder_sound() → beep sintético
```

Esto garantiza que nunca haya silencio total, incluso sin assets.

---

## ✅ Checklist de Integración

Cuando añadas arte/sonido a un minijuego:

### Assets
- [ ] **Texturas** importadas en `res://art/minigames/<nombre>/`
- [ ] **Sonidos** importados en `res://art/sounds/`
- [ ] **SoundSet** editado: Abrir `res://data/minigame_sounds_default.tres` y arrastrar AudioStreams

### Código del Minijuego
- [ ] **Colores** adaptados desde `MinigameFX.COLORS` (usa hex → Color)
- [ ] **Feedback Visual** con `MinigameFX.full_feedback(quality, position)` en cada intento
- [ ] **Feedback Sonoro** con `MinigameAudio.play_feedback(quality)` (automático vía SoundSet)
- [ ] **Audio Start** con `MinigameAudio.play_start()` en `start_trial()`
- [ ] **Audio Finish** con `MinigameAudio.play_finish(success)` en `complete_trial()`
- [ ] **Title Screen** configurado con `setup_title_screen(titulo, instrucciones)`

### Testing
- [ ] **Transiciones** fade in/out funcionando (0.3s entrada, 0.25s salida)
- [ ] **Responsive** probado en 1280x720 y 1920x1080 (MinigameContainer escala automático)
- [ ] **Audio Context** verificado FORGE activo (MinigameBase lo hace automático)
- [ ] **Sin warnings** en consola de Godot
- [ ] **FPS >= 60** estable durante gameplay
- [ ] **Placeholder** funcional si falta algún AudioStream en SoundSet

---

## 📝 Notas Técnicas

### Performance

- **Partículas:** Máximo 24 por evento (Perfect), auto-destruidas tras 0.6s
- **Tweens:** Auto-limpiados, sin fugas de memoria
- **Audio:** Contexto FORGE activado/desactivado automáticamente
- **Draw calls:** Optimizados con `draw_polyline` en lugar de múltiples `draw_line`

### Compatibilidad

- **Godot:** 4.5 estable
- **Resoluciones:** 1280x720 (mín) - 1920x1080 (máx)
- **Plataforma:** Desktop (Windows/Linux/Mac)
- **Input:** Teclado + Ratón

### Limitaciones Actuales

- ❌ Sin control de pitch en audio (pendiente AudioEffects)
- ❌ Sin audio espacial 2D (todos los SFX son globales)
- ❌ Sin vibración (sin soporte de gamepad)

---

## 🔗 Referencias

- **MinigameFX:** `res://scripts/ui/MinigameFX.gd`
- **MinigameAudio:** `res://scripts/ui/MinigameAudio.gd`
- **MinigameBase:** `res://scripts/core/MinigameBase.gd`
- **AudioManager:** `res://scripts/autoload/AudioManager.gd`
- **Copilot Instructions:** `.github/copilot-instructions.md`

---

## 📞 Contacto y Soporte

Para dudas sobre el sistema visual/audio de minijuegos:
- Revisar código de ejemplo en `ForgeMinigame.gd`
- Consultar documentación de AudioManager en `doc/MIGRACION_AUDIO_CONTEXTOS.md`
- Verificar que AutoLoads estén registrados en Project Settings

---

**Última actualización:** Octubre 2025  
**Versión:** 1.0 (FASE 1 completada)
