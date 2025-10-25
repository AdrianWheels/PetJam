# 🧵 Sistema de Puntos Aleatorios - Minijuego Sew

## Cambios implementados

### 1. **SewTrialConfig.gd** - Nueva variable de velocidad
- ✅ Cambio: `speed` (0.0-1.0) → `stitch_speed` (0.3-2.5) 
- ✅ Rango más amplio y descriptivo para velocidad de colapso
- ✅ Sincronizado en `_sync_to_parameters()`

### 2. **SewMinigame_NEW.gd** - Sistema de 20 puntos distribuidos
#### Características principales:
- ✅ **20 puntos predefinidos** distribuidos estratégicamente por el panel
- ✅ **Posicionamiento aleatorio**: Cada trial aparece en una posición diferente
- ✅ **Detección mejorada de click**: Solo acepta clicks dentro del círculo colapsando
- ✅ **Márgenes de seguridad**: 80px desde los bordes para evitar recortes

#### Sistema de coordenadas:
```gdscript
SPAWN_POINTS: Array[Vector2] = [
	# Superior: 3 puntos
	Vector2(0.25, 0.25), Vector2(0.5, 0.25), Vector2(0.75, 0.25),
	# Media-Alta: 3 puntos
	Vector2(0.2, 0.4), Vector2(0.5, 0.4), Vector2(0.8, 0.4),
	# Centro: 2 puntos
	Vector2(0.25, 0.5), Vector2(0.75, 0.5),
	# Media-Baja: 3 puntos
	Vector2(0.15, 0.6), Vector2(0.5, 0.6), Vector2(0.85, 0.6),
	# Inferior: 3 puntos
	Vector2(0.25, 0.75), Vector2(0.5, 0.75), Vector2(0.75, 0.75),
	# Extra inferior: 2 puntos
	Vector2(0.3, 0.85), Vector2(0.7, 0.85),
	# Laterales extremos: 2 puntos
	Vector2(0.1, 0.5), Vector2(0.9, 0.5),
	# Diagonales: 2 puntos
	Vector2(0.35, 0.35), Vector2(0.65, 0.65)
]
```

#### Nueva función `_position_at_random_spawn()`:
1. Selecciona punto aleatorio del array de 20 posiciones
2. Convierte coordenadas relativas (0.0-1.0) a píxeles
3. Aplica márgenes de seguridad
4. Posiciona tanto el anillo objetivo como el círculo colapsando

#### Detección de click mejorada:
```gdscript
# Verificar que el cursor esté dentro del círculo
var circle_center := _collapsing_circle.global_position + _collapsing_circle.size / 2.0
var distance_to_center := mouse_pos.distance_to(circle_center)
var current_circle_radius := (_current_radius / START_R) * (_collapsing_circle.size.x / 2.0)

# Solo válido si está dentro
if distance_to_center <= current_circle_radius:
	_judge_hit(...)
```

### 3. **Blueprints actualizados** (.tres)
- ✅ `bow_simple.tres` - stitch_speed: 1.0
- ✅ `armor_leather.tres` - stitch_speed: 1.0
- ✅ Valores por defecto: events=8, precision=0.5, evasion_threshold=0.7

### 4. **Script de editor** - `update_sew_configs.gd`
- ✅ Actualiza masivamente blueprints que falte stitch_speed
- ✅ Preserva otras configuraciones existentes

---

## Testing checklist

### ✅ Tests básicos
- [ ] El minijuego inicia correctamente
- [ ] Los círculos aparecen en posiciones diferentes cada trial
- [ ] Los 8 trials usan posiciones variadas (no repetitivas)
- [ ] El círculo colapsando se reduce hacia el anillo objetivo
- [ ] La velocidad respeta el parámetro `stitch_speed`

### ✅ Tests de interacción
- [ ] Click dentro del círculo colapsando → Se registra el hit
- [ ] Click fuera del círculo colapsando → No hace nada
- [ ] Espacio con cursor dentro del círculo → Funciona igual que click
- [ ] Espacio con cursor fuera del círculo → No registra hit
- [ ] El feedback visual (Perfect/Bien/Regular/Miss) aparece correctamente

### ✅ Tests de posicionamiento
- [ ] Los círculos no se cortan por los bordes del panel
- [ ] La distribución es visualmente equilibrada
- [ ] No hay puntos inaccesibles o fuera de pantalla
- [ ] Las posiciones extremas (esquinas) funcionan correctamente

