# Franja de combate en pixel art

**Fecha:** 2026-09-27 · **Estado:** diseño aprobado en conversación, pendiente de revisar este spec · sin commit
**Petición:** la UI que el usuario imaginaba es la de su referencia (juego móvil en pixel art: franja de combate arriba, tablero en medio, botonera abajo). "Las formas geométricas eran realmente placeholder". Tras ver el elenco dibujado a mano: "Me encanta la dirección de arte así". Este spec cubre solo el primer paso, la franja de combate.

Sustituye la decisión de la fase anterior (`doc/specs/2026-09-27-mejora-visual-y-feeling.md`, apartado 2, que seguía `doc/Preguntas del proyecto.md` C1/C6) de mantener personajes geométricos.

---

## 1. Objetivo y criterios de éxito

La franja superior (25 % de la pantalla, hoy un `SubViewport` de 1080×480 dibujado con formas) pasa a ser pixel art como el de la referencia, con el elenco de `tools/pixel_art/`.

Criterios:
- Todo lo que se ve en la franja (personajes, fondo, efectos, textos y HUD) sale de píxeles nítidos del mismo tamaño. No hay texto con fuente vectorial, líneas suavizadas ni sprites escalados o girados.
- Los píxeles se ven regulares en cualquier ancho de pantalla, también cuando la ampliación no es entera.
- El equipo se ve en Tico: cada una de las 12 piezas (espada, escudo, casco y botas, en básico, avanzado y maestro) cambia su aspecto, y las 5 calidades se distinguen por color. Vale para la franja y para el panel de Equipo.
- Los 5 biomas se reconocen por fondo y decoración, y el cambio de bioma sigue fundiendo paletas.
- Se conserva todo lo que hoy pasa en la franja: carga y golpe, números de daño, críticos, hit-stop, temblor, bloqueo, pulsos, entrada de enemigos, jefe, muerte y reaparición del héroe, botín, plano desbloqueado, puertas de sala y carteles.
- La lógica de combate y el balance no cambian.
- El coste en móvil es igual o menor que ahora: se pintan 25 veces menos píxeles y los polígonos por fotograma pasan a ser sprites.

## 2. Decisiones

| Decisión | Elegido | Motivo |
|---|---|---|
| Tamaño de píxel | **×5**: lienzo de 216×96 para la franja (216×384 para la pantalla entera en los pasos siguientes) | Los personajes de 32 px ocupan un tercio de la altura y caben jefes de 48 px con nombre y barra. A ×6 (180×80) todo iba apretado. Elegido por el usuario sobre un boceto de las dos escalas. |
| Enfoque | **A: pasillo nativo a 216×96** | Es la única opción con píxeles nítidos en todo, efectos y textos incluidos. Descartadas: B (mundo a 1080×480 con sprites ×5: efectos y textos en alta resolución y píxeles deformados al moverse) y C (híbrido con textos en la capa de alta resolución: dos sistemas de coordenadas que sincronizar). |
| Paso siguiente | Tablero y botonera quedan para otros specs | Usarán el mismo tamaño de píxel. |

## 3. Render y medidas

- `HeroViewPanel` (`SubViewportContainer`, `stretch = true`) pasa a `stretch_shrink = 5`, y `HeroViewport` pinta a 216×96.
- Dentro del viewport, `canvas_item_default_texture_filter = Nearest`, `snap_2d_transforms_to_pixel = true` y `snap_2d_vertices_to_pixel = true`.
- La ampliación la hace el contenedor con un sombreador *sharp bilinear* (`shaders/pixel_upscale.gdshader`): muestreo por vecino más cercano dentro del píxel y mezcla solo en su borde. Con eso los píxeles se ven regulares también a escalas no enteras (ventana de 540, móviles de 720 o 1440 de ancho). El contenedor queda con filtro lineal, que es el que necesita el sombreador.
- **Unidad de mundo = 1 píxel del arte.** Una clase nueva `PixelView` (`scripts/gameplay/visual/PixelView.gd`, solo constantes) centraliza las medidas que hoy están repetidas en `Corridor.gd`, `DungeonBackdrop.gd`, `BackdropLayer.gd`, `RoomGate.gd`, `Hero.respawn` y `CombatFX.shatter`.

