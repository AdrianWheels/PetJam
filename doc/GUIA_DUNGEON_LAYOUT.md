# Guía de Personalización del DungeonLayout

## 📋 Resumen de Implementación

Se ha creado un **DungeonLayout visual y manipulable** que reemplaza el sistema anterior de spawn calculado por código.

**IMPORTANTE:** El sistema visual (DungeonLayout) convive con la lógica de juego (Corridor). 
- **DungeonLayout**: Fondos, decoración, markers de posición
- **Corridor**: Hero, Enemy, combate (lógica)
- Los fondos viejos de Corridor están **desactivados** para evitar doble renderizado

### ✅ Archivos Creados/Modificados

1. **`scenes/DungeonLayout.tscn`** — Escena principal del layout de dungeon
2. **`scripts/gameplay/DungeonLayout.gd`** — Script que gestiona zonas y spawns
3. **`scripts/gameplay/Corridor.gd`** — Modificado para usar DungeonLayout
4. **`scenes/Corridor.tscn`** — Desactivados `ParallaxBG` y `BackgroundWalls` (visible=false)
5. **`scenes/Main.tscn`** — Integra DungeonLayout en DungeonArea
6. **`scripts/main.gd`** — Añadido @onready para dungeon_area
7. **`.github/copilot-instructions.md`** — Actualizado con info de resolución móvil

---

## 📱 Resoluciones y Display

### Configuración Actual

**Desktop (base de diseño):**
- Resolución: 1280x720 (16:9)
- Aspect ratio: Widescreen estándar

**Móvil (viewport actual):**
- Resolución: 1080x1350 (4:5 portrait)
- Aspect ratio: Más cuadrado que 16:9

### ¿Es correcta la resolución móvil actual?

**1080x1350 es válida**, pero hay opciones mejores dependiendo del target:

| Resolución | Aspect | Uso recomendado |
|------------|--------|-----------------|
| **1080x1920** | 9:16 | ✅ **RECOMENDADO** - Portrait estándar, más común en móviles |
| **1080x1350** | 4:5 | ✅ Válido - Formato tipo Instagram, más cuadrado |
| **720x1280** | 9:16 | ✅ Budget móviles, mismo aspect que 1080x1920 |
| **1080x2400** | 9:20 | ⚠️ Pantallas extra largas (Samsung S20+, etc.) |

### Recomendación para este Proyecto

**Para jam/prototipo:**
- Mantén **1080x1350** si vas a publicar en web (formato tipo móvil casual)
- Cambia a **1080x1920** si apuntas a App Store/Google Play

**Para producción:**
- Usa **1080x1920** (9:16) como base
- Diseña UI con **safe areas** para notches
- Testea en 720x1280 para dispositivos low-end

### Cómo Cambiar Resolución

1. Abre `Project > Project Settings > Display > Window`
2. Cambia:
   - `Viewport Width`: 1080
   - `Viewport Height`: 1920 (o la que elijas)
3. Asegúrate de que `Stretch Mode` = `2d`
4. Ajusta `Width` y `Height` (ventana desktop) proporcionalmente

### Consideraciones de Layout

Con **1080x1350**:
- ✅ Más espacio vertical para UI de forja
- ⚠️ Menos espacio horizontal para el corredor
- ⚠️ DungeonLayout puede necesitar ajustes de zoom

Con **1080x1920**:
- ✅ Formato móvil estándar
- ✅ Mejor para corredor horizontal
- ⚠️ UI de forja puede sentirse "apretada" verticalmente

**Tip:** Usa `Control` nodes con `anchors` para que la UI se adapte a ambas resoluciones.

---

## 🎨 Cómo Personalizar Visualmente

### 1. Abrir DungeonLayout en el Editor

1. En Godot, navega a `res://scenes/DungeonLayout.tscn`
2. Haz doble clic para abrirla en el editor 2D

### 2. Estructura del Árbol de Nodos

```
DungeonLayout (Node2D) — Script: DungeonLayout.gd
├─ ParallaxBackground (Node2D) — Fondos en capas
│   ├─ BackLayer, BackLayer2, etc. (Sprite2D)
├─ TileMap (Node2D) — Líneas de suelo/techo placeholder
│   ├─ FloorLine (Line2D)
│   └─ CeilingLine (Line2D)
├─ Decorations (Node2D) — Antorchas, props
│   ├─ Torch_01 a Torch_Boss (Label con emoji 🔥)
├─ HeroSpawn (Marker2D) — Posición inicial del héroe
└─ RoomZones (Node2D) — Contenedor de salas
    ├─ Room_01 (Area2D)
    │   ├─ ZoneRect (ColorRect) — Visualización de zona
    │   ├─ RoomLabel (Label) — "Sala 1"
    │   └─ EnemySpawn (Marker2D) — Spawn del enemigo
    ├─ Room_02 (Area2D)
    └─ ... hasta Room_09 (BOSS)
```

