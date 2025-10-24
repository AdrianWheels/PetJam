# 📋 **INFORME TÉCNICO: MINIJUEGOS DE FORJA**
### *Análisis de Diseño, Parámetros y Balance*

**Fecha:** 24 de Octubre, 2025  
**Autor:** Sistema de Análisis de Mecánicas  
**Versión:** 1.0  
**Estado:** Draft para revisión

---

## 🎯 **RESUMEN EJECUTIVO**

El sistema de forja cuenta con **4 minijuegos especializados** que representan las distintas fases de creación de equipo. Cada uno implementa mecánicas de habilidad distintas y acepta configuración paramétrica vía `TrialConfig`, permitiendo ajustar dificultad y recompensas según el blueprint del ítem.

---

## 🔥 **1. TEMPERATURA (ForgeTemp)**
**Archivo:** `res://scripts/TempMinigame.gd`  
**Mecánica:** Cursor senoidal en barra horizontal; presionar ESPACIO/clic cuando cursor esté en zona verde óptima.

### **Parámetros de Configuración:**
| Parámetro | Tipo | Rango | Efecto |
|-----------|------|-------|--------|
| `label` | String | - | Nombre del ítem mostrado |
| `hardness` | float | 0.0 - 1.0 | **Dureza del material**. A mayor dureza (↑), zona óptima más estrecha (↓). Coeficiente: `k = 1 - 0.6 * hardness` |
| `temp_window_base` | float | 20 - 180 | Ancho base de zona óptima en píxeles. Default: 80px |
| `precision` | float | 0.0 - 1.0 | Amplia ventanas de calidad. Perfect: +70%, Bien/Regular: sin cambio |

### **Mecánica de Juego:**
- **Objetivo:** 3 aciertos antes de 5 fallos
- **Cursor:** Oscila sinusoidalmente en barra de 560px (escalado)
- **Frecuencia dinámica:** Inicia en 0.45 Hz, aumenta +0.08 Hz por acierto (max 1.6 Hz)
- **Scoring:**
  - Perfect: 100 pts (≤ 6px * (1 + precision*0.7))
  - Bien: 70 pts (≤ 14px)
  - Regular: 40 pts (≤ 24px)
  - Miss: -15 pts

### **Margen de Maniobra:**
- **Dureza 0.0 → 1.0:** Zona óptima pasa de 80px a **32px** (reducción 60%)
- **Precisión 0.0 → 1.0:** Ventana Perfect crece de 6px a **10.2px** (+70%)
- **Velocidad máxima:** Cursor puede oscilar hasta **5 veces por segundo** en intento final
- **Estrategia:** Items frágiles (alta dureza) requieren timing perfecto; items resistentes permiten más error

### **Notas de Diseño:**
> _[ESPACIO PARA TUS PUNTUALIZACIONES]_
> 
> - TODO: 
> - TODO: 
> - TODO: 

---

## 🔨 **2. MARTILLO (HammerTiming)**
**Archivo:** `res://scripts/HammerMinigame.gd`  
**Mecánica:** Juego de ritmo; golpear ESPACIO/clic cuando círculos lleguen a línea de impacto.

### **Parámetros de Configuración:**
| Parámetro | Tipo | Rango | Efecto |
|-----------|------|-------|--------|
| `label` | String | - | Nombre del ítem |
| `tempo_bpm` | float | 45 - 220 | **BPM del ritmo**. Intervalos entre notas: 60000/BPM ms |
| `notes` | int | 3 - 10 | Cantidad de golpes requeridos. Default: 5 |
| `precision` | float | 0.0 - 1.0 | Ajusta ventanas de timing. A mayor precisión, ventanas más estrictas |
| `weight` | float | 0.0 - 1.0 | **Peso del martillo**. Afecta ease-out (1.0-3.0) y flash visual (6-18) |

### **Mecánica de Juego:**
- **Ventanas de timing (base @ precision=0.5):**
  - Perfect: ±40 ms
  - Bien: ±90 ms (×scaling de precision)
  - Regular: ±140 ms (×scaling)
- **Scoring:**
  - Perfect: 100 pts + 10×combo
  - Bien: 70 pts + 10×combo
  - Regular: 40 pts + 10×combo
  - Miss: 0 pts, rompe combo
