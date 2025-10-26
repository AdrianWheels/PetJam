# Plan de Implementación: Sistema de Audio Completo

## 📋 Resumen
Sincronizar sonidos desde `PetJam-assets`, integrar en minijuegos, ambientes alternados en dungeon/forja, SFX de crafteo y corregir bug de delivery blocking.

---

## 🔊 FASE 1: Sincronización de Assets de Audio

### 1.1. Estructura de destino
```
res://art/sounds/
	ambient/
		# Ambiente forja
		amb_dungeon_workshop_arcade_loop_01.wav
		amb_dungeon_workshop_arcade_loop_02.wav
		u3512428292_Dungeon_forge_workshop_background_anvil_brick_fur_[...].wav
		
		# Ambiente dungeon (4 variaciones - alternadas)
		amb_corridor_tension_arcade_loop_01.wav
		amb_corridor_tension_arcade_loop_02.wav
		amb_corridor_tension_arcade_loop_03.wav
		amb_corridor_tension_arcade_loop_04.wav
	
	sfx/
		combat/
			atk_sword_flesh_hit_01.wav (5 variaciones)
			atk_sword_flesh_cloth_01.wav
			atk_sword_flesh_leather_01.wav (3 variaciones)
		
		hero/
			step_hero_stone_walk_loop_01.wav (4 variaciones)
		
		minigames/
			forge/
				# TODO: background forge (usar pitch variation si no existe)
			
			hammer/
				hammer_perfect.wav
				hammer_good.wav
				hammer_miss.wav
			
			sew/
				# TODO: stitch sounds (usar pitch variation de hammer si no existe)
			
			quench/
				quench_background.wav
		
		craft/
			craft_gold.wav      # Para ItemInfoPanel quality "gold"
			craft_silver.wav    # Para ItemInfoPanel quality "silver"
			craft_bronze.wav    # Para ItemInfoPanel quality "bronze"
		
		ui/
			good.mp3            # (ya existe)
			perfect.mp3         # (ya existe)
			miss.mp3            # (ya existe)
			regular.mp3         # (ya existe)
```

### 1.2. Archivos a copiar
Desde `PetJam-assets/Sonidos/`:
- **Ambiente**: `amb_*.wav` → `res://art/sounds/ambient/`
- **Combate**: `atk_sword_*.wav` → `res://art/sounds/sfx/combat/`
- **Héroe**: `step_hero_*.wav` → `res://art/sounds/sfx/hero/`
- **Minijuegos**: `sfx/hammer/*.wav` → `res://art/sounds/sfx/minigames/hammer/`
- **Minijuegos**: `sfx/quench/*.wav` → `res://art/sounds/sfx/minigames/quench/`
- **Craft**: `sfx/craft/*.wav` → `res://art/sounds/sfx/craft/`

**Faltantes** (usar pitch variation):
- Forge background: usar `quench_background.wav` con pitch +0.2
- Sew feedback: usar `hammer_perfect/good/miss.wav` con pitch +0.5

---

## 🎵 FASE 2: Sistema de Ambiente Alternado

### 2.1. Mejora de AudioManager
Añadir sistema de alternancia de ambient loops con fade in/out.

**Archivo**: `res://scripts/autoload/AudioManager.gd`

