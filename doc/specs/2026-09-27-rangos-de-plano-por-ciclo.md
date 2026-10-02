# Rangos de plano por ciclo

**Fecha:** 2026-09-27 · **Estado:** aprobado; revisado el 2026-09-27 con el muro y el farmeo (apartado 7); tarea 3 del plan (calibración del balance) hecha con Balanza el 2026-10-01 (apartado 6); siguen las tareas 4 a 11 y la 13
**Petición:** "Qué le faltaría al juego para estar completo". El análisis encontró que el juego se agota pronto: los 12 planos se desbloquean al pasar la sala 9 y el poder de Tico tiene techo, porque solo cuenta el equipo, mientras los enemigos crecen sin límite. El usuario eligió publicar **gratis primero** (medir la retención antes de monetizar) y, como eje de progresión infinito, **rangos de plano por ciclo**, con estas decisiones:

| Pregunta | Elegido |
|---|---|
| Qué crece sin límite | Rangos de plano por ciclo de biomas |
| Dónde sigue Tico al morir | Delante del muro: farmea la sala anterior y lo reintenta (revisión) |
| Cómo vuelve a los biomas anteriores | Selector de sala y candado (revisión) |
| Qué piden los rangos altos | Materiales nuevos, uno por bioma |
| Cómo se desbloquea un rango | Por los jefes del ciclo |
| Dificultad de los minijuegos | Sube con el rango, con tope |
| Opcionales | Encargo propio (la vuelta rápida se quitó en la revisión) |

**Revisión (2026-09-27):** el usuario encontró en Orc Incremental (Steam) el bucle que tenía en mente: el héroe avanza solo hasta chocar con un muro, muere, mejora y vuelve a intentarlo. Aquí la mejora sale de la forja. Cambian los apartados 1, 6, 7, 8, 9, 10, 11, 12 y 13.

---

## 1. Objetivo y criterios de éxito

Cada vuelta completa a los 5 biomas (un ciclo, 50 salas) desbloquea versiones más fuertes de los 12 planos. Bajar más da mejor forja, y la forja es la que permite bajar más.

Criterios:
- Siempre hay un objetivo a la vista: el muro (el primer enemigo que Tico no vence) y el siguiente hito de desbloqueo.
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
| Coser | `stitch_speed`, `precision` | velocidad ×1,08; precision −0,05 (en coser, más precisión agranda las ventanas: es más fácil) | 1,6; 0,0 |
| Temple | `quench_speed`, `time_window` | velocidad ×1,08; ventana ×0,92 | velocidad 2,0; ventana 0,12 |

- Los topes se confirman jugando en un móvil real (tarjeta de prueba en dispositivo) y quedan por debajo de los límites que ya aplica cada minijuego.
- **Arreglo previo, porque hoy la dificultad por plano no llega entera a los minijuegos:**
  - La forja lee `difficulty`, pero los planos le pasan `precision`: la ventana de la forja es igual en todos los niveles. La forja pasa a leer `precision`, con `difficulty` como alternativa.
  - Los planos de botas pasan `circles` y `difficulty`, que el minijuego de coser no lee: las botas se cosen igual en básico y en maestro. Pasan a `SewTrialConfig` con `stitch_speed` y `precision`, escalonados como el resto de piezas: la velocidad sube del básico al maestro y la precisión baja, porque en coser una precisión menor da ventanas más pequeñas.

**Encargo propio (opcional aprobado):**
- En la biblioteca de planos, cada plano desbloqueado muestra su rango máximo, un selector de rango (del I al máximo) y el botón **Forjar**.
- Forjar paga los materiales de la receta de ese rango y encola la tarea en la cola de 5 huecos, como un pedido. No da oro.
- Sin materiales, la tarjeta tiembla y avisa de lo que falta, como las de pedido. Con la cola llena, avisa y no cobra.
- Los pedidos gratis no aplican.

## 6. Balance

