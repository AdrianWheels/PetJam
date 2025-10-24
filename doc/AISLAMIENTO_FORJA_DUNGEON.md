# 🎯 **AISLAMIENTO: FORJA vs DUNGEON**
### *Arquitectura para sistemas independientes ejecutándose en paralelo*

**Fecha:** 24 de Octubre, 2025  
**Objetivo:** Separar audio, debug y UI mientras mantienen ambas escenas activas

---

## 🔍 **SITUACIÓN ACTUAL**

### **Lo que funciona bien:**
- ✅ UI ya está aislada (HUD_Forge vs HUD_Hero en CanvasLayers separados)
- ✅ Cambio de área con clic derecho funciona correctamente
- ✅ Hero sigue peleando cuando estamos en Forja (corridor.process_mode)
- ✅ Minijuegos se renderizan solo en área de Forja

### **Lo que necesita aislamiento:**
- ❌ **AudioManager** es único → necesita sistema de contextos
- ❌ **Debug prints** mezclados → necesita prefijos o filtros
- ❌ **No hay checkbox** para activar ambos debugs a la vez

---

## 📋 **PROPUESTA DE ARQUITECTURA**

### **1. Sistema de Audio por Contexto**

**Problema:** Un solo `AudioManager` con un `_music_player` y un `_sfx_player`.

**Solución:** Añadir sistema de capas/contextos:

```gdscript
# AudioManager.gd (extendido)
enum AudioContext { GLOBAL, FORGE, DUNGEON }

var _contexts := {
	AudioContext.FORGE: {
		"music_player": AudioStreamPlayer.new(),
		"sfx_player": AudioStreamPlayer.new(),
		"enabled": true
	},
	AudioContext.DUNGEON: {
		"music_player": AudioStreamPlayer.new(),
		"sfx_player": AudioStreamPlayer.new(),
		"enabled": true
	}
}

func play_music(stream: AudioStream, context: AudioContext = AudioContext.GLOBAL, loop: bool = true):
	if context == AudioContext.GLOBAL:
		_music_player.stream = stream
		_music_player.play()
	else:
		var ctx = _contexts[context]
		if ctx.enabled:
			ctx.music_player.stream = stream
			ctx.music_player.play()
```

**Ventajas:**
- Música de forja y dungeon independientes
- Se pueden activar/desactivar por separado
- Transiciones suaves con crossfade

---

### **2. Sistema de Debug Modular**

**Problema:** Prints mezclados sin forma de filtrar por origen.

**Solución:** Crear un `DebugManager` con categorías:

```gdscript
# res://scripts/autoload/DebugManager.gd
extends Node

@export var show_forge_debug := true
@export var show_dungeon_debug := true
@export var show_minigame_debug := false
@export var show_audio_debug := false

func log_forge(message: String) -> void:
	if show_forge_debug:
		print("[FORGE] %s" % message)

func log_dungeon(message: String) -> void:
	if show_dungeon_debug:
		print("[DUNGEON] %s" % message)

func log_minigame(message: String) -> void:
	if show_minigame_debug:
		print("[MINIGAME] %s" % message)
```

**Uso:**
```gdscript
# Antes:
print("Forja: Iniciando minijuego...")

# Después:
DebugManager.log_forge("Iniciando minijuego...")
```

**Ventajas:**
- Filtros granulares
- Se puede desactivar en runtime
- Fácil integración con logger existente

---

### **3. Panel de Debug con Checkboxes**

**Ubicación:** Nuevo panel flotante con `@tool` support

```gdscript
# res://scenes/UI/DebugPanel.tscn
[Panel visible siempre en esquina superior derecha]

┌─ DEBUG CONTROLS ───────┐
│ [ ] Show All           │
│ [✓] Forge Debug        │
│ [✓] Dungeon Debug      │
│ [ ] Minigame Debug     │
│ [ ] Audio Debug        │
│                        │
│ [✓] Forge Audio        │
│ [✓] Dungeon Audio      │
└────────────────────────┘
```

