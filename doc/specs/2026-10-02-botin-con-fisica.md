# Botín con física

**Fecha:** 2026-10-02 · **Estado:** propuesto, pendiente de revisión del usuario
**Petición:** que el contenedor sin límite del panel de Equipo (el botín, no la rejilla de Tico ni la mochila) sea físico, como el almacén de Backpack Battles: las piezas caen, chocan entre ellas y se quedan donde caen.

Decisiones del usuario (2026-10-02):

| Pregunta | Elegido |
|---|---|
| Qué pasa cuando se llena | Caja de tamaño fijo; la pila puede subir por encima del borde |
| Hasta dónde sube | Techo invisible; si una pieza no cabe, la pila se aprieta (solapada), nunca pasa del techo |
| Al cerrar y reabrir, o al reiniciar | La pila se queda igual (se guarda la pose de cada pieza) |
| Dentro de la caja | Coger, mover y lanzar, con la inercia del gesto |
| Dónde entra una pieza | Donde la sueltas; lo forjado y «Al botín» caen desde arriba |
| Giro | Libre, en cualquier ángulo |
| Tamaño de la caja | Más alta que la tira actual |
| Pieza que no cabe | Modo fantasma, semitransparente |

---

## 1. Objetivo y criterios de éxito

El botín deja de ser una tira ordenada y pasa a ser un montón físico: lo forjado cae dentro, rueda y se apila. Ordenar, vender y sacar piezas del montón es parte del juego.

Criterios:
- Las piezas caen, chocan con su forma real (por casillas, aristas incluidas) y se quedan quietas en unos segundos.
- La pila nunca pasa del techo, por muchas piezas que haya.
- Al cerrar y reabrir el panel, o al reiniciar, cada pieza está donde estaba.
- Sacar una pieza a la rejilla, a la mochila o a la venta funciona como hoy.
- No se pierde nunca una pieza: la lista del botín de `InventoryManager` sigue siendo la fuente de verdad.

## 2. La caja en el panel

El panel mide 1080×1920. Cambia la parte de abajo:

| Zona | Antes | Ahora |
|---|---|---|
| Título del botín y «Vender todo» | y ≈ 926 | igual |
| Botín | tira de 960×330 (y 970–1300), con desplazamiento lateral | caja de 960×440 (x 60–1020, y 970–1410), 4 casillas de alto, sin desplazamiento |
| Título de la mochila (con su icono) | y ≈ 1300–1346 | y ≈ 1410–1456 |
| Mochila 6×4 y zona de venta | y 1350–1790 | y 1460–1900 |

- **Techo invisible:** 1,5 casillas (165 px) por encima del borde superior de la caja, en y ≈ 805. Con la pila a rebosar, tapa como mucho la última fila y media de la rejilla de Tico.
- La caja se dibuja con el fondo de la tira de hoy; el techo no se dibuja.

## 3. Física

- **Motor:** la física 2D de Godot. La caja es un `Node2D` dentro del panel con suelo, paredes y techo estáticos.
- **Una pieza = un `RigidBody2D`.**
  - Una forma rectangular por casilla de su silueta, aristas incluidas, según `PieceShape`.
  - La masa, proporcional al número de casillas.
  - Fricción, rebote y amortiguado se ajustan para que las pilas no tiemblen y se duerman pronto.
- **Giro libre:** las piezas ruedan y quedan torcidas.
- **Dibujo:** la pieza se pinta con `GearGridView.draw_piece_at` (textura de `GearArt` o casillas de color, borde de calidad y aristas), girada con su cuerpo.

## 4. Entrar en la caja

- **Soltada por el jugador** (desde la rejilla, la mochila o la propia caja): aparece en el punto donde se suelta. Lleva la velocidad del gesto, con un tope para que no salga disparada.
- **Forjada, o mandada con «Al botín» desde la ficha:** cae desde arriba de la caja, en una x al azar y con un pequeño giro inicial.
- **Lo que entra con el panel cerrado** (lo forjado) cae al abrir el panel, una pieza tras otra.

## 5. Pila llena: modo fantasma

- Una pieza que entra y no cabe por debajo del techo pasa a **modo fantasma**:
  - choca con el suelo, las paredes y el techo, pero no con las demás piezas;
  - se queda solapada dentro de la pila;
  - se dibuja semitransparente.
- Cuando hay sitio para ella (sin solapes), porque se vende o se saca otra pieza, vuelve a chocar con normalidad y se recoloca sola.
- Así la pila nunca pasa del techo.
- "No cabe" se decide de forma comprobable: la pieza, ya quieta, sigue solapando a otra o tendría que quedar por encima del techo.

## 6. Coger, mover y lanzar

- **Pulsar y arrastrar** una pieza de la caja:
  - la saca de la física y la lleva el dedo;
  - la endereza al giro de 90° más cercano, para que la vista previa de la rejilla y de la mochila cuadre.
  - La vista previa del arrastre (stats, colocación y precio en la zona de venta) es la de hoy.
- **Soltar:**
  - en la rejilla de Tico, en la mochila o en la venta: como hoy;
  - en la caja: vuelve a la física desde ese punto, con la inercia del gesto, y empuja a las demás.
  - Si se suelta fuera de todo: una pieza que venía de la rejilla o de la mochila se comporta como hoy; una que venía de la caja vuelve a ella, soltada en el punto de la caja más cercano al dedo.
  - Una pieza que un intercambio saca de la rejilla o de la mochila y manda al botín cae desde arriba, como lo forjado.
