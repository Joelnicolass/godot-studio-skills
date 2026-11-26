# <img src="icons/dice_kit.svg" width="32" height="32" alt=""> DiceKit

Dados para juegos de guerra, roguelikes, de mesa o RPGs: con cualquier cara (números, íconos, uno o varios símbolos), tirados con tu `RandomNumberGenerator`. La tirada te dice la suma, cuántas veces salió cada símbolo, los dados más altos y los más bajos, y vuelve a tirar los que elijas. Hay dos niveles:

- **`DieData`** (Resource) y **`DiceRoll`** (RefCounted): el dado y la tirada como datos puros, sin nodos ni escena. Las reglas de tu juego tiran con su propio rng y se testean headless.
- **`DiceRoller`** (Node): tira los dados del inspector (también mezclados: 2d6 + 1d8) con su semilla y avisa con `rolled`. **`DiceTray3D`** (Node3D, opcional) muestra la tirada en 3D: los dados giran y caen con la cara que salió arriba.

DiceKit **no tiene** reglas de juego (qué significa un `hit`, cuánto daño hace un crítico), física, red ni autoload. Ninguna parte del kit usa el azar global de Godot: cada número sale de un rng que le das, así que la misma semilla da las mismas tiradas.

## Instalar

```bash
./install.sh --addon /path/to/godot-project dice_kit
```

Habilitá el plugin **DiceKit** (tipos `DiceRoller` y `DiceTray3D` en Create Node; `DieData` y `DieFace` en New Resource).

## En 3 pasos

1. Agregá un `DiceRoller` y arrastrá un dado a `die`: uno listo de `addons/dice_kit/dice/` (`d4.tres`, `d6.tres`, `d8.tres`, `d10.tres`, `d12.tres`, `d20.tres`) o uno tuyo (New Resource → `DieData`, con un `DieFace` por cara: `value`, `tags`, `icon`). Copiá el `.tres` de `dice/` a tu juego antes de editarlo: reinstalar el kit pisa esa carpeta.
2. Poné `count` (cuántos dados) y apretá **Roll** en el inspector: `last_result` muestra lo que salió («3 + 5 = 8 · 1 sword»), sin correr el juego.
3. Tirá desde tu código. Un ataque tira tantos dados como el atacante y cuenta los aciertos:

```gdscript
@onready var roller: DiceRoller = %Roller


func attack(dice: int) -> int:
	var roll := roller.roll(dice)
	print("Salió %s" % roll.describe())
	return roll.count(&"hit")
```

`roll.sum()` suma los valores; `roll.count(&"hit")` cuenta cuántas veces salió ese símbolo.

## Ejemplo mínimo

`examples/minimal/minimal.tscn` (F6, 3D): un dado propio, `attack_die.tres`, con 3 caras `hit` (valen 1, con ícono), 2 `blank` (valen 0) y 1 `crit` (vale 2, con ícono); cada cara tiene un símbolo en `tags`. **Roll 1**, **Roll 2** y **Roll 3** tiran esa cantidad; los dados giran y, cuando caen, el texto dice la suma y los aciertos. Escribí una semilla en **Seed** (0: al azar) y las mismas tiradas vuelven en el mismo orden.

```
Minimal          # minimal.gd: conecta los botones y lee la tirada en settled
├── Camera, Sun, Environment, Table
├── %Roller      # DiceRoller: die = attack_die.tres, count = 3, rng_seed = 0
├── %Tray        # DiceTray3D: roller = %Roller
└── Ui           # Roll 1 / 2 / 3, %Seed, %Result
```

## Cómo tira

