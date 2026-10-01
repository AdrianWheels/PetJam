# Informe de balance: PetJam-calibracion

Balanza 0.1.0 · 2026-10-01 · carpeta `balance`

## Avisos

Ninguno.

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