- **Tocar sin arrastrar** abre la ficha, como hoy. La pulsación larga y el giro se comportan igual que en la tira.
- **Desaparecen** el desplazamiento lateral de la tira y el orden «lo más nuevo a la izquierda».

## 7. Panel cerrado

- La física de la caja se congela al cerrar el panel: los cuerpos no se simulan.
- Al abrir, cada pieza aparece con su pose guardada, ya quieta. Después caen las que no tienen pose (apartado 4).

## 8. Datos y guardado

- **`CraftedItem.loot_pose`:** posición en la caja (coordenadas locales de la caja) y ángulo. Vacío = sin pose.
- **`to_dict`** escribe `lx`, `ly` y `ang` solo si la pieza está en el botín y tiene pose. **`from_dict`** los lee si están.
- **Sin versión nueva de guardado:** los campos son opcionales. Una partida sin ellos carga igual y sus piezas caen al abrir el panel.
- **Cuándo se guarda la pose:** al cerrar el panel, y cuando la pila se queda quieta tras un cambio (como mucho una vez por segundo), con el guardado diferido que ya existe.
- **`InventoryManager.loot`** sigue siendo la lista del botín. «Vender todo», la venta, la ficha y la migración no cambian; el orden de la lista pasa a ser solo el de llegada.
- **Una pose imposible** (fuera de la caja, por encima del techo o con valores no numéricos) se descarta y la pieza cae desde arriba. Nunca se pierde una pieza.

## 9. Código

| Fichero | Cambio |
|---|---|
| `scripts/ui/LootBoxView.gd` (nuevo) | Sustituye a `LootStripView`. Tiene la caja, el suelo, las paredes y el techo; crea y quita cuerpos según el botín; congela y descongela; dice qué pieza hay bajo un punto; recoge las poses. |
| `scripts/ui/LootPiece.gd` (nuevo) | El `RigidBody2D` de una pieza: formas por casilla, dibujo, modo fantasma y vuelta a la normalidad. |
| `scripts/core/PieceShape.gd` | Función pura nueva: los rectángulos de colisión de una pieza en un giro, centrados en su centro de masa. |
| `scripts/data/CraftedItem.gd` | `loot_pose`, en `to_dict` y `from_dict`. |
| `scripts/ui/EquipmentPanel.gd` y `scenes/UI/EquipmentPanel.tscn` | Fuera el desplazamiento; arrastre desde la caja con el cuerpo; lanzamiento al soltar en la caja; posiciones nuevas de la caja, el título de la mochila, la mochila y la zona de venta. |
| `scripts/ui/LootStripView.gd` | Se borra cuando nada lo use. |
| `scripts/tests/VisualCapture.gd` | Plan de captura `lootbox`. |
| `doc/ARCHITECTURE.md` | Apartado 4.3: el botín con física. |

Sin autoloads nuevos ni plugins. GDScript con tabuladores y comentarios en español.

## 10. Pruebas

**`LootBoxTests`** (suite nueva sobre `TestSuite.gd`, sin ventana, con la física real):
- Varias piezas soltadas acaban quietas dentro de la caja, por debajo del techo, antes de un tiempo límite.
- Con la caja llena, una pieza nueva entra en modo fantasma; al vender otra, vuelve a chocar y se recoloca.
- Ninguna pieza queda por encima del techo con 60 piezas en la caja.
- La pose se guarda y se carga igual; una pieza sin pose cae al abrir; una pose imposible se descarta.
- El lanzamiento respeta el tope de velocidad; coger una pieza la endereza al giro de 90° más cercano.
- Con el panel cerrado, los cuerpos no se mueven.
- `PieceShape`: los rectángulos de colisión cubren exactamente las casillas de la pieza en cada giro.
- Rendimiento: 60 piezas se quedan quietas, y abrir el panel cabe en un presupuesto de tiempo fijado en la prueba.

**Siguen en verde:** `InventoryGridTests` (adaptando las pruebas de la tira y del desplazamiento), `RankTests`, `GameplayTests`, `PixelTests` y `TextTests`.

**Capturas (`VisualCapture`, plan `lootbox`):** caída de varias piezas forjadas; pila llena con una pieza en modo fantasma; arrastre de una pieza a la rejilla; a 540×960 y a 810×1440.

## 11. Riesgos

- **Pilas que tiemblan:** se ajustan fricción, amortiguado y umbral de reposo; la prueba de «quietas a tiempo» lo vigila.
- **Muchas piezas:** cientos de piezas en el botín son cientos de cuerpos. Dormidos cuestan poco y los fantasmas no chocan entre sí. La prueba en un móvil real (tarjeta aparte) lo confirmará.
- **Física dentro de una interfaz:** la caja vive dentro de un `Control`. Las coordenadas de entrada (el dedo, en coordenadas del panel) se pasan a las de la caja en un solo sitio.

## 12. Fuera de alcance

- Sacudir la caja, ordenar automáticamente o filtrar el botín.
- Sonidos de choque (tarjeta de audio).
- Física en la rejilla de Tico o en la mochila.
- Límite de piezas en el botín.
