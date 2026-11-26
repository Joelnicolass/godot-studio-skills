# <img src="icons/stat_kit.svg" width="32" height="32" alt=""> StatKit

Estadísticas con bonus para RPGs, roguelikes, juegos de estrategia o de mesa: cuánto vale un número ahora, con cada bonus. Ataque +2 por una espada, +10 % por un anillo, comida ×2 por un granero, movimientos fijos en 1 en un pantano, una defensa que no pasa de 10, y sacar de una vez todo lo que dio una fuente. Hay tres piezas:

- **`StatModifier`** (Resource): un bonus. Suma (`ADD`), suma un porcentaje (`PERCENT`), multiplica (`MUL`) o fija (`SET`) una estadística, y dice quién lo da (`source`).
- **`StatSheet`**: las estadísticas como datos puros (`RefCounted`, sin nodos ni escena). Una base por estadística, un mínimo y un máximo opcionales, y una lista de modificadores. Las reglas de tu juego la usan directo y se testea headless.
- **`StatBlock`** (Node): arma o muestra un `StatSheet` con los valores del inspector, y muestra los valores finales en el inspector sin correr el juego.

StatKit **no tiene** ítems, inventario, buffs con duración, UI, red ni autoload. Qué da cada cosa y cuándo se pone o se saca lo decide tu juego.

## Instalar

```bash
./install.sh --addon /path/to/godot-project stat_kit
```

Habilitá el plugin **StatKit** (tipo `StatBlock` en Create Node; `StatModifier` en New Resource).

## En 3 pasos

1. Agregá un `StatBlock`.
2. En el inspector poné `base_values` (por ejemplo `attack: 5, defense: 4`) y, si querés, `start_modifiers` (lo que trae equipado), `min_values` y `max_values`. Abajo, en el grupo **Values**, ves el valor final (`Attack 5`) sin correr el juego. Cambiá un número y el valor cambia al momento.
3. Creá la espada como recurso: New Resource › `StatModifier`, con `stat` = `attack`, `op` = `Add`, `amount` = `2`, `source` = `sword`, guardado como `sword.tres`. Arrastralo al `sword` del script, que la equipa, la desequipa y redondea el ataque para el daño:

```gdscript
@export var sword: StatModifier

@onready var hero: StatBlock = %Hero


func equip_sword() -> void:
	hero.add(sword)


func unequip_sword() -> void:
	hero.remove(sword)


func damage() -> int:
	return roundi(hero.value(&"attack"))
```

Para que la espada dé +3, cambiá `amount` en `sword.tres`: no se toca código.

## Ejemplo mínimo

`examples/minimal/minimal.tscn` (F6): la carta de un héroe con ataque 5, defensa 4 (máximo 10, en `max_values`) y 3 movimientos. La espada arranca equipada: es un `start_modifiers` del inspector de `Hero`, así que el editor ya muestra `Attack 7` en **Values**. Los botones ponen y sacan un modificador cada uno (`.tres` en `modifiers/`): la espada (+2 ataque), el escudo (×1,5 defensa) y el pantano (movimientos = 1). Un solo `ring.tres` (+50 % ataque) se usa en las dos manos: cada mano lo agrega con su propia fuente (`left_ring`, `right_ring`), y los dos +50 % se suman (×2, no ×2,25). **Bless** agrega dos modificadores armados en código con una sola fuente (+2 defensa, +1 movimiento); apretalo dos veces y se apilan hasta el máximo de defensa. **Remove blessing** los saca a todos con `remove_source`. La carta muestra cada valor con su desglose (`describe`), y el registro muestra cada `stat_changed`.

```
Minimal          # minimal.gd: arma la carta y conecta los botones; sword, shield, swamp y ring en su inspector
├── Card         # valores con su desglose, los toggles, los anillos, Bless, Remove blessing, registro
└── %Hero        # StatBlock: base_values = {attack: 5, defense: 4, moves: 3}, max_values = {defense: 10}
                 # start_modifiers = [sword.tres: +2 attack]
```

## Cómo calcula

