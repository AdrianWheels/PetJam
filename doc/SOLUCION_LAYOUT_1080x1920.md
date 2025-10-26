# Solución de layout para 1080x1920 (CORREGIDA)

**Fecha**: 2025-10-25  
**Problema resuelto**: Cámara no centraba correctamente el área dungeon en viewport

---

## 🔧 Sistema correcto (áreas separadas)

### Arquitectura de áreas
El juego usa **dos áreas independientes en world space**:

```
World Y=0
    ↓
┌─────────────────────────┐ Y=0 a Y=1920
│   ÁREA FORGE            │
│   (Cámara: 540, 960)    │
│   Background, UI forja  │
└─────────────────────────┘

    ↓ +3000px ↓

┌─────────────────────────┐ Y=3000 a Y=4920
│   ÁREA DUNGEON          │
│   (Cámara: X sigue      │
│    héroe, Y=3576)       │
│   Hero, enemies, etc    │
└─────────────────────────┘
```

### ✅ Por qué funciona así
1. **Ambas áreas renderizan simultáneamente** (no hay scene switching)
2. **Usuario cambia entre áreas** con clic derecho (mueve cámara)
3. **Cámara se mueve** entre Y=960 (forge) y Y=3576 (dungeon)
4. **UI en CanvasLayer** (independiente, siempre visible)

---

## 🎯 Solución aplicada

### Cambio crítico: `Corridor.gd` función `cam_follow()`

**Problema**: La cámara solo seguía al héroe en X, pero no ajustaba Y correctamente.

**Solución**:
```gdscript
func cam_follow(delta: float):
        if hero == null or camera == null:
                return
        # Target X: 33% desde izquierda (hero a la izquierda del viewport)
        var target_x = hero.position.x - 540.0 * 0.33  # 540 = mitad de 1080
        cam_x = lerp(cam_x, target_x, 1.0 - pow(1.0 - CAM_LERP, max(1.0, delta * 60.0)))
        
        # Target Y: Centro del 60% superior del viewport
        # Área dungeon en +3000, viewport 1920, 60% = 1152px
        # Centro: 3000 + 576 (mitad de 1152)
        var target_y = 3000.0 + 576.0  # = 3576
        
        camera.position.x = cam_x
        camera.position.y = target_y  # ← ESTE ERA EL CAMBIO CRÍTICO
```

---

## 📐 Posiciones finales

### Forge
- **Área world**: Y = 0 a 1920
- **Cámara**: `Vector2(540, 960)` (centro viewport)
- **Background**: `Vector2(540, 960)`

### Dungeon  
- **Área world**: Y = 3000 a 4920
- **Cámara**: `Vector2(cam_x, 3576)` 
  - `cam_x`: Sigue al héroe con lerp
  - `3576`: Centro del 60% superior (3000 + 576)
- **Hero spawn**: `Vector2(2100, 4120)` (3000 + 1120)
- **Ground line**: Y = 4150 (3000 + 1150)

### UI Panel (CanvasLayer)
- **Independiente** del world space
- **Anchor**: Bottom (12)
- **Offset top**: -768px (40% de 1920)
- **Visible en ambas áreas**

---

## 🔍 Verificación del sistema

### Cuando estás en Forge:
- Cámara en `(540, 960)`
- Ves: Background forja, label "FORJA"
- Panel UI abajo con stats (aunque está en DungeonUI layer)

### Cuando estás en Dungeon:
- Cámara en `(cam_x, 3576)` 
- Ves: 60% superior = dungeon con hero/enemies
- Panel UI abajo con stats del héroe
- NO ves el área de forge (está 3000px arriba)

### Clic derecho:
- Fade out/in
- Cámara se mueve de Y=960 a Y=3576 (o viceversa)
- UI layers cambian visibilidad

---

## ✅ Archivos modificados (solución correcta)

1. **`scripts/gameplay/Corridor.gd`**: 
   - `cam_follow()`: Añadida línea `camera.position.y = target_y`
   - Cálculo de `target_x` ajustado para 1080px viewport