---

## 🔧 Tareas Comunes de Personalización

### A. Añadir TileMap Real

**Actualmente:** Líneas placeholder  
**Mejora:** TileMap con texturas

1. Selecciona el nodo `TileMap`
2. Bórralo y crea un nuevo nodo `TileMap` (con TileSet)
3. Asigna tu TileSet con tiles de dungeon
4. Pinta el suelo y las paredes desde X=0 hasta X=6000 (cubre las 9 salas)

**Recomendación de Layout:**
- **Suelo**: Y=490 a Y=540
- **Techo/Paredes**: Y=100 a Y=450
- **Ancho total**: ~6000px (600px por sala × 9 + margen)

### B. Reemplazar Antorchas por Sprites Animados

1. En `Decorations`, selecciona `Torch_01`
2. Borra el nodo Label
3. Añade `AnimatedSprite2D` con tu spritesheet de antorcha
4. Repite para las demás antorchas

**Posiciones actuales:**
- Torch_01: X=400
- Torch_02: X=1000
- Torch_03: X=1600
- Torch_04: X=2200
- Torch_05: X=2800
- Torch_06: X=3400
- Torch_07: X=4000
- Torch_08: X=4600
- Torch_Boss: X=5200

### C. Añadir Decoración por Sala

Puedes añadir decoración específica dentro de cada `Room_XX`:

```
Room_03 (Area2D)
├─ ZoneRect
├─ RoomLabel
├─ EnemySpawn
└─ (NUEVO) Decoration
    ├─ Pillar (Sprite2D)
    ├─ Barrel (Sprite2D)
    └─ Chain (AnimatedSprite2D)
```

### D. Ajustar Posiciones de Spawn

**Para cambiar dónde spawnea cada enemigo:**

1. Selecciona `RoomZones > Room_XX > EnemySpawn`
2. Mueve el Marker2D en el editor 2D
3. El código usa `.global_position` automáticamente

**Para el héroe:**

1. Selecciona `HeroSpawn` (raíz de DungeonLayout)
2. Muévelo a la posición deseada

### E. Personalizar la Sala del Boss

La sala 9 ya tiene diferenciación visual:
- `ZoneRect` con color rojo (Color(0.6, 0.2, 0.2, 0.15))
- `RoomLabel` con texto "SALA BOSS" en rojo
- Emoji de corona 👑

**Mejoras sugeridas:**
- Añadir más decoración intimidante
- Cambiar el fondo (añadir sprites únicos)
- Añadir partículas de fuego/humo

---

## 🎯 Espaciado y Distribución de Salas

### Posiciones Actuales (X)

| Sala | Posición X | Separación |
|------|------------|------------|
| Hero Spawn | 100 | — |
| Room_01 | 620 | 520px |
| Room_02 | 1220 | 600px |
| Room_03 | 1820 | 600px |
| Room_04 | 2420 | 600px |
| Room_05 | 3020 | 600px |
| Room_06 | 3620 | 600px |
| Room_07 | 4220 | 600px |
| Room_08 | 4820 | 600px |
| Room_09 (Boss) | 5420 | 600px |

**Total de recorrido:** ~5320px

### Cambiar Espaciado

Si quieres salas más juntas o separadas:

1. Selecciona `Room_XX`
2. Cambia su `position.x` en el Inspector
3. Mantén coherencia (ej: todas a 500px de separación)

**Recomendación:** Mantén al menos 400-500px entre salas para que el héroe tenga tiempo de recorrer.

---

## 🔍 Sistema de Zonas (Area2D)

Cada `Room_XX` es un `Area2D` que **puede detectar triggers**:

```gdscript
# Ejemplo: Detectar cuando el héroe entra a una sala
func _ready():
	var room_05 = get_node("RoomZones/Room_05")
	room_05.body_entered.connect(_on_room_05_entered)

func _on_room_05_entered(body):
	if body.is_in_group("hero"):
		print("¡Héroe entró a la Sala 5!")
		# Aquí puedes: activar música boss, spawnear efectos, etc.
```

**Futuras expansiones:**
- Puertas que se cierran al entrar
- Trampas activadas por zona
- Cambios de iluminación

---

## 📐 Parallax y Fondos

Actualmente hay 5 capas de fondo (`BackLayer` 1-5) que cubren el área.

**Para añadir parallax real:**

1. Reemplaza el nodo `ParallaxBackground (Node2D)` por `ParallaxBackground` (nodo específico de Godot)
2. Añade nodos `ParallaxLayer` hijos
3. Configura `motion_scale` para cada capa (ej: 0.3, 0.5, 0.7)