- **El valor final** es `(base + todos los ADD) × (1 + todos los PERCENT) × todos los MUL`. Si hay un SET, gana el último SET agregado: pisa la base, los ADD, los PERCENT y los MUL. Al final, el valor se queda entre el mínimo y el máximo de la estadística (también el de un SET).
  - Escudo ×1,5 y bendición +2 sobre una defensa de 4: `(4 + 2) × 1,5 = 9`, no `4 × 1,5 + 2 = 8`. El orden en que se agregan no importa.
  - Pantano `= 1` sobre 3 movimientos y una bendición +1: da 1. Sin el pantano, 4.
  - Con `max_values = {defense: 10}`, dos bendiciones y el escudo dan `(4 + 4) × 1,5 = 12`, y queda en 10.
- **PERCENT se suma, MUL se multiplica:** dos +50 % (`PERCENT`, `amount` 0,5) dan ×2; dos ×1,5 (`MUL`) dan ×2,25. Elegí el que dice tu diseño: «+10 % de ataque» de anillos y talentos suele ser `PERCENT`; «el doble» de un buff fuerte suele ser `MUL`.
- **Sin base:** una estadística sin base arranca en 0. `value()` de una que no existe da 0.
- **Apilar:** el mismo modificador dos veces cuenta dos veces.
- **La fuente:** cada modificador cuenta como dado por su `source`, o por la que le pasás al agregarlo: `add(ring, &"left_ring")` y `add(ring, &"right_ring")` son dos anillos con un solo `.tres`. `add_all(mods, source)` agrega los bonus de un ítem con una sola fuente. `remove_source(source)` saca todos los de esa fuente, de todas las estadísticas, y devuelve cuántos sacó.
- **Sacar uno:** `remove(mod)` saca una vez ese modificador; `remove(mod, source)`, uno agregado con esa fuente. Lo que vuelve de `from_dict` son copias: para esas, `remove` acepta un modificador igual (misma `stat`, `op`, `amount` y fuente). Para todo lo demás cuenta el mismo objeto.
- **Un modificador cambia en vivo:** si cambiás `amount`, `op` o `stat` de un modificador que ya está en una hoja, el valor cambia al momento y se emite `stat_changed`.
- **La señal:** `stat_changed(stat, value)` sale solo cuando el valor final cambia de verdad. Un +0, un ×1, una base nueva debajo de un SET o un valor que ya estaba en su máximo no la emiten. Si cambian varias estadísticas a la vez, sale una por estadística, en orden alfabético.
- **Leer es barato:** la hoja guarda el valor final de cada estadística y lo actualiza en cada cambio; `value()` solo lo lee. Un HUD puede leerlo en cada cuadro.
- **Números:** son `float`. Si tu juego quiere enteros, redondea él (`roundi(value)`, `int(value)`). Un mínimo o un máximo van en el inspector (`min_values`, `max_values`) o en `set_limits`.
- **Errores:** un modificador null o sin `stat`, o un mínimo mayor que el máximo, es un error y no cambia nada.
- **Guardar:** `to_dict()` y `StatSheet.from_dict()` guardan las bases, los límites y los modificadores en orden (el orden decide qué SET gana), cada uno con la fuente con la que cuenta.

## API

### `StatModifier` (Resource)

| Miembro | Qué hace |
| --- | --- |
| `stat`, `op` (`ADD`, `MUL`, `SET`, `PERCENT`), `amount`, `source` | La estadística, qué le hace, cuánto, y quién lo da. Cambiar cualquiera emite `changed` |
| `StatModifier.new(stat, op, amount, source)` | Uno a mano. Todo es opcional |
| `StatModifier.plus(stat, amount, source)` | Suma `amount` |
| `StatModifier.percent(stat, fraction, source)` | Suma un porcentaje: `0.1` es +10 %, y se suma con los otros |
| `StatModifier.times(stat, factor, source)` | Multiplica por `factor` |
| `StatModifier.fixed(stat, value, source)` | Fija la estadística en `value` |
| `describe(source = &"")` | Para un tooltip: `+2 attack (sword)`, `+10 % attack (ring)`, `×1.5 food (granary)`, `= 1 moves (swamp)`. Con `source`, nombra esa fuente en vez de la suya |
| `to_dict()` / `StatModifier.from_dict(data)` | Datos planos. `op` va como `"add"`, `"mul"`, `"set"` o `"percent"`; `from_dict` acepta también el número. Un `op` desconocido es un error y devuelve null |

