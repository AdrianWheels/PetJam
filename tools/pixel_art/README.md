# Pixel art de AFK Armory

Sprites dibujados a mano, píxel a píxel, con Python y Pillow. Cada personaje es código: se edita su script y se regenera.

## Uso

```
python tools/pixel_art/export.py
```

Genera en `tools/pixel_art/out/`:

- `strips/*.png`: una tira de 2 fotogramas (reposo) por personaje, a escala 1.
- `afk_armory_personajes.png`: hoja con todo el elenco a 5×.
- `review_frames.png`: fotogramas A y B uno junto al otro, para cazar saltos raros.

`hero.py`, `smith.py`, `enemies.py` y `bosses.py` también se pueden lanzar solos (desde esta carpeta) para una hoja de revisión rápida de su grupo.

## Convenciones

- Tamaños: 32×32 para Tico, Brasa y los enemigos; 48×48 para los jefes. Los pies apoyan en la fila 28 (32×32) o 45 (48×48).
- Paleta común en `pixel_kit.py`, una letra por color. `put(y, x, "cadena")` pinta una tira; `.` deja el píxel como está.
- `outline()` añade el contorno exterior de 1 px. Para separar piezas que se solapan (un brazo delante del torso), cada pieza se dibuja en su propio `Sprite` y se pega con `stamp(pieza, edge=<color de sombra>)`, que le pone un contorno interior oscuro.
- Todo se dibuja mirando a la derecha con la luz arriba a la izquierda. Enemigos y jefes se voltean al final con `flip()` para mirar al héroe.
- El equipo de Tico son capas sobre el cuerpo base (`hero.py`): arma, escudo, casco y botas.

La carpeta lleva `.gdignore` para que Godot no importe nada de aquí. La hoja de presentación usa fuentes de Windows (Bahnschrift y Segoe UI).
