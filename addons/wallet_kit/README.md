# WalletKit

Recursos y monedas para juegos de estrategia, gestión, crafting, tiendas o de mesa. Hay dos niveles:

- **`Purse`**: los montos como datos puros (`RefCounted`, sin nodos ni escena). Guarda un número entero por clave, con topes opcionales, y sustitutos que cubren lo que falta al pagar, con una tasa. Las reglas de tu juego lo usan directo y se testea headless.
- **`Wallet`** (Node): arma o muestra un `Purse` con los valores del inspector.

WalletKit **no tiene** precios, tiendas, UI, red ni autoload. Qué cuesta cada cosa lo decide tu juego.

## Instalar

```bash
./install.sh --addon /path/to/godot-project wallet_kit
```

Habilitá el plugin **WalletKit** (tipo `Wallet` en Create Node).

## En 3 pasos

1. Agregá un `Wallet`.
2. En el inspector poné `start_amounts` (por ejemplo `food: 2`), `limits` (por ejemplo `food: 2, wood: 7`) y, si querés, `substitutes`: una lista de `WalletSubstitute` (por ejemplo `gold` sin `covers`: el oro cubre lo que falte de cualquier cosa).
3. Pagá y sumá:

```gdscript
@onready var wallet: Wallet = $Wallet


func build_temple() -> bool:
	var cost := {&"wood": 2, &"ore": 1}
	if not wallet.can_pay(cost):
		return false
	return wallet.pay(cost)


func harvest() -> void:
	var lost := wallet.add({&"food": 1, &"wood": 2})
	for key in lost:
		print("Se perdieron %d de %s por el tope" % [lost[key], key])
```

## Ejemplo mínimo

`examples/minimal/minimal.tscn` (F6): comida, madera, mineral y oro. **Harvest** suma 1 comida, 2 de madera y 1 de mineral; la comida tiene tope 2, así que lo que sobra se pierde y se avisa. **Build (2 wood, 1 ore)** cuesta 2 de madera y 1 de mineral, y lo que falta lo cubren dos sustitutos del inspector, en este orden: 2 de comida cubren 1 de madera, y el oro cubre cualquier cosa 1 a 1. El registro dice lo que se cobró.

```
Minimal          # minimal.gd: muestra los montos y conecta los botones
├── Box          # montos, botones Harvest y Build, registro
└── Wallet       # start = {food: 2, gold: 1}, limits = {food: 2, …}
                 # substitutes = [food → wood a 2, gold → todo a 1]
```

## Cómo cuenta

- **Montos:** enteros desde 0. Una clave que nunca se sumó vale 0. Las claves son `StringName`, y `String` también sirve.
- **Topes:** una clave sin tope no tiene límite. Lo que pasa del tope se pierde: `add()` lo devuelve como `{clave: perdido}` y emite `overflowed`.
- **Pagar:** `pay(cost)` paga todo o nada. Si `can_pay(cost)` es false, no cambia nada.
- **Sustitutos:** `rate` de una clave pagan 1 de lo que falta de otra. `covers` dice qué puede cubrir (vacío: cualquier clave menos la suya). Un sustituto nunca cubre su propia clave. Paga solo con lo que tiene: no hay cadenas, nadie «fabrica» stock para otro.
  - `gold` sin `covers`, tasa 1: el oro cubre lo que falte de cualquier cosa, 1 a 1.
  - `wood` cubriendo `gold`, tasa 2: 2 de madera cubren 1 de oro. Con 3 de madera se cubre 1, no 1,5.
  - Varias reglas pueden usar la misma clave con otra tasa o lista (oro cubre mineral a 1 y cultura a 3): comparten lo que queda de oro.
- **El plan de pago** es siempre el mismo:
  1. Se aparta lo propio: de cada clave del costo (en orden alfabético) se toma lo que haya, hasta lo que pide. Así un sustituto nunca gasta lo que el mismo costo le pide directo.
  2. A cada clave a la que le falta (en orden alfabético) se le aplican los sustitutos **en el orden de la lista** que la cubren. Cada uno cubre todas las unidades que pueda con lo que le queda (`floor(queda / tasa)`) y cobra `unidades × tasa`.
  3. Si a alguna clave le sigue faltando, no se puede pagar y no cambia nada.
- **Ejemplo 1** (1 a 1). Bolsa `wood 1, gold 2`, sustituto `gold`. Costo `wood 2, ore 1`. Paso 1: toma 1 de madera. Paso 2: falta 1 de madera y 1 de mineral; el oro cubre las dos. Se cobra `gold 2, wood 1`.
- **Ejemplo 2** (tasa 2). Bolsa `food 5, gold 1`, sustitutos `[food cubre wood a 2, gold]`. Costo `wood 3, ore 1`. Paso 1: no hay madera propia. Paso 2: `ore` (orden alfabético) lo cubre el oro: cobra 1. Después a `wood` le faltan 3: la comida cubre `floor(5 / 2) = 2` y el oro ya no tiene. Sigue faltando 1: no se puede pagar. Con `food 6` cubre 3 y se cobra `food 6, gold 1`.
- **El plan es voraz:** puede decir que no cuando una asignación más rebuscada alcanzaría. Poné primero el sustituto más específico.
- `payment_for(cost)` dice qué se cobraría, en una sola entrada por clave (lo directo y lo que cubrió un sustituto), sin cobrar nada. Es exactamente lo que `pay(cost)` cobra.
- **Errores:** un monto negativo en un costo o en `add()` es un error y no cambia nada.
- **Determinismo:** las claves se recorren en orden alfabético, así las señales y los pagos salen igual en cada máquina. `to_dict()` y `Purse.from_dict()` guardan todo, sustitutos incluidos.

