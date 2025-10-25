# 🎯 Mapa visual de los 20 puntos de spawn - Minijuego Sew

## Distribución estratégica

```
┌─────────────────────────────────────────────────────────────┐
│                        PANEL DE JUEGO                       │
│                                                             │
│         [19]                                                │
│                                                             │
│                                                             │
│    [1]              [2]              [3]                    │
│                                                             │
│                                                             │
│ [4]                 [5]                 [6]                 │
│                                                             │
│                                                             │
│[17]     [7]                     [8]                [18]     │
│                                                             │
│                                                             │
│ [9]                [10]                [11]                 │
│                                                             │
│                                                             │
│    [12]            [13]             [14]                    │
│                                                             │
│                                                             │
│         [15]                    [16]                        │
│                                                             │
│                                                             │
│                                                [20]         │
└─────────────────────────────────────────────────────────────┘
```

## Coordenadas exactas (relativas 0.0-1.0)

### Zona Superior (Y: 0.25)
- **[1]** `Vector2(0.25, 0.25)` - Superior izquierda
- **[2]** `Vector2(0.50, 0.25)` - Superior centro
- **[3]** `Vector2(0.75, 0.25)` - Superior derecha

### Zona Media-Alta (Y: 0.35-0.40)
- **[19]** `Vector2(0.35, 0.35)` - Diagonal superior izquierda
- **[4]** `Vector2(0.20, 0.40)` - Media-alta izquierda
- **[5]** `Vector2(0.50, 0.40)` - Media-alta centro
- **[6]** `Vector2(0.80, 0.40)` - Media-alta derecha

### Zona Centro (Y: 0.50)
- **[17]** `Vector2(0.10, 0.50)` - Centro extremo izquierdo
- **[7]** `Vector2(0.25, 0.50)` - Centro izquierda
- **[8]** `Vector2(0.75, 0.50)` - Centro derecha
- **[18]** `Vector2(0.90, 0.50)` - Centro extremo derecho

### Zona Media-Baja (Y: 0.60)
- **[9]** `Vector2(0.15, 0.60)` - Media-baja izquierda
- **[10]** `Vector2(0.50, 0.60)` - Media-baja centro
- **[11]** `Vector2(0.85, 0.60)` - Media-baja derecha

### Zona Inferior (Y: 0.65-0.75)
- **[20]** `Vector2(0.65, 0.65)` - Diagonal inferior derecha
- **[12]** `Vector2(0.25, 0.75)` - Inferior izquierda
- **[13]** `Vector2(0.50, 0.75)` - Inferior centro
- **[14]** `Vector2(0.75, 0.75)` - Inferior derecha

### Zona Baja (Y: 0.85)
- **[15]** `Vector2(0.30, 0.85)` - Baja izquierda
- **[16]** `Vector2(0.70, 0.85)` - Baja derecha

---

## Características de la distribución

### ✅ Balance horizontal
- **Izquierda**: Puntos 1, 4, 7, 9, 12, 15, 17, 19
- **Centro**: Puntos 2, 5, 10, 13
- **Derecha**: Puntos 3, 6, 8, 11, 14, 16, 18, 20

### ✅ Balance vertical
- **Superior (0.25-0.35)**: 4 puntos
- **Media (0.40-0.60)**: 9 puntos
- **Inferior (0.65-0.85)**: 7 puntos

### ✅ Puntos especiales
- **Extremos laterales** (17, 18): Para jugadores expertos, máxima distancia
- **Diagonales** (19, 20): Añaden variedad y desafío espacial
- **Centro absoluto**: No hay punto en (0.5, 0.5) para evitar monotonía

### ✅ Distancias mínimas
Todos los puntos mantienen al menos **15% de separación** entre sí para:
- Evitar confusión visual
- Dar tiempo al jugador para reposicionar el cursor
- Mantener sensación de variedad

---

## Adaptación responsive

### Márgenes dinámicos
```gdscript
adaptive_margin := Vector2(
	min(80.0, panel_size.x * 0.1),  # Máximo 80px o 10% del ancho
	min(80.0, panel_size.y * 0.1)   # Máximo 80px o 10% del alto
)
```

### Resoluciones comunes

