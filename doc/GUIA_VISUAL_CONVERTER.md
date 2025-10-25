# 🎯 Guía Visual Rápida — Conversión de Blueprints

## Paso 1: Abrir Godot

```
┌─────────────────────────────────────────┐
│  Godot Engine v4.5                     │
├─────────────────────────────────────────┤
│  FileSystem         │  Scene           │
│  ├─ scenes/         │                  │
│  │  ├─ sandboxes/  │                  │
│  │  │  └─ Blueprint│                  │
│  │  │     Converter │   ← AQUÍ        │
│  │  │     .tscn     │                  │
│  ├─ scripts/        │                  │
│  ├─ data/           │                  │
└─────────────────────────────────────────┘
```

**Acción:** Doble-clic en `BlueprintConverter.tscn`

---

## Paso 2: Ejecutar la Scene

```
┌─────────────────────────────────────────┐
│  BlueprintConverter.tscn (*)           │
├─────────────────────────────────────────┤
│  [▶ Play Scene (F6)]  ← PRESIONA ESTO │
│                                         │
│  Node Tree:                            │
│  └─ BlueprintConverter (Control)      │
│     └─ MarginContainer                │
│        └─ VBoxContainer               │
│           ├─ Title                     │
│           ├─ Description               │
│           ├─ ConvertButton             │
│           └─ LogOutput                 │
└─────────────────────────────────────────┘
```

**Acción:** Presiona **F6** o el botón ▶ "Play Scene"

---

## Paso 3: Convertir Blueprints

```
┌────────────────────────────────────────────┐
│  🔧 Conversor de Blueprints               │
├────────────────────────────────────────────┤
│  Convierte blueprints del sistema antiguo  │
│  al nuevo sistema con configs específicos  │
│  (ForgeTrialConfig, HammerTrialConfig...)  │
│                                            │
│  ─────────────────────────────────────────│
│                                            │
│  Esperando...                              │
│  [████████████████████] 100%               │
│                                            │
│  ╔══════════════════════════════════════╗ │
│  ║  ▶ Convertir Blueprints             ║ │  ← CLIC AQUÍ
│  ╚══════════════════════════════════════╝ │
│                                            │
│  ─────────────────────────────────────────│
│                                            │
│  Log de conversión:                        │
│  ┌──────────────────────────────────────┐ │
│  │ === Iniciando conversión ===        │ │
│  │ [1/16] Procesando: sword_basic.tres │ │
│  │   ✓ Convertido: ForgeTrialConfig   │ │
│  │   ✓ Blueprint guardado             │ │
│  │ [2/16] Procesando: axe_iron.tres   │ │
│  │   ✓ Convertido: HammerTrialConfig  │ │
│  └──────────────────────────────────────┘ │
└────────────────────────────────────────────┘
```

**Acción:** Clic en el botón grande. Espera a que termine.

---

## Paso 4: Verificar Conversión

```
┌─────────────────────────────────────────┐
│  sword_basic.tres — Inspector           │
├─────────────────────────────────────────┤
│  📦 BlueprintResource                   │
│   ├─ blueprint_id: "sword_basic"        │
│   ├─ display_name: "Espada básica"     │
│   └─ trial_sequence (2)                │
│       ├─ [0] TrialResource             │
│       │   └─ config: ForgeTrialConfig  │ ← MIRA ESTO
│       │       ├─ temp_window_base: 90  │
│       │       │   [━━━━━━━|━━━━] 150   │ ← SLIDER
│       │       ├─ hardness: 0.3         │
│       │       │   [━━|━━━━━━━━] 1.0    │ ← SLIDER
│       │       ├─ precision: 0.5        │
│       │       │   [━━━━━|━━━━] 1.0     │ ← SLIDER
│       │       └─ label: "Forja"        │
│       │                                │
│       └─ [1] TrialResource             │
│           └─ config: HammerTrialConfig │
│               ├─ notes: 5              │
│               │   [━━━━━|━━━━] 10      │ ← SLIDER
│               ├─ tempo_bpm: 85         │
│               │   [━━━━|━━━━━━] 180    │ ← SLIDER
│               └─ ...                   │
└─────────────────────────────────────────┘
```

