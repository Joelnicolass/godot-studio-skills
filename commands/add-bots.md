---
description: "Bots (BotKit addon): a node on your character that plays like a person, pressing its keys; it sees, aims with a person's limits, picks a weapon, walks the navmesh, with your own behaviours and difficulty presets, in 3D."
---

Add **bots that play a character like a person** to the **game's Godot project** with the BotKit addon:
- a `Bot3D` child of each character a bot plays, and the character reading `bot.input` where it read `Input`;
- its enemies in a group;
- a `BotWeapon` per weapon, if it has more than one;
- a `BotGoal3D` on each pickup worth it;
- a `BotMode` per behaviour of the game's own (flee, guard), if needed.

Then the person sees its sight and handles in the 3D view and watches it play with `show_in_game`; the agent builds and explains.

This is **not** the character, its weapons, its health or its death: the kit presses keys and the game turns them into movement and shots. **Not** the network: a network game decides which seat a bot plays and connects its keys to its input. **Not** a strategy or RTS AI.

Load: `godot-bot-kit`, `godot-composition-first`.

If `addons/bot_kit/` is missing:

```bash
./install.sh --addon /ABS/GODOT_ROOT bot_kit
```

Enable **BotKit**. If `godot-studio-workflow` is loaded: orchestrator → tree (this chat if it is 1–3 files; otherwise `studio-tech-lead`) → OK → `studio-developer`. No extra subagent.

## 1. Scope

If missing, ask in one batch:

1. Which character the bot plays and where it reads its keys today (the script that calls `Input`); its actions' names (move, jump, fire, switch weapon); whether it turns with the mouse or with values.
2. Whom it fights: free for all, teams, only the player; what happens on death (when it comes back).
3. Its weapons: which, at what distance each suits, whether one is thrown in an arc (the projectile's speed and gravity), their rules (heat, ammo, charge).
4. Which pickups there are and when they are worth going for.
5. Whether a behaviour of its own is needed (flee when hurt, guard, follow a leader) and the difficulty (easy, normal, hard, or the numbers).
6. Whether the game is networked (with MpKit or what), and whether the level has its navmesh baked.

## 2. Plan

Show the file tree before touching the game (`[+]` new, `[~]` changed, `[-]` deleted), for example:

```
[~] project.godot                        # BotKit plugin
[+] bots/bot.tscn                        # Bot3D: weapons, difficulty, Controls with the game's actions; Flee (BotMode)
[+] bots/flee.gd                         # the game's BotMode: hurt, to the nearest health
[+] bots/weapons/rifle.tres              # BotWeapon: 0 to 40 m, HOLD
[+] bots/weapons/grenade.tres            # BotWeapon: 6 to 16 m, the game's grenade speed and gravity, TAP
[~] scenes/player/player.gd             # input = Input or bot.input; weapon_changed switches the weapon; weapon_score with no ammo
[~] scenes/player/player.tscn           # in the group bot_target
[~] scenes/pickups/health.tscn           # BotGoal3D: priority 2; wanted: hurt
[~] scenes/levels/arena.tscn             # navmesh baked; the bots that fill the seats
```

Start from `addons/bot_kit/examples/minimal_3d` (a robot that hunts you) or `arena_3d` (four bots, rifle and grenades, pickups, fleeing, difficulty).

## 3. Implement

Follow [godot-bot-kit](../skills/godot-bot-kit/SKILL.md) and `addons/bot_kit/README.md`.

- The bot as a child of the character, `head` on what looks up and down, the game's actions in "Controls".
- The character reads `bot.input` (or an `input` variable that is `Input` for a person). With `turn_body` off, it applies `input.get_value(&"yaw")` and `&"pitch"`.
- Enemies in `target_group`; teams or dead bodies in `is_enemy`.
- The weapons as `BotWeapon`; `weapon_changed` switches the character's weapon; the game's rules in `weapon_score`.
- `BotGoal3D` on the pickups (a taken pickup hides); `wanted` for when it is worth it.
- On death `enabled = false`, on respawn `true`. In a network game, `enabled` only where the game is decided and the signals of `bot.input` connected to its input.
- Tell the person how to see it: selecting the bot shows its sight, cone and distance in the 3D view; `show_in_game` draws what it thinks.

## 4. Done when

- The bot shows no warning and the person saw its sight and handles.
- F6: the bot walks the level, fights with a person's limits, switches weapon by distance, goes to the pickups it needs and gets out of where it is stuck.
- In a network game, it plays on the server and a person who takes its seat replaces it with no stuck keys.
- Nothing of the character, its weapons, its health or its network inside `addons/bot_kit`.