2. **`scripts/main.gd`**:
   - `forge_camera_pos = Vector2(540, 960)`
   - `dungeon_camera_pos = Vector2(540, 3576)`
   - `corridor.position = Vector2(0, 3000)` ← RESTAURADO

3. **`scenes/Main.tscn`**:
   - `DungeonArea position = Vector2(0, 3000)` ← RESTAURADO
   - `ForgeArea`: Background centrado en `(540, 960)`
   - `HeroStatsPanel`: `offset_top = -768` (40% viewport)

4. **`scenes/DungeonLayout.tscn`**:
   - Sin offsets manuales (posición relativa a DungeonArea)

---

## ⚠️ IMPORTANTE: NO HACER

1. ❌ **NO quitar `DungeonArea position = Vector2(0, 3000)`**
2. ❌ **NO quitar `corridor.position = Vector2(0, 3000)`**
3. ❌ **NO añadir camera limits** (rompe el sistema de áreas)
4. ❌ **NO mover nada a posición 0,0** (áreas deben estar separadas)

---

## 🎮 Flujo de gameplay

```
Usuario inicia juego
    ↓
Forja visible (cámara Y=960)
    ↓
Clic derecho
    ↓
Fade → Cámara se mueve a Y=3576 → Fade in
    ↓
Dungeon visible (60% superior)
    ↓
Héroe corre, cámara sigue en X
Panel UI siempre abajo (CanvasLayer)
```

---

## 📝 Cálculos de referencia

### Viewport 1080x1920
- 60% altura = 1152px (área dungeon visible)
- 40% altura = 768px (panel UI)
- Centro 60%: 1152 / 2 = 576px

### World space dungeon
- Base Y: 3000
- Suelo: 3000 + 1150 = 4150
- Hero spawn: 3000 + 1120 = 4120
- Cámara centro: 3000 + 576 = 3576

### Cámara X (sigue héroe)
- Hero X: variable (corre a la derecha)
- Cámara X: `hero.x - 540 * 0.33` = hero.x - 178.2
- Resultado: Héroe a ~33% desde la izquierda

---

**Estado**: ✅ Sistema de áreas separadas restaurado y funcional  
**Fix aplicado**: Cámara Y ahora se centra correctamente en área dungeon

---

## 🔧 Cambios aplicados

### 1. **Eliminado offset de DungeonArea**
**Archivo**: `scenes/Main.tscn`
- **Antes**: `position = Vector2(0, 3000)`
- **Después**: Sin offset (posición 0,0)
- **Razón**: El sistema de "áreas separadas verticalmente" causaba problemas con el viewport

### 2. **Eliminado offset de DungeonLayout**
**Archivo**: `scenes/DungeonLayout.tscn`
- **Antes**: `position = Vector2(0, -98)`
- **Después**: Sin offset (posición 0,0)
- **Razón**: Eliminamos offsets manuales para centralizar control en cámara

### 3. **Corridor sin offset**
**Archivo**: `scripts/main.gd` línea 40
- **Antes**: `corridor.position = Vector2(0, 3000)`
- **Después**: `corridor.position = Vector2(0, 0)`

### 4. **Cámara con límites**
**Archivo**: `scripts/main.gd` función `_ready()`
```gdscript
camera.limit_left = -9999
camera.limit_right = 9999
camera.limit_top = 0
camera.limit_bottom = 1152  # 60% de 1920
```
**Razón**: La cámara ahora está limitada al área superior (dungeon) y no puede ver el panel inferior

### 5. **Posiciones de cámara actualizadas**
**Archivo**: `scripts/main.gd` líneas 19-21
```gdscript
var forge_camera_pos := Vector2(540, 400)   # Centro forja
var dungeon_camera_pos := Vector2(540, 576) # Centro dungeon (60% = 576)
```
**Razón**: Adaptado para viewport 1080x1920 con cámara centrada en área visible

### 6. **ForgeArea centrada**
**Archivo**: `scenes/Main.tscn`
- Background: `position = Vector2(540, 400)` (centro 1080x800)
- Label: Reposicionado y aumentado font a 48px

---

## 📐 Sistema actual

