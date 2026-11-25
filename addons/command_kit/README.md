# CommandKit

Órdenes validadas con registro, para juegos por turnos, puzzles con deshacer, editores o multijugador por órdenes. Hay dos niveles:

- **`GameCommand` y `CommandLog`**: las órdenes y su registro como datos puros (`RefCounted`, sin nodos ni escena). Una orden dice si puede correr y qué hace. El registro corre solo las válidas, guarda las aceptadas como `{type, seat, args}`, deshace la última y repite una partida entera. Las reglas de tu juego lo usan directo y se testea headless.
- **`CommandBus`** (Node): arma o muestra un `CommandLog` con los tipos de orden elegidos en el inspector.

CommandKit **no tiene** reglas de juego, azar, red ni autoload. El estado de la partida (`ctx`) es tuyo: el kit nunca mira adentro. El azar vive en tu estado (un `RandomNumberGenerator` con la semilla de la partida), así que repetir el registro sobre un estado nuevo con la misma semilla da el mismo resultado.

## Instalar

```bash
./install.sh --addon /path/to/godot-project command_kit
```

Habilitá el plugin **CommandKit** (tipo `CommandBus` en Create Node).

## En 3 pasos

1. Escribí una orden por cosa que el jugador puede hacer, extendiendo `GameCommand`:

```gdscript
class_name MoveUnit
extends GameCommand

var unit_id := 0
var to := Vector2i.ZERO


static func command_type() -> StringName:
	return &"move_unit"


static func from_args(data: Dictionary) -> GameCommand:
	var command := MoveUnit.new()
	command.unit_id = int(data.get("unit_id", 0))
	command.to = data.get("to", Vector2i.ZERO)
	return command


func args() -> Dictionary:
	return {"unit_id": unit_id, "to": to}


func can_run(ctx: Variant) -> StringName:
	if not ctx.has_unit(unit_id):
		return &"unknown_unit"
	return &""


func run(ctx: Variant) -> void:
	ctx.move(unit_id, to)
```

2. Agregá un `CommandBus` y poné el script en `commands`.
3. Corré las órdenes y escuchá los rechazos:

```gdscript
@onready var bus: CommandBus = $Commands


func _ready() -> void:
	bus.context = match_state
	bus.rejected.connect(func(_cmd: GameCommand, why: StringName) -> void: hud.say(tr(why)))


func _on_cell_clicked(cell: Vector2i) -> void:
	var move := MoveUnit.new()
	move.unit_id = selected
	move.to = cell
	move.seat = local_seat
	bus.run(move)
```

## Ejemplo mínimo

`examples/minimal/minimal.tscn` (F6): dos jugadores ponen fichas (X y O) por turnos en un tablero de 5 × 5. Cada clic es una orden `place_stone`. Una casilla ocupada se rechaza y se ve el motivo. **Undo** saca la última ficha y **Replay** vacía el tablero y repite el registro ficha por ficha.

```
Minimal          # minimal.gd: el estado, el tablero de botones, Undo y Replay
├── Box          # estado, tablero, botones Undo y Replay
└── Commands     # CommandBus: commands = [place_stone.gd]
```

## Cómo funciona

- **Una orden** define:
  - `static command_type()`: su nombre en el registro, único.
  - `static from_args(args)`: la arma de nuevo a partir de sus datos.
  - `args()`: sus datos, solo valores planos (números, textos, `StringName`, vectores, arrays, diccionarios).
  - `can_run(ctx)`: `&""` si puede correr, o el código de rechazo. No cambia `ctx`.
  - `run(ctx)`.
  - Si se puede deshacer: `can_undo()` devuelve true y `undo(ctx)` la saca. Por defecto no se puede, porque una tirada de dados o una carta revelada no se devuelven.
  - `seat`: quién la mandó. Lo pone tu juego y queda en el registro.
- **Correr:** `run(cmd, ctx)` llama a `can_run` y, si da `&""`, a `run`.
  - La orden aceptada entra al registro y se emite `executed`.
  - La rechazada emite `rejected(cmd, reason)` y no deja rastro.
- **Registro:** `entries()` devuelve un `{type, seat, args}` por orden aceptada, de la más vieja a la más nueva. Sirve para guardar, mandar por red o comparar.
- **Deshacer:** `undo(ctx)` saca la última orden del registro si se puede deshacer, y emite `undone`. Solo la última: si la última no se puede deshacer, las anteriores tampoco.
- **Repetir:** `replay(entries, ctx)` arma cada orden con `make` y la corre.
  - Se detiene en la primera que no corre y devuelve su código, o `UNKNOWN_COMMAND` si el tipo no está registrado.
  - Las órdenes repetidas se agregan al final del registro. Sobre un registro vacío (llamá a `clear()` antes), una repetición completa lo deja igual al original.
  - Mientras corre, `is_replaying()` es true. Un listener que manda órdenes propias (un bot, un efecto automático) no manda nada en ese momento, porque sus órdenes ya están en el registro y se repetirían dos veces.

## API

### `GameCommand` (RefCounted)

