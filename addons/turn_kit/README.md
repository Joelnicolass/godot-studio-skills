# TurnKit

Turnos, rondas y ciclos para juegos de estrategia, de mesa, de cartas, tácticos o RPG por turnos. Hay dos niveles:

- **`TurnCycle`**: los turnos como datos puros (`RefCounted`, sin nodos ni escena). Sabe de quién es el turno, cuántas acciones le quedan, en qué ronda y en qué ciclo va la partida, y cuándo termina. Las reglas de tu juego lo usan directo y se testea headless.
- **Nodos para la escena**:
  - `TurnClock` arma o muestra un `TurnCycle` con los números del inspector.
  - `TurnSeat` es un jugador: un hijo del reloj por asiento.

TurnKit **no tiene** reglas de juego, bots, red ni autoload. Qué cuesta una acción o qué pasa al final de un ciclo lo decide tu juego, escuchando las señales.

## Instalar

```bash
./install.sh --addon /path/to/godot-project turn_kit
```

Habilitá el plugin **TurnKit** (tipos `TurnClock` y `TurnSeat` en Create Node).

## En 3 pasos

1. Agregá un `TurnClock` y elegí en el inspector `actions_per_turn`, `rounds_per_cycle` y `cycles` (0 = sin fin).
2. Agregale un hijo `TurnSeat` por jugador, en el orden en que juegan. El primero es el asiento 0.
3. Conectá las señales y gastá acciones:

```gdscript
@onready var turns: TurnClock = $Turns


func _ready() -> void:
	turns.turn_started.connect(_on_turn_started)
	turns.cycle_ended.connect(func(n: int) -> void: print("Termina la era ", n))


func _on_move_pressed() -> void:
	if turns.spend_action():
		move_unit()


func _on_end_pressed() -> void:
	turns.end_turn()
```

## Ejemplo mínimo

`examples/minimal/minimal.tscn` (F6): tres asientos (Ana, Beto y un bot). **Spend action** usa una acción y **End turn** pasa el turno. El bot pasa solo. Dos rondas hacen un ciclo, y la partida termina a los dos ciclos.

```
Minimal              # minimal.gd: muestra el estado y conecta los botones
├── Box              # estado, botones Spend action y End turn, registro
└── Turns            # TurnClock: rounds_per_cycle = 2, cycles = 2
    ├── Ana, Beto    # TurnSeat
    └── Bot          # TurnSeat: is_bot = true
```

## Cómo cuenta

- **Turno:** empieza con `actions_per_turn` acciones. `spend_action(n)` gasta `n`, y devuelve false sin cambiar nada si no alcanzan.
  - Gastar la última acción **no** cierra el turno. Lo cierra `end_turn()`, que también vale con acciones sin usar.
- **Ronda:** un turno de cada asiento activo, empezando por `first_seat`. Si ese asiento está inactivo, empieza el siguiente activo.
- **Ciclo:** `rounds_per_cycle` rondas (una era, un año). Con 0, las rondas se cuentan pero los ciclos no terminan.
- **Fin:** después de `cycles` ciclos. Con 0, la partida no termina. También termina si no queda ningún asiento activo.
- **Orden de las señales en `end_turn()`:** `turn_ended(seat)`, después `round_ended(n)`, `cycle_ended(n)` y `finished` si corresponden, y al final `turn_started(next)` si la partida sigue.
- **Asientos inactivos** (eliminados, desconectados): se saltean. Un asiento que vuelve a estar activo juega desde la ronda siguiente.
- **Determinismo:** no hay azar ni tiempo real. `to_dict()` y `TurnCycle.from_dict()` guardan el estado entero, a mitad de un turno incluido.

## API

### `TurnCycle` (RefCounted)

