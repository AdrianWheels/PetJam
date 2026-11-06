# ✅ PRUEBA COMPLETADA - Extracción de Animaciones MP4

## 🎯 Objetivo Cumplido

Se ha realizado con éxito la **extracción de fotogramas** del video `hero_walk_01.mp4` con:
- ✅ Eliminación de fondo negro (transparencia)
- ✅ Generación de 4 variantes de FPS (8, 10, 12, 15)
- ✅ Loop perfecto (primer y último frame iguales)
- ✅ Formato spritesheet horizontal para Godot

---

## 📊 Resultados de la Prueba

### Spritesheets Generados

| Variante | Frames | Tamaño | Calidad Visual |
|----------|--------|--------|----------------|
| **8 FPS** | 41 frames | 8.31 MB | Retro, steps visibles |
| **10 FPS** | 51 frames | 10.28 MB | ⭐ **RECOMENDADO** - Balance ideal |
| **12 FPS** | 62 frames | 12.32 MB | Suave, estándar animación |
| **15 FPS** | 77 frames | 15.03 MB | Muy fluido, archivos grandes |

### ⭐ Recomendación Personal

Para **PetJam (Jam de 2D minimal)**:
- **Caminar/Idle**: 10-12 FPS
- **Ataque**: 12 FPS (más dinámico)
- **Muerte**: 8-10 FPS (más dramático)

**Prueba en el comparador para decidir según tu gusto visual.**

---

## 🎮 Cómo Probar AHORA

### Método 1: Desde el Juego (Rápido)
```
1. Abre Godot
2. Ejecuta el proyecto (F5)
3. Presiona F5 en el juego
   → Se abre el comparador de animaciones
```

### Método 2: Escena Directa
```
1. En Godot, abre: scenes/sandboxes/AnimationTestComparison.tscn
2. Ejecuta la escena (F6)
```

### Controles del Comparador

| Tecla | Acción |
|-------|--------|
| **1-4** | Ver variante específica (8, 10, 12, 15 FPS) |
| **0** | Ver todas en grid 2x2 |
| **ESPACIO** | Pausar/reanudar |
| **ESC** | Volver al menú principal |

---

## 🚀 Próximos Pasos

### 1. Decide el FPS ⭐
Después de probar en el comparador, decide qué FPS prefieres:
- Si quieres retro → **8-10 FPS**
- Si quieres fluido → **12-15 FPS**

### 2. Procesa Todas las Animaciones

**Opción A: Script Automático (Recomendado)**
```powershell
# Procesar TODOS los MP4 con 10 y 12 FPS
cd d:\Proyectos\PetJam
.\scripts\tools\process_all_animations.ps1

# Ver qué haría sin ejecutar
.\scripts\tools\process_all_animations.ps1 -DryRun

# Solo Hero
.\scripts\tools\process_all_animations.ps1 -Filter "*hero*"

# Solo Walk
.\scripts\tools\process_all_animations.ps1 -Filter "*walk*"

# Con FPS personalizados
.\scripts\tools\process_all_animations.ps1 -FPSVariants @(8, 12, 15)
```

**Opción B: Manual (Video por Video)**
```powershell
# Hero Attack
.\scripts\tools\extract_animation_frames.ps1 -InputVideo "art/assets/Animaciones/Hero/Attack/hero_attack_01.mp4"

# Hero Death
.\scripts\tools\extract_animation_frames.ps1 -InputVideo "art/assets/Animaciones/Hero/Death/hero_death.mp4"

# Enemies
.\scripts\tools\extract_animation_frames.ps1 -InputVideo "art/assets/Animaciones/Enemies/Attack/grunt_attack.mp4"
```

### 3. Integrar en Godot

Después de decidir el FPS y generar todos los spritesheets:

**A. Actualizar Hero.tscn**
```gdscript
# Reemplazar Sprite2D por AnimatedSprite2D
# Configurar SpriteFrames con:
# - walk: hero_walk_01_12fps.png (62 frames, 12 FPS)
# - attack: hero_attack_01_12fps.png
# - death: hero_death_12fps.png
```

**B. Actualizar Enemy.tscn**
```gdscript
# Similar al héroe
# - idle/walk: grunt/tank walk
# - attack: grunt/tank attack
# - death: grunt/tank death
```

---

## 🛠️ Herramientas Creadas

### Scripts PowerShell
1. **`scripts/tools/extract_animation_frames.ps1`**
   - Extrae frames de un MP4 específico
   - Genera múltiples variantes de FPS
   - Remueve fondo negro automáticamente
   - Cierra loops duplicando primer frame

