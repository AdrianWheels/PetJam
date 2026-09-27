# Rangos de plano por ciclo

**Fecha:** 2026-09-27 · **Estado:** diseño aprobado en conversación, pendiente de revisar este spec
**Petición:** "Qué le faltaría al juego para estar completo". El análisis encontró que el juego se agota pronto: los 12 planos se desbloquean al pasar la sala 9 y el poder de Tico tiene techo, porque solo cuenta el equipo, mientras los enemigos crecen sin límite. El usuario eligió publicar **gratis primero** (medir la retención antes de monetizar) y, como eje de progresión infinito, **rangos de plano por ciclo**, con estas decisiones:

| Pregunta | Elegido |
|---|---|
| Qué crece sin límite | Rangos de plano por ciclo de biomas |
| Dónde reaparece Tico al morir | Sala 1, como ahora |
| Qué piden los rangos altos | Materiales nuevos, uno por bioma |
| Cómo se desbloquea un rango | Por los jefes del ciclo |
| Dificultad de los minijuegos | Sube con el rango, con tope |
| Opcionales | Encargo propio y vuelta rápida |

---

## 1. Objetivo y criterios de éxito

Cada vuelta completa a los 5 biomas (un ciclo, 50 salas) desbloquea versiones más fuertes de los 12 planos. Bajar más da mejor forja, y la forja es la que permite bajar más.

Criterios:
- Siempre hay un objetivo a la vista: el siguiente hito de desbloqueo o el primer jefe que Tico no vence.
- Los minijuegos y la calidad siguen decidiendo: el mismo plano forjado mejor llega más lejos.
- El oro y los materiales tienen uso en todos los ciclos.
- Los objetivos de balance del apartado 6 se cumplen en la simulación para los ciclos I a V.
- Una partida guardada de hoy carga sin perder nada.

## 2. Ciclos y rangos

- **Ciclo N:** salas 50·(N−1)+1 a 50·N. Son los 5 biomas de `Biomes.LIST`, 10 salas cada uno, con un jefe en cada sala múltiplo de 10. Coincide con el numeral que ya muestra `Biomes.display_name` (Catacumbas II empieza en la sala 51).
- **Rango N:** la versión de los 12 planos que se desbloquea en el ciclo N. El rango I es lo que hay hoy.
- **No hay ficheros nuevos por rango.** Un plano de rango N es la pareja (plano, N). El rango se aplica al forjar:
  - Estadísticas: las del `ItemResource` según la calidad, como hoy, multiplicadas por `stat_mult(N)`. El multiplicador escala las estadísticas aditivas: daño, vida, fuerza y armadura. La agilidad, la inteligencia, el crítico y la velocidad de ataque no escalan, porque tienen tope en Tico (`Hero.reset_stats`).
  - Materiales: la receta del apartado 4, que crece con N.
  - Dificultad de sus minijuegos: el apartado 5.
- **El objeto forjado guarda su rango** y lo muestra con numeral romano: "Espada maestra III" (con `Biomes.roman`). En el rango I no se muestra numeral.
- Toda la matemática de rangos vive en una clase estática nueva, `scripts/core/Ranks.gd`:
  - ciclo de una sala;
  - hitos de desbloqueo;
  - `stat_mult`, `mat_mult` y `gold_mult`;
  - receta de un plano en un rango;
  - dificultad de un rango.

## 3. Desbloqueo por jefes

| Hito | Se desbloquea |
|---|---|
| Entrar en el ciclo N (para N = 1, al empezar la partida; para N ≥ 2, al vencer al jefe de la sala 50·(N−1)) | Los 4 planos básicos de rango N (espada, escudo, casco y botas) |
| Vencer al jefe de la sala 50·(N−1)+20 | Los 4 avanzados de rango N |
| Vencer al jefe de la sala 50·(N−1)+40 | Los 4 maestros de rango N |

- Sustituye al desbloqueo actual (un plano al azar por la primera victoria en cada sala, en `GameManager.register_enemy_defeat`) y a `DataManager.DEFAULT_UNLOCKED`.
- **Estado:** `DataManager` guarda el rango máximo desbloqueado por plano (0 = bloqueado). `is_blueprint_unlocked(id)` sigue existiendo y significa rango ≥ 1.
- **Aviso:** cada hito lanza `blueprint_unlocked` por plano, con el rango, y el cartel de la franja anuncia el grupo ("¡Planos avanzados II!"). El pergamino que vuela al botón de Planos se conserva.
- **Al cargar una partida** se aplican los hitos ya superados según el récord (`best_enemy_level`): un hito de jefe en la sala X está superado si el récord es mayor que X. Así ninguna partida queda atrás por el cambio de reglas.