| Miembro | Qué hace |
| --- | --- |
| `static command_type() -> StringName` | El tipo en el registro |
| `static from_args(args) -> GameCommand` | La orden a partir de sus datos |
| `args() -> Dictionary` | Sus datos |
| `can_run(ctx) -> StringName` | `&""` = puede correr; si no, el código de rechazo |
| `run(ctx)`, `can_undo()`, `undo(ctx)` | Hacerla y deshacerla |
| `seat`, `type()`, `to_dict()` | Quién la mandó, su tipo y su entrada en el registro |

### `CommandLog` (RefCounted)

| Miembro | Qué hace |
| --- | --- |
| `register(script) -> bool`, `has_type(type)`, `types()` | Los tipos de orden que sabe armar |
| `run(cmd, ctx) -> StringName` | Corre una orden válida y la registra |
| `can_undo()`, `undo(ctx) -> bool` | Deshace la última |
| `replay(entries, ctx) -> StringName`, `is_replaying()` | Repite un registro; `is_replaying()` es true mientras corre |
| `make(entry)`, `entries()`, `last()`, `size()`, `clear()` | El registro |
| `keep_log` | Apagado: las órdenes corren y emiten, pero no se guardan |
| `UNKNOWN_COMMAND`, `NO_COMMAND` | Códigos propios del kit |
| señales `executed(cmd)`, `rejected(cmd, reason)`, `undone(cmd)` | En pasado: ya ocurrió |

### `CommandBus` (Node)

- **Inspector:** `commands` (los scripts de orden que sabe armar) y `keep_log`.
- **Contexto:** `context` es el `ctx` que se usa cuando `run`, `undo` o `replay` no reciben uno. Normalmente es el estado de tu partida.
- **Registro:** `command_log` es el `CommandLog` que muestra. `use_log(log)` muestra el de tus reglas y `use_own_log()` vuelve al propio, vacío.
- **Métodos:** `run`, `can_undo`, `undo`, `replay`, `is_replaying`, `make`, `entries`, `size` y `clear`, con el `ctx` opcional. Lo demás (`register`, `has_type`, `types`, `last`) va por `command_log`.
- **Señales:** las mismas de `CommandLog`, más `rebuilt` cuando pasa a mostrar otro registro (`use_log`, `use_own_log` o `commands` nuevos).
- **Avisos del editor:** un lugar vacío en `commands`, un script que no extiende `GameCommand`, uno sin `command_type()` y dos con el mismo tipo.

## Tips

- **Las reglas usan `CommandLog`, no el nodo.** Guardalo con el estado de tu partida y mostralo con `bus.use_log(rules.commands)`. Así las reglas y el replay corren headless.
- **Partida repetible:** el estado guarda su semilla y su RNG. Para reproducirla, armá un estado nuevo con la misma semilla, vaciá el registro con `clear()` y llamá a `replay(entries)`. Compará los dos estados con un `to_dict()` tuyo.
- **Órdenes que disparan órdenes:** si un bot o un efecto automático responde a `executed` (o a un `turn_started`) mandando otra orden, que no haga nada mientras `is_replaying()` sea true:

```gdscript
func _on_executed(command: GameCommand) -> void:
	if bus.is_replaying():
		return
	if command.seat == human_seat:
		bus.run(bot.answer(command))
```

  El chequeo va en el handler mismo, antes de cualquier `call_deferred` o `await`: una respuesta diferida lo leería con la repetición ya terminada y la mandaría igual.

- **Guardar en un archivo:** `JSON.stringify` convierte un `Vector2i` en el texto `"(1, 2)"` y la orden ya no se arma igual. Guardá el registro con `var_to_str` / `str_to_var`, `var_to_bytes` / `bytes_to_var`, o `JSON.from_native` / `JSON.to_native`.
- **Red:** el kit no manda nada. Con MpKit, el cliente manda los datos de la orden (`to_dict()`) al servidor, y el servidor la arma con `make()` y la corre: el servidor valida, y si la acepta la reparte. **El servidor nunca confía en el `seat` que manda el cliente:** lo pisa con el de quien mandó, y descarta una entrada de tipo desconocido.

```gdscript
func mp_sv_command(entry: Dictionary) -> void:
	var command := bus.make(entry)
	if command == null:
		return  # tipo desconocido: no se corre
	command.seat = net.sender_slot()  # quién mandó, no lo que dice la entrada
	bus.run(command)
```
- **Códigos de rechazo:** usá `StringName` cortos (`&"not_your_turn"`) y traducilos en la UI con `tr()`.

## Tests

```bash
godot --headless --path commandkit_lab --script res://addons/command_kit/tests/command_test_runner.gd
```

Sale `COMMANDKIT TESTS PASS (n)`. Los tests cubren:

- Correr y rechazar, el formato del registro, deshacer, repetir sobre un estado con semilla, cortar la repetición en una entrada mala, repetir con un listener que responde (`is_replaying`), repetir sobre un registro no vacío, `make`, `register` y `keep_log`.
- El nodo: los tipos desde el inspector, el contexto, las señales, la repetición, `use_log`, `rebuilt` y los avisos del editor.
- El ejemplo jugado con sus botones.
- Que el addon no nombre a ningún otro kit.
