# BotKit

Bots that play your character like a person, in 3D:
- **One node on your character.** `Bot3D` presses the same keys a player presses, in `bot.input`, which reads like Godot's `Input`. Your character walks, jumps and shoots with its own code, without knowing whether a person or a bot plays it.
- **It sees** the nearest enemy of a group, within its reach and with no wall in between, and remembers where it saw one last.
- **It fights like a person:** it turns at a person's speed, aims with an error, takes a moment to react before its first shot, fires only inside a cone, in bursts, aims ahead of a walking enemy and lobs grenades in an arc over cover. It keeps its distance and steps sideways.
- **It picks the weapon** that suits the distance (`BotWeapon`), with your game's own rules (heat, ammo) in a function.
- **It walks the level** on its navmesh: to a pickup (`BotGoal3D`), to where it saw an enemy, or to any point it can reach. Stuck, it jumps and picks another way.
- **Your own behaviours** (flee, guard, follow a leader) are child nodes (`BotMode`): the bot does what it wants most.
- **Difficulty:** three presets (easy, normal, hard) in a resource (`BotDifficulty`).
- **In the editor:** its sight, its fire cone and its fight distance drawn in the 3D view, with handles for its eye and aim heights; each goal's reach, with its handle.

It has no network code and no autoload, and BotKit depends on no other kit. In a network game it runs on the server and its keys travel like a player's (below, [Network](#network)).

```bash
./install.sh --addon /path/to/godot-project bot_kit
```

Enable the **BotKit** plugin for the drawings and handles in the editor. The nodes work without it.

**Examples:**

