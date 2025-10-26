# Sistema de Cursor + Cuerda + Costura para SewOSU

## 📝 Resumen de implementación

### ✅ Sistemas creados

#### 1. **ThreadSpring.gd** - Sistema de cuerda con física
**Ubicación:** `res://scripts/ui/ThreadSpring.gd`

Sistema de cuerda con física realista basado en ley de Hooke:
- ⚙️ **Física spring**: k=120, c=14, m=1, gravedad=400 px/s²
- 📏 **Distancia mínima**: 90px entre cursor y bolita (configurable)
- 🎨 **Visual**: Cuerda cáñamo con sag/belly, sombras y brillos
- 🔴 **Bolita**: Con stroke y nudo en el extremo
- 🐛 **Debug**: Círculo de distancia mínima (activable)

**API:**
```gdscript
enable(initial_pos: Vector2)      # Activa el sistema
disable()                         # Desactiva
update_target(cursor_pos: Vector2) # Actualiza posición cursor
```

#### 2. **StitchVisual.gd** - Sistema de costura visual
**Ubicación:** `res://scripts/ui/StitchVisual.gd`

Renderiza costuras entre puntos con efecto de hilo trenzado:
- 🧵 **Puntadas cruzadas**: Estilo cordones/shoelace
- 🕳️ **Ojetes**: Agujeros por donde pasa el hilo
- 📐 **Líneas guía**: Rails laterales (opcional, desactivable)
- ✨ **Brillo sutil**: Efecto de luz en el hilo
- 🎨 **Configurable**: Espaciado, ancho, grosor, color

**API:**
```gdscript
enable()                    # Activa
disable()                   # Desactiva y limpia
add_point(point: Vector2)   # Añade punto de costura
remove_last_point()         # Elimina último punto
clear_points()              # Limpia todos
get_point_count() -> int    # Retorna número de puntos
```

**Parámetros exportados:**
- `stitch_spacing: float = 28.0`
- `seam_width: float = 12.0`
- `thread_thickness: float = 3.0`
- `thread_color: Color = #6ee7ff`
- `show_guides: bool = false`
- `show_holes: bool = true`

#### 3. **Integración en SewMinigame.gd**
**Ubicación:** `res://scripts/SewMinigame.gd`

##### Cursor custom
- 🖱️ **Path**: `res://art/assets/Imagenes/Cursor/staff_with_cloth_sin_fondo.png`
- 🔒 **Activación**: Solo durante el minijuego activo
- 🔄 **Fallback**: Cursor normal si falla carga
- ✅ **Restauración**: Al finalizar minijuego

Funciones añadidas:
- `_load_custom_cursor()` - Carga en `_ready()`
- `_activate_custom_cursor()` - Activa en `start_game()`
- `_deactivate_custom_cursor()` - Restaura en `_finish_minigame()`

##### Sistemas visuales
- 🧵 **ThreadSpring**: Instanciado en `_ready()`, z_index=-1
- 🪡 **StitchVisual**: Instanciado en `_ready()`, z_index=-2
- 🔄 **Update**: Target del hilo actualizado en `_process()`
- ✅ **Costura**: Punto añadido en `_judge_hit()` si calidad != Miss
- 🧹 **Limpieza**: Desactivados en `_finish_minigame()`

### 🎮 Escenas de prueba

#### 1. ThreadSpringTest.tscn
**Ubicación:** `res://scenes/sandboxes/ThreadSpringTest.tscn`

Prueba aislada del sistema de cuerda:
- Fondo oscuro con instrucciones
- Click para activar/desactivar
- Debug visual activado

#### 2. SewingSystemTest.tscn
**Ubicación:** `res://scenes/sandboxes/SewingSystemTest.tscn`

Prueba combinada de ambos sistemas:
- **Click izquierdo**: Añadir punto de costura
- **Click derecho**: Toggle hilo spring
- **Z**: Deshacer último punto
- **C**: Limpiar todo

**Controlador:** `res://scripts/ui/SewingTestController.gd`

### 🎯 Flujo en SewOSU

