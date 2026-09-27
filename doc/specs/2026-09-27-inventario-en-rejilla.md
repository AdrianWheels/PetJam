# Inventario en rejilla

**Fecha:** 2026-09-27 · **Estado:** aprobado. El 2026-09-28, al escribir el plan, se ajustó a la revisión del spec de rangos (duelos con la vida llena, muro y calibración con Balanza) y a la fase 2 del pixel art, en los apartados 3.2, 5, 6, 7, 8, 9.5, 13, 14 y 16
**Petición:** "Quiero que el inventario del héroe de PetJam funcione como el de Lootbound" (https://store.steampowered.com/app/3091140/Lootbound/). En Lootbound el equipo es una rejilla delante de la silueta del héroe, sin huecos fijos: cada objeto ocupa una forma que se gira y se coloca donde quepa. Hay mochila, botín y 2 consumibles, y algunos objetos dan auras a sus vecinos o se activan por su posición. La tarjeta del tablero pide que colocar lo que se forja sea un puzle con sinergias y dé más razones para forjar. Decisiones del usuario:

| Pregunta | Elegido |
|---|---|
| Qué se quiere de la rejilla | Las dos cosas: encajar piezas con forma y auras entre vecinas |
| Cuántas piezas lleva Tico | Lo que quepa, sin límite por tipo |
| Formas | Crecen con el nivel de la pieza |
| Calidad y forma | Las peores traen aristas (casillas sin poder); limpias desde Épico |
| Crecimiento de la rejilla | De 4×4 a 6×6 con 4 recetas únicas, una por jefe de las salas 10, 20, 30 y 40 del ciclo I; forjarlas siempre sale bien |
| Auras | Fijas por tipo de pieza; la calidad da la fuerza |
| Legendarias | Una habilidad de combate propia por pieza (12), multiplicativa; algunas con precio |
| Almacén | Botín sin límite y mochila de 6×4 |
| Consumibles | 2 huecos; las pociones se beben solas con una regla fija |
| Sprite de Tico | La mejor pieza de cada tipo |
| Toque | Tocar gira; mantener pulsado abre la ficha |
| Automatismos | Ninguno: lo forjado espera en el botín |
| Enfoque | Reglas en clases sin nodos; cada rejilla es un control que se dibuja a sí mismo |

---

## 1. Objetivo y criterios de éxito

El equipo de Tico deja los 5 huecos fijos de hoy (casco, arma, escudo, pecho y botas) y pasa a ser una rejilla. Cada pieza forjada ocupa una forma; todo lo que está en la rejilla cuenta para Tico, y dónde está cambia cuánto rinde.

Criterios:
- Cualquier pieza forjada puede servir: si cabe, suma. No hace falta que supere a otra.
- Mover una pieza una casilla puede cambiar las estadísticas de Tico, y el panel enseña el cambio antes de soltarla.
- La calidad de la forja se nota en la rejilla: las peores piezas ocupan más y dan auras más débiles, y las legendarias tienen una habilidad propia que se ve en la franja.
- Todo se hace con un dedo en vertical: colocar, girar, intercambiar, guardar y vender.
- Una partida guardada de antes carga sin perder ninguna pieza.
- Con rejillas llenas se cumplen los objetivos de balance del spec de rangos (`doc/specs/2026-09-27-rangos-de-plano-por-ciclo.md`, apartado 6).
- El panel se abre en menos de 50 ms y el arrastre va a 60 FPS en el móvil de pruebas.
- No queda ningún hueco imposible de llenar: el "Pecho" desaparece.

## 2. Piezas

### 2.1 Tipo
- Sale de `ItemResource.equipment_slot`: `main_hand` (espada) es **arma**; `off_hand` (escudo), `head` (casco) y `feet` (botas) son **armaduras**.
- Sirve para las auras, las zonas, las habilidades y el sprite. No limita cuántas piezas de cada tipo lleva Tico.

### 2.2 Forma limpia
Es la forma de la pieza bien hecha. Crece con el nivel, y cada nivel da más poder por casilla (apartado 6), así que las básicas siguen sirviendo para rellenar huecos. Casillas en (columna, fila), con la pieza sin girar:

| Pieza | Básico | Avanzado | Maestro |
|---|---|---|---|
| Espada | 1×2 vertical: (0,0) (0,1) | 1×3 vertical | 1×4 vertical |
| Escudo | 1×2 vertical | 2×2 | 2 de ancho y 3 de alto |
| Casco | 1×1 | 2×1 horizontal: (0,0) (1,0) | T de 4: (1,0) (0,1) (1,1) (2,1) |
| Botas | 1×1 | L de 3: (0,0) (0,1) (1,1) | L de 4: (0,0) (0,1) (0,2) (1,2) |

- Un juego completo limpio ocupa 6 casillas en básico, 12 en avanzado y 18 en maestro.
- Se guarda en cada `ItemResource` como `shape_cells: Array[Vector2i]`. El rango no cambia la forma.

### 2.3 Aristas
- Las piezas peor forjadas traen aristas: casillas de más, pegadas a la forma limpia, que no dan nada y estorban al colocar.
- Cuántas, según la calidad (`CraftedItem.get_quality_tier()`):

| Calidad | Aristas |
|---|---|
| Básico (0-39 %) | 2 |
| Bueno (40-69 %) | 2 |
| Raro (70-89 %) | 1 |
| Épico (90-98 %) y Legendario (99-100 %) | 0: forma y aspecto reales |

- **Dónde:**
  - cada `ItemResource` define `arista_spots: Array[Vector2i]`, 3 casillas pegadas por un lado a la forma limpia y elegidas a mano para que se vean creíbles: una rebaba en el filo, un bulto en el borde del escudo o una correa suelta en la bota;
  - al forjar se sortean, sin repetir, tantas como toquen;
  - se guardan en `CraftedItem.aristas`, en coordenadas de la pieza sin girar.
- Las aristas cuentan para ver si la pieza cabe, pero no dan estadísticas, no emiten ni reciben auras y no cuentan para la vecindad ni para las zonas.

### 2.4 Giro
- De 90 en 90 grados en el sentido de las agujas del reloj (`CraftedItem.rot`, de 0 a 3).
- La forma limpia y las aristas giran juntas y se normalizan para que la pieza empiece en la casilla (0,0) de su caja.

## 3. Rejilla de Tico, mochila y botín

### 3.1 Dónde está cada pieza
Cada pieza forjada está en uno solo de estos sitios (`CraftedItem.place`):
- **Tico** (`&"hero"`): su rejilla de equipo. Solo cuenta lo que hay aquí.
- **Mochila** (`&"bag"`): una rejilla de 6×4, fija. Guarda sin contar.
- **Botín** (`&"loot"`): una lista sin límite, con lo más nuevo primero. Aquí llega todo lo forjado.

Las piezas de una rejilla guardan también su casilla (`CraftedItem.cell`, la esquina de arriba a la izquierda de su caja) y su giro.

### 3.2 Colocar, intercambiar y vender
- Una pieza cabe si todas sus casillas, limpias y aristas, están dentro de la rejilla y no pisan otra pieza.
- Al soltar una pieza:
  - **en casillas libres de una rejilla:** se coloca;
  - **encima de una sola pieza, si cabe al quitarla:** se intercambian. La otra va al sitio de donde salió la primera (la misma rejilla y casilla, o el botín) con su propio giro, si cabe allí; si no, al botín;
  - **encima de dos o más piezas, fuera de una rejilla o donde no cabe:** vuelve a su sitio;
  - **en el botín:** pasa al botín;
  - **en la zona de venta:** se vende al precio de la tienda (`ShopPanel._get_sell_price`, que el spec de rangos multiplica por el rango). Vender una Épica o una Legendaria pide confirmación.
- **Vender todo:** vende las piezas del botín, salvo las Épicas y las Legendarias, tras una confirmación con el total. No toca la mochila ni la rejilla de Tico.
- **Nada se coloca solo.** La única excepción es la migración de partidas antiguas (apartado 10).
- **Muro de los rangos:** colocar, quitar, girar o intercambiar una pieza de la rejilla de Tico cuenta como cambiarle el equipo. Tico vuelve a probar el muro (spec de rangos, apartado 7).

### 3.3 Tamaño de la rejilla de Tico
- Empieza en 4×4 (ancho × alto) y llega a 6×6 con las 4 recetas de ampliación (apartado 7): 4×4 → 5×4 → 5×5 → 6×5 → 6×6.
- Las columnas nuevas se añaden a la derecha y las filas, abajo.
- Al ampliar, ninguna pieza se mueve. Las zonas de la columna derecha y de la fila de abajo pasan al borde nuevo.

## 4. Auras y zonas

### 4.1 Auras
Cada tipo de pieza emite un aura fija; su fuerza depende de la calidad de quien la emite.

| Pieza | Aura |
|---|---|
| Espada | Más daño a las armas vecinas |
| Escudo | Más armadura a las armaduras vecinas |
| Casco | Más vida a todas las piezas vecinas |
| Botas | Más velocidad de ataque a las armas vecinas |

| Calidad del emisor | Básico | Bueno | Raro | Épico | Legendario |
|---|---|---|---|---|---|
| Fuerza | 0 % | 5 % | 10 % | 15 % | 20 % |

- **Vecinas:** dos piezas lo son si alguna casilla limpia de una toca por un lado (arriba, abajo, izquierda o derecha) alguna casilla limpia de la otra. Las diagonales no cuentan.
- **Una vez por vecina:** cada pieza recibe el aura de cada vecina una sola vez, aunque se toquen por varias casillas. Ninguna pieza se potencia a sí misma.
- **Estadística que falta:** un aura sobre una estadística que la receptora no tiene no hace nada (el casco no da vida a una espada).
- **Solo en Tico:** solo hay auras entre las piezas de su rejilla.

### 4.2 Zonas
La rejilla está delante de Tico, que mira a la derecha. Una pieza en su zona (con alguna casilla limpia dentro) gana un **+10 %** en todas sus estadísticas.

| Zona | Casillas | Pieza |
|---|---|---|
| Cabeza | Fila de arriba | Casco |
| Pies | Fila de abajo | Botas |
| Brazo del escudo | Columna izquierda | Escudo |
| Brazo de la espada | Columna derecha | Espada |

### 4.3 Suma y tope
- Para cada pieza y cada estadística: `valor × (1 + min(0,5, zona + auras recibidas para esa estadística))`. Entre zona y auras, como mucho un +50 %.
- Las estadísticas de Tico son la suma de las piezas de su rejilla. Las enteras (daño, fuerza, agilidad, inteligencia, vida y armadura) se redondean al final.
- `InventoryManager.calculate_total_stats()` devuelve las mismas claves que hoy, así que `CombatMath.hero_stats()`, `Hero`, `RankTests` y `BalanceSim` no cambian de interfaz.
- Las fuerzas (5-20 %), la zona (10 %) y el tope (50 %) son valores de partida: los fija la calibración (apartado 6).

## 5. Habilidades legendarias

Cada pieza tiene su habilidad de combate cuando sale Legendaria. Las maestras son las más fuertes y tienen precio.

| Pieza | Habilidad | Efecto | Precio |
|---|---|---|---|
| Espada básica | Filo perfecto | Daño ×1,25 | — |
| Espada avanzada | Golpe doble | 25 % de golpear dos veces | — |
| Espada maestra | Filo ígneo | Cada golpe quema: el 40 % de su daño en 3 s, sin contar la armadura | Probabilidad de crítico ×0,5 |
| Escudo básico | Aguante | Vida máxima ×1,2 | — |
| Escudo avanzado | Parada | 15 % de parar un golpe entero | — |
| Escudo maestro | Espinas | Devuelve el 30 % del daño recibido | Velocidad de ataque ×0,85 |
| Casco básico | Ojo de halcón | Probabilidad de crítico ×1,5 | — |
| Casco avanzado | Regeneración | Recupera el 1,5 % de la vida máxima por segundo | — |
| Casco maestro | Segunda oportunidad | Una vez por duelo, al caer vuelve con el 40 % de la vida | Vida máxima ×0,85 |
| Botas básicas | Paso ligero | Velocidad de ataque ×1,15 | — |
| Botas avanzadas | Esquiva | 12 % de esquivar un golpe | — |
| Botas maestras | Ímpetu | El primer golpe contra cada enemigo hace ×3 | Armadura ×0,8 |

- **Cuándo cuenta:** si la pieza está en la rejilla de Tico, en cualquier casilla. La legendaria conserva también su aura del 20 %.
- **Multiplicativas:** se aplican a las estadísticas finales de Tico (después de `CombatMath.hero_stats()`), fuera del tope de auras. Siguen los topes de siempre: crítico 75 % y velocidad de ataque 5.
- **Sin repetir:** dos piezas con la misma habilidad cuentan como una. Habilidades distintas se multiplican entre sí.
- **Detalles:**
  - Golpe doble: el segundo golpe llega justo después del primero, con su propia tirada de crítico.
  - Filo ígneo: cada golpe pone una quemadura nueva de 3 s. No se acumulan: si ya había una, se queda la que hace más daño por segundo y el tiempo vuelve a 3 s. Ignora la armadura, como el pulso.
  - Esquiva y parada: el golpe no hace daño. Se tira primero la esquiva y después la parada.
  - Espinas: vuelve al atacante el 30 % del daño que Tico recibe de verdad, después de la armadura.
  - Regeneración: solo con Tico vivo; no resucita.
  - Segunda oportunidad: la primera vez en un duelo que la vida de Tico iba a llegar a 0, se queda con el 40 % y sigue. Se recarga al empezar el duelo siguiente: en el spec de rangos revisado, cada sala es un duelo con la vida llena.
  - Ímpetu: solo el primer golpe contra cada enemigo; con golpe doble, solo el primero de los dos. El pulso mágico no cuenta como golpe.
- **En la franja:** se ven con la fuente pixel ("¡DOBLE!", "¡PARADA!", "¡ESQUIVA!", "¡OTRA VEZ!") y con efectos de quemadura y de curación en `CombatFX`.
- **Magnitudes:** son de partida; las fija la calibración.

## 6. Balance

El spec de rangos se revisó el 2026-09-27 (apartados 6 y 7). Desde entonces, cada sala es un duelo con la vida llena y los objetivos se miden en duelos. La calibración se hará con el motor Balanza, y el tablero fija el orden: Balanza, rangos e inventario. Este apartado sigue esa revisión.

- **Poder por casilla.** Con "lo que quepa", el espacio es el techo de poder, así que las estadísticas de las piezas se miden por casilla limpia:
  - a igual nivel, las cuatro piezas dan el mismo poder por casilla (hoy el casco da unas tres veces más que las botas);
  - cada nivel da más por casilla que el anterior. Punto de partida: avanzado ×1,3 y maestro ×1,6 frente al básico;
  - el poder de una pieza se mide con una métrica continua: cuánto sube el daño esperado por la vida efectiva de Tico (con su armadura) al añadirla a una rejilla de referencia;
  - con eso se reescriben los rangos de estadísticas de los 12 `data/items/*.tres`.
- **Simulación con rejillas de verdad.** Es la de los rangos: `BalanceSim`, o el enlace de PetJam con Balanza si los rangos se calibraron con él.
  - Mide duelos, como los rangos: Tico entra en cada sala con la vida llena, y su muro es el primer enemigo al que no gana.
  - La rejilla tiene en cada sala el tamaño que tendría el jugador. En el ciclo I, crece una vez por cada jefe de las salas 10, 20, 30 y 40 ya vencido, contando con que su receta se forja en cuanto sale. Desde el ciclo II mide siempre 6×6.
  - `GearPacker` la llena con piezas del nivel, el rango y la calidad que se prueban, con las aristas que les tocan por su calidad.
  - Prueba varias mezclas de armas y armaduras y se queda con la que llega más lejos.
  - Aplica auras, zonas, tope y habilidades legendarias con las reglas reales. Las habilidades cuentan por su valor esperado en el duelo:
    - golpe doble, quemadura e ímpetu suben el daño;
    - esquiva y parada quitan golpes;
    - espinas devuelve daño;
    - regeneración cura;
    - segunda oportunidad da una segunda vida del 40 %.
  - Los objetivos son los del spec de rangos: hitos con calidad 0,85, cotas con calidad 1,00 y la escalera de 15 estados. Solo cambia "las 4 piezas equipadas" por "la rejilla llena".
- **Rango del equipo.** El spec de rangos hace que la base de Tico crezca con el rango de su equipo, y deja la regla en una sola función para que este spec la redefina.
  - Con la rejilla, es el menor rango entre las mejores piezas de cada tipo que lleva Tico (las que dibuja su sprite, apartado 9.4).
  - Añadir una pieza de un tipo que ya lleva nunca lo baja.
  - Una pieza de rango bajo de un tipo que no llevaba sí lo baja, como con 4 huecos.
  - Sin piezas, es el rango I.
- **Qué se recalibra:**
  - de los rangos: `Ranks.stat_mult`, la base de Tico por rango y, si hace falta, las constantes de `EnemyScaling`;
  - de este spec: las estadísticas de las piezas y las cifras de auras, zonas, tope y habilidades.
- **Materiales.** Un equipo pasa a ser de 8-10 piezas en vez de 4.
  - Una cuenta de materiales en la simulación comprueba que llenar la rejilla de un nivel cuesta más o menos las victorias que el spec de rangos preveía para 4 piezas.
  - Si no, sube la tanda de botín por enemigo.
  - El resto de la economía es de su tarjeta.
- **Recalibración.** La calibración de los rangos (con 4 piezas) se repite aquí con rejillas, con la misma herramienta y los mismos objetivos. Con Balanza:
  - el enlace de PetJam recibe el conjunto de las 4 piezas de un nivel y llena la rejilla con copias, porque en Balanza un conjunto no puede llevar dos piezas de la misma ranura;
  - el factor de cada pieza es su número de casillas limpias;
  - las 12 habilidades son efectos, con el precio medido con y sin ellas.
- **Riesgo propio del ciclo I.** Allí la rejilla crece con los jefes: 20 casillas contra el jefe 20, 30 contra el 40 y 36 al final. Desde el ciclo II siempre tiene 36, así que la ventaja de un nivel sobre otro no será la misma en el ciclo I que en los demás. Si la calibración no cumple con los dos, se consulta al usuario antes de tocar los objetivos.

## 7. Recetas de ampliación

| Receta | Se desbloquea al vencer por primera vez | Rejilla (si se forjan en este orden) | Materiales (de partida) | Minijuegos |
|---|---|---|---|---|
| Correas de hueso | Rey Osario (sala 10) | 4×4 → 5×4 | 10 de hueso y 20 de cuero | Coser |
| Bolsas de musgo | Madre del Musgo (sala 20) | 5×4 → 5×5 | 10 de musgo y 20 de tela | Coser |
| Hebillas de obsidiana | Señor del Magma (sala 30) | 5×5 → 6×5 | 10 de obsidiana y 20 de hierro | Forja y martillo |
| Arnés de escarcha | Coloso de Escarcha (sala 40) | 6×5 → 6×6 | 10 de escarcha y 20 de cuero | Coser y temple |

- **Qué son.** 4 planos que `scripts/core/GridExpansions.gd` (estático) construye en código, sin `.tres`, con su jefe, su nombre, sus materiales y sus minijuegos. Están fuera de `BlueprintLibrary`: no salen en los pedidos ni tienen rango.
- **En cualquier orden.** Cada receta forjada amplía la rejilla al tamaño siguiente de la tabla, sea cual sea la receta.
- **Solo en el ciclo I.** Volver a vencer a esos jefes en ciclos posteriores no da nada más.
- **Al desbloquear:**
  - la franja lo anuncia ("¡Nueva receta: Correas de hueso!"), con la cola de avisos de `HeroViewOverlay`;
  - la receta aparece en la biblioteca de planos, en un apartado propio, con el botón Forjar del encargo propio del spec de rangos;
  - en las salas 20 y 40 coincide con el aviso de planos nuevos; los dos salen uno detrás de otro.
- **Al forjar:**
  - se pagan los materiales al entrar en la cola; sin materiales o con la cola llena, avisa y no cobra, como el encargo propio;
  - no da oro y siempre sale bien, sea cual sea la calidad;
  - al terminar, la rejilla crece y la pantalla de resultado dice "¡La rejilla crece!" con el tamaño nuevo. No se crea ninguna pieza.
- **Estado.** Las recetas desbloqueadas se deducen del récord (`best_enemy_level` mayor que la sala del jefe), como los hitos de rangos. Las forjadas se guardan (apartado 10).
- **Materiales.** Los de bioma son los del spec de rangos (apartado 4). Las cantidades se ajustan con la cuenta de materiales.

## 8. Consumibles

- **Huecos:** 2, en `InventoryManager`. Cada uno guarda un tipo de poción y hasta 5 unidades (valor de partida).
- **Compra:**
  - la tienda deja de aplicar la poción al comprarla: la poción va al hueco de su tipo o a uno vacío;
  - si no cabe (los dos huecos tienen otros tipos, o el suyo está lleno), avisa "No hay hueco" y no cobra;
  - la de Vida ya se puede comprar con Tico caído o con la vida llena.
- **Se beben solas** (`GameManager`):
  - Vida: cuando Tico recibe daño, sigue vivo y queda por debajo del 30 % de su vida. Cura al máximo, como hoy.
  - Velocidad y Suerte: al aparecer un jefe (sala de jefe según `Biomes.is_boss_room`), si su efecto no está activo.
  - Los efectos no cambian (`GameManager.apply_buff`): Velocidad, ataques ×1,5 durante 30 s; Suerte, 20 % de botín doble durante 60 s.
  - Beber sola una poción cuenta como beberla para el muro del spec de rangos (apartado 7): Tico vuelve a probarlo.
- **Dónde se ven:** en el panel de Equipo (los 2 huecos con su número), en la franja (icono pequeño y número, junto al indicador de efectos) y en la tienda ("En hueco: 3").
- **Vaciar un hueco:** manteniéndolo pulsado en el panel se venden sus pociones a mitad de precio. Es la única forma de cambiar de tipo.
- **Guardado:** los huecos se guardan. Los efectos activos siguen sin guardarse, como hoy.

## 9. Interfaz

### 9.1 Panel de Equipo
Se rehace (`scenes/UI/EquipmentPanel.tscn` y `scripts/ui/EquipmentPanel.gd`) a pantalla completa. De arriba abajo:
1. **Título y Cerrar,** también con el botón Atrás de Android.
2. **Estadísticas de Tico:** Vida, Daño, Armadura (con su reducción en la sala actual), Crítico y Velocidad.
3. **Ficha breve** de la última pieza tocada:
   - nombre con el numeral de rango y calidad;
   - estadísticas con su aumento ("Daño 38 (+20 %)");
   - el aura que da y su zona;
   - si es legendaria, su habilidad y su precio.
4. **Rejilla de Tico,** delante de su sprite a gran tamaño y tenue (el mismo Tico compuesto de la fase 2 del pixel art).
   - Las zonas se marcan con un icono en su borde.
   - Las casillas que aún no existen se dibujan punteadas, con el nombre de su receta.
   - Los 2 huecos de consumibles van al lado.
5. **Botín:** una tira con desplazamiento lateral y el botón "Vender todo". Las piezas van a tamaño real y tumbadas: giradas para que ocupen la menor altura.
6. **Mochila** de 6×4.
7. **Zona de venta,** que enseña el precio al pasar una pieza por encima.

Medidas: casillas de 22×22 píxeles de arte a ×5 (110 px de pantalla), el mismo tamaño de píxel que la franja. La rejilla de 6×6 mide 660 px de lado y la mochila, 660×440. Todo cabe en 1080×1920.

### 9.2 Controles
- **Tocar** una pieza de una rejilla: gira 90° en su sitio y enseña su ficha breve. Si girada no cabe, tiembla y no gira. En el botín, tocar solo enseña la ficha.
- **Mantener pulsado** (0,4 s): ficha completa con los botones Mochila, Botín y Vender.
- **Arrastrar** (a partir de 10 px de movimiento): la pieza se levanta y se dibuja una casilla por encima del dedo, para que se vea el destino.
  - Las casillas de destino se marcan en verde si cabe o hay intercambio, y en rojo si no.
  - Las piezas que ganarían o perderían un aura se iluminan en verde o en rojo, y la barra de estadísticas enseña el cambio (`InventoryManager.preview_stats`).
  - Un segundo dedo gira la pieza sin soltarla.
- **Soltar:** las reglas del apartado 3.2.
- **En el ordenador** (pruebas y capturas): el ratón hace lo mismo, y la rueda o la tecla R giran.

### 9.3 Resto del juego
- **Botón Equipo:** su insignia cuenta las piezas del botín.
- **Pantalla de resultado de la forja** (`CraftResultScreen`):
  - enseña la forma de la pieza con sus aristas ("Sin aristas" desde Épico);
  - si es legendaria, el nombre y el efecto de su habilidad;
  - con una receta de ampliación, "¡La rejilla crece!".
- **Tienda** (`ShopPanel`): la pestaña de venta lista el botín y la mochila; lo que lleva Tico no se vende desde la tienda. Las pociones van a los huecos (apartado 8).
- **Biblioteca de planos:** el apartado de recetas de ampliación (apartado 7).
- **Franja** (`HeroViewOverlay`): los consumibles, el aviso de receta y los textos de las habilidades legendarias.
- **Tutorial:** como nada se coloca solo, la tarjeta del tutorial tiene que enseñar a colocar la primera pieza del botín.

### 9.4 Sprite de Tico
- `Hero.refresh_gear()` elige, entre las piezas de la rejilla de Tico, la mejor de cada tipo: primero por rango, después por nivel y después por calidad.
- Rellena `gear` como hoy, así que la fase 2 del pixel art no cambia.

### 9.5 Pixel art
En `tools/pixel_art/` hay un script nuevo, `gear.py`, con sus pruebas, que exporta a `art/sprites/pixel/gear/`:
- **Las 12 piezas,** con su forma limpia (22 px por casilla) y su aspecto real:
  - los píxeles de acento van en la rampa reservada de la fase 2 (`+ * #`, de `recolor.py`) y el juego los cambia por la rampa de la calidad. Sin la fase 2 integrada, `gear.py` usa esos mismos valores;
  - en Épicas y Legendarias, un destello recorre esos píxeles de acento, con la fuerza de `recolor.SHINE`.
- **Teselas de arista:** rebaba de metal (espada, escudo y casco) y de cuero (botas), con 3 variantes de cada. Se dibujan pegadas a un lado y el código las gira.
- **Interfaz:** casilla (marco y fondo), casilla por abrir, iconos de las 4 zonas, iconos de las 3 pociones y un marco de madera para 9 partes, que usan el hueco de consumible y la zona de venta.
- **Giros:** los hace el código; 90° es exacto en pixel art.
- **Textos del panel:** usan el tema actual hasta que el spec del tablero y la botonera decida la fuente de la interfaz.

## 10. Guardado y migración

- **Guardado versión 3** (la 2 es la del spec de rangos). En `inventory`:
  - cada pieza de `crafted_items` guarda, además de lo de hoy (`item_id`, `quality`, `stats`, `timestamp` y el `rank` de los rangos), `place`, `x`, `y`, `rot` y `aristas` (una lista de pares);
  - desaparecen `equipped` en las piezas y `equipped_slots`;
  - el orden de las piezas del botín es el de la lista;
  - `hero_grid`: [ancho, alto];
  - `expansions`: los ids de las recetas forjadas;
  - `consumables`: los 2 huecos (`id` y `count`).
- **Migración de la versión 2 a la 3,** encadenada tras la de la 1 a la 2:
  1. Se dan como forjadas las ampliaciones de los jefes que el récord ya supera, y la rejilla toma su tamaño.
  2. Cada pieza recibe sus aristas según su calidad, con los sitios sorteados con una semilla fija (su `timestamp` y su posición en la lista). La misma partida da siempre el mismo resultado.
  3. Las piezas que estaban equipadas se colocan en la rejilla con `GearPacker`: las mejores primero y, si se puede, en su zona. Las que no caben van al botín.
  4. El resto va al botín, con las mejores primero.
  5. Los huecos de consumibles empiezan vacíos.
- **En cualquier carga,** una pieza con una posición imposible (fuera de la rejilla o pisando otra) pasa al botín. Nunca se pierde una pieza.
- **Guardado robusto:** si para entonces está hecha su tarjeta, la migración se hace sobre ella.

## 11. Rendimiento

- **Controles de dibujo:** cada rejilla (Tico y mochila) es un solo control que se dibuja a sí mismo (`GearGridView`), y el botín es otro (`LootStripView`). No hay un nodo por casilla.
- **Caché de texturas:** la textura de cada pieza (forma, aristas, recoloreado y giro) se compone una vez y se guarda en caché, como la composición de Tico de la fase 2.
- **Recálculo:** las auras y las estadísticas se recalculan cuando cambia algo. Durante un arrastre, solo cuando cambia la casilla de destino o el giro, nunca en cada fotograma.
- **Empaquetador:** `GearPacker` solo se usa en la migración y en `BalanceSim`.
- **Objetivo:** abrir el panel en menos de 50 ms y arrastrar a 60 FPS en el móvil de pruebas.

## 12. Textos e idioma

- Todo texto nuevo va en español, que es el texto base, con su fila en `locale/textos.csv` (columnas `keys,es,en`, sin líneas en blanco), y `tr()` en los textos formateados. Tras editar el CSV: `D:/Software/Godot/godot_ver4.5.exe --headless --path . --import`.
- **Textos nuevos:**
  - "Botín", "Mochila", "Vender todo", "Suelta aquí para vender", "No hay hueco", "En hueco: %d" y "Sin aristas";
  - "¡La rejilla crece!" y "¡Nueva receta: %s!";
  - los nombres de las 4 recetas, las 4 auras y las 4 zonas;
  - los nombres, efectos y precios de las 12 habilidades.
- Los textos de la franja ("¡DOBLE!", "¡PARADA!", "¡ESQUIVA!", "¡OTRA VEZ!" y el aviso de receta) respetan los caracteres de `PixelFont`.

## 13. Pruebas

- **`InventoryGridTests`** (suite nueva sobre `TestSuite.gd`, `scenes/tests/InventoryGridTests.tscn`):
  - las formas de las 12 piezas y los giros;
  - aristas: cuántas por calidad, siempre en sitios válidos y las mismas con la misma semilla;
  - colocar, rechazar (fuera de la rejilla o encima de dos piezas), intercambiar (con vuelta al origen o al botín) y vender;
  - auras: vecindad por los lados y no en diagonal, una vez por vecina, aristas sin efecto y tope;
  - zonas, también después de ampliar la rejilla;
  - habilidades legendarias: multiplicadores, sin repetir, topes y los efectos de combate con semilla fija. Segunda oportunidad, una vez por duelo;
  - `calculate_total_stats()` igual a la suma hecha a mano en un caso de ejemplo;
  - rango del equipo: el menor entre las mejores piezas de cada tipo;
  - recetas: se desbloquean una sola vez al vencer al jefe, forjarlas amplía la rejilla sin crear pieza y no se repiten en el ciclo II;
  - consumibles: compra al hueco, "No hay hueco" sin cobrar, Vida por debajo del 30 %, y Velocidad y Suerte al aparecer un jefe;
  - guardar y cargar la versión 3;
  - migración con una partida de la versión 2 que genera la propia prueba (4 piezas equipadas, 40 sueltas y récord 35): ninguna pieza perdida, rejilla de 6×5 y aristas deterministas;
  - posiciones imposibles al cargar: la pieza pasa al botín.
- **Simulación de balance** (`BalanceSim`, y Balanza si los rangos la usan): duelos con rejillas llenas, los objetivos y la escalera del spec de rangos, el poder por casilla y la cuenta de materiales.
- **Siguen en verde:**
  - `GameplayTests`, con su prueba de equipar reescrita para la rejilla;
  - `RankTests`, `PixelTests` y `TextTests`;
  - las pruebas de Python de `tools/pixel_art`.
- **Capturas** (`VisualCapture`, plan nuevo `inventory`):
  - el panel con piezas en la rejilla de Tico, en la mochila y en el botín;
  - un arrastre en curso con intercambio y las casillas por abrir;
  - la ficha de una legendaria y sus textos en la franja.

## 14. Qué cambia en el código

- **Nuevos:**
  - Reglas sin nodos en `scripts/core/`:
    - `PieceShape.gd`: formas, giros y aristas;
    - `GearGrid.gd`: una rejilla (caber, colocar, quitar y vecinas);
    - `GearAuras.gd`: auras, zonas y tope;
    - `LegendaryPowers.gd`: habilidades;
    - `GearPacker.gd`: colocación automática para la migración y la simulación;
    - `GridExpansions.gd`: recetas de ampliación.
  - Interfaz en `scripts/ui/`: `GearGridView.gd` y `LootStripView.gd`. El arrastre vive dentro de `EquipmentPanel.gd`.
  - Arte: `tools/pixel_art/gear.py` y sus pruebas, que generan `art/sprites/pixel/gear/`.
  - Pruebas: `scripts/tests/InventoryGridTests.gd` y `scenes/tests/InventoryGridTests.tscn`.
- **Modificados:**
  - Datos: `ItemResource.gd` (`shape_cells` y `arista_spots`) y los 12 `data/items/*.tres` (formas, sitios de arista y estadísticas por casilla).
  - `CraftedItem.gd`: `place`, `cell`, `rot` y `aristas`; desaparece `is_equipped`.
  - Autoloads y núcleo:
    - `InventoryManager`: los tres sitios, consumibles, ampliaciones, rango del equipo, guardado y migración;
    - `CraftingManager`: aristas al forjar y recetas de ampliación;
    - `GameManager`: recetas desbloqueadas por jefes y consumibles automáticos;
    - `SaveManager`: versión 3;
    - `RequestsManager` no cambia: las recetas de ampliación no están en `BlueprintLibrary`, así que nunca salen en los pedidos;
    - `CombatMath`: aplica los multiplicadores legendarios después de `hero_stats()`.
  - Combate:
    - `Hero`: mejor pieza de cada tipo, regeneración, esquiva, parada, espinas, segunda oportunidad (una por duelo) y una señal de daño recibido;
    - `CombatController`: golpe doble, quemadura e ímpetu;
    - `CombatFX`: quemadura, curación y textos.
  - Interfaz: `EquipmentPanel` (rehecho), `HUDMain` (insignia), `CraftResultScreen`, `ShopPanel`, `BlueprintLibraryPanel` y `HeroViewOverlay`.
  - Pruebas y documentación: `BalanceSim`, `GameplayTests`, `VisualCapture`, `locale/textos.csv`, `doc/ARCHITECTURE.md` y `doc/ROADMAP.md`.
- **Sin tocar:** `DungeonHUD`, que no se usa y está en la tarjeta de limpieza, llama a la API vieja con `has_method` y no rompe.
- **Normas:** sin autoloads nuevos ni plugins; GDScript con tabuladores y comentarios en español.

## 15. Fases

Cada fase deja el juego funcionando.
1. **Reglas sin interfaz** y sus pruebas: `PieceShape`, `GearGrid`, `GearAuras`, `LegendaryPowers` (multiplicadores) y `GearPacker`.
2. **Datos,** `InventoryManager` con sus tres sitios, guardado versión 3 y migración. Mientras llega el panel nuevo, unas funciones de compatibilidad provisionales mantienen el panel viejo: equipar coloca con `GearPacker`.
3. **Panel nuevo y controles,** con dibujos provisionales (casillas de color). Se quitan las funciones de compatibilidad.
4. **Habilidades legendarias** en combate y sus efectos en la franja.
5. **Recetas de ampliación y consumibles.**
6. **Pixel art** de las piezas, las aristas y el panel.
7. **Balance:** estadísticas por casilla, duelos con rejillas en la simulación y calibración, con la misma herramienta que los rangos.
8. **Verificación:** capturas, prueba en un móvil y documentación.

## 16. Dependencias y riesgos

- **Orden: Balanza, rangos e inventario.** La calibración de los rangos está en pausa hasta que esté el motor Balanza (otra sesión), y los rangos no se terminan sin ella.
- **Rangos:**
  - La implementación empieza cuando la tarjeta "Implementar los rangos de plano por ciclo" esté en "Completada - Pendiente Revisión". Entonces esta rama se rebasa sobre `franja-pixel-fase-1` actualizada.
  - Usa de los rangos:
    - `CraftedItem.rank`, `Ranks.stat_mult` y los numerales;
    - los materiales de bioma, el encargo propio de la biblioteca y el guardado versión 2;
    - los duelos con la vida llena y el reintento del muro al cambiar de equipo o beber una poción;
    - la función del rango del equipo y la simulación de balance.
  - Si al rebasar algo de esto ha cambiado, se ajusta este spec antes de seguir.
- **Balanza:** si los rangos se calibran con ella, este spec también (apartado 6). Su orden `import` solo cambia las líneas de estadísticas de los `.tres`, así que conserva `shape_cells` y `arista_spots`.
- **Fase 2 del pixel art** (Tico por capas): no hace falta. Si no está hecha, el panel usa el Tico de hoy. Si lo está, este spec usa lo suyo:
  - su rampa de acento y sus rampas de calidad (apartado 9.5);
  - `Hero.read_equipped_gear()`, la única lectura del equipo para el dibujo (apartado 9.4);
  - `HeroPreview`, para el Tico grande y tenue del panel (apartado 9.1).
- **Riesgos:**
  - **Balance:** ahora tiene tres capas (poder por casilla, auras y habilidades). Se contiene con la simulación y con los topes. En el ciclo I, además, la rejilla crece con los jefes (apartado 6).
  - **Casillas de 110 px en móviles pequeños:** se comprueba en el dispositivo. Si no se acierta con el dedo, la mochila baja a 6×3 y las casillas crecen.
  - **Jugador nuevo que no coloca nada:** lo cubre la tarjeta del tutorial.
  - **Migración:** se prueba con la partida de ejemplo y con copia de `save.json` antes de cada prueba.

## 17. Fuera de alcance

- Pulir aristas, que crezca la mochila y cualquier colocación automática.
- Piezas nuevas (amuletos y otros) y tipos de daño.
- Auras al azar y piezas a la espalda en el sprite.
- La fuente de la interfaz, que decide el spec del tablero y la botonera.
- La tarjeta "Hueco Pecho sin objetos" queda resuelta: sin huecos fijos, no hay pecho.