| Constante | Hoy (1080×480) | Nueva (216×96) |
|---|---|---|
| Lienzo | 1080×480 | 216×96 |
| Suelo (`FLOOR_Y`) | 400 | 80 |
| Héroe en pantalla | 0,3 del ancho (324) | 0,3 del ancho (65) |
| Inicio del héroe | (260, 400) | (52, 80) |
| Velocidad del héroe | 190 px/s | 38 px/s |
| Enemigo por delante (`SPAWN_AHEAD`) | 800 | 160 |
| Extra de jefe | 260 | 52 |
| Puerta antes del enemigo | 330 | 66 |
| Hueco de enganche | 16 | 3 |
| Adelanto de cámara | 216 | 43 |
| Cámara inicial / tras reaparecer | (0, 240) / (476, 240) | (0, 48) / (95, 48) |
| Enemigo tras reiniciar | x = 1060 | x = 212 |
| Alcance y medio ancho del héroe | 44 / 30 | 9 / 6 |
| Temblor máximo | 14×10 px y giro | 3×2 px, sin giro |

- Los tiempos (carga, golpe, pausas, reaparición, hit-stop) no cambian.
- **Cámara** (`CorridorCamera`): sigue igual en x con suavizado, pero redondea su posición a píxel entero para que las capas no tiemblen. El temblor son desplazamientos enteros. Se quitan el giro y el zoom de impacto, porque deforman el pixel art.
- Tamaño de los enemigos: `half_width`, `body_height`, `hover` y los puntos de anclaje (origen del orbe, centro del cuerpo) salen de `art/sprites/pixel/metrics.json`, que genera la herramienta a partir de la caja de píxeles opacos de cada sprite. Dejan de estar escritos a mano en `EnemyArchetypes`.

## 4. Tico

**Capas.** La herramienta exporta a `art/sprites/pixel/hero/` una tira por capa, todas con los mismos 13 fotogramas de 32×32 y sin contorno:

| Fotogramas | Uso |
|---|---|
| `idle_a`, `idle_b` | reposo (0,5 s cada uno) |
| `walk_1`…`walk_4` | andar, ligado a la fase de paso actual (que sigue soltando polvo en cada pisada) |
| `windup` | carga, cuando la carga supera la mitad |
| `strike_a`, `strike_b` | golpe, según avanza su decaimiento |
| `hurt` | recibir daño |
| `fall_1`…`fall_3` | caída al morir |

- Capas: `body` (lleva las botas en colores reservados), `weapon_none` (el palo), `weapon_basic`, `weapon_advanced`, `weapon_master`, `shield_*` y `helmet_*` en los tres niveles. El arma se dibuja para cada pose; escudo y casco se colocan en cada fotograma en el ancla del brazo y de la cabeza. Faltan por dibujar las piezas de nivel avanzado.
- **Composición en el juego** (`scripts/gameplay/visual/HeroSpriteBuilder.gd`, estático): al cambiar el equipo, apila `body` → `shield` → `helmet` → `weapon` con `Image.blend_rect`. Un color reservado de "borrado" en los cascos quita el pelo que asomaría. Después recolorea y añade el contorno exterior de 1 px, igual que `pixel_kit.outline()`. El resultado es un atlas de 13 fotogramas en una `ImageTexture`, cacheado por combinación de equipo.
- **Recoloreado por calidad:** los píxeles de acento de cada pieza (filo, banda del casco, emblema del escudo, banda de la bota) usan una rampa reservada de 3 tonos (colores exactos que no usa ningún otro píxel), que se sustituye por la del color de calidad (`TIER_COLORS`: aclarado, base y oscurecido).
- **Botas:** una rampa reservada que se sustituye por material. Sin botas o básicas, cuero; avanzadas, hierro; maestras, acero con puntera dorada.
- Épico y Legendario llevan un destello que recorre el filo. La composición genera, junto al atlas, una máscara con los píxeles de acento del arma, y el sombreador del sprite la recorre con una franja de brillo.
- **Nodo:** un `Sprite2D` con `hframes = 13`. `Hero.gd` elige el fotograma a partir del estado que ya calcula (`_windup`, `_strike`, `_hurt`, `walking`, `alive`). La estocada y el retroceso se mantienen como desplazamientos en píxeles enteros. La inclinación, el aplastamiento y el balanceo con giro desaparecen y los sustituyen los fotogramas.
- Un solo sombreador de sprite, `shaders/pixel_sprite.gdshader`, reúne el destello de golpe (mezcla hacia blanco), la disolución por patrón de píxeles para aparecer y caer (en lugar de escalar) y el brillo del filo.
- **Barra y nombre:** "TICO" en fuente pixel y barra de 22×3 px con borde oscuro, sobre la cabeza.
- **API:** se conserva la pública (`hp`, `max_hp`, `dmg`, `armor`, `crit_p`, `crit_m`, `aps`, `alive`, `gear`, `show_hud`, `reach`, `half_width`, `TIER_COLORS`, `take_damage`, `reset_stats`, `refresh_gear`, `respawn`, `attack`, `pulse`, `prepare_for_combat`, `set_invincible`, `body_center` y las señales), con posiciones en unidades nuevas. Se añade `play_materialize()` para que el panel de Equipo deje de tocar `_materialize`.
- **Panel de Equipo:** muestra el mismo Tico en su propio `SubViewportContainer` de 32×32 ampliado con el sombreador de la franja, en lugar de un `Hero.tscn` escalado ×2,5.

