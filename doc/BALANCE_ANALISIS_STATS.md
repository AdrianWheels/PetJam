# Análisis de Balance y Stats para Items

**Fecha**: 26 octubre 2025  
**Objetivo**: Configurar stats de items con progresión equilibrada

---

## 📊 STATS ACTUALES (Sin equipo)

### Hero Base (Nivel 1)
```
HP:  160 (60 base + 10*10 STR)
DMG: 21  (6 base + 10*1.5 STR)
APS: 1.20 (1.0 base + 10*0.02 AGI)
CRIT: 5% (10*0.005 AGI)
DPS: ~25.8 (21 * 1.025 crits * 1.2 aps)
```

### Enemigos (Escala agresiva)
```
Nivel 1:  HP=40,   DMG=14.9, APS=0.88  → DPS ~13.1
Nivel 2:  HP=72,   DMG=19.4, APS=0.92  → DPS ~17.9
Nivel 3:  HP=104,  DMG=23.9, APS=0.95  → DPS ~22.7
Nivel 4:  HP=136,  DMG=28.4, APS=0.99  → DPS ~28.1
Nivel 5:  HP=168,  DMG=32.9, APS=1.02  → DPS ~33.6
Nivel 6:  HP=200,  DMG=37.4, APS=1.06  → DPS ~39.6
Nivel 7:  HP=232,  DMG=41.9, APS=1.09  → DPS ~45.7
Nivel 8:  HP=264,  DMG=46.4, APS=1.13  → DPS ~52.4
```

---

## ⚔️ TIEMPO DE MUERTE (TTK - Time To Kill)

### Sin equipo (Hero base):
```
Lvl 1: 40 HP / 25.8 DPS = 1.5 s ✅ Fácil
Lvl 2: 72 HP / 25.8 DPS = 2.8 s ✅ Fácil
Lvl 3: 104 HP / 25.8 DPS = 4.0 s ⚠️ Empieza a costar
Lvl 4: 136 HP / 25.8 DPS = 5.3 s ⚠️ Necesita equipo
Lvl 5: 168 HP / 25.8 DPS = 6.5 s ❌ Muy lento
Lvl 6: 200 HP / 25.8 DPS = 7.8 s ❌ Imposible sin equipo
```

### Hero TTK (tiempo que tarda enemigo en matar al Hero):
```
Hero HP: 160
Lvl 1 DMG: 13.1 DPS → 160/13.1 = 12.2 s ✅ Safe
Lvl 2 DMG: 17.9 DPS → 160/17.9 = 8.9 s  ✅ Safe
Lvl 3 DMG: 22.7 DPS → 160/22.7 = 7.0 s  ⚠️ Apretado
Lvl 4 DMG: 28.1 DPS → 160/28.1 = 5.7 s  ❌ Peligroso
Lvl 5 DMG: 33.6 DPS → 160/33.6 = 4.8 s  ❌ Muy peligroso
```

**CONCLUSIÓN**: Sin equipo, Hero puede llegar a **Nivel 3** razonablemente. A partir de Nivel 4 **REQUIERE crafteo** para progresar.

---

## 🎯 DISEÑO DE PROGRESIÓN CON EQUIPO

### Objetivo JAM (8 salas + jefe):
- **Salas 1-2**: Sin equipo (tutorial)
- **Salas 3-4**: Equipo BASIC (primer crafteo)
- **Salas 5-6**: Equipo ADVANCED (segundo crafteo)
- **Salas 7-8**: Equipo MASTER (crafteo final)
- **Jefe**: Equipo MASTER completo (4 piezas)

---

## ⚖️ PROPUESTA DE STATS BALANCEADOS

### Tier 1: BASIC (Salas 3-4)
**Objetivo**: +30-50% poder base, superar nivel 4