---

## 🧪 Testing en el Editor

### Ver el Layout Completo

1. Abre `DungeonLayout.tscn`
2. En la toolbar superior, ajusta el **Zoom** al 10-25%
3. Verás las 9 salas en línea horizontal

### Probar en Runtime

1. Ejecuta `Main.tscn` (F5)
2. Haz clic derecho del ratón para cambiar a Dungeon
3. Observa que:
   - El héroe spawnea en la posición del marker `HeroSpawn`
   - Los enemigos spawnean en las posiciones de cada `Room_XX/EnemySpawn`
   - La cámara sigue al héroe a través del layout

### Verificar Posiciones en Consola

Busca en el output de Godot:
```
DungeonLayout: Ready with 9 room zones
Corridor: DungeonLayout found at ...
Corridor: Using DungeonLayout hero spawn: (100, 460)
Corridor: Using DungeonLayout spawn position for level 1: (620, 460)
```

---

## 🎨 Próximos Pasos Creativos

### Fase 1: Reemplazar Placeholders
- [ ] Crear/importar TileSet de dungeon
- [ ] Pintar suelo, paredes, techo con tiles
- [ ] Reemplazar emojis de antorcha con sprites animados
- [ ] Añadir sprites de fondo (columnas, arcos)

### Fase 2: Decoración por Sala
- [ ] Sala 1-3: Dungeon básico (antorchas, barriles)
- [ ] Sala 4-6: Dungeon intermedio (cadenas, huesos)
- [ ] Sala 7-8: Dungeon avanzado (sangre, runas)
- [ ] Sala 9: Arena del boss (altar, fuego, símbolos)

### Fase 3: FX y Ambiente
- [ ] Partículas de polvo en todas las salas
- [ ] Luces dinámicas (PointLight2D en antorchas)
- [ ] Añadir neblina (CanvasModulate o shaders)
- [ ] Sistema de parallax multi-capa

### Fase 4: Mecánicas Avanzadas
- [ ] Puertas que se abren al derrotar enemigo
- [ ] Trampas activadas por `Area2D`
- [ ] Eventos especiales (spawn de cofre, buff temporal)
- [ ] Transiciones visuales entre salas

---

## 🐛 Troubleshooting

### El héroe/enemigo no spawnea en las posiciones correctas

**Causa:** DungeonLayout no se encuentra en el árbol  
**Solución:** Verifica en consola que aparezca:
```
Corridor: DungeonLayout found at ...
```

Si no aparece:
1. Asegúrate de que `DungeonLayout` es hijo de `DungeonArea` en `Main.tscn`
2. Verifica que `DungeonLayout.tscn` tenga el script asignado

### Las decoraciones no se ven

**Causa:** Z-index incorrecto o posición fuera de cámara  
**Solución:**
1. Revisa que `DungeonLayout` tenga `z_index = -5`
2. Verifica que `Decorations` no tenga `z_index` negativo excesivo
3. Comprueba que la cámara esté centrada en el área dungeon (Y=3360)

### Los enemigos spawnean todos en el mismo lugar

**Causa:** Los markers `EnemySpawn` no tienen posiciones únicas  
**Solución:**
1. Abre `DungeonLayout.tscn`
2. Selecciona cada `Room_XX` y verifica que su `position.x` sea diferente
3. Los `EnemySpawn` heredan la posición del padre `Room_XX`

---

## 📚 Referencia Técnica

### API de DungeonLayout.gd

```gdscript
class_name DungeonLayout

# Obtiene posición de spawn para enemigo de nivel especificado
func get_enemy_spawn_for_level(level: int) -> Vector2

# Obtiene posición inicial del héroe
func get_hero_spawn() -> Vector2

# Verifica si el nivel es el boss
func is_boss_level(level: int) -> bool

# Obtiene la zona de sala para el nivel (para triggers)
func get_room_zone(level: int) -> Area2D
```

### Constantes en DungeonLayout.gd

```gdscript
const FALLBACK_SPAWN := Vector2(620, 460)  # Spawn por defecto si falla
const ROOM_SPACING := 600.0  # Separación estándar entre salas
```

---

## 💡 Consejos Finales

1. **Itera en pequeños pasos:** Primero reemplaza placeholders, luego añade decoración
2. **Usa grupos de nodos:** Agrupa decoraciones similares para editarlas en batch
3. **Guarda versiones:** Crea copias de `DungeonLayout.tscn` antes de cambios grandes
4. **Prueba frecuentemente:** Ejecuta el juego cada vez que añadas decoración para ver el resultado
5. **Mantén el performance:** No añadas cientos de nodos; usa TileMap para repetición

---

🎉 **¡El layout de dungeon ahora es completamente visual y manipulable!** 🎉
