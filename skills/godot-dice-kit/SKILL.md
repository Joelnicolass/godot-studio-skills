---
name: godot-dice-kit
description: >-
  Dados en un juego Godot 4 con el addon DiceKit: dados con cualquier cara
  (números, íconos, uno o varios símbolos como hit, blank o crit), tirados con
  el RandomNumberGenerator del juego, con la suma y cuántas veces salió cada
  símbolo; los más altos y los más bajos (ventaja, desventaja, sacar el más
  bajo), volver a tirar algunos dados, dados listos (d4 a d20), dados
  mezclados desde el inspector (2d6 + 1d8), la misma semilla para las mismas
  tiradas, tiradas que se guardan o se mandan por red como índices, un botón
  Roll en el inspector para probar los dados y una bandeja 3D (cubos o tu
  malla, en filas) donde los dados giran y caen con la cara que salió. Un
  DieData y un DiceRoll de datos puros para las reglas, un nodo DiceRoller
  para el editor y un DiceTray3D opcional. Usar cuando el usuario quiere
  dados, tirar dados, un 2d6, dados de ataque con símbolos, aciertos y
  críticos, ventaja, volver a tirar, tiradas que se repiten con una semilla o
  /add-dice. No son las reglas del juego (qué hace un acierto), la física de
  los dados ni la red.
---

# Godot — dados (DiceKit)

Addon `addons/dice_kit/` en el proyecto del **juego**. Referencia: `addons/dice_kit/README.md`.

Si el addon no está:

```bash
./install.sh --addon /path/to/godot-project dice_kit
```

Habilitá el plugin **DiceKit** (tipos `DiceRoller` y `DiceTray3D` en Create Node; `DieData` y `DieFace` en New Resource). Pedido acotado: `/add-dice`. Composición: [godot-composition-first](../godot-composition-first/SKILL.md).

## Reglas

- **Dos niveles.** Las reglas del juego tiran con `die.roll(n, rng)` o `DiceRoll.of(pool, rng)` (datos puros, se testea headless). El `DiceRoller` es el nodo que tira el dado del inspector; el `DiceTray3D` lo muestra.
- **Un dado es un recurso.** `DieData` con un `DieFace` por cara (`value`, `tags`, `icon`). Una cara puede tener varios símbolos, y uno puede repetirse (`[hit, hit, shield]`). Los dados con números ya están en `addons/dice_kit/dice/` (d4 a d20): para editarlos, copiá el `.tres` al juego. Un dado propio es un `.tres` del juego; una cara más probable va dos veces en `faces`. Un lugar vacío en `faces` hace que el dado no tire.
- **El azar es del juego.** Cada dado saca un número del rng que recibe; nada del kit llama al azar global. `rng_seed` distinto de 0 repite las tiradas; con un rng de la partida (`roller.rng = match_rng`), una sola semilla repite todo, y `rng_seed` ya no lo toca.
- **La tirada es tipada y no cambia.** `DiceRoll` con `sum()`, `count(tag)`, `has(tag)`, `slots_with(tag)`, `values()`, `highest()` / `lowest()` (lugares), `highest_values()` / `lowest_values()` (valores), `rerolled(slots, rng)` (una tirada nueva) y `describe()`. `dice`, `faces` e `indices` son copias de solo lectura. Nada de arrays de diccionarios.
- **Dados mezclados sin código.** `count` de `die` más uno de cada `extra_dice`, desde el inspector; `roller.pool()` dice qué dados tira.
- **Editor primero.** El botón **Roll** del inspector tira con los valores del nodo y muestra el resultado en `last_result`; la bandeja muestra los dados en el editor, sigue al roller con `dice_changed` y los hace girar con ese botón. El roller avisa si faltan dados, si uno no tiene caras o si tiene lugares vacíos.
- **La bandeja es presentación.** Los dados giran sin azar (la misma tirada gira igual) y `settled` dice cuándo cayeron: ahí se muestra el resultado. La regla usa la tirada apenas sale (`rolled` o lo que devuelve `roll()`). Cada dado se dibuja con su `DieData.mesh` (un d8 con forma de d8, también entre otros dados), si no con el `die_mesh` de la bandeja, si no como un cubo; la cara que salió va arriba, como una calcomanía. `per_row` arma filas.
- **Guardar y la red.** `to_dict()` guarda solo los índices; `DiceRoll.from_dict(roller.pool(), data)` la rearma con los mismos dados. En red, el servidor tira y manda índices.
- **Ningún kit depende de otro.** DiceKit no tiene reglas, red ni autoload: el juego conecta (por ejemplo, cada acierto le saca vida a otra unidad).

## Árbol

```
Level
├── AttackRoller (DiceRoller)            # die = attack_die.tres, count = 3, extra_dice = [], rng_seed = 0
├── DiceTray3D                           # roller = AttackRoller; settled → HUD
├── Hud (Control)                        # escucha settled y muestra sum() / count(&"hit")
└── Combat (Node)                        # roller.roll(n) → aplica count(&"hit") a sus reglas
```

Arrancá desde `addons/dice_kit/examples/minimal/minimal.tscn`.

## Qué va dónde

| Kit | Juego |
|---|---|
| Las caras, tirar, sumar y contar símbolos | Qué significa cada símbolo, cuántos dados tira cada uno |
| `rng_seed`, `rng`, una tirada por índices | La semilla de la partida, quién tira en red |
| `highest`, `lowest`, `rerolled`, `slots_with` | Cuándo hay ventaja, qué dados se vuelven a tirar y cuántas veces |
| `DiceTray3D`, `settled` | La cámara, la mesa, el HUD y cuándo mostrar el resultado |
| `to_dict` / `from_dict` / `from_indices` | Dónde se guarda y cómo viaja por la red |
| `describe()` | El texto del registro en el idioma del juego |

## Listo cuando

- El `DiceRoller` no muestra avisos y **Roll** en el inspector muestra un `last_result` que tiene sentido.
- F6: los dados giran, caen con la cara que salió y el HUD muestra la suma y los conteos en `settled`.
- Con el mismo `rng_seed`, la misma secuencia de tiradas.
- `godot --headless --path dicekit_lab --script res://addons/dice_kit/tests/dice_test_runner.gd` da `DICEKIT TESTS PASS` (en el repo del kit).

## Antipatrones

- `randi()`, `randf()` o `pick_random()` para tirar dados: usá un `DieData` y un rng del juego.
- Un `Array` de diccionarios como tirada: `DiceRoll` ya está tipada.
- Reglas de daño o de combate dentro del kit: el kit dice qué salió, el juego decide qué hace.
- Mostrar el resultado en `rolled` con la bandeja girando: esperá `settled`.
- Tirar en cada cliente sin compartir la semilla: tira el servidor y manda índices.
- Un `Dictionary` suelto para caras con varios símbolos: van en `tags`, repetidos si hace falta.
- Editar un dado de `addons/dice_kit/dice/` en su lugar: reinstalar el kit lo pisa; copialo al juego.
- Armar a mano una tirada para volver a tirar algunos dados: `roll.rerolled(slots, rng)`.
