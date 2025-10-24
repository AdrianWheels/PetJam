# ✅ **CHECKLIST DE TESTING - FASE 1**
### Mejoras de Minijuegos Implementadas

**Fecha:** 24 de Octubre, 2025  
**Versión:** 1.0  
**Estado:** Pendiente de verificación en Godot

---

## 📋 **CHECKLIST GENERAL**

### **Pre-Testing**
- [ ] Abrir proyecto en Godot 4.5
- [ ] Verificar que no hay errores de compilación en Output
- [ ] Verificar que todos los autoloads están registrados
- [ ] Cargar `Main.tscn` y ejecutar escena

---

## 🔥 **TEMPERATURA (TempMinigame)**

### **Guardarraíles de seguridad**
- [ ] **Test 1:** hardness=0.9 → Zona verde ≥30px
  - Configurar blueprint con `hardness: 0.9`
  - Medir ancho de zona verde visualmente
  - ✅ PASS si zona ≥30px | ❌ FAIL si <30px

- [ ] **Test 2:** Frecuencia máxima limitada a 1.6Hz
  - Lograr 3 Perfect consecutivos
  - Observar velocidad del cursor
  - ✅ PASS si oscilación no excede visualmente ~1.6 ciclos/s

- [ ] **Test 3:** Anti-spam activo
  - Spamear clicks rápidamente (>4 clicks en <500ms)
  - ✅ PASS si se ignoran inputs extras o aparece mensaje de penalización

### **Casos extremos**
- [ ] hardness=0.0, precision=0.6 → Zona amplia, fácil
- [ ] hardness=0.875, precision=0.1 → Zona justa en límite (30px)
- [ ] hardness=1.0 (inválido) → Clampeado a 0.875 automáticamente

---

## 🔨 **MARTILLO (HammerMinigame)**

### **Guardarraíles de seguridad**
- [ ] **Test 1:** BPM=200 (máximo) → Ventanas razonables
  - Configurar `tempo_bpm: 200`
  - Intentar golpes Perfect/Bien
  - ✅ PASS si ventanas ≥50ms (alcanzable)

- [ ] **Test 2:** BPM=60 (mínimo) → Intervalos 1s
  - Configurar `tempo_bpm: 60`
  - Cronometrar intervalo entre notas
  - ✅ PASS si ~1000ms entre notas

- [ ] **Test 3:** Ventanas escalan con BPM
  - BPM=140 → Ventanas base
  - BPM=180 → Ventanas ~15% más grandes
  - ✅ PASS si se nota diferencia en perdón de timing

### **Casos extremos**
- [ ] BPM=45 (inválido) → Clampeado a 60
- [ ] BPM=220 (inválido) → Clampeado a 200
- [ ] precision=0.9, BPM=180 → Difícil pero jugable

---

## 🧵 **COSER (SewMinigame)**

### **Guardarraíles de seguridad**
- [ ] **Test 1:** stitch_speed=1.8 (máximo) → Pre-freeze activo
  - Configurar `stitch_speed: 1.8`
  - Observar si círculo ralentiza cerca del anillo
  - ✅ PASS si visible ralentización en últimos ~15px

- [ ] **Test 2:** Ventanas escalan con radio
  - Golpear cuando círculo está lejos (r>100px)
  - Golpear cuando círculo está cerca (r<50px)
  - ✅ PASS si ventana más generosa cuando está lejos

- [ ] **Test 3:** Anti-spam activo
  - Spamear clicks
  - ✅ PASS si cooldown 150ms respetado

### **Casos extremos**
- [ ] stitch_speed=2.0 (inválido) → Clampeado a 1.8
- [ ] stitch_speed=0.3, precision=0.5 → Muy lento pero jugable
- [ ] precision=0.0 → Ventanas mínimas pero ≥2px

---

## 💧 **TEMPLE (QuenchMinigame)**

### **Guardarraíles de seguridad**
- [ ] **Test 1:** Ventana <12°C → Ampliada automáticamente
  - Configurar `temp_low: 550, temp_high: 555` (5°C ventana)
  - Verificar que se ajusta a 12°C mínimo
  - ✅ PASS si ventana final ≥12°C

- [ ] **Test 2:** cool_rate=0.95 (máximo) → Enfriamiento rápido pero manejable
  - Configurar `cool_rate: 0.95`
  - Intentar soltar en ventana
  - ✅ PASS si ventana aparece en <5s y es alcanzable

- [ ] **Test 3:** cool_rate=0.1 (mínimo) → Enfriamiento muy lento
  - Configurar `cool_rate: 0.1`
  - Cronometrar hasta ventana óptima
  - ✅ PASS si tarda >15s

### **Casos extremos**
- [ ] cool_rate=1.5 (inválido) → Clampeado a 0.95
- [ ] cool_rate=0.05 (inválido) → Clampeado a 0.1
- [ ] catalyst=true, intelligence=0.5 → Ventana amplia, perdón activo

---

## 🛡️ **SISTEMA ANTI-SPAM (MinigameBase)**

### **Pruebas globales**
- [ ] **Test 1:** Cooldown 150ms entre inputs
  - En cualquier minijuego, intentar clicks a <150ms
  - ✅ PASS si solo se registra 1 cada 150ms

- [ ] **Test 2:** Detección de ráfaga
  - Hacer >3 clicks en <500ms
  - ✅ PASS si activa penalización de 2s