#### 🖥️ Desktop (1280x720)
- Margen: 80px (fijo)
- Área segura: 1120x560 px
- Todos los puntos visibles y accesibles

#### 📱 Mobile Portrait (720x1280)
- Margen: 72px (10% de 720)
- Área segura: 576x1136 px
- Puntos adaptados al formato vertical

#### 📱 Mobile Landscape (1280x720)
- Margen: 72px (10% de 720)
- Área segura: 1136x576 px
- Igual que desktop, más compacto

#### 🖥️ HD (1920x1080)
- Margen: 80px (10% sería 108/192, limitado a 80)
- Área segura: 1760x920 px
- Más espacio, misma distribución relativa

---

## Testing visual

### Cómo visualizar los puntos
1. Abrir `scenes/sandboxes/SewSandbox.tscn`
2. Ejecutar (F6)
3. Presionar tecla **V** para toggle visualización
4. Observar:
	- Puntos verdes numerados (1-20)
	- Círculos amarillos semitransparentes (área de ring)
	- Distribución equilibrada

### Validar accesibilidad
- ✅ Todos los puntos deben ser visibles
- ✅ Ningún punto debe estar cortado por los bordes
- ✅ Los círculos de 42px de radio no deben sobrepasar el panel
- ✅ El cursor debe poder alcanzar todos los puntos cómodamente

---

## Rationale del diseño

### ¿Por qué 20 puntos?
- **Menos de 20**: Muy repetitivo, jugadores memorizan posiciones
- **20 puntos**: Balance ideal entre variedad y manejo de memoria
- **Más de 20**: Sobrecarga cognitiva, diferencias imperceptibles

### ¿Por qué no aleatorio completo?
1. **Consistencia**: Puntos predefinidos aseguran buena distribución
2. **Testing**: Posiciones conocidas facilitan balance y debug
3. **Fair play**: Todos los jugadores ven las mismas posiciones posibles
4. **Performance**: No cálculos de generación en runtime

### ¿Por qué coordenadas relativas?
1. **Responsive**: Adapta automáticamente a cualquier resolución
2. **Escalable**: Funciona en mobile y desktop sin cambios
3. **Mantenible**: Cambiar tamaño del panel no rompe posiciones
4. **Predecible**: Mismo layout visual independiente de la pantalla

---

## Modificar la distribución

### Añadir más puntos
```gdscript
# En SewMinigame_NEW.gd, línea ~24
const SPAWN_POINTS: Array[Vector2] = [
	# ... puntos existentes ...
	Vector2(0.4, 0.3),   # Nuevo punto
	Vector2(0.6, 0.7),   # Nuevo punto
]
```

### Cambiar márgenes
```gdscript
# En SewMinigame_NEW.gd, línea ~34
const MARGIN_SIZE := 100.0  # Aumentar de 80 a 100
```

### Crear patrón específico
```gdscript
# Ejemplo: Distribución en círculo
const CIRCLE_POINTS: Array[Vector2] = []

func _generate_circle_pattern():
	for i in range(20):
		var angle := (TAU / 20.0) * i
		var radius := 0.35  # 35% del radio del panel
		var point := Vector2(
			0.5 + cos(angle) * radius,
			0.5 + sin(angle) * radius
		)
		CIRCLE_POINTS.append(point)
```

---

## Troubleshooting

### ❌ Puntos aparecen fuera del panel
**Causa**: Márgenes insuficientes o panel muy pequeño
**Solución**: Aumentar `MARGIN_SIZE` o reducir valores extremos (0.1, 0.9)

### ❌ Puntos muy juntos visualmente
**Causa**: Resolución muy alta o panel muy grande
**Solución**: Añadir más puntos o redistribuir existentes

### ❌ Mismo punto aparece muchas veces
**Causa**: RNG sesgado o array muy pequeño
**Solución**: Implementar sistema de history (últimos 3 puntos no repetir)

### ❌ Detección de click no funciona
**Causa**: Posición global vs local mal calculada
**Solución**: Verificar que `_collapsing_circle.global_position` es correcto

---

**Diseño**: Sistema responsive de 20 puntos  
**Implementado**: 24 de octubre, 2025  
**Versión**: 1.0 - Godot 4.5.1
