# Cambios de WalletKit

## 0.3.0

- Nuevo: sustitutos con tasa. `Purse.add_substitute(key, covers, rate)`: `rate` de `key` pagan 1 de lo que falte de cualquiera de `covers` (vacío: cualquier otra clave). `substitutes()`, `substitutes_for(key)`, `clear_substitutes()`. El plan de pago es fijo y está en el README: primero lo propio de cada clave del costo, después los sustitutos en el orden de la lista.
- Nuevo: recurso `WalletSubstitute` (`key`, `covers`, `rate`) y `Wallet.substitutes`. Cambiar la lista o un valor de un recurso se aplica al momento a la bolsa propia; nunca a una de `use_purse`. Avisos del editor para un lugar vacío, un `key` vacío, un sustituto que se cubre a sí mismo y dos reglas idénticas.
- Cambia: `wildcard` y `wildcard_covers` desaparecen (de `Purse` y de `Wallet`), y `Purse.new` ya no recibe el comodín. Un comodín es un sustituto sin `covers`. `covers(key)` pasa a `substitutes_for(key)`. `to_dict()` guarda `substitutes`; `from_dict` sigue leyendo el formato viejo. Ver «Migrar desde 0.2» en el README.
- `payment_for` devuelve las claves en orden alfabético, con una sola entrada por clave.
- Ejemplo `minimal`: dos sustitutos en el inspector (2 de comida cubren 1 de madera; el oro cubre todo a 1) y el registro dice lo que cobró.

## 0.2.0

- Nuevo: señal `rebuilt` en `Wallet` cuando pasa a mostrar otra bolsa (`use_purse`, `use_own_purse` o `start_amounts` nuevos), para que un HUD que cambia de jugador redibuje todo.
- README: los botones del ejemplo se nombran como en pantalla.

## 0.1.0

Primera versión:

- `Purse`: montos enteros por clave como datos puros. Topes que devuelven lo perdido, pagar todo o nada, un comodín que cubre 1 a 1 con su lista de claves, `payment_for` y `to_dict` / `from_dict`. Resultados en orden fijo.
- `Wallet`: arma la bolsa desde el inspector o muestra la de tus reglas (`use_purse`).
- Ejemplo `examples/minimal`, tests propios y `walletkit_lab/`.
