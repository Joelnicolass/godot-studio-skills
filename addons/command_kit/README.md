# CommandKit

Jugadas validadas con motivo de rechazo, deshacer, y un historial que se guarda, se manda y se repite. Sirve para juegos por turnos, puzzles con deshacer, editores y multijugador por órdenes.

Cada jugada es una función de tu juego con un nombre: `do_place`, y opcionalmente `can_place` (por qué no) y `undo_place` (cómo se saca). CommandKit **no tiene** reglas de juego, azar, red ni autoload: el estado y las reglas son tuyos, el kit solo corre las jugadas válidas y las anota.

## Instalar

```bash
./install.sh --addon /path/to/godot-project command_kit
```

Habilitá el plugin **CommandKit** (tipo `GameCommands` en Create Node).

## En 3 pasos

1. Escribí las funciones en tu juego. El primer parámetro es siempre `seat`: quién la pide (un juego de un solo jugador pasa `0`).

```gdscript
# stones.gd (el nodo de tu juego)
var stones: Dictionary[Vector2i, int] = {}
var turn := 0


func can_place(seat: int, cell: Vector2i) -> String:  # opcional: "" = se puede, o el motivo
	if seat != turn:
		return "not_your_turn"
	return "occupied" if stones.has(cell) else ""


func do_place(seat: int, cell: Vector2i) -> void:     # la jugada
	stones[cell] = seat
	turn = 1 - seat


func undo_place(seat: int, cell: Vector2i) -> void:   # opcional: si existe, se puede deshacer
	stones.erase(cell)
	turn = seat
```

2. Agregá un nodo `GameCommands` como hijo de tu juego (o poné tu juego en `game`). El inspector muestra `found_commands`: las jugadas que encontró, por ejemplo `place (can, undo)`.
3. Corré las jugadas y escuchá los rechazos:

```gdscript
@onready var commands: GameCommands = $Commands


func _ready() -> void:
	commands.rejected.connect(func(_seat: int, _name: StringName, _args: Array, reason: String) -> void: hud.say(tr(reason)))


func _on_cell_clicked(cell: Vector2i) -> void:
	commands.run(turn, &"place", [cell])
```

## Ejemplo mínimo

`examples/minimal/minimal.tscn` (F6): dos jugadores ponen fichas (X y O) por turnos en un tablero de 5 × 5. Un clic en una casilla ocupada se rechaza y se ve el motivo. **Undo** saca la última ficha y **Replay** vacía el tablero y repite el historial ficha por ficha.

```
Minimal          # minimal.gd (Control): solo la pantalla: botones del tablero, Undo, Replay y el estado
├── Box          # Status (Label), Board (GridContainer), Undo y Replay
├── Stones       # stones.gd (Node): EL JUEGO: estado tipado y can_place / do_place / undo_place
└── Commands     # GameCommands: game = Stones
```

## Cómo funciona

- **Jugadas.** Son las funciones `do_<nombre>` del script de tu objeto (un `Node`, o el `RefCounted` de tus reglas), incluidas las de sus scripts base. Nada más se puede correr: `run(0, &"queue_free")` se rechaza con `unknown_command`, porque no hay un `do_queue_free`. Esa lista cerrada es lo que hace segura a la red.
- **Argumentos.** `run(seat, &"place", [cell])` los valida contra la firma de `do_place`: cantidad (los que tienen valor por defecto pueden faltar) y tipo. Un `int` vale donde va un `float`, `String` y `StringName` son intercambiables, un `Array` plano vale donde va un `Array[Vector2i]` si sus elementos lo son (igual con `Dictionary[K, V]`). Si no coinciden: `bad_arguments`, sin llamar a nada y sin errores de script, aunque el cliente mande basura.
- **Chequeos, en este orden:** la jugada existe, los argumentos coinciden, `can_run(seat, command, args)` general si existe, y `can_<nombre>(seat, args…)` si existe. El primer motivo no vacío rechaza. Las `can_` devuelven `String` o `StringName`, y no cambian el estado. Una `can_` sin tipar que devuelve `true` o nada deja pasar; `false` rechaza con `not_allowed`; cualquier otro tipo es un error (se avisa) y también rechaza con `not_allowed`.
- **Hacerla.** Se llama `do_<nombre>(seat, args…)`. Después entra al historial y recién entonces se emite `done`. Un listener de `done` puede correr otra jugada (un bot que responde): queda después en el historial.
- **Historial.** `history()` devuelve una **copia profunda** con un `{name, seat, args}` por jugada aceptada, de la más vieja a la más nueva. Los `args` se copian antes de llamar a `do_`: si `do_` cambia un array que le pasaron, el historial no cambia.
- **Deshacer.** `undo()` saca la última jugada y llama a `undo_<nombre>(seat, args…)`. Solo la última: si no tiene `undo_`, `can_undo()` es false y las anteriores tampoco se pueden deshacer. Si `undo_<nombre>` declara **un parámetro más** que `do_<nombre>`, recibe al final lo que devolvió `do_<nombre>` (por ejemplo la pieza capturada). Ese dato vive solo en memoria: no está en `history()`.
- **Repetir.** `replay(history)` corre cada entrada. Devuelve `""` si todas corrieron, o el motivo de la primera que no (las anteriores ya corrieron). Las repetidas se agregan al final del historial: sobre un historial vacío (`clear()` antes) una repetición completa lo deja igual al original.
  - Mientras corre, `is_replaying()` es true. Un listener que manda jugadas propias (un bot, un efecto automático) no manda nada en ese momento, porque sus jugadas ya están en el historial.
  - Una entrada mal formada corta con `unknown_command` (no es un diccionario, no tiene `name`) o `bad_arguments` (`args` no es un array, `seat` no es un entero), sin errores de script.
