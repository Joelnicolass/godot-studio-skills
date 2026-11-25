# <img src="icons/turn_kit.svg" width="32" height="32" alt=""> TurnKit

Turnos, rondas y ciclos para juegos de estrategia, de mesa, de cartas, tácticos o RPG por turnos. Hay dos niveles:

- **`TurnCycle`**: los turnos como datos puros (`RefCounted`, sin nodos, sin escena y sin leer el reloj). Sabe de quién es el turno, cuántas acciones le quedan, en qué fase y con cuánto tiempo, en qué ronda y en qué ciclo va la partida, y cuándo termina. Las reglas de tu juego lo usan directo y se testea headless.
- **Nodos para la escena**:
  - `TurnClock` arma o muestra un `TurnCycle` con los números del inspector.
  - `TurnSeat` es un jugador: un hijo del reloj por asiento.

Todo lo que no es "un turno por asiento" es opcional y viene apagado: jugador inicial que rota, fases dentro del turno, tiempo por turno y un orden de ronda propio (iniciativa). Un juego que no lo usa no ve nada nuevo.

TurnKit **no tiene** reglas de juego, bots, red ni autoload. Qué cuesta una acción, qué se hace en cada fase o qué pasa al final de un ciclo lo decide tu juego, escuchando las señales.

## Instalar

```bash
./install.sh --addon /path/to/godot-project turn_kit
```

Habilitá el plugin **TurnKit** (tipos `TurnClock` y `TurnSeat` en Create Node).

## En 3 pasos

1. Agregá un `TurnClock` y elegí en el inspector `actions_per_turn`, `rounds_per_cycle` y `cycles` (0 = sin fin). Si querés fases, tiempo o un jugador inicial que rota, están en los grupos Round, Phases y Time.
2. Agregale un hijo `TurnSeat` por jugador, en el orden en que juegan. El primero es el asiento 0.
3. Conectá las señales y gastá acciones. Cada jugador mueve gastando acciones en su turno, y el juego se entera de cuándo empieza un turno y de cuándo termina una era:

```gdscript
@onready var turns: TurnClock = %Turns


func _ready() -> void:
	turns.turn_started.connect(_on_turn_started)
	turns.cycle_ended.connect(func(n: int) -> void: print("Termina la era ", n))


func _on_move_pressed() -> void:
	if turns.spend_action():
		move_unit()


func _on_end_pressed() -> void:
	turns.end_turn()
```

Con fases y tiempo, el juego se entera de cada fase nueva y de cuándo a un jugador se le acaba el tiempo:

```gdscript
turns.phase_started.connect(func(phase: StringName) -> void: print("Fase ", phase))
turns.turn_timed_out.connect(func(seat: int) -> void: print("Se le acabó el tiempo al asiento ", seat))
turns.next_phase()  # en la última fase cierra el turno
```

## Ejemplo mínimo

`examples/minimal/minimal.tscn` (F6): tres asientos (Ana, Beto y un bot). Cada turno tiene dos fases (`draw`, `play`) y 10 segundos. **Spend action** usa una acción, **Next phase** pasa a la fase siguiente (en la última cierra el turno) y **End turn** pasa el turno. Si el tiempo se acaba, el turno pasa solo y el registro lo dice. Cada ronda la abre el asiento siguiente, y el registro dice quién. El bot pasa solo. Dos rondas hacen un ciclo, y la partida termina a los dos ciclos.

```
Minimal              # minimal.gd: muestra el estado y conecta los botones
├── Box              # estado con fase y tiempo, botones Spend action, Next phase y End turn, registro
└── %Turns           # TurnClock: rounds_per_cycle = 2, cycles = 2, first_seat_rotates, phases = [draw, play], turn_seconds = 10
    ├── Ana, Beto    # TurnSeat
    └── Bot          # TurnSeat: is_bot = true
```

## Cómo cuenta

- **Turno:** empieza con `actions_per_turn` acciones (1 por defecto). `spend_action(n)` gasta `n`, y devuelve false sin cambiar nada si no alcanzan.
  - Gastar la última acción **no** cierra el turno. Lo cierra `end_turn()`, que también vale con acciones sin usar.
  - Las acciones son del turno entero, no de una fase. Si tu juego no limita las acciones, no llames a `spend_action`.
