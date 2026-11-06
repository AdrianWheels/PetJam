# Mejora visual y de "feeling" — Escenario, enemigos y combate

**Fecha:** 2026-09-27 · **Estado:** implementado (pendiente de revisión humana) · sin commit
**Petición:** "Mejora el escenario, los enemigos, el feeling general y lo visual. Total libertad. Piensa en el objetivo final del prototipo."

---

## 1. Objetivo y criterios de éxito

El objetivo final del prototipo es un idle/casual Android donde **lo que forjas se nota en la mazmorra**.
La franja del héroe (25 % superior) es la ventana que convierte el crafteo en progreso visible, así que es donde más rinde la mejora.

Criterios:
- La zona del héroe se lee de un vistazo en un móvil: quién gana, cuánta vida queda, en qué sala/profundidad estamos y cuánto falta para el jefe.
- Cada golpe, crítico, muerte y botín tiene respuesta visual y sonora (anticipación → impacto → reacción).
- El equipo que el jugador fabrica **se ve puesto en el héroe** (espada, escudo, casco, botas con color por calidad).
- Los enemigos son reconocibles por silueta y comportamiento, no solo por color.
- La profundidad se siente: el bioma cambia cada 10 salas, con un jefe como hito.
- Coste móvil bajo: nada de texturas gigantes, dibujo vectorial cacheado, partículas acotadas.

## 2. Decisión de dirección de arte: "geometría iluminada"

En `doc/Preguntas del proyecto.md` (C1, C6) se pidió explícitamente **combate con formas geométricas y ataques por cooldown**.
Se mantiene esa decisión y se convierte en un estilo deliberado en lugar de un placeholder:

- Personajes = formas geométricas planas con **sombreado a dos tonos, contorno oscuro, ojos** y accesorios. Siguen siendo pentágono (héroe), rombos/figuras (enemigos) y hexágono (jefe).
- Escenario = siluetas por capas con **perspectiva atmosférica** (lo lejano más apagado y tintado por la niebla del bioma), antorchas con halos aditivos y polvo flotante.
- Paleta cálida y oscura coherente con el fondo pintado de la forja y la fuente PirataOne.
- Se descartan los spritesheets de `art/assets/Spritesheets` (tiras de hasta 92 160 px de ancho: inviables en GPU móvil). Además se quitan de `Hero.tscn`/`Enemy.tscn`, donde se cargaban ocultos.

## 3. Escenario

- **Parallax procedural** (`Parallax2D`, Godot 4.3+) con 5 capas: fondo lejano, muro con arcos, columnas con antorchas, suelo y primer plano oscuro. Cada capa dibuja su contenido **una vez** en `_draw()` y se repite sola.
- **Biomas cada 10 salas** (el jefe cierra cada bioma): Catacumbas → Cripta Musgosa → Caverna de Magma → Glaciar Olvidado → Santuario del Vacío, y vuelta a empezar con numeral (II, III…). Cambio con fundido de paleta y cartel.
- **Puertas de sala**: un arco con el número de sala marca la frontera entre salas; el héroe lo cruza al avanzar.
- **Atmósfera**: polvo/brasas flotando (color por bioma), niebla baja sobre el suelo y viñeta.
- **Cámara**: héroe al tercio izquierdo, suelo al ~83 % de la altura, enemigo entrando por la derecha. Shake por "trauma" y pequeño punch de zoom en golpes fuertes.

## 4. Personajes

### Héroe
- Pentágono-escudo con cara (parpadea y mira al enemigo), capa, pies animados al andar e inclinación hacia delante.
- **Equipo visible** según `InventoryManager.equipped_items`: espada (main_hand), escudo (off_hand), casco (head), botas (feet). Color por tier de calidad (`CraftedItem.get_quality_color()`); sin espada lleva un puño/garrote básico.
- Animaciones: anticipación antes del golpe (se echa atrás), estocada con arco de corte, retroceso al recibir daño, estallido en fragmentos al morir y rayo de luz al reaparecer.

### Enemigos (arquetipos)
Mismo presupuesto de amenaza (vida × DPS ≈ constante) para no romper el balance, distinto ritmo:

| Arquetipo | Forma | Ritmo | Perfil |
|---|---|---|---|
| Limo | gota que rebota | medio | +vida, −daño |
| Esqueleto | rombo con calavera y hueso | medio | base |
| Murciélago | triángulo alado que flota | rápido | −vida, +velocidad |
| Gólem | bloque de piedra | lento y pesado | ++vida, golpes fuertes (shake) |
| Espectro | triángulo invertido que flota | medio | lanza orbes, −vida, +daño |
| **Jefe** | hexágono con corona y fragmentos orbitando | — | stats ×1.6 (como antes) + aura |

