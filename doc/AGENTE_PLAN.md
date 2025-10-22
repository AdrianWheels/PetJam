# AGENTE_PLAN.md — Plan de implementación del GDD “Timeline Forgemaster”

> Este plan operacional guía a un agente de código para implementar el MVP del juego descrito en el GDD. Base: Godot 4.5, GDScript, alcance jam.

## TL;DR

- Motor: Godot 4.5.
- Estructura: corredor lineal de 8 salas + jefe, combate automático del Héroe.
- Sistema paralelo: 4 minijuegos de craft que determinan la calidad de ítems.
- Prioridad: loop funcional completo, UI mínima, 3 enemigos, 6 ítems, 1 jefe.
- Entrega: en 2–3 PRs grandes y 10–14 PRs chicos, cada PR con escena jugable y DoD claro.

---

## 0) Requisitos de entorno

- Godot 4.5 LTS.
- Proyecto raíz `PetJam/`.
- Registrar autoloads desde el editor:
  - `GameManager` → `res://scripts/autoload/GameManager.gd`
  - `DataManager` → `res://scripts/autoload/DataManager.gd`
  - `CraftingManager` → `res://scripts/autoload/CraftingManager.gd`
  - `AudioManager` → `res://scripts/autoload/AudioManager.gd`
  - `TelemetryManager` → `res://scripts/autoload/TelemetryManager.gd`

**Verificación rápida:** ejecutar `Main.tscn` y confirmar en consola “XxxManager ready”.

---

## 1) Objetivos del MVP (Definición de Hecho)

- Corredor lineal jugable con 8 salas + 1 jefe, avance automático, respawn a Sala 1 tras 3 s.
- 3 tipos de enemigo (esbirro melee, arquero, jefe con contramedida en fase 2).
- 6 ítems (arma/armadura/consumibles) con calidad afectada por minijuegos.
- 4 minijuegos funcionales: Forja, Martillo, Coser OSU, Agua.
- Sistema “Entrega” con burbuja, CD, curación, equipamiento en campo.
- UI única que muestre corredor, crafting/cola e inventario.
- Telemetría mínima: porcentajes de acierto, uso de Entrega, distribución de Calor.

---

## 2) Estructura de carpetas propuesta

```
res://
  scenes/
    Main.tscn
    Corridor.tscn
    Room.tscn
    CombatView.tscn
    UI/
      HUD.tscn
      CraftPanel.tscn
      InventoryPanel.tscn
      DeliveryButton.tscn
    Minigames/
      ForgeTemp.tscn
      HammerTiming.tscn
      SewOSU.tscn
      QuenchWater.tscn
  scripts/
    autoload/
      GameManager.gd
      DataManager.gd
      CraftingManager.gd
      AudioManager.gd
      TelemetryManager.gd
    core/
      Hero.gd
      Enemy.gd
      CombatController.gd
      RoomController.gd
      DeliveryController.gd
    systems/
      Inventory.gd
      Items.gd
      Blueprints.gd
      Materials.gd
      CraftQueue.gd
      HeatSystem.gd
      ForgeMagicMeter.gd
    minigames/
      ForgeTemp.gd
      HammerTiming.gd
      SewOSU.gd
      QuenchWater.gd
  data/
    enemies.json
    items.json
    materials.json
    blueprints.json
  audio/
  fx/
```

---

## 3) Roadmap por hitos

### Hito A — Núcleo de corredor y combate (P0)
1. `Main.tscn` carga `Corridor.tscn` y `HUD.tscn`.
2. `Corridor`: genera 8 `Room.tscn` + 1 jefe; marca índice activo; avanza al limpiar sala.
3. `RoomController`: spawnea 1 enemigo, hook a `CombatController`.
4. `Hero.gd` y `Enemy.gd`: stats simples; auto-combate; respawn del héroe en 3 s a Sala 1.
5. `TelemetryManager`: log básico por sala.