**Nuevas funciones**:
```gdscript
var _ambient_tracks: Array[AudioStream] = []
var _current_ambient_index: int = 0
var _ambient_loops_before_switch: int = 3  # Repetir 3 veces antes de cambiar
var _ambient_loop_count: int = 0
var _ambient_fade_time: float = 2.0  # 2 segundos fade in/out

func play_ambient_loop_alternating(tracks: Array[AudioStream], context: AudioContext, loops_per_track: int = 3):
	"""Reproduce tracks de ambiente alternados con fade in/out"""
	_ambient_tracks = tracks
	_ambient_loops_before_switch = loops_per_track
	_ambient_loop_count = 0
	_current_ambient_index = 0
	_play_next_ambient_track(context)

func _play_next_ambient_track(context: AudioContext):
	"""Reproduce siguiente track con fade in"""
	if _ambient_tracks.is_empty():
		return
	
	var player: AudioStreamPlayer = _get_music_player(context)
	if not player:
		return
	
	var track = _ambient_tracks[_current_ambient_index]
	player.stream = track
	player.volume_db = -80.0  # Empezar silencioso
	player.play()
	
	# Fade in
	var tween = create_tween()
	tween.tween_property(player, "volume_db", 0.0, _ambient_fade_time)
	
	# Conectar finished para alternar
	if not player.is_connected("finished", _on_ambient_finished):
		player.finished.connect(_on_ambient_finished.bind(context, player))
	
	print("AudioManager: Playing ambient track %d/%d (context: %s)" % [_current_ambient_index + 1, _ambient_tracks.size(), _get_context_name(context)])

func _on_ambient_finished(context: AudioContext, player: AudioStreamPlayer):
	_ambient_loop_count += 1
	
	if _ambient_loop_count >= _ambient_loops_before_switch:
		# Cambiar a siguiente track con fade out/in
		_ambient_loop_count = 0
		_current_ambient_index = (_current_ambient_index + 1) % _ambient_tracks.size()
		
		# Fade out actual
		var tween = create_tween()
		tween.tween_property(player, "volume_db", -80.0, _ambient_fade_time)
		tween.tween_callback(func(): _play_next_ambient_track(context))
	else:
		# Repetir mismo track
		player.play()
```

### 2.2. Integración en Main.gd
**Archivo**: `res://scripts/main.gd`

En `_ready()` después de activar contextos:
```gdscript
# Cargar tracks de ambiente
var dungeon_ambient := [
	preload("res://art/sounds/ambient/amb_corridor_tension_arcade_loop_01.wav"),
	preload("res://art/sounds/ambient/amb_corridor_tension_arcade_loop_02.wav"),
	preload("res://art/sounds/ambient/amb_corridor_tension_arcade_loop_03.wav"),
	preload("res://art/sounds/ambient/amb_corridor_tension_arcade_loop_04.wav"),
]

var forge_ambient := [
	preload("res://art/sounds/ambient/amb_dungeon_workshop_arcade_loop_01.wav"),
	preload("res://art/sounds/ambient/amb_dungeon_workshop_arcade_loop_02.wav"),
]

# Iniciar ambient loops alternados
AudioManager.play_ambient_loop_alternating(dungeon_ambient, AudioManager.AudioContext.DUNGEON, 3)
AudioManager.play_ambient_loop_alternating(forge_ambient, AudioManager.AudioContext.FORGE, 4)
```

---

## 🎮 FASE 3: Audio de Minijuegos

### 3.1. Sonidos por minijuego

| Minigame | Background | Feedback | Eventos especiales |
|----------|-----------|----------|-------------------|
| **Forge** | `quench_background.wav` (pitch +0.2) | `perfect.mp3`, `good.mp3`, `miss.mp3` | - |
| **Hammer** | `quench_background.wav` | `hammer_perfect.wav`, `hammer_good.wav`, `hammer_miss.wav` | - |
| **Sew** | `quench_background.wav` (pitch +0.1) | `hammer_perfect.wav` (pitch +0.5), etc. | - |
| **Quench** | `quench_background.wav` | `perfect.mp3`, `good.mp3`, `miss.mp3` | Splash: `quench_background.wav` (pitch -0.3) |

### 3.2. Implementación en MinigameBase
**Archivo**: `res://scripts/core/MinigameBase.gd`

Añadir:
```gdscript
var _background_stream: AudioStream
var _feedback_sounds: Dictionary = {}

func set_background_audio(stream: AudioStream, volume_db: float = -5.0):
	_background_stream = stream
	if stream:
		AudioManager.play_music(stream, true, volume_db, AudioManager.AudioContext.FORGE)

func set_feedback_sounds(sounds: Dictionary):
	"""
	sounds = {
		"perfect": AudioStream,
		"good": AudioStream,
		"regular": AudioStream,
		"miss": AudioStream
	}
	"""
	_feedback_sounds = sounds

func play_feedback_audio(grade: String):
	var stream = _feedback_sounds.get(grade.to_lower())
	if stream:
		AudioManager.play_sfx(stream, 0.0, AudioManager.AudioContext.FORGE)

func _on_trial_ending():
	# Detener background al finalizar
	if _background_stream:
		AudioManager.stop_music(AudioManager.AudioContext.FORGE)
```

