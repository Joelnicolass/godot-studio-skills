# PlatKit

**2D platformer** motor as a child of a `CharacterBody2D`: coyote, jump buffer, apex gravity, corner correction, lift remember. **No** levels, score, dash, or stamina. No autoload, and it depends on no other kit.

Celeste-style forgiveness windows ([Maddy Thorson](https://maddymakesgames.com/articles/celeste_and_forgiveness/index.html)): widen timing and position in the player’s favor. This addon is **not** a Celeste clone.

## Install

```bash
./install.sh --addon /path/to/godot-project plat_kit
```

Enable the **PlatKit** plugin. Project ▸ Tools ▸ *PlatKit: Add motor to selected CharacterBody2D* adds the motor to the selected body (Ctrl+Z undoes it).

InputMap: `move_left`, `move_right`, `jump` (or change the actions in the motor's *InputMap* group).

## Minimal example

`examples/minimal_2d/minimal_2d.tscn` (F6): a player on a floor and two ledges. Arrows to run, Space to jump (a tap jumps low, holding it jumps high). Try jumping right after leaving a ledge (coyote) or right before landing (buffer).

It has no code: it is the tree and the inspector.

```
Minimal2D
├── Floor, LedgeLow, LedgeHigh   # StaticBody2D
├── Walls                        # two WorldBoundaryShape2D on the sides
└── Player (CharacterBody2D)
    ├── Shape, Look
    └── PlatMotor                # body = Player; actions ui_left / ui_right / ui_accept; jump_speed = 420
```

The example's motor reads the `ui_*` actions so it runs in any project; a game sets its own.

## Tree

```
Player (CharacterBody2D)
├── CollisionShape2D
├── Visual
└── PlatMotor          # body = Player (or the parent)
```

If you use a state machine, it goes as **another** child of the actor (below, [Driving it from another script](#driving-it-from-another-script)).

## Knobs (inspector)

| Group | What |
|-------|------|
| Run | `max_speed`, `accel`, `friction` (px/s and px/s²) |
| Jump | `jump_speed`, `gravity`, `fall_gravity_mult` (falls faster than it rises), `cut_jump_mult` (letting go early cuts the jump), `coyote_time`, `jump_buffer` |
| Apex | `apex_gravity_mult` while jump is held near vy = 0 (`apex_speed_threshold`) |
| Corner | `jump_corner_pixels` (ceiling); `side_corner_pixels` (0 = off; the **game’s** dash calls `try_side_corner_correct`) |
| Lift | `lift_remember`: the platform’s velocity, for a few seconds after leaving it |
| Wall jump | off by default; `wall_extra_pixels`, `wall_jump_velocity` |

A held jump is roughly `jump_speed² / (2 · gravity)` pixels high: 320 and 980 (the defaults) give about 52 px; the example raises `jump_speed` to 420, about 90 px.

Dash, one-way pop, stamina refund: **game glue**, not this addon.

## Driving it from another script

With `read_input` off the motor does not read the InputMap: a state, an AI or the network feeds it.

```gdscript
# The script that drives the motor: a player state, an AI, the network.
@export var motor: PlatMotor


func _physics_process(_delta: float) -> void:
	motor.axis = Input.get_axis(&"move_left", &"move_right")
	if Input.is_action_just_pressed(&"jump"):
		motor.request_jump()
	if Input.is_action_just_released(&"jump"):
		motor.release_jump()
```

| Call | What it does |
|---|---|
| `axis` | The run, -1 to 1 |
| `request_jump()` | Press jump: it fires now on the floor or in coyote time, or on landing within `jump_buffer` |
| `release_jump()` | Let go of jump: cuts a rising jump and stops floating at the apex. A tap still in the buffer fires on landing anyway |
| `tick(delta)` | One physics step. With `auto_process` on the motor calls it; off, call it yourself in your own order (your own simulation, a rollback) |
| `wall_dir()` | -1 / 1 when a wall is on the left / right (or within `wall_extra_pixels`), else 0 |
| `try_side_corner_correct(delta)` | Steps up a lip of up to `side_corner_pixels` when running into it (the game’s dash) |

## Multiplayer

PlatKit has no networking. The motor runs where physics is simulated (the server, or a single-player game) and everyone else draws the body you sync. With `read_input` off, the server feeds it the owner’s input (with MpKit, what it reads from their `MpInput`). The motor’s timers (coyote, buffer, lift) are not part of the pose: a reconciliation that rewinds the body does not rewind them.

## Tests

```bash
godot --headless --path <project> --script res://addons/plat_kit/tests/plat_test_runner.gd
```

In the kit's repo, the project is `platkit_lab/` (where `addons/plat_kit` is a symlink).

`PLATKIT TESTS PASS (n)`. They play the motor on real physics (landing, running, the jump and its cut, the apex, the buffer, coyote time, the corner, the wall jump, a moving platform, `tick()` by hand) and the minimal example with input. A test that stops on a script error, or never gets to check anything, fails. The first time in a project, import it once (`godot --headless --path <project> --import`) so `PlatMotor` is known.

Changes between versions, and what to update in your project: [CHANGELOG.md](CHANGELOG.md).

## Tips and recommendations

- Start from the defaults (coyote 0.08 s, buffer 0.12 s) and change them while playing, one at a time. Windows that are too wide feel like a jump that happens by itself.
- The jump height comes from `jump_speed` and `gravity`; the feel, from `fall_gravity_mult` (falling faster) and `apex_gravity_mult` (floating at the top). Tune those before the height.
- One `move_and_slide` per frame: the motor calls it. The body's script does not move the body.
- Moving platforms: an `AnimatableBody2D`. On a jump, the body takes the platform's velocity once: Godot adds it on leaving (`platform_on_leave`) and the motor only adds the remembered one in coyote time, or if you turned that off.
- With a state machine: `read_input` off and the states feed `axis`, `request_jump()` and `release_jump()`. Without `release_jump()` the jump stays "held" forever.
- Dash, one-way, super wall jump, stamina: those belong to your game. The catalog of how to do them is in the `godot-platformer-2d` skill (`forgiveness.md`).

## Don’t

- `is_on_floor()` + jump **without** coyote or buffer in a precision game.
- Move the body in its own script and also in the motor.
- Put PlatKit inside another addon, or fork it per title.