**Objetivos: pequeños muros.** Decisión del usuario: "cada bicho es un pequeño muro, que te obligue a farmear un poco el anterior". Se miden en duelos (apartado 7): un equipo llega hasta la última sala en la que Tico gana el duelo con la vida llena, y la siguiente es su muro. Objetivos para cada rango N, confirmados con el usuario el 2026-10-01 tal cual:
- **Escalera:** 15 estados, que son las piezas básicas, avanzadas y maestras con calidad 0,40, 0,55, 0,70, 0,85 y 1,00, con las 4 piezas equipadas. De un estado al siguiente, el muro avanza de 0 a 6 salas: mejorar siempre se nota, pero ningún salto se come medio bioma.
- **Hitos, con calidad 0,85:** el básico vence al jefe de la sala 50·(N−1)+20, el avanzado al de la +40 y el maestro al de la 50·N (acaba el ciclo).
- **Cotas, con calidad 1,00:** el básico no vence al jefe +40, el avanzado no acaba el ciclo y el maestro no vence al jefe 50·N+10.
- Sustituye a los objetivos de la primera versión del spec, que medían carreras sin curarse con calidad 0,55.

**Base de Tico.** Decisión del usuario: escala con el rango de su equipo. La regla que da "el rango del equipo" va en una sola función, porque el inventario en rejilla la redefine. Con 4 huecos, es el menor rango entre las piezas equipadas.

**Simulación.** Una escena de pruebas sin ventana (el motor Balanza, con el enlace `scripts/tests/BalanzaBinding.gd`) calcula, con las fórmulas reales de `Hero` y `Enemy`, el muro de cada combinación de rango, nivel de pieza y calidad: el primer enemigo al que Tico no gana el duelo. Usa el daño esperado por segundo de cada lado (`expected_dps`), la armadura y el tiempo hasta matar, sin azar, y comprueba los objetivos para los ciclos I a V.

**Palancas que fija la calibración:**
- las constantes de `EnemyScaling` (la fórmula de la curva sale de `Enemy.reset_stats` a esa clase estática; se mantienen los arquetipos); el multiplicador de los jefes, antes fijo en ×1,6, pasó a ser una palanca más (decisión del 2026-10-01, más abajo);
- `stat_mult(N)` y la base de Tico por rango;
- `mat_mult(N)`: punto de partida, 1,6^(N−1);
- las cantidades del apartado 4.

**Lo aprendido en la tarea 3.** Medía carreras sin curarse; con duelos hay que rehacer las cuentas.
- Con las palancas de partida no se cumplía casi nada:
  - la agilidad y la inteligencia del enemigo crecen fuera de la curva, y el pulso mágico ignora la armadura;
  - la mitigación de la armadura (`armor / (armor + K)`, con K = 40 de partida y tope del 60 %) deja de importar en rangos altos;
  - la base de Tico no escalaba con el rango.
- Este es el modelo que cumple los objetivos. La réplica en Python fue solo su punto de partida (×1,006 por sala dentro del ciclo y un salto de ×8 al empezar cada ciclo); los valores finales son los de «Estado», más abajo:
  - la curva de enemigos va en escalera: poco por sala dentro del ciclo y un salto al empezar cada ciclo;
  - la agilidad y la inteligencia del enemigo se quedan en las de la sala 1, y su pulso crece con la escala;
  - la armadura se compara con la escala del enemigo;
  - la base de Tico se multiplica por el salto elevado a (rango del equipo − 1);
  - la espada básica conserva su daño máximo (8) y su ritmo máximo (0,15), que la réplica subía a 12 y a 0,225: el catálogo calibrado solo le mueve el crítico (0,04 a 0,09) y el ritmo mínimo (0,065).
- Con el salto calibrado de ×10,5, el equipo de rango V multiplica por unos 12.155 (10,5⁴): la interfaz necesitará cifras abreviadas.

**Consecuencia aceptada:** en el ciclo I las piezas maestras llegan en la sala 40 en lugar de hacia la 9. El principio es más lento y el contenido dura más.