### 3.3. Configurar cada minijuego
**ForgeTemp.gd**:
```gdscript
func _ready():
	super._ready()
	set_background_audio(preload("res://art/sounds/sfx/minigames/quench/quench_background.wav"))
	set_feedback_sounds({
		"perfect": preload("res://art/sounds/ui/perfect.mp3"),
		"good": preload("res://art/sounds/ui/good.mp3"),
		"miss": preload("res://art/sounds/ui/miss.mp3")
	})
```

**HammerMinigame.gd**:
```gdscript
func _ready():
	super._ready()
	set_background_audio(preload("res://art/sounds/sfx/minigames/quench/quench_background.wav"))
	set_feedback_sounds({
		"perfect": preload("res://art/sounds/sfx/minigames/hammer/hammer_perfect.wav"),
		"good": preload("res://art/sounds/sfx/minigames/hammer/hammer_good.wav"),
		"miss": preload("res://art/sounds/sfx/minigames/hammer/hammer_miss.wav")
	})
```

**SewOSU.gd** (pitch variation):
```gdscript
func _ready():
	super._ready()
	var bg = preload("res://art/sounds/sfx/minigames/quench/quench_background.wav")
	# Aplicar pitch +0.1
	var player = AudioStreamPlayer.new()
	player.stream = bg
	player.pitch_scale = 1.1
	# Configurar manualmente (MinigameBase puede no soportar pitch)
	set_background_audio(bg)
	
	set_feedback_sounds({
		"perfect": preload("res://art/sounds/sfx/minigames/hammer/hammer_perfect.wav"),  # pitch +0.5 en código
		"good": preload("res://art/sounds/sfx/minigames/hammer/hammer_good.wav"),
		"miss": preload("res://art/sounds/sfx/minigames/hammer/hammer_miss.wav")
	})
```

**QuenchWater.gd**:
```gdscript
func _ready():
	super._ready()
	set_background_audio(preload("res://art/sounds/sfx/minigames/quench/quench_background.wav"))
	set_feedback_sounds({
		"perfect": preload("res://art/sounds/ui/perfect.mp3"),
		"good": preload("res://art/sounds/ui/good.mp3"),
		"miss": preload("res://art/sounds/ui/miss.mp3")
	})
```

---

## 🎁 FASE 4: SFX de Crafteo Completado

### 4.1. Reproducir según calidad
**Archivo**: `res://scripts/forge/ItemInfoPanel.gd`

En `show_item_info()` después de calcular quality:
```gdscript
func show_item_info(payload: Dictionary) -> void:
	# ... código existente ...
	
	# Calcular quality normalizada
	var quality: float = clamp(score / max_score if max_score > 0.0 else 0.0, 0.0, 1.0)
	
	# 🔊 Reproducir SFX según calidad
	var quality_label_text = QualityUtils.get_quality_label(quality).to_lower()
	var craft_sfx: AudioStream
	
	match quality_label_text:
		"legendary", "gold":
			craft_sfx = preload("res://art/sounds/sfx/craft/craft_gold.wav")
		"silver", "good":
			craft_sfx = preload("res://art/sounds/sfx/craft/craft_silver.wav")
		_:
			craft_sfx = preload("res://art/sounds/sfx/craft/craft_bronze.wav")
	
	if craft_sfx:
		AudioManager.play_sfx(craft_sfx, 0.0, AudioManager.AudioContext.FORGE)
		print("ItemInfoPanel: Playing craft SFX for quality '%s'" % quality_label_text)
	
	# ... resto del código ...
```

---

## 🐛 FASE 5: Corrección Bug de Delivery Blocking

### 5.1. Problema detectado
**Descripción**: El usuario puede hacer otro pedido y empezar pruebas nuevas sin usar el botón "Delivery" después de completar un crafteo.

**Causa**: `HUDMinigameLauncher._on_trial_completed()` re-habilita la interacción con blueprints en el caso `status == "in_progress"`, pero `UIManager.present_delivery()` no bloquea la cola de blueprints.

### 5.2. Solución
**Bloquear blueprints cuando ItemInfoPanel + DeliveryPanel estén visibles.**

#### 5.2.1. Modificar UIManager.present_delivery()
**Archivo**: `res://scripts/autoload/UIManager.gd`

