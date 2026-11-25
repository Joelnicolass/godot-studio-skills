# WalletKit changes

## 0.3.0

- New: substitutes with a rate. `Purse.add_substitute(key, covers, rate)`: `rate` of `key` pay for 1 that is missing of any of `covers` (empty: any other key). `substitutes()`, `substitutes_for(key)`, `clear_substitutes()`. The payment plan is fixed and written in the README: what is its own for each key of the cost first, then the substitutes in list order.
- New: `WalletSubstitute` resource (`key`, `covers`, `rate`) and `Wallet.substitutes`. Changing the list or a value of a resource applies at once to the own purse; never to a `use_purse` one. Editor warnings for an empty slot, an empty `key`, a substitute that covers itself and two identical rules.
- Changed: `wildcard` and `wildcard_covers` are gone (from `Purse` and from `Wallet`), and `Purse.new` no longer takes the wildcard. A wildcard is a substitute with no `covers`. `covers(key)` becomes `substitutes_for(key)`. `to_dict()` saves `substitutes`; `from_dict` still reads the old format. See "Migrating from 0.2" in the README.
- `payment_for` returns the keys in alphabetical order, with a single entry per key.
- `minimal` example: two substitutes in the inspector (2 food cover 1 wood; gold covers anything at 1) and the log says what it took.

## 0.2.0

- New: `rebuilt` signal on `Wallet` when it starts showing another purse (`use_purse`, `use_own_purse` or new `start_amounts`), so a HUD that switches players redraws everything.
- README: the example's buttons are named as they read on screen.

## 0.1.0

First version:

- `Purse`: whole amounts by key as plain data. Limits that return what is lost, all-or-nothing payments, a wildcard that covers 1 to 1 with its list of keys, `payment_for` and `to_dict` / `from_dict`. Results in a fixed order.
- `Wallet`: builds the purse from the inspector or shows your rules' purse (`use_purse`).
- Example `examples/minimal`, the kit's own tests and `walletkit_lab/`.
