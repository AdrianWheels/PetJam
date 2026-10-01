# Informe de balance: PetJam-calibracion

Balanza 0.1.0 · 2026-10-01 · carpeta `balance`

## Avisos

- measured.json se midió con el plan anterior: si el catálogo cambió mucho, vuelve a medir

## Objetivos

35 de 35 cumplidos.

| Objetivo | Tipo | Valores | Límites | Margen |  |
|---|---|---|---|---|---|
| escalera[N=1] | order | 35 · 37 · 37 · 37 · 38 · 40 · 44 · 45 · 47 · 48 · 50 · 51 · 52 · 55 · 57 | paso 0 ≤ · < 7 | 0 % | ✔ |
| escalera[N=2] | order | 86 · 87 · 88 · 88 · 88 · 90 · 94 · 95 · 97 · 98 · 100 · 102 · 103 · 105 · 106 | paso 0 ≤ · < 7 | 0 % | ✔ |
| escalera[N=3] | order | 136 · 137 · 137 · 137 · 138 · 140 · 144 · 145 · 147 · 148 · 150 · 151 · 153 · 154 · 156 | paso 0 ≤ · < 7 | 0 % | ✔ |
| escalera[N=4] | order | 185 · 187 · 188 · 188 · 189 · 190 · 194 · 195 · 197 · 198 · 200 · 202 · 203 · 205 · 207 | paso 0 ≤ · < 7 | 0 % | ✔ |
| escalera[N=5] | order | 235 · 236 · 238 · 238 · 239 · 240 · 243 · 245 · 247 · 248 · 250 · 251 · 253 · 255 · 256 | paso 0 ≤ · < 7 | 0 % | ✔ |
| hito-basico[N=1] | band | 37 | ≥ 21 | 76,2 % | ✔ |
| hito-basico[N=2] | band | 88 | ≥ 71 | 23,9 % | ✔ |
| hito-basico[N=3] | band | 137 | ≥ 121 | 13,2 % | ✔ |
| hito-basico[N=4] | band | 188 | ≥ 171 | 9,9 % | ✔ |
| hito-basico[N=5] | band | 238 | ≥ 221 | 7,7 % | ✔ |
| hito-avanzado[N=1] | band | 47 | ≥ 41 | 14,6 % | ✔ |
| hito-avanzado[N=2] | band | 97 | ≥ 91 | 6,6 % | ✔ |
| hito-avanzado[N=3] | band | 147 | ≥ 141 | 4,3 % | ✔ |
| hito-avanzado[N=4] | band | 197 | ≥ 191 | 3,1 % | ✔ |
| hito-avanzado[N=5] | band | 247 | ≥ 241 | 2,5 % | ✔ |
| hito-maestro[N=1] | band | 55 | ≥ 51 | 7,8 % | ✔ |
| hito-maestro[N=2] | band | 105 | ≥ 101 | 4 % | ✔ |
| hito-maestro[N=3] | band | 154 | ≥ 151 | 2 % | ✔ |
| hito-maestro[N=4] | band | 205 | ≥ 201 | 2 % | ✔ |
| hito-maestro[N=5] | band | 255 | ≥ 251 | 1,6 % | ✔ |
| cota-basico[N=1] | band | 38 | < 41 | 7,3 % | ✔ |
| cota-basico[N=2] | band | 88 | < 91 | 3,3 % | ✔ |
| cota-basico[N=3] | band | 138 | < 141 | 2,1 % | ✔ |
| cota-basico[N=4] | band | 189 | < 191 | 1 % | ✔ |
| cota-basico[N=5] | band | 239 | < 241 | 0,8 % | ✔ |
| cota-avanzado[N=1] | band | 48 | < 51 | 5,9 % | ✔ |
| cota-avanzado[N=2] | band | 98 | < 101 | 3 % | ✔ |
| cota-avanzado[N=3] | band | 148 | < 151 | 2 % | ✔ |
| cota-avanzado[N=4] | band | 198 | < 201 | 1,5 % | ✔ |
| cota-avanzado[N=5] | band | 248 | < 251 | 1,2 % | ✔ |
| cota-maestro[N=1] | band | 57 | < 61 | 6,6 % | ✔ |
| cota-maestro[N=2] | band | 106 | < 111 | 4,5 % | ✔ |
| cota-maestro[N=3] | band | 156 | < 161 | 3,1 % | ✔ |
| cota-maestro[N=4] | band | 207 | < 211 | 1,9 % | ✔ |
| cota-maestro[N=5] | band | 256 | < 261 | 1,9 % | ✔ |

Peor paso de cada orden:

- escalera[N=1]: basico (quality 0,55) → basico (quality 0,7): +0
- escalera[N=2]: basico (quality 0,7) → basico (quality 0,85): +0
- escalera[N=3]: basico (quality 0,55) → basico (quality 0,7): +0
- escalera[N=4]: basico (quality 0,7) → basico (quality 0,85): +0
- escalera[N=5]: basico (quality 0,7) → basico (quality 0,85): +0

