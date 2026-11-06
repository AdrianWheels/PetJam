# 🎮 PetJam - Layout Specification

> **Resolución:** 1080x1920 (portrait 9:16)
> **Plataforma:** Solo smartphone (Android/iOS)

---

## 📐 Layout Principal

```
┌─────────────────────────────────────┐ 0px
│                                     │
│       ESCENA DEL HÉROE              │ ← SubViewport (HeroScene.tscn)
│       (incrustar escena separada)   │    480px altura (~25%)
│                                     │
├─────────────────────────────────────┤ 480px
│                                     │
│                                     │
│       PRUEBAS / MINIJUEGOS          │ ← SubViewport (minigames)
│       (Parte Central)               │    960px altura (~50%)
│                                     │
│                                     │
│                                     │
├───────────────────────┬─────────────┤ 1440px
│  BOTONES TOUCH        │  MENÚ       │
│  (lanzar minijuegos)  │  BLUEPRINTS │ ← Controles
│                       │  Y ENTREGAS │    480px altura (~25%)
├───────────────────────┤             │
│  COLA DE PEDIDOS      │             │
│  (requests activos)   │             │
└───────────────────────┴─────────────┘ 1920px
     756px (70%)          324px (30%)
```

---

## 🧩 Componentes

### 1. Panel Superior: Escena del Héroe (HeroViewPanel)

**Archivo:** `scenes/UI/HeroViewPanel.tscn` (CREAR)

| Propiedad | Valor |
|-----------|-------|
| Tipo | SubViewportContainer |
| Anchors | Top (0, 0, 1, 0.25) |
| Tamaño | 1080 x 480 |
| Contenido | HeroScene.tscn (escena separada) |

**Contenido visible:**
- Fondo parallax del dungeon
- Héroe con animaciones (walk, attack, death)
- Enemigo actual
- Mini barra de HP
- Indicador: "Sala 3/8"

> **IMPORTANTE:** Mantener `HeroScene.tscn` como escena separada para edición independiente. Se incrusta via SubViewport.

---

### 2. Panel Central: Área de Minijuegos (MinigamePanel)

**Archivo:** `scenes/UI/MinigamePanel.tscn` (MODIFICAR existente)

| Propiedad | Valor |
|-----------|-------|
| Tipo | SubViewportContainer |
| Anchors | Center (0, 0.25, 1, 0.75) |
| Tamaño | 1080 x 960 |
| Contenido | Minijuegos dinámicos |

**Minijuegos disponibles:**
1. Forja (temperatura)
2. Martillo (timing)
3. Coser (OSU)
4. Temple (agua)

---

### 3. Panel Inferior Izquierdo: Controles Touch + Cola

**Archivo:** Parte de `HUD_Main.tscn`

| Propiedad | Valor |
|-----------|-------|
| Tipo | VBoxContainer |
| Anchors | Bottom-Left |
| Tamaño | 756 x 480 (70% ancho) |

**Estructura:**
```
VBoxContainer
├── TouchButtonsRow (HBoxContainer)
│   ├── ForgeBtn (icono)
│   ├── HammerBtn (icono)
│   ├── SewBtn (icono)
│   └── QuenchBtn (icono)
│
└── QueuePanel (Panel)
    └── QueueContainer (HBoxContainer)
        ├── RequestSlot1
        ├── RequestSlot2
        └── RequestSlot3
```

> **NOTA:** "Cola de pedidos" = Requests activos del sistema de RequestsManager. NO confundir con menú de blueprints.

---

### 4. Panel Inferior Derecho: Menú Blueprints y Entregas

**Archivo:** Parte de `HUD_Main.tscn`

| Propiedad | Valor |
|-----------|-------|
| Tipo | VBoxContainer |
| Anchors | Bottom-Right |
| Tamaño | 324 x 480 (30% ancho) |

**Estructura:**
```
VBoxContainer
├── BlueprintsBtn (TextureButton)
│   └── Abre BlueprintLibraryPanel
│
└── DeliveryBtn (TextureButton)
    └── Entrega item completado (a cliente o héroe)
```

---

## 🔗 Arquitectura de Escenas

```
Main.tscn
├── Camera2D (fija, no se mueve)
│
├── HUD_Main (CanvasLayer)
│   ├── HeroViewPanel (SubViewportContainer)
│   │   └── SubViewport
│   │       └── HeroScene (instancia de HeroScene.tscn)
│   │
│   ├── MinigamePanel (SubViewportContainer)
│   │   └── SubViewport
│   │       └── [Minigame actual]
│   │
│   ├── BottomLeftPanel (VBox)
│   │   ├── TouchButtons
│   │   └── QueueContainer
│   │
│   └── BottomRightPanel (VBox)
│       ├── BlueprintsBtn
│       └── DeliveryBtn
│
└── PopupLayer (CanvasLayer)
    ├── BlueprintLibraryPanel (popup)
    └── DeliveryPanel (popup)
```

---

## 📏 Medidas Exactas (1080x1920)

| Componente | X | Y | Ancho | Alto |
|------------|---|---|-------|------|
| HeroViewPanel | 0 | 0 | 1080 | 480 |
| MinigamePanel | 0 | 480 | 1080 | 960 |
| BottomLeftPanel | 0 | 1440 | 756 | 480 |
| BottomRightPanel | 756 | 1440 | 324 | 480 |
| TouchButtonsRow | 20 | 1460 | 716 | 200 |
| QueueContainer | 20 | 1680 | 716 | 220 |
| BlueprintsBtn | 776 | 1460 | 284 | 220 |
| DeliveryBtn | 776 | 1700 | 284 | 200 |

---

## 🎨 Clarificación de Términos

| Término | Significado |
|---------|-------------|
| **Cola de Pedidos** | Requests activos (lo que el jugador debe fabricar) |
| **Menú Blueprints** | Biblioteca de blueprints desbloqueados |
| **Entregas** | Botón para entregar item completado |
| **Minijuegos** | Las 4 pruebas de crafteo |

---

**Fecha:** 2026-01-08
**Referencia visual:** `doc/layout/layout.png`