### `StatSheet` (RefCounted)

| Miembro | Qué hace |
| --- | --- |
| `StatSheet.new(bases)` | Una hoja con `{stat: base}`. Todo es opcional |
| `set_base(stat, amount)`, `base(stat)`, `bases()` | Las bases (0 si no hay) |
| `set_limits(stat, min_value = -INF, max_value = INF)`, `clear_limits(stat)`, `limits(stat) -> Vector2` | El mínimo y el máximo, aplicados al final. `limits` da `Vector2(min, max)`, con `-INF` o `INF` donde no hay |
| `add(mod, source = &"")` | Agrega un modificador; con `source`, cuenta como dado por esa fuente. El mismo dos veces se apila |
| `add_all(mods, source = &"")` | Agrega varios, todos con esa fuente (un ítem con varios bonus) |
| `remove(mod, source = &"") -> bool` | Saca una vez ese modificador (con `source`: uno agregado con esa fuente) |
| `remove_source(source) -> int` | Saca todos los de una fuente y devuelve cuántos |
| `modifiers(stat = &"")`, `sources(stat = &"")` | Los modificadores, o los de una estadística, en el orden en que se agregaron, y la fuente con la que cuenta cada uno, en el mismo orden |
| `describe(stat) -> PackedStringArray` | Una línea por modificador de la estadística, con su fuente: el desglose de un tooltip |
| `clear_modifiers()` | Saca todos los modificadores; las bases y los límites quedan |
| `value(stat) -> float` | El valor final |
| `values()`, `stats()` | Todos los valores y todas las estadísticas (con base, límite o modificador), en orden alfabético |
| `to_dict()` / `StatSheet.from_dict(data)` | Datos planos para guardar, mandar por red o comparar un replay |
| señal `stat_changed(stat, value)` | En pasado: el valor final ya cambió |

### `StatBlock` (Node)

- **Inspector:** `base_values` (`{stat: base}`), `start_modifiers` (una lista de `StatModifier`, como lo que el personaje trae equipado), `min_values` y `max_values` (`{stat: límite}`). Cambiar un valor dentro de un modificador se aplica al momento. Cambiar las bases, la lista o los límites arma la hoja de nuevo **y conserva lo que hizo el código**: los modificadores agregados con `add`, los que sacó de los de inicio, y las bases y los límites que cambió. Nunca toca una hoja de `use_sheet`.
- **Values:** un grupo de solo lectura al final del inspector con el valor final de cada estadística (con sus límites), al día. No se guarda en la escena. En una hoja de `use_sheet` muestra los valores de esa hoja.
- **Avisos del editor:** un nombre de estadística vacío, un lugar vacío en `start_modifiers`, un modificador sin `stat`, un `MUL` con `amount` 0 (deja la estadística en 0), un mínimo mayor que el máximo, y una estadística con modificador o límite pero sin base (vale, arranca en 0; se avisa una vez por estadística).
- **Hoja:** `sheet` es el `StatSheet` que muestra. `use_sheet(sheet)` muestra el de tus reglas y `use_own_sheet()` vuelve a una hoja nueva armada solo con el inspector.
- **Métodos:** los mismos de `StatSheet`: `value`, `values`, `base`, `set_base`, `add`, `add_all`, `remove`, `remove_source`, `modifiers`, `sources`, `describe`. `set_base` cambia la hoja, no `base_values`. Los límites en código van por `sheet.set_limits`.
- **Señales:** `stat_changed(stat, value)`, más `rebuilt` cuando el nodo pasa a mostrar otra hoja (`use_sheet`, `use_own_sheet` o valores nuevos del inspector). Al recibirla, volvé a leer todos los valores.

## Querés → escribí

