# 🔊 **GUÍA: Migración de Audio a Contextos**

Esta guía explica cómo migrar llamadas a `AudioManager.play_sfx()` y `AudioManager.play_music()` para usar los contextos apropiados.

---

## 🎯 **¿Por qué migrar?**

Antes:
```gdscript
AudioManager.play_sfx(sfx_sound)  # GLOBAL (no se puede silenciar por área)
```

Después:
```gdscript
AudioManager.play_sfx(sfx_sound, 0.0, AudioManager.AudioContext.DUNGEON)  # Se puede silenciar
```

**Beneficio:** Ahora puedes desactivar audio de Forja o Dungeon independientemente desde el DebugPanel.

---

## 📋 **Reglas de asignación de contextos**

| Sistema | Contexto | Ejemplos |
|---------|----------|----------|
| **Dungeon** | `AudioContext.DUNGEON` | Combate, pasos del héroe, enemigos, corredor |
| **Forja** | `AudioContext.FORGE` | Minijuegos, crafteo, entrega de ítems, UI de forja |
| **Global** | `AudioContext.GLOBAL` | Menús, música de fondo general, UI general |

---

## 🔧 **Migración paso a paso**

### **1. Buscar llamadas antiguas**

```bash
# En terminal de VS Code:
grep -r "AudioManager.play_sfx" scripts/
grep -r "AudioManager.play_music" scripts/
```

### **2. Identificar el contexto apropiado**

Pregúntate:
- ¿Este sonido ocurre en la dungeon (combate/corredor)? → `DUNGEON`
- ¿Este sonido ocurre en la forja (minijuegos/crafteo)? → `FORGE`
- ¿Este sonido es de UI/menú general? → `GLOBAL`

### **3. Aplicar la migración**

**Antes:**
```gdscript
am.play_sfx(hit_sfx, 0.1)
```

**Después:**
```gdscript
am.play_sfx(hit_sfx, 0.1, am.AudioContext.DUNGEON)
```

---

## ✅ **Ejemplos migrados**

### **Hero.gd (combate) → DUNGEON**
```gdscript
# scripts/gameplay/Hero.gd, línea 95
if has_node("/root/AudioManager"):
    var am = get_node("/root/AudioManager")
    if am.has_method("play_sfx"):
        var hit_sfx = load("res://art/sounds/atk_sword_flesh_hit_01.wav")
        am.play_sfx(hit_sfx, 0.1, am.AudioContext.DUNGEON)  # ✅ Migrado
```

### **ForgeMinigame (minijuego) → FORGE**
```gdscript
# Ejemplo para cuando se implemente audio en minijuegos
if has_node("/root/AudioManager"):
    var am = get_node("/root/AudioManager")
    var hammer_sfx = load("res://art/sounds/sfx_hammer_hit.wav")
    am.play_sfx(hammer_sfx, 0.0, am.AudioContext.FORGE)  # ✅ FORGE
```

### **CraftingManager (crafteo) → FORGE**
```gdscript
# Ejemplo para sonido de entrega de ítem
if has_node("/root/AudioManager"):
    var am = get_node("/root/AudioManager")
    var deliver_sfx = load("res://art/sounds/sfx_item_delivered.wav")
    am.play_sfx(deliver_sfx, 0.0, am.AudioContext.FORGE)  # ✅ FORGE
```

### **Main (UI general) → GLOBAL**
```gdscript
# Ejemplo para sonido de cambio de área
if has_node("/root/AudioManager"):
    var am = get_node("/root/AudioManager")
    var transition_sfx = load("res://art/sounds/sfx_transition.wav")
    am.play_sfx(transition_sfx, -5.0, am.AudioContext.GLOBAL)  # ✅ GLOBAL
```

---

## 🎵 **Música (play_music)**

### **Música de combate → DUNGEON**
```gdscript
if has_node("/root/AudioManager"):
    var am = get_node("/root/AudioManager")
    var combat_music = load("res://art/sounds/music_combat.ogg")
    am.play_music(combat_music, true, -8.0, am.AudioContext.DUNGEON)
```

### **Música de forja → FORGE**
```gdscript
if has_node("/root/AudioManager"):
    var am = get_node("/root/AudioManager")
    var forge_music = load("res://art/sounds/music_forge_ambient.ogg")
    am.play_music(forge_music, true, -10.0, am.AudioContext.FORGE)
```

---

## 🧪 **Testing después de migrar**

1. **Ejecutar Main.tscn** (`F5`)
2. **Abrir DebugPanel** (`F12`)
3. **Probar cada contexto:**
   - Desactivar "Dungeon Audio" → sonidos de combate deberían silenciarse
   - Desactivar "Forge Audio" → sonidos de minijuegos deberían silenciarse
   - Desactivar ambos → solo sonidos GLOBAL deberían sonar

---

## 📊 **Estado de migración actual**

| Archivo | Estado | Contexto usado |
|---------|--------|----------------|
| `scripts/gameplay/Hero.gd` | ✅ Migrado | DUNGEON |
| `scripts/gameplay/Enemy.gd` | ❌ Sin audio | N/A |
| `scripts/TempMinigame.gd` | ❌ Pendiente | FORGE |
| `scripts/HammerMinigame.gd` | ❌ Pendiente | FORGE |
| `scripts/SewMinigame.gd` | ❌ Pendiente | FORGE |
| `scripts/QuenchMinigame.gd` | ❌ Pendiente | FORGE |
| `scripts/autoload/CraftingManager.gd` | ❌ Pendiente | FORGE |
| `scripts/main.gd` | ❌ Sin audio | N/A |

---

## 🚀 **Próximos pasos**

1. **Cuando añadas nuevo audio:**
   - Identifica el contexto apropiado (FORGE/DUNGEON/GLOBAL)
   - Usa el tercer parámetro en `play_sfx()` o `play_music()`

2. **Migración masiva (opcional):**
   - Buscar todos los `AudioManager.play_` sin contexto
   - Migrarlos uno por uno según ubicación

3. **Testing:**
   - Verificar que cada contexto se silencia correctamente
   - Verificar que no hay sonidos "huérfanos" en GLOBAL

---

## 💡 **Tips**

- **Default es GLOBAL:** Si omites el contexto, usa GLOBAL (backward compatible)
- **No mezcles contextos:** Un sistema debe usar siempre el mismo contexto
- **Música ambiente:** Usa DUNGEON o FORGE según área, no GLOBAL
- **UI sounds:** Usa GLOBAL solo para sonidos de interfaz universal

---

**Última actualización:** 2025-10-24  
**Migraciones completadas:** 1/6 archivos con audio
