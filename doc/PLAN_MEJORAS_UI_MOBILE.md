# Plan de mejoras UI para Mobile (1080x1920)

**Fecha**: 2025-10-25  
**Viewport objetivo**: 1080x1920 (9:16 portrait)  
**Layout**: 60% dungeon superior / 40% UI inferior  

---

## 📐 Cálculos base

```
Viewport: 1080 x 1920
- 60% superior (Dungeon): 1152px altura
- 40% inferior (UI): 768px altura
- Línea de suelo: Y = 1150
- Línea de techo: Y = 300
```

---

## ✅ Cambios ya realizados

- [x] `DungeonLayout.tscn`: Líneas de suelo/techo ajustadas
- [x] `Corridor.gd`: `GROUND_Y = 1120`
- [x] `Hero.gd`: Spawn position ajustado
- [x] `Main.tscn`: Panel UI inferior (768px altura)
- [x] `HeroStatsPanel.gd`: Script de actualización de stats

---

## 🎯 Cambios pendientes por prioridad

### 🔴 **ALTA PRIORIDAD** (Funcionalidad crítica)

#### 1. **Cámara y viewport dungeon**
**Problema**: La cámara actual no está limitada al área 60% superior.

**Archivos a modificar**:
- `scripts/main.gd`
- `scenes/Main.tscn` (Camera2D)

**Cambios**:
```gdscript
# main.gd - Añadir límites de cámara
@onready var camera: Camera2D = $Camera2D

func _ready():
	# Limitar cámara al área de dungeon (60% superior)
	camera.limit_top = 0
	camera.limit_bottom = 1152  # 60% de 1920
	camera.position.y = 576  # Centro del área dungeon
```

**Alternativa**: Usar `SubViewportContainer` para aislar dungeon en área superior.

---

#### 2. **HUD de combate superior**
**Problema**: Info de combate (sala, enemigo, estado) no es visible.

**Archivos a modificar**:
- `scenes/HUD/CombatHUD.tscn` (crear o modificar)
- `scripts/main.gd`

**Cambios**:
```
Crear/modificar CombatHUD con:
- Posición: Anclado arriba (top margin 20px)
- Contenido:
  * Sala actual (1/8)
  * Nivel enemigo
  * Estado combate (RUN/FIGHT)
  * Mini-mapa de progreso (8 puntos)
- Layout: HBoxContainer con labels y margin responsive
```

**Mockup**:
```
┌─────────────────────────────┐
│ Sala 2/8  │ Enemigo Lv 2   │
│ ●●○○○○○○  │ [FIGHT]         │
└─────────────────────────────┘
```

---

#### 3. **Panel de stats inferior - Layout responsive**
**Problema**: Con 768px altura, hay espacio para mejorar diseño.

**Archivos a modificar**:
- `scenes/Main.tscn` (HeroStatsPanel)
- `scripts/ui/HeroStatsPanel.gd`

**Cambios**:
```
Layout propuesto (VBoxContainer):
┌─────────────────────────────────┐
│          [HÉROE]                │ 60px
├─────────────────────────────────┤
│  [HP Bar grande visual]         │ 80px
│  160/160                        │
├─────────────────────────────────┤
│  STR: 5  AGI: 5  INT: 5  DMG: 21│ 60px
├─────────────────────────────────┤
│  [EQUIPAMIENTO]                 │ 40px
│  ┌───┐  ┌───┐  ┌───┐           │
│  │ W │  │ A │  │ A │           │ 200px
│  └───┘  └───┘  └───┘           │
│  Espada  Cota  Anillo           │
├─────────────────────────────────┤
│  [INVENTARIO] (4 slots)         │ 200px
│  ┌───┐┌───┐┌───┐┌───┐          │
│  │ 1 ││ 2 ││ 3 ││ 4 │          │
│  └───┘└───┘└───┘└───┘          │
├─────────────────────────────────┤
│  [← Volver a Forja]             │ 80px
└─────────────────────────────────┘
Total: ~720px (con márgenes)
```

