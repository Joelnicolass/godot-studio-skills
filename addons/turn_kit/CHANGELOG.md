# Cambios de TurnKit

## 0.1.0

Primera versión:

- `TurnCycle`: turnos, rondas y ciclos como datos puros. Acciones por turno, ronda desde `first_seat`, ciclos y fin configurables (0 = sin fin), asientos inactivos, señales en un orden fijo y `to_dict` / `from_dict`.
- `TurnClock`: arma el ciclo desde el inspector con un `TurnSeat` hijo por jugador, o muestra el de tus reglas (`use_cycle`). `autostart`.
- `TurnSeat`: nombre, `is_bot`, `active` y señales propias de ese asiento.
- Ejemplo `examples/minimal`, tests propios y `turnkit_lab/`.