## 5. Enemigos y jefes

- Tiras de 4 fotogramas (`idle_a`, `idle_b`, `windup`, `strike`) en `art/sprites/pixel/enemies/<id>.png` (32×32) y `art/sprites/pixel/bosses/<bioma>.png` (48×48), ya mirando hacia el héroe.

| Estilo | Carga | Golpe | Movimiento que se conserva (en píxeles) |
|---|---|---|---|
| hop (Limo) | se aplasta | se estira en el salto | salto adelante en arco |
| swing (Esqueleto) | espada atrás | tajo | pequeño avance |
| dive (Murciélago) | alas arriba | en picado | subida y caída en diagonal |
| slam (Gólem y jefes) | puños arriba | puños al suelo | avance corto y bajada |
| cast (Espectro) | manos arriba con el orbe cargando | brazos adelante | subida corta; el orbe sigue saliendo de `cast_origin()` y llega al impactar |

- **Entradas:** caer desde arriba, entrar en picado y subir se conservan como desplazamientos. Las que hoy crecen o se estiran pasan a disolución por píxeles.
- **Jefe:** el de cada bioma según `Biomes.biome_index_for_room` (Rey Osario, Madre del Musgo, Señor del Magma, Coloso de Escarcha y Heraldo del Vacío) sustituye al hexágono con corona. `BOSS_STYLES` solo aporta el color de acento para efectos.
- Destello blanco al recibir daño con `pixel_sprite.gdshader`, el mismo que Tico, más un retroceso de 2 px.
- **Muerte:** `CombatFX.shatter_sprite()` lanza en trozos de 2×2 los píxeles opacos del fotograma actual, con sus colores, gravedad y rebote en el suelo. Sustituye a los polígonos.
- **Barra, nombre y alerta:**
  - Enemigo: "LIMO NV 3" en fuente pixel y barra de 22×3 px con daño fantasma, como ahora.
  - Jefe: barra de 40 px.
  - El "!" de alerta pasa a sprite.
- Se quita el crecimiento de tamaño por nivel (`size_mult`). No afecta a estadísticas.
- `set_biome_palette` deja de pintar el borde de luz, y la llamada desde `Corridor` desaparece.

## 6. Escenario

- **Capas:** se conservan las 5 capas `Parallax2D` de `DungeonBackdrop` (lejos 0,18, muro 0,5, columnas 0,78, suelo 1,0 y primer plano 1,45, que se atenúa en combate). Cada `BackdropLayer` pasa de dibujar polígonos a mostrar una tesela pixel: muro y lejos de 432 px, columnas y suelo de 216 y primer plano de 324.
- **Paleta por bioma:**
  - Las teselas de arquitectura (muro, arcos, nichos, columnas y losas) se dibujan una sola vez en tonos que codifican un papel: cielo, lejos, muro oscuro/base/luz, columna oscura/base/luz, suelo oscuro/base/luz, niebla, luz y acento.
  - `shaders/palette_swap.gdshader` los traduce a los colores del bioma leyendo las claves que ya tiene `Biomes.gd`.
  - El fundido de bioma (`lerp_palette` durante 1,4 s) sigue igual, pero actualizando el sombreador.
  - Si alguna paleta de `Biomes.gd` no funciona en pixel se ajusta allí.
- **Decoración propia de cada bioma**, en sprites a color en los nichos, como hoy hace `_draw_niche_decor`:

| Bioma | Nicho principal | Otros nichos | Detalle en el suelo |
|---|---|---|---|
| Catacumbas | estandartes | velas; armas cruzadas y escudo | — |
| Cripta Musgosa | enredaderas | velas; calaveras | musgo |
| Caverna de Magma | goteo de lava | brasero; estatua | grietas de lava encendidas |
| Glaciar Olvidado | cristales | estatua; calaveras | hielo |
| Santuario del Vacío | círculo de runas | estatuas | runas tenues |

