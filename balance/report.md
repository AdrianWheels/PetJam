# Informe de balance: PetJam-calibracion

Balanza 0.1.0 · 2026-10-01 · carpeta `balance`

## Avisos

- measured.json se midió con el plan anterior: si el catálogo cambió mucho, vuelve a medir

## Objetivos

15 de 35 cumplidos.

| Objetivo | Tipo | Valores | Límites | Margen |  |
|---|---|---|---|---|---|
| escalera[N=1] | order | 51 · 51 · 51 · 51 · 51 · 51 · 51 · 51 · 51 · 51 · 60 · 60 · 60 · 60 · 70 | paso 0 ≤ · < 7 | -42,9 % | ✘ |
| escalera[N=2] | order | 101 · 101 · 101 · 101 · 101 · 101 · 101 · 101 · 101 · 102 · 110 · 110 · 110 · 110 · 120 | paso 0 ≤ · < 7 | -42,9 % | ✘ |
| escalera[N=3] | order | 151 · 151 · 151 · 151 · 151 · 151 · 151 · 151 · 151 · 151 · 160 · 160 · 160 · 160 · 170 | paso 0 ≤ · < 7 | -42,9 % | ✘ |
| escalera[N=4] | order | 201 · 201 · 201 · 201 · 201 · 201 · 201 · 201 · 201 · 202 · 210 · 210 · 210 · 210 · 220 | paso 0 ≤ · < 7 | -42,9 % | ✘ |
| escalera[N=5] | order | 251 · 251 · 251 · 251 · 251 · 251 · 251 · 251 · 251 · 251 · 260 · 260 · 260 · 260 · 270 | paso 0 ≤ · < 7 | -42,9 % | ✘ |
| hito-basico[N=1] | band | 51 | ≥ 21 | 142,9 % | ✔ |
| hito-basico[N=2] | band | 101 | ≥ 71 | 42,3 % | ✔ |
| hito-basico[N=3] | band | 151 | ≥ 121 | 24,8 % | ✔ |
| hito-basico[N=4] | band | 201 | ≥ 171 | 17,5 % | ✔ |
| hito-basico[N=5] | band | 251 | ≥ 221 | 13,6 % | ✔ |
| hito-avanzado[N=1] | band | 51 | ≥ 41 | 24,4 % | ✔ |
| hito-avanzado[N=2] | band | 101 | ≥ 91 | 11 % | ✔ |
| hito-avanzado[N=3] | band | 151 | ≥ 141 | 7,1 % | ✔ |
| hito-avanzado[N=4] | band | 201 | ≥ 191 | 5,2 % | ✔ |
| hito-avanzado[N=5] | band | 251 | ≥ 241 | 4,1 % | ✔ |
| hito-maestro[N=1] | band | 60 | ≥ 51 | 17,6 % | ✔ |
| hito-maestro[N=2] | band | 110 | ≥ 101 | 8,9 % | ✔ |
| hito-maestro[N=3] | band | 160 | ≥ 151 | 6 % | ✔ |
| hito-maestro[N=4] | band | 210 | ≥ 201 | 4,5 % | ✔ |
| hito-maestro[N=5] | band | 260 | ≥ 251 | 3,6 % | ✔ |
| cota-basico[N=1] | band | 51 | < 41 | -24,4 % | ✘ |
| cota-basico[N=2] | band | 101 | < 91 | -11 % | ✘ |
| cota-basico[N=3] | band | 151 | < 141 | -7,1 % | ✘ |
| cota-basico[N=4] | band | 201 | < 191 | -5,2 % | ✘ |
| cota-basico[N=5] | band | 251 | < 241 | -4,1 % | ✘ |
| cota-avanzado[N=1] | band | 51 | < 51 | 0 % | ✘ |
| cota-avanzado[N=2] | band | 102 | < 101 | -1 % | ✘ |
| cota-avanzado[N=3] | band | 151 | < 151 | 0 % | ✘ |
| cota-avanzado[N=4] | band | 202 | < 201 | -0,5 % | ✘ |
| cota-avanzado[N=5] | band | 251 | < 251 | 0 % | ✘ |
| cota-maestro[N=1] | band | 70 | < 61 | -14,8 % | ✘ |
| cota-maestro[N=2] | band | 120 | < 111 | -8,1 % | ✘ |
| cota-maestro[N=3] | band | 170 | < 161 | -5,6 % | ✘ |
| cota-maestro[N=4] | band | 220 | < 211 | -4,3 % | ✘ |
| cota-maestro[N=5] | band | 270 | < 261 | -3,4 % | ✘ |

Peor paso de cada orden:

- escalera[N=1]: maestro (quality 0,85) → maestro (quality 1): +10
- escalera[N=2]: maestro (quality 0,85) → maestro (quality 1): +10
- escalera[N=3]: maestro (quality 0,85) → maestro (quality 1): +10
- escalera[N=4]: maestro (quality 0,85) → maestro (quality 1): +10
- escalera[N=5]: maestro (quality 0,85) → maestro (quality 1): +10

## Medidas

1 semilla por evaluación.

### Valor de cada estadística (puntos de damage por unidad)

| Nivel | damage | hp | armor | crit | aps |
|---|---|---|---|---|---|
| 1 | 1 | 0,1278 | 0,0654 | 18,2279 | 23,9726 |

### Poder medido de los objetos

| Objeto | Nivel | Puntos | Por escenario |
|---|---|---|---|
| boots_advanced | 1 | 4,523 | duel 4,52 |
| boots_basic | 1 | 2,113 | duel 2,11 |
| boots_master | 1 | 9,385 | duel 9,38 |
| helmet_advanced | 1 | 9,267 | duel 9,27 |
| helmet_basic | 1 | 4,189 | duel 4,19 |
| helmet_master | 1 | 18,295 | duel 18,3 |
| shield_advanced | 1 | 12,691 | duel 12,69 |
| shield_basic | 1 | 5,857 | duel 5,86 |
| shield_master | 1 | 24,975 | duel 24,98 |
| sword_advanced | 1 | 25,088 | duel 25,09 |
| sword_basic | 1 | 9,314 | duel 9,31 |
| sword_masterwork | 1 | 603,681 | duel 603,68 |

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