- **Condición de éxito:** ≥60% de notas acertadas (3/5 por defecto)

### **Margen de Maniobra:**
- **BPM 45 vs 220:** Intervalos de 1333ms vs 273ms (relación 4.9:1)
- **Precision 0.0 → 1.0:**
  - Bien: 108ms → 75.6ms (-30%)
  - Regular: 168ms → 117.6ms (-30%)
- **Weight 0.0 → 1.0:** Altera percepción visual (ease cúbico vs lineal), NO afecta mecánica
- **Combo bonus:** En 5 notas perfectas, bonus acumulado = **10+20+30+40+50 = 150 pts** extra
- **Max score típico:** 500 (base) + 150 (combo) = **650 pts** (5 notas)

### **Notas de Diseño:**
> _[ESPACIO PARA TUS PUNTUALIZACIONES]_
> 
> - TODO: 
> - TODO: 
> - TODO: 

---

## 🧵 **3. COSER (SewOSU)**
**Archivo:** `res://scripts/SewMinigame.gd`  
**Mecánica:** OSU-like; círculo colapsa hacia anillo central, clic cuando coinciden.

### **Parámetros de Configuración:**
| Parámetro | Tipo | Rango | Efecto |
|-----------|------|-------|--------|
| `label` | String | - | Nombre del ítem |
| `stitch_speed` | float | 0.3 - 2.0 | **Velocidad de colapso**. Multiplica `BASE_SPEED` (120 px/s) |
| `agility` | float | 0.0 - 1.0 | **Perdón en golpes tardíos**. Amplía ventana Regular en misses late: +6×agility |
| `precision` | float | 0.0 - 1.0 | Amplía todas las ventanas: Perfect +50%, Bien +35%, Regular +20% |

### **Mecánica de Juego:**
- **Total de eventos:** 8 puntadas fijas
- **Radio inicial:** 140px → colapsa a 42px (anillo central)
- **Ventanas base (@ precision=0.0):**
  - Perfect: ≤3px diferencia
  - Bien: ≤8px
  - Regular: ≤14px
- **Intervalo entre puntadas:** 420ms cooldown
- **Condición especial:** Si promedio calidad ≥2.0 (Bien), otorga **bonus evasión**

### **Margen de Maniobra:**
- **StitchSpeed 0.3 → 2.0:** Tiempo de colapso varía de **1.17s a 0.175s** (relación 6.7:1)
- **Precision 0.0 → 1.0:**
  - Perfect: 3px → 4.5px (+50%)
  - Bien: 8px → 10.8px (+35%)
  - Regular: 14px → 16.8px (+20%)
- **Agility:** En miss tardío, perdona hasta **+6px** en ventana Regular
- **Scoring:** Perfect=300, Bien=200, Regular=100, Miss=0. Max teórico: **2400 pts** (8×300)
- **Promedio ≥2.0:** Requiere mínimo 6 Bien + 2 Perfect, o equivalente

### **Notas de Diseño:**
> _[ESPACIO PARA TUS PUNTUALIZACIONES]_
> 
> - TODO: 
> - TODO: 
> - TODO: 

---

## 💧 **4. TEMPLE (QuenchWater)**
**Archivo:** `res://scripts/QuenchMinigame.gd`  
**Mecánica:** Curva de enfriamiento exponencial; soltar ESPACIO cuando temperatura esté en ventana óptima.

### **Parámetros de Configuración:**
| Parámetro | Tipo | Rango | Efecto |
|-----------|------|-------|--------|
| `label` | String | - | Nombre del ítem |
| `t_initial` | float | 500 - 1200 | Temperatura inicial (°C) |
| `t_ambient` | float | 15 - 35 | Temperatura ambiente (°C) |
| `cool_rate` | float | 0.1 - 1.0 | **Tasa de enfriamiento** `k` en fórmula Newton: `T(t) = T_amb + (T_ini - T_amb)×e^(-k×t)` |
| `temp_low` | float | - | Límite inferior ventana óptima (°C) |
| `temp_high` | float | - | Límite superior ventana óptima (°C) |
| `catalyst` | bool | true/false | **Catalizador**. Amplía ventana +20% y otorga "Elemento fijado" si Perfect/Bien |
| `intelligence` | float | 0.0 - 1.0 | **Inteligencia del herrero**. Perdona errores early: reduce delta en early-drop |

