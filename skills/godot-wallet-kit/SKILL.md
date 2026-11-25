---
name: godot-wallet-kit
description: >-
  Recursos y monedas en un juego Godot 4 con el addon WalletKit: un número
  entero por clave (madera, oro, comida), con topes que devuelven lo perdido,
  pagar todo o nada, sustitutos con tasa que cubren lo que falta (el oro cubre
  cualquier cosa 1 a 1; 2 de comida cubren 1 de madera) con un plan de pago
  fijo y `payment_for` para mostrar el costo antes de cobrar, y guardar y
  restaurar con `to_dict`. Un `Purse` de datos puros para las reglas y un nodo
  `Wallet` para el editor. Usar cuando el usuario quiere recursos, monedas, un
  costo que se paga, topes de almacén, un comodín o una moneda que reemplaza a
  otra, o /add-wallet. No son precios, tiendas ni UI, ni la red.
---

# Godot — recursos y monedas (WalletKit)

Addon `addons/wallet_kit/` en el proyecto del **juego**. Referencia: `addons/wallet_kit/README.md`.

Si el addon no está:

```bash
./install.sh --addon /path/to/godot-project wallet_kit
```

Habilitá el plugin **WalletKit** (tipo `Wallet` en Create Node; `WalletSubstitute` en New Resource). Pedido acotado: `/add-wallet`. Composición: [godot-composition-first](../godot-composition-first/SKILL.md).

## Reglas

- **Dos niveles.** Las reglas del juego guardan un `Purse` por jugador (datos puros, se testea headless). El `Wallet` es el nodo que lo arma con los valores del inspector o muestra el de tus reglas (`use_purse`).
- **Enteros desde 0.** Las claves son `StringName` (`&"wood"`). Un monto negativo en un costo o en `add()` es un error y no cambia nada.
- **Topes.** Una clave sin tope no tiene límite. Lo que pasa del tope se pierde: `add()` lo devuelve como `{clave: perdido}` y se emite `overflowed`.
- **Pagar es todo o nada.** `can_pay(cost)` antes; `pay(cost)` no cambia nada si no alcanza. Para mostrar cuánto se gastará, `payment_for(cost)`: es exactamente lo que `pay` cobra.
- **Sustitutos, no comodines.** `add_substitute(key, covers, rate)` o un `WalletSubstitute` en `Wallet.substitutes`: `rate` de `key` pagan 1 de lo que falte de `covers` (vacío: cualquier otra clave). Un «comodín» es un sustituto sin `covers`. Lo que no se debe cubrir (cultura, ánimo) queda fuera de `covers`.
- **El plan de pago es fijo.** Primero lo propio de cada clave del costo; después los sustitutos en el orden de la lista. Es voraz: poné primero el sustituto más específico. Sin cadenas: un sustituto paga con lo que tiene.
- **Editor primero.** `start_amounts`, `limits` y `substitutes` se configuran en el inspector, y cambiarlos en vivo se aplica al momento. El nodo avisa de un lugar vacío, un `key` vacío, un sustituto que se cubre a sí mismo y reglas repetidas.
- **El HUD escucha.** `changed` por cada monto, `overflowed` por lo perdido, `rebuilt` para redibujar todo cuando el nodo pasa a mostrar otra bolsa.
- **Guardar.** `to_dict()` y `Purse.from_dict()` guardan montos, topes y sustitutos en orden fijo.
- **Ningún kit depende de otro.** WalletKit no tiene precios, tiendas, UI, red ni autoload: el juego conecta. En red, el servidor decide el pago y manda montos.

## Árbol

```
Level
├── Wallet                               # start_amounts, limits
│   └── (substitutes)                    # [food → wood a 2, gold → todo a 1] como recursos del inspector
├── Hud (Control)                        # escucha changed / rebuilt y muestra los montos
└── Shop (Button)                        # can_pay(cost) → disabled; pay(cost)
```

Arrancá desde `addons/wallet_kit/examples/minimal/minimal.tscn`.

## Qué va dónde

| Kit | Juego |
|---|---|
| Los montos, los topes, qué se pierde | Cuánto vale cada cosa, qué cuesta construir o comprar |
| Pagar todo o nada, el plan con sustitutos, `payment_for` | Cuándo se cobra, quién paga, qué pasa si no alcanza |
| Qué sustitutos hay y a qué tasa | Qué fichas existen y cuáles se pueden reemplazar |
| `changed`, `overflowed`, `rebuilt` | El HUD, las animaciones, los avisos |
| `to_dict` / `from_dict` | Dónde se guarda y cómo viaja por la red |

## Listo cuando

- El `Wallet` no muestra avisos y los sustitutos se ven en el inspector.
- F6: sumar pasa el tope y se pierde con aviso; pagar con lo propio, luego con los sustitutos en orden; sin alcanzar no cambia nada.
- `payment_for` muestra al jugador lo que `pay` cobra.
- `godot --headless --path walletkit_lab --script res://addons/wallet_kit/tests/wallet_test_runner.gd` da `WALLETKIT TESTS PASS` (en el repo del kit).

## Antipatrones

- Precios o reglas de tienda dentro del kit: el costo lo arma el juego.
- Un `Purse` por jugador creado desde el nodo: las reglas lo guardan y el nodo lo muestra con `use_purse`.
- Cambiar los montos con `set_amount` para cobrar: usá `pay`, que es todo o nada.
- Un sustituto que cubre fichas que no deben cubrirse: listá en `covers` solo lo cubrible.
- Guardar el estado de las reglas en el nodo: el nodo es una vista.
- Esperar cadenas (comida → madera → oro): un sustituto paga solo con lo que tiene.
