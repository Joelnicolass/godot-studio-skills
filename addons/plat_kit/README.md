# PlatKit

**2D platformer** motor as a child of `CharacterBody2D`: coyote, jump buffer, apex gravity, corner correction, lift remember. **No** levels, score, dash, or stamina.

Celeste-style forgiveness windows ([Maddy Thorson](https://maddymakesgames.com/articles/celeste_and_forgiveness/index.html)): widen timing and position in the player’s favor. This addon is **not** a Celeste clone.

## Install

```bash
./install.sh --addon /path/to/godot-project plat_kit
```

Enable the **PlatKit** plugin. Tools → `PlatKit: Add motor to selected CharacterBody2D`.

InputMap: `move_left`, `move_right`, `jump` (or change the `@export`s).

## Tree

```
Player (CharacterBody2D)
├── CollisionShape2D
├── Visual
└── PlatMotor          # body = Player (or the parent)
```

If you use a state machine: it goes as **another** child of the actor. A state calls `request_jump()` / sets `axis` with `read_input = false` (MP: the host simulates).

## Knobs (inspector)

| Group | What |
|-------|------|
| Jump | `coyote_time`, `jump_buffer`, `cut_jump_mult` |
| Apex | `apex_gravity_mult` while holding jump near vy=0 |
| Corner | `jump_corner_pixels` (ceiling); `side_corner_pixels` (0 = off; the game’s dash calls `try_side_corner_correct`) |
| Lift | `lift_remember` — platform velocity for a few frames after |
| Wall jump | off by default; `wall_extra_pixels` |

Dash, one-way pop, stamina refund: **game glue**, not this addon.

## MP

The motor runs where physics is authoritative (host / 1P). Guests do not simulate the jump. Do not put PlatKit inside another addon.
