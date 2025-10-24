# 📋 **PLAN DE IMPLEMENTACIÓN: MEJORAS MINIJUEGOS**
### *Priorización y Fases de Desarrollo*

**Fecha:** 24 de Octubre, 2025  
**Basado en:** `INFORME_MINIJUEGOS_FORJA.md`  
**Estado:** Propuesta para revisión

---

## 🎯 **CRITERIOS DE PRIORIZACIÓN**

Cada mejora se evalúa según:

| Criterio | Peso | Descripción |
|----------|------|-------------|
| **Impacto en jugabilidad** | ⭐⭐⭐⭐⭐ | ¿Mejora significativamente la experiencia? |
| **Riesgo de ruptura** | ⭐⭐⭐⭐ | ¿Puede romper sistemas existentes? |
| **Complejidad técnica** | ⭐⭐⭐ | ¿Cuánto tiempo/esfuerzo requiere? |
| **Dependencias** | ⭐⭐ | ¿Requiere otros sistemas primero? |

**Escala de riesgo:**
- 🟢 **BAJO:** Cambios aislados, fácil rollback
- 🟡 **MEDIO:** Afecta múltiples archivos, requiere pruebas
- 🔴 **ALTO:** Cambios estructurales, puede romper saves/lógica existente

---

## 📊 **ANÁLISIS DE PROPUESTAS**

### **MEJORAS GENERALES**

#### ✅ **1. Presets por tier + "difficulty budget"**
- **Impacto:** ⭐⭐⭐⭐⭐ (facilita diseño de contenido enormemente)
- **Riesgo:** 🟢 BAJO (sistema nuevo, no toca código existente)
- **Complejidad:** Media (crear sistema de presets y funciones de mapeo)
- **Fase sugerida:** **FASE 1** ✨

**Implementación:**
```gdscript
# res://scripts/data/MinigameDifficultyPreset.gd
class_name MinigameDifficultyPreset extends Resource

@export var tier: int = 1  # 1=Común, 2=Raro, 3=Legendario
@export var difficulty_budget: float = 50.0  # 0-100
@export var shares: Dictionary = {
    "temp": 0.25,
    "hammer": 0.25,
    "sew": 0.25,
    "quench": 0.25
}

func get_temp_config() -> Dictionary:
    var local_diff = difficulty_budget * shares.temp
    return {
        "hardness": remap(local_diff, 0, 100, 0.2, 0.9),
        "precision": remap(local_diff, 0, 100, 0.6, 0.1),
        "temp_window_base": remap(local_diff, 0, 100, 100, 60)
    }
# ... similar para hammer, sew, quench
```

---

#### ✅ **2. Normalización 0-100 + fusión robusta**
- **Impacto:** ⭐⭐⭐⭐ (evita desbalance entre minijuegos)
- **Riesgo:** 🟡 MEDIO (cambia scoring, puede afectar balance existente)
- **Complejidad:** Baja (ya existe `max_score` en TrialResult)
- **Fase sugerida:** **FASE 1** ✨

**Implementación:**
```gdscript
# En CraftingManager o sistema de fusión
func fuse_trials(results: Array[TrialResult], weights: Dictionary) -> float:
    var normalized_scores := []
    var total_weight := 0.0
    
    for result in results:
        var norm_score = (result.score / result.max_score) * 100.0
        normalized_scores.append(norm_score)
        total_weight += weights.get(result.minigame_id, 1.0)
    
    # Media geométrica ponderada para evitar hard-carry
    var product := 1.0
    for i in range(normalized_scores.size()):
        var weight = weights.get(results[i].minigame_id, 1.0) / total_weight
        product *= pow(normalized_scores[i] / 100.0, weight)
    
    return product * 100.0
```

---

#### ⚠️ **3. Telemetría, seeds y replays**
- **Impacto:** ⭐⭐⭐ (útil para debugging y análisis)
- **Riesgo:** 🟢 BAJO (TelemetryManager ya existe)
- **Complejidad:** Media (añadir campos a logs)
- **Fase sugerida:** **FASE 2** 🔄

**Implementación:**
```gdscript
# Añadir a cada minijuego en start_trial()
func start_trial(config: TrialConfig) -> void:
    super.start_trial(config)
    var seed_value = randi()
    seed(seed_value)
    TelemetryManager.log_event("minigame_start", {
        "minigame": config.minigame_id,
        "blueprint": config.blueprint_id,
        "seed": seed_value,
        "timestamp": Time.get_ticks_msec(),
        "parameters": config.parameters.duplicate()
    })
```