### **Mecánica de Juego:**
- **UN SOLO intento** (prueba única)
- **Ventanas de calidad (delta al centro):**
  - Perfect: ≤5°C
  - Bien: ≤12°C
  - Regular: ≤20°C
  - Miss: >20°C
- **Scoring:**
  - Perfect: 100 pts (+5 con catalizador)
  - Bien: 85 pts (+5 con catalizador)
  - Regular: 65 pts
  - Miss: 0 pts
- **Tiempo límite visual:** 12s (ajustable)

### **Margen de Maniobra:**
- **CoolRate 0.1 → 1.0:** Tiempo hasta ventana óptima varía radicalmente
  - k=0.1: Enfriamiento lento, ~30s para caer 400°C
  - k=1.0: Enfriamiento rápido, ~3s para caer 400°C
- **Catalizador ON:** Ventana amplía de (Low-High) a **1.2×amplitud** (±10% centro)
- **Intelligence 0.0 → 1.0:** Perdona early-drops hasta **mitad de la ventana**
  - Ejemplo: Si drop 30°C antes, intelligence=1.0 puede reducir delta de 30°C a 15°C → Regular en vez de Miss
- **Estrategia:** Items difíciles (k alto, ventana estrecha) requieren timing perfecto; catalizador + intelligence facilita drásticamente

### **Notas de Diseño:**
> _[ESPACIO PARA TUS PUNTUALIZACIONES]_
> 
> - TODO: 
> - TODO: 
> - TODO: 

---

## 📊 **ANÁLISIS COMPARATIVO**

| Minijuego | Dificultad Base | Escalabilidad | Impacto Skill | Margen Error |
|-----------|----------------|---------------|---------------|--------------|
| **Temperatura** | Media | Alta (velocidad crece) | ⭐⭐⭐⭐ | Estrecho (6-24px) |
| **Martillo** | Media-Alta | Extrema (BPM×precision) | ⭐⭐⭐⭐⭐ | Temporal (40-140ms) |
| **Coser** | Media | Alta (speed×precision) | ⭐⭐⭐⭐ | Visual (3-17px) |
| **Temple** | Baja | Media (k + ventana) | ⭐⭐⭐ | Amplio (5-20°C) |

### **Observaciones Clave:**
1. **Temple** es el más **permisivo** (un intento, ventanas grandes, catalizador)
2. **Martillo** ofrece **mayor rango de dificultad** (BPM 45-220 = factor 4.9×)
3. **Coser** es el **más largo** (8 eventos vs 1-5 otros) pero más **predecible**
4. **Temperatura** tiene **dificultad dinámica** (velocidad crece con éxitos)

---

## 🎮 **RECOMENDACIONES DE BALANCE**

### **Para Items Comunes (fácil):**
```gdscript
Temperatura: hardness=0.2, precision=0.6, temp_window_base=100
Martillo: tempo_bpm=75, precision=0.3, notes=4
Coser: stitch_speed=0.8, precision=0.5, agility=0.4
Temple: cool_rate=0.25, catalyst=true, intelligence=0.5, ventana=80°C
```

### **Para Items Legendarios (difícil):**
```gdscript
Temperatura: hardness=0.9, precision=0.1, temp_window_base=60
Martillo: tempo_bpm=180, precision=0.9, notes=8
Coser: stitch_speed=1.8, precision=0.1, agility=0.0
Temple: cool_rate=0.85, catalyst=false, intelligence=0.0, ventana=15°C
```

### **Curvas de Progresión Sugeridas:**
- **Hardness:** 0.3 → 0.5 → 0.7 → 0.9 (lineal)
- **BPM:** 70 → 95 → 130 → 180 (exponencial)
- **StitchSpeed:** 0.7 → 1.0 → 1.4 → 1.9 (cuadrático)
- **CoolRate:** 0.2 → 0.35 → 0.6 → 0.9 (logarítmico)

---

## 🔧 **MÁRGENES TÉCNICOS CRÍTICOS**