## 4. Materiales de bioma

**Cinco materiales nuevos**, uno por bioma:

| Bioma (salas del ciclo) | id | Nombre | Lo piden |
|---|---|---|---|
| Catacumbas (1-10) | `bone` | Hueso | básicos |
| Cripta Musgosa (11-20) | `moss` | Musgo | avanzados |
| Caverna de Magma (21-30) | `obsidian` | Obsidiana | avanzados |
| Glaciar Olvidado (31-40) | `frost` | Escarcha | maestros |
| Santuario del Vacío (41-50) | `void_shard` | Fragmento de vacío | maestros |

- Son recursos `MaterialResource` en `data/materials/`, con icono pixel dibujado en `tools/pixel_art` (12x12 para el botín de la franja y el mismo sprite ampliado con Nearest en la interfaz).
- Cada hito pide llegar un poco más allá del jefe que lo desbloquea: la obsidiana cae después del jefe +20 y el fragmento de vacío después del +40.

**Receta de un plano en el rango N:**
- los materiales de siempre del `.tres`, multiplicados por `mat_mult(N)`;
- más los de su bioma, según el nivel de la pieza:
  - básico: hueso;
  - avanzado: musgo y obsidiana;
  - maestro: escarcha y fragmento de vacío.
- La cantidad base de material de bioma es de 2 por material, multiplicada por `mat_mult(N)`. Se ajusta en la simulación de economía.
- Vale también para el rango I: los materiales nuevos tienen uso desde el principio.

**Botín:**
- Cada enemigo suelta, como hoy, una tanda de un material de siempre al azar. La tanda pasa de 15 fijo a `15 × mat_mult(ciclo de la sala)`.
- Además tiene un 30 % de probabilidad de soltar `3 × mat_mult(ciclo)` del material de su bioma.
- Los jefes sueltan siempre `10 × mat_mult(ciclo)` del material de su bioma, además de la tanda normal.
- La poción de Suerte (botín doble) aplica a la tanda de material de siempre.
- Regla de diseño: las recetas y el botín crecen al mismo ritmo (`mat_mult`), así que forjar un plano cuesta más o menos las mismas victorias en todos los ciclos.

**Otros cambios:**
- La hierba sigue sin uso: el material de la Cripta es el musgo, como se aprobó. `data/materials/herb.tres` se conserva.
- Los materiales nuevos entran en el orden de materiales de `HUDMinigameLauncher` y en el inventario. No se venden en la tienda: su única fuente es la mazmorra.

## 5. Pedidos, oro y forja

**Pedidos (`RequestsManager`):**
- Cada pedido elige un plano entre los desbloqueados. Su rango es el máximo desbloqueado de ese plano con un 80 % de probabilidad, y el anterior con un 20 % (si existe).
- El pedido guarda su rango, y la tarjeta muestra el numeral.
- **Oro:** la recompensa actual (50 + 10 por material + 15 por prueba, por el multiplicador de grado) se multiplica por `gold_mult(N)`. Regla inicial: `gold_mult = mat_mult`, para que el oro compre en la tienda la misma proporción de materiales en cada ciclo.
- Los 2 pedidos gratis del principio no cambian.

**Crafteo (`CraftingManager`):**
- La tarea guarda el rango y el origen (pedido o encargo propio).
- Al terminar crea el `CraftedItem` con su rango.
- `_finalize_task` hoy da 50 de oro base cuando la recompensa es 0. Con un encargo propio no da oro.

**Dificultad por rango:**
- Una clase nueva, `scripts/core/TrialDifficulty.gd`, ajusta la copia de la configuración de cada prueba antes de lanzarla (en `CraftingManager._resolve_trial_config`).
- Toca solo los parámetros que cada minijuego lee de verdad:

| Minijuego | Parámetros | Por cada rango por encima del I | Tope |
|---|---|---|---|
| Forja | `forge_speed`, `difficulty` | velocidad ×1,1; difficulty +0,06 | velocidad 2,0; difficulty 0,85 |
| Martillo | `hammer_speed`, `precision` | bpm ×1,08; precision +0,05 | 160 bpm; 0,85 |
| Coser | `stitch_speed`, `precision` | velocidad ×1,08; precision +0,05 | 1,6; 0,85 |
| Temple | `quench_speed`, `time_window` | velocidad ×1,08; ventana ×0,92 | velocidad 2,0; ventana 0,12 |

