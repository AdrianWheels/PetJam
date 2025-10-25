# 🔊 MinigameSoundSet - Quick Start

> **Sistema de sonidos reutilizables para los 4 minijuegos**  
> Archivo: `res://data/minigame_sounds_default.tres`

---

## ¿Qué es?

Un **Resource de Godot** que centraliza todos los AudioStreams de los minijuegos en un solo archivo `.tres` editable desde el Inspector.

**Beneficios:**
- ✅ **Reutilización**: Un sonido "perfect" compartido por Forge, Hammer, Sew, Quench
- ✅ **Sin código**: Arrastra archivos `.wav`/`.ogg` desde el FileSystem al Inspector
- ✅ **Variantes fáciles**: Crea `sounds_halloween.tres` y cámbialo en runtime
- ✅ **Fallback automático**: Si un sonido es `null`, se usa placeholder sintético

---

## Workflow: Asignar Sonidos (2 minutos)

### 1. Abrir el Resource

**FileSystem** → `res://data/` → Doble clic en `minigame_sounds_default.tres`

### 2. Arrastrar Sonidos en el Inspector

Verás 11 propiedades vacías (`sound_perfect`, `sound_bien`, etc.):

| Propiedad | Descripción | Ejemplo |
|-----------|-------------|---------|
| `sound_perfect` | Acierto perfecto (90-100% precisión) | `forge_perfect.wav` |
| `sound_bien` | Acierto bueno (70-89%) | `hammer_good.wav` |
| `sound_regular` | Acierto regular (50-69%) | `generic_ok.wav` |
| `sound_miss` | Fallo total (<50%) | `error_buzz.wav` |
| `sound_hit` | Impacto físico (martillo, coser) | `hit.wav` |
| `sound_start` | Inicio de trial | `start_beep.wav` |
| `sound_finish_success` | Victoria en minijuego | `victory.wav` |
| `sound_finish_fail` | Derrota en minijuego | `fail.wav` |
| `sound_combo` | Combo de aciertos (3+) | `combo.wav` |
| `sound_ambient` | Loop de fondo opcional | `forge_ambient_loop.wav` |
| `sound_countdown` | Cuenta regresiva "3, 2, 1" | `countdown.wav` |

**Arrastra archivos desde `res://art/sounds/` a cada propiedad.**

### 3. Guardar

`Ctrl+S` o clic en **Resource → Save**

### 4. Testear

Ejecuta cualquier minijuego. Los sonidos se reproducirán automáticamente vía `MinigameAudio`.

---

## Uso Avanzado: Variantes Temáticas

### Crear un SoundSet de Halloween

1. **Duplicar**: Clic derecho en `minigame_sounds_default.tres` → **Duplicate**
2. **Renombrar**: `sounds_halloween.tres`
3. **Editar**: Reemplaza `sound_perfect` con `ghost_laugh.wav`, etc.
4. **Activar en Runtime**:

```gdscript
# main.gd
func _ready():
    if current_event == "halloween":
        var spooky: MinigameSoundSet = load("res://data/sounds_halloween.tres")
        MinigameAudio.set_sound_set(spooky)
```

### Resetear al Default

```gdscript
var default: MinigameSoundSet = load("res://data/minigame_sounds_default.tres")
MinigameAudio.set_sound_set(default)
```

---

## Estructura de Fallback

```
Jugador hace acierto "Perfect"
  ↓
MinigameAudio.play_feedback("Perfect")
  ↓
1. ¿SoundSet.sound_perfect existe?
   → Sí: Reproducir con AudioManager.play_sfx()
   → No: ↓
2. ¿SOUND_PATHS["Perfect"] existe?
   → Sí: Cargar y reproducir
   → No: ↓
3. Generar beep sintético (placeholder)
```

**Garantía:** Nunca habrá silencio total, incluso sin assets.

---

## Archivo Técnico

**Script Resource:**  
`res://scripts/data/MinigameSoundSet.gd`

**Instancia Default:**  
`res://data/minigame_sounds_default.tres`

**Sistema de Audio:**  
`res://scripts/ui/MinigameAudio.gd` (static class)

**Contexto:**  
AudioManager usa `AudioContext.FORGE` automáticamente (activado por `MinigameBase.start_trial()`)

---

## Troubleshooting

### Los sonidos no se reproducen

1. **Verifica que los archivos existan:**  
   `FileSystem` → `res://art/sounds/` → Verifica que los `.wav` estén importados
2. **Comprueba el SoundSet:**  
   Abre `minigame_sounds_default.tres` → Deberías ver iconos de audio en las propiedades
3. **Revisa la consola de Godot:**  
   Busca warnings de `AudioManager` o `MinigameAudio`

### ¿Cómo saber qué SoundSet está activo?

```gdscript
var current: MinigameSoundSet = MinigameAudio.get_sound_set()
print(current.resource_path)  # → res://data/minigame_sounds_default.tres
```

### ¿Puedo usar sonidos diferentes por minijuego?

Sí, crea múltiples SoundSets:

```gdscript
# ForgeMinigame.gd
func _ready():
    var forge_sounds: MinigameSoundSet = load("res://data/sounds_forge.tres")
    MinigameAudio.set_sound_set(forge_sounds)
    super._ready()  # Llama a MinigameBase._ready()
```

---

## Checklist: Primera Integración

- [ ] Importar sonidos en `res://art/sounds/`
- [ ] Abrir `minigame_sounds_default.tres` en Inspector
- [ ] Arrastrar al menos `sound_perfect`, `sound_bien`, `sound_regular`, `sound_miss`
- [ ] Guardar con `Ctrl+S`
- [ ] Ejecutar **Forge Minigame** (F6) y verificar audio
- [ ] Si falta algún sonido, verificar que el placeholder suene

---

## Referencias

- **Documentación completa:** `doc/MINIGAME_VISUAL_THEME.md`
- **API de MinigameAudio:** Buscar en `scripts/ui/MinigameAudio.gd`
- **Integración en minijuegos:** Ver `scripts/ForgeMinigame.gd` (líneas con `MinigameAudio.play_feedback()`)