### **Valores límite para mantener jugabilidad:**
- **Temperatura:** Zona mínima viable = **30px** (hardness max 0.875)
- **Martillo:** BPM mínimo viable = **60** (1s entre notas), máximo práctico = **200**
- **Coser:** StitchSpeed máximo viable = **1.8** (< 0.2s reacción)
- **Temple:** Ventana mínima viable = **12°C** (con intelligence=0)

### **Score ranges por minijuego:**
- Temperatura: 0 - 300 pts (3 Perfect)
- Martillo: 0 - 650+ pts (5 notas + combo)
- Coser: 0 - 2400 pts (8 Perfect)
- Temple: 0 - 105 pts (Perfect + catalizador)

**Normalización recomendada:** Escalar todos a 0-100 para items, multiplicar por rareza para XP.

---

## 🚀 **PROPUESTAS DE MEJORA**

### **Sección para tus puntualizaciones:**

#### **Mejoras Generales:**
Cambios que afectan a todos los minijuegos
Presets por tier + “difficulty budget”: define diff_budget∈[0..100] y reparte por prueba (shares), generando parámetros con funciones controladas y clamps duros.
Normalización 0–100 + fusión robusta: escala cada prueba a 0–100 y combina con media geométrica ponderada para evitar “hard carry” de una sola prueba.
Telemetría, seeds y replays: registra seed, timestamps, resultados y parámetros. Interesante guardar esta información para replicar problemas
Guardarraíles de viabilidad: clamps globales (p. ej., ventanas mínimas, speeds máximas), autoscaling perceptual con BPM/velocidad y bloqueo de combinaciones inviables.

#### **Nuevas Mecánicas:**
Coser: Ahora mismo el circulo es estatico, debería poder moverse.

#### **Balance y Tuning:**

Temperatura: 
Martillo: ventanas dependientes de BPM: win = base*lerp(1.0,1.25,saturate((BPM-140)/60)); quantize de notas a subdivisiones y drift_ms≤±20.
Coser: ventanas por área visual: win_px = base * sqrt(radius/42); añade “pre-freeze” 60–90 ms cerca del anillo cuando stitch_speed≥1.5.
Temple: ventana en tiempo además de °C: window_time = clamp(alpha*(1/k), 120ms, 900ms); catalizador +20% ventana pero −5–10% al multiplicador final.

Anti-spam global: única evaluación por evento, bloqueo de 150–200 ms tras input, y detección de ráfagas con malus temporal de precisión.
#### **UX/UI:**
Feedback multimodal: sonidos distintos para Perfect/Bien/Regular/Miss, pulso visual al centro, y trail suave en targets.


#### **Integración con otros sistemas:**
Presets por rareza: blueprint define w_temp,w_hammer,w_sew,w_quench y pesos de fusión; facilita balance por familia de ítems.
Calidad → Stats del ítem: mapea score_normalizado a rangos de daño/defensa/durabilidad con curvas distintas por arquetipo.
Maestrías por minijuego: XP por prueba desbloquea perks (p. ej., +5% ventana en esa prueba o −5% penalización por fallo).
Logros falsos: retos del tipo “3 Perfect seguidos” o “sin Miss a 160 BPM” que otorgan planos, skins o mejoras utilitarias.
---

## ✅ **CONCLUSIÓN**

Los 4 minijuegos ofrecen **amplio margen de configuración** para cubrir desde items iniciales hasta legendarios end-game. La parametrización actual permite:

- **15+ niveles de dificultad** por combinación de parámetros
- **Personalización por tipo de ítem** (espadas rápidas = BPM alto, armaduras pesadas = hardness alto)
- **Bonus mecánicos** (evasión en Coser, elemento en Temple) que integran con sistemas RPG

**Recomendación final:** Implementar **presets por tier** de rareza para acelerar diseño de contenido.

---

## 📝 **CHANGELOG**

### **v1.0 - 24 Oct 2025**
- Análisis inicial de los 4 minijuegos
- Documentación de parámetros y rangos
- Recomendaciones de balance base

### **[Tus cambios aquí]**
> - Añadido a PROPUESTAS DE MEJORA algunas mejoras
> - 
> - 

---

*Documento vivo — Actualizar con cada iteración de diseño*
