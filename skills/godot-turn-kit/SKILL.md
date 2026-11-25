---
name: godot-turn-kit
description: >-
  Turnos para un juego Godot 4 con el addon TurnKit: de quién es el turno, cuántas
  acciones le quedan, fases dentro del turno (robar, jugar, descartar), tiempo por
  turno, rondas, ciclos (eras, años), el fin de la partida, un jugador inicial que
  rota, un orden de ronda propio (iniciativa) y asientos que se saltean. Un
  TurnCycle en datos puros que las reglas usan directo y un TurnClock en la
  escena con un TurnSeat por jugador. Usar cuando el usuario quiere turnos,
  rondas, fases de turno, un límite de tiempo por turno, iniciativa, estrategia
  o juegos de mesa o de cartas por turnos, un RPG táctico, quién juega ahora o
  /add-turns. No son las reglas del juego (qué cuesta una acción, qué hace una
  fase), ni los bots, ni la red.
---

# Godot — turnos (TurnKit)

Addon `addons/turn_kit/` en el proyecto del **juego**. Referencia: `addons/turn_kit/README.md`.

Si el addon no está:

```bash
./install.sh --addon /path/to/godot-project turn_kit
```

Habilitá el plugin **TurnKit** (tipos `TurnClock` y `TurnSeat` en Create Node). Pedido acotado: `/add-turns`. Composición: [godot-composition-first](../godot-composition-first/SKILL.md).

## Reglas

- **Los turnos son datos.** `TurnCycle` es un `RefCounted` sin nodos ni reloj: el juego lo guarda en su estado y sus reglas lo usan directo (se testea headless). `TurnClock` lo arma desde el inspector o muestra el de las reglas con `use_cycle`.
- **Un `use_cycle` nunca se reinicia.** Ni `autostart` ni `start()` lo vuelven a la ronda 1, y los valores del inspector y `TurnSeat.active` no lo tocan: lo manda el juego.
- **Todo lo nuevo es opcional.** Fases, tiempo, jugador inicial que rota y orden propio vienen apagados. No los prendas si el juego no los pide.
- **Fases del turno.** `phases` en el inspector; `next_phase()` pasa a la siguiente y en la última cierra el turno. `end_turn()` cierra desde cualquier fase. Las acciones son del turno, no de la fase.
- **El tiempo entra por `tick(delta)`.** El núcleo no lee el reloj: el `TurnClock` hace `tick` cada cuadro (`advance_time`), nunca en el editor. En un juego en red, los clientes apagan `advance_time` y el servidor manda `to_dict()`.
- **Iniciativa.** En `round_ended`, `set_round_order([...])` con el orden que calculan las reglas: vale para la ronda que está por empezar.
- **Señales en pasado, en orden fijo.** Al cerrar un turno: `phase_ended` → `turn_ended` → `round_ended` / `cycle_ended` / `finished` → `turn_started` → `phase_started`. El tiempo agotado: `turn_timed_out` y recién después se cierra el turno.
- **Un bot que pasa solo** cierra su turno con `end_turn.call_deferred()`.
- **Sin límite de acciones:** no llames a `spend_action`.
- **Ningún kit depende de otro.** TurnKit no sabe de red, bots ni cartas: el juego conecta.

## Árbol

```
Game
├── Turns (TurnClock)        # actions_per_turn, phases, turn_seconds, first_seat_rotates, rounds_per_cycle, cycles
│   ├── Ana (TurnSeat)       # display_name; asiento 0
│   ├── Beto (TurnSeat)      # asiento 1
│   └── Bot (TurnSeat)       # is_bot: lo usa el juego
└── Hud                      # escucha las señales del reloj
```

Arrancá desde `addons/turn_kit/examples/minimal/minimal.tscn`: tres asientos, fases, 10 segundos por turno y un jugador inicial que rota.

## Qué va dónde

| Kit | Juego |
|---|---|
| De quién es el turno, fases, acciones que quedan, tiempo | Qué cuesta una acción, qué se hace en cada fase |
| Rondas, ciclos, el fin, quién abre la ronda | Qué pasa al final de una ronda o de un ciclo (mantenimiento, ingresos) |
| El orden de ronda que le pasan | Cómo se calcula la iniciativa |
| Asientos activos e inactivos | Quién queda eliminado |
| `to_dict()` / `from_dict()` | Guardar, mandar por red, el servidor que hace `tick` |

## API esencial

- `TurnCycle.new(seats, actions_per_turn := 1, rounds_per_cycle := 0, cycles := 0)`; `phases`, `turn_seconds`, `timeout_ends_turn`, `first_seat`, `first_seat_rotates`.
- `start()`, `spend_action(n)`, `next_phase()`, `end_turn()`, `tick(delta)`, `set_round_order(order)`, `set_seat_active(seat, active)`.
- Estado: `current_seat`, `actions_left`, `current_phase`, `time_left`, `round_number`, `cycle_number`, `round_first_seat`, `is_finished`.
- Señales: `turn_started`, `phase_started`, `phase_ended`, `action_spent`, `turn_timed_out`, `turn_ended`, `round_ended`, `cycle_ended`, `finished`.
- `TurnClock`: lo mismo con el inspector (grupos Turn, Round, Phases, Time), `use_cycle(cycle)`, `use_own_cycle()`, `rebuilt`.

## Listo cuando

- El `TurnClock` no muestra avisos y cada jugador es un `TurnSeat` hijo, en orden.
- F6: los turnos pasan en el orden esperado, las fases y el tiempo (si se usan) se ven en el HUD y el turno pasa solo al agotarse el tiempo.
- La partida termina cuando tiene que (ciclos o sin asientos activos).
- `godot --headless --path turnkit_lab --script res://addons/turn_kit/tests/turn_test_runner.gd` da `TURNKIT TESTS PASS` (en el repo del kit).

## Antipatrones

- Escribir las reglas del juego dentro de los nodos del kit: van en `TurnCycle` y en tus señales.
- Leer el reloj del sistema para el tiempo del turno: usá `tick(delta)` con un paso que decidas.
- Reiniciar un ciclo que viene de un guardado: `use_cycle` lo muestra tal cual.
- Cerrar el turno de un bot en la misma llamada de `turn_started`: usá `call_deferred`.
- Mantener el tiempo a mano en el juego cuando `turn_seconds` y `tick` ya lo hacen.