### Viewport: 1080x1920
```
┌─────────────────────────┐ Y=0
│                         │
│    ÁREA DUNGEON         │ 60% (1152px)
│    (Cámara limitada)    │
│                         │
│    Héroe, enemigos,     │
│    backgrounds          │
│                         │
├─────────────────────────┤ Y=1152 (limit_bottom)
│                         │
│    PANEL UI             │ 40% (768px)
│    (CanvasLayer)        │
│                         │
│    Stats, equipo,       │
│    inventario           │
│                         │
└─────────────────────────┘ Y=1920
```

### Comportamiento de cámara
- **En FORJA**: Cámara en Y=400, muestra área forja
- **En DUNGEON**: Cámara en Y=576 (centro del 60%), sigue al héroe horizontalmente
- **Límite bottom**: 1152px (no puede ver el panel UI inferior)
- **Panel UI**: Siempre anclado abajo, visible en ambas áreas

---

## ✅ Ventajas del sistema actual

1. **Cámara controlada**: Límites evitan que se vea contenido no deseado
2. **UI persistente**: Panel inferior siempre visible (CanvasLayer)
3. **Sin offsets manuales**: Todo en posición world 0,0, más predecible
4. **Responsive**: Anchors de UI funcionan correctamente
5. **Performance**: No hay áreas duplicadas ni offsets complejos

---

## 🎯 Elementos en world space

### Dungeon (Node2D, sin offset)
- `DungeonLayout`: Backgrounds, líneas, decoraciones
- `Corridor`: Héroe, enemigos (spawn Y=1120)
- `Hero`: Sprite animado, scale 4.5x
- `Enemy`: Sprite rojo, scale 4.5x

### Forja (Node2D, sin offset)
- `AnimatedForgeBackground`: Animación de forja
- `ForgeLabel`: Texto "FORJA"

### UI (CanvasLayer, independiente de world)
- `ForgeUI`: HUD de forja, paneles, blueprints
- `DungeonUI`: HUD dungeon, HeroStatsPanel
- `FadeLayer`: Overlay de transiciones

---

## 🐛 Debugging

Si el dungeon aparece mal posicionado:

1. **Verificar offsets en escenas**:
```bash
# Buscar offsets no deseados
grep -r "position = Vector2" scenes/
```

2. **Verificar límites de cámara**:
```gdscript
# En _ready() de main.gd
print("Camera limits: ", camera.limit_top, " to ", camera.limit_bottom)
print("Camera pos: ", camera.position)
```

3. **Verificar viewport**:
```gdscript
# En project.godot o display settings
Display/Window/Size/Viewport_width = 1080
Display/Window/Size/Viewport_height = 1920
```

4. **Test manual**:
- Activar "Visible Collision Shapes" en debug
- Verificar línea de suelo en Y=1150
- Héroe spawn en Y=1120 (30px sobre suelo)

---

## 🔄 Flujo de cambio de área

```
Usuario: Clic derecho o botón
    ↓
main.gd: change_area(&"dungeon")
    ↓
UIManager: show_dungeon()
    ↓
Fade out → Callback → Fade in
    ↓
_apply_area_locally():
  - forge_ui.visible = false
  - dungeon_ui.visible = true
  - camera.position = Vector2(540, 576)
  - corridor.visible = true
```

---

## 📝 Notas importantes

1. **No mover DungeonArea**: Debe estar en Vector2(0, 0)
2. **No mover Corridor**: Debe estar en Vector2(0, 0)
3. **No tocar camera limits**: Ya configurados para 60%/40%
4. **UI usa anchors**: No hardcodear posiciones en UI
5. **CanvasLayer independiente**: No afecta world space

---

## 🎨 Próximos pasos (según PLAN_MEJORAS_UI_MOBILE.md)

1. [ ] HUD combate superior (sala, enemigo, estado)
2. [ ] HP bar visual grande en panel stats
3. [ ] Equipment slots con íconos
4. [ ] Botón "Volver a Forja" visible
5. [ ] Forja layout vertical optimizado

---

**Estado**: ✅ Layout base corregido y funcional  
**Pendiente**: Implementar mejoras visuales del plan
