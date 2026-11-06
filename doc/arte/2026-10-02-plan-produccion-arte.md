# Plan de producción de arte de PetJam

Fecha: 2 de octubre de 2026. Este documento conserva el plan inicial. **Producción ejecutada:** véase el [resumen con capturas y comprobaciones](resumen-produccion-2026-10-02.md). La petición posterior de usar pocas poses sticker sustituye las estimaciones de animación completa del plan; el inventario definitivo contiene 78 recursos.

## 1. Objetivo y referencia

Crear una identidad visual coherente para todo el juego, usando el arte de las armas antiguas como referencia. El usuario ha confirmado que quiere conservar ese estilo y extenderlo al resto. El plan cubre equipo, formas de inventario, personajes, escenarios, fabricación, interfaz y efectos.

La revisión se ha hecho sobre imágenes y código del repositorio, no sobre una partida ejecutada. La hoja `auditoria-visual-2026-10-02.jpg` reúne ejemplos existentes; sus miniaturas sirven para comparar estilos, no para evaluar tamaños reales de juego.

Referencia inicial: las espadas de `art/assets/Imagenes/Items/`, especialmente `sword_basic.png` y `sword_masterwork.png`: contorno oscuro dibujado, superficies con marcas, colores desaturados, metal gris azulado y acentos cálidos. Antes de producir, fijar una lámina con las tres armas antiguas a tamaño real; hay otra familia de espadas en `art/gear/`, más lisa y estrecha, que no debe convertirse automáticamente en el modelo del resto.

Conservar el estilo confirmado no obliga a conservar todos los detalles diminutos: simplificar los que desaparezcan al reducir. Las piezas nuevas de metal pulido, la mochila y la poción pueden aportar formas, pero habrá que adaptar su acabado a la referencia.

## 2. Qué existe y qué falta

| Bloque | Evidencia actual | Trabajo previsto |
|---|---|---|
| Equipo activo | 12 recursos en `data/items/`: 3 espadas, 3 escudos, 3 cascos y 3 botas | Revisar y unificar originales, iconos, piezas de rejilla y representación equipada |
| Equipo futuro | 10 ilustraciones y 10 JSON en `tools/gear_art/futuras/`; sin recursos de objeto ni estadísticas | Explorar siluetas y preparar arte; integrar únicamente las armas que entren en el diseño |
| Materiales | 14 recursos: madera, hierro, cuero, tela, agua, hierba, fuego, hielo, veneno, hueso, musgo, obsidiana, escarcha y fragmento de vacío | Una familia de iconos consistente para materiales, pedidos, tienda y botín |
| Consumibles | Vida, Velocidad y Suerte en `Potions.CATALOG`; solo Vida declara icono propio | Diseñar 3 frascos reconocibles por forma, símbolo y contenido |
| Personajes | Tico con 3 tiras pixel; Brasa tiene fuente en `tools/pixel_art/`; 5 enemigos y 5 jefes pixel | Diseñar personajes en el lenguaje elegido, poses y equipo visible |
| Escenario | 5 biomas en `Biomes.gd`, con fondo por capas y decoración | Kit compartido de arquitectura más identidad propia por bioma |
| Fabricación | 4 minijuegos con imágenes de calor, martillo, cuero y barra de temple | Fondos, herramientas, objetos en proceso y respuesta visual consistente |
| Interfaz | Inicio, HUD, pedidos, cola, biblioteca, equipo, mochila, caja de botín, tienda, resultados y avisos | Kit de componentes, símbolos, tipografía y estados comunes |
| Efectos | Golpes, críticos, bloqueo, fuego, entrega, reaparición, muerte, botín y desbloqueos | Definir un vocabulario de efectos que deje leer el combate y las formas |

Los archivos de placeholders, animaciones antiguas y recursos sueltos no equivalen a contenido activo. La primera tarea de producción será inventariar referencias efectivas desde escenas, scripts y recursos, con uso, fuente y estado de cada asset. El README describe un alcance jam anterior; el catálogo y los scripts actuales tienen prioridad para medir la producción.

