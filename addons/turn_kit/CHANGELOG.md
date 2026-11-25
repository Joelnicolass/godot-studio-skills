# Cambios de TurnKit

## 0.3.1

- **Iconos propios en el editor:** cada nodo y recurso del kit tiene el suyo, del color del kit: se ven en el árbol de escena, en «Agregar nodo» y en el FileSystem.

Nada que actualizar en tu proyecto.

## 0.3.0

Todo lo nuevo es opcional y viene apagado: un juego que no lo usa no ve nada nuevo.

- Nuevo: **jugador inicial que rota** (`first_seat_rotates`, `round_first_seat`): cada ronda la abre el asiento siguiente al que abrió la anterior.
- Nuevo: **orden propio de ronda** (iniciativa): `set_round_order(order)` y `custom_round_order()`. Vale desde la próxima ronda (llamado desde `round_ended`, para la que está por empezar); `[]` vuelve al orden por asiento.
- Nuevo: **fases dentro del turno** (`phases`, `current_phase`, `phase_index`, `next_phase()`) y las señales `phase_started` y `phase_ended`. Las acciones siguen siendo del turno entero.
- Nuevo: **tiempo por turno** (`turn_seconds`, `time_left`, `timeout_ends_turn`, `tick(delta)`) y la señal `turn_timed_out`. El núcleo no lee el reloj del sistema: el tiempo entra por `tick`.
- `TurnClock`: propiedades del inspector nuevas en grupos (Turn, Round, Phases, Time), `advance_time` (el reloj hace `tick` en cada cuadro, nunca en el editor), métodos `next_phase()`, `set_round_order()` y `tick()`, propiedades `current_phase` y `time_left`, las señales nuevas reenviadas y avisos para una fase con nombre vacío o repetido. Los valores nuevos se aplican al ciclo propio (también en vivo), nunca a uno de `use_cycle`.
- `to_dict()` / `from_dict()` guardan todo el estado nuevo; `from_dict` sigue leyendo los de 0.2.
- Cambio: `actions_per_turn` vale **1** por defecto (era 3), en `TurnCycle.new` y en `TurnClock`. Una escena que dependía del 3 lo tiene que poner en el inspector.
- Ejemplo `minimal`: fases (`draw`, `play`) con el botón **Next phase**, 10 segundos por turno con el tiempo en el estado, y el jugador inicial que rota.
- README: "Cómo cuenta" con fases, tiempo, ronda y el orden completo de señales; tips de iniciativa, sin límite de acciones y red; "Migrar desde 0.2".
- Tests nuevos para cada caso (48 en total), y `test_independence` con los nombres finales de las clases de los otros kits.
- Nuevo: skill `godot-turn-kit` y command `/add-turns`.

## 0.2.0

- Arreglo: `autostart` y `start()` ya no reinician un ciclo mostrado con `use_cycle`. Un ciclo empezado o restaurado con `from_dict` sigue en su turno, y `start()` solo lo empieza si no había empezado.
- Arreglo: con `use_cycle`, `TurnSeat.active` ya no pisa los asientos activos de tus reglas.
- Nuevo: señal `rebuilt` en `TurnClock` cuando pasa a mostrar otro ciclo, y `owns_cycle()`.
- `TurnCycle`: `first_seat` negativo o fuera de rango da la vuelta (`posmod`), y quedarse sin asientos termina la partida sin dividir por cero.
- README: la partida **sí** termina sin asientos activos, y los botones del ejemplo se nombran como en pantalla.

## 0.1.0

Primera versión:

- `TurnCycle`: turnos, rondas y ciclos como datos puros. Acciones por turno, ronda desde `first_seat`, ciclos y fin configurables (0 = sin fin), asientos inactivos, señales en un orden fijo y `to_dict` / `from_dict`.
- `TurnClock`: arma el ciclo desde el inspector con un `TurnSeat` hijo por jugador, o muestra el de tus reglas (`use_cycle`). `autostart`.
- `TurnSeat`: nombre, `is_bot`, `active` y señales propias de ese asiento.
- Ejemplo `examples/minimal`, tests propios y `turnkit_lab/`.
