---
name: godot-stat-kit
description: >-
  Estadísticas con bonus en un juego Godot 4 con el addon StatKit: una base
  por estadística (ataque, defensa, comida, movimientos), un mínimo y un
  máximo, y modificadores que suman, suman un porcentaje, multiplican o fijan
  el valor, en un orden fijo (ADD, PERCENT, MUL, y el último SET gana), cada
  uno con su fuente para sacar de una vez todo lo que dio un ítem, un buff o
  una tecnología. Un `StatSheet` de datos puros para las reglas, recursos
  `StatModifier` y un nodo `StatBlock` que muestra los valores finales en el
  inspector sin correr el juego; guardar con `to_dict`. Usar cuando el
  usuario quiere estadísticas, atributos, bonus de equipo, buffs y debuffs,
  porcentajes o multiplicadores, un terreno que fija un valor, topes de una
  estadística, bonus de tecnologías o /add-stats. No son ítems, inventario,
  la duración de un buff, UI ni la red.
---

# Godot — estadísticas con bonus (StatKit)

Addon `addons/stat_kit/` en el proyecto del **juego**. Referencia: `addons/stat_kit/README.md`.

Si el addon no está:

```bash
./install.sh --addon /path/to/godot-project stat_kit
```

Habilitá el plugin **StatKit** (tipo `StatBlock` en Create Node; `StatModifier` en New Resource). Pedido acotado: `/add-stats`. Composición: [godot-composition-first](../godot-composition-first/SKILL.md).

## Reglas

- **Dos niveles.** Las reglas del juego guardan un `StatSheet` por personaje, unidad o ciudad (datos puros, se testea headless). El `StatBlock` es el nodo que lo arma con los valores del inspector o muestra el de tus reglas (`use_sheet`).
- **Un orden fijo.** `(base + todos los ADD) × (1 + todos los PERCENT) × todos los MUL`; si hay un SET, gana el último agregado; al final, el mínimo y el máximo. Los PERCENT se suman (dos +10 % = +20 %) y los MUL se multiplican (dos ×1,5 = ×2,25): elegí el que dice el diseño.
- **Cada bonus tiene fuente.** Quién lo da (un ítem, un desbloqueo, un buff) lo pasa el código al agregarlo: `add(mod, &"left_ring")`, `add_all(item.bonuses, item.id)`. Si no se pasa, cuenta la `source` del recurso. `remove_source(source)` saca todo lo de esa fuente.
- **Los números de diseño van en recursos.** Un bonus fijo de un ítem es un `StatModifier` `.tres` (o una lista en el `.tres` de tipo del ítem) exportado en el script: `hero.add(sword)`. `StatModifier.plus`, `percent`, `times` y `fixed` son para bonus que calcula el código (por nivel, por cantidad). Un `.tres` se comparte: para cambiar uno solo en el juego, `duplicate()`.
- **Editor primero.** `base_values`, `start_modifiers`, `min_values` y `max_values` se configuran en el inspector, y el grupo **Values** muestra el valor final al momento, sin correr el juego. El nodo avisa de un lugar vacío, un modificador sin `stat`, un `MUL` en 0, un mínimo mayor que el máximo y una estadística sin base.
- **Rearmar no pierde nada.** Cambiar los valores del inspector con el juego corriendo arma la hoja de nuevo y conserva lo que hizo el código (bonus agregados o sacados, bases y límites cambiados). `use_own_sheet()` sí empieza de cero.
- **El HUD escucha.** `stat_changed(stat, value)` solo cuando el valor final cambia; `rebuilt` para redibujar todo cuando el nodo pasa a mostrar otra hoja. `value()` lee un valor ya calculado: se puede leer en cada cuadro.
- **Números `float`.** El juego redondea (`roundi`); los topes van en `min_values` / `max_values`.
- **Guardar.** `to_dict()` y `StatSheet.from_dict()` guardan bases, límites y modificadores en orden, con su fuente. Los que vuelven son copias: se sacan con `remove_source`.
- **Ningún kit depende de otro.** StatKit no tiene ítems, inventario, duración de buffs, UI, red ni autoload: el juego conecta. Un buff con tiempo es un `Timer` del juego que llama `remove` o `remove_source`. En red, el servidor decide los bonus y manda valores o `to_dict()`.

## Árbol

```
Unit
├── StatBlock                            # base_values {attack: 5, defense: 4}, min_values {moves: 1}; Values muestra el final
│   └── (start_modifiers)                # [sword.tres: +2 attack] como recursos del inspector
├── Equipment (Node)                     # equip: block.add_all(item.bonuses, item.id); unequip: block.remove_source(item.id)
└── Hud (Control)                        # escucha stat_changed / rebuilt y muestra los valores
```

Arrancá desde `addons/stat_kit/examples/minimal/minimal.tscn`.

## Qué va dónde

| Kit | Juego |
|---|---|
| Las bases, los límites, los modificadores, el orden ADD → PERCENT → MUL → SET | Qué estadísticas existen, qué da cada ítem, terreno o tecnología, y cuáles son sus topes |
| `add`, `add_all`, `remove`, `remove_source`, `sources` | Cuándo se equipa, quién da cada bonus, cuánto dura un buff, qué lo termina |
| `value`, `values`, `describe` | El redondeo y cómo se usa el valor (daño, costo, alcance) |
| `stat_changed`, `rebuilt` | El HUD, las animaciones, los avisos |
| `to_dict` / `from_dict` | Dónde se guarda y cómo viaja por la red |

## Listo cuando

- El `StatBlock` no muestra avisos y el grupo **Values** del inspector muestra lo esperado sin correr el juego.
- F6: equipar y desequipar cambia el valor; los ADD van antes que los PERCENT y los MUL; dos PERCENT se suman; un SET pisa todo; los topes se respetan; `remove_source` saca todos los bonus de una fuente.
- El HUD redondea donde hace falta y se redibuja con `stat_changed` y `rebuilt`.
- `godot --headless --path statkit_lab --script res://addons/stat_kit/tests/stat_test_runner.gd` da `STATKIT TESTS PASS` (en el repo del kit).

## Antipatrones

- Ítems, inventarios o tiempos de buff dentro del kit: el juego los tiene y llama `add` / `remove_source`.
- Guardar el valor final en otra variable y sumarle bonus a mano, o recortarlo con `maxf` en el juego: el valor es `value(stat)`, con sus límites en el inspector.
- El número de un bonus fijo escrito en el código (`StatModifier.plus(&"attack", 2, …)` para una espada): va en un `.tres` exportado.
- Un bonus sin fuente: después no se puede sacar con `remove_source`. La fuente la pasa quien lo agrega.
- Cambiar `amount` de un `.tres` compartido para un solo personaje: cambia en todos; usá `duplicate()`.
- Guardar el estado de las reglas en el nodo: el nodo es una vista; las reglas guardan el `StatSheet`.
