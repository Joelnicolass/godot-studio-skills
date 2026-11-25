# <img src="icons/wallet_kit.svg" width="32" height="32" alt=""> WalletKit

Resources and coins for strategy, management, crafting, shop or board games. It has two levels:

- **`Purse`**: the amounts as plain data (`RefCounted`, no nodes, no scene). It keeps a whole number per key, with optional limits, and substitutes that cover what is missing when paying, at a rate. Your game's rules use it directly, and it tests headless.
- **`Wallet`** (Node): builds or shows a `Purse` with the values from the inspector.

WalletKit has **no** prices, shops, UI, network or autoload. What each thing costs is up to your game.

## Install

```bash
./install.sh --addon /path/to/godot-project wallet_kit
```

Enable the **WalletKit** plugin (type `Wallet` in Create Node).

## In 3 steps

1. Add a `Wallet`.
2. In the inspector set `start_amounts` (for example `food: 2`), `limits` (for example `food: 2, wood: 7`) and, if you want, `substitutes`: a list of `WalletSubstitute` (for example `gold` with no `covers`: gold covers what is missing of anything).
3. Pay and add. Building the temple costs 2 wood and 1 ore (if it falls short, nothing is charged), and harvesting adds food and wood and reports what the limit made you lose:

```gdscript
@onready var wallet: Wallet = %Wallet


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

`examples/minimal/minimal.tscn` (F6): food, wood, ore and gold. **Harvest** adds 1 food, 2 wood and 1 ore; food holds 2, so the rest is lost and reported. **Build (2 wood, 1 ore)** costs 2 wood and 1 ore, and two substitutes from the inspector cover what is missing, in this order: 2 food cover 1 wood, and gold covers anything 1 to 1. The log says what was taken.

```
Minimal          # minimal.gd: shows the amounts and connects the buttons
├── Box          # amounts, Harvest and Build buttons, log
└── %Wallet      # start = {food: 2, gold: 1}, limits = {food: 2, …}
                 # substitutes = [food → wood at 2, gold → anything at 1]
