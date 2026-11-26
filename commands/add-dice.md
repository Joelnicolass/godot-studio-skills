---
description: "Dados (addon DiceKit): dados con números, íconos y símbolos tirados con el rng del juego, suma y conteo por símbolo, los más altos y los más bajos, volver a tirar, dados mezclados desde el inspector, la misma semilla para las mismas tiradas, botón Roll en el inspector y una bandeja 3D opcional."
---

Agregá **dados** en el **proyecto Godot del juego** con el addon DiceKit:
- un `DieData` por tipo de dado (uno listo de `addons/dice_kit/dice/`, copiado al juego si hay que editarlo, o uno propio, con un `DieFace` por cara: `value`, `tags`, `icon`);
- un `DiceRoller` con ese dado, `count`, `extra_dice` si se mezclan dados, y `rng_seed` (o el rng de la partida en `roller.rng`);
- las reglas leyendo la tirada con `sum()`, `count(tag)`, `highest()` / `lowest()` y, si se vuelve a tirar, `rerolled(slots, rng)`;
- si se ven los dados, un `DiceTray3D` con `roller` y el HUD escuchando `settled`.

Después la persona aprieta **Roll** en el inspector y ve el resultado sin correr el juego; el agente arma y explica.

Esto **no** son las reglas del juego: el kit dice qué salió, y el juego decide qué hace un acierto o un crítico. **No** es física: los dados de la bandeja giran como presentación. **No** es la red: un juego en red tira en el servidor y manda índices.

Cargar: `godot-dice-kit`, `godot-composition-first`.

Si falta `addons/dice_kit/`:

```bash
./install.sh --addon /ABS/GODOT_ROOT dice_kit
```

Habilitá **DiceKit**. Si `godot-studio-workflow` está cargado: orquestador → árbol (este chat si son 1–3 archivos; si no, `studio-tech-lead`) → OK → `studio-developer`. Sin subagente extra.

## 1. Alcance

Si falta, preguntá en una sola tanda:

1. Qué dados hay: con números (d6, d20) o con símbolos propios (qué caras, qué valen, qué símbolos e ícono tiene cada una).
2. Quién tira, cuántos dados y cuándo (un ataque, un turno, un evento); si se mezclan dados de distinto tipo.
3. Qué hace el juego con la tirada: sumar, contar un símbolo, buscar un crítico, quedarse con el más alto o el más bajo, volver a tirar algunos.
4. Si las tiradas se repiten con una semilla (replays, desafíos diarios) o si el juego ya tiene un rng de la partida.
5. Si los dados se ven en 3D o solo el resultado (y con qué forma: cubos, un modelo para todos en `die_mesh` o uno por tipo de dado en `DieData.mesh`); si la partida se guarda o es en red.

## 2. Plan

Mostrá el árbol de archivos antes de tocar el juego (`[+]` nuevo, `[~]` cambiado, `[-]` borrado), por ejemplo:

```
[~] project.godot                        # plugin DiceKit
[+] dice/attack_die.tres          # DieData: 3 hit (1), 2 blank (0), 1 crit (2), con íconos
[+] dice/icons/hit.png            # el ícono de la cara hit
[~] combat/combat.gd              # roller.roll(n); count(&"hit") a las reglas
[~] ui/combat_hud.gd              # escucha tray.settled; muestra sum() y count(&"hit")
[~] levels/level/level.tscn       # DiceRoller (die, count, extra_dice, rng_seed) + DiceTray3D (roller)
```

Arrancá desde `addons/dice_kit/examples/minimal/minimal.tscn` (un dado propio, Roll 1/2/3, una semilla).

## 3. Implementar

Seguí [godot-dice-kit](../skills/godot-dice-kit/SKILL.md) y `addons/dice_kit/README.md`.

- Un `.tres` por dado propio; las caras repetidas van dos veces en `faces`.
- `die`, `count`, `extra_dice` y `rng_seed` en el inspector del `DiceRoller`; con un rng de la partida, `roller.rng = match_rng`.
- Las reglas leen la tirada que devuelve `roll()` (o `rolled`); sin nodos, `die.roll(n, rng)` y `DiceRoll.of(pool, rng)` para dados mezclados. Volver a tirar: `roll.rerolled(roll.slots_with(&"blank"), rng)`.
- El HUD muestra el resultado en `tray.settled`, cuando los dados cayeron.
- Guardar con `to_dict()` / `DiceRoll.from_dict(roller.pool(), data)`. En red, el servidor tira y manda índices.
- Decile a la persona cómo verlo: **Roll** en el inspector del `DiceRoller`, y los dados de la bandeja en la vista 3D.

## 4. Listo cuando

- El `DiceRoller` no muestra avisos y la persona apretó **Roll** en el inspector.
- F6: los dados giran, caen con la cara que salió y el HUD muestra la suma y los conteos.
- Con el mismo `rng_seed`, las mismas tiradas en el mismo orden.
- Nada de reglas de juego, `randi()` ni red dentro de `addons/dice_kit`.