- **Caras:** `DieData.faces` es la lista, en orden. Todas son igual de probables. Una cara que tiene que salir más seguido va dos veces en la lista (el mismo recurso sirve: editarlo cambia las dos).
- **Símbolos:** `DieFace.tags` es una lista, y un símbolo puede estar más de una vez. `count(tag)` cuenta cada aparición: una cara `[hit, hit, shield]` suma 2 aciertos y 1 escudo. Para una cara de un solo símbolo, `face.tag` lee el primero y escribirlo deja solo ese.
- **Una tirada:** cada dado saca **un** número del rng, `rng.randi_range(0, caras - 1)`, en orden. Por eso la misma semilla da la misma tirada, y dos tiradas seguidas del mismo rng siguen su secuencia.
- **Lugares:** cada dado de la tirada tiene un lugar (`slot`), 0 el primero. `highest()`, `lowest()` y `slots_with(tag)` devuelven lugares; `highest_values()` y `lowest_values()`, valores.
- **Volver a tirar:** `rerolled(slots, rng)` da una tirada nueva con esos lugares tirados otra vez y los otros como estaban. Cada dado que se vuelve a tirar saca un número del rng, en orden de lugar.
- **Lo que guarda:** `dice` (el dado de cada lugar), `faces` (la cara que salió) e `indices` (el lugar de esa cara en `faces`, 0 la primera). Son de solo lectura: lo que los lee recibe copias, y una tirada no cambia nunca. Con los dados y los índices se arma la misma tirada otra vez: eso viaja por red o se guarda.
- **Dados mezclados:** `DiceRoller.extra_dice` suma un dado de cada uno a cada tirada, después de los `count` de `die`. `roller.pool()` dice qué dados tira.
- **Semilla:** `DiceRoller.rng_seed` distinto de 0 da las mismas tiradas en cada partida. Con 0, cada roller toma una semilla nueva al azar cuando arranca, distinta de la de los otros rollers. Cambiar `rng_seed` arranca de nuevo el rng propio del roller.
- **Un rng para toda la partida:** `roller.rng = rng_de_la_partida`. Así un solo número (la semilla de la partida) repite todo, dados incluidos. Cambiar `rng_seed` nunca toca un rng asignado; `roller.rng = null` vuelve al propio.
- **Lugares vacíos:** un dado con un lugar vacío en `faces` no se puede tirar (`can_roll()` es false): da un error y una tirada vacía, y no saca nada del rng. El `DiceRoller` lo muestra como aviso en el editor.
- **Errores:** sin dados, un dado sin caras o con un lugar vacío, `n` menor a -1 o sin rng: un error y una tirada vacía (`size() == 0`). El roller no emite `rolled` ni cambia `last_roll`. Una tirada que falla no saca números del rng.
- **La bandeja no usa azar:** el giro de cada dado sale de su lugar y de la cara que salió. La misma tirada gira siempre igual.
- **Cambios de Godot:** un test fija la secuencia de un d6 con semilla 12345. Si una versión nueva de Godot cambia su `RandomNumberGenerator`, ese test falla: las semillas guardadas ya no darían las mismas tiradas.

## API

### `DieFace` (Resource)

| Miembro | Qué hace |
| --- | --- |
| `value: int` | Lo que suma a `sum()`. Un símbolo que no suma queda en 0 |
| `tags: Array[StringName]` | Los símbolos de la cara, que cuenta `count(tag)` (`hit`, `blank`, `shield`); uno puede repetirse. Vacío: ninguno |
| `tag: StringName` | Atajo para una cara de un símbolo: lee el primero de `tags`; escribirlo deja solo ese |
| `icon: Texture2D` | El dibujo que muestran las vistas. Vacío: escriben el valor y los símbolos |
| `DieFace.new(value, tag, icon)` | Todo opcional; para varios símbolos, `tags` después |

### `DieData` (Resource)

| Miembro | Qué hace |
| --- | --- |
| `faces: Array[DieFace]` | Las caras, en orden. Cambiar la lista o una cara se aplica al momento (avisos del roller, dados de la bandeja) |
| `sides() -> int` | Cuántas caras tiene |
| `mesh: Mesh` | La forma con que las vistas dibujan este dado (un modelo de d8). Vacío: la de la vista (`die_mesh` de la bandeja, o un cubo). Los dados listos no tienen |
| `can_roll() -> bool` | Tiene caras y ningún lugar vacío |
| `roll(n, rng) -> DiceRoll` | Tira `n` dados de este tipo |
| `DieData.numbered(sides)` | Un dado con caras que valen de 1 a `sides` (`numbered(6)` es un d6) |

### `DiceRoll` (RefCounted)

| Miembro | Qué hace |
| --- | --- |
| `sum() -> int` | La suma de los valores |
| `count(tag) -> int`, `has(tag) -> bool` | Cuántas veces salió ese símbolo (todas sus apariciones), y si salió |
| `slots_with(tag) -> Array[int]` | Los lugares cuya cara tiene ese símbolo |
| `values() -> Array[int]`, `size() -> int` | El valor de cada dado, en orden, y cuántos dados hay |
| `highest(n = 1)`, `lowest(n = 1) -> Array[int]` | Los **lugares** de los `n` valores más altos (o más bajos), primero el más alto (o el más bajo); un empate deja primero el lugar anterior |
| `highest_values(n = 1)`, `lowest_values(n = 1) -> Array[int]` | Esos **valores** |
| `rerolled(slots, rng) -> DiceRoll` | Una tirada nueva con esos lugares tirados otra vez; los otros quedan. Esta no cambia |
| `dice`, `faces`, `indices` | El dado, la cara y el índice de la cara de cada lugar. Solo lectura: copias |
| `describe() -> String` | La tirada en palabras: «3 + 5 = 8», «1 + 0 + 2 = 3 · 1 blank · 1 crit · 1 hit» |
| `DiceRoll.of(pool, rng)` | Un dado de cada uno, en orden: dados mezclados (`[d6, d6, d8]`) |
| `to_dict()` / `DiceRoll.from_dict(pool, data)` | `{"indices": [..]}` para guardar o mandar; del otro lado, con los mismos dados, la misma tirada. Los números de JSON sirven |
| `DiceRoll.from_indices(pool, indices)` | La tirada que dan esos índices (un registro, una tirada fija para un tutorial). No saca números |