- [ ] **Test 3:** Penalización temporal
  - Activar penalización
  - Esperar 2s
  - ✅ PASS si vuelve a permitir inputs normales

- [ ] **Test 4:** Aplicado en todos los minijuegos
  - Probar anti-spam en Temperatura
  - Probar anti-spam en Martillo
  - Probar anti-spam en Coser
  - Probar anti-spam en Temple
  - ✅ PASS si funciona en todos

---

## 📊 **SISTEMA DE PRESETS (MinigameDifficultyPreset)**

### **Creación de presets**
- [ ] **Test 1:** Crear preset común
  ```gdscript
  var preset = MinigameDifficultyPreset.create_common()
  var config = preset.get_temp_config()
  print(config)  # Verificar valores razonables
  ```
  - ✅ PASS si hardness~0.2-0.3, precision~0.6

- [ ] **Test 2:** Crear preset legendario
  ```gdscript
  var preset = MinigameDifficultyPreset.create_legendary()
  var config = preset.get_hammer_config()
  print(config)  # Verificar valores difíciles
  ```
  - ✅ PASS si BPM>150, precision>0.8

- [ ] **Test 3:** Obtener todos los configs
  ```gdscript
  var preset = MinigameDifficultyPreset.create_rare()
  var all_configs = preset.get_all_configs()
  print(all_configs.keys())  # Debe tener: temp, hammer, sew, quench
  ```
  - ✅ PASS si devuelve Dictionary con 4 keys

---

## 🔀 **FUSIÓN ROBUSTA (CraftingManager)**

### **Normalización 0-100**
- [ ] **Test 1:** Fusionar 2 resultados iguales
  ```gdscript
  var r1 = TrialResult.new()
  r1.score = 80
  r1.max_score = 100
  r1.trial_id = &"temp"
  
  var r2 = TrialResult.new()
  r2.score = 80
  r2.max_score = 100
  r2.trial_id = &"hammer"
  
  var fused = CraftingManager.fuse_trial_results([r1, r2])
  print(fused)  # Esperado: ~80
  ```
  - ✅ PASS si resultado ~80 (±5)

- [ ] **Test 2:** Evitar "hard carry"
  ```gdscript
  var r1 = TrialResult.new()  # Perfect
  r1.score = 100
  r1.max_score = 100
  
  var r2 = TrialResult.new()  # Miss
  r2.score = 0
  r2.max_score = 100
  
  var fused = CraftingManager.fuse_trial_results([r1, r2])
  print(fused)  # Esperado: ~0-20 (media geométrica castiga fuerte)
  ```
  - ✅ PASS si resultado <30 (no permite hard-carry)

- [ ] **Test 3:** Pesos personalizados
  ```gdscript
  var weights = {&"temp": 2.0, &"hammer": 1.0}
  var fused = CraftingManager.fuse_trial_results([r1, r2], weights)
  print(fused)  # temp pesa el doble
  ```
  - ✅ PASS si temp tiene más impacto en resultado final

---

## 🎮 **REGRESIONES**

### **Verificar que NO se rompió nada**
- [ ] Main.tscn carga correctamente
- [ ] Minijuegos se pueden iniciar desde UI
- [ ] Scores se muestran correctamente
- [ ] Pantallas de título/fin funcionan
- [ ] Transiciones entre minijuegos sin crash
- [ ] CraftingManager sigue encolando blueprints
- [ ] HUD actualiza información correctamente

---

## 📈 **CASOS DE USO COMPLETOS**

### **Escenario 1: Espada común (fácil)**
- [ ] Usar preset común para temp+hammer+sew
- [ ] Completar secuencia de 3 minijuegos
- [ ] Verificar score final razonable (>60)
- [ ] Verificar grade asignado (bronze/silver)

### **Escenario 2: Armadura legendaria (difícil)**
- [ ] Usar preset legendario
- [ ] Intentar completar con parámetros extremos
- [ ] Verificar que sigue siendo jugable (no imposible)
- [ ] Score bajo pero alcanzable (20-40 es válido)

### **Escenario 3: Run completa**
- [ ] Craftear 3 items distintos
- [ ] Verificar que cola funciona correctamente
- [ ] Anti-spam no interfiere con gameplay normal
- [ ] Fusión de scores coherente

---

## ✅ **CRITERIOS DE ACEPTACIÓN**

**Mínimo para aprobar FASE 1:**
- ✅ 90% de tests individuales PASS
- ✅ 0 crashes o errores críticos
- ✅ Regresiones: 100% PASS
- ✅ Al menos 1 escenario completo PASS

**Notas:**
- Tests que fallen con motivo justificado (ej. precisión de medición) pueden marcarse como PASS con nota
- Casos extremos pueden tener tolerancia ±10%

---

## 📝 **RESULTADOS**

### **Ejecutado por:** _________________  
### **Fecha:** _________________  
### **Versión Godot:** _________________

### **Resumen:**
- Tests PASS: ___/___
- Tests FAIL: ___/___
- Crashes: ___
- **VEREDICTO:** [ ] APROBADO | [ ] REQUIERE AJUSTES

### **Notas adicionales:**
```
[Espacio para observaciones]
```

---

*Este checklist debe ejecutarse antes de mergear FASE 1 a main*