### Hito B — Sistemas BS y Entrega (P0)
1. `Inventory`, `Materials`, `Items`, `Blueprints`: datos mínimos en JSON.
2. `CraftQueue` 3 slots con reordenar/promoción segura y cancelación con devolución 80%.
3. `DeliveryController`: burbuja 5 s, bloqueo de daño, CD 20 s, curación y equipamiento.
4. `HUD`: corredor arriba, panel craft, inventario y botón de Entrega.

### Hito C — Minijuegos MVP (P0)
1. Forja (temperatura): 3 aciertos en zona dulce, velocidad creciente.
2. Martillo (timing): 5 golpes a BPM, ventanas ms.
3. Coser OSU: 8 notas, círculos colapsan, media ≥ Bien da Evasión.
4. Agua (temple): suelta en intervalo óptimo; con catalizador, ventana +20% y sello “Elemento fijado” si ≥ Bien.

### Hito D — Sistemas avanzados (P1)
1. `HeatSystem` y `ForgeMagicMeter` con efectos en ventanas/velocidades.
2. `Crit Craft`: 3 Perfect seguidos → calidad +1 y reembolso 1 material.
3. `Fail-forward`: chatarra y reroll de plano o +1 intento OSU.

### Hito E — Enemigos/Ítems/Jefe (P1)
- Esbirro melee, Arquero, Jefe con contramedida y fase 2 a 50% HP.
- 6 ítems base e infusiones elementales.

---

## 4) Tareas priorizadas para el agente

> Cada tarea termina en PR con escena jugable y checklist de verificación.

### P0 — Críticos del loop
- [ ] `GameManager.gd`: estados Run/Respawn/Win/Lose.
- [ ] `Corridor.tscn` + `RoomController.gd`: ciclo 8 salas + jefe.
- [ ] `CombatController.gd`: dps tick, objetivo único, muerte y transición.
- [ ] `Hero.gd`: slots, uso de poción a ≤ 35% si hay stock.
- [ ] Respawn y avance automático entre salas.

### P0 — BS + UI + Entrega
- [ ] `Inventory`/`Materials`/`Items`/`Blueprints`: carga JSON.
- [ ] `CraftQueue`: agregar, reordenar, cancelar con 80% devolución.
- [ ] `DeliveryController`: burbuja, CD, curación, equipar.
- [ ] `HUD.tscn`: corredor, panel craft, inventario, botón Entrega.

### P0 — Minijuegos
- [ ] Forja Temperatura (3 aciertos, velocidad sube).
- [ ] Martillo Timing (5 golpes, ventanas Perfect/Bien/Regular/Miss).
- [ ] Coser OSU (8 notas, media ≥ Bien otorga Evasión).
- [ ] Agua Temple (intervalo; catalizador aumenta ventana 20%).

### P1 — Sistemas de maestría
- [ ] `ForgeMagicMeter`: puntos por Perfect/Bien; Overclock 5 s.
- [ ] `HeatSystem`: efectos >60 y >85; reducción por Agua o perk.
- [ ] `Crit Craft` y `Fail-forward`.

### P1 — Contenido
- [ ] Enemigos: Esbirro, Arquero, Jefe con contramedida + fase 2.
- [ ] Ítems: espada, arco, peto cuero, casco, poción vida, tónica; infusiones.

---

## 5) Contrato de PR y verificación (DoD)

- PR debe incluir:
  - Escena de prueba reproducible (`/scenes/sandboxes/SBX_<feature>.tscn`).
  - Vídeo GIF corto o texto de pasos para reproducir.
  - Métricas relevantes registradas por `TelemetryManager`.
  - Sin dependencias externas.
- Test manual mínimo por PR:
  - [ ] FPS estable en PC medio.
  - [ ] Sin crash al resetear `Main.tscn`.
  - [ ] Persistencia temporal reseteada al volver a menú.
