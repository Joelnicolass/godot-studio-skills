# WalletKit

Recursos y monedas para juegos de estrategia, gestión, crafting, tiendas o de mesa. Hay dos niveles:

- **`Purse`**: los montos como datos puros (`RefCounted`, sin nodos ni escena). Guarda un número entero por clave, con topes opcionales, y un comodín que cubre lo que falta al pagar. Las reglas de tu juego lo usan directo y se testea headless.
- **`Wallet`** (Node): arma o muestra un `Purse` con los valores del inspector.

WalletKit **no tiene** precios, tiendas, UI, red ni autoload. Qué cuesta cada cosa lo decide tu juego.

## Instalar

```bash
./install.sh --addon /path/to/godot-project wallet_kit
```

Habilitá el plugin **WalletKit** (tipo `Wallet` en Create Node).

## En 3 pasos

1. Agregá un `Wallet`.
2. En el inspector poné `start_amounts` (por ejemplo `food: 2`), `limits` (por ejemplo `food: 2, wood: 7`) y, si querés, un `wildcard` (por ejemplo `gold`).
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

`examples/minimal/minimal.tscn` (F6): comida, madera, mineral y oro. Cosechar suma 1 comida, 2 de madera y 1 de mineral; la comida tiene tope 2, así que lo que sobra se pierde y se avisa. Construir cuesta 2 de madera y 1 de mineral, y el oro cubre lo que falta.

```
Minimal          # minimal.gd: muestra los montos y conecta los botones
├── Box          # montos, botones Cosechar y Construir, registro
└── Wallet       # start = {food: 2, gold: 1}, limits = {food: 2, …}, wildcard = gold
```

## Cómo cuenta

- **Montos:** enteros desde 0. Una clave que nunca se sumó vale 0. Las claves son `StringName`, y `String` también sirve.
- **Topes:** una clave sin tope no tiene límite. Lo que pasa del tope se pierde: `add()` lo devuelve como `{clave: perdido}` y emite `overflowed`.
- **Pagar:** `pay(cost)` paga todo o nada. Si `can_pay(cost)` es false, no cambia nada.
- **Comodín:** cubre 1 a 1 lo que falta de las claves de `wildcard_covers` (si la lista está vacía, de todas menos él mismo).
  - Primero se usa lo propio de cada clave, después el comodín.
  - Si el costo pide el comodín directamente, eso se cuenta primero.
  - `payment_for(cost)` dice qué se cobraría, con el comodín incluido, sin cobrar nada.
- **Errores:** un monto negativo en un costo o en `add()` es un error y no cambia nada.
- **Determinismo:** las claves se recorren en orden alfabético, así las señales y los pagos salen igual en cada máquina. `to_dict()` y `Purse.from_dict()` guardan todo.

## API

### `Purse` (RefCounted)

| Miembro | Qué hace |
| --- | --- |
| `Purse.new(start, limits, wildcard)` | Una bolsa. Todo es opcional |
| `amount(key)`, `amounts()`, `keys()` | Los montos |
| `limit(key)` (-1 = sin tope), `has_limit(key)`, `set_limit(key, value) -> int` | Los topes. `set_limit` devuelve lo que ya no entra; un valor negativo quita el tope |
| `set_amount(key, value) -> int` | Fija un monto y devuelve lo que no entró |
| `add(gains) -> Dictionary` | Suma y devuelve lo perdido por tope |
| `can_pay(cost)`, `payment_for(cost)`, `pay(cost) -> bool` | Pagar, con el comodín |
| `wildcard`, `wildcard_covers`, `covers(key)` | El comodín |
| `to_dict()` / `Purse.from_dict(data)` | Datos planos para guardar, mandar por red o comparar un replay |
| señales `changed(key, value)`, `overflowed(key, lost)` | En pasado: ya ocurrió |

### `Wallet` (Node)

- **Inspector:** `start_amounts`, `limits`, `wildcard` y `wildcard_covers`. Cambiar los topes o el comodín en el juego se aplica al momento; cambiar `start_amounts` arma la bolsa de nuevo.
- **Bolsa:** `purse` es el `Purse` que muestra. `use_purse(purse)` muestra el de tus reglas y `use_own_purse()` vuelve al del inspector.
- **Métodos:** los mismos de `Purse` (`amount`, `amounts`, `limit`, `can_pay`, `payment_for`, `pay`, `add`, `set_amount`).
- **Señales:** las mismas de `Purse`.

## Tips

- **Las reglas usan `Purse`, no el nodo.** Guardá una bolsa por jugador en el estado de tu partida y mostrala con `wallet.use_purse(player.purse)`. El HUD escucha `changed`.
- **Fichas que no son recursos** (cultura, ánimo): usá otras claves y dejalas fuera de `wildcard_covers`, así el comodín no las cubre.
- **Un costo para mostrar:** `payment_for(cost)` sirve para decirle al jugador cuánto oro va a gastar antes de confirmar.

## Tests

```bash
godot --headless --path walletkit_lab --script res://addons/wallet_kit/tests/wallet_test_runner.gd
```

Sale `WALLETKIT TESTS PASS (n)`. Los tests cubren:

- Montos, topes y lo que se pierde, pagar todo o nada, el comodín y su lista, los errores y `to_dict`.
- El nodo: la bolsa del inspector, las señales, los cambios en vivo, `use_purse` y los avisos del editor.
- El ejemplo jugado con los botones.
- Que el addon no nombre a ningún otro kit.
