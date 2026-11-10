# BotKit changelog

## 0.1.0

The first version: bots that play your character like a person, in 3D.

- `Bot3D`: a node on the character that presses a player's keys in `bot.input` (`BotInput`, which reads like `Input`). It sees the nearest enemy of `target_group` with no wall in between; in a fight it turns at a person's speed, aims with an error, reacts before its first shot, fires inside a cone, in bursts, aims ahead and lobs in an arc, keeps its distance and steps sideways without leaving the navmesh. With nobody in sight it walks the navmesh: to a goal, to where it saw the enemy, or to a random reachable point; stuck, it jumps and picks another way. `enabled` lets go of every key. `turn_body` off only writes `yaw` and `pitch`, for a network game.
- The game's rules in functions: `is_enemy`, `choose_target`, `weapon_score`.
- `BotWeapon`: range, score, `chance`, `keep_m`, `fire_within_m`, the projectile's speed and gravity, a HOLD, TAP or CHARGE trigger.
- `BotDifficulty` with three presets: easy, normal and hard.
- `BotGoal3D`: a place worth walking to (a pickup), with priority, reach and `wanted`.
- `BotMode`: your own behaviours as child nodes; the bot does what it wants most.
- Editor: the bot's sight, fire cone and fight distance in the 3D view, with handles for its eye and aim heights; a goal's reach, with its handle; every drag undoes; warnings. `show_in_game` draws what it thinks while it plays.
- Examples `minimal_3d` (a robot that hunts you) and `arena_3d` (four bots with a rifle and grenades, pickups, fleeing when hurt, difficulty).
- `botkit_lab`: 40 tests and an editor check.
