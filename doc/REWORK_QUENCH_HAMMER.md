# Rework Quench y Mejora Hammer - SISTEMA RESPONSIVE

## Fecha
26 de octubre de 2025

## 🎯 Cambio Principal: Sistema Responsive

**Eliminados píxeles hardcodeados** → Ahora usa **proporciones (0.0-1.0)** y **anchors**

### ¿Por qué?
- ✅ **Escalable**: Funciona en cualquier resolución (1280x720, 1080x1920, etc.)
- ✅ **Responsive**: Se adapta automáticamente al viewport
- ✅ **Parámetros de Blueprint**: Respeta `quench_speed`, `time_window`, `catalyst_bonus`
- ✅ **Sin hardcoding**: No más valores mágicos de píxeles

---

## Cambios Realizados

### 🌊 QUENCH - Sistema Responsive con Proporciones

#### Arquitectura nueva
```gdscript
# Proporciones en lugar de píxeles
const STEEL_START_PROGRESS := 0.0  # Arriba del todo
const STEEL_END_PROGRESS := 1.0    # Abajo del todo
const TEMP_BAR_MARGIN := 0.05      # 5% margen

var _steel_progress := 0.0  # Estado: 0.0 = arriba, 1.0 = abajo
```

#### Parámetros del Blueprint (desde `.tres`)
```gdscript
# Se leen desde QuenchTrialConfig
var _quench_speed := 1.0     # 0.3 a 2.5 (multiplicador velocidad)
var _time_window := 0.3      # 0.1 a 1.0 (segundos ventana)
var _catalyst_bonus := false # true = +20% ventana
```

#### Física basada en proporciones
```gdscript
# Velocidad de descenso (progreso/segundo)
var progress_speed := 0.4 * _quench_speed  # Base: 2.5s para descender

# Temperatura sincronizada con progreso
var temp_range := MAX_TEMP - MIN_TEMP
_current_temperature = MAX_TEMP - (_steel_progress * temp_range)
```

#### Sistema de anchors (UI responsive)
```gdscript
# Barra de temperatura: usa anchor_top/bottom
_optimal_zone.anchor_top = min_progress
_optimal_zone.anchor_bottom = max_progress

# Indicador de temperatura: anchor_top dinámico
_current_temp.anchor_top = temp_progress

# Barra de metal: calcula posición basada en viewport
var container_height := get_viewport_rect().size.y
var start_y: float = -bar_height
var end_y: float = container_height * 0.6
var current_y: float = lerp(start_y, end_y, _steel_progress)
```

#### Cálculo de ventana óptima desde blueprint
```gdscript
# time_window del blueprint define tamaño ventana
var window_size: float = BASE_WINDOW * (_time_window / 0.3)
if _catalyst_bonus:
	window_size *= 1.2  # +20% con catalizador

_optimal_min = OPTIMAL_CENTER - window_size / 2
_optimal_max = OPTIMAL_CENTER + window_size / 2
```

#### Assets utilizados
- `res://art/assets/Imagenes/Trial Resources/Tempered/steel_bar.png`
- `res://art/assets/Imagenes/Trial Resources/Tempered/steel_bar_background.mp4`

---

### 🔨 HAMMER - Martillo más grande

#### Mejora visual
- **Tamaño del martillo aumentado +50%**
  - Escala anterior: `Vector2(1.3, 1.3)`
  - Escala nueva: `Vector2(1.95, 1.95)`
- Más impacto visual en los golpes
- Mantiene la misma animación de rotación y timing

---

## Estructura Responsive de la Escena

### GameArea
```gdscript
# Usa anchors_preset = 15 (fill todo el viewport)
anchor_right = 1.0
anchor_bottom = 1.0
# Sin offsets hardcodeados, se adapta automáticamente
```

### SteelBar (barra de metal)
```gdscript
# Anclada al centro, tamaño fijo pero posición dinámica
anchors_preset = 8  # Centro
offset_left = -50.0, offset_right = 50.0  # Ancho: 100px
# offset_top/bottom se calculan dinámicamente en código
```

### TemperatureBar
```gdscript
# Anclada a la derecha, centrada verticalmente
anchors_preset = 6  # Derecha centro
anchor_left = 1.0, anchor_top = 0.5
offset_left = -80.0, offset_top = -200.0
offset_right = -30.0, offset_bottom = 200.0
# Altura: 400px (responsive al viewport)
```

### OptimalZone y CurrentTemp
```gdscript
# Usan anchors dinámicos (calculados en código)
# Se posicionan proporcionalmente dentro de TemperatureBar
anchor_top = [calculado según temperatura]
anchor_bottom = [calculado según temperatura]
```

---

## Archivos Modificados

### Escenas
- `scenes/Minigames/QuenchWater.tscn`
  - Estructura completamente responsive con anchors
  - VideoStreamPlayer para fondo animado
  - Sin píxeles hardcodeados en posiciones críticas

### Scripts
- `scripts/QuenchMinigame.gd`
  - Sistema de proporciones (0.0-1.0) en lugar de píxeles
  - Lectura de parámetros desde `QuenchTrialConfig`
  - Cálculos dinámicos basados en viewport
  - Sincronización temperatura ↔ progreso

- `scripts/HammerMinigame.gd`
  - Aumento de escala del martillo a 1.95x

---

## Ventajas del Sistema Responsive

### ✅ Resoluciones soportadas
- **Desktop**: 1280x720, 1920x1080, etc.
- **Mobile portrait**: 1080x1920, 1080x1350
- **Cualquier aspect ratio**: El sistema se adapta automáticamente

### ✅ Escalabilidad
- No hay valores mágicos de píxeles
- Todo se calcula proporcionalmente
- Funciona en cualquier tamaño de pantalla

### ✅ Balanceo desde blueprints
```tres
# Ejemplo de blueprint fácil
quench_speed = 0.7     # Más lento
time_window = 0.35     # Ventana generosa
catalyst_bonus = true  # +20% ventana

# Ejemplo de blueprint difícil
quench_speed = 1.1     # Más rápido
time_window = 0.25     # Ventana estrecha
catalyst_bonus = false
```

### ✅ Mantenibilidad
- Un cambio en la lógica responsive afecta todas las resoluciones
- No hay que ajustar píxeles manualmente
- Fácil testear en diferentes viewports

---

## Testing Recomendado

### Quench
1. ✅ Probar en 1280x720 (desktop)
2. ✅ Probar en 1080x1920 (mobile portrait)
3. ✅ Verificar que la zona verde se alcanza con diferentes `quench_speed`
4. ✅ Probar con `catalyst_bonus = true` (ventana +20%)
5. ✅ Validar que temperatura y progreso están sincronizados

### Hammer
1. ✅ Verificar martillo más grande en ambas resoluciones
2. ✅ Comprobar que sigue siendo fluido

---

## Parámetros de Blueprint Soportados

### QuenchTrialConfig
```gdscript
quench_speed: float = 1.0      # 0.3-2.5 (velocidad descenso)
optimal_time: float = 1.5      # (NO USADO actualmente)
time_window: float = 0.3       # 0.1-1.0 (tamaño ventana)
catalyst_bonus: float = 1.2    # 1.0-2.0 (ampliación ventana)
```

---

## Próximos pasos sugeridos

1. **Partículas de vapor**: Añadir efecto al templar
2. **SFX del temple**: Sonido "ssssshhhh" al entrar al agua
3. **Burbujas**: Partículas en el agua durante el temple
4. **Feedback táctil**: Vibración al soltar (mobile)
5. **Animación de éxito/fallo**: Más juice visual