| Miembro | Qué hace |
| --- | --- |
| `TurnCycle.new(seats, actions_per_turn, rounds_per_cycle, cycles)` | Un ciclo de turnos. Todo es opcional (2, 3, 0, 0) |
| `seats`, `actions_per_turn`, `rounds_per_cycle`, `cycles`, `first_seat` | La configuración. Un cambio de acciones cuenta desde el turno siguiente y uno de `first_seat` desde la ronda siguiente |
| `start(first := -1)` | Empieza la ronda 1 del ciclo 1 |
| `spend_action(amount := 1) -> bool` | Gasta acciones del turno |
| `end_turn() -> bool` | Cierra el turno y empieza el siguiente |
| `set_seat_active(seat, active)`, `is_seat_active(seat)` | Saltear un asiento |
| `current_seat`, `actions_left`, `round_number`, `cycle_number`, `rounds_in_cycle`, `is_started`, `is_finished` | El estado. `current_seat` es -1 antes de empezar y después del fin |
| `round_order()` | Los asientos de la ronda actual, en orden |
| `to_dict()` / `TurnCycle.from_dict(data)` | Datos planos para guardar, mandar por red o comparar un replay |
| señales `turn_started(seat)`, `action_spent(left)`, `turn_ended(seat)`, `round_ended(n)`, `cycle_ended(n)`, `finished` | En pasado: ya ocurrió |

### `TurnClock` (Node)

- **Inspector:** `actions_per_turn`, `rounds_per_cycle`, `cycles`, `first_seat` y `autostart`.
  - `autostart` empieza solo el ciclo **propio** del reloj, cuando la escena está lista. Si lo apagás, llamá a `start()`.
- **Ciclo:** `turn_cycle` es el `TurnCycle` que muestra. `use_cycle(cycle)` muestra el de tus reglas en vez del propio y `use_own_cycle()` vuelve al del inspector. `owns_cycle()` dice cuál muestra.
  - Un ciclo de `use_cycle` **nunca se reinicia**: ni `autostart` ni `start()` lo vuelven a la ronda 1, así que uno cargado de un guardado sigue en su turno. Si todavía no empezó, `start()` lo empieza.
  - Con `use_cycle`, `TurnSeat.active` no toca los asientos de tus reglas: quién está activo lo deciden ellas.
- **Métodos:** `start()`, `spend_action()`, `end_turn()`, `set_seat_active()`, `seat_nodes()`, `seat_node(seat)` y `current_seat_node()`.
- **Estado:** `current_seat` y `actions_left`.
- **Señales:** las mismas de `TurnCycle`, más `rebuilt` cuando el reloj pasa a mostrar otro ciclo (`use_cycle`, `use_own_cycle` o `start()` del propio). Al recibirla, volvé a leer el estado.

### `TurnSeat` (Node, hijo de un `TurnClock`)

- **Inspector:** `display_name`, `is_bot` (TurnKit solo lo guarda; lo usa tu juego) y `active` (solo para el ciclo propio del reloj).
- **Métodos:** `index()` (su número de asiento) e `is_current()`.
- **Señales:** `turn_started` y `turn_ended`, solo de ese asiento. Sirven para un bot o el HUD de un jugador.

## Tips

- **Las reglas usan `TurnCycle`, no los nodos.** Guardalo en el estado de tu partida y mostralo con `clock.use_cycle(state.turns)`. Así las reglas corren headless y el HUD escucha las señales del reloj. Tus reglas lo empiezan (`state.turns.start()`), o llega ya empezado de un guardado.
- **Una fase de mantenimiento al final del ciclo:** escuchá `cycle_ended`. Llega antes del `turn_started` del ciclo nuevo, en la misma llamada a `end_turn()`. Si la fase necesita que el jugador elija algo, tu juego la resuelve antes de aceptar órdenes del turno nuevo.
- **Red:** el ciclo no sabe nada de red. Mandá `to_dict()` en el snapshot, o repetí las mismas órdenes en cada máquina.

## Tests

```bash
godot --headless --path turnkit_lab --script res://addons/turn_kit/tests/turn_test_runner.gd
```

Sale `TURNKIT TESTS PASS (n)`. Los tests cubren:

- Acciones, el orden de turnos y de señales, rondas, ciclos, el fin y el sin fin.
- `first_seat` (también negativo o fuera de rango), los asientos inactivos, quedarse sin asientos y `to_dict`.
- Los nodos: los asientos como hijos, las señales por asiento, `autostart`, `use_cycle` sin reinicio (con un ciclo empezado y con uno de `from_dict`), `rebuilt` y los avisos del editor.
- El ejemplo jugado con los botones.
- Que el addon no nombre a ningún otro kit.