- `examples/minimal_3d/minimal_3d.tscn`: the least, a robot that hunts you round some walls (below, [Minimal example](#minimal-example)). **Arrows:** walk. **F:** draw what it thinks.
- `examples/arena_3d/arena_3d.tscn`: four bots fight in an arena with a rifle and grenades, go for health and grenades when short, flee to health when hurt (a `BotMode` of the example) and come back when they die. Keys:
  - **1, 2, 3:** easy, normal, hard.
  - **F:** draw what each one thinks.
  - **Left and right:** turn round the arena.

## Getting started

1. **Add a `Bot3D`** as a child of your character (the `CharacterBody3D`). If its head or camera turns to look up and down, put it in `head`.
2. **Have your character read `bot.input`** where a player's reads `Input`: the same methods (`get_vector`, `is_action_pressed`, `is_action_just_pressed`). The default keys are those of Godot's character template (`ui_left`, `ui_right`, `ui_up`, `ui_down`, `ui_accept`) plus `fire`; change them in the "Controls" group.
3. **Put its enemies in the group `bot_target`** (Node › Groups). Its own character never counts.
4. **Bake the level's navmesh** (a `NavigationRegion3D` › Bake NavigationMesh): it walks on it.

With that it already fights and walks the level. For more: weapons in `weapons`, a difficulty in `difficulty`, a `BotGoal3D` on each pickup.

## Minimal example

`examples/minimal_3d/minimal_3d.tscn` (F6): a robot and you on a floor with four walls.

```
Minimal3D (minimal_3d.gd)                # draws the shots and counts those that hit you
├── WorldEnvironment, Sun, Camera3D
├── Level (NavigationRegion3D)          # the baked navmesh of the floor and the walls
│   ├── Floor (StaticBody3D)            # on layer 1, like the walls
│   └── Wall, Wall2, Wall3, Wall4
├── You (CharacterBody3D, you.gd)       # in the group bot_target: reads Input (the arrows)
├── Robot (CharacterBody3D, robot.gd)   # Godot's character template, reading bot.input
│   ├── Head (Node3D)                   # at 1.6 m: turns up and down to look
│   └── Bot3D                           # head: Head; everything else as it comes
└── Label
```

```gdscript
# robot.gd (the gist): Godot's template, with bot.input where it said Input
func _physics_process(delta: float) -> void:
	var input := bot.input
	if not is_on_floor():
		velocity += get_gravity() * delta
	if input.is_action_just_pressed(&"ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	var keys := input.get_vector(&"ui_left", &"ui_right", &"ui_up", &"ui_down")
	var direction := transform.basis * Vector3(keys.x, 0.0, keys.y)
	velocity.x = direction.x * SPEED
	velocity.z = direction.z * SPEED
	move_and_slide()
	if input.is_action_pressed(&"fire") and _cooldown_s <= 0.0:
		_shoot()  # a ray from the head, where it looks
```

**Tips from the example:**
- The bot turns the character (and the head) itself. Your code only moves it toward where it looks, as with a player.
- `fire` is not in the project's InputMap, and it needs not be: the bot's keys are its own, not the keyboard's.
- The robot sees in every direction. Behind a wall (layer 1, the default `sight_mask`) it does not see you; having lost you, it sometimes walks to where it saw you last.

## Network

The kit has no network. In a network game the bot runs where the game is decided (the server) and presses a seat's keys as if it were its player: its signals `pressed`, `released` and `value_changed` have just the shape to connect to the game's network input. Turn `turn_body` off, so the bot only writes where it looks and your character applies it, as with a player.

**With MpKit:** on the server, on the pawn of a free seat.

```gdscript
var bot := preload("res://bot.tscn").instantiate() as Bot3D  # a Bot3D saved as a scene
bot.turn_body = false
pawn.add_child(bot)
var keys := pawn.get_node(^"MpInput") as MpInput
bot.input.pressed.connect(keys.bot_press)
bot.input.released.connect(keys.bot_release)
bot.input.value_changed.connect(keys.bot_set_value)  # yaw and pitch, in radians
```

When a person takes the seat (`keys.has_player()`, or `Mp.gate().joined_late`), free the bot with `bot.queue_free()`: it lets go of every key as it leaves. To fill the free seats, see MpKit's `bots_2d` example.

**Without MpKit:** `enabled = multiplayer.is_server()` on each machine, and whatever your network does with a player's keys, connected to the same three signals.

## The bot (`Bot3D`)

| Property | Default | What it is |
|---|---|---|
| `enabled` | on | Off, it lets go of every key, forgets its enemy and waits. Turn it off where the game is not decided and while its character is dead |
| `body` | its parent | The character it plays |
| `head` | empty | What turns up and down to look (its `rotation.x`) |
| `difficulty` | `presets/normal.tres` | How well it plays |
| `weapons` | empty | Its weapons; empty, a single one on `fire_action`, at any distance, in bursts |
| `target_group` | `bot_target` | Its enemies are the nodes of this group |
| `turn_body` | on | It turns the character and `head` itself; off, it only writes `yaw` and `pitch` |
| Controls | those of Godot's template | `move_left` (`ui_left`), `move_right`, `move_forward` (`ui_up`), `move_back`, `jump_action` (`ui_accept`), `fire_action` (`fire`), `yaw_value`, `pitch_value` |
| Eyes | 1.6 m / 1.1 m | `eye_height_m` (where it looks from), `aim_height_m` (where it aims on an enemy), `sight_mask` (what blocks its sight and its shots: the walls), `pitch_limit_deg` |
| Fight | | `fight_want` (1), `strafe_s` (how often it changes side), `jump_chance` |
| Roam | | `roam_want` (0.1), `navigation_layers`, `arrive_m`, `reach_slack_m`, `stuck_s` and `stuck_m` (when it is stuck), `repath_s` |
| Thinking | 0.2 s | `think_s` (how often it looks around and decides), `random_seed` (0: different every time) |
| `show_in_game` | off | Draws, while the game runs, its enemy, its path, its goal and what it does |

**What the game reads:** `input` (its keys), `target` (its enemy, or null), `weapon`, `mode` (`&"fight"`, `&"roam"` or a `BotMode`'s name), `goal` (where it walks), `last_seen`.

**Signals:** `target_changed(enemy)`, `weapon_changed(weapon)` (switch your character's weapon), `mode_changed(mode)`, `stuck`.

**The game's own rules, in functions** (all optional):
- `is_enemy = func(node) -> bool`: whether a node of the group is an enemy (a team, a dead body).
- `choose_target = func() -> Node3D`: your own choice of enemy, instead of its sight (another perception, a scripted fight).
- `weapon_score = func(weapon, distance_m, score) -> float`: your rule on a weapon (heat, ammo, an enemy's back); 0 is "not now".

**What a mode uses:** `walk_to(point, delta)`, `aim_and_fire(delta)`, `move(direction)`, `look_toward(direction, delta)`, `turn_to(yaw, pitch, delta)`, `press(action)`, `release(action)`, `tap(action)`, `jump()`, `stop()`, `can_see(point, of)`, `random_reachable_point()`, `eye_position()`, `flat_distance_to(point)`, `current_difficulty()`.

## You want → you write

| You want | Write |
|---|---|
| A bot on your character | A `Bot3D` child of the character, and the character reads `bot.input` |
| It to fight other bots | Every character in the group `bot_target` |
| Teams | `bot.is_enemy = func(node): return node.team != team` |
| Easier or harder | `bot.difficulty = preload("res://addons/bot_kit/presets/hard.tres")` |
| A weapon for close and one for far | Two `BotWeapon` in `weapons`, with their `min_m` and `max_m`; switch the weapon in `weapon_changed` |
| A grenade in an arc | `projectile_speed_m_s` and `gravity_m_s2` in its `BotWeapon` (your grenade's); `trigger` on TAP |
| It not to use a weapon with no ammo | `bot.weapon_score = func(weapon, distance, score): return 0.0 if no_ammo else score` |
| It to go for a pickup | A `BotGoal3D` in the pickup's scene; hide the pickup when it is taken |
| It to go only when it needs it | `goal.wanted = func(bot): return bot.body.health < 80` |
| It to flee when hurt | A `BotMode` child of the bot that wants 2 under some health and walks with `bot.walk_to()` |
| The bot not to play while dead | `bot.enabled = false`; back alive, `true` |
| To see what it thinks | `show_in_game` |
| A bot in a network game | [Network](#network) |

## Weapons (`BotWeapon`)

One resource per weapon. In a fight, on each think, the bot picks the one with the highest score at its enemy's distance and says so with `weapon_changed`. When none scores, it does not fire (but keeps fighting).

| Group | Properties |
|---|---|
| | `name` (your game's), `fire_action` (empty: the bot's) |
| When | `score` (the highest wins), `min_m` and `max_m` (its range), `chance` (how often it switches to it: a mine now and then), `keep_m` (the distance it keeps with it; -1: the difficulty's), `fire_within_m` (it fires only this close: a hammer it picks to close in) |
| Aim | `projectile_speed_m_s` (0: it hits at once; otherwise it aims ahead), `gravity_m_s2` (above 0: it lobs it in an arc, over cover), `lead_max_s`, `aim_height_m` (-1: the bot's; low for a blast) |
| Trigger | `trigger`: HOLD (held, in the difficulty's bursts), TAP (one press every `tap_every_s`), CHARGE (held up to `charge_s` and let go; `tap_chance` of a short tap) |

## Difficulty (`BotDifficulty`)

| Group | Properties | Easy / normal / hard |
|---|---|---|
| Seeing | `sight_m`, `reaction_s` | 25 / 35 / 45 m; 1.2 / 0.8 / 0.55 s |
| Aim | `turn_deg_s`, `aim_error_deg`, `fire_cone_deg` | 92 / 149 / 229 °/s; 14 / 9 / 6°; 5 / 6 / 7° |
| Firing | `burst_s`, `burst_pause_s` | 0.4 + 1.3 / 0.8 + 0.6 / 1.5 + 0.25 s |
| Moving | `move_scale`, `keep_m`, `chase_chance`, `goal_reach_scale` | 0.6 / 0.78 / 1; 12 / 10 / 9 m; 0.25 / 0.6 / 1; 0.5 / 1 / 1.4 |

A preset is shared: to tune one bot only, make its difficulty unique in the inspector (or duplicate the file).

## Goals (`BotGoal3D`)

A place worth walking to for a bot with nobody to fight: put one in a pickup's scene. The bot walks to the goal of the highest `priority` within its `reach_m` (scaled by its difficulty), the nearest of those. A hidden goal (the pickup was taken and hid) or an off one (`enabled`) counts for no bot. One it cannot reach (on top of a desk) it leaves aside for a few seconds. `wanted = func(bot) -> bool` is your rule on whether that bot wants it now.

## Your own modes (`BotMode`)

What your bot does besides fighting and roaming: flee, guard a door, follow a leader, carry a flag. A child node of the `Bot3D` that overrides `_want(bot)` (how much it wants to run now) and `_tick(bot, delta)` (every frame while it runs), and if needed `_enter` and `_exit`. On each think the bot does what it wants most: its fight wants `fight_want` (1) while it sees an enemy, its roam `roam_want` (0.1) always. A tie keeps what it does.

```gdscript
# flee.gd (from the arena_3d example): hurt, it runs to the nearest health
extends BotMode

func _want(bot: Bot3D) -> float:
	return 2.0 if bot.body.health < 35.0 and _nearest_health(bot) != null else 0.0

func _tick(bot: Bot3D, delta: float) -> void:
	bot.walk_to(_nearest_health(bot).global_position, delta)
```

## In the editor

- **The bot:** select it and the 3D view draws its sight (its difficulty's `sight_m`, around its eyes), its fire cone ahead, the distance it keeps in a fight (around its feet) and where it aims on an enemy. The handles move `eye_height_m` and `aim_height_m`.
- **The goal:** its reach, with a handle to drag it.
- Every drag undoes. The sight, the cone and the distance live in the difficulty (a shared preset): they are drawn, and changed in the inspector.
- **Warnings:** a bot that is not on a character, an empty group, a weapon with `min_m` above `max_m`, a `BotMode` outside a bot, a goal without reach.

## Performance

- It thinks every `think_s` (0.2 s), each bot at its own moment: it looks for its enemy (one ray per candidate within its reach), its weapon and its mode.
- Every frame: one ray for the line of fire while it aims, a few navmesh queries while it fights (so it never steps off the mesh), and its path.
- It asks the NavigationServer3D for its path when the goal changes and every `repath_s` (1 s). A random point tries up to eight paths.
- It creates no nodes while it plays. `show_in_game` does draw; leave it off on a server.
- Measured on an M4: 16 bots fighting in an arena with walls cost about 0.8 ms a frame in all (0.05 ms each), their characters' movement aside.

## Tips and recommendations

- **Save your bot as a scene** (the `Bot3D` with its weapons and modes) and spawn copies on each character a bot plays.
- **One layer for the walls.** `sight_mask` is what blocks its sight and its shots. If the characters are in the mask too, its own and its enemy's never block; a third one does.
- **The navmesh, baked in the editor.** A level that bakes it on load has to wait a few frames: the bot stands until the mesh is there.
- **The bot's grenade and the game's, the same.** If `projectile_speed_m_s` and `gravity_m_s2` are your projectile's, the arc lands where it aimed.
- **The aim error is human:** with an error larger than the cone, the bot fires less (it waits for the error to fall inside). For a bot that fires a lot and misses, lower the error and widen the cone.
- **It sees in every direction.** For a view cone, ears or memory, connect your perception in `choose_target`.

## Where the ideas come from

The first version was the bots of a network shooter, which filled the empty seats and gave their place to a person. This kit made them generic:
- **A bot that presses keys instead of moving the body:** the character moves the same with a person or a bot, and the network does not change.
- **A person's limits on the aim** (turn, error, reaction, cone, bursts), as in the bots of arena shooters: so a bot can be beaten.
- **Choosing by score** (the weapon, what it does): each option says how much it wants, and the one that wants most wins. Adding one is adding a node, not touching a state machine.
- **Roaming by goals with priority**, to where it saw the enemy and to a random reachable point, with a jump to get out of where it got stuck.

## Tests

```bash
godot --headless --path botkit_lab --script res://addons/bot_kit/tests/bot_test_runner.gd
```

The result is `BOTKIT TESTS PASS (n)`. The tests cover:

- **its keys:** they read like `Input` (strength, axis, a vector at most 1 long, just pressed in its frame), and their signals fire once per change and connect to another input;
- **the aim's math:** the angles of Godot's forward, the turn the short way round, leading by the flight time, an arc that lands on its point;
- **its sight:** the nearest with no wall in between, a hidden one or one out of reach does not count, its own body and the enemy's never block, `is_enemy`, `choose_target`, a freed enemy;
- **the fight:**
  - it turns at its speed, reacts and fires only once it aims inside its cone;
  - bursts and pauses; TAP and CHARGE; an error far larger than the cone does not fire;
  - it keeps its distance, steps sideways and backs off when too close; a grenade's arc;
- **the weapons:** by distance and score, `chance`, the game's rule, no weapon that fits holds its fire, `fire_within_m` and its own distance;
- **the roam:** the goal of the highest priority within its reach (round a wall), a hidden one or one it does not want does not count, the difficulty's scale, to where it saw the enemy, a random point never on an island, stuck it jumps and changes, without a navmesh it stands;
- **the modes:** fight and roam, a mode that wants more takes over and hands back, a tie keeps what it does, an off one never runs, a mode walks with the bot's functions;
- **off or freed:** it lets go of every key, also those of an input it was connected to; without `turn_body` it only writes where it looks;
- **every file loads; the presets rise in difficulty; what runs on a server uses no camera or screen; no other kit or game is named;**
- **both examples, from start to end.**

A test that stops on a script error, or never gets to check anything, fails.

The handles have their own check in a real editor:

```bash
BOTKIT_EDITOR_CHECK=1 godot --headless --editor --path botkit_lab
```

It checks that the bot and the goal have the kit's gizmo, drags their handles from the 3D view's camera, undoes and redoes each drag, and saves the scene with its values. It prints `EDITOR CHECK PASS`.

## Outside the kit

This is the game's:

- the character and how it moves with the keys;
- the real weapons: the damage, the ammo, the heat (the kit takes your rule in `weapon_score`);
- which pickup is worth it for whom (`wanted`);
- health, death and respawn (turn the bot off with `enabled`);
- in a network game: which seat a bot plays, and when a person takes it.
