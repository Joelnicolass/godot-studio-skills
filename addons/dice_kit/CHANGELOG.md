# Cambios de DiceKit

## 0.1.0

Primera versión:

- `DieFace` y `DieData`: un dado como recurso, con caras que tienen valor, símbolos (`tags`, uno puede repetirse; `tag` es el atajo para una cara de un símbolo) e ícono. `DieData.mesh` opcional: la forma con que la bandeja dibuja ese dado. Dados listos en `dice/` (d4, d6, d8, d10, d12 y d20, sin malla), `DieData.numbered(sides)` y `can_roll()`. Un dado con un lugar vacío no tira.
- `DiceRoll`: la tirada como datos puros y de solo lectura. `sum()`, `count(tag)` (cada aparición de un símbolo), `has(tag)`, `slots_with(tag)`, `values()`, `highest(n)` / `lowest(n)` (lugares) y `highest_values(n)` / `lowest_values(n)` (valores), `rerolled(slots, rng)` para volver a tirar algunos dados, `describe()`, dados mezclados con `DiceRoll.of`, y `to_dict` / `from_dict` / `from_indices` para guardar o mandar por red. Cada dado saca un número del rng que le das: la misma semilla da la misma tirada.
- `DiceRoller`: tira `count` de `die` más uno de cada `extra_dice` (dados mezclados desde el inspector) con su rng propio, armado con `rng_seed`, o con el rng de tu partida (`rng`); cambiar `rng_seed` nunca toca un rng asignado. Emite `rolled` y `dice_changed`; `pool()` dice qué dados tira. Botón **Roll** en el inspector, con `last_result`, para probar los dados sin correr el juego.
- `DiceTray3D`: muestra la tirada en 3D, en filas de `per_row`; cada dado con su `DieData.mesh`, o con la malla de la bandeja (`die_mesh`), o un cubo; los dados giran sin usar azar y caen con la cara que salió arriba, y avisa con `settled`. Sigue al roller con `dice_changed`, sin preguntar en cada cuadro.
- Ejemplo `examples/minimal` (3D), tests propios y `dicekit_lab/`, con avisos estrictos de GDScript y un chequeo en el editor real (`-- --dicekit-editor-check`).