En `present_delivery()`:
```gdscript
func present_delivery(payload: Dictionary) -> void:
	print("UIManager: present_delivery() called")
	_current_item_data = payload
	
	# Mostrar ItemInfoPanel
	if item_info_panel and item_info_panel.has_method("show_item_info"):
		item_info_panel.show_item_info(payload)
		print("UIManager: ItemInfoPanel shown")
	
	# Mostrar DeliveryPanel
	if delivery_panel:
		delivery_panel.visible = true
		print("UIManager: DeliveryPanel shown")
	
	# 🔒 NUEVO: Bloquear interacción con blueprints mientras delivery está abierto
	if hud_forge and hud_forge.has_method("set_queue_interaction_enabled"):
		hud_forge.set_queue_interaction_enabled(false)
		print("UIManager: Blueprints BLOCKED until delivery is completed")
	
	# Ocultar paneles de forja (MinigamesPanel, QueuePanel, Inventory)
	if hud_forge:
		var panels = ["MinigamesPanel", "BlueprintQueuePanel", "InventoryPanel"]
		for panel_name in panels:
			var panel = hud_forge.get_node_or_null(panel_name)
			if panel:
				panel.visible = false
				print("UIManager: %s hidden" % panel_name)
	
	emit_signal("delivery_opened", payload.get("result_item", "unknown"))
```

#### 5.2.2. Mover set_queue_interaction_enabled() de HUDMinigameLauncher a método público
**Archivo**: `res://scripts/core/HUDMinigameLauncher.gd`

Cambiar visibilidad de `_set_queue_interaction_enabled()` a pública:
```gdscript
# Cambiar de:
# func _set_queue_interaction_enabled(enabled: bool) -> void:

# A:
func set_queue_interaction_enabled(enabled: bool) -> void:
	"""Habilita/deshabilita la interacción con los blueprints de la cola"""
	print("HUD: set_queue_interaction_enabled(%s)" % enabled)
	# ... resto del código sin cambios ...
```

Y actualizar todas las llamadas internas de `_set_queue_interaction_enabled()` a `set_queue_interaction_enabled()` (quitar guión bajo).

#### 5.2.3. Confirmar desbloqueo al cerrar delivery
**Archivo**: `res://scripts/autoload/UIManager.gd`

En `_on_delivered_to_client()` y `_on_delivered_to_hero()`:
```gdscript
func _on_delivered_to_client(item_data: Dictionary) -> void:
	# ... código existente ...
	
	emit_signal("delivery_closed")
	print("UIManager: Delivery completed (client), returning to IDLE state")
	
	# 🔓 NUEVO: Desbloquear blueprints al cerrar delivery
	if hud_forge and hud_forge.has_method("set_queue_interaction_enabled"):
		hud_forge.set_queue_interaction_enabled(true)
		print("UIManager: Blueprints UNLOCKED after delivery")
	
	# ... resto del código ...

func _on_delivered_to_hero(item_data: Dictionary) -> void:
	# ... código existente ...
	
	emit_signal("delivery_closed")
	print("UIManager: Delivery completed (hero), returning to IDLE state")
	
	# 🔓 NUEVO: Desbloquear blueprints al cerrar delivery
	if hud_forge and hud_forge.has_method("set_queue_interaction_enabled"):
		hud_forge.set_queue_interaction_enabled(true)
		print("UIManager: Blueprints UNLOCKED after delivery")
	
	# ... resto del código ...
```

#### 5.2.4. Remover desbloqueo prematuro
**Archivo**: `res://scripts/core/HUDMinigameLauncher.gd`

En `_on_trial_completed()`, **comentar** la línea que desbloquea blueprints cuando status == "in_progress":
```gdscript
elif status == "in_progress":
	print("HUD: More trials remain, next trial will auto-start via task_started signal")
	# Ya NO actualizar queue aquí - solo se actualiza desde RequestsManager
	# NO desbloquear blueprints - el siguiente trial iniciará automáticamente
	# CraftingManager ya llamó _start_next_trial() que emitirá task_started
	# 🚫 ELIMINADO: set_queue_interaction_enabled(true)  <-- CAUSA DEL BUG
```

---

## 📝 FASE 6: Checklist de Testing