- **Fases (opcional):** `phases = [draw, play]`. Cada turno empieza en la primera. `next_phase()` pasa a la siguiente y, en la última, cierra el turno como `end_turn()`. `end_turn()` cierra el turno desde cualquier fase. Sin fases, `next_phase()` es `end_turn()`. Un cambio de `phases` cuenta desde el turno siguiente. `current_phase` es `&""` sin fases o sin turno.
- **Tiempo (opcional):** `turn_seconds > 0` carga `time_left` al empezar cada turno. `tick(delta)` lo baja. Al llegar a 0 emite `turn_timed_out(seat)` **una vez** por turno y, con `timeout_ends_turn`, cierra el turno (si lo apagás, el turno sigue y solo avisa). Lo que sobra del `delta` se pierde: no pasa al turno siguiente. Un cambio de `turn_seconds` cuenta desde el turno siguiente. `tick` no hace nada sin turno en juego, con `turn_seconds` 0, con `delta` <= 0 ni después de agotado el tiempo.
- **Ronda:** un turno de cada asiento activo, empezando por `first_seat`. Si ese asiento está inactivo, empieza el siguiente activo.
  - **Jugador inicial que rota:** con `first_seat_rotates`, cada ronda la abre el asiento siguiente al que abrió la anterior (0, 1, 2, 0…; si está inactivo, el siguiente activo). `round_first_seat` dice quién abrió la ronda actual (-1 antes de empezar).
  - **Orden propio (iniciativa):** `set_round_order([2, 0, 1])` fija el orden desde la **próxima** ronda. No hace falta listar todos: los que no están no juegan esas rondas. Los inactivos se saltean. Un asiento que no existe o repetido no cambia nada. `set_round_order([])` vuelve al orden por asiento. Mientras haya un orden propio, `first_seat` y la rotación no aplican. Llamado desde `round_ended`, cuenta para la ronda que está por empezar.
- **Ciclo:** `rounds_per_cycle` rondas (una era, un año). Con 0, las rondas se cuentan pero los ciclos no terminan.
- **Fin:** después de `cycles` ciclos. Con 0, la partida no termina. También termina si no queda ningún asiento activo.
- **Orden de las señales al cerrar un turno:** `phase_ended(actual)` (con fases), `turn_ended(seat)`, después `round_ended(n)`, `cycle_ended(n)` y `finished` si corresponden, y al final `turn_started(next)` y `phase_started(primera)` si la partida sigue. Dentro del turno: `phase_ended(x)` → `phase_started(y)` en cada `next_phase()`. El tiempo agotado emite `turn_timed_out(seat)` y recién después cierra el turno.
- **Asientos inactivos** (eliminados, desconectados): se saltean. Un asiento que vuelve a estar activo juega desde la ronda siguiente.
- **Determinismo:** no hay azar ni reloj del sistema: el tiempo entra por `tick(delta)`, así que quien lo llama decide el paso (con un paso fijo, dos máquinas dan lo mismo). `to_dict()` y `TurnCycle.from_dict()` guardan el estado entero, a mitad de un turno, de una fase o con el tiempo corriendo.

## API

### `TurnCycle` (RefCounted)