## 3. Dirección de arte

Tres vías posibles:

1. **Ilustración coherente derivada de las armas antiguas — recomendada.** Equipo, personajes y escenarios comparten trazo, materiales y paleta. Preserva directamente la referencia confirmada; exige adaptar la franja de combate.
2. **Equipo ilustrado y combate pixel art.** Mantiene parte del trabajo actual. Necesita reglas explícitas entre ambas vistas y versiones pixel de cada arma; sigue habiendo dos lenguajes de producción.
3. **Todo pixel art.** Facilita continuidad con la franja actual, pero interpreta de nuevo las armas y se aleja más de conservar su acabado.

La propuesta de este documento sigue la vía 1. La confirmación del usuario fija la referencia de armas; la conversión completa de personajes y franja sigue siendo una recomendación para revisar con una muestra visual. Los specs anteriores que proponían toda la pantalla pixel no se han modificado.

La guía de estilo deberá fijar:

- Trazo oscuro con grosor legible al tamaño final; detalle interior menor que el contorno.
- Luz y perspectiva comunes; objetos de inventario casi planos y personajes de perfil.
- Materiales con identidad: madera fibrosa, cuero mate, acero frío, tela suave; ornamentación al servicio de la progresión.
- Paleta base tomada de los originales y acentos limitados para magia, calidad y biomas.
- Fondos menos contrastados que personajes, armas, zonas de interacción y avisos.
- Borde blanco de pegatina como tratamiento de presentación de inventario, si funciona en la muestra; no incorporarlo al original ni a las armas equipadas.
- Silueta y símbolo además del color para distinguir calidad, materiales y consumibles.

## 4. Equipo activo y sus formas

Estas formas vienen de `shape_cells`; el arte debe respetarlas. Cambiar una forma afecta al inventario, auras y colisiones, y requiere una decisión de diseño independiente.

| Familia | Básico | Avanzado | Maestro | Problema artístico que resolver |
|---|---|---|---|---|
| Espada | 1×2, 2 casillas | 1×3, 3 | 1×4, 4 | Conservar diferencias de hoja, guarda y mango al pasar de dibujo diagonal a pieza vertical |
| Escudo | 1×2, 2 | 2×2, 4 | 2×3, 6 | El básico necesita proporción alta; el avanzado admite escudo redondo; el maestro necesita volumen vertical |
| Casco | 1×1, 1 | 2×1, 2 | T, caja 3×2, 4 | Perfil ancho para avanzado; cresta central y protecciones laterales para maestro |
| Botas | 1×1, 1 | L, caja 2×2, 3 | L, caja 2×3, 4 | Diseñar una bota lateral cuya caña y puntera expliquen las casillas |

Crear una ficha por pieza con: referencia antigua, silueta negra, plantilla de casillas, dibujo limpio, icono reducido y prueba equipada. Mantener separados nivel de pieza, calidad de fabricación y rango de plano: no producir automáticamente un dibujo nuevo por cada combinación.

Las cinco calidades se resolverán primero mediante marco, emblema y efectos/acento controlados. Las aristas por mala fabricación necesitan un pequeño kit de rebabas y roturas que corresponda a las casillas adicionales; actualmente aparecen grises sobre la pieza. No convertirlas en adornos que parezcan casillas libres.

## 5. Exploración de las 10 armas futuras

Las formas siguientes ya están propuestas en los JSON. Son hipótesis de diseño, no contenido jugable aprobado. Las ideas de animación describen presentación; no presuponen daño, alcance, balance ni nuevas mecánicas.