#### Espada Básica
```
DMG:    3-8   (min 50%, max 100% quality)
CRIT:   0.03-0.08  (+3% min, +8% max)
APS:    0.05-0.15  (+0.05 min, +0.15 max)

Con 50% quality:
  DMG +5.5 → Hero DMG = 26.5 (+26%)
  CRIT +5.5% → Hero CRIT = 10.5%
  APS +0.10 → Hero APS = 1.30
  DPS = 26.5 * 1.0525 * 1.30 = 36.3 (+41%)

Con 100% quality:
  DMG +8 → Hero DMG = 29
  CRIT +8% → Hero CRIT = 13%
  APS +0.15 → Hero APS = 1.35
  DPS = 29 * 1.065 * 1.35 = 41.7 (+62%)
```

#### Casco Básico
```
HP:     15-35
ARMOR:  1-3

Con 100%: HP +35, ARMOR +3
Hero survives: 195 HP, reduce 3 dmg por hit
```

#### Escudo Básico
```
HP:     20-45
ARMOR:  2-4

Con 100%: HP +45, ARMOR +4
```

#### Botas Básicas
```
HP:     8-18
ARMOR:  1-2

Con 100%: HP +18, ARMOR +2
```

**SET BASIC COMPLETO (100% quality)**:
```
Total: DMG +8, CRIT +8%, APS +0.15, HP +98, ARMOR +9
Hero Stats: HP=258, DMG=29, APS=1.35, CRIT=13%
DPS: 41.7 (+62% vs base)

Lvl 4: 136 HP / 41.7 DPS = 3.3 s ✅ Viable
Lvl 5: 168 HP / 41.7 DPS = 4.0 s ✅ Viable
```

---

### Tier 2: ADVANCED (Salas 5-6)
**Objetivo**: +80-120% poder base, superar nivel 6

#### Espada Avanzada
```
DMG:    8-18
CRIT:   0.08-0.20  (+8% min, +20% max)
APS:    0.15-0.35

Con 100%:
  DMG +18 → Hero DMG = 39
  CRIT +20% → Hero CRIT = 25%
  APS +0.35 → Hero APS = 1.55
  DPS = 39 * 1.125 * 1.55 = 68.0 (+164% vs base)
```

#### Casco Avanzado
```
HP:     35-75
ARMOR:  3-7
```

#### Escudo Avanzado
```
HP:     45-95
ARMOR:  4-9
```

#### Botas Avanzadas
```
HP:     18-40
ARMOR:  2-5
```

**SET ADVANCED COMPLETO (100%)**:
```
Total: DMG +18, CRIT +20%, APS +0.35, HP +210, ARMOR +21
Hero Stats: HP=370, DMG=39, APS=1.55, CRIT=25%
DPS: 68.0 (+164%)

Lvl 6: 200 HP / 68 DPS = 2.9 s ✅ Fácil
Lvl 7: 232 HP / 68 DPS = 3.4 s ✅ Viable
```

---

### Tier 3: MASTER (Salas 7-8 + Jefe)
**Objetivo**: +150-250% poder base, derrotar jefe

#### Espada Maestra
```
DMG:    18-35
CRIT:   0.20-0.45  (+20% min, +45% max)
APS:    0.35-0.70

Con 100%:
  DMG +35 → Hero DMG = 56
  CRIT +45% → Hero CRIT = 50%
  APS +0.70 → Hero APS = 1.90
  DPS = 56 * 1.25 * 1.90 = 133 (+416% vs base)
```

#### Casco Maestro
```
HP:     75-140
ARMOR:  7-14
```

#### Escudo Maestro
```
HP:     95-180
ARMOR:  9-18
```

#### Botas Maestras
```
HP:     40-80
ARMOR:  5-10
```

**SET MASTER COMPLETO (100%)**:
```
Total: DMG +35, CRIT +45%, APS +0.70, HP +400, ARMOR +42
Hero Stats: HP=560, DMG=56, APS=1.90, CRIT=50%
DPS: 133 (+416%)

Lvl 8: 264 HP / 133 DPS = 2.0 s ✅ Dominante
Boss (x1.6): 422 HP / 133 DPS = 3.2 s ✅ Factible
```

