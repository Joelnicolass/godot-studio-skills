---
name: godot-bot-kit
description: >-
  Bots that play a character like a person in a Godot 4 3D game, with the
  BotKit addon: a node on the character that presses a player's keys (an Input
  of its own the character reads), sees the nearest enemy with no wall in
  between, turns and aims with a person's limits (reaction, error, a fire cone,
  bursts, leading the shot, grenades in an arc), picks the weapon by distance,
  keeps its distance and steps sideways, walks the navmesh to pickups, to where
  it saw the enemy or anywhere, and gets out of where it is stuck. Your own
  behaviours as child nodes (flee, guard), difficulty presets, its sight and
  handles in the editor. Use when the user wants bots, enemies that play like
  players, bots filling empty seats, a deathmatch against the computer, shooter
  AI or /add-bots. Not the character, its weapons or health, nor the network.
---

# Godot — bots that play like a person (BotKit)

Addon `addons/bot_kit/` in the **game's** project. Reference: `addons/bot_kit/README.md`; API per piece: [api.md](api.md).

If the addon is missing:

```bash
./install.sh --addon /path/to/godot-project bot_kit
```

Enable the **BotKit** plugin (the sight, cone and handles in the 3D view; the nodes work without it). Scoped request: `/add-bots`. Composition: [godot-composition-first](../godot-composition-first/SKILL.md).

## Rules

- **One node and one line.** A `Bot3D` child of the character, and the character reads `bot.input` where a player's reads `Input` (the same methods). The bot never moves the body: it presses keys. If the character already reads `Input` in several places, an `input` variable that is `Input` or `bot.input` depending on who plays.
- **Keys, by name.** By default those of Godot's character template (`ui_left`, `ui_right`, `ui_up`, `ui_down`, `ui_accept`) plus `fire`; the bot's "Controls" group changes them to the game's. They need not be in the InputMap.
- **Looking.** With `turn_body` (the default) the bot turns the character and its `head`. If the character applies where it looks itself (a network game, its own camera), `turn_body = false` and the character reads `input.get_value(&"yaw")` and `&"pitch"` (radians).
- **Enemies, by group.** The nodes of `target_group` (`bot_target`); teams and dead bodies with `is_enemy`. Another perception (a cone, ears): `choose_target`.
- **Weapons, by distance.** One `BotWeapon` per weapon, with its range, score and trigger; the character switches weapon on `weapon_changed`. The game's rules on a weapon (heat, ammo) go in `weapon_score`, never in the kit. A grenade: `projectile_speed_m_s` and `gravity_m_s2` equal to the game's projectile.
- **Pickups, as goals.** A `BotGoal3D` in the pickup's scene; a taken pickup hides (and its goal with it). Whether it needs it, in `wanted`.
- **Your own behaviours, as nodes.** A `BotMode` child of the bot with `_want()` and `_tick()`; it uses `walk_to`, `aim_and_fire`, `move`, `look_toward`. No replacing the fight or the roam: you beat them by wanting more.
- **Difficulty, in a resource.** `presets/easy.tres`, `normal.tres`, `hard.tres`; a preset is shared.
- **Dead, or where the game is not decided:** `enabled = false`. It lets go of every key.
- **No kit depends on another.** BotKit has no network nor another kit's perception: the game connects them.
- **The person sees it in the editor.** Selecting the bot draws its sight, its cone and its distance; the handles move the eye and aim heights. `show_in_game` draws what it thinks while it plays.

## Network

The bot runs where the game is decided and presses a seat's keys. **With MpKit**, on the server, on the pawn of a free seat:

```gdscript
var bot := preload("res://bots/bot.tscn").instantiate() as Bot3D
bot.turn_body = false
pawn.add_child(bot)
var keys := pawn.get_node(^"MpInput") as MpInput
bot.input.pressed.connect(keys.bot_press)
bot.input.released.connect(keys.bot_release)
bot.input.value_changed.connect(keys.bot_set_value)
```

A person takes the seat (`keys.has_player()`, `Mp.gate().joined_late`): `bot.queue_free()`, which lets go of every key as it leaves. Filling free seats: MpKit's `bots_2d` example. **Without MpKit:** `enabled = multiplayer.is_server()` and the three signals connected to the game's network input.

## Tree

```
Level
├── Navigation (NavigationRegion3D)     # the baked navmesh
│   └── Floor, Walls (StaticBody3D)     # on the sight_mask layer: they block sight and shots
├── HealthPickup (Area3D)
│   └── BotGoal3D                        # priority 2, wanted: hurt
└── Fighter (CharacterBody3D)            # in the group bot_target; reads bot.input
    ├── Head (Node3D)                    # the bot's head
    └── Bot3D                            # weapons: [rifle.tres, grenade.tres]; difficulty
        └── Flee (BotMode)               # the game's: hurt, it runs to health
```

Start from `addons/bot_kit/examples/minimal_3d/minimal_3d.tscn` (a robot that hunts you) or `arena_3d` (four bots, rifle and grenades, pickups, a `BotMode` to flee, difficulty on 1, 2, 3).

## What goes where

| Kit | Game |
|---|---|
| Which key it presses and when, where it looks | The character, how it walks, jumps and shoots with those keys |
| Whom it sees, whom it picks (`is_enemy`, `choose_target`) | The teams, health, death |
| Which weapon suits the distance | The real weapons, damage, ammo, heat (`weapon_score`) |
| Which goal it walks to | Which pickup is worth it for whom (`wanted`) |
| Picking what it wants most | Its own behaviours (`BotMode`) |
| `pressed`, `released`, `value_changed` | The network, which seat a bot plays, when a person takes it |

## Done when

- The bot shows no warning and the person saw (or knows how to see) its sight and handles in the 3D view.
- F6: the bot walks the level, finds an enemy, turns, reacts, fires in bursts and keeps its distance; it loses the enemy behind a wall and goes looking.
- With weapons: it switches weapon by distance; a grenade lands where it aimed.
- In a network game: the bot plays on the server and a person who takes the seat replaces it with no stuck keys.
- `godot --headless --path botkit_lab --script res://addons/bot_kit/tests/bot_test_runner.gd` gives `BOTKIT TESTS PASS` (in the kit's repo).

## Antipatterns

- Moving the body from the bot, or writing a separate character for the bot: the bot presses keys and the character is the same.
- `Input.action_press()` for the bot: it is global, every bot and the person press it at once. Each bot has its `bot.input`.
- A weapon's rules (heat, ammo, backs) inside a copied `BotWeapon` or the kit: they go in `weapon_score`.
- A `BotMode` that rewrites the fight or the roam: call `aim_and_fire` and `walk_to`.
- Leaving the bot on with its character dead: `enabled = false`.
- Changing a shared preset for a single bot: make its difficulty unique.
- Baking the navmesh in the game without waiting: the bot walks once the map is there; bake it in the editor.