- Los topes se confirman jugando en un móvil real (tarjeta de prueba en dispositivo) y quedan por debajo de los límites que ya aplica cada minijuego.
- **Arreglo previo, porque hoy la dificultad por plano no llega entera a los minijuegos:**
  - La forja lee `difficulty`, pero los planos le pasan `precision`: la ventana de la forja es igual en todos los niveles. La forja pasa a leer `precision`, con `difficulty` como alternativa.
  - Los planos de botas pasan `circles` y `difficulty`, que el minijuego de coser no lee: las botas se cosen igual en básico y en maestro. Pasan a `SewTrialConfig` con `stitch_speed` y `precision`, escalonados como el resto de piezas.

**Encargo propio (opcional aprobado):**
- En la biblioteca de planos, cada plano desbloqueado muestra su rango máximo, un selector de rango (del I al máximo) y el botón **Forjar**.
- Forjar paga los materiales de la receta de ese rango y encola la tarea en la cola de 5 huecos, como un pedido. No da oro.
- Sin materiales, la tarjeta tiembla y avisa de lo que falta, como las de pedido. Con la cola llena, avisa y no cobra.
- Los pedidos gratis no aplican.

## 6. Balance

**Objetivos por ciclo.** "Calidad media" es 0,55 y cada objetivo cuenta con las 4 piezas equipadas:

| Con el equipo de rango N | Debe |
|---|---|
| Básico, calidad media | vencer al jefe de la sala 50·(N−1)+20 |
| Avanzado, calidad media | vencer al jefe de la sala 50·(N−1)+40 |
| Maestro, calidad media | vencer al jefe de la sala 50·N (acabar el ciclo) |
| Maestro, calidad 1,0 | **no** vencer al jefe de la sala 50·N+10 (el primero del ciclo siguiente) |

- Con la curva actual el primero ya falla: por las cuentas del análisis, con equipo básico Tico pierde contra el jefe de la sala 10. La curva de enemigos cambia:
  - la fórmula sale de `Enemy.reset_stats` a una clase estática nueva, `scripts/core/EnemyScaling.gd`, con constantes ajustables;
  - se mantienen los arquetipos y el ×1,6 de los jefes.
- **Simulación antes de tocar el juego:** una escena de pruebas sin ventana (`BalanceSim`) que calcula, con las fórmulas reales de `Hero` y `Enemy`, quién gana cada sala. Usa el daño esperado por segundo de cada lado (`expected_dps`), la armadura y el tiempo hasta matar, sin azar. Informa de la sala máxima para cada (rango, nivel de pieza, calidad) y comprueba los objetivos de la tabla para los ciclos I a V.
- Con ella se fijan:
  - las constantes de `EnemyScaling`;
  - `stat_mult(N)`: punto de partida, la relación entre la escala del enemigo a mitad del ciclo N y a mitad del ciclo I;
  - `mat_mult(N)`: punto de partida, 1,6^(N−1);
  - las cantidades del apartado 4.
- **Riesgos a vigilar en la simulación:**
  - la mitigación de armadura (`armor / (armor + 40)`, con tope del 60 %) deja de importar en rangos altos, así que puede tener que compararse con el nivel del enemigo;
  - el pulso mágico (`INT × 3`) no escala con el rango y se vuelve irrelevante.
- **Consecuencia aceptada:** en el ciclo I las piezas maestras llegan en la sala 40 en lugar de hacia la 9. El principio es más lento y el contenido dura más.

## 7. Muerte y vuelta rápida

- Al morir, Tico vuelve a la sala 1, como ahora. El récord no cambia.
- **Vuelta rápida (opcional aprobado).** Se activa en una sala cuando se cumplen dos condiciones:
  - la sala está por debajo del récord;
  - un golpe sin crítico de Tico basta para matar al enemigo de esa sala.
- Mientras está activa, Tico:
  - anda 3 veces más rápido;
  - ataca nada más llegar al enemigo;
  - apenas se detiene tras la muerte (pausa al 25 %).
- En esas salas no hay hit-stop ni temblor, para que la carrera no dé tirones.
- Se acaba en la primera sala que no cumple las dos condiciones.
- No hay carteles: se nota por la velocidad.
- Vive en `Corridor` y `Hero` (velocidad de paso y primer ataque), sin cambiar la lógica de combate.

## 8. Datos y guardado

- **Datos que ganan rango:**
  - `CraftedItem.rank` (1 por defecto): se guarda en `to_dict` y se lee en `from_dict`. Las estadísticas calculadas ya incluyen el multiplicador.
  - `DataManager`: rango máximo desbloqueado por plano.
  - `RequestsManager`: el rango de cada pedido activo.
  - `CraftingManager`: el rango y el origen de cada tarea.
- **Guardado versión 2** (`SaveManager.SAVE_VERSION`), con migración desde la 1:
  - los objetos forjados pasan a rango I;
  - los planos desbloqueados se conservan como rango I;
  - después se aplican los hitos que ya supera el récord (apartado 3).
