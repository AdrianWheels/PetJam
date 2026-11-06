# PetJam — Plan de limpieza del proyecto

> **Última actualización**: 2026-02-07  
> Este documento lista archivos y carpetas candidatos a eliminación o reorganización.

---

## 1. Archivos eliminables con seguridad

Estos archivos no están referenciados en código activo y se pueden borrar directamente.

### Prototipos HTML (pre-desarrollo)
| Archivo | Motivo |
|---------|--------|
| `agua.html` | Prototipo HTML del minijuego de agua. Sin referencias en GDScript. |
| `coser.html` | Prototipo HTML del minijuego de coser. |
| `hero.html` | Prototipo HTML del héroe. |
| `martillo.html` | Prototipo HTML del minijuego de martillo. |
| `temperatura.html` | Prototipo HTML del minijuego de temperatura. |

### Build artifacts (raíz)
| Archivo | Motivo |
|---------|--------|
| `PetJam.pck` (raíz) | Artefacto de build. Duplicado de EXE/. |
| `EXE/` (carpeta completa) | Builds exportados. No pertenece al repo. |

### Documentación obsoleta
| Archivo | Motivo |
|---------|--------|
| `SOLUCION_ERRORES.txt` | Log de errores one-time ya resueltos. |

### Archivos temporales y backups
| Archivo | Motivo |
|---------|--------|
| `scenes/sandboxes/*.tmp` | Archivos temporales de Godot. |
| `scripts/gameplay/resources/DropTable.gd.broken` | Backup rota de DropTable. |

### Godot docs clone
| Archivo | Motivo |
|---------|--------|
| `doc/godotdocu/` (carpeta completa) | **Clon completo de la documentación de Godot** con su propio `.git/`. Potencialmente gigabytes. No pertenece al proyecto. |

---

## 2. Archivos a confirmar antes de eliminar

### Escenas y scripts legacy
| Archivo | Estado | Acción recomendada |
|---------|--------|-------------------|
| `scenes/MainNew.tscn` | **ELIMINADO** — integrado en Main.tscn | ✅ Hecho |
| `scripts/MainSimplified.gd` + `.uid` | **ELIMINADO** — no existía | ✅ Hecho |
| `scenes/Room.tscn` | Marcado "obsoleto" en copilot-instructions. | **Eliminar** |
| `scripts/BlueprintQueueSlot_TOOL_VERSION.gd` + `.uid` | Versión @tool para editor preview. | **Eliminar** si no se usa |
| `scenes/UI/GameOverScreen.tscn` | No hay game over en endless. | **Eliminar** (o conservar para futuro debug) |

### HUD backups
| Archivo | Estado | Acción |
|---------|--------|--------|
| `scenes/UI/HUD.tscn.bak` | Backup del HUD antiguo. | **Eliminar** |
| `scenes/UI/HUD_manual.tscn.bak` | Backup manual. | **Eliminar** |

### Sandboxes
| Carpeta | Estado | Acción recomendada |
|---------|--------|-------------------|
| `scenes/sandboxes/` | Escenas de test para desarrollo. | **Conservar** para testing individual de minijuegos. Marcar como dev-only. |

### Tools
| Carpeta | Estado | Acción recomendada |
|---------|--------|-------------------|
| `scripts/tools/` | Scripts de pipeline (PS1, PY, debug GD). | **Conservar** pero documentar que son herramientas de desarrollo. |
| `addons/editor_scripts/` | Scripts de editor para blueprints. | **Conservar** — útiles para workflow. |

---

## 3. Archivos a mover (reorganizar)

| Archivo actual | Destino propuesto |
|---------------|-------------------|
| `GUIA_EXPORTACION.md` | → `doc/GUIA_EXPORTACION.md` |
| `RESUMEN_PRUEBA_ANIMACIONES.md` | → `doc/RESUMEN_PRUEBA_ANIMACIONES.md` |
| `RESUMEN_SEW_PUNTOS_ALEATORIOS.md` | → `doc/RESUMEN_SEW_PUNTOS_ALEATORIOS.md` |

---

## 4. .gitignore — Entradas a añadir

```gitignore
# Build outputs
EXE/
*.pck
*.exe
*.console.exe
*.rar

# Runtime logs
logs/

# Temp files
*.tmp

# Godot editor
.godot/
```

---

## 5. Duplicados a verificar

| Archivo | Duplicado de | Acción |
|---------|-------------|--------|
| `scripts/ParticleManager.gd` | `scripts/core/ParticleManager.gd` | Verificar cuál usa `Corridor.tscn` y eliminar el otro |
| `art/assets/Sonidos/` | `art/sounds/ambient/` | Mismo contenido. `assets/` es el subrepo raw. Solo mantener `art/sounds/`. |

---

## 6. Código legacy en autoloads (refactoring menor)

Estos cambios no requieren borrar archivos pero sí limpiar código:

| Archivo | Qué limpiar |
|---------|-------------|
| `GameManager.gd` | Eliminar `MAX_DEATHS`, `DungeonState.COMPLETED`, `DungeonState.FAILED`. Quitar game_over logic. |
| `AudioManager.gd` | Simplificar a un solo contexto (GLOBAL). Arreglar leak de `duck_music()`. |
| `UIManager.gd` | Eliminar `show_forge()`, `show_dungeon()`, `area_changed` signal. |
| `CraftingManager.gd` | Eliminar `_enqueue_defaults()` (dead code). |
| `DataManager.gd` | Eliminar `get_all_blueprints()` (duplicado de `get_blueprints()`). |
| Varios | Reemplazar `print()` directos por `DebugManager` categorizado. |

---

## Orden de ejecución recomendado

1. **Añadir entradas a `.gitignore`** (seguro, sin impacto)
2. **Eliminar archivos seguros** (HTML prototypes, SOLUCION_ERRORES.txt, build artifacts, doc/godotdocu/)
3. **Eliminar archivos confirmados** (MainNew, Room.tscn, backups .bak)
4. **Mover documentación** a `doc/`
5. **Verificar duplicados** (ParticleManager, sonidos)
6. **Limpiar código legacy** en autoloads
7. **Commit**: `chore: project cleanup — remove legacy files, update docs`
