# Armas futuras

Arte preparado para armas que aún no existen en el juego (2026-10-02): imágenes de ChatGPT en `../sources/nuevas/` y una forma propuesta para cada una. No hay objeto en `data/items/` ni estadísticas: son una propuesta que el usuario decidirá.

| Arma | Forma propuesta | Casillas |
|---|---|---|
| Guantelete | cuadrado 2×2 | 4 |
| Guadaña | C de 2×3 | 5 |
| Cruz | + de 3×3 | 5 |
| Aro | anillo de 3×3 con el centro vacío | 8 |
| Martillo | T de 3×2 | 4 |
| Pico | L de 2×2 | 3 |
| Ballesta | 2×1 | 2 |
| Maza | 1×2 | 2 |
| Espada con vaina | 1×3 | 3 |
| Lanza | 1×3 | 3 |

El aro va sin máscara: así conserva su hueco redondo, que deja libre la casilla del centro.

Para revisarlas:

    python tools/gear_art/build_gear_art.py --pieces=tools/gear_art/futuras --preview=<carpeta>

Las texturas salen en `out/`, que no se sube. Cuando una arma entre en el juego, su `.json` pasa a `../pieces/` con el `item_id` del objeto y las mismas `cells` que su `shape_cells`.
