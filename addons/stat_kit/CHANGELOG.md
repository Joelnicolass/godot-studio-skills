# StatKit changes

## 0.1.0

First version:

- `StatModifier` (Resource): a bonus to one stat that adds (`ADD`), adds a percent (`PERCENT`, `0.1` is +10 %), multiplies (`MUL`) or fixes (`SET`), with its source (`source`). Shortcuts `plus`, `percent`, `times` and `fixed`, `describe(source)` for tooltips and `to_dict` / `from_dict`.
- `StatSheet`: bases, limits and modifiers as plain data. The final value is `(base + ADD) × (1 + PERCENT) × MUL`, the last SET wins, and then it is kept between the minimum and the maximum (`set_limits`, `clear_limits`, `limits`). The source can be passed when adding (`add(mod, source)`, `add_all(mods, source)`), so one `.tres` serves two rings. Stacking, `remove(mod, source)`, `remove_source`, `sources`, `describe(stat)`, `stat_changed` only when the value changes, modifiers that change live, a `value()` that reads an already computed value and `to_dict` / `from_dict`.
- `StatBlock`: builds the sheet from the inspector (`base_values`, `start_modifiers`, `min_values`, `max_values`) or shows your rules' sheet (`use_sheet`), and lists the final values in the inspector, read only, without running the game. Rebuilding the sheet after an inspector change keeps what code did. Editor warnings, a `MUL` of 0 too.
- Example `examples/minimal`, the kit's own tests and `statkit_lab/` with a check in the real editor.