- **Antorchas:** llama pixel de 4 fotogramas con colores `flame_*` del bioma y halo escalonado en 2 anillos, sin degradado continuo.
- **Puertas:** arco pixel (normal y de jefe con calaveras), con farol y placa con el número de sala en fuente pixel. Usan la paleta del bioma y la actualizan en los fundidos; hoy no se actualiza nunca.
- **Ambiente:** cielo en bandas con tramado, polvo, esporas, brasas o nieve de 1 px, y viñeta, tinte y destello a 216×96.

## 7. Efectos, textos y HUD de la franja

- **Fuentes pixel propias**, generadas por la herramienta en formato BMFont (`art/font/pixel/`) y cargadas como `FontFile` de tamaño fijo con escalado entero:
  - pequeña de 3×5, solo mayúsculas, con números, tildes, ñ, ¡ ¿ y puntuación (la del boceto). El texto se convierte a mayúsculas al pintarse;
  - grande de 5×7 para carteles y críticos.
- **Nada de texto vectorial dentro de la franja.** Números de daño, nombres, número de puerta, botín, "Bloqueo", "¡JEFE DERROTADO!" y "¡Nuevo plano!" usan estas fuentes.
- **`CombatFX`** conserva sus nombres de función para que `CombatController` y `Corridor` apenas cambien. Por dentro:
  - Chispas: puntos de 1 px con estela corta, sin antialiasing.
  - Corte: sprite de 3 fotogramas teñido con el color de calidad de la espada (hoy mezclado al 45 % hacia blanco).
  - Anillo y onda de pulso: círculos de 1 px sin antialiasing.
  - Estrella, orbe (3 fotogramas) y nube de polvo (3 fotogramas): sprites.
  - Haz de reaparición: columna en bandas con bordes tramados.
  - Números de daño: rebote de 1 px en lugar de escalar. Los críticos usan la fuente grande en dorado.
  - Botín: icono pixel de 12×12 para cada uno de los 9 materiales (`cloth`, `fire`, `herb`, `ice`, `iron`, `leather`, `poison`, `water`, `wood`), en lugar de los PNG de 1024 px.
  - Halos aditivos: escalonados.
- **HUD de la franja** (`HeroViewOverlay`): pasa a pintarse dentro del lienzo de 216×96, en una `CanvasLayer` del viewport que no sigue a la cámara. Así se amplía igual que todo lo demás.
  - Contenido, redistribuido para 216 px de ancho: oro con moneda animada de 4 fotogramas, muertes con calavera, sala, bioma, récord, las 10 marcas hasta el jefe (rombos y corona), carteles, avisos y fundido de caída.
  - Mantiene su lógica: señales del pasillo y de `GameManager`, y cola de avisos.
  - `HUDMain` enlaza con él en su nueva ruta.
  - El vuelo del plano hasta el botón de Planos sigue en `HUDMain`, en alta resolución. Su conversión de coordenadas ya contempla el `stretch_shrink`.
- Hit-stop sin cambios.

## 8. Herramienta y recursos

- `tools/pixel_art/` crece con los fotogramas de Tico, las capas de equipo, los fotogramas de enemigos y jefes, las teselas de fondo, la decoración, los sprites de efectos y HUD, los iconos de material, las fuentes y `metrics.json`.
- `python tools/pixel_art/export.py` regenera todo en `art/sprites/pixel/` y `art/font/pixel/`.
- Los PNG se importan sin mipmaps ni compresión con pérdida.
- Donde se ven fuera del viewport de la franja (panel de Equipo), el nodo lleva filtro Nearest o su propio mini-lienzo.
- Las normas de dibujo siguen `tools/pixel_art/README.md`:
  - paleta común;
  - contorno exterior de 1 px;
  - contorno interior con `stamp()` entre piezas;
  - dibujo mirando a la derecha con luz arriba a la izquierda;
  - enemigos volteados.

## 9. Qué cambia en el código

- **Reescritos por dentro, misma función:** `Hero.gd`, `Enemy.gd`, `CombatFX.gd`, `DungeonBackdrop.gd`, `BackdropLayer.gd`, `TorchFlame.gd`, `RoomGate.gd` y `HeroViewOverlay.gd`.
- **Adaptados a las nuevas unidades:** `Corridor.gd`, `CorridorCamera.gd` y `CombatController.gd` (anclajes de corte, números y "Bloqueo").
- **Otros ficheros tocados:**
  - `EnemyArchetypes.gd` pierde las medidas escritas a mano.
  - `HUD_Main.tscn`: contenedor, viewport y la nueva ruta del HUD.
  - `HUDMain.gd`: enlace con el HUD.
  - `EquipmentPanel.gd`: mini-lienzo y `play_materialize()`.
