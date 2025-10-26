# Limpieza de Debug y Actualización de Stats en HUD

**Fecha**: 26 octubre 2025  
**Contexto**: Reducir debug de animaciones y mostrar stats del héroe en `DungeonHUD.tscn`

---

## Problemas Identificados

1. **Debug excesivo de animaciones**: Cada cambio de animación imprimía en consola:
   ```
   Hero: Changed animation to ATTACK (hframes=62, fps=24.0, scale=(0.079468, 0.161616))
   Hero: Changed animation to WALK (hframes=63, fps=24.0, scale=(0.080750, 0.164103))
   Enemy: Changed animation to ATTACK (hframes=62, fps=24.0)
   ```

2. **Stats no visibles en DungeonHUD**: El HUD mostraba STR/AGI/INT pero faltaban:
   - DMG, APS, CRIT, ARMOR (stats reales de combate)
   - Estado visual del héroe (Running/Attacking/Dying)

3. **HUD_Hero.tscn legacy**: Confirmado como escena obsoleta (marcada `visible = false` y deshabilitada en `UIManager.gd` + `main.gd`)

---

## Cambios Implementados

### 1. **Reducción de Debug en Animaciones**

**Archivos modificados**:
- `scripts/gameplay/Hero.gd` (línea ~148)
- `scripts/gameplay/Enemy.gd` (línea ~169)

**Cambio**: Comentar prints de debug de animaciones:
```gdscript
# DEBUG: Descomentar para debug de animaciones
# print("Hero: Changed animation to %s (hframes=%d, fps=%.1f, scale=%v)" % [...])
```

**Resultado**: Logs de animaciones desactivados por defecto. Descomentar solo para debugging específico.

---

### 2. **Actualización de Stats en DungeonHUD**

**Archivo modificado**: `scenes/UI/DungeonHUD.tscn`

**Cambios en el .tscn**:
- ❌ **Eliminados**: `STRLabel`, `AGILabel`, `INTLabel` (stats primarios poco relevantes para gameplay)
- ✅ **Añadido**: `ARMORLabel` (muestra armadura del héroe)
- ✅ **Mantenidos**: `DMGLabel`, `APSLabel`, `CRITLabel` (stats de combate críticos)

**Nueva estructura de StatsGrid**:
```
DMG: 28.0       APS: 1.33
CRIT: 11.9%     ARMOR: 6
```

---

### 3. **Script DungeonHUD.gd**

**Archivo modificado**: `scripts/ui/DungeonHUD.gd`

**Cambios**:

#### A. Declaraciones de labels (líneas 5-15):
```gdscript
# ELIMINADO: @onready var str_label, agi_label, int_label
# AÑADIDO:
@onready var armor_label: Label = $MainPanel/.../StatsGrid/ARMORLabel
```

#### B. Función `_update_stats_silent()` (actualización en tiempo real):
```gdscript
func _update_stats_silent() -> void:
	# HP actual
	if hp_bar:
		hp_bar.max_value = hero_ref.max_hp
		hp_bar.value = hero_ref.hp
	
	if hp_label:
		hp_label.text = "%d/%d" % [hero_ref.hp, hero_ref.max_hp]
	
	# Stats de combate
	if dmg_label:
		dmg_label.text = "DMG: %.1f" % hero_ref.dmg
	
	if aps_label:
		aps_label.text = "APS: %.2f" % hero_ref.aps
	
	if crit_label:
		crit_label.text = "CRIT: %.1f%%" % (hero_ref.crit_p * 100.0)
	
	if armor_label:
		armor_label.text = "ARMOR: %d" % hero_ref.armor
	
	# Estado visual del héroe (NUEVO)
	if state_label and hero_ref.has("current_anim_state"):
		var state_text = ""
		match hero_ref.current_anim_state:
			0:  # IDLE
				state_text = "Estado: Parado"
				state_label.modulate = Color.GRAY
			1:  # WALK
				state_text = "Estado: Corriendo"
				state_label.modulate = Color.WHITE
			2:  # ATTACK
				state_text = "Estado: Atacando"
				state_label.modulate = Color.ORANGE
			3:  # DEATH
				state_text = "Estado: Muriendo"
				state_label.modulate = Color.RED
		state_label.text = state_text
```