## Catálogo

| Objeto | Rareza | Ranura | Nivel | Presupuesto | Estadísticas (nominal) | Efectos | Redondeo |
|---|---|---|---|---|---|---|---|
| sword_basic | basic | main_hand | 1 | 9,85 | damage 6 · crit 0,07 · aps 0,115 | — | 1,9 % |
| shield_basic | basic | off_hand | 1 | 4,35 | hp 33 · armor 3 | — | 2,2 % |
| helmet_basic | basic | head | 1 | 3,38 | hp 25 · armor 2 | — | -1,1 % |
| boots_basic | basic | feet | 1 | 1,84 | hp 14 · armor 1 | — | 1,4 % |
| sword_advanced | advanced | main_hand | 1 | 22,13 | damage 13 · crit 0,15 · aps 0,255 | — | -1,2 % |
| shield_advanced | advanced | off_hand | 1 | 9,77 | hp 73 · armor 6 | — | 0,1 % |
| helmet_advanced | advanced | head | 1 | 7,6 | hp 57 · armor 4 | — | -0,2 % |
| boots_advanced | advanced | feet | 1 | 4,13 | hp 30 · armor 3 | — | -1,6 % |
| sword_masterwork | master | main_hand | 1 | 44,51 | damage 27 · crit 0,3 · aps 0,51 | — | 0,5 % |
| shield_master | master | off_hand | 1 | 19,65 | hp 147 · armor 11 | — | -0,2 % |
| helmet_master | master | head | 1 | 15,28 | hp 115 · armor 9 | — | 0,6 % |
| boots_master | master | feet | 1 | 8,3 | hp 61 · armor 6 | — | -0,6 % |

## Medidas

1 semilla por evaluación.

### Valor de cada estadística (puntos de damage por unidad)

| Nivel | damage | hp | armor | crit | aps |
|---|---|---|---|---|---|
| 1 | 1 | 0,1275 | 0,079 | 18,1817 | 24,0591 |

### Poder medido de los objetos

| Objeto | Nivel | Puntos | Por escenario |
|---|---|---|---|
| sword_basic | 1 | 8,671 | duel 8,67 |
| shield_basic | 1 | 5,517 | duel 5,52 |
| helmet_basic | 1 | 3,853 | duel 3,85 |
| boots_basic | 1 | 2,092 | duel 2,09 |
| sword_advanced | 1 | 18,685 | duel 18,69 |
| shield_advanced | 1 | 11,337 | duel 11,34 |
| helmet_advanced | 1 | 8,173 | duel 8,17 |
| boots_advanced | 1 | 4,433 | duel 4,43 |
| sword_masterwork | 1 | 33,4 | duel 33,4 |
| shield_master | 1 | 20,455 | duel 20,46 |
| helmet_master | 1 | 15,023 | duel 15,02 |
| boots_master | 1 | 8,44 | duel 8,44 |

## Ajuste

12 objetos, 6 grados de libertad, error típico 2,8 %. Aplicado a balance.json y archetypes.csv.

| Parámetro | Valor |
|---|---|
| curve.base | 9,85 |
| rarities.basic.mult | 1 (fija) |
| rarities.advanced.mult | 2,2464 |
| rarities.master.mult | 4,519 |
| slots.main_hand | 1 (fija) |
| slots.feet | 0,1865 |
| slots.head | 0,3433 |
| slots.off_hand | 0,4415 |
| rarities.advanced.quality | lo 0,593 · hi 1,333 · ref 0,55 |
| rarities.basic.quality | lo 0,577 · hi 1,346 · ref 0,55 |
| rarities.master.quality | lo 0,645 · hi 1,29 · ref 0,55 |
| arquetipo botas | hp 0,942 · armor 0,058 |
| arquetipo casco | hp 0,956 · armor 0,044 |
| arquetipo escudo | hp 0,954 · armor 0,046 |
| arquetipo espada | damage 0,603 · crit 0,121 · aps 0,276 |

| Objeto | Presupuesto implícito | Ajustado | Residuo | Fuente |
|---|---|---|---|---|
| sword_basic | 9,32 | 9,85 | -5,4 % | modelo |
| sword_masterwork | 46,51 | 44,51 | 4,5 % | modelo |
| shield_basic | 4,52 | 4,35 | 3,9 % | modelo |
| shield_master | 19,03 | 19,65 | -3,1 % | modelo |
| helmet_master | 14,87 | 15,28 | -2,7 % | modelo |
| helmet_basic | 3,46 | 3,38 | 2,4 % | modelo |
| boots_master | 8,43 | 8,3 | 1,6 % | modelo |
| sword_advanced | 22,39 | 22,13 | 1,2 % | modelo |
| boots_advanced | 4,09 | 4,13 | -1 % | modelo |
| shield_advanced | 9,71 | 9,77 | -0,6 % | modelo |
| boots_basic | 1,83 | 1,84 | -0,6 % | modelo |
| helmet_advanced | 7,63 | 7,6 | 0,4 % | modelo |