**Script:**
```gdscript
extends PanelContainer

@onready var chk_forge_debug := %ChkForgeDebug
@onready var chk_dungeon_debug := %ChkDungeonDebug
@onready var chk_forge_audio := %ChkForgeAudio
@onready var chk_dungeon_audio := %ChkDungeonAudio

func _ready():
	chk_forge_debug.toggled.connect(_on_forge_debug_toggled)
	chk_dungeon_debug.toggled.connect(_on_dungeon_debug_toggled)
	chk_forge_audio.toggled.connect(_on_forge_audio_toggled)
	chk_dungeon_audio.toggled.connect(_on_dungeon_audio_toggled)

func _on_forge_debug_toggled(active: bool):
	DebugManager.show_forge_debug = active

func _on_forge_audio_toggled(active: bool):
	AudioManager.set_context_enabled(AudioManager.AudioContext.FORGE, active)
```

---

## 🔧 **IMPLEMENTACIÓN POR FASES**

### **FASE A: AudioManager con contextos** (30 min)
1. Añadir enum `AudioContext` 
2. Crear diccionario `_contexts` con players separados
3. Modificar `play_music()` y `play_sfx()` para aceptar contexto
4. Añadir `set_context_enabled(context, enabled)`
5. Testing: reproducir música en ambos contextos simultáneamente

### **FASE B: DebugManager** (20 min)
1. Crear `res://scripts/autoload/DebugManager.gd`
2. Añadir exports para checkboxes
3. Implementar funciones `log_forge()`, `log_dungeon()`, etc.
4. Registrar como AutoLoad
5. Reemplazar prints clave en 3-4 archivos como ejemplo

### **FASE C: DebugPanel UI** (40 min)
1. Crear escena `res://scenes/UI/DebugPanel.tscn`
2. Añadir CheckBoxes con nombres únicos (`%ChkForgeDebug`, etc.)
3. Script con conexiones a DebugManager y AudioManager
4. Integrar en Main.tscn como hijo de un CanvasLayer en layer 10 (siempre encima)
5. Posición fija en esquina superior derecha
6. Testing: cambiar checkboxes y verificar efectos

---

## ✅ **CHECKLIST DE COMPORTAMIENTO ESPERADO**

- [ ] **Audio independiente:**
  - [ ] Música de forja suena solo en forja
  - [ ] Música de dungeon suena solo en dungeon
  - [ ] Desactivar "Forge Audio" → silencia minijuegos
  - [ ] Desactivar "Dungeon Audio" → silencia combates

- [ ] **Debug separado:**
  - [ ] Activar solo "Forge Debug" → solo prints de forja
  - [ ] Activar solo "Dungeon Debug" → solo prints de dungeon
  - [ ] Activar ambos → ve todo
  - [ ] Desactivar ambos → consola limpia

- [ ] **Panel persistente:**
  - [ ] Visible siempre (incluso al cambiar de área)
  - [ ] Cambios se aplican inmediatamente (sin reinicio)
  - [ ] Estados se guardan en memoria (no persistentes aún)

---

## 📝 **NOTAS TÉCNICAS**

### **Alternativa 1: Bus separados**
En vez de players separados, usar buses de audio:
- `Master/Forge`
- `Master/Dungeon`

**Ventajas:** Más ligero, mejor performance  
**Desventajas:** Menos control granular, no se pueden reproducir simultáneamente

### **Alternativa 2: Singleton por área**
Crear `ForgeAudioManager` y `DungeonAudioManager` independientes.

**Ventajas:** Aislamiento total  
**Desventajas:** Duplicación de código, más complejo

**Decisión:** Ir con contextos en AudioManager único (más flexible).

---

## 🚀 **PRÓXIMOS PASOS**

1. **Implementar FASE A** (AudioManager con contextos)
2. Testing básico: reproducir 2 músicas a la vez
3. **Implementar FASE B** (DebugManager)
4. Reemplazar 5-10 prints como ejemplo
5. **Implementar FASE C** (DebugPanel UI)
6. Testing completo con checklist
7. Commit: `feat(audio+debug): Aislamiento forja/dungeon con panel de control`

---

**¿Proceder con implementación? Responde "Sí" para comenzar con FASE A.**