| Arma | Forma / casillas | Exploración de silueta | Representación equipada a explorar |
|---|---|---|---|
| Maza | 1×2 / 2 | Cabeza pesada arriba, empuñadura clara abajo | Carga corta y golpe pesado |
| Espada con vaina | 1×3 / 3 | Separar visualmente hoja, vaina y correas; estudiar orientación vertical | Elegir si se muestra envainada o desenvainada; no atacar con el icono de la vaina |
| Lanza | 1×3 / 3 | Punta identificable, asta continua; diferenciarla de la espada | Estocada de perfil y ancla de mano |
| Ballesta | 2×1 / 2 | Arco horizontal, cuerpo y cuerda; lectura en icono pequeño | Pose de disparo, proyectil y eventual recarga visual |
| Pico | L 2×2 / 3 | Mango en columna izquierda, cabeza en fila inferior, como la propuesta actual | Golpe angular; comprobar que no se confunda con herramienta de forja |
| Martillo | T 3×2 / 4 | Cabeza transversal y mango central; unión visible | Anticipación de peso y golpe descendente |
| Guantelete | 2×2 / 4 | Puño, dedos y placa de muñeca; evitar masa metálica indistinta | Mano equipada y pose de puñetazo; no sostenerlo como una espada |
| Guadaña doble | C 2×3 / 5 | Asta a la izquierda y hojas arriba/abajo; hueco lateral central libre | Barrido lateral; comprobar márgenes de la franja |
| Cruz de hojas | + 3×3 / 5 | Núcleo y cuatro brazos; esquinas transparentes | Definir primero si se empuña, lanza o tiene uso mágico |
| Aro de hojas | Anillo 3×3 / 8 | Hueco central transparente y hojas que expliquen las ocho casillas | Definir primero si se sostiene, lanza o gira |

Para cada una: dos bocetos de silueta sobre la misma plantilla, elección de uno, adaptación al estilo antiguo y hoja en cuatro giros. No estirar ni cortar el diseño para forzar una máscara. Si no puede explicar su forma, rediseñar el dibujo antes de plantear cambiar las casillas.

El aro merece una revisión específica: un agujero redondo puede dejar transparente parte de las ocho casillas ocupadas o invadir visualmente el centro libre. Mostrar la huella de casillas en hover/arrastre y comprobar el centro con otra pieza colocada dentro. La transparencia del PNG no define las colisiones: las define la huella.

Orden sugerido: maza y lanza para validar armas verticales; martillo y pico para T/L; guadaña y aro para huecos; ballesta y guantelete para nuevas poses; cruz y espada con vaina después de resolver su presentación equipada.

## 6. Resto del arte

**Personajes.** Empezar con Tico, un esqueleto y Brasa. Conservar identidad y proporciones reconocibles, pero adaptar acabado a las armas. Para Tico: reposo, caminar, anticipación, golpe, daño, muerte y reaparición; separar cuerpo, arma y equipo cuando sea útil. Un atlas de personaje completo por cada combinación de 12 piezas multiplicaría la producción innecesariamente. Compartir poses por familia de ataque y anclas de manos, cabeza y pies. Después producir Limo, Murciélago, Gólem y Espectro; cerrar con los cinco jefes.

**Entornos.** Producir primero Catacumbas como kit: lejos, muro, columnas, suelo y primer plano; puerta normal y puerta de jefe; antorcha y decoración. Derivar Cripta Musgosa, Caverna de Magma, Glaciar Olvidado y Santuario del Vacío mediante paleta y elementos propios. Un recolor solo no basta: enredaderas, lava, cristales y runas deben cambiar su identidad. Revisar continuidad del parallax y separación visual de enemigo, suelo y botín.

**Fabricación.** Crear cuatro estaciones reconocibles: horno, yunque, mesa de costura y recipiente de temple. Compartir banco, herramientas y materiales donde tenga sentido. Separar pieza fría/caliente, herramienta móvil y fondo. El arma en proceso debe parecer el mismo objeto que se recibe. Las ventanas de timing, anillos y puntos interactivos necesitan más contraste que el decorado.

