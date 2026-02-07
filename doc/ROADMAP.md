# PetJam — Roadmap

> **Plataforma**: Android (Google Play)  
> **Resolución**: 1080x1920 (portrait 9:16)  
> **Motor**: Godot 4.5.1  
> **Última actualización**: 2026-02-07

---

## Estado actual

El proyecto viene de una **game jam** y está en fase de **reestructuración hacia un producto móvil**. Los fundamentos básicos existen (4 minijuegos, corredor con héroe, sistema de crafteo) pero muchos sistemas necesitan completarse o reimplementarse para el objetivo de un juego idle/casual Android.

### Lo que ya funciona (parcial)
- [x] 4 minijuegos con API unificada (MinigameBase)
- [x] Sistema de requests (generación por timer)
- [x] Cola de crafteo (5 slots)
- [x] Flujo de trials secuenciales
- [x] Corredor con héroe y enemigos
- [x] Sistema de combate básico (hit-frame based)
- [x] Desbloqueo de blueprints al derrotar enemigos
- [x] Inventario de materiales en memoria
- [x] 15 blueprints + 12 ItemResources
- [x] HUD con zona héroe + minijuegos + controles
- [x] Layout 1080x1920 portrait- [x] AudioManager unificado (sin dual-context)
- [x] Formulas escalado infinito exponencial
- [x] Debug prints limpios (via DebugManager)
- [x] Archivos obsoletos eliminados
### Lo que no funciona / está incompleto
- [x] EquipmentPanel (WIP — no actualiza stats)
- [ ] Combate visual (spritesheets complejos con bugs)
- [ ] Persistencia (todo se pierde al cerrar)
- [ ] Audio (dual-context legacy, leaks)
- [ ] Escalado infinito real (fórmulas básicas)
- [ ] Muchos prints de debug activos
- [ ] Código legacy/muerto en autoloads

---

## Fases de desarrollo

### Fase 1: Fundamentos solidos
> Objetivo: que el loop basico funcione de forma robusta.

- [x] **Limpiar codigo legacy**: eliminado `MAX_DEATHS`, `DungeonState.FAILED/COMPLETED`, `game_over`, dual-context audio
- [x] **Eliminar archivos obsoletos**: Room.tscn, MainNew.tscn, prototipos HTML, builds viejos, GameOverScreen
- [x] **Unificar AudioManager**: eliminado dual-context, arreglado leak de duck_music (usa Tween)
- [x] **Limpiar prints de debug**: reemplazados con DebugManager categorizado en gameplay core
- [x] **Formulas de escalado infinito**: stats de enemigos crecen exponencialmente (lineal + 4% compuesto/nivel)
- [ ] **Simplificar combate**: migrar a formas geometricas + ataques por cooldown (eliminar dependencia de spritesheets)
- [x] **EquipmentPanel funcional**: equipar items actualiza stats del heroe correctamente
- [ ] **Calidad final del crafteo**: puntuacion total / maximo posible, con barra animada

### Fase 2: Sistemas de progresión
> Objetivo: que el jugador sienta progresión y enganche.

- [ ] **Persistencia a disco**: save/load inventario, equipo, progreso, blueprints desbloqueados (`user://save.json` o similar)
- [ ] **Cálculos offline**: al volver a abrir la app, calcular cuánto avanzó/murió el héroe según deltatime (mover a una fase mas adelante)
- [ ] **Tienda de materiales y pociones**: gastar oro obtenido de requests
- [ ] **Medidor de Forjamagia**: barra siempre presente durante crafteo
- [ ] **Heat system**: acumular heat por crafteo consecutivo
- [ ] **Crit Craft chains**: encadenar perfectos para bonus
- [ ] **Simplificar Sew**: convertir a timing puro y quitar el mouse pointer custom (quitar click en puntos)
- [ ] **Sistema de dificultad automático**: generar TrialConfigs según nivel de blueprint

### Fase 3: Contenido y profundidad
> Objetivo: variedad y profundidad de gameplay.

- [ ] **Sistema de tipos de daño**: armaduras (fortificada/pesada/ligera/héroe/divina) × daño (siege/perforante/cortante/caos)
- [ ] **Pool de pasivas para bosses**: boss cada X niveles con pasivas del pool. Escalado combinatorio.
- [ ] **Infusiones elementales**: drops de enemigos → dificultad extra en recetas → encantamiento al item
- [ ] **Eventos narrativos en RequestManager**: requests prefijados para partes de "historia"
- [ ] **Items faltantes**: crear las 3 ItemResources pendientes
- [ ] **Más blueprints**: expandir las categorías existentes y añadir trinkets
- [ ] **Leaderboard**: ranking por nivel máximo alcanzado

### Fase 4: Mobile Ready
> Objetivo: publicar en Google Play.

- [ ] **Configurar export Android**: SDK, signing, target API
- [ ] **Optimizaciones de rendimiento**: profiling, reducir draw calls, pools de objetos
- [ ] **Testing en dispositivo real**: verificar touch, rendimiento, batería
- [ ] **UI polish**: animaciones, feedback visual, sonidos de confirmación
- [ ] **Tutoriales**: narrador o pop-ups que expliquen el flujo
- [ ] **Google Play Store**: listing, screenshots, descripción
- [ ] **Testing conjunto**: QA en distintos dispositivos

---

## Estimación orientativa

| Fase | Esfuerzo estimado |
|------|-----------------|
| Fase 1: Fundamentos | 15-25h |
| Fase 2: Progresión | 20-30h |
| Fase 3: Contenido | 25-40h |
| Fase 4: Mobile Ready | 15-20h |
| **Total** | **~75-115h** |

---

## Prioridades inmediatas (top 5)

1. **Limpiar archivos y código obsoleto** — reducir confusión
2. **Simplificar combate a geometría** — eliminar bugs de spritesheet
3. **EquipmentPanel funcional** — cerrar el loop de crafteo
4. **Persistencia a disco** — que no se pierda el progreso
5. **Fórmulas de escalado infinito** — que el endless sea real