```

## How it counts

- **Amounts:** whole numbers from 0 up. A key never added is 0. Keys are `StringName`; `String` works too.
- **Limits:** a key without a limit has none. What goes past the limit is lost: `add()` returns it as `{key: lost}` and emits `overflowed`.
- **Paying:** `pay(cost)` pays all or nothing. When `can_pay(cost)` is false, nothing changes.
- **Substitutes:** `rate` of a key pay for 1 that is missing of another. `covers` says what it can cover (empty: any key but its own). A substitute never covers its own key. It pays only with what it has: there are no chains, nobody "makes" stock for another.
  - `gold` with no `covers`, rate 1: gold covers what is missing of anything, 1 to 1.
  - `wood` covering `gold`, rate 2: 2 wood cover 1 gold. With 3 wood it covers 1, not 1.5.
  - Several rules can use the same key with another rate or list (gold covers ore at 1 and culture at 3): they share what is left of the gold.
- **The payment plan** is always the same:
  1. What is its own is set aside: from each key of the cost (in alphabetical order) it takes what there is, up to what is asked. So a substitute never spends what the cost asks of it directly.
  2. Each key that is short (in alphabetical order) gets the substitutes that cover it, **in list order**. Each covers as many units as it can with what it has left (`floor(left / rate)`) and takes `units × rate`.
  3. If a key is still short, it cannot be paid and nothing changes.
- **Example 1** (1 to 1). Purse `wood 1, gold 2`, substitute `gold`. Cost `wood 2, ore 1`. Step 1: takes 1 wood. Step 2: 1 wood and 1 ore are missing; gold covers both. It takes `gold 2, wood 1`.
- **Example 2** (rate 2). Purse `food 5, gold 1`, substitutes `[food covers wood at 2, gold]`. Cost `wood 3, ore 1`. Step 1: no wood of its own. Step 2: `ore` (alphabetical order) is covered by gold: takes 1. Then `wood` is short 3: food covers `floor(5 / 2) = 2` and gold has none left. 1 is still missing: it cannot be paid. With `food 6` it covers 3 and takes `food 6, gold 1`.
- **The plan is greedy:** it can say no when a more convoluted assignment would have worked. Put the most specific substitute first.
- `payment_for(cost)` tells what would be taken, in a single entry per key (what is direct and what a substitute covered), without taking anything. It is exactly what `pay(cost)` takes.
- **Errors:** a negative amount in a cost or in `add()` is an error and changes nothing.
- **Determinism:** keys are walked in alphabetical order, so signals and payments come out the same on every machine. `to_dict()` and `Purse.from_dict()` keep everything, substitutes included.

## API

### `Purse` (RefCounted)

| Member | What it does |
| --- | --- |
| `Purse.new(start, limits)` | A purse. All optional |
| `amount(key)`, `amounts()`, `keys()` | The amounts |
| `limit(key)` (-1 = no limit), `has_limit(key)`, `set_limit(key, value) -> int` | The limits. `set_limit` returns what no longer fits; a negative value takes the limit away |
| `set_amount(key, value) -> int` | Sets an amount and returns what did not fit |
| `add(gains) -> Dictionary` | Adds and returns what was lost to the limits |
| `can_pay(cost)`, `payment_for(cost)`, `pay(cost) -> bool` | Paying, with the substitutes. `payment_for` returns `{key: taken}` |
| `add_substitute(key, covers = [], rate = 1)` | `rate` of `key` pay for 1 that is missing of any of `covers` (empty: any other key). A rate under 1, an empty key or a `covers` that holds it is an error and adds nothing |
| `substitutes()`, `substitutes_for(key)`, `clear_substitutes()` | The rules (copies `{key, covers, rate}`, in order), the ones that cover `key`, and taking them all away |
| `to_dict()` / `Purse.from_dict(data)` | Plain data to save, send over the network or compare a replay |
| signals `changed(key, value)`, `overflowed(key, lost)` | Past tense: it already happened |

### `Wallet` (Node)

- **Inspector:** `start_amounts`, `limits` and `substitutes` (a list of `WalletSubstitute` with `key`, `covers` and `rate`, in priority order). Changing the limits, the list or a value of a substitute applies at once; changing `start_amounts` builds the purse again. It never touches a `use_purse` purse.
- **Editor warnings:** a negative amount, a start above its limit, an empty slot in `substitutes`, an empty `key`, a substitute that covers itself and two identical rules.
- **Purse:** `purse` is the `Purse` it shows. `use_purse(purse)` shows your rules' purse and `use_own_purse()` goes back to the inspector's.
- **Methods:** the same as `Purse` (`amount`, `amounts`, `limit`, `can_pay`, `payment_for`, `pay`, `add`, `set_amount`) and `substitutes_for`.
- **Signals:** the same as `Purse`, plus `rebuilt` when the node starts showing another purse (`use_purse`, `use_own_purse` or new `start_amounts`). When it arrives, read every amount again.

## Migrating from 0.2

| Before (0.2) | Now (0.3) |
| --- | --- |
| `Purse.new(start, limits, wildcard)` and `purse.wildcard_covers = [...]` | `Purse.new(start, limits)` and `purse.add_substitute(wildcard, covers)` |
| `Wallet.wildcard`, `Wallet.wildcard_covers` | `Wallet.substitutes`: a `WalletSubstitute` with `key` and `covers` |
| `purse.covers(key)` | `purse.substitutes_for(key)` (the rules that cover that key, in order) |
| `to_dict()` with `wildcard` and `wildcard_covers` | `to_dict()` with `substitutes`; `from_dict` reads both formats (the old one becomes a rate 1 substitute) |

An old scene that had `wildcard` or `wildcard_covers` saved: Godot ignores a property that no longer exists, so set them again as `substitutes`.

## Tips

- **Rules use `Purse`, not the node.** Keep one purse per player in your match state and show it with `wallet.use_purse(player.purse)`. The HUD listens to `changed` for each change and to `rebuilt` to redraw everything, for example when the player shown changes.
- **A wildcard** is ONE substitute with no `covers`. **Tokens that must not be covered** (culture, mood): use other keys and list in `covers` only what can be covered, so nothing covers them.
- **Code instead of the inspector:** `add_substitute` is the same as a `WalletSubstitute`. On your rules' `Purse`, `purse.add_substitute(&"gold")`.
- **A cost to show:** `payment_for(cost)` tells the player how much gold they will spend before they confirm.

## Tests

```bash
godot --headless --path walletkit_lab --script res://addons/wallet_kit/tests/wallet_test_runner.gd
```

It prints `WALLETKIT TESTS PASS (n)`. The tests cover:

- Amounts, limits and what is lost, all-or-nothing payments, the substitutes (1 to 1, with a list, with a rate, the order, the same key with two rates, nothing changes when short), `payment_for` against what `pay` takes, errors and `to_dict` (the 0.2 format too).
- The node: the purse from the inspector, signals, live changes (a resource's `rate` too), `use_purse`, `rebuilt` and the editor warnings.
- The example played with its buttons.
- That the addon names no other kit.
