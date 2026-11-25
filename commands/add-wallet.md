---
description: "Resources and coins (WalletKit addon): a whole number per key with limits, all-or-nothing payments, substitutes with a rate that cover what is missing, payment_for to show the cost, saving with to_dict."
---

Add **resources and coins** to the **game's Godot project** with the WalletKit addon:
- a `Wallet` where the game keeps what each player has (or a `Purse` per player in its rules, shown with `use_purse`);
- each key's limits in `limits`;
- the `substitutes` that cover what is missing when paying (gold covers everything, 2 food cover 1 wood);
- the HUD listening to `changed`, `overflowed` and `rebuilt`.

Then the person sees the amounts and the substitutes in the inspector; the agent builds and explains.

This is **not** prices, shops or UI: the kit keeps and charges, and the game decides what each thing costs and when it is charged. **Not** the network: a network game charges on the server and sends amounts.

Load: `godot-wallet-kit`, `godot-composition-first`.

If `addons/wallet_kit/` is missing:

```bash
./install.sh --addon /ABS/GODOT_ROOT wallet_kit
```

Enable **WalletKit**. If `godot-studio-workflow` is loaded: orchestrator → tree (this chat if it is 1–3 files; otherwise `studio-tech-lead`) → OK → `studio-developer`. No extra subagent.

## 1. Scope

If missing, ask in one batch:

1. Which resources or coins exist (keys) and which have a storage limit.
2. What each player starts with and how many players there are (a `Purse` per player or a single node).
3. What is paid and when (building, buying, recruiting, a turn) and who builds the cost.
4. Whether a token stands in for another when paying: which, what it covers, at what rate and in what order. Which tokens can never be covered (culture, mood).
5. What the HUD shows and whether the game saves or is networked.

## 2. Plan

Show the file tree before touching the game (`[+]` new, `[~]` changed, `[-]` deleted), for example:

```
[~] project.godot                        # WalletKit plugin
[+] scenes/economy/wallet.tscn           # Wallet: start_amounts, limits, substitutes [food → wood at 2, gold → anything at 1]
[+] scenes/ui/resources_hud.gd           # listens to changed and rebuilt; shows the amounts
[~] scenes/ui/resources_hud.tscn         # the labels
[~] scenes/buildings/temple.gd           # can_pay(COST) disables the button; pay(COST) when building
[~] scenes/levels/level.tscn             # instances the Wallet
```

Start from `addons/wallet_kit/examples/minimal/minimal.tscn` (harvest, limits, building with substitutes).

## 3. Implement

Follow [godot-wallet-kit](../skills/godot-wallet-kit/SKILL.md) and `addons/wallet_kit/README.md`.

- `start_amounts`, `limits` and `substitutes` in the `Wallet` inspector, in priority order (the most specific first).
- The rules call `can_pay(cost)` and `pay(cost)`; `add(gains)` returns what the limit lost.
- With a `Purse` per player in the rules: `wallet.use_purse(player.purse)` and the HUD listens to `rebuilt`.
- `payment_for(cost)` to show what will be taken before confirming.
- Save with `to_dict()` / `Purse.from_dict()`. Over the network, the server pays and sends amounts.
- Tell the person how to see it: the substitutes are inspector resources, and the node warns about an empty, repeated or self-covering rule.

## 4. Done when

- The `Wallet` shows no warnings and the person saw its substitutes in the inspector.
- F6: adding respects the limits and reports what is lost; paying uses what is its own and then the substitutes in order; falling short changes nothing.
- The HUD shows the amounts and redraws with `rebuilt`.
- No prices, shops or network inside `addons/wallet_kit`.