| Miembro | Qué hace |
| --- | --- |
| `TurnCycle.new(seats, actions_per_turn, rounds_per_cycle, cycles)` | Un ciclo de turnos. Todo es opcional (2, 1, 0, 0) |
| `seats`, `actions_per_turn`, `rounds_per_cycle`, `cycles`, `first_seat` | La configuración. Un cambio de acciones cuenta desde el turno siguiente y uno de `first_seat` desde la ronda siguiente |
| `first_seat_rotates` | Cada ronda la abre el asiento siguiente al que abrió la anterior (apagado por defecto) |
| `phases: Array[StringName]` | Las fases de un turno (vacío = sin fases). Un cambio cuenta desde el turno siguiente |
| `turn_seconds`, `timeout_ends_turn` | Segundos por turno (0 = sin tiempo) y si al agotarse el turno pasa solo (sí por defecto) |
| `start(first := -1)` | Empieza la ronda 1 del ciclo 1 |
| `spend_action(amount := 1) -> bool` | Gasta acciones del turno |
| `next_phase() -> bool` | Pasa a la fase siguiente; en la última (o sin fases) cierra el turno |
| `end_turn() -> bool` | Cierra el turno, desde cualquier fase, y empieza el siguiente |
| `tick(delta)` | Deja pasar `delta` segundos del turno. Al llegar a 0: `turn_timed_out` y, con `timeout_ends_turn`, cierra el turno |
| `set_round_order(order: Array[int])`, `custom_round_order()` | Orden propio desde la próxima ronda; `[]` lo borra. `custom_round_order()` devuelve una copia |
| `set_seat_active(seat, active)`, `is_seat_active(seat)` | Saltear un asiento |
| `current_seat`, `actions_left`, `current_phase`, `phase_index`, `time_left`, `round_number`, `cycle_number`, `rounds_in_cycle`, `round_first_seat`, `is_started`, `is_finished` | El estado. `current_seat` es -1 antes de empezar y después del fin |
| `round_order()` | Los asientos de la ronda actual, en orden |
| `to_dict()` / `TurnCycle.from_dict(data)` | Datos planos para guardar, mandar por red o comparar un replay. `from_dict` lee también los de 0.2 |
| señales `turn_started(seat)`, `phase_started(phase)`, `phase_ended(phase)`, `action_spent(left)`, `turn_timed_out(seat)`, `turn_ended(seat)`, `round_ended(n)`, `cycle_ended(n)`, `finished` | En pasado: ya ocurrió |

### `TurnClock` (Node)

- **Inspector**, en grupos:
  - Turn: `actions_per_turn` (1 por defecto) y `autostart`.
  - Round: `rounds_per_cycle`, `cycles`, `first_seat` y `first_seat_rotates`.
  - Phases: `phases`.
  - Time: `turn_seconds`, `timeout_ends_turn` y `advance_time`.
  - `autostart` empieza solo el ciclo **propio** del reloj, cuando la escena está lista. Si lo apagás, llamá a `start()`.
  - Los valores del inspector se aplican al ciclo **propio**, también en vivo. Nunca a uno de `use_cycle`.
- **Tiempo:** con `advance_time` (por defecto), el reloj llama a `tick(delta)` en cada cuadro, nunca en el editor. Apagalo si tus reglas, o el servidor, llaman a `tick()`.
- **Ciclo:** `turn_cycle` es el `TurnCycle` que muestra. `use_cycle(cycle)` muestra el de tus reglas en vez del propio y `use_own_cycle()` vuelve al del inspector. `owns_cycle()` dice cuál muestra.
  - Un ciclo de `use_cycle` **nunca se reinicia**: ni `autostart` ni `start()` lo vuelven a la ronda 1, así que uno cargado de un guardado sigue en su turno. Si todavía no empezó, `start()` lo empieza.
  - Con `use_cycle`, `TurnSeat.active` no toca los asientos de tus reglas: quién está activo lo deciden ellas.
- **Métodos:** `start()`, `spend_action()`, `next_phase()`, `end_turn()`, `tick(delta)`, `set_round_order(order)`, `set_seat_active()`, `seat_nodes()`, `seat_node(seat)` y `current_seat_node()`.
- **Estado:** `current_seat`, `actions_left`, `current_phase` y `time_left`.
- **Señales:** las mismas de `TurnCycle`, más `rebuilt` cuando el reloj pasa a mostrar otro ciclo (`use_cycle`, `use_own_cycle` o `start()` del propio). Al recibirla, volvé a leer el estado.
- **Avisos del editor:** sin `TurnSeat` hijos, `first_seat` más allá del último asiento, y una fase con nombre vacío o repetido.

### `TurnSeat` (Node, hijo de un `TurnClock`)

- **Inspector:** `display_name`, `is_bot` (TurnKit solo lo guarda; lo usa tu juego) y `active` (solo para el ciclo propio del reloj).
- **Métodos:** `index()` (su número de asiento) e `is_current()`.
- **Señales:** `turn_started` y `turn_ended`, solo de ese asiento. Sirven para un bot o el HUD de un jugador.

