---
name: godot-command-kit
description: >-
  Jugadas validadas en un juego Godot 4, con el addon CommandKit: cada jugada es
  una función del juego con nombre (do_place, y opcionalmente can_place con el
  motivo de rechazo y undo_place para deshacer), un nodo GameCommands que las
  encuentra y las corre, y un historial que se deshace, se guarda, se manda y se
  repite sobre un estado nuevo con la misma semilla. Los argumentos se validan
  contra la firma y solo corren las funciones do_*, así que sirve para recibir
  jugadas de la red. Usar cuando el usuario quiere deshacer, un historial de
  jugadas, repetir una partida, validar jugadas con un motivo («no es tu turno»,
  «casilla ocupada»), un juego por turnos o un puzzle con undo, jugadas por red
  sin confiar en el cliente o /add-commands. No son las reglas del juego, el
  azar ni la red.
---

# Godot — jugadas validadas con historial (CommandKit)

Addon `addons/command_kit/` en el proyecto del **juego**. Referencia: `addons/command_kit/README.md`.

Si el addon no está:

```bash
./install.sh --addon /path/to/godot-project command_kit
```

Habilitá el plugin **CommandKit** (el tipo `GameCommands` en Create Node; el nodo anda sin él). Pedido acotado: `/add-commands`. Composición: [godot-composition-first](../godot-composition-first/SKILL.md).

## Reglas

- **Una jugada es una función del juego.** `do_<nombre>(seat, args…)` la hace. Opcional: `can_<nombre>(seat, args…) -> String` (`""` = se puede, o el motivo) y `undo_<nombre>(seat, args…)` (si existe, se puede deshacer). Sin clases de orden.
- **`seat` es siempre el primer parámetro.** Quién la pide; un juego de un solo jugador pasa `0`.
- **Un nodo.** Un `GameCommands` hijo del nodo del juego (o con `game` apuntándolo). El inspector muestra `found_commands`: lo que encontró.
- **Solo corren las `do_*`.** `run(0, &"queue_free")` se rechaza con `unknown_command`. Los argumentos se validan contra la firma (`bad_arguments`): nunca confíes en otra cosa para una jugada que viene de la red.
- **El motivo es un texto corto** (`"not_your_turn"`), no una frase (un `can_` devuelve siempre `String`; `false` da `not_allowed`): la pantalla lo traduce con `tr()`.
- **Los chequeos de todas las jugadas, en un solo lugar.** `can_run(seat, command, args)` en el juego corre antes que el `can_<nombre>` de cada una.
- **Las funciones no cambian el estado de otra forma que `do_` y `undo_`.** Un `can_` no cambia nada. Una jugada no corre otra (`busy`): emití una señal y corré la otra desde un listener de `done`.
- **Deshacer = la última.** Si `undo_<nombre>` tiene un parámetro más que `do_<nombre>`, recibe lo que devolvió `do_<nombre>` (la pieza capturada). Una tirada de dados o una carta revelada no tiene `undo_`.
- **Azar repetible.** El `RandomNumberGenerator` con su `seed` vive en el estado del juego; `replay` sobre un estado nuevo con la misma semilla da lo mismo.
- **Un listener que responde** (un bot, un efecto) chequea `is_replaying()` en el handler mismo, antes de cualquier `call_deferred` o `await`.
- **El historial se guarda con `var_to_str`** (o `var_to_bytes`, o `JSON.from_native`), no con `JSON.stringify`: un `Vector2i` no sobrevive.
- **Las reglas headless usan `CommandLog`:** `CommandLog.new(self)` en un `RefCounted` y `commands.use_log(rules.commands)` en la escena.
- **Ningún kit depende de otro.** CommandKit no tiene red ni reglas: el juego conecta.

## Red

El asiento **nunca viaja**: el cliente manda el nombre y los argumentos, y el servidor pone el asiento de quien mandó. **Con MpKit**:

```gdscript
# cliente
net.to_server(&"command", &"place", [cell])


# servidor (el MpActor): sender_slot() dice quién mandó
func mp_sv_command(command: StringName, args: Array) -> void:
	commands.run(net.sender_slot(), command, args)
```

Una jugada que no existe o mal armada se rechaza sola, sin correr nada ni tirar errores. **Sin MpKit:** el mismo `run(slot_de_quien_mandó, nombre, args)` desde la entrada de red del juego.

## Árbol

```
Game (Node)                  # game.gd: estado tipado y do_place / can_place / undo_place; opcional can_run
├── Commands (GameCommands)  # game vacío = el padre
└── Hud                      # clic → commands.run(seat, &"place", [cell]); rejected → el motivo; Undo → commands.undo()
```

Arrancá desde `addons/command_kit/examples/minimal/minimal.tscn` (fichas en un tablero con rechazo, Undo y Replay).

## Qué va dónde

| Kit | Juego |
| --- | --- |
| Encontrar las `do_*`, validar los argumentos, correr los chequeos en orden | Las funciones `do_`, `can_` y `undo_` y las reglas que hay adentro |
| El historial: copia, deshacer, repetir, `is_replaying()` | El estado (tipado) y el RNG con semilla |
| Los motivos propios: `unknown_command`, `bad_arguments`, `not_allowed`, `busy` | Los motivos del juego (`"occupied"`) y cómo se dicen en pantalla |
| `done`, `rejected`, `undone` | Qué se anima o se escucha con cada una |
| Nada de la red | Mandar el nombre y los argumentos, y poner el asiento en el servidor |

## API esencial

| Qué | Cómo |
| --- | --- |
| Correr | `commands.run(seat, &"place", [cell]) -> String` (`""` = corrió) |
| Preguntar sin correr | `commands.can_run(seat, &"place", [cell]) -> String` |
| Deshacer | `commands.can_undo()`, `commands.undo()` |
| Guardar y repetir | `commands.history()`, `commands.clear()`, `commands.replay(history) -> String` |
| Mostrar el log de tus reglas | `commands.use_log(rules.commands)`, `commands.use_own_log()` |
| Señales | `done(seat, name, args)`, `rejected(seat, name, args, reason)`, `undone(seat, name, args)`, `rebuilt` |

## Listo cuando

- El nodo no muestra avisos y `found_commands` lista las jugadas del juego.
- F6: una jugada válida corre; una inválida se rechaza con su motivo y no deja rastro; Undo saca la última; repetir el historial sobre un estado nuevo da el mismo estado.
- En red, `run` recibe el asiento del servidor y una jugada inventada se rechaza sin errores.
- `godot --headless --path commandkit_lab --script res://addons/command_kit/tests/command_test_runner.gd` da `COMMANDKIT TESTS PASS` (en el repo del kit).

## Antipatrones

- Una clase por orden, `command_type()`, `from_args()`: son de 0.1. La jugada es una función.
- Mandar el `seat` desde el cliente y confiar en él: lo pone el servidor.
- Un `can_` que cambia el estado, o un `do_` que llama a `commands.run()`: da `busy`.
- Guardar el historial con `JSON.stringify` y perder los `Vector2i`.
- Dejar el azar fuera del estado (`randi()` global): la repetición no da lo mismo.
- Un `.tres` o un autoload para el historial: es un nodo en la escena o un `CommandLog` en las reglas.
- Dispararle jugadas propias a un listener de `done` sin chequear `is_replaying()`: el historial las duplica.