**Estado (2026-10-01): calibrada con Balanza.**
- La calibración se hizo con el motor de balance reutilizable (Balanza), con el enlace `scripts/tests/BalanzaBinding.gd` y los 35 objetivos de `balance/balance.json`. Falta repetirla con el inventario en rejilla (su spec, apartado 6).
- El riesgo que justificó la pausa (que la tarea 6 atascara la partida) queda resuelto: con el catálogo calibrado, el equipo básico del ciclo I con calidad 0,85 tiene su muro en la sala 37, y el hito pide pasar de la 20.
- El intento anterior (carreras sin curarse) queda solo como historia: el código, en la rama local `rangos-calibracion-aparcada`; el informe y la réplica en Python, en `.superpowers/sdd/2026-09-27-rangos-de-plano-por-ciclo/` (fuera de git).
- **Valores calibrados (2026-10-01, con Balanza):** `EnemyScaling.EXP` = 1,0455, `EnemyScaling.STEP` = 10,5, `EnemyScaling.BOSS_MULT` = 1,15, `CombatMath.ARMOR_K` = 60, `Ranks.RANK_POWER_BONUS` = 1. Objetos: los de `balance/catalog.json` (importados a `data/items/`). Comprobación: `bash balance/arnes.sh check` (35 objetivos, `balance/balance.json`); el informe es `balance/report.md`.
- **Decisiones de la calibración:**
  - Por decisión del usuario (2026-10-01), el multiplicador de los jefes dejó de ser fijo en ×1,6 y pasó a ser una palanca de calibración. Se calibró en ×1,15: con ×1,6 todos los muros caían en salas de jefe y la escalera no se podía cumplir.
  - El salto de ciclo es ×10,5 y no ×8, así que el equipo de rango V multiplica por unos 12.155: la interfaz necesitará cifras abreviadas.
  - El `progress` del enlace de Balanza (solo sirve para medir; los objetivos no lo usan) se interpola contra el esqueleto de la curva en lugar de calcularse como `muro − 1 + fracción`, porque esa fórmula daba un salto en cada sala ganada.
  - Los 35 objetivos no se cambiaron. El muro se entiende así: vencer al jefe de la sala R equivale a muro ≥ R + 1.
- **Resultado:** 35 de 35 con los `.tres` ya importados, con el redondeo del juego. Las cotas del básico en N = 4 y N = 5 son las más justas: 1 sala de holgura (muro 189 y 239 frente a < 191 y < 241).

## 7. Muro, farmeo y selector de sala

**Referencia del usuario:** Orc Incremental (Steam). El ejército avanza solo hasta chocar con un muro, muere, mejora y vuelve a intentarlo. En PetJam la mejora sale de la forja.

**Duelos:**
- Tico entra en cada sala con la vida llena: los golpes de una sala no pasan a la siguiente.
- La poción de Vida sigue sirviendo a mitad de un duelo.

**Récord y muro:**
- El récord (`GameManager.best_enemy_level`) es la sala más profunda que Tico ha alcanzado y aún no ha vencido. Vencerla lo sube aunque Tico no avance, por ejemplo con el candado puesto.
- **El muro** es la sala donde Tico perdió por última vez, hasta que la vence. Casi siempre es la del récord.
- Los hitos del apartado 3 no cambian: el jefe de la sala X está vencido si el récord es mayor que X.

**Al perder en la sala X:**
- Tico reaparece en la sala X−1 (en la 1 si X es la 1), con la animación de siempre. Morir no cuesta nada más que ese tiempo.
- Delante del muro, farmea la sala anterior: la repite y se queda con su botín.
- Vuelve a probar el muro cada 3 victorias (constante `WALL_RETRY_WINS`), y también en cuanto le cambian el equipo o bebe una poción de efecto (Velocidad o Suerte). La de Vida no cuenta: se gasta en el duelo en curso.
- Con el muro en la sala 1, lo reintenta cada vez que reaparece.
- Al vencer el muro, deja de haberlo y Tico sigue avanzando.

**Selector de sala y candado** (junto al indicador de sala de la franja, hoy en `HeroViewOverlay`):
- **Flechas:** mandan a Tico a cualquier sala entre la 1 y el récord. Elegir el récord es probarlo ya. Mantener pulsada una flecha salta al principio del bioma anterior o del siguiente.
- **Viaje:** instantáneo, con un fundido. Si había un combate a medias, se abandona sin premio ni castigo.
- **Candado:** elegir a mano una sala por debajo del récord lo pone (elegir el muro o el récord es probarlo, sin candado). Con el candado, Tico repite esa sala sin fin y no reintenta el muro. Sirve, por ejemplo, para farmear hueso en las Catacumbas.
- **Quitar el candado** lleva a Tico a la sala anterior al muro, o a la anterior al récord si no hay muro (como mínimo, a la 1). Desde ahí sigue el bucle: delante de un muro farmea y reintenta; si no, avanza.
- **Si muere con el candado puesto,** reaparece en la sala anterior y el candado baja con él.
- **Muro a la vista:** con muro, el indicador dice "Muro: sala N" en lugar de "Récord: sala N".
- Los controles tienen tamaño de dedo en un móvil.