## Migrar desde 0.2

| Antes (0.2) | Ahora (0.3) |
| --- | --- |
| `actions_per_turn` valía 3 por defecto | Vale **1**. Una escena que dependía del 3 lo tiene que poner en el inspector (un valor por defecto no se guarda en el `.tscn`), y `TurnCycle.new()` pasa `actions` si lo necesita |
| `to_dict()` con las claves del ciclo | Suma `first_seat_rotates`, `round_first_seat`, `custom_order`, `phases`, `turn_phases`, `phase_index`, `turn_seconds`, `time_left`, `timeout_ends_turn` y `timed_out`. `from_dict` sigue leyendo los de 0.2 |
| El reloj no tenía tiempo | `TurnClock` hace `tick` solo (`advance_time`). Con `turn_seconds` en 0 no pasa nada |
| Todo lo demás | Igual: señales, `use_cycle`, `rebuilt`, `TurnSeat` |

## Tips

- **Las reglas usan `TurnCycle`, no los nodos.** Guardalo en el estado de tu partida y mostralo con `clock.use_cycle(state.turns)`. Así las reglas corren headless y el HUD escucha las señales del reloj. Tus reglas lo empiezan (`state.turns.start()`), o llega ya empezado de un guardado.
- **Una fase de mantenimiento al final del ciclo:** escuchá `cycle_ended`. Llega antes del `turn_started` del ciclo nuevo, en la misma llamada a `end_turn()`. Si la fase necesita que el jugador elija algo, tu juego la resuelve antes de aceptar órdenes del turno nuevo.
- **Iniciativa:** ordená los asientos al final de cada ronda. En `round_ended` llamá a `set_round_order(...)` con los asientos según la iniciativa que tiran o calculan tus reglas: vale para la ronda que está por empezar.
- **Sin límite de acciones:** no llames a `spend_action`. `actions_left` queda en `actions_per_turn` y el turno lo cierra `end_turn()` (o `next_phase()` en la última fase).
- **Un bot que pasa solo:** cerrá su turno desde `turn_started` con `end_turn.call_deferred()`: así el turno se ve entero (`phase_started` incluido) antes de cerrar. Cerrarlo en la misma llamada también es válido: ese turno no emite señales de fase.
- **Red:** el ciclo no sabe nada de red. Mandá `to_dict()` en el snapshot, o repetí las mismas órdenes en cada máquina. El tiempo entra por `tick(delta)`: en el servidor, mostrá el ciclo con `use_cycle` y mandá el `to_dict()`. En los clientes **apagá `advance_time`** para que no corran un reloj propio, y mostrá el ciclo que llega de cada snapshot.

## Tests

```bash
godot --headless --path turnkit_lab --script res://addons/turn_kit/tests/turn_test_runner.gd
```

Sale `TURNKIT TESTS PASS (n)`. Los tests cubren:

- Acciones (1 por defecto), el orden de turnos y de señales, rondas, ciclos, el fin y el sin fin.
- `first_seat` (también negativo o fuera de rango), el jugador inicial que rota (con asientos inactivos y otro `first_seat`), el orden propio (desde la próxima ronda, desde `round_ended`, parcial, inválido, vacío), los asientos inactivos y quedarse sin asientos.
- Fases: el orden exacto de las señales, `next_phase` en la última y sin fases, `end_turn` a mitad de fase y un cambio de `phases` a mitad de turno.
- Tiempo: `tick` parcial, exacto, pasado de largo, una sola vez, con y sin `timeout_ends_turn`, recarga en el turno siguiente, antes de empezar y después del fin.
- `to_dict` / `from_dict` con todo el estado nuevo (a mitad de turno, de fase y con el tiempo corriendo, siguiendo igual en el original y en la copia) y con un dict de 0.2.
- Los nodos: los asientos como hijos, los valores del inspector en el ciclo propio y en vivo, las señales por asiento y las reenviadas, `autostart`, `use_cycle` sin reinicio ni pisado, `advance_time` y `_process`, `rebuilt` y los avisos del editor.
- El ejemplo jugado con los botones y el tiempo empujado a mano.
- Que el addon no nombre a ningún otro kit.