## API

### `Purse` (RefCounted)

| Miembro | Qué hace |
| --- | --- |
| `Purse.new(start, limits)` | Una bolsa. Todo es opcional |
| `amount(key)`, `amounts()`, `keys()` | Los montos |
| `limit(key)` (-1 = sin tope), `has_limit(key)`, `set_limit(key, value) -> int` | Los topes. `set_limit` devuelve lo que ya no entra; un valor negativo quita el tope |
| `set_amount(key, value) -> int` | Fija un monto y devuelve lo que no entró |
| `add(gains) -> Dictionary` | Suma y devuelve lo perdido por tope |
| `can_pay(cost)`, `payment_for(cost)`, `pay(cost) -> bool` | Pagar, con los sustitutos. `payment_for` devuelve `{clave: cobrado}` |
| `add_substitute(key, covers = [], rate = 1)` | `rate` de `key` pagan 1 de lo que falte de cualquiera de `covers` (vacío: cualquier otra clave). Una tasa menor a 1, una clave vacía o un `covers` que la incluye es un error y no agrega |
| `substitutes()`, `substitutes_for(key)`, `clear_substitutes()` | Las reglas (copias `{key, covers, rate}`, en orden), las que cubren `key` y sacarlas todas |
| `to_dict()` / `Purse.from_dict(data)` | Datos planos para guardar, mandar por red o comparar un replay |
| señales `changed(key, value)`, `overflowed(key, lost)` | En pasado: ya ocurrió |

### `Wallet` (Node)

- **Inspector:** `start_amounts`, `limits` y `substitutes` (una lista de `WalletSubstitute` con `key`, `covers` y `rate`, en orden de prioridad). Cambiar los topes, la lista o un valor de un sustituto se aplica al momento; cambiar `start_amounts` arma la bolsa de nuevo. Nunca toca una bolsa de `use_purse`.
- **Avisos del editor:** un monto negativo, un inicio sobre el tope, un lugar vacío en `substitutes`, un `key` vacío, un sustituto que se cubre a sí mismo y dos reglas idénticas.
- **Bolsa:** `purse` es el `Purse` que muestra. `use_purse(purse)` muestra el de tus reglas y `use_own_purse()` vuelve al del inspector.
- **Métodos:** los mismos de `Purse` (`amount`, `amounts`, `limit`, `can_pay`, `payment_for`, `pay`, `add`, `set_amount`) y `substitutes_for`.
- **Señales:** las mismas de `Purse`, más `rebuilt` cuando el nodo pasa a mostrar otra bolsa (`use_purse`, `use_own_purse` o `start_amounts` nuevos). Al recibirla, volvé a leer todos los montos.

## Migrar desde 0.2

| Antes (0.2) | Ahora (0.3) |
| --- | --- |
| `Purse.new(start, limits, wildcard)` y `purse.wildcard_covers = [...]` | `Purse.new(start, limits)` y `purse.add_substitute(wildcard, covers)` |
| `Wallet.wildcard`, `Wallet.wildcard_covers` | `Wallet.substitutes`: un `WalletSubstitute` con `key` y `covers` |
| `purse.covers(key)` | `purse.substitutes_for(key)` (las reglas que cubren esa clave, en orden) |
| `to_dict()` con `wildcard` y `wildcard_covers` | `to_dict()` con `substitutes`; `from_dict` lee los dos formatos (el viejo queda como un sustituto de tasa 1) |

Una escena vieja que tenía `wildcard` o `wildcard_covers` guardados: Godot ignora la propiedad que ya no existe, así que hay que cargarlos de nuevo como `substitutes`.

## Tips

- **Las reglas usan `Purse`, no el nodo.** Guardá una bolsa por jugador en el estado de tu partida y mostrala con `wallet.use_purse(player.purse)`. El HUD escucha `changed` para cada cambio y `rebuilt` para redibujar todo, por ejemplo cuando cambia el jugador que se muestra.
- **Un comodín** es UN sustituto sin `covers`. **Fichas que no se deben cubrir** (cultura, ánimo): usá otras claves y listá en `covers` solo lo cubrible, así no las cubre nadie.
- **Código en vez del inspector:** `add_substitute` es lo mismo que un `WalletSubstitute`. En un `Purse` de tus reglas, `purse.add_substitute(&"gold")`.
- **Un costo para mostrar:** `payment_for(cost)` sirve para decirle al jugador cuánto oro va a gastar antes de confirmar.

## Tests

```bash
godot --headless --path walletkit_lab --script res://addons/wallet_kit/tests/wallet_test_runner.gd
```

Sale `WALLETKIT TESTS PASS (n)`. Los tests cubren:

- Montos, topes y lo que se pierde, pagar todo o nada, los sustitutos (1 a 1, con lista, con tasa, el orden, la misma clave con dos tasas, que no cambie nada si falta), `payment_for` contra lo que cobra `pay`, los errores y `to_dict` (también el formato de 0.2).
- El nodo: la bolsa del inspector, las señales, los cambios en vivo (también el `rate` de un recurso), `use_purse`, `rebuilt` y los avisos del editor.
- El ejemplo jugado con los botones.
- Que el addon no nombre a ningún otro kit.