- Etiquetas:
  - `P0` loop roto; `P1` features de maestría; `P2` polish.

---

## 6) Datos iniciales sugeridos

`data/enemies.json`
```json
[
  {"id":"grunt","hp":60,"atk":8,"spd":1.0,"tags":["melee"]},
  {"id":"archer","hp":45,"atk":6,"spd":1.2,"tags":["ranged","bleed_vs_armor"]},
  {"id":"boss","hp":240,"atk":12,"spd":1.0,"tags":["phase2","counter_meta"]}
]
```

`data/items.json`
```json
[
  {"id":"sword_basic","slot":"weapon","atk":10,"type":"physical"},
  {"id":"bow_light","slot":"weapon","atk":7,"spd":0.15},
  {"id":"leather_chest","slot":"armor","def":8,"spd":-0.05},
  {"id":"padded_helm","slot":"helm","hp":20},
  {"id":"potion_heal","slot":"consumable","heal_pct":0.4},
  {"id":"potion_tonic","slot":"consumable","spd_buff":0.2,"dur":10}
]
```

`data/materials.json`
```json
[
  {"id":"iron"},
  {"id":"leather"},
  {"id":"cloth"},
  {"id":"distilled_water"},
  {"id":"catalyst_fire"},
  {"id":"catalyst_ice"},
  {"id":"catalyst_venom"}
]
```

`data/blueprints.json`
```json
[
  {"id":"bp_serrated_edge","affects":"weapon","mods":{"crit":0.05}},
  {"id":"bp_reinforced_padding","affects":"armor","mods":{"def":4}},
  {"id":"bp_elemental_basic","affects":"weapon","mods":{"elem":"fire|ice|venom"}}
]
```

> Nota: los blueprints se desbloquean al matar por primera vez a un enemigo concreto.

---

## 7) Especificaciones compactas por sistema

### 7.1 Combate automático
- Tick de combate a 10 Hz; cada unidad con `atk`, `spd`, `hp`.
- Arquero aplica sangrado si hero lleva armadura pesada.
- Jefe: abre con contramedida al daño más usado y cambia en 50% HP.

### 7.2 Entrega
- Al activar: pausa el ataque del héroe 5 s, invulnerable, equipa ítems y cura. CD 20 s.
- QTE “Entrega Perfecta” reduce CD −5 s y añade Pulido +3% durante 20 s.

### 7.3 Minijuegos
- **Forja**: barra 0–100 con cursor senoidal; 3 aciertos.
- **Martillo**: 5 beats, ventanas ms: Perfect ≤40, Bien ≤90, Regular ≤150.
- **Coser OSU**: 8 notas, colapso 650 ms, partículas y pitch random ±3%. Media ≥ Bien da +Evasión.
- **Agua**: T(t) exponencial; soltar en [T_low, T_high]; catalizador +20% ventana.

### 7.4 Forjamagia y Calor
- Forjamagia: Perfect=2, Bien=1; a 10 pts Overclock 5 s, ventanas +20%, OSU −15% velocidad de colapso.
- Calor: >60 ventanas −10%, >85 −20%; baja esperando, Agua éxito o perk Temple.

---

## 8) Prompts operativos para el agente

> Usar uno por PR. Objetivo: respuestas cortas, código concreto.

**A. Crear corredor y combate**
```
Actúa como desarrollador senior de Godot 4.5. Crea scenes y scripts para un corredor lineal de 9 salas (8 + jefe) con combate automático entre un Hero y un Enemy por sala. Requisitos:
- Main.tscn carga Corridor.tscn y HUD.tscn.
- RoomController spawnea 1 Enemy según índice; al morir, avanza a la siguiente sala.
- Respawn del Hero en 3 s a Sala 1 si muere.
- Scripts en res://scripts/core, escenas en res://scenes.
- Entregar código GDScript y pasos para probar en SBX_Corridor.tscn.
```

