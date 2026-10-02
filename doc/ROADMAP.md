# PetJam — Roadmap

> **Plataforma**: Android (Google Play)  
> **Resolución**: 1080x1920 (portrait 9:16)  
> **Motor**: Godot 4.5.1  
> **Última actualización**: 2026-10-02

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
- [x] EquipmentPanel — rehecho como inventario en rejilla (las estadísticas de Tico se recalculan al colocar piezas)
- [x] Combate visual — simplificado a formas geométricas + cooldowns
- [ ] Persistencia (todo se pierde al cerrar)
- [x] Audio — AudioManager unificado (sin dual-context)
- [x] Escalado infinito — fórmulas exponenciales implementadas
- [x] Prints de debug — categorizado via DebugManager
- [ ] Código legacy/muerto en autoloads (parcial)

---

## Fases de desarrollo

### Fase 1: Fundamentos solidos
> Objetivo: que el loop basico funcione de forma robusta.

- [x] **Limpiar codigo legacy**: eliminado `MAX_DEATHS`, `DungeonState.FAILED/COMPLETED`, `game_over`, dual-context audio
- [x] **Eliminar archivos obsoletos**: Room.tscn, MainNew.tscn, prototipos HTML, builds viejos, GameOverScreen
- [x] **Unificar AudioManager**: eliminado dual-context, arreglado leak de duck_music (usa Tween)
- [x] **Limpiar prints de debug**: reemplazados con DebugManager categorizado en gameplay core
- [x] **Formulas de escalado infinito**: stats de enemigos crecen exponencialmente (lineal + 4% compuesto/nivel)
- [x] **Simplificar combate**: migrado a formas geométricas (`_draw()`) + ataques por cooldown (eliminada dependencia de spritesheets)
- [x] **EquipmentPanel funcional**: equipar items actualiza stats del heroe correctamente
- [x] **Calidad final del crafteo**: CraftResultScreen con barra animada, reveal de tier, botones vender/equipar integrados

### Fase 2: Sistemas de progresión
> Objetivo: que el jugador sienta progresión y enganche.

- [x] **Persistencia a disco**: SaveManager (`user://save.json`), auto-save 60s + triggers (equip, craft, enemy kill), carga en data_ready
- [ ] **Cálculos offline**: al volver a abrir la app, calcular cuánto avanzó/murió el héroe según deltatime (mover a una fase mas adelante)
- [x] **Tienda de materiales y pociones**: ShopPanel con catálogo de materiales y pociones, gold display en HUD, gold unificado (RequestsManager → CraftingManager → resultado)
- [x] **Medidor de Forjamagia**: ForgeMagiaMeter con 10 segmentos, colores azul→morado→dorado, glow en overclock. Sube con Perfects (+3), baja con Misses (-1). Bonus calidad: +5%/+10%/+15%. Panel semi-transparente superpuesto al MinigamePanel
- [ ] **Crit Craft chains**: encadenar perfectos para bonus
- [x] **Simplificar Sew**: convertido a timing puro (tap en cualquier lugar, sin check posicional, cursor custom eliminado)
- [x] **Sistema de dificultad automático**: sustituido por los rangos (`TrialDifficulty` sube las pruebas con el rango del pedido)
- [x] **Simplificar final crafteo**: Al completar un item, va directo al inventario con botón "AL INVENTARIO" + animación de partículas. Se vende en la tienda (tab Vender) y se equipa desde el panel de héroe
- [x] **Mejorar visualmente la tienda**: Textos más grandes (26-42px), tienda ocupa zona central de minijuegos (no fullscreen), nueva pestaña "Vender" para vender items crafteados por oro
- [x] **Inventario en rejilla** (estilo Lootbound, [spec](specs/2026-09-27-inventario-en-rejilla.md)): el equipo de Tico es una rejilla de 4×4 a 6×6 sin huecos fijos. Las piezas tienen forma y aristas según su calidad, se giran y se colocan donde quepan; dan auras a sus vecinas y ganan en su zona; las legendarias traen una habilidad de combate. Mochila de 6×4, botín sin límite y 2 huecos de pociones que se beben solas. La rejilla crece al vencer a los jefes de las salas 10, 20, 30 y 40 (provisional). Pendiente aparte: las recetas de ampliación (con los rangos), el balance con Balanza y el arte. Ver [Inventario en rejilla](ARCHITECTURE.md#43-inventario-en-rejilla) en la arquitectura

### Fase 3: Contenido y profundidad
> Objetivo: variedad y profundidad de gameplay.

- [ ] **Sistema de tipos de daño**: armaduras (fortificada/pesada/ligera/héroe) × daño (siege/perforante/cortante/caos)
- [ ] **Pool de pasivas para bosses**: boss cada 10 niveles con pasivas del pool. Escalado combinatorio.
- [ ] **Infusiones elementales**: drops de enemigos → dificultad extra en recetas → encantamiento al item
- [ ] **Eventos narrativos en RequestManager**: requests prefijados para partes de "historia"
- [ ] **Items faltantes**: crear las 3 ItemResources pendientes
- [x] **Rangos de plano por ciclo** ([spec](specs/2026-09-27-rangos-de-plano-por-ciclo.md)): sustituyen a «Más blueprints» y a la dificultad automática de la fase 2. Cada ciclo de 5 biomas (50 salas) da los planos de rango N, que piden materiales de bioma y más oro y suben la dificultad de los minijuegos; los jefes del ciclo los desbloquean (cartel «¡Planos avanzados II!»). El rango del equipo es la base de Tico; si cae, farmea delante del muro y el selector de sala le deja volver atrás. Curva calibrada con Balanza (`arnes.sh check`, 35 de 35). Pendiente: la revisión humana y la prueba en el móvil. Ver [Rangos por ciclo](ARCHITECTURE.md#44-rangos-por-ciclo)
- [ ] **Leaderboard**: ranking por nivel máximo alcanzado
- [ ] **Decisión de publicación**: gratis primero, sin anuncios al principio. Se mide la retención antes de monetizar

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

1. ~~**Limpiar archivos y código obsoleto**~~ ✅
2. ~~**Simplificar combate a geometría**~~ ✅ — formas geométricas + cooldowns
3. ~~**EquipmentPanel funcional**~~ ✅ — cerrar el loop de crafteo
4. ~~**Persistencia a disco**~~ ✅ — SaveManager + auto-save + load al arrancar
5. ~~**Fórmulas de escalado infinito**~~ ✅ — que el endless sea real
