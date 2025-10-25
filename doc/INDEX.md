# 📚 Índice de Documentación del Proyecto

## 🚀 Guías de Inicio Rápido

### Para Desarrolladores Nuevos
1. **[README.md](../README.md)** — GDD completo y overview del proyecto
2. **[VSCODE_GODOT_WORKFLOW.md](VSCODE_GODOT_WORKFLOW.md)** — Cómo trabajar con VS Code + Godot
3. **[REGISTRO_AUTOLOADS.md](REGISTRO_AUTOLOADS.md)** — Setup de singletons del proyecto

### Para Balance y Diseño
1. **[BLUEPRINT_DIFICULTAD_EDITOR.md](BLUEPRINT_DIFICULTAD_EDITOR.md)** — Editar dificultad visualmente
2. **[GUIA_VISUAL_CONVERTER.md](GUIA_VISUAL_CONVERTER.md)** — Guía paso a paso con "capturas"
3. **[scenes/sandboxes/README_CONVERTER.md](../scenes/sandboxes/README_CONVERTER.md)** — Uso de herramienta de conversión

---

## 🎨 Arte y Assets

- **[asset_guidelines.md](asset_guidelines.md)** — Normas de arte y placeholders
- **[art/placeholders/README.md](../art/placeholders/README.md)** — Especificaciones de placeholders

---

## 🔧 Implementación Técnica

### Fase 1 (Completada)
- **[FASE1_RESUMEN_IMPLEMENTACION.md](FASE1_RESUMEN_IMPLEMENTACION.md)** — Resumen de MVP inicial
- **[TESTING_FASE1_CHECKLIST.md](TESTING_FASE1_CHECKLIST.md)** — Checklist de testing
- **[AISLAMIENTO_IMPLEMENTADO.md](AISLAMIENTO_IMPLEMENTADO.md)** — Sistema de aislamiento de contextos

### Minijuegos
- **[INFORME_MINIJUEGOS_FORJA.md](INFORME_MINIJUEGOS_FORJA.md)** — Implementación de Forja
- **[FLUJO_CORREGIDO_MINIJUEGOS.md](FLUJO_CORREGIDO_MINIJUEGOS.md)** — Flujo de minijuegos corregido
- **[MEJORAS_MINIJUEGOS_VISUALES.md](MEJORAS_MINIJUEGOS_VISUALES.md)** — Mejoras visuales
- **[MINIGAME_VISUAL_THEME.md](MINIGAME_VISUAL_THEME.md)** — Tema visual consistente
- **[LIMPIEZA_TEMPMINIGAME.md](LIMPIEZA_TEMPMINIGAME.md)** — Limpieza de código temporal

### Audio
- **[MIGRACION_AUDIO_CONTEXTOS.md](MIGRACION_AUDIO_CONTEXTOS.md)** — Sistema de audio contextual
- **[ACTIVACION_CONTEXTUAL_AUDIO.md](ACTIVACION_CONTEXTUAL_AUDIO.md)** — Activación por contexto
- **[MINIGAME_SOUNDSET_QUICKSTART.md](MINIGAME_SOUNDSET_QUICKSTART.md)** — Guía rápida de audio

### Editor y Herramientas
- **[EDITAR_LAYOUT_VISUALMENTE.md](EDITAR_LAYOUT_VISUALMENTE.md)** — Editar layouts en editor
- **[EDITOR_PREVIEW_GUIDE.md](EDITOR_PREVIEW_GUIDE.md)** — Previsualizaciones en editor
- **[AISLAMIENTO_FORJA_DUNGEON.md](AISLAMIENTO_FORJA_DUNGEON.md)** — Aislamiento de sistemas
- **[PASOS_TESTING_AISLAMIENTO.md](PASOS_TESTING_AISLAMIENTO.md)** — Testing de aislamiento

---

## 📋 Planes y Roadmap

- **[AGENTE_PLAN.md](AGENTE_PLAN.md)** — Plan de desarrollo por agente
- **[PLAN_IMPLEMENTACION_MEJORAS.md](PLAN_IMPLEMENTACION_MEJORAS.md)** — Plan de mejoras

---

## 🔍 Documentación por Tema

### Sistema de Crafteo
```
├─ BLUEPRINT_DIFICULTAD_EDITOR.md    ← ⭐ Editar blueprints visualmente
├─ GUIA_VISUAL_CONVERTER.md          ← ⭐ Guía paso a paso
├─ scenes/sandboxes/README_CONVERTER.md
└─ data/blueprints/                   ← Archivos de blueprints
```

