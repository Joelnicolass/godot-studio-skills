# Cambios de StatKit

## 0.1.0

Primera versión:

- `StatModifier` (Resource): un bonus a una estadística que suma (`ADD`), suma un porcentaje (`PERCENT`, `0.1` es +10 %), multiplica (`MUL`) o fija (`SET`), con su fuente (`source`). Atajos `plus`, `percent`, `times` y `fixed`, `describe(source)` para tooltips y `to_dict` / `from_dict`.
- `StatSheet`: bases, límites y modificadores como datos puros. El valor final es `(base + ADD) × (1 + PERCENT) × MUL`, el último SET gana, y después se queda entre el mínimo y el máximo (`set_limits`, `clear_limits`, `limits`). La fuente se puede pasar al agregar (`add(mod, source)`, `add_all(mods, source)`), así un `.tres` sirve para dos anillos. Apilar, `remove(mod, source)`, `remove_source`, `sources`, `describe(stat)`, `stat_changed` solo cuando el valor cambia, modificadores que cambian en vivo, `value()` que lee un valor ya calculado y `to_dict` / `from_dict`.
- `StatBlock`: arma la hoja desde el inspector (`base_values`, `start_modifiers`, `min_values`, `max_values`) o muestra la de tus reglas (`use_sheet`), y lista los valores finales en el inspector, de solo lectura, sin correr el juego. Rearmar la hoja por un cambio del inspector conserva lo que hizo el código. Avisos del editor, también para un `MUL` en 0.
- Ejemplo `examples/minimal`, tests propios y `statkit_lab/` con un chequeo en el editor real.