```
1. _ready()
   ├─ Cargar cursor custom (fallback si falla)
   ├─ Crear ThreadSpring (z=-1)
   └─ Crear StitchVisual (z=-2)

2. start_game()
   ├─ Activar cursor custom
   ├─ thread_spring.enable(mouse_pos)
   └─ stitch_visual.enable()

3. _process(delta)
   └─ thread_spring.update_target(mouse_pos)

4. _judge_hit(diff, late)
   └─ Si calidad != "Miss":
      └─ stitch_visual.add_point(target_center)

5. _finish_minigame()
   ├─ Deactivar cursor custom
   ├─ thread_spring.disable()
   └─ stitch_visual.disable()
```

### 🎨 Parámetros visuales

#### Cuerda (ThreadSpring)
- Color: `Color(0.886, 0.78, 0.58, 0.95)` - Cáñamo
- Grosor: 3px
- Sag máximo: 140px
- Factor sag: 18% de distancia
- Bolita radio: 12px

#### Costura (StitchVisual)
- Color: `Color(0.43, 0.91, 1.0)` - Cyan (#6ee7ff)
- Espaciado: 28px
- Ancho seam: 12px
- Grosor hilo: 3px
- Ojetes: activados por defecto

### 📂 Archivos creados/modificados

**Nuevos:**
- `scripts/ui/ThreadSpring.gd`
- `scripts/ui/StitchVisual.gd`
- `scripts/ui/SewingTestController.gd`
- `scenes/sandboxes/ThreadSpringTest.tscn`
- `scenes/sandboxes/SewingSystemTest.tscn`

**Modificados:**
- `scripts/SewMinigame.gd` (+70 líneas aprox)

### 🧪 Testing

#### Prueba aislada ThreadSpring
```
1. Abrir ThreadSpringTest.tscn en editor
2. Run Scene (F6)
3. Click para activar
4. Mover mouse → ver cuerda siguiendo con física
```

#### Prueba combinada Sewing
```
1. Abrir SewingSystemTest.tscn
2. Run Scene (F6)
3. Click izq: añadir puntos de costura
4. Click der: activar hilo que cuelga
5. Z: deshacer, C: limpiar
```

#### Prueba en SewOSU
```
1. Iniciar juego normal
2. Entrar a Forja
3. Craftear cualquier blueprint con trial de Sew
4. Observar:
   - Cursor custom activo
   - Hilo colgando desde cursor
   - Costura formándose en aciertos
```

### ✅ Checklist implementación

- [x] Sistema ThreadSpring con física spring
- [x] Sistema StitchVisual con costura realista
- [x] Cursor custom con fallback
- [x] Integración en SewMinigame
- [x] Activación/desactivación contextual
- [x] Update de target en _process
- [x] Añadir puntos en _judge_hit
- [x] Escena de prueba ThreadSpring
- [x] Escena de prueba combinada
- [x] Z-index correcto (hilo=-1, costura=-2)
- [x] Limpieza en _finish_minigame
- [x] **TABS exclusivos** en todo el código

### 🐛 Posibles ajustes

Si necesitas tweakear:

**Cuerda más/menos elástica:**
```gdscript
# En ThreadSpring.gd exports
spring_k: 80-180  # Mayor = más rígida
damping_c: 10-20  # Mayor = más amortiguación
```

**Costura más/menos densa:**
```gdscript
# En StitchVisual.gd exports
stitch_spacing: 15-40  # Menor = más densa
```

**Distancia mínima cursor-bolita:**
```gdscript
# En ThreadSpring.gd export
min_distance: 60-120  # Ajustar a gusto
```

### 📝 Notas finales

- **Rendimiento**: Ambos sistemas usan `_draw()` nativo de Godot, altamente optimizado
- **Tabs**: Todo el código usa **tabs** exclusivamente (sin espacios)
- **Modular**: Sistemas independientes, reutilizables en otros minijuegos
- **Fallback**: Cursor normal si falla carga del custom
- **Debug**: Ambos sistemas tienen flags de debug opcionales

---

**🎉 Listo para probar. Recomendación: empieza por `SewingSystemTest.tscn` para ver ambos sistemas funcionando juntos de forma interactiva.**