- Cada enemigo tiene placa con nombre y nivel, barra de vida con "daño fantasma" y un "!" de alerta al entrar en combate.
- Telegrafía: el ataque se anticipa (se carga) antes de impactar, así los golpes se leen.

## 5. Feeling de combate

- **Anticipación ligada al cooldown**: la pose de carga empieza cuando al temporizador le quedan ~0,15 s, así no cambia el DPS ni la lógica.
- **Hit-stop local** (congela solo el corredor, nunca los minijuegos): críticos y muertes.
- **Números de daño en el mundo** (antes se dibujaban en el viewport equivocado y no se veían): blanco normal, dorado grande en crítico, rojo cuando golpean al héroe, cian para el pulso mágico.
- **Partículas** propias en una sola capa de FX: chispas, fragmentos, anillos, polvo de pasos, arcos de corte.
- **Muerte de enemigo**: se rompe en fragmentos, sale el botín ("+15 Hierro" con icono) y, si desbloquea plano, un pergamino que vuela al botón de Planos con aviso.
- **Jefe**: cartel "¡JEFE!", viñeta roja pulsante y golpe de cámara al aparecer.
- **Muerte del héroe**: fundido rápido que oculta el teletransporte al inicio, cartel de caída y reaparición con luz.
- **Audio**: `AudioManager` pasa a tener varias voces (los golpes ya no se cortan entre sí) y variación de tono; golpes con 5 variantes.

## 6. HUD de la zona del héroe

- Arriba izquierda: oro con icono y conteo animado.
- Arriba centro: muertes (tal como se pidió en F3).
- Arriba derecha: sala actual, bioma y **récord** de sala (persistido; base para el leaderboard).
- Bajo el título: **10 marcas hasta el siguiente jefe**.
- Carteles: nuevo bioma, jefe, caída del héroe, plano desbloqueado.

## 7. Pulido general

- Tema global (`art/font/default_theme.tres`): paneles de hierro oscuro con borde bronce, botones con relieve y estados hover/pressed, pestañas y scrollbars a juego.
- Dock inferior: la fila de "minijuegos sueltos" (lanzaba minijuegos sin pedido) queda oculta salvo con el debug de minijuegos (Shift+P). Tarjetas de pedido verticales con cliente, icono en medallón, materiales en rojo si faltan, recompensa y etiqueta GRATIS; sacudida si no se puede aceptar y el icono "vuela a la forja" al aceptar.
- Botones Planos / Equipo / Tienda con icono pintado y etiqueta; insignia de "nuevo" en Equipo (objetos forjados sin mirar) y en Planos (planos desbloqueados).
- Panel de Equipo rehecho en vertical: el héroe EN VIVO (mismo dibujo que en la mazmorra) muestra lo que lleva; huecos con el icono del objeto y marco del color de su calidad; mochila con tarjetas legibles, stats y marca "▲ Mejora".
- Resultado de crafteo: **barra vertical** de metal fundido con umbrales Bueno/Raro/Épico/Legendario que se encienden (clinc cada vez más agudo); el objeto pasa de silueta a color con rayos y chispas del color del tier (se pidió así en E6).
- Títulos de minijuego: en español, con las instrucciones reales (antes siempre salía "INSTRUCTIONS"), se desvanecen solos a los 1,4 s y un toque los salta.
- Pantalla de inicio: arte a pantalla completa (sin franjas grises), título con brillo, brasas, botón grande y récord de profundidad.
- Colores de calidad unificados (acero, verde, azul, morado, naranja) en lugar de los colores puros de Godot.

## 7b. Sonido

- `AudioManager`: pool de 10 voces (los golpes ya no se cortan entre sí) y `play_sfx_pitched` con variación de tono.
- `default_bus_layout.tres`: bus `SFX` y limitador duro en Master (−1 dB) para que los solapes no saturen en el móvil.
- 13 SFX generados en local con ComfyUI + Stable Audio 3 (skill game-sfx): rotura de enemigo, monedas del botín, aparición y derrota del jefe, caída y reaparición del héroe, plano desbloqueado, entrada a bioma, orbe del espectro, golpe del gólem, equipar, aceptar pedido y toque de UI. Catálogo en `doc/sfx/petjam_sfx_events.json`, archivos en `art/sounds/sfx/generated/`, reproducción con `Sfx.play(id)`.
- Las tomas se eligieron puntuando con CLAP la adherencia a cada descripción (sin escucha humana): conviene reescucharlas. Para reauditar: `python <skill game-sfx>/scripts/sfx.py listen --events doc/sfx/petjam_sfx_events.json --out <carpeta de tomas>`.