---

#### ✅ **4. Guardarraíles de viabilidad**
- **Impacto:** ⭐⭐⭐⭐⭐ (previene configuraciones frustrantes)
- **Riesgo:** 🟢 BAJO (solo añade clamps)
- **Complejidad:** Baja (revisar rangos en cada minijuego)
- **Fase sugerida:** **FASE 1** ✨

**Implementación:**
```gdscript
# Añadir constantes de seguridad en cada minijuego
const SAFETY_LIMITS = {
    "temp": {"min_zone_px": 30, "max_freq_hz": 1.6},
    "hammer": {"min_bpm": 60, "max_bpm": 200, "min_window_ms": 30},
    "sew": {"max_speed": 1.8, "min_window_px": 2},
    "quench": {"min_window_c": 12, "max_k": 0.95}
}

func apply_blueprint(bp):
    # Ejemplo en TempMinigame
    var hardness = clamp(bp.hardness, 0, 0.875)  # Garantiza zona ≥30px
    var temp_window = max(bp.temp_window_base * (1 - 0.6*hardness), 30)
```

---

### **NUEVAS MECÁNICAS**

#### 🚀 **5. Coser: Círculo móvil**
- **Impacto:** ⭐⭐⭐⭐⭐ (aumenta skill ceiling significativamente)
- **Riesgo:** 🟡 MEDIO (cambia mecánica core de Coser)
- **Complejidad:** Media (añadir movimiento al anillo)
- **Fase sugerida:** **FASE 2** 🔄

**Implementación:**
```gdscript
# En SewMinigame.gd, añadir movimiento aleatorio
var target_offset := Vector2.ZERO
var offset_speed := 80.0  # px/s

func _schedule_next_note():
    super._schedule_next_note()
    # Nuevo target aleatorio dentro de bounds
    var max_offset = 60 * scale_factor
    target_offset = Vector2(
        randf_range(-max_offset, max_offset),
        randf_range(-max_offset, max_offset)
    )

func _process(delta):
    super._process(delta)
    if running and note_active:
        # Lerp suave hacia target
        var center = Vector2(cx, cy)
        center = center.lerp(center + target_offset, delta * 2.0)
        # Actualizar posición del anillo en _draw()
```

---

### **BALANCE Y TUNING**

#### ✅ **6. Martillo: Ventanas dependientes de BPM**
- **Impacto:** ⭐⭐⭐⭐ (mejora fairness en BPMs extremos)
- **Riesgo:** 🟢 BAJO (ajuste de fórmula existente)
- **Complejidad:** Baja (cambiar cálculo de ventanas)
- **Fase sugerida:** **FASE 1** ✨

**Implementación:**
```gdscript
# En HammerMinigame.gd
func make_windows(precision):
    var p = clamp(precision, 0, 1)
    var bpm = _pending_blueprint.get("tempoBPM", DEFAULT_BPM)
    
    # Ventanas más generosas en BPMs altos
    var bpm_scaling = lerp(1.0, 1.25, clamp((bpm - 140) / 60.0, 0, 1))
    
    return {
        "perfect": WINDOWS_BASE.perfect,  # No escala
        "bien": WINDOWS_BASE.bien * lerp(1.2, 0.7, p) * bpm_scaling,
        "regular": WINDOWS_BASE.regular * lerp(1.2, 0.7, p) * bpm_scaling
    }
```

---

#### ✅ **7. Coser: Ventanas por área visual + pre-freeze**
- **Impacto:** ⭐⭐⭐ (mejora UX en velocidades altas)
- **Riesgo:** 🟢 BAJO (ajuste de fórmula)
- **Complejidad:** Baja
- **Fase sugerida:** **FASE 1** ✨

**Implementación:**
```gdscript
# En SewMinigame.gd
func compute_windows(precision):
    var p = clamp(precision, 0, 1)
    var radius_factor = sqrt(r / ring_r) if r > 0 else 1.0
    
    # Pre-freeze cerca del anillo
    var freeze_threshold = ring_r + 15
    if r <= freeze_threshold and bp.stitchSpeed >= 1.5:
        speed *= 0.3  # 70% más lento en últimos px
    
    return {
        "perfect": 3 * (1 + 0.5 * p) * radius_factor,
        "bien": 8 * (1 + 0.35 * p) * radius_factor,
        "regular": 14 * (1 + 0.20 * p) * radius_factor
    }
```

---

