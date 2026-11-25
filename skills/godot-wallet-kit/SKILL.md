---
name: godot-wallet-kit
description: >-
  Resources and coins in a Godot 4 game with the WalletKit addon: a whole
  number per key (wood, gold, food), with limits that return what is lost,
  all-or-nothing payments, substitutes with a rate that cover what is missing
  (gold covers anything 1 to 1; 2 food cover 1 wood) with a fixed payment plan
  and `payment_for` to show the cost before taking it, and saving and
  restoring with `to_dict`. A plain-data `Purse` for the rules and a `Wallet`
  node for the editor. Use when the user wants resources, coins, a cost that
  is paid, storage limits, a wildcard or a coin that stands in for another, or
  /add-wallet. Not prices, shops or UI, nor the network.
---

# Godot — resources and coins (WalletKit)

Addon `addons/wallet_kit/` in the **game's** project. Reference: `addons/wallet_kit/README.md`.

If the addon is missing:

```bash
./install.sh --addon /path/to/godot-project wallet_kit
```

Enable the **WalletKit** plugin (type `Wallet` in Create Node; `WalletSubstitute` in New Resource). Scoped request: `/add-wallet`. Composition: [godot-composition-first](../godot-composition-first/SKILL.md).

## Rules

- **Two levels.** The game's rules keep one `Purse` per player (plain data, tests headless). The `Wallet` is the node that builds it from the inspector values or shows your rules' purse (`use_purse`).
- **Whole numbers from 0.** Keys are `StringName` (`&"wood"`). A negative amount in a cost or in `add()` is an error and changes nothing.
- **Limits.** A key without a limit has none. What goes past the limit is lost: `add()` returns it as `{key: lost}` and `overflowed` is emitted.
- **Paying is all or nothing.** `can_pay(cost)` first; `pay(cost)` changes nothing when it falls short. To show what will be spent, `payment_for(cost)`: it is exactly what `pay` takes.
- **Substitutes, not wildcards.** `add_substitute(key, covers, rate)` or a `WalletSubstitute` in `Wallet.substitutes`: `rate` of `key` pay for 1 that is missing of `covers` (empty: any other key). A "wildcard" is a substitute with no `covers`. What must not be covered (culture, mood) stays out of `covers`.
- **The payment plan is fixed.** What is its own for each key of the cost first; then the substitutes in list order. It is greedy: put the most specific substitute first. No chains: a substitute pays with what it has.
- **Editor first.** `start_amounts`, `limits` and `substitutes` are set in the inspector, and changing them live applies at once. The node warns about an empty slot, an empty `key`, a substitute that covers itself and repeated rules.
- **The HUD listens.** `changed` for each amount, `overflowed` for what is lost, `rebuilt` to redraw everything when the node starts showing another purse.
- **Saving.** `to_dict()` and `Purse.from_dict()` keep amounts, limits and substitutes in a fixed order.
- **No kit depends on another.** WalletKit has no prices, shops, UI, network or autoload: the game connects. Over the network, the server decides the payment and sends amounts.

## Tree

```
Level
├── Wallet                               # start_amounts, limits
│   └── (substitutes)                    # [food → wood at 2, gold → anything at 1] as inspector resources
├── Hud (Control)                        # listens to changed / rebuilt and shows the amounts
└── Shop (Button)                        # can_pay(cost) → disabled; pay(cost)
```

Start from `addons/wallet_kit/examples/minimal/minimal.tscn`.

## What goes where

| Kit | Game |
|---|---|
| The amounts, the limits, what is lost | What each thing is worth, what building or buying costs |
| All-or-nothing payment, the plan with substitutes, `payment_for` | When it is charged, who pays, what happens when it falls short |
| Which substitutes exist and at what rate | Which tokens exist and which can stand in for others |
| `changed`, `overflowed`, `rebuilt` | The HUD, the animations, the notices |
| `to_dict` / `from_dict` | Where it is saved and how it travels over the network |

## Done when

- The `Wallet` shows no warnings and the substitutes are visible in the inspector.
- F6: adding goes past the limit and is lost with a notice; paying uses what is its own, then the substitutes in order; falling short changes nothing.
- `payment_for` shows the player what `pay` takes.
- `godot --headless --path walletkit_lab --script res://addons/wallet_kit/tests/wallet_test_runner.gd` gives `WALLETKIT TESTS PASS` (in the kit repo).

## Anti-patterns

- Prices or shop rules inside the kit: the game builds the cost.
- A `Purse` per player created from the node: the rules keep it and the node shows it with `use_purse`.
- Changing amounts with `set_amount` to charge: use `pay`, which is all or nothing.
- A substitute that covers tokens that must not be covered: list in `covers` only what can be covered.
- Keeping the rules' state in the node: the node is a view.
- Expecting chains (food → wood → gold): a substitute pays only with what it has.