### `DiceRoller` (Node)

- **Inspector:** `die`, `count` (cuántos de `die` por tirada), `extra_dice` (uno de cada uno más en cada tirada: un d8 acá y `count` 2 de un d6 tiran 2d6 + 1d8; sin `die`, solo estos) y `rng_seed` (0: al azar). En el grupo **Try it**, el botón **Roll** tira con esos valores, también en el editor, y `last_result` (solo lectura) muestra lo que salió. Cada Roll sigue la secuencia; para empezar de nuevo, escribí la semilla otra vez.
- **Avisos del editor:** sin dados, un dado sin caras o con lugares vacíos, y un lugar vacío en `extra_dice`.
- **`roll(n = -1) -> DiceRoll`:** tira `n` de `die` (-1: `count`) y uno de cada `extra_dice`, guarda la tirada en `last_roll` y emite `rolled(roll)`.
- **`pool(n = -1) -> Array[DieData]`:** los dados que tiraría `roll(n)`, en orden. Sirve para `DiceRoll.from_dict(roller.pool(), data)`.
- **`rng`:** de dónde salen los números. Si le asignás el de tu partida, usa ese; si no, el suyo, armado con `rng_seed` la primera vez. Cambiar `rng_seed` arma de nuevo solo el propio; `null` vuelve al propio.
- **Señales:** `rolled(roll)` y `dice_changed` (cambió `die`, `count`, `extra_dice` o una cara de esos dados).

### `DiceTray3D` (Node3D, opcional)

- **Inspector:** `roller` (muestra cada tirada suya), `die_mesh` (la forma de los dados que no traen `mesh` propio; vacío: un cubo), `die_size`, `spacing` (de centro a centro), `per_row` (cuántos dados por fila), `tumble_time` (0: caen al instante), `die_color` y `pip_color` (el color del valor y los símbolos; los íconos tienen su color).
- **Qué dibuja:** un dado por lugar, en filas de `per_row` sobre el eje X, centradas en el nodo y apoyadas en su plano XZ; la fila siguiente va detrás. Arriba va el ícono de la cara o, sin ícono, su valor y sus símbolos. Mientras gira, la cara de arriba va cambiando hasta quedar en la que salió.
- **Otra forma de dado:** cada dado usa su `DieData.mesh`; si no tiene, el `die_mesh` de la bandeja; si tampoco, un cubo. Así, en 2d6 + 1d8 el d8 se ve con su forma. Cualquier malla sirve (un modelo de d20): se escala para que su lado más largo mida `die_size`, y la cara que salió se dibuja plana arriba de la malla, como una calcomanía: la malla no gira hasta esa cara. Una malla con material propio lo conserva; una sin material se pinta de `die_color`.
- **En el editor y antes de la primera tirada:** muestra los dados del roller quietos, con la primera cara arriba. Cambiar `die`, `count` o `extra_dice` se ve al momento (escucha `dice_changed`, no pregunta en cada cuadro). Apretar **Roll** en el roller los hace girar en la vista 3D.
- **`show_roll(roll)`:** muestra cualquier tirada (dados mezclados, una que llegó por red). Una tirada nueva reemplaza a la que gira.
- **Señal `settled(roll)`:** los dados quedaron quietos. Es el momento de mostrarle el resultado al jugador.
- **Preguntas:** `shown_roll` (la tirada en la mesa; `null` en reposo), `is_tumbling()`, `dice_shown()` y `face_on_top(slot)` (la cara que se ve arriba del dado `slot`).

## Querés → escribí

