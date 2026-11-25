# Cambios de CommandKit

## 0.1.0

Primera versión:

- `GameCommand`: la base de una orden. Tipo, `from_args`, `args`, `can_run` (`&""` = puede), `run`, deshacer opcional, `seat` y `to_dict` (`{type, seat, args}`).
- `CommandLog`: corre solo las órdenes válidas, registra las aceptadas, deshace la última, repite un registro (cortando en la primera que no corre, con `is_replaying()` para que un listener no mande órdenes dos veces) y arma órdenes desde sus entradas.
- `CommandBus`: los tipos de orden desde el inspector, un `context` por defecto, `use_log` y `rebuilt`.
- Ejemplo `examples/minimal` (fichas en un tablero con Undo y Replay), tests propios y `commandkit_lab/`.