### ✅ Tests de dificultad
- [ ] stitch_speed bajo (0.5) → Colapso lento, más fácil
- [ ] stitch_speed medio (1.0) → Velocidad balanceada
- [ ] stitch_speed alto (1.8) → Colapso rápido, difícil
- [ ] precision baja (0.3) → Ventanas amplias
- [ ] precision alta (0.8) → Ventanas estrechas

### ✅ Tests responsive (móvil)
- [ ] Los 20 puntos se adaptan a diferentes resoluciones
- [ ] Los márgenes de 80px son suficientes en pantallas pequeñas
- [ ] Touch input funciona igual que mouse click
- [ ] La detección dentro del círculo funciona con touch

### ✅ Tests de progresión
- [ ] Combo se mantiene con hits consecutivos
- [ ] Combo se resetea con miss
- [ ] Puntuación se acumula correctamente
- [ ] El último trial completa el minijuego
- [ ] La pantalla de resultados muestra stats correctos

---

## Valores recomendados por dificultad

### 🟢 Fácil (Early blueprints)
```gdscript
events = 6
stitch_speed = 0.7
precision = 0.3
```

### 🟡 Medio (Mid-game blueprints)
```gdscript
events = 8
stitch_speed = 1.0
precision = 0.5
```

### 🔴 Difícil (Late-game blueprints)
```gdscript
events = 10
stitch_speed = 1.5
precision = 0.7
```

### ⚫ Muy Difícil (Boss/Legendario)
```gdscript
events = 12
stitch_speed = 2.0
precision = 0.85
```

---

## Notas de implementación

### Consideraciones de diseño UI responsive:
1. **Coordenadas relativas (0.0-1.0)**: Permiten adaptación automática a diferentes resoluciones
2. **Márgenes seguros**: 80px desde bordes para evitar recortes en cualquier pantalla
3. **20 puntos estratégicos**: Balance entre variedad y jugabilidad
4. **Detección precisa**: Solo clicks dentro del círculo activo previenen errores

### Mejoras futuras sugeridas:
- [ ] Animación de transición suave entre posiciones
- [ ] Efecto de trail/estela para visualizar trayectoria
- [ ] Haptic feedback en móvil para feedback táctil
- [ ] Predicción de siguiente posición para jugadores avanzados
- [ ] Sistema de patterns (secuencias predefinidas de puntos)

---

## Cómo probar

### En el editor:
1. Abrir `scenes/Minigames/SewOSU.tscn`
2. Ejecutar la escena (F6)
3. Presionar ESPACIO para iniciar
4. Observar que cada trial aparece en posición diferente
5. Probar clicks dentro/fuera del círculo

### En HUD_Forge:
1. Ejecutar Main.tscn (F5)
2. Ir a la forja
3. Seleccionar blueprint con Sew (bow_simple o armor_leather)
4. Verificar que cada trial cambia de posición
5. Completar 8 trials para ver resultado final

### Debugging:
```gdscript
# Añadir en _position_at_random_spawn() para debug visual:
print("📍 Trial %d en posición: %v (relativa: %v)" % 
	[_note_index, _current_spawn_pos, spawn_point])
```

---

## Archivos modificados

✅ `scripts/data/SewTrialConfig.gd` - Nueva variable stitch_speed
✅ `scripts/SewMinigame_NEW.gd` - Sistema de 20 puntos + detección mejorada
✅ `data/blueprints/bow_simple.tres` - Config actualizada
✅ `data/blueprints/armor_leather.tres` - Config actualizada
✅ `addons/editor_scripts/update_sew_configs.gd` - Script de migración

---

## Problemas conocidos y soluciones

### ❌ Los círculos se cortan en los bordes
**Solución**: Ajustar `_margin` en SewMinigame_NEW.gd (actual: 80px)

### ❌ Algunos puntos parecen muy juntos
**Solución**: Modificar array `SPAWN_POINTS` para mejor distribución

### ❌ Click no se registra en touch móvil
**Solución**: Verificar que InputEventScreenTouch se procesa igual que MouseButton

### ❌ Velocidad no cambia entre blueprints
**Solución**: Verificar que `.prepare()` se llama antes de pasar config al minijuego