**Botín al farmear:**
- El de siempre (apartado 4), incluido el material de bioma.
- El extra del jefe (10 × `mat_mult` de su material) solo cae cuando su muerte sube el récord. Si se repite, suelta el botín de un enemigo normal. Así, poner el candado en un jefe no multiplica el material de bioma.

**Se quitan** la vuelta a la sala 1 al morir y la vuelta rápida.

**Dónde vive:** `GameManager` (récord, muro, candado y contador de reintentos), `Corridor` y `Hero` (vida llena al entrar, reaparición, viaje y combate abandonado) y `HeroViewOverlay` (selector, candado y muro).

## 8. Datos y guardado

- **Datos que ganan rango:**
  - `CraftedItem.rank` (1 por defecto): se guarda en `to_dict` y se lee en `from_dict`. Las estadísticas calculadas ya incluyen el multiplicador.
  - `DataManager`: rango máximo desbloqueado por plano.
  - `RequestsManager`: el rango de cada pedido activo. No se guarda: hoy `RequestsManager` solo guarda `free_requests_remaining` y los pedidos se rehacen al arrancar.
  - `CraftingManager`: el rango y el origen de cada tarea. Tampoco se guarda: la cola no se guarda.
- **Guardado versión 3** (`SaveManager.SAVE_VERSION`; la 2 es la del inventario en rejilla), con migración desde la 1 y desde la 2:
  - desde la 1, el inventario se migra a la rejilla como dice el spec del inventario (apartado 10) y los objetos forjados pasan a rango I;
  - desde la 2, las piezas ya guardan su rango (1) y no se mueven;
  - en las dos, los planos desbloqueados se conservan como rango I;
  - después se aplican los hitos que ya supera el récord (apartado 3);
  - antes de migrar, `SaveManager` copia la partida en `save.v<versión de origen>.bak.json`, solo si esa copia no existe.
- **Muro y candado:** `GameManager` guarda también el candado y la sala del muro (0 si no hay). La sala actual ya se guardaba (`current_enemy_level`). El contador de reintentos vuelve a 0 al cargar, y una partida de la versión 1 carga sin candado ni muro.
- Si ya está hecha la tarjeta de guardado robusto (escritura atómica y copia de seguridad), la migración se hace sobre ella. Si no, esta tarjeta no la adelanta.

## 9. Textos e idioma

- Los textos nuevos van en español, que es el texto base, con su entrada en el CSV de inglés de la tarjeta de traducción. Algunos ejemplos: nombres de material, "Forjar", avisos de hito, numerales y "Muro: sala %d".
- Los que se pintan en la franja respetan los caracteres de `PixelFont`: A-Z, ÁÉÍÓÚÜÑ, cifras y ! ¡ ? ¿ . , : ; - + / ( ) % ' · ×.

## 10. Pruebas

- **`RankTests`** (suite sobre `TestSuite.gd`):
  - `Ranks`: ciclo de una sala, hitos, multiplicadores crecientes y recetas por nivel de pieza.
  - `TrialDifficulty`: sube con el rango y respeta los topes; las claves que llegan a cada minijuego son las que este lee.
  - Hitos: al entrar en los ciclos I y II y al vencer a los jefes +20 y +40 se desbloquea lo que toca, una sola vez.
  - Pedidos: el reparto 80/20 por rango, con una semilla fija; el oro crece con el rango.
  - Crafteo: la tarea de rango N da un objeto de rango N con las estadísticas multiplicadas; el encargo propio cobra la receta y no da oro.
  - Botín: la cantidad crece con el ciclo; el material de bioma cae solo en su bioma; el jefe siempre suelta el suyo.
  - Guardado: una partida de versión 1 (fichero de prueba) y otra de versión 2 cargan en la versión 3 sin perder objetos ni planos, con los hitos del récord aplicados y la copia de cada una.
  - Botín del jefe: el extra solo cae cuando su muerte sube el récord.