### Minijuegos
```
├─ INFORME_MINIJUEGOS_FORJA.md
├─ FLUJO_CORREGIDO_MINIJUEGOS.md
├─ MEJORAS_MINIJUEGOS_VISUALES.md
├─ MINIGAME_VISUAL_THEME.md
├─ MINIGAME_SOUNDSET_QUICKSTART.md
└─ scenes/Minigames/
    ├─ ForgeTemp.tscn
    ├─ HammerMinigame.tscn
    ├─ SewMinigame.tscn
    └─ QuenchMinigame.tscn
```

### Audio
```
├─ MIGRACION_AUDIO_CONTEXTOS.md
├─ ACTIVACION_CONTEXTUAL_AUDIO.md
├─ MINIGAME_SOUNDSET_QUICKSTART.md
├─ scripts/autoload/AudioManager.gd
└─ data/minigame_sounds_default.tres
```

### Editor y Workflow
```
├─ VSCODE_GODOT_WORKFLOW.md          ← ⭐ Cómo usar VS Code + Godot
├─ EDITAR_LAYOUT_VISUALMENTE.md
├─ EDITOR_PREVIEW_GUIDE.md
└─ REGISTRO_AUTOLOADS.md
```

---

## 🎯 Documentos Clave por Rol

### 🎨 Diseñador de Niveles / Balance
1. **BLUEPRINT_DIFICULTAD_EDITOR.md** — Ajustar dificultad de ítems
2. **GUIA_VISUAL_CONVERTER.md** — Tutorial visual
3. **asset_guidelines.md** — Normas de arte

### 💻 Programador
1. **FASE1_RESUMEN_IMPLEMENTACION.md** — Estado actual del código
2. **VSCODE_GODOT_WORKFLOW.md** — Setup de entorno
3. **REGISTRO_AUTOLOADS.md** — Arquitectura de singletons
4. **AISLAMIENTO_IMPLEMENTADO.md** — Sistema de contextos

### 🎵 Diseñador de Audio
1. **MINIGAME_SOUNDSET_QUICKSTART.md** — Implementar audio rápido
2. **ACTIVACION_CONTEXTUAL_AUDIO.md** — Sistema contextual
3. **MIGRACION_AUDIO_CONTEXTOS.md** — Migración de sistema antiguo

### 🎮 Tester / QA
1. **TESTING_FASE1_CHECKLIST.md** — Checklist de testing
2. **PASOS_TESTING_AISLAMIENTO.md** — Testing de sistemas aislados
3. **README.md** → Sección "Godot 4.5 Setup" — Configuración inicial

---

## 🆕 Documentos Recientes (Octubre 2025)

- ✨ **BLUEPRINT_DIFICULTAD_EDITOR.md** — Sistema de edición visual de dificultad
- ✨ **GUIA_VISUAL_CONVERTER.md** — Guía con "capturas" ASCII
- ✨ **VSCODE_GODOT_WORKFLOW.md** — Workflow VS Code + Godot
- ✨ **scenes/sandboxes/README_CONVERTER.md** — Herramienta de conversión

---

## 📞 Convenciones del Proyecto

### Nombres de Archivos
- **MAYUSCULAS_CON_GUIONES.md** → Documentación técnica
- **lowercase_snake_case.md** → Guías y tutoriales
- **PascalCase.gd** → Clases de GDScript
- **snake_case.gd** → Scripts y herramientas

### Estructura de Documentos
```markdown
# Título Principal

## TL;DR (resumen ejecutivo)

## Contexto / Problema

## Solución

## Cómo usar

## Troubleshooting

## Referencias
```

---

## 🔗 Referencias Externas

- **Godot Docs**: https://docs.godotengine.org/en/4.5/
- **GDScript Reference**: https://docs.godotengine.org/en/stable/classes/
- **Godot Community**: https://godotengine.org/community

---

## 🤝 Contribuir

Al añadir nueva documentación:
1. Sigue las convenciones de nombres
2. Añade entrada a este índice
3. Incluye TL;DR al inicio
4. Añade ejemplos de código cuando aplique
5. Actualiza referencias cruzadas

---

**Última actualización:** Octubre 24, 2025  
**Mantenedor:** Equipo PetJam