- Si ya está hecha la tarjeta de guardado robusto (escritura atómica y copia de seguridad), la migración se hace sobre ella. Si no, esta tarjeta no la adelanta.

## 9. Textos e idioma

- Los textos nuevos van en español, que es el texto base, con su entrada en el CSV de inglés de la tarjeta de traducción. Algunos ejemplos: nombres de material, "Forjar", avisos de hito y numerales.
- Los que se pintan en la franja respetan los caracteres de `PixelFont`: A-Z, ÁÉÍÓÚÜÑ, cifras y ! ¡ ? ¿ . , : ; - + / ( ) % ' · ×.

## 10. Pruebas

- **`RankTests`** (suite sobre `TestSuite.gd`):
  - `Ranks`: ciclo de una sala, hitos, multiplicadores crecientes y recetas por nivel de pieza.
  - `TrialDifficulty`: sube con el rango y respeta los topes; las claves que llegan a cada minijuego son las que este lee.
  - Hitos: al entrar en los ciclos I y II y al vencer a los jefes +20 y +40 se desbloquea lo que toca, una sola vez.
  - Pedidos: el reparto 80/20 por rango, con una semilla fija; el oro crece con el rango.
  - Crafteo: la tarea de rango N da un objeto de rango N con las estadísticas multiplicadas; el encargo propio cobra la receta y no da oro.
  - Botín: la cantidad crece con el ciclo; el material de bioma cae solo en su bioma; el jefe siempre suelta el suyo.
  - Guardado: una partida de versión 1 (fichero de prueba) carga en la versión 2 sin perder objetos ni planos, con los hitos del récord aplicados.
  - Vuelta rápida: activa por debajo del récord cuando un golpe mata e inactiva en caso contrario.
- **`BalanceSim`:** los objetivos del apartado 6 para los ciclos I a V, como comprobaciones.
- **Siguen en verde:** `PixelTests` y `GameplayTests`.
- **Capturas con `VisualCapture`:** tarjeta de pedido con numeral, biblioteca con el selector de rango, botín con material de bioma y aviso de hito.

## 11. Qué cambia en el código

- **Nuevos:**
  - `scripts/core/Ranks.gd`, `scripts/core/EnemyScaling.gd` y `scripts/core/TrialDifficulty.gd`;
  - `data/materials/{bone,moss,obsidian,frost,void_shard}.tres`;
  - iconos en `tools/pixel_art` → `art/sprites/pixel/materials/`;
  - `scenes/tests/RankTests.tscn` y `scenes/tests/BalanceSim.tscn`, con sus scripts.
- **Modificados:**
  - Autoloads y núcleo: `DataManager`, `GameManager`, `RequestsManager`, `CraftingManager`, `CraftedItem` y `SaveManager`.
  - Pasillo: `Enemy` (curva y botín), `Corridor` y `Hero` (vuelta rápida).
  - Minijuegos: `ForgeMinigame` (lee `precision`) y los `.tres` de las botas.
  - Interfaz: `BlueprintLibraryPanel` y `BlueprintCard` (rango y encargo), `RequestSlot` (numeral), `EquipmentPanel` y `CraftResultScreen` (numeral), `HUDMinigameLauncher` (materiales nuevos) y `HeroViewOverlay` (aviso de hito).
- **Sin autoloads nuevos ni plugins.** GDScript con tabuladores y comentarios en español.

## 12. Fases

1. **Simulación y curva:** `EnemyScaling`, `Ranks` (solo multiplicadores), `BalanceSim` y la calibración. El juego cambia solo en la curva de enemigos.
2. **Rango en los datos:** `CraftedItem`, `DataManager`, el guardado versión 2 y su migración.
3. **Hitos, pedidos y oro por rango.**
4. **Materiales de bioma:** datos, iconos, botín y recetas.
5. **Dificultad por rango**, con el arreglo de las claves de forja y botas.
6. **Encargo propio y numerales en la interfaz.**
7. **Vuelta rápida.**
8. **Verificación:** capturas, simulación y prueba en un móvil de los topes de dificultad (con la tarjeta de dispositivo real).

## 13. Fuera de alcance

- Prestigio y progreso offline (tarjetas aparte; el offline usará estas reglas).
- La ranura "Pecho" del panel de Equipo, que hoy no tiene ningún objeto (tarjeta nueva).
- Cómo se ve el rango en el sprite de Tico (la fase 2 del pixel art dibuja pieza y calidad; el rango solo se ve en la interfaz).
- Los precios de la tienda más allá de `gold_mult` y los sumideros de oro nuevos (tarjeta de economía).
- Anuncios y compras.