- **Una jugada no corre otra.** Si `run`, `undo` o `replay` se llaman desde adentro de un `can_`, un `do_` o un `undo_` del juego, el kit avisa con un error y devuelve `busy` sin tocar nada: el historial quedaría en un orden que la repetición duplicaría. Emití una señal y corré la otra jugada después, o desde un listener de `done`.

## API

### `CommandLog` (RefCounted)

`CommandLog.new(game)`: datos puros, sin nodos. Las reglas de tu juego lo usan directo y se testea headless. No mantiene vivo a `game`.

| Miembro | Qué hace |
| --- | --- |
| `game` | El objeto con las funciones `do_` / `can_` / `undo_`. Cambiarlo vuelve a leer las jugadas y no vacía el historial |
| `keep_history` | Apagado: las jugadas corren y emiten, pero no se guardan (sin deshacer ni historial) |
| `run(seat, name, args = []) -> String` | Corre una jugada válida. `""` = corrió; si no, el motivo |
| `can_run(seat, name, args = []) -> String` | Lo mismo sin correr: no cambia nada ni emite |
| `can_undo()`, `undo() -> bool` | Deshace la última |
| `history() -> Array[Dictionary]` | Copia del historial: `{name, seat, args}` |
| `replay(history) -> String`, `is_replaying()` | Repite un historial; `""` = todas corrieron |
| `size()`, `clear()` | Cuántas hay, y vaciar el historial (las jugadas siguen) |
| `commands() -> Array[StringName]`, `has_command(name)` | Las jugadas que encontró (sin `do_`), ordenadas |
| `UNKNOWN_COMMAND`, `BAD_ARGUMENTS`, `NOT_ALLOWED`, `BUSY` | Motivos propios del kit: `"unknown_command"`, `"bad_arguments"`, `"not_allowed"`, `"busy"` |
| señal `done(seat, name, args)` | Corrió y está en el historial |
| señal `rejected(seat, name, args, reason)` | No corrió |
| señal `undone(seat, name, args)` | Se sacó |

### `GameCommands` (Node)

- **Inspector:** `game` (el nodo con las funciones; vacío = el padre), `keep_history` y `found_commands` (solo lectura: las jugadas que encontró, `place (can, undo), pass`; no se guarda en la escena).
- **Métodos:** los de `CommandLog`: `run`, `can_run`, `undo`, `can_undo`, `history`, `replay`, `is_replaying`, `size`, `clear`, `commands` y `has_command`.
- **Registro:** `command_log` es el `CommandLog` que muestra. `use_log(log)` muestra el de tus reglas, `use_own_log()` vuelve al propio (vacío) y `owns_log()` dice cuál es.
- **Señales:** `done`, `rejected` y `undone`, más `rebuilt` cuando pasa a mostrar otro log (`use_log` o `use_own_log`): volvé a leerlo.
- **Avisos del editor:** sin juego, el juego no tiene script, ningún `do_*`, un `do_x` sin parámetros (falta `seat`), un `can_x` o `undo_x` sin su `do_x` (casi seguro un typo), un `can_x` o `undo_x` con otra cantidad de parámetros que `do_x`, y un `can_x` que no devuelve `String`. No hace falta que tu juego sea `@tool`.

## Tips

- **Chequeos comunes a todas las jugadas.** Una sola función `can_run(seat: int, command: StringName, args: Array) -> String` en tu juego corre antes que el `can_<nombre>` de cada jugada: ahí va «¿es tu turno?», «¿terminó la partida?». El orden es siempre general → propio.
- **Las reglas usan `CommandLog`, no el nodo.** Guardalo con el estado de tu partida (`var commands := CommandLog.new(self)`) y mostralo en la escena con `$Commands.use_log(rules.commands)`. Así las reglas y el replay corren headless. `CommandLog` no mantiene vivo a su juego, así que no crea un ciclo de referencias; si el juego se libera, `run` avisa con un error (una vez) y devuelve `unknown_command`.
- **Partida repetible.** El azar con semilla vive en tu estado (un `RandomNumberGenerator` con su `seed`). Para reproducirla, armá un estado nuevo con la misma semilla, vaciá el historial con `clear()` y llamá a `replay(history)`: da lo mismo. Compará los dos estados con un `to_dict()` tuyo.
- **Jugadas que disparan jugadas.** Si un bot o un efecto automático responde a `done` mandando otra jugada, que no haga nada mientras `is_replaying()` sea true:

```gdscript
func _on_done(seat: int, _name: StringName, _args: Array) -> void:
	if commands.is_replaying():
		return
	if seat == human_seat:
		commands.run(bot_seat, &"place", [bot.choose_cell()])
```

  El chequeo va en el handler mismo, antes de cualquier `call_deferred` o `await`: una respuesta diferida lo leería con la repetición ya terminada y la mandaría igual.

- **Guardar en un archivo.** `JSON.stringify` convierte un `Vector2i` en el texto `"(1, 2)"` y la jugada ya no coincide con la firma. Guardá el historial con `var_to_str` / `str_to_var`, `var_to_bytes` / `bytes_to_var`, o `JSON.from_native` / `JSON.to_native`.
- **Motivos de rechazo.** Textos cortos (`"not_your_turn"`) que la pantalla traduce con `tr()`.
- **Red.** El kit no manda nada. Con MpKit, **el asiento nunca viaja**: el cliente manda el nombre y los argumentos, y el servidor pone el asiento de quien mandó (`sender_slot()`).

```gdscript
# cliente: un clic en una casilla
net.to_server(&"command", &"place", [cell])


# servidor (el MpActor): sender_slot() dice quién mandó
func mp_sv_command(command: StringName, args: Array) -> void:
	commands.run(net.sender_slot(), command, args)
```

  Es seguro porque solo corren las funciones `do_*` (una jugada que no existe se rechaza sola, sin correr nada), los argumentos se validan contra la firma (una jugada mal armada se rechaza sin errores) y el asiento lo pone el servidor, no el cliente. Los motivos que devuelve `run` sirven para avisarle al cliente por qué no.

## Migrar desde 0.1

| Antes (0.1) | Ahora (0.2) |
| --- | --- |
| Una subclase de `GameCommand` por orden | Tres funciones en tu juego: `do_<nombre>`, y opcionalmente `can_<nombre>` y `undo_<nombre>` |
| `command_type()`, `from_args()`, `args()` | Desaparecen: el nombre es el de la función y los argumentos son sus parámetros |
| `can_run(ctx) -> StringName` de la orden | `can_<nombre>(seat, args…) -> String`; `can_run(seat, command, args)` es el chequeo general |
| `run(ctx)` de la orden | `do_<nombre>(seat, args…)` |
| `can_undo()` y `undo(ctx)` de la orden | Existe `undo_<nombre>(seat, args…)` |
| `command.seat` | El primer parámetro, `seat`, de las tres funciones |
| `CommandLog.register(script)` | `CommandLog.new(game)` (o `log.game = juego`) |
| `log.run(cmd, ctx)` | `log.run(seat, &"place", [cell])` |
| Rechazo `StringName` | Rechazo `String` |
| `entries()` con `{type, seat, args: Dictionary}` | `history()` con `{name, seat, args: Array}` |
| `make(entry)` | No existe: `replay(history)` las corre directo |
| `last()` | No existe: `history()[-1]` |
| `keep_log` | `keep_history` |
| `CommandBus` con `commands` y `context` | `GameCommands` con `game` (vacío = el padre) |
| Señales `executed(cmd)`, `rejected(cmd, reason)`, `undone(cmd)` | `done(seat, name, args)`, `rejected(seat, name, args, reason)`, `undone(seat, name, args)` |
| `replay(entries, ctx)` | `replay(history)` |
| `NO_COMMAND`, `UNKNOWN_COMMAND` | `UNKNOWN_COMMAND`, y los nuevos `BAD_ARGUMENTS`, `NOT_ALLOWED` y `BUSY` |

El historial guardado con 0.1 (`{type, seat, args: Dictionary}`) no se lee en 0.2: convertilo a `{name, seat, args: Array}` con los argumentos en el orden de `do_<nombre>`.

## Tests

```bash
godot --headless --path commandkit_lab --script res://addons/command_kit/tests/command_test_runner.gd
```

Sale `COMMANDKIT TESTS PASS (n)`. Los tests cubren:

- Correr y rechazar con motivo, el chequeo general antes que el propio, las jugadas desconocidas (incluidos métodos nativos como `free` y `queue_free`), los argumentos de más, de menos, de otro tipo, con valor por defecto y las colecciones tipadas.
- El historial (copia profunda, formato, ida y vuelta con `var_to_str`), deshacer con y sin dato devuelto, `keep_history`, repetir sobre un estado con semilla, cortar en la primera mala, repetir con un listener que responde y sobre entradas mal formadas, la reentrada (`busy`), una `can_` que no devuelve texto y un juego que ya no existe.
- Un juego `Node`, un juego `RefCounted` y cambiar de juego.
- El nodo: `game` vacío = el padre, `use_log`, `rebuilt`, las señales, los avisos del editor y `found_commands`.
- El ejemplo jugado con sus botones.
- Que el addon no nombre a ningún otro kit.