**B. Inventario, crafting y cola**
```
Implementa Inventory.gd, Materials.gd, Items.gd y CraftQueue.gd.
- Carga JSON de res://data.
- Tres slots, reordenar arrastrando, promoción urgente con coste de calor, cancelación devuelve 80% materiales.
- Integrar en HUD.tscn con panel CraftPanel.tscn.
- Incluir SBX_Crafting.tscn para prueba.
```

**C. Entrega con burbuja**
```
Implementa DeliveryController.gd y DeliveryButton.tscn:
- Al pulsar: invulnerable 5 s, hero deja de atacar, equipamiento instantáneo, curación moderada, CD 20 s.
- QTE: si acierto en ventana breve, reduce CD en 5 s y aplica buff Pulido 20 s.
- SBX_Delivery.tscn para test.
```

**D. Minijuegos (uno por PR)**
```
Crea Minigame SewOSU (8 notas, colapso 650 ms, scoring Perfect/Bien/Regular/Miss; media ≥ Bien otorga Evasión).
Exponer API: start(params), on_result(callback).
SBX_SewOSU.tscn con HUD marcador de combo y partículas.
```

**E. Forjamagia y Calor**
```
Implementa ForgeMagicMeter.gd y HeatSystem.gd con efectos en ventanas de minijuegos y velocidad de OSU conforme a diseño.
Hooks en CraftingManager y cada minijuego.
SBX_MasterySystems.tscn para test.
```

---

## 9) Checklists de verificación por feature

**Corredor y combate**
- [ ] Avance correcto sala→sala.
- [ ] Respawn del héroe en Sala 1 con cooldown.
- [ ] Jefe entra en fase 2 a 50% HP.

**Entrega**
- [ ] Burbuja bloquea daño y pausa ataques 5 s.
- [ ] Equipamiento aplicado y curación realizada.
- [ ] CD visible; Perfect reduce CD −5 s.

**Minijuegos**
- [ ] Entrada por teclado/ratón, feedback Perfect/Bien/Regular/Miss.
- [ ] Exportan `result.score`, `result.quality`, `result.combo`.
- [ ] Integración con CraftingManager altera calidad de ítem.

**Forjamagia/Calor**
- [ ] Overclock en 10 pts durante 5 s.
- [ ] Calor >60 y >85 afecta ventanas.
- [ ] Agua reduce Calor correctamente.

---

## 10) Métricas mínimas y tuning

- % de acierto por minijuego, tiempo medio en cola, uso de Entrega y % Perfect.
- Distribución del Calor en run.
- Correlación Forjamagia vs victoria por sala.

---

## 11) Pitfalls y cómo evitarlos

- Tick de combate y framerate: fija lógica por delta para no depender de FPS.
- Sincronías de estado: Entrega debe bloquear daño y acciones del héroe con bandera clara.
- Minijuegos desacoplados: exponer API común `start(params)` y `signal completed(result)`.
- JSON de datos: validar claves en carga y fallar con mensaje útil.

---

## 12) Alternativas y contingencias

- Si falta tiempo:
  - Reducir minijuegos a 2 (Forja y Coser) y simular el resto como “auto Bien”.
  - Enemigos sin estados especiales; jefe sin fase 2.
  - UI de corredor sin mini-iconos, solo índice textual.
- Si Godot 4.5 no está disponible: usar 2D puro y eliminar cualquier dependencia de 3D.

---

## 13) Criterios de victoria y derrota

- Victoria: jefe derrotado en última sala, pantalla “Habrá más mundos”.
- Derrota global: 50 muertes del héroe. Guardar stats de la run.

---

## 14) Entregables finales

- Juego ejecutable del corredor con minijuegos integrados.
- Carpeta `/scenes/sandboxes` con escenas de test por sistema.
- Logs de telemetría simple y tabla de métricas en README.
- GIF corto de gameplay en `docs/`.