**Mejoras específicas**:
- HP bar grande y visual (ColorRect con gradiente)
- Stats en GridContainer 2x2
- Equipment slots con TextureRect e íconos
- Inventario con slots interactivos
- Botón "Volver a Forja" grande y accesible

---

### 🟡 **MEDIA PRIORIDAD** (UX importante)

#### 4. **Forja - Layout vertical optimizado**
**Problema**: Forja diseñada para landscape, no portrait.

**Archivos a modificar**:
- `scenes/UI/HUD_Forge.tscn`
- `scenes/ForgeUI/*.tscn` (todos los paneles)
- `scripts/forge/*.gd`

**Cambios**:
```
Layout propuesto vertical:
┌─────────────────────────┐
│  [Blueprint Library]    │ 300px (arriba)
│  ┌────┐┌────┐┌────┐    │
│  │ BP ││ BP ││ BP │    │
│  └────┘└────┘└────┘    │
├─────────────────────────┤
│  [Cola Crafteo]         │ 200px
│  → → → →                │
├─────────────────────────┤
│  [Minigame Container]   │ 1000px (centro)
│                         │
│    [MINIJUEGO]          │
│                         │
├─────────────────────────┤
│  [Controles/Info]       │ 420px (abajo)
│  Botones grandes        │
│  [Ir a Dungeon]         │
└─────────────────────────┘
```

**Específico**:
- Blueprint library: ScrollContainer horizontal en top
- Cola crafteo: Compact horizontal con íconos pequeños
- Minigame container: Expandir a 1000x800px
- Botones: Tamaño mínimo 80px altura (touch-friendly)

---

#### 5. **Minijuegos - Inputs táctiles**
**Problema**: Minijuegos diseñados para mouse, no touch.

**Archivos a modificar**:
- `scripts/ForgeMinigame.gd`
- `scripts/HammerMinigame.gd`
- `scripts/SewMinigame.gd`
- `scripts/QuenchMinigame.gd`
- `scripts/core/MinigameBase.gd`

**Cambios**:
```gdscript
# Añadir a MinigameBase.gd
func _input(event: InputEvent) -> void:
	# Soportar tanto mouse como touch
	if event is InputEventMouseButton or event is InputEventScreenTouch:
		_handle_touch_input(event.position)
	
	if event is InputEventMouseMotion or event is InputEventScreenDrag:
		_handle_drag_input(event.position)

# Forja: Añadir botones grandes para +/- temperatura
# Martillo: Zona de tap grande y visual
# Coser: Anillos más grandes (min 150px diámetro)
# Agua: Botón grande de soltar con feedback visual
```

**Mejoras visuales**:
- Indicadores táctiles grandes
- Feedback visual inmediato (pulso, color)
- Botones mínimo 80x80px
- Zonas de tap claras con bordes

---

#### 6. **Transición Forja ↔ Dungeon**
**Problema**: Transición confusa, no hay contexto visual.

**Archivos a modificar**:
- `scripts/main.gd`
- `scenes/UI/TransitionScreen.tscn` (crear)

**Cambios**:
```
Crear pantalla de transición:
┌──────────────────────────┐
│                          │
│    [Fade negro]          │
│                          │
│   "Entrando al dungeon..." │
│   "Volviendo a forja..."  │
│                          │
│    [Loader icon]         │
│                          │
└──────────────────────────┘

Duración: 0.5s fade-out + 0.5s fade-in
Incluir texto descriptivo
```

---

### 🟢 **BAJA PRIORIDAD** (Polish y detalles)

#### 7. **Parallax background responsive**
**Archivos**: `scenes/DungeonLayout.tscn`

**Cambios**:
- Ajustar scale de backgrounds para 1080px ancho
- Verificar seamless tiling en scroll
- Optimizar cantidad de layers (3-4 máximo)

---

#### 8. **Fonts escalables y legibles**
**Archivos**: Todos los `.tscn` con Labels

**Cambios**:
```
Tamaños de fuente móvil:
- Títulos: 36px
- Subtítulos: 24px
- Cuerpo: 18px
- Labels pequeños: 14px
- Mínimo: 12px

Usar `theme_override_font_sizes` en todos los labels.
Considerar fuente con mejor legibilidad en mobile.
```

