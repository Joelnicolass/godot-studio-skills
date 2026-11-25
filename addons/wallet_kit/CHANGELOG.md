# Cambios de WalletKit

## 0.1.0

Primera versión:

- `Purse`: montos enteros por clave como datos puros. Topes que devuelven lo perdido, pagar todo o nada, un comodín que cubre 1 a 1 con su lista de claves, `payment_for` y `to_dict` / `from_dict`. Resultados en orden fijo.
- `Wallet`: arma la bolsa desde el inspector o muestra la de tus reglas (`use_purse`).
- Ejemplo `examples/minimal`, tests propios y `walletkit_lab/`.