- **Nuevos:** `PixelView.gd`, `HeroSpriteBuilder.gd`, `shaders/pixel_upscale.gdshader`, `shaders/pixel_sprite.gdshader` y `shaders/palette_swap.gdshader`.
- **Se mantienen:** `Biomes.gd` (quizá con paletas ajustadas) y `ShapeKit.gd`, que siguen usando la pantalla de inicio, el resultado de crafteo, `ForgeIdleFX` y el HUD de la forja. Solo el pasillo deja de usarlo.
- **Se borran:** `CorridorParallax.gd` y `FloatingNumber.gd`, que no usa nadie, y la galería de formas `scenes/tests/ShapeGallery.tscn` con su script, sustituida por la nueva.
- La API pública que usan `CombatController`, `Corridor`, `GameManager`, `UIManager`, `DebugPanel`, `ShopPanel` y el panel de Equipo se conserva. Solo cambian las unidades de posición y distancia.

## 10. Pruebas

- **`scenes/tests/PixelGallery.tscn`** (sustituye a `ShapeGallery`) muestra, animándose:
  - Tico con varias combinaciones de equipo, que cubren las 12 piezas y las 5 calidades, pasando por todas sus animaciones;
  - los 5 enemigos y los 5 jefes con carga y golpe;
  - muestras de efectos;
  - las dos fuentes.
- **Arnés `scenes/tests/VisualCapture.tscn`** con los planes `main`, `boss`, `death`, `unlock`, `biome` y `tour`, que recorre los 5 biomas. Se revisan las capturas. Se corrige el comentario de cabecera que dice que el plan `boss` salta a la sala 9: los jefes están en la 10.
- **Comprobaciones:**
  - arranque sin errores de script;
  - combate completo;
  - equipar una pieza cambia a Tico en la franja y en el panel de Equipo;
  - muerte y reaparición;
  - jefe;
  - cambio de bioma;
  - plano desbloqueado.
- **Escalas no enteras:** captura con ventana de 540 y de 720 de ancho para comprobar el sombreador.

## 11. Riesgos

- **Mucho arte que dibujar:** 13 fotogramas de Tico con sus capas, 5×4 de enemigos, 5×4 de jefes, teselas, decoración de 5 biomas, efectos y fuentes. Se contiene con el recoloreado por paleta (fondos, calidades y botas) y con las capas, y se entrega por fases con el juego funcionando al final de cada una.
- **Las paletas de `Biomes.gd` se diseñaron para formas vectoriales.** Pueden necesitar ajuste para el pixel art.
- **Texto de 3×5 en móviles pequeños.** A ×5 en un móvil de 720 de ancho cada letra mide unos 10×17 px de pantalla. Si no se lee, la fuente pequeña pasa a 4×6.
- **La composición de Tico en el juego tiene un coste único al cambiar de equipo:** 13 fotogramas de 32×32 píxeles. Es despreciable y queda cacheado por combinación.

## 12. Fases

1. **Render y medidas:**
   - contenedor ×5 y sombreador de ampliación;
   - `PixelView`, unidades nuevas y cámara;
   - fuentes pixel;
   - Tico y enemigos con su reposo actual sobre un fondo liso, para que el juego funcione ya a 216×96.
2. **Tico:** fotogramas, capas de equipo (incluidas las de nivel avanzado), composición, recoloreado, destello y panel de Equipo.
3. **Enemigos y jefes:** fotogramas de carga y golpe, entradas, muerte en trozos, barras y nombres.
4. **Escenario:** teselas, sombreador de paleta, decoración de los 5 biomas, antorchas, puertas y ambiente.
5. **Efectos y HUD de la franja:** `CombatFX` en pixel, iconos de botín y HUD dentro del lienzo.
6. **Limpieza y verificación:** `PixelGallery`, borrados, capturas de todos los planes y escalas no enteras.

## 13. Fuera de alcance

- El tablero de minijuegos, la botonera y el resto de la interfaz (pasos 2 y 3).
- La lógica de combate, el balance, la economía, el audio y los enemigos nuevos.
- La herrera (Brasa) no aparece en la franja.