---

#### 9. **Partículas y efectos visuales**
**Archivos**: `scripts/ParticleManager.gd`

**Cambios**:
- Reducir cantidad de partículas en móvil
- Optimizar lifetime y cantidad
- Añadir opción de "FX Low" en settings

---

#### 10. **Animaciones y feedback visual**
**Archivos**: Varios

**Cambios**:
- Héroe: Idle animation cuando no corre
- Enemigos: Animaciones básicas
- UI: Transiciones suaves entre paneles
- Botones: Efectos hover/press táctiles

---

## 📋 Checklist de implementación

### Fase 1 - Funcionalidad core (1-2 sesiones)
- [ ] Cámara limitada a área dungeon
- [ ] HUD combate superior funcional
- [ ] Panel stats inferior mejorado
- [ ] HP bar visual grande
- [ ] Equipment slots con íconos

### Fase 2 - Forja mobile (2-3 sesiones)
- [ ] Layout forja vertical
- [ ] Blueprint library responsive
- [ ] Minigame container expandido
- [ ] Controles táctiles en minijuegos
- [ ] Botones grandes touch-friendly

### Fase 3 - Polish y UX (1-2 sesiones)
- [ ] Transiciones suavizadas
- [ ] Fonts responsive
- [ ] Feedback visual táctil
- [ ] Optimización partículas
- [ ] Testing en diferentes resoluciones

---

## 🧪 Testing checklist

### Viewport targets
- [x] 1080x1920 (9:16 portrait) — PRIMARY
- [ ] 1080x1350 (4:5 cuadrado)
- [ ] 1280x720 (16:9 landscape) — DESKTOP

### Inputs
- [ ] Mouse (desktop)
- [ ] Touch (mobile emulator)
- [ ] Teclado shortcuts

### Performance
- [ ] 60 FPS constante en mobile
- [ ] Sin stutters en transiciones
- [ ] Memoria estable (<200MB)

---

## 🎨 Assets pendientes

### UI Icons (crear o buscar)
- [ ] Arma icon (espada)
- [ ] Armadura icon (pechera)
- [ ] Accesorio icon (anillo)
- [ ] Inventario slots (4 tipos)
- [ ] HP bar gradient texture
- [ ] Mini-mapa dots

### Botones
- [ ] "Volver a Forja" (grande)
- [ ] "Ir a Dungeon" (grande)
- [ ] Minigame controls (+/-, tap, etc)

---

## 📝 Notas técnicas

### Anchors y margins
Usar siempre anchors para UI responsive:
```gdscript
# Top bar
anchors_preset = 10  # Top wide
offset_top = 20

# Bottom panel
anchors_preset = 12  # Bottom wide
offset_top = -768

# Centered
anchors_preset = 8   # Center
```

### Touch input detection
```gdscript
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event.pressed:
			_on_touch_pressed(event.position)
		else:
			_on_touch_released(event.position)
```

### Performance tips
- Usar `CanvasLayer` para UI (no afecta z-index dungeon)
- `visible = false` en lugar de `queue_free()` para reusar nodos
- Cachear referencias `@onready` en lugar de `get_node()` cada frame
- Limitar `_process()` con `set_process(false)` cuando no se necesita

---

## 🚀 Quick wins (implementar YA)

1. **Aumentar font sizes general**: +4px en todos los labels
2. **Margin aumentado en paneles**: 30px en lugar de 20px
3. **Botones mínimo 80px altura**: Todos los botones interactivos
4. **HP bar grande visual**: Reemplazar ProgressBar pequeña por ColorRect + Label

---

## 🔧 Herramientas útiles

### Godot viewport testing
```gdscript
# En main.gd para testing rápido
func _ready():
	get_viewport().size = Vector2(1080, 1920)  # Forzar resolución
```

### Debug overlay
Añadir en `DebugManager.gd`:
- Mostrar resolución actual
- FPS counter grande
- Touch points visualization
- Safe area indicators

---

**Estado actual**: ✅ Layout base ajustado para 1080x1920  
**Siguiente paso**: Implementar Fase 1 (Cámara + HUD combate + Stats mejorados)