| Querés | Escribí |
| --- | --- |
| Equipar un ítem | `@export var sword: StatModifier` con su `.tres`, y `hero.add(sword)` |
| Desequiparlo | `hero.remove(sword)`, o `hero.remove_source(&"sword")` si dio varios bonus |
| Un ítem con varios bonus | `@export var bonuses: Array[StatModifier]` y `hero.add_all(bonuses, &"armor")`; sacarlo es `hero.remove_source(&"armor")` |
| Dos anillos iguales | Un `ring.tres` y `hero.add(ring, &"left_ring")`, `hero.add(ring, &"right_ring")`: cada uno se saca con su fuente |
| Que dos +10 % den +20 % | `op` = `Percent` y `amount` = `0.1` en cada uno |
| Un bonus que arma el código | `hero.add(StatModifier.plus(&"attack", level, &"level"))`, o `percent`, `times`, `fixed` |
| Un buff y sacarlo después | `hero.add(haste)` y, cuando termina (un `Timer` de tu juego), `hero.remove(haste)` |
| Un terreno que fija un valor | Un `.tres` con `op` = `Set` (`= 1 moves`) que el terreno agrega al entrar y saca al salir |
| Que los movimientos no bajen de 1 | `min_values = {moves: 1}` en el inspector, o `sheet.set_limits(&"moves", 1)` |
| El número entero para el juego | `roundi(hero.value(&"attack"))` |
| Un tooltip con el desglose | `"\n".join(hero.describe(&"attack"))` |
| Saber si un buff está puesto | `hero.sources().has(&"haste")` |
| Redibujar el HUD | `hero.stat_changed.connect(_on_stat_changed)` y `hero.rebuilt.connect(_redraw_all)` |
| Una hoja por personaje en tus reglas | `var sheet := StatSheet.new({&"attack": 5})` en el estado de la partida, y `block.use_sheet(sheet)` para verla |
| Guardar y cargar | `save["stats"] = sheet.to_dict()` y `StatSheet.from_dict(save["stats"])` |

## Tips

- **Las reglas usan `StatSheet`, no el nodo.** Guardá una hoja por personaje en el estado de tu partida y mostrala con `block.use_sheet(unit.stats)`. El HUD escucha `stat_changed` y, para redibujar todo cuando cambia la unidad que se muestra, `rebuilt`.
- **Un `.tres` se comparte:** el mismo `sword.tres` en diez personajes es un solo recurso. Si cambiás su `amount` en el juego, cambia en los diez. Para uno solo, `sword.duplicate()` (o *Local to Scene* en el inspector).
- **La fuente la pone quien agrega:** el recurso dice qué hace el bonus; quién lo da lo sabe el código que lo pone. Pasá la fuente en `add` o `add_all` (el id del ítem, del buff, del desbloqueo) y no la repitas en cada `.tres`.
- **`remove_source(&"")`** saca los modificadores sin fuente. Ponele siempre una fuente a lo que vas a querer sacar.

## Tests

```bash
godot --headless --path statkit_lab --script res://addons/stat_kit/tests/stat_test_runner.gd
```

Sale `STATKIT TESTS PASS (n)`. Los tests cubren:

- El modificador: valores por defecto, `plus` / `percent` / `times` / `fixed`, `describe` (también con otra fuente), `changed` y `to_dict` (también por JSON y con `op` como número).
- La hoja: bases, el orden ADD → PERCENT → MUL → SET (los PERCENT se suman, los MUL se multiplican, el último SET gana), los límites (también sobre un SET), apilar, la fuente al agregar (`add`, `add_all`, `remove` con fuente), `remove` de una copia cargada, `remove_source` (también `&""`), `stat_changed` solo cuando el valor cambia, un modificador que cambia después de agregarse, uno compartido por dos hojas, los errores y `to_dict` / `from_dict` (con límites y fuentes, por JSON).
- El nodo: la hoja del inspector, el grupo **Values** de solo lectura y sin guardar, los cambios en vivo, los límites del inspector, que rearmar conserve lo que hizo el código, las señales, `use_sheet`, `rebuilt` y los avisos del editor (también un `MUL` en 0).
- El ejemplo jugado con sus botones.
- Que el addon no nombre a ningún otro kit.

El lab tiene además un chequeo en el editor real (ver `statkit_lab/README.md`).