2. **`scripts/tools/process_all_animations.ps1`**
   - Procesa TODOS los MP4 en batch
   - Filtros opcionales (hero, enemies, walk, etc.)
   - Modo dry-run para ver qué haría

### Escenas Godot
1. **`scenes/sandboxes/AnimationTestComparison.tscn`**
   - Comparador visual interactivo
   - 4 variantes en simultáneo
   - Controles para ver individual o grid

2. **Atajo en Main.gd**
   - Presiona **F5 en el juego** → Abre comparador

---

## 📁 Estructura Generada

```
art/assets/
  Spritesheets/          # NUEVO
    Hero/
      hero_walk_01_8fps.png   (41 frames)
      hero_walk_01_10fps.png  (51 frames)
      hero_walk_01_12fps.png  (62 frames)
      hero_walk_01_15fps.png  (77 frames)
      # Aquí irán el resto al procesarlos
    Enemies/               # Se creará al procesar
      grunt_attack_12fps.png
      tank_death_12fps.png
      ...
    temp_frames/           # Frames individuales (temporal)
      hero_walk_01/
        fps_8/
          frame_0001.png
          frame_0002.png
          ...
```

---

## ⚠️ Notas Importantes

### Fondo Negro
- **Bien removido** ✅ Usando colorkey de FFmpeg
- Si ves restos negros, ajusta tolerancia en `extract_animation_frames.ps1` línea 71:
  ```powershell
  $vfilter += ",colorkey=0x000000:0.15:0.3"  # Aumentar tolerancia
  ```

### Loop Perfecto
- El script **duplica automáticamente** el primer frame al final
- Esto garantiza que la animación sea cíclica sin saltos
- **Respetado en todas las variantes** ✅

### Tamaño de Archivos
- Spritesheets son grandes (8-15 MB cada uno)
- **Normal para assets sin comprimir**
- Godot los comprimirá al exportar (`.import` con compresión)
- Si necesitas reducir: usa FPS más bajo (8-10) o reduce resolución

---

## 🎯 Estado Actual

| Tarea | Estado |
|-------|--------|
| Script de extracción | ✅ Funcional |
| Script batch | ✅ Creado |
| Prueba con hero_walk_01 | ✅ 4 variantes generadas |
| Fondo negro removido | ✅ Transparente |
| Loop cerrado | ✅ Perfecto |
| Comparador visual | ✅ Implementado y corregido |
| Atajo F5 en juego | ✅ Agregado |
| Documentación | ✅ Completa |
| **Animaciones funcionando** | ✅ **TODAS las variantes se animan correctamente** |

**CORRECCIÓN APLICADA (25/10/2025):** Se corrigió el comparador para usar `Sprite2D` con animación manual frame por frame en lugar de `AnimatedSprite2D`. Cada variante ahora tiene su propio acumulador de tiempo independiente.

---

## 💡 Decisión Pendiente

**Ahora es tu turno:**

1. **Abre el comparador** (F5 en juego o ejecuta la escena)
2. **Mira las 4 variantes** de hero_walk_01
3. **Decide qué FPS prefieres** (10-12 recomendado)
4. **Dime cuál elegiste** y procesamos el resto

**Ejemplo de lo que verás:**
```
+------------------+------------------+
|    8 FPS         |    10 FPS        |
| (retro, steps)   | (balance ideal)  |
+------------------+------------------+
|   12 FPS         |    15 FPS        |
| (suave std)      | (muy fluido)     |
+------------------+------------------+
```

---

## 📝 Preguntas Frecuentes

### ¿Puedo cambiar los FPS después?
Sí, solo ejecuta de nuevo el script con diferentes `-FPSVariants`.

### ¿Dónde están los frames individuales?
En `art/assets/Spritesheets/temp_frames/` (puedes borrarlos después).

### ¿Cómo integro en AnimatedSprite2D?
Ver documentación completa en: `doc/SISTEMA_ANIMACIONES_MP4.md`

### ¿Puedo procesar solo algunos videos?
Sí:
```powershell
# Solo walks
.\scripts\tools\process_all_animations.ps1 -Filter "*walk*"

# Solo hero
.\scripts\tools\process_all_animations.ps1 -Filter "*hero*"
```

---

## 🎬 Conclusión

**Sistema de extracción funcional al 100%.**

Todo está listo para:
1. ✅ Comparar variantes visualmente
2. ✅ Decidir FPS óptimo
3. ✅ Procesar todas las animaciones en batch
4. ✅ Integrar en Godot con AnimatedSprite2D

**Siguiente acción:** Abre el comparador y dime qué FPS prefieres. 🚀
