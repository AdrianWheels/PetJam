# Sistema de Drag & Drop e Integración de Calidad

## Cambios Implementados

### 1. **QualityHelper.gd - Helper Centralizado de Calidad** ✨
**Archivo**: `scripts/core/QualityHelper.gd` (NUEVO)

Helper estático que centraliza toda la lógica de colores y tiers de calidad:

```gdscript
QualityUtils.get_quality_tier(quality)      # legendary/epic/rare/uncommon/common
QualityUtils.get_quality_color(quality)     # Color del outline
QualityUtils.get_quality_label(quality)     # LEGENDARIO, ÉPICO, etc.
QualityUtils.get_quality_percent(quality)   # 0-100
QualityUtils.create_quality_border_style()  # StyleBoxFlat con borde
```

**Ventajas**:
- DRY: No duplicar lógica de colores
- Consistencia: Mismo sistema en popup de crafteo y dungeon
- Fácil ajuste: Cambiar umbrales en un solo lugar

### 2. **ItemInfoPanel Actualizado** 🎨
**Archivo**: `scripts/forge/ItemInfoPanel.gd`

El popup que aparece al completar un crafteo ahora usa el sistema centralizado:

**Cambios**:
- ✅ Usa `QualityUtils` para colores consistentes
- ✅ Calcula quality normalizada (0-100%)
- ✅ Muestra tier en español con color (LEGENDARIO, ÉPICO, etc.)
- ✅ Aplica borde de calidad al panel si existe `%ItemPanel`

**Resultado**: El popup de la imagen ahora mostrará:
- "Calidad: RARO" en color azul (70-89%)
- "Puntaje: 79%" con el porcentaje exacto
- Borde azul alrededor del panel

### 3. **DungeonHUD con Drag & Drop** 🖱️
**Archivo**: `scripts/ui/DungeonHUD.gd`

#### Items Cuadrados
- ✅ Slots de items ahora son **100x100 cuadrados**
- ✅ Icono centrado de **80x80**
- ✅ Label de calidad con **color del tier**

#### Sistema Drag & Drop Completo
```gdscript
# Arrastrar item desde inventario
_get_drag_data_item()
  → Crea preview visual con borde de calidad
  → Devuelve CraftedItem como data

# Validar drop en slot
_can_drop_on_equipment()
  → Verifica compatibilidad item-slot
  → Feedback visual: verde=compatible, rojo=no

# Soltar en slot
_drop_on_equipment()
  → Equipa el item
  → Animación de flash blanco
  → Actualiza stats y UI
```

#### Restricciones de Slot
| Slot | Tipo Permitido |
|------|----------------|
| Casco | `head` |
| Arma | `main_hand` |
| Escudo | `off_hand` |
| Botas | `feet` |
| Armadura | `body` |

**Validación**:
- ✅ Solo items compatibles pueden dropearse
- ✅ Feedback visual en tiempo real
- ✅ Items incompatibles se rechazan

### 4. **Limpieza de UI Legacy** 🧹

#### Removido:
- ❌ Label "FORJA" (gigante en ForgeArea) - eliminado de `Main.tscn`
- ❌ `HUD_Hero.tscn` - marcado como legacy (no usado en ninguna escena)

**Razón**: El feedback visual ya es claro:
- Área de forja tiene fondo animado característico
- Dungeon tiene layout visual propio con ground/ceiling
- DungeonHUD muestra toda la info necesaria

## Flujo de Uso

### Equipar Item via Drag & Drop:
```
1. Player craftea item → aparece en inventario dungeon
2. Player hace drag del item → preview visual sigue el cursor
3. Player arrastra sobre slot de equipamiento
   → Slot se pone VERDE si compatible
   → Slot se pone ROJO si incompatible
4. Player suelta
   → Si compatible: item se equipa + flash visual
   → Stats del héroe se actualizan automáticamente
```

### Visual del Borde de Calidad:
```
Item calidad 79% (RARO):
┌─────────────────┐  ← Borde azul 3px
│  ╔═══════════╗  │
│  ║  [ICONO]  ║  │  ← 80x80 centrado
│  ╚═══════════╝  │
│      79%        │  ← Label azul
└─────────────────┘  ← 100x100 total
```

## Colores de Calidad (Centralizados)

| Tier | Rango | Color | Código |
|------|-------|-------|--------|
| LEGENDARIO | 99-100% | 🟠 Naranja | `Color.ORANGE` |
| ÉPICO | 90-98% | 🟣 Morado | `Color.PURPLE` |
| RARO | 70-89% | 🔵 Azul | `Color.DODGER_BLUE` |
| COMÚN | 40-69% | 🟢 Verde | `Color.GREEN` |
| BÁSICO | 0-39% | ⚪ Blanco | `Color.WHITE` |

## Archivos Modificados/Creados

### Nuevos:
- ✅ `scripts/core/QualityHelper.gd` (70 líneas)
- ✅ `doc/SISTEMA_DRAG_DROP.md` (este archivo)

### Modificados:
- ✅ `scripts/forge/ItemInfoPanel.gd` (integración QualityHelper)
- ✅ `scripts/ui/DungeonHUD.gd` (+150 líneas drag & drop)
- ✅ `scenes/Main.tscn` (removido ForgeLabel)

### Legacy (no usado):
- 📦 `scenes/UI/HUD_Hero.tscn`

## Testing Checklist

- [ ] Craftear item y ver popup con color de tier correcto
- [ ] Item aparece en inventario dungeon como cuadrado 100x100
- [ ] Arrastrar item muestra preview con borde de calidad
- [ ] Arrastrar item compatible sobre slot → verde
- [ ] Arrastrar item incompatible sobre slot → rojo
- [ ] Soltar item compatible → se equipa + flash
- [ ] Soltar item incompatible → se rechaza
- [ ] Stats del héroe se actualizan al equipar
- [ ] Equipar segundo item del mismo tipo reemplaza el anterior
- [ ] Calidad legendaria (99-100%) muestra borde naranja
- [ ] Labels "FORJA" y "HÉROE" ya no aparecen

## Próximos Pasos Sugeridos

1. **Shader para borde en PNG**: 
   - Crear shader que detecte bordes del alpha channel
   - Aplicar glow del color de calidad respetando transparencia
   
2. **Animaciones de equipamiento**:
   - Partículas al equipar épico+
   - Sonido de "clink" al equipar
   
3. **Tooltip de items**:
   - Mostrar stats detallados al hover
   - Comparación con item equipado actual
   
4. **Desequipar items**:
   - Drag desde slot equipado al inventario
   - Botón de "Desequipar todo"
   
5. **Filtros de inventario**:
   - Mostrar solo armas / solo armaduras
   - Ordenar por calidad / tipo

## Notas Técnicas

### ¿Por qué QualityHelper es una clase con statics?
- No necesita instanciarse
- Funciones puras sin estado
- Rápido acceso desde cualquier script
- Evita crear autoload para algo tan simple

### ¿Por qué preload en vez de autoload?
- QualityHelper es ligero (solo funciones estáticas)
- No necesita persistir entre escenas
- Preload es más eficiente para helpers pequeños
- Evita ensuciar el namespace global

### Drag & Drop API de Godot 4.x
```gdscript
# En el nodo draggable:
set_drag_forwarding(
    Callable(self, "_get_drag_data"),  # Inicia drag
    Callable(),                         # Can drop (vacío)
    Callable()                          # Drop (vacío)
)

# En el nodo receptor:
set_drag_forwarding(
    Callable(),                         # Get data (vacío)
    Callable(self, "_can_drop"),        # Valida
    Callable(self, "_drop")             # Ejecuta drop
)
```