#### ⚠️ **8. Temple: Ventana en tiempo + ajuste catalizador**
- **Impacto:** ⭐⭐⭐ (añade dimensión temporal)
- **Riesgo:** 🟡 MEDIO (cambia mecánica, requiere ajuste de balance)
- **Complejidad:** Media
- **Fase sugerida:** **FASE 2** 🔄

**Implementación:**
```gdscript
# En QuenchMinigame.gd
func eval_drop(temp, time_sec):
    var win = effective_window()
    var delta_temp = abs(temp - win.center)
    
    # Ventana temporal basada en k
    var k = bp.k
    var window_time_ms = clamp(0.8 * (1.0 / k) * 1000, 120, 900)
    var optimal_time = calculate_optimal_drop_time()
    var delta_time = abs(time_sec * 1000 - optimal_time)
    
    # Combinación: debe estar bien en AMBAS dimensiones
    var temp_ok = delta_temp <= (win.half if not bp.catalyst else win.half * 1.2)
    var time_ok = delta_time <= window_time_ms
    
    if temp_ok and time_ok:
        # Lógica existente...
        if bp.catalyst:
            score = min(100, score * 0.92)  # -8% multiplier por facilidad
```

---

#### ✅ **9. Anti-spam global**
- **Impacto:** ⭐⭐⭐⭐ (previene cheese y mejora feel)
- **Riesgo:** 🟢 BAJO (lógica defensiva)
- **Complejidad:** Baja
- **Fase sugerida:** **FASE 1** ✨

**Implementación:**
```gdscript
# En MinigameBase.gd (clase base)
var _last_input_time := 0
var _input_burst_count := 0
var _burst_window_ms := 500
const INPUT_COOLDOWN_MS = 150

func _input(event):
    if not (event is InputEventMouseButton or event is InputEventKey):
        return
    if not event.pressed:
        return
        
    var now = Time.get_ticks_msec()
    
    # Anti-spam: cooldown mínimo
    if now - _last_input_time < INPUT_COOLDOWN_MS:
        return
    
    # Detección de ráfaga
    if now - _last_input_time < _burst_window_ms:
        _input_burst_count += 1
        if _input_burst_count > 3:
            # Penalización temporal: ventanas -10%
            apply_spam_penalty()
    else:
        _input_burst_count = 0
    
    _last_input_time = now
    _on_valid_input(event)
```

---

### **UX/UI**

#### ✅ **10. Feedback multimodal**
- **Impacto:** ⭐⭐⭐⭐⭐ (JUICE fundamental)
- **Riesgo:** 🟢 BAJO (AudioManager ya existe)
- **Complejidad:** Media (requiere assets de audio)
- **Fase sugerida:** **FASE 2** 🔄

**Implementación:**
```gdscript
# Crear res://scripts/ui/MinigameFeedback.gd
class_name MinigameFeedback extends Node

const SOUNDS = {
    "Perfect": preload("res://art/sounds/sfx_perfect.wav"),
    "Bien": preload("res://art/sounds/sfx_good.wav"),
    "Regular": preload("res://art/sounds/sfx_ok.wav"),
    "Miss": preload("res://art/sounds/sfx_miss.wav")
}

func play_quality_feedback(quality: String, position: Vector2):
    # Audio
    if SOUNDS.has(quality):
        AudioManager.play_sfx(SOUNDS[quality], {"pitch": randf_range(0.97, 1.03)})
    
    # Visual: pulso en centro
    var pulse = create_pulse_effect(position, quality)
    get_tree().current_scene.add_child(pulse)
    
    # Háptico (si disponible)
    if Input.is_joy_known(0):
        Input.start_joy_vibration(0, 0.3, 0.0, 0.1)
```

---

### **INTEGRACIÓN CON OTROS SISTEMAS**

#### ⚠️ **11. Calidad → Stats del ítem**
- **Impacto:** ⭐⭐⭐⭐⭐ (core gameplay loop)
- **Riesgo:** 🔴 ALTO (requiere sistema de items completo)
- **Complejidad:** Alta (integración con equipamiento y combate)
- **Fase sugerida:** **FASE 3** 🔮

**Requiere:**
- Sistema de items funcional
- Stats de Hero implementados
- CraftingManager conectado con inventario

---

#### ⚠️ **12. Maestrías por minijuego**
- **Impacto:** ⭐⭐⭐ (progresión meta)
- **Riesgo:** 🟡 MEDIO (nuevo sistema de progresión)
- **Complejidad:** Alta (persistencia, unlock trees)
- **Fase sugerida:** **FASE 3** 🔮

