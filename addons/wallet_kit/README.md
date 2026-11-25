# WalletKit

Resources and coins for strategy, management, crafting, shop or board games. It has two levels:

- **`Purse`**: the amounts as plain data (`RefCounted`, no nodes, no scene). It keeps a whole number per key, with optional limits, and a wildcard that covers what is missing when paying. Your game's rules use it directly, and it tests headless.
- **`Wallet`** (Node): builds or shows a `Purse` with the values from the inspector.

WalletKit has **no** prices, shops, UI, network or autoload. What each thing costs is up to your game.

## Install

```bash
./install.sh --addon /path/to/godot-project wallet_kit
```

Enable the **WalletKit** plugin (type `Wallet` in Create Node).

## In 3 steps

1. Add a `Wallet`.
2. In the inspector set `start_amounts` (for example `food: 2`), `limits` (for example `food: 2, wood: 7`) and, if you want, a `wildcard` (for example `gold`).
3. Pay and add:

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
		print("%d %s lost to the limit" % [lost[key], key])
```

## Minimal example

`examples/minimal/minimal.tscn` (F6): food, wood, ore and gold. **Harvest** adds 1 food, 2 wood and 1 ore; food holds 2, so the rest is lost and reported. **Build (2 wood, 1 ore)** costs 2 wood and 1 ore, and gold covers what is missing.

```
Minimal          # minimal.gd: shows the amounts and connects the buttons
├── Box          # amounts, Harvest and Build buttons, log
└── Wallet       # start = {food: 2, gold: 1}, limits = {food: 2, …}, wildcard = gold
```

## How it counts

- **Amounts:** whole numbers from 0 up. A key never added is 0. Keys are `StringName`; `String` works too.
- **Limits:** a key without a limit has none. What goes past the limit is lost: `add()` returns it as `{key: lost}` and emits `overflowed`.
- **Paying:** `pay(cost)` pays all or nothing. When `can_pay(cost)` is false, nothing changes.
- **Wildcard:** covers, 1 to 1, what is missing of the keys in `wildcard_covers` (when the list is empty, of every key but itself).
  - Each key's own amount goes first, then the wildcard.
  - If the cost asks for the wildcard itself, that counts first.
  - `payment_for(cost)` tells what would be taken, the wildcard included, without taking anything.
- **Errors:** a negative amount in a cost or in `add()` is an error and changes nothing.
- **Determinism:** keys are walked in alphabetical order, so signals and payments come out the same on every machine. `to_dict()` and `Purse.from_dict()` keep everything.

## API

### `Purse` (RefCounted)

| Member | What it does |
| --- | --- |
| `Purse.new(start, limits, wildcard)` | A purse. All optional |
| `amount(key)`, `amounts()`, `keys()` | The amounts |
| `limit(key)` (-1 = no limit), `has_limit(key)`, `set_limit(key, value) -> int` | The limits. `set_limit` returns what no longer fits; a negative value takes the limit away |
| `set_amount(key, value) -> int` | Sets an amount and returns what did not fit |
| `add(gains) -> Dictionary` | Adds and returns what was lost to the limits |
| `can_pay(cost)`, `payment_for(cost)`, `pay(cost) -> bool` | Paying, with the wildcard |
| `wildcard`, `wildcard_covers`, `covers(key)` | The wildcard |
| `to_dict()` / `Purse.from_dict(data)` | Plain data to save, send over the network or compare a replay |
| signals `changed(key, value)`, `overflowed(key, lost)` | Past tense: it already happened |

### `Wallet` (Node)

- **Inspector:** `start_amounts`, `limits`, `wildcard` and `wildcard_covers`. Changing the limits or the wildcard in game applies at once; changing `start_amounts` builds the purse again.
- **Purse:** `purse` is the `Purse` it shows. `use_purse(purse)` shows your rules' purse and `use_own_purse()` goes back to the inspector's.
- **Methods:** the same as `Purse` (`amount`, `amounts`, `limit`, `can_pay`, `payment_for`, `pay`, `add`, `set_amount`).
- **Signals:** the same as `Purse`, plus `rebuilt` when the node starts showing another purse (`use_purse`, `use_own_purse` or new `start_amounts`). When it arrives, read every amount again.

## Tips

- **Rules use `Purse`, not the node.** Keep one purse per player in your match state and show it with `wallet.use_purse(player.purse)`. The HUD listens to `changed` for each change and to `rebuilt` to redraw everything, for example when the player shown changes.
- **Tokens that are not resources** (culture, mood): use other keys and leave them out of `wildcard_covers`, so the wildcard does not cover them.
- **A cost to show:** `payment_for(cost)` tells the player how much gold they will spend before they confirm.

## Tests

```bash
godot --headless --path walletkit_lab --script res://addons/wallet_kit/tests/wallet_test_runner.gd
```

It prints `WALLETKIT TESTS PASS (n)`. The tests cover:

- Amounts, limits and what is lost, all-or-nothing payments, the wildcard and its list, errors and `to_dict`.
- The node: the purse from the inspector, signals, live changes, `use_purse`, `rebuilt` and the editor warnings.
- The example played with its buttons.
- That the addon names no other kit.