- [ ] **Ambient Loops**: Dungeon alterna entre 4 tracks cada 3 loops con fade
- [ ] **Ambient Loops**: Forja alterna entre 2 tracks cada 4 loops con fade
- [ ] **Minigame Background**: Cada minijuego reproduce su background al iniciar
- [ ] **Minigame Feedback**: Perfect/Good/Miss reproducen audio correcto
- [ ] **Craft SFX**: ItemInfoPanel reproduce `craft_gold/silver/bronze.wav` según calidad
- [ ] **Delivery Blocking**: No se puede seleccionar otro blueprint hasta entregar ítem
- [ ] **Delivery Blocking**: Al entregar (cliente o héroe), blueprints se desbloquean
- [ ] **Delivery Blocking**: ItemInfoPanel y DeliveryPanel desaparecen tras entrega

---

## 🎯 Orden de Implementación Recomendado

1. **Sincronizar assets** (copiar archivos desde repo)
2. **Fix delivery blocking** (crítico para UX)
3. **Sistema ambient alternado** (AudioManager mejoras)
4. **SFX de crafteo** (ItemInfoPanel)
5. **Audio de minijuegos** (MinigameBase + cada minijuego)
6. **Testing completo**

---

## 🛠️ Comandos PowerShell para Sincronización

```powershell
# Copiar sonidos desde temp a proyecto
$source = "$env:TEMP\PetJam-assets\Sonidos"
$dest = "d:\Proyectos\PetJam\art\sounds"

# Crear directorios
New-Item -ItemType Directory -Force -Path "$dest\ambient"
New-Item -ItemType Directory -Force -Path "$dest\sfx\combat"
New-Item -ItemType Directory -Force -Path "$dest\sfx\hero"
New-Item -ItemType Directory -Force -Path "$dest\sfx\minigames\forge"
New-Item -ItemType Directory -Force -Path "$dest\sfx\minigames\hammer"
New-Item -ItemType Directory -Force -Path "$dest\sfx\minigames\sew"
New-Item -ItemType Directory -Force -Path "$dest\sfx\minigames\quench"
New-Item -ItemType Directory -Force -Path "$dest\sfx\craft"

# Copiar archivos
Copy-Item "$source\amb_*.wav" "$dest\ambient\" -Force
Copy-Item "$source\u3512428292_*.wav" "$dest\ambient\" -Force
Copy-Item "$source\atk_sword_*.wav" "$dest\sfx\combat\" -Force
Copy-Item "$source\step_hero_*.wav" "$dest\sfx\hero\" -Force
Copy-Item "$source\sfx\hammer\*.wav" "$dest\sfx\minigames\hammer\" -Force
Copy-Item "$source\sfx\quench\*.wav" "$dest\sfx\minigames\quench\" -Force
Copy-Item "$source\sfx\craft\*.wav" "$dest\sfx\craft\" -Force

Write-Host "✅ Sonidos sincronizados correctamente"
```

---

## 🎵 Pitch Variations para Sonidos Faltantes

### Forge Background
```gdscript
var forge_bg_player = AudioStreamPlayer.new()
forge_bg_player.stream = preload("res://art/sounds/sfx/minigames/quench/quench_background.wav")
forge_bg_player.pitch_scale = 1.2  # +0.2 semitones
AudioManager.add_child(forge_bg_player)
forge_bg_player.play()
```

### Sew Feedback
```gdscript
# En SewOSU.gd cuando detecte "perfect":
var sfx_player = AudioStreamPlayer.new()
sfx_player.stream = preload("res://art/sounds/sfx/minigames/hammer/hammer_perfect.wav")
sfx_player.pitch_scale = 1.5  # +0.5 semitones
add_child(sfx_player)
sfx_player.play()
```

---

## ✅ Resultado Final

- **Ambiente dinámico**: Dungeon y forja con loops alternados y transiciones suaves
- **Minijuegos inmersivos**: Background y feedback audio contextual
- **Crafteo satisfactorio**: SFX de calidad al completar ítem
- **Bug de delivery corregido**: No se puede iniciar nuevo trabajo hasta entregar ítem actual
- **100% funcional**: Sistema de audio completo e integrado con arquitectura existente

---

**Fecha**: 2025-10-26  
**Versión Godot**: 4.5.1  
**Lenguaje**: GDScript (TABS, no espacios)