---

## 📈 CURVA DE PROGRESIÓN COMPLETA

| Sala | Enemy Lvl | Enemy HP | Hero DPS (sin/con equipo) | TTK | Equipo Requerido |
|------|-----------|----------|---------------------------|-----|------------------|
| 1 | 1 | 40 | 26 | 1.5s | Ninguno ✅ |
| 2 | 2 | 72 | 26 | 2.8s | Ninguno ✅ |
| 3 | 3 | 104 | 26 → **42** (Basic 100%) | 4.0s → 2.5s | Basic 50%+ ⚠️ |
| 4 | 4 | 136 | 42 | 3.2s | Basic 100% ✅ |
| 5 | 5 | 168 | 42 → **68** (Adv 100%) | 4.0s → 2.5s | Advanced 50%+ ⚠️ |
| 6 | 6 | 200 | 68 | 2.9s | Advanced 100% ✅ |
| 7 | 7 | 232 | 68 → **133** (Master 100%) | 3.4s → 1.7s | Master 50%+ ⚠️ |
| 8 | 8 | 264 | 133 | 2.0s | Master 100% ✅ |
| 9 (Jefe) | 8 Boss | 422 | 133 | 3.2s | Master FULL ✅ |

---

## 🎮 EXPERIENCIA DE JUEGO ESPERADA

### Fase 1: Tutorial (Salas 1-2)
- Sin crafteo necesario
- Enemigos débiles
- Aprende mecánicas de combate

### Fase 2: Primer Crafteo (Sala 3)
- **WALL**: Lvl 3 es difícil sin equipo
- Forzar crafteo de espada/casco basic
- Con 50% quality ya es viable
- Con 100% se vuelve fácil

### Fase 3: Progresión (Salas 4-5)
- Sala 4: fácil con basic
- Sala 5: **WALL** sin advanced
- Tiempo para craftear set advanced

### Fase 4: Endgame (Salas 6-8)
- Sala 6-7: manageable con advanced
- Sala 8: **WALL** sin master
- Craftear master para jefe

### Fase 5: Boss Fight
- Requiere full master set
- Margen de error razonable (3.2s TTK)
- Victoria = dominio del crafteo

---

## ✅ VALIDACIÓN DE BALANCE

### Checks de Progresión:
- [x] Sala 1-2: viable sin equipo
- [x] Sala 3: wall claro → crafteo obligatorio
- [x] Sala 4: viable con basic 50%+
- [x] Sala 5: wall claro → upgrade obligatorio
- [x] Sala 6-7: viable con advanced
- [x] Sala 8: wall suave → master recomendado
- [x] Jefe: posible con master full

### Checks de Crafteo:
- [x] Calidad 50% da +40% poder (útil pero no óptimo)
- [x] Calidad 100% da +60-80% poder (recompensa habilidad)
- [x] Diferencia entre tiers: ~2x poder (incentivo a upgradear)

### Checks de Dificultad:
- [x] Sin equipo: llegar a sala 3 (tutorial)
- [x] Con equipo malo (50%): superar walls con dificultad
- [x] Con equipo bueno (100%): superar walls cómodamente
- [x] Boss: desafío final pero factible

---

## 🚀 SIGUIENTE PASO

**Implementar stats en 12 archivos `.tres`** con los valores balanceados propuestos.

**Archivos a editar**:
1. sword_basic.tres
2. sword_advanced.tres  
3. sword_masterwork.tres
4. helmet_basic.tres
5. helmet_advanced.tres
6. helmet_master.tres
7. shield_basic.tres
8. shield_advanced.tres
9. shield_master.tres
10. boots_basic.tres
11. boots_advanced.tres
12. boots_master.tres

**Tiempo estimado**: 15 minutos (copiar/pegar valores)