#### C. Función `_update_stats()` (debug inicial):
- Eliminados prints y lógica de STR/AGI/INT
- Añadido print de ARMOR

---

### 4. **Hero.gd - Variable Armor**

**Archivo modificado**: `scripts/gameplay/Hero.gd`

**Cambios**:

#### A. Declaración de variable (línea ~25):
```gdscript
var armor: int = 0  # Armadura del héroe (proveniente de equipamiento)
```

#### B. Aplicación en `reset_stats()` (línea ~176):
```gdscript
armor = bonus_armor  # Aplicar armor del equipamiento
```

#### C. Print de debug actualizado:
```gdscript
print("Hero: Stats reset - HP:%d DMG:%.1f APS:%.2f CRIT:%.1f%% ARMOR:%d" % [max_hp, dmg, aps, crit_p * 100, armor])
```

**Antes**: Armor se guardaba en `loadout_bonus["ARMOR"]` (no accesible directamente)  
**Ahora**: Armor es una variable pública del héroe → accesible desde DungeonHUD

---

## Resultado Visual en DungeonHUD

```
┌─────────────────────────────────────────┐
│ Sala: 4/8          ┃  STATISTICS        │
│ Muertes: 5         ┃  HP: 229/229       │
│ Estado: Atacando   ┃  ███████████████   │
│                    ┃  DMG: 28.0         │
│                    ┃  APS: 1.33         │
│                    ┃  CRIT: 11.9%       │
│                    ┃  ARMOR: 6          │
└─────────────────────────────────────────┘
```

**Código de color para estado**:
- 🟢 **WALK** (Corriendo): Blanco
- 🟠 **ATTACK** (Atacando): Naranja
- 🔴 **DEATH** (Muriendo): Rojo
- ⚪ **IDLE** (Parado): Gris

---

## Testing

### Checklist de Validación:
- [x] Logs de animaciones reducidos (solo prints críticos)
- [x] DungeonHUD muestra HP, DMG, APS, CRIT, ARMOR en tiempo real
- [x] Estado visual actualiza colores según animación del héroe
- [x] ARMOR se calcula correctamente desde equipamiento
- [x] No hay errores de compilación en GDScript

### Flujo de Testing:
1. Iniciar run → verificar stats base en HUD
2. Craftear arma/armadura → equipar → verificar incremento de stats
3. Entrar en combate → verificar estado "Atacando" con color naranja
4. Morir → verificar estado "Muriendo" con color rojo
5. Respawn → verificar estado "Corriendo" con color blanco

---

## Archivos Modificados

```
✏️ scripts/gameplay/Hero.gd
   - Añadida variable `armor: int = 0`
   - Aplicada en `reset_stats()`
   - Comentado print de debug de animaciones

✏️ scripts/gameplay/Enemy.gd
   - Comentado print de debug de animaciones

✏️ scenes/UI/DungeonHUD.tscn
   - Eliminados: STRLabel, AGILabel, INTLabel
   - Añadido: ARMORLabel

✏️ scripts/ui/DungeonHUD.gd
   - Eliminadas referencias a str_label, agi_label, int_label
   - Añadida `armor_label`
   - Actualizada lógica de `state_label` con colores
   - Limpiada función `_update_stats_silent()`
```

---

## Notas

- **HUD_Hero.tscn**: Confirmado como legacy. No eliminar aún (puede tener dependencias en código comentado).
- **Armor mitigation**: Actualmente solo se muestra, no aplica reducción de daño. Implementar en futuro si es necesario.
- **AnimState enum**: Se usa `current_anim_state` (0=IDLE, 1=WALK, 2=ATTACK, 3=DEATH) para detectar estado visual.

---

## Próximos Pasos

1. **Testing de balance**: Verificar que ARMOR de equipamiento se aplica correctamente en combate real
2. **Implementar reducción de daño**: `take_damage()` podría reducir daño basándose en armor (ej: `amount = max(1, amount - armor)`)
3. **Polish visual**: Añadir iconos a stats (DMG 🗡️, APS ⚡, CRIT 💥, ARMOR 🛡️)
