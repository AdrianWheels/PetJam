# Prompts para el arte de las piezas del inventario en rejilla

Tarjeta "Arte del inventario en rejilla"; spec `doc/specs/2026-09-27-inventario-en-rejilla.md`, apartado 9.5.

Las piezas se montan con `tools/gear_art/build_gear_art.py`: recorta la imagen, la gira, la encaja en su forma (110 px por casilla), la recorta a sus casillas y le pone el borde blanco de pegatina. Las 3 espadas salen de las armas de la franja (`arma_basica`, `arma_avanzada` y `arma_maestra`).

Para la armadura hay dos fuentes:
- **Los iconos actuales** (`art/assets/Imagenes/Items/`): sirven para las formas rectangulares, pero tienen otro estilo (más de dibujo animado, azul y rosa) que las espadas.
- **Imágenes nuevas** con estos prompts, en la misma conversación de ChatGPT de las pegatinas (`doc/arte/prompts-chatgpt.md` de la rama `franja-pegatinas`), para que vayan con el estilo de las espadas. Son las piezas cuya forma pide un dibujo concreto: una L, una T o un escudo alto y estrecho.

Los originales se guardan en `art/assets/Stickers/originales/` (repositorio de assets) con el nombre de cada prompt.

## Método que funciona: la plantilla de la forma

Probado con el casco maestro (2026-10-02): un prompt solo con texto da un dibujo bonito pero con otras proporciones. Lo que funciona es adjuntar la plantilla de la pieza (`doc/arte/plantillas/<item_id>.png`, la forma en gris con sus casillas) y pedir que la rellene entera, con pelo, plumas o adornos en las casillas raras, sobre fondo blanco liso. La imagen va a `tools/gear_art/sources/` y su `prepare()` quita el blanco que toca el borde (mira `pieces/helmet_master.py`).

```
Te adjunto una plantilla: la zona gris es la forma exacta que tiene que ocupar el dibujo. Dibuja <la pieza> en el mismo estilo de ilustración, rellenando TODA la zona gris y nada fuera de ella. <Qué llena cada casilla rara: penacho, alas, hombreras, puntera…>. Que cada casilla gris tenga dibujo hasta cerca de sus bordes. Las zonas blancas de la plantilla quedan vacías. Misma proporción que la plantilla. Fondo blanco liso, sin brillo, sin resplandor y sin sombra. No dibujes la plantilla, ni la rejilla ni el contorno negro.
```

## Las que no encajan con los iconos actuales

### Escudo básico (1×2, alto y estrecho) · `escudo_basico.png`

El icono es redondo: en una caja de 1×2 queda una moneda pequeña con media caja vacía.

```
Un escudo de madera sencillo para el explorador de las imágenes anteriores: alto y estrecho, rectangular con las esquinas redondeadas, de tablas verticales de madera clara unidas por dos bandas de hierro y un umbo de hierro pequeño en el centro, algo gastado. Solo, sin personaje ni manos, visto de frente y totalmente plano. Mismo estilo de ilustración que las espadas: contorno fino oscuro y color con sombreado suave. Sin gemas ni adornos de colores. Fondo transparente, sin borde de pegatina, sin sombra. Formato vertical, con el escudo el doble de alto que de ancho, ocupando casi todo el alto y margen alrededor.
```

### Casco maestro (T: una casilla arriba en el centro y tres abajo) · `casco_maestro.png`

La forma pide un casco ancho con una cresta alta en el centro.

```
Un yelmo de caballero de acero pulido para el explorador de las imágenes anteriores, con una cresta alta y estrecha de crin oscura que sale del centro de la cabeza hacia arriba, y protecciones anchas para las mejillas y la nuca que lo hacen más ancho por abajo. Solo, sin personaje, visto de frente y totalmente plano. Mismo estilo de ilustración que las espadas: contorno fino oscuro y color con sombreado suave. Ribetes dorados finos, sin gemas. Fondo transparente, sin borde de pegatina, sin sombra. Formato cuadrado: la cresta ocupa el tercio de arriba solo en el centro y el yelmo, ancho, ocupa los dos tercios de abajo de lado a lado.
```

### Botas avanzadas (L: dos casillas de alto y la punta a la derecha abajo) · `botas_avanzadas.png`

Los iconos son pares de botas vistos de frente; la L pide una sola bota de perfil.

```
Una sola bota de cuero reforzado para el explorador de las imágenes anteriores, con hebillas de hierro y una puntera de metal, vista de perfil totalmente plano con la punta hacia la derecha. La caña sube recta y estrecha en la mitad izquierda y el pie se alarga hacia la derecha por abajo. Sola, sin personaje ni pierna. Mismo estilo de ilustración que las espadas: contorno fino oscuro y color con sombreado suave. Sin gemas ni adornos de colores. Fondo transparente, sin borde de pegatina, sin sombra. Formato cuadrado: la caña ocupa la mitad izquierda de arriba abajo y el pie, la mitad de abajo de lado a lado.
```

### Botas maestras (L: tres casillas de alto y la punta a la derecha abajo) · `botas_maestras.png`

```
Una sola greba de acero de caballero con su escarpe, para el explorador de las imágenes anteriores: protege la pierna desde la rodilla hasta el pie, con placas articuladas y ribetes dorados finos, vista de perfil totalmente plano con la punta del pie hacia la derecha. La pierna sube recta y estrecha y el pie se alarga hacia la derecha por abajo. Sola, sin personaje. Mismo estilo de ilustración que las espadas: contorno fino oscuro y color con sombreado suave. Sin gemas. Fondo transparente, sin borde de pegatina, sin sombra. Formato vertical, de 2 de ancho por 3 de alto: la pierna ocupa la mitad izquierda de arriba abajo y el pie, el tercio de abajo de lado a lado.
```

## Las que encajan con los iconos (o con prompt, si se quiere el mismo estilo que las espadas)

| Pieza | Forma | Icono actual | Cómo se monta |
|---|---|---|---|
| Escudo avanzado | 2×2 | redondo de madera (`shield_basic.png`) | entero, centrado |
| Escudo maestro | 2×3 | de cometa (`shield_master.png`) | entero, de pie |
| Casco básico | 1×1 | gorro de cuero (`helmet_basic.png`) | entero |
| Casco avanzado | 2×1 | yelmo con visera (`helmet_advanced.png`) | ancho: se recorta arriba y abajo o se pide de perfil |
| Botas básicas | 1×1 | par con cordones (`boots_basic.png`) | entero |

Ojo: los nombres de los iconos no siguen las formas de ahora. El icono `shield_basic.png` es redondo y va mejor en el 2×2 del avanzado; el `shield_advanced.png` es casi cuadrado.
