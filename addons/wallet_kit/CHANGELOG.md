# WalletKit changes

## 0.1.0

First version:

- `Purse`: whole amounts by key as plain data. Limits that return what is lost, all-or-nothing payments, a wildcard that covers 1 to 1 with its list of keys, `payment_for` and `to_dict` / `from_dict`. Results in a fixed order.
- `Wallet`: builds the purse from the inspector or shows your rules' purse (`use_purse`).
- Example `examples/minimal`, the kit's own tests and `walletkit_lab/`.
