---
description: "Estadísticas con bonus (addon StatKit): una base y topes por estadística, y modificadores que suman, suman un porcentaje, multiplican o fijan, en orden ADD → PERCENT → MUL → SET, cada uno con su fuente; remove_source saca todos los de un ítem o un buff, y el inspector muestra el valor final."
---

Agregá **estadísticas con bonus** en el **proyecto Godot del juego** con el addon StatKit:
- un `StatBlock` en cada cosa que tiene estadísticas (o un `StatSheet` por personaje en sus reglas, mostrado con `use_sheet`);
- las bases en `base_values` y los topes en `min_values` / `max_values`;
- los bonus que trae de arranque en `start_modifiers` (recursos `StatModifier`);
- el juego poniendo y sacando bonus con `add` / `add_all` (con la fuente del ítem) y `remove_source`, y el HUD escuchando `stat_changed` y `rebuilt`.

Después la persona ve los valores finales en el grupo **Values** del inspector, sin correr el juego; el agente arma y explica.

Esto **no** son ítems, inventarios, duración de buffs ni UI: el kit calcula, y el juego decide qué da cada cosa y cuándo se pone o se saca. **No** es la red: un juego en red decide los bonus en el servidor y manda valores.

Cargar: `godot-stat-kit`, `godot-composition-first`.

Si falta `addons/stat_kit/`:

```bash
./install.sh --addon /ABS/GODOT_ROOT stat_kit
```

Habilitá **StatKit**. Si `godot-studio-workflow` está cargado: orquestador → árbol (este chat si son 1–3 archivos; si no, `studio-tech-lead`) → OK → `studio-developer`. Sin subagente extra.

## 1. Alcance

Si falta, preguntá en una sola tanda:

1. Qué estadísticas hay (ataque, defensa, movimientos, comida) y en qué cosas (personajes, unidades, ciudades).
2. Qué da bonus: ítems, terrenos, tecnologías, buffs. Si cada uno suma, suma un porcentaje (`PERCENT`: dos +10 % = +20 %), multiplica (`MUL`: dos ×1,1 = ×1,21) o fija.
3. Cuándo se pone y cuándo se saca cada bonus (equipar, entrar a un terreno, un buff con tiempo).
4. Si el valor se usa entero (daño, movimientos) y qué mínimo o máximo tiene cada estadística.
5. Qué muestra el HUD (el valor, el desglose) y si el juego guarda la partida o es en red.

## 2. Plan

Mostrá el árbol de archivos antes de tocar el juego (`[+]` nuevo, `[~]` cambiado, `[-]` borrado), por ejemplo:

```
[~] project.godot                        # plugin StatKit
[+] items/sword/sword_modifier.tres      # StatModifier: attack, ADD, 2
[+] items/ring/ring_modifier.tres        # StatModifier: attack, PERCENT, 0.1 (+10 %)
[~] units/hero/hero.tscn                 # StatBlock: base_values {attack: 5, defense: 4, moves: 3}, min_values {moves: 1}
[+] units/hero/equipment.gd              # equip: block.add(mod, item_id); unequip: block.remove_source(item_id)
[+] ui/stats_hud.gd                      # escucha stat_changed y rebuilt; muestra roundi(value) y describe()
[~] docs/tuning.md                       # filas de base_values y de cada .tres de bonus
```

Arrancá desde `addons/stat_kit/examples/minimal/minimal.tscn` (espada, escudo, pantano, un anillo en las dos manos y una bendición de dos bonus).

## 3. Implementar

Seguí [godot-stat-kit](../skills/godot-stat-kit/SKILL.md) y `addons/stat_kit/README.md`.

- `base_values`, `start_modifiers`, `min_values` y `max_values` en el inspector del `StatBlock`. Cada bonus fijo de un ítem es un `StatModifier` `.tres` (o una lista en el `.tres` de tipo del ítem) exportado en el script: nunca su número en el código. `StatModifier.plus` / `percent` / `times` / `fixed` solo para bonus que calcula el código.
- La fuente la pone quien agrega: `add(mod, item_id)` o `add_all(item.bonuses, item_id)`. Sacar es `remove_source(item_id)`. Dos ítems iguales son dos fuentes con el mismo `.tres`.
- Un buff con tiempo: un `Timer` del juego que llama `remove_source` al terminar.
- Cambiar los valores del inspector en el juego conserva lo que hizo el código; `use_own_sheet()` empieza de cero.
- Con un `StatSheet` por personaje en las reglas: `block.use_sheet(unit.stats)` y el HUD escucha `rebuilt`.
- El juego redondea (`roundi(value)`) y pone sus mínimos y máximos.
- Guardar con `to_dict()` / `StatSheet.from_dict()`. En red, el servidor pone los bonus y manda valores.
- Decile a la persona cómo verlo: elegí el `StatBlock` y mirá el grupo **Values** del inspector; cambiá un `amount` y el valor cambia al momento.

## 4. Listo cuando

- El `StatBlock` no muestra avisos y la persona vio el grupo **Values** con los valores esperados.
- F6: equipar y desequipar cambia el valor; los ADD van antes que los PERCENT y los MUL; un SET pisa todo; los topes se respetan; `remove_source` saca todo lo de una fuente.
- El HUD muestra los valores y se redibuja con `stat_changed` y `rebuilt`.
- Nada de ítems, inventarios, tiempos ni red dentro de `addons/stat_kit`.
