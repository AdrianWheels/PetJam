# Arte ilustrado de PetJam

Producción del 2 de octubre de 2026: **78 recursos originales**. Se conserva la referencia de las armas antiguas: tinta irregular, metal gris azulado, cuero marrón, rojo apagado y dorado reservado para las piezas maestras. Los personajes llevan borde de sticker. Las capturas de inventario aportadas sirven de referencia para siluetas grandes y reconocibles dentro de la rejilla.

| Familia | Recursos | Contenido |
|---|---:|---|
| Personajes | 15 hojas | 60 poses: cuatro Ticos, cinco enemigos, cinco jefes y Brasa |
| Equipo | 22 | 12 piezas activas y 10 armas futuras; 13 diseños de armas en total |
| Materiales y pociones | 17 | 14 materiales y 3 pociones |
| Fondos | 6 | Cinco biomas y el taller del piloto |
| Estaciones y herramientas | 8 | Cuatro estaciones y cuatro herramientas |
| Interfaz | 8 | Planos, equipo, tienda, entrega, mochila, moneda, yunque y chispa |
| Pantallas | 2 | Inicio integrado y derrota opcional preparada |

## Archivos y uso

- `sources/`: originales de producción, conservados a su resolución completa.
- `prompts/`: instrucciones de generación por recurso; el taller reutiliza el piloto.
- `generation_jobs.json`: trazabilidad de las 77 generaciones del lote.
- `gear/`: texturas técnicas para inventario, a 110 píxeles por celda. Sus dimensiones siguen los JSON y las formas de `data/items`; permiten las rotaciones existentes.
- `archive/`: versiones corregidas conservadas para comparación.
- `review/`: galería independiente de Godot, con transparencia sobre damero y navegación por categorías y páginas. Su `.gdignore` evita incluirla en el juego.

Las hojas de personajes usan una cuadrícula 2×2: reposo arriba izquierda, ataque arriba derecha, daño abajo izquierda y derrota abajo derecha. Brasa usa reposo, martillo, costura y celebración. `StickerSprites.gd` crea una tira de cuatro poses de 320 píxeles por pose y cambia de estado sin interpolar fotogramas. Se mantienen las colisiones, distancias y reglas del combate.

Las 12 piezas activas, materiales, pociones, fondos, estaciones, personajes e iconos están vinculados a los recursos y escenas existentes. Algunas herramientas están vinculadas a los botones táctiles que ya estaban ocultos. Las diez armas futuras tienen original y textura de rejilla, pero todavía carecen de objetos, estadísticas y recetas. La pantalla de derrota queda preparada: el flujo actual muestra la pose de derrota y reaparece automáticamente. Brasa cambia de pose con las señales de fabricación; el taller se oculta durante el minijuego.

Se conservan los textos localizables, tipografía, marcos y componentes procedurales de interfaz y efectos de combate y fabricación. Los recursos antiguos permanecen disponibles como respaldo.

## Herramientas

Desde la raíz del proyecto:

```powershell
python tools/art/inventory.py
godot --headless --log-file logs/art-build.log --path . --script res://tools/art/BuildTextures.gd
godot --headless --log-file logs/art-runtime.log --path . --script res://tools/art/tests/StickerRuntimeTests.gd -- --art-preview
godot --headless --log-file logs/art-combat.log --path . res://scenes/tests/PixelTests.tscn -- --art-preview
```

`integrate.py` reproduce los enlaces del lote. `save_generated.py` guarda las salidas registradas y sus prompts. La generación creativa se hizo con imagegen; Godot se utiliza para empaquetado, ajuste de tamaño y renderizado.

La galería se abre con `godot --path art/stickers/review`. Para las capturas del juego se usa `tools/art/CaptureGame.gd` y siempre `--art-preview`, que evita leer o escribir la partida guardada.

Inventario detallado: [inventario de producción](../../doc/arte/inventario-produccion.md). Resultado y comprobaciones: [resumen de producción](../../doc/arte/resumen-produccion-2026-10-02.md).