**Éxito:** Si ves sliders y campos individuales, ¡funcionó! 🎉

---

## Paso 5: Editar Dificultad

```
ANTES (Dictionary no editable):
┌──────────────────────────┐
│ parameters: Dictionary   │  ← No se puede editar bien
│   • hardness: 0.3        │
│   • precision: 0.5       │
│   • temp_window_base: 90 │
└──────────────────────────┘

DESPUÉS (Propiedades @export):
┌────────────────────────────────┐
│ Temp Window Base: 90.0         │
│ [━━━━━━━|━━━━━━] 30-150       │ ← AJUSTABLE
│                                │
│ Hardness: 0.3                  │
│ [━━|━━━━━━━━━━] 0.0-1.0       │ ← AJUSTABLE
│                                │
│ Precision: 0.5                 │
│ [━━━━━|━━━━━━] 0.0-1.0        │ ← AJUSTABLE
│                                │
│ Label: "Espada básica"         │
│ [___________________________]  │ ← EDITABLE
└────────────────────────────────┘
```

**Acción:** Arrastra sliders, cambia valores, guarda (`Ctrl+S`).

---

## ⚠️ Importante

### ❌ NO hacer:
- Intentar ejecutar desde VS Code (no funciona)
- Editar `.tres` en un editor de texto (rompe formato)
- Cambiar script a `TrialConfig.gd` después de convertir

### ✅ SÍ hacer:
- Ejecutar desde Godot con F6
- Editar blueprints en el Inspector de Godot
- Guardar cambios antes de cerrar

---

## 📖 ¿Qué significan los parámetros?

### Forja (Temperatura)
- **Temp Window Base** (30-150): Ancho de zona verde. ↓ = más difícil
- **Hardness** (0-1): Velocidad del cursor. ↑ = más difícil
- **Precision** (0-1): Penalización por error. ↑ = más difícil

### Martillo (Timing)
- **Notes** (3-10): Cantidad de golpes. ↑ = más largo
- **Tempo BPM** (60-180): Velocidad del ritmo. ↑ = más difícil
- **Precision** (0-1): Ventana de acierto. ↓ = más difícil

### Coser (OSU)
- **Events** (4-12): Cantidad de círculos. ↑ = más largo
- **Speed** (0-1): Velocidad de colapso. ↑ = más difícil
- **Precision** (0-1): Ventana de acierto. ↓ = más difícil

### Temple (Agua)
- **Optimal Time** (0.5-3.0): Tiempo ideal en segundos
- **Time Window** (0.1-1.0): Tolerancia. ↓ = más difícil
- **Catalyst Bonus** (1.0-2.0): Ampliación con catalizador

---

## 🎮 Ejemplo: Crear un ítem difícil

```
Espada Legendaria (Hard Mode):

ForgeTrialConfig:
  temp_window_base: 50.0    # Zona muy estrecha
  hardness: 0.8             # Cursor muy rápido
  precision: 0.9            # Castigo severo por error

HammerTrialConfig:
  notes: 9                  # Muchos golpes
  tempo_bpm: 160            # Ritmo frenético
  precision: 0.2            # Ventana muy pequeña
  weight: 0.3               # Martillo ligero (difícil de controlar)

SewTrialConfig:
  events: 12                # Máximos círculos
  speed: 0.9                # Colapso rapidísimo
  precision: 0.3            # Ventana minúscula

QuenchTrialConfig:
  optimal_time: 0.8         # Ventana muy corta
  time_window: 0.15         # Tolerancia mínima
```

Guarda estos valores y prueba en el juego. ¡Ajusta hasta encontrar el balance perfecto!

---

## 🆘 ¿Problemas?

**"No veo la herramienta en Godot"**
→ Asegúrate de que existe `res://scenes/sandboxes/BlueprintConverter.tscn`

**"Error al ejecutar"**
→ Verifica que las nuevas clases estén registradas: Project → Reload Current Project

**"Los cambios no se aplican"**
→ Guarda el blueprint (Ctrl+S) y reinicia el juego (F5)

**"Quiero revertir cambios"**
→ Usa Git: `git checkout -- data/blueprints/`

---

📚 **Documentación completa:** `doc/BLUEPRINT_DIFICULTAD_EDITOR.md`