| Querés | Escribí |
|---|---|
| Tirar 2d6 y sumar | `roller.roll(2).sum()` con un d6 en `die` |
| Contar aciertos | `roll.count(&"hit")` |
| Saber si salió un crítico | `roll.has(&"crit")` |
| Un dado propio con símbolos | New Resource → `DieData`; en `faces`, un `DieFace` por cara con `value`, `tags` e `icon` |
| Una cara con dos símbolos (2 aciertos y un escudo) | `tags = [hit, hit, shield]` en esa cara: `count(&"hit")` cuenta 2 |
| Una cara que salga más seguido | La misma cara dos veces en `faces` |
| Editar un dado listo | Copiá el `.tres` de `addons/dice_kit/dice/` a tu juego y editá la copia |
| Dados mezclados (2d6 + 1d8) | `count` 2 con un d6 en `die` y un d8 en `extra_dice`; en código, `DiceRoll.of([d6, d6, d8], rng)` |
| Ventaja (el mejor de 2d20) | `roller.roll(2).highest_values()[0]` |
| Desventaja | `roll.lowest_values()[0]` |
| 4d6 sacando el más bajo | `roll.sum() - roll.lowest_values()[0]` |
| Marcar los dos dados más altos | `roll.highest(2)`: sus lugares, para `tray.face_on_top(slot)` o tu vista |
| Volver a tirar los blancos | `roll = roll.rerolled(roll.slots_with(&"blank"), roller.rng)` y `tray.show_roll(roll)` |
| Las mismas tiradas en cada partida | `rng_seed` distinto de 0 en el inspector |
| Que los dados usen el rng de la partida | `roller.rng = match_rng` |
| Tirar desde las reglas, sin nodos | `die.roll(3, rng)` |
| Mostrar el resultado cuando caen | `tray.settled.connect(_show_result)` |
| Sin animación | `tray.tumble_time = 0` |
| Que un d8 se vea como un d8, también entre otros dados | Tu malla de d8 en el `mesh` de su `DieData` |
| Otra forma para todos los dados | Tu malla en `die_mesh` de la bandeja (los dados con `mesh` propio lo conservan) |
| Muchos dados | `per_row` en la bandeja: más filas, no una fila larga |
| Mandar una tirada por red | `roll.to_dict()`; del otro lado, `DiceRoll.from_dict(roller.pool(), data)` y `tray.show_roll(roll)` |
| Guardar y seguir la misma secuencia | Guardá `roller.rng.state`; al cargar, `roller.rng.state = saved` |
| Un texto para el registro | `roll.describe()` |
| Probar el dado sin correr el juego | **Roll** en el inspector del `DiceRoller` |

## Tips

- **Las reglas usan `DieData` y un rng, no el nodo.** `attack_die.roll(3, match_rng)` es todo lo que necesita una regla, y se testea sin escena. El `DiceRoller` es para el editor y para la bandeja.
- **En red, tira el servidor.** El servidor tira y manda `roll.to_dict()`; cada cliente arma la misma tirada con `DiceRoll.from_dict(roller.pool(), data)` (o con los dados que conoce el juego) y la muestra con `tray.show_roll(roll)`. Otra opción es compartir la semilla de la partida y tirar en el mismo orden en todas las máquinas.
- **Los dados listos son del kit.** Reinstalar el kit pisa `addons/dice_kit/dice/`: copiá el `.tres` a una carpeta de tu juego antes de editarlo (un ícono en el 8 de un d8, por ejemplo).
- **El significado es del juego.** `hit`, `crit` o `blank` son símbolos: cuánto daño hace un crítico lo deciden tus reglas.

## Tests

```bash
godot --headless --path dicekit_lab --script res://addons/dice_kit/tests/dice_test_runner.gd
```

Sale `DICEKIT TESTS PASS (n)`. Los tests cubren:

- Las caras y sus símbolos (también una cara guardada con el `tag` de antes), los dados con números, los dados listos de `dice/`, los errores al tirar, que un dado con un lugar vacío no tire ni saque números, y los cambios en vivo.
- La tirada: suma, conteos con varios símbolos por cara, `slots_with`, los más altos y los más bajos, `rerolled` (con su secuencia fija), que no se pueda cambiar, `describe`, dados mezclados, la misma semilla en varias semillas, una secuencia fija (d6 con semilla 12345 y d20 con 2026), un número del rng por dado, `to_dict` por JSON y los errores.
- El nodo: `count`, `rolled` y `last_roll`, `extra_dice` y `pool()`, `rng_seed`, dos rollers con semilla 0 que no repiten, un rng asignado que `rng_seed` no toca, `dice_changed`, el botón Roll con `last_result` y los avisos.
- La bandeja: los dados en reposo, girar y caer con la cara que salió, qué se dibuja arriba, que la misma tirada gire igual sin sacar ningún número al azar, las filas, una malla para todos y una por dado, seguir al roller sin preguntar en cada cuadro, el tamaño y la separación.
- El ejemplo jugado con los botones, también con la misma semilla dos veces.
- Que el addon no nombre a ningún otro kit ni llame al azar global.

En el editor real, el lab tiene un chequeo que abre el ejemplo, cambia el roller desde el inspector, aprieta **Roll** y mira `last_result` y los dados de la bandeja en la vista 3D:

```bash
godot --headless --editor --path dicekit_lab -- --dicekit-editor-check
```

Sale `DICEKIT EDITOR CHECK PASS (n)`.