- **Arnés de Balanza** (`bash balance/arnes.sh check`): los 35 objetivos de `balance/balance.json` (los del apartado 6 para los ciclos I a V), medidos en duelos, como comprobaciones.
- **`GameplayTests`**, además de seguir en verde:
  - Muro y farmeo: al perder en la sala X, Tico reaparece en la X−1 con el muro en la X; vuelve al muro tras 3 victorias y en cuanto cambia el equipo o bebe una poción de efecto; con el muro en la sala 1 lo reintenta; entra en cada sala con la vida llena.
  - Selector y candado: no pasa del récord; elegir sala pone el candado (salvo el muro); con candado repite la sala; morir con candado lo baja una sala; quitarlo lo lleva delante del muro; cambiar de sala a mitad de un combate lo abandona sin premio; con Tico caído, el viaje espera a la reaparición.
  - Guardado del muro: la sala, el candado y el muro se guardan y se cargan.
- **Siguen en verde:** `PixelTests`.
- **Capturas con `VisualCapture`:** tarjeta de pedido con numeral, biblioteca con el selector de rango, botín con material de bioma, aviso de hito y selector de sala con el candado y el muro.

## 11. Qué cambia en el código

- **Nuevos:**
  - `scripts/core/Ranks.gd`, `scripts/core/EnemyScaling.gd` y `scripts/core/TrialDifficulty.gd`;
  - `data/materials/{bone,moss,obsidian,frost,void_shard}.tres`;
  - iconos en `tools/pixel_art` → `art/sprites/pixel/materials/`;
  - `scenes/tests/RankTests.tscn` con su script, y el enlace de Balanza (`scripts/tests/BalanzaBinding.gd`, con `balance/` y `addons/balanza/`).
- **Modificados:**
  - Autoloads y núcleo: `DataManager`, `GameManager`, `RequestsManager`, `CraftingManager`, `CraftedItem` y `SaveManager`.
  - Pasillo: `Enemy` (curva y botín, con el extra de jefe solo con récord nuevo), `Corridor` y `Hero` (duelos con la vida llena, reaparición delante del muro y viaje entre salas).
  - Minijuegos: `ForgeMinigame` (lee `precision`) y los `.tres` de las botas.
  - Interfaz: `BlueprintLibraryPanel` y `BlueprintCard` (rango y encargo), `RequestSlot` (numeral), `EquipmentPanel` y `CraftResultScreen` (numeral), `HUDMinigameLauncher` (materiales nuevos) y `HeroViewOverlay` (aviso de hito, selector de sala, candado y muro).
- **Sin autoloads nuevos ni plugins.** GDScript con tabuladores y comentarios en español.

## 12. Fases

1. **Simulación y curva:** `EnemyScaling`, `Ranks` (solo multiplicadores), el enlace de Balanza (`BalanzaBinding`) y la calibración. El juego cambia solo en la curva de enemigos.
2. **Rango en los datos:** `CraftedItem`, `DataManager`, el guardado versión 2 y su migración.
3. **Hitos, pedidos y oro por rango.**
4. **Materiales de bioma:** datos, iconos, botín y recetas.
5. **Dificultad por rango**, con el arreglo de las claves de forja y botas.
6. **Encargo propio y numerales en la interfaz.**
7. **Muro, farmeo y selector de sala.** No depende de la calibración, así que puede ir antes.
8. **Verificación:** capturas, simulación y prueba en un móvil de los topes de dificultad (con la tarjeta de dispositivo real).

## 13. Fuera de alcance

- Prestigio y progreso offline (tarjetas aparte; el offline farmeará la sala donde esté Tico, con estas reglas).
- La variedad de jefes entre ciclos: en Orc Incremental se critica que se repitan, y aquí los 5 jefes vuelven en cada ciclo. Queda para la tarjeta de pasivas de jefe.
- La ranura "Pecho" del panel de Equipo, que hoy no tiene ningún objeto (tarjeta nueva).
- Cómo se ve el rango en el sprite de Tico (la fase 2 del pixel art dibuja pieza y calidad; el rango solo se ve en la interfaz).
- Los precios de la tienda más allá de `gold_mult` y los sumideros de oro nuevos (tarjeta de economía).
- Anuncios y compras.