**Interfaz.** Kit común de panel, botón, pestaña, ficha, tooltip, marco de calidad y barra; estados normal, hover, pulsado, seleccionado, bloqueado y deshabilitado cuando corresponda. Aplicarlo a pedidos, cola, biblioteca, equipo, mochila, botín, tienda y resultado. Iconos propios para navegación y acciones hoy representadas con símbolos o emojis. Mantener el texto como texto para localización; no generar rótulos dentro de las ilustraciones.

**Materiales y pociones.** Catorce iconos de material, tres pociones y mochila. Hielo y escarcha, hueso y vacío, agua y pociones deben distinguirse a tamaño pequeño. Vida/Velocidad/Suerte compartirán familia de frascos, con cuello, silueta y símbolo diferentes.

**Efectos.** Lista por evento: tajo, impacto, crítico, bloqueo, quemadura, aura, entrega, curación, aparición, muerte, desbloqueo y recogida. Diseñar primero los necesarios para la muestra. Compartir efectos mediante tintes donde siga habiendo lectura; evitar que brillo o humo tapen las celdas libres y los indicadores de timing.

## 7. Cómo llevar el arte al juego

Cada objeto necesita entregables diferentes derivados de un mismo diseño:

1. **Original limpio:** alta resolución, fondo transparente, sin rejilla ni marco ni sombra de interfaz; fuente editable y referencia asociada.
2. **Pieza de inventario:** giro 0, tamaño de caja según huella, a 110 px por casilla en el sistema actual. Salida `art/gear/<item_id>.png`; configuración en `tools/gear_art/pieces/<item_id>.json`. Los otros giros los calcula `GearArt.texture_for()`.
3. **Icono compacto:** composición preparada para ficha, tienda y biblioteca. No encoger sin más una lanza de cuatro casillas hasta volver invisible su hoja.
4. **Plano:** versión de esquema del mismo objeto para `BlueprintResource.blueprint_icon`; separada del icono del producto.
5. **Equipo visible:** arma adaptada a poses y anclas del héroe, sin borde de pegatina.
6. **Estados y efectos:** acentos de calidad, pieza caliente, aristas y efectos pertinentes, reutilizando capas cuando sea posible.

Puntos de integración actuales:

- `ItemResource.icon` y `BlueprintResource.icon` siguen usando recursos antiguos en varias fichas; sustituir solo `art/gear/` no unifica todas las pantallas.
- `GearGridView`, `LootBoxView` y `LootPiece` comparten `GearArt`; validar también el botín a 55 px por casilla, caída, giro físico y arrastre.
- Tico elige hoy entre tres tiras según la rareza del arma (`Hero._hero_sprite_key()`), sin identificar una familia nueva. Preparar poses no hace que una ballesta o un guantelete aparezcan equipados: habrá que ampliar esa selección y su presentación.
- La franja actual depende de sprites, métricas, fuente y shader pixel. Para ilustración, adaptar conjuntamente resolución de render, filtros, métricas, anclas, cámara, efectos y HUD; cargar una imagen grande en el viewport pixel perdería su detalle.
- Los minijuegos usan recursos distintos por estación. Conservar sus señales de interacción y tiempos al sustituir el arte.

Para incorporar una arma futura, además de PNG y JSON hacen falta el recurso de objeto, huella y aristas, receta, materiales, secuencia de pruebas, adquisición/desbloqueo, slot, selección visual y validación del combate. Ese trabajo se presupuestará aparte de producir su ilustración. Cruz y aro requieren resolver su uso antes.

La herramienta existente busca originales en varias carpetas, incluida una ruta de worktree antigua. Los originales `arma_basica/avanzada/maestra` mencionados por los JSON no están en las carpetas locales de fuentes revisadas. Antes de regenerar las piezas, localizar y conservar las fuentes exactas o fijar explícitamente las nuevas fuentes de referencia; no asumir que los PNG finales permiten reproducir el proceso.