## 7c. Arreglos colaterales encontrados por el camino

- La armadura se calculaba pero no reducía daño: ahora mitiga daño físico (`armor / (armor + 40)`, máx. 60 %), con destello "Bloqueo".
- Los 3 planos de botas no tenían `blueprint_id` ni `result_item`: forjar botas consumía materiales y no daba objeto.
- El primer jefe avanzaba dos salas (lo hacían `register_boss_defeat` y el Corridor).
- `start_run()` borraba muertes y sala de la partida cargada al entrar en Main.
- `SaveManager` imprimía un error en cada guardado (`Engine.get_singleton("GameManager")`).
- Los números de daño y las partículas no se veían (se añadían al viewport raíz o nunca se dibujaban) y las barras de vida quedaban fuera de cámara.

## 8. Arquitectura

Nuevos (todos en `scripts/gameplay/visual/` salvo el overlay):
- `Biomes.gd` — datos de biomas y helpers (bioma por sala, nombres, numerales).
- `ShapeKit.gd` — utilidades de dibujo (polígonos con contorno, sombreado, ojos…).
- `DungeonBackdrop.gd` + `BackdropLayer.gd` + `TorchFlame.gd` — escenario.
- `RoomGate.gd` — arco con número de sala.
- `CombatFX.gd` — partículas, textos y números en espacio de mundo.
- `CorridorCamera.gd` — seguimiento, shake y punch.
- `EnemyArchetypes.gd` — datos de arquetipos.
- `scripts/ui/HeroViewOverlay.gd` — HUD de la franja del héroe.

Modificados: `Hero.gd`, `Enemy.gd`, `Corridor.gd` (pasa a tabs), `CombatController.gd`, `Corridor.tscn`, `Hero.tscn`, `Enemy.tscn`, `HUD_Main.tscn`, `HUDMain.gd`, `AudioManager.gd`, `GameManager.gd` (récord + señal de plano desbloqueado), `SaveManager.gd` (quita un error de consola en cada guardado).

La API pública de `Hero`/`Enemy` (hp, max_hp, dmg, armor, crit_p, alive, take_damage, reset_stats, respawn, configure_for_level, set_invincible…) se mantiene.
No se añaden autoloads ni plugins. Indentación con tabs.

## 9. Verificación

- Arnés `scenes/tests/VisualCapture.tscn` grabado con `--write-movie` para revisar sin interacción. Planes: `main`, `craft`, `boss`, `death`, `unlock`, `biome`, `tour` (los 5 biomas), `panels`, `result` (pantalla de resultado; `--quality=0.93`), `title`.
  `godot --path . --write-movie out/f.png --fixed-fps 10 --quit-after 300 res://scenes/tests/VisualCapture.tscn -- --plan=tour`
  (ojo: el juego guarda en `user://save.json`).
- `scenes/tests/ShapeGallery.tscn`: todos los enemigos, los 5 jefes y el héroe con 4 equipos distintos, animándose.
- Arranque sin errores de script en consola; flujo de crafteo completo (3 pruebas → resultado → objeto en inventario) verificado.

## 9b. Revisión de código independiente (aplicada)

- Crítico: en móvil un toque en una tarjeta de pedido se procesaba dos veces (toque + clic emulado) y podía aceptar dos pedidos. Corregido.
- El pulso mágico podía golpear al enemigo siguiente en el mismo frame de una muerte; el tier de la pantalla de resultado podía diferir del del objeto (redondeo); el polvo del bioma se reiniciaba cada frame durante las transiciones; equipar durante la caída "revivía" al héroe en pantalla. Corregidos.
- Menores: puertas con fundido de entrada, contorno de luz sin diagonales, botín que rebota en el suelo real bajo enemigos voladores, arte correcto del plano que vuela, insignia de Equipo al llegar el objeto, enfriamiento en la "fanfarria" de críticos, tarjetas que no parpadean al reconstruir la cola y varias optimizaciones para móvil (caché de sombreado, rects transparentes ocultos, héroe de muestra sin procesar con el panel cerrado).
- Pendiente a propósito: el shader de fuego es compartido con el medidor de Forjamagia y no se tocó; el pulso de los enemigos no escala con el arquetipo (±5 % de amenaza); al crear el preset de Android conviene excluir `scenes/tests/*` y `scripts/tests/*` del export.

## 10. Fuera de alcance

Tipos de daño, pasivas de jefe, cálculo offline, rediseño de minijuegos y cambios de economía.
