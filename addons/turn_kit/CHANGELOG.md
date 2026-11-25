# Cambios de TurnKit

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