---

#### ✅ **13. Logros internos**
- **Impacto:** ⭐⭐⭐ (engagement y replayabilidad)
- **Riesgo:** 🟢 BAJO (sistema independiente)
- **Complejidad:** Media (tracking + UI)
- **Fase sugerida:** **FASE 2** 🔄

---

## 📅 **ROADMAP DE FASES**

### **FASE 1: Fundamentos Sólidos** ✨ (Prioridad ALTA)
**Duración estimada:** 2-3 horas  
**Objetivo:** Mejorar robustez y balance sin romper nada

- ✅ Guardarraíles de viabilidad (clamps de seguridad)
- ✅ Anti-spam global (input cooldown + burst detection)
- ✅ Normalización 0-100 + fusión robusta
- ✅ Presets por tier + difficulty budget
- ✅ Martillo: ventanas dependientes de BPM
- ✅ Coser: ventanas por área visual + pre-freeze

**Riesgo total:** 🟢 BAJO  
**Archivos afectados:**
- `MinigameBase.gd` (anti-spam)
- `TempMinigame.gd` (clamps)
- `HammerMinigame.gd` (ventanas BPM)
- `SewMinigame.gd` (ventanas área + pre-freeze)
- `MinigameDifficultyPreset.gd` (NUEVO)
- `CraftingManager.gd` (fusión robusta)

---

### **FASE 2: Experiencia y Polish** 🔄 (Prioridad MEDIA)
**Duración estimada:** 3-4 horas  
**Objetivo:** Mejorar feel y engagement

- 🎨 Feedback multimodal (sonidos + visuales)
- 🎯 Coser: círculo móvil
- 📊 Telemetría mejorada (seeds + replays)
- ⏱️ Temple: ventana temporal + ajuste catalizador
- 🏆 Logros internos básicos

**Riesgo total:** 🟡 MEDIO  
**Requiere:** Assets de audio (6-8 SFX cortos)

---

### **FASE 3: Integración Profunda** 🔮 (Prioridad BAJA)
**Duración estimada:** 6+ horas  
**Objetivo:** Conectar con sistemas de progresión

- ⚔️ Calidad → Stats del ítem
- 📈 Maestrías por minijuego
- 💾 Sistema de persistencia robusto

**Riesgo total:** 🔴 ALTO  
**Requiere:** Sistemas de combate e inventario completos

---

## ✅ **RECOMENDACIÓN INMEDIATA**

### **Implementar FASE 1 completa**

**Razones:**
1. **Riesgo mínimo:** Solo mejoras defensivas y ajustes de balance
2. **Impacto alto:** Mejora sustancialmente la experiencia sin romper nada
3. **Base sólida:** Prepara arquitectura para Fase 2 y 3
4. **Tiempo razonable:** 2-3 horas para implementar + 30 min de testing

**Orden de implementación sugerido:**
```
1. Guardarraíles (15 min) → Testing inmediato
2. Anti-spam (30 min) → Testing
3. Presets + difficulty budget (60 min) → Testing con varios tiers
4. Normalización + fusión (30 min) → Testing
5. Ajustes de ventanas BPM/área (30 min) → Testing final
```

---

## 🧪 **TESTING CHECKLIST (FASE 1)**

Antes de mergear, verificar:

- [ ] **Temperatura:** Hardness=0.9 genera zona ≥30px
- [ ] **Martillo:** BPM=180 tiene ventanas razonables (≥50ms)
- [ ] **Coser:** StitchSpeed=1.8 tiene pre-freeze activo
- [ ] **Temple:** Ventanas nunca <12°C
- [ ] **Anti-spam:** Spam de clicks no registra múltiples hits
- [ ] **Presets:** Tier 1/2/3 generan dificultades progresivas
- [ ] **Fusión:** 2 Perfect + 1 Miss no da score inflado
- [ ] **Sin regresiones:** Partidas existentes siguen funcionando

---

## 📝 **NOTAS FINALES**

### **Lo que NO hacer ahora:**
- ❌ No tocar sistema de combate/hero
- ❌ No cambiar formato de guardado
- ❌ No añadir dependencias externas
- ❌ No refactorizar nombres de archivos existentes

### **Ventanas de oportunidad:**
- ✨ Fase 1 se puede implementar en una tarde
- ✨ Cada mejora es independiente → rollback fácil
- ✨ Mejoras preparatorias para sistemas futuros

---

*¿Proceder con Fase 1? Responde "Sí, implementar Fase 1" para comenzar.*