## 8. Fases y entregables

| Fase | Entregable concreto | Criterio para avanzar |
|---|---|---|
| 0. Auditoría | Registro de assets activos con ID, uso, fuente, estado y variantes; lámina de referencia antigua | Fuentes identificadas y contenido activo separado de archivo histórico |
| 1. Dirección | Guía breve de trazo, paleta, materiales, escalas y presentación; comparación de estilos | Referencia inequívoca y muestra que conserva el carácter de las armas |
| 2. Muestra completa | Espada básica, martillo de prueba, Tico, esqueleto, Catacumbas, ficha/plano y estación de martillo | Se ve coherente en pantalla real, mochila, botín y fabricación |
| 3. Equipo activo | Las 12 piezas con original, inventario, icono y plano; kit de aristas y calidad | Sin cambios involuntarios de huella; mismo objeto reconocible en todas las vistas |
| 4. Contenido auxiliar | 14 materiales, 3 pociones, mochila y kit común de interfaz | Iconos legibles y sin familias gráficas mezcladas |
| 5. Mundo y personajes | Elenco completo, cinco biomas y cinco jefes; poses y efectos | Combate, fondos y equipo visible comparten lenguaje y escala |
| 6. Taller y pantallas | Cuatro minijuegos, inicio, resultados y avisos finales | Una sesión completa mantiene la dirección aprobada |
| 7. Expansión | Armas futuras seleccionadas, por lotes, con su paquete de arte e integración | Cada arma completa su recorrido desde receta hasta equipo visible |
| 8. Cierre | Capturas de revisión, fuentes archivadas, referencias actualizadas y limpieza de recursos sin uso | No quedan placeholders visibles dentro del alcance acordado |

Las fases 3–6 pueden agruparse por dependencias después de la muestra; no conviene esperar a terminar todo para integrar. Cada lote debe llegar al juego y revisarse antes del siguiente.

No fijar fechas por cantidad de PNG: originales, variantes y frames tienen costes diferentes. Medir el tiempo real de la muestra, incluyendo corrección e integración, y usarlo para estimar cada categoría. Separar presupuesto de concepto, producción, animación e integración; reservar una ronda de corrección por lote. Las diez armas futuras constituyen un alcance opcional y no deben retrasar la coherencia del contenido ya activo.

## 9. Revisión y aceptación

Cada entrega pasará estos controles:

- Comparación con la referencia de las armas antiguas y con la pieza básica del lote.
- Silueta legible sobre fondo claro y oscuro, a tamaño final; sin depender exclusivamente del color.
- Cuatro giros correctos; tamaño `ancho × 110` por `alto × 110` para inventario; margen para contorno y sombra.
- Huecos libres transparentes y ocupación entendible. Ninguna punta, hoja o empuñadura cortada por una máscara.
- Calidad y aristas legibles en pieza, ficha, arrastre y botín físico.
- Anclas, pies y dirección de mirada estables; el arma aparece en el punto de impacto visual previsto.
- Revisión en ventana actual de 540×960 y en viewport de 1080×1920; revisar también otros anchos objetivo y textos en español/inglés.
- Sin rutas dependientes de un worktree desaparecido; fuente editable y derivaciones reproducibles.
- Capturas mediante `scenes/tests/VisualCapture.tscn`, aprovechando los planes `inventory`, `lootbox`, `craft`, `shop`, `potions`, `boss`, `death` y `ranks` cuando se integre el lote.
- Al cambiar formas o selección visual, ejecutar los controles pertinentes de inventario y gameplay; no basta una hoja bonita fuera del juego.

Primer lote recomendado: fijar las tres espadas antiguas como lámina de referencia y diseñar una muestra con espada básica + martillo en T + Tico + esqueleto + Catacumbas. Resuelve a la vez estilo, escala, forma irregular y equipo visible antes de producir en masa.
