---
name: godot-fsm
description: >-
  Adds a Godot 4 composition StateMachine (FsmKit addon: FsmMachine +
  FsmState children, actor socket, transition by node name). Use when the
  user wants a state machine, FSM, Idle/Move/Hurt states, or /add-state-machine.
  Not a platformer motor. Not gameplay rules.
---

# Godot — state machine (FsmKit)

States = **child nodes**, not an `enum` on the actor. Addon `addons/fsm_kit/` in the **game** project.

If the addon is missing:

```bash
./install.sh --addon /path/to/godot-project fsm_kit
```

Enable plugin **FsmKit**. Bounded request: `/add-state-machine`. No extra subagent: `studio-developer` (or this chat if 1–3 files).

Composition: [godot-composition-first](../godot-composition-first/SKILL.md). 2D platformer (coyote, buffer): [godot-platformer-2d](../godot-platformer-2d/SKILL.md) — the motor is **another** child; states call it.

## Tree

```
Actor
├── Visual
├── PlatMotor          # optional, other addon
└── States             # FsmMachine
    ├── Idle
    ├── Move
    └── Hurt
```

- `@export var actor` on the machine (the container).
- `@export var initial_state`.
- `transition(&"Hurt")` = node name. `transition(&"Hurt", payload)` carries generic data (`machine.payload`); the same state again only calls `apply_payload`. States or actor added later: `notify_actor_ready()`.
- Start: `autostart` (on) enters `initial_state` by itself. Off: `start(state, payload)` when the actor is ready (pooled, loaded from a save, joined mid-match).
- Who changes it: the owner calls `machine.transition()` (direct). A state's own `transition()` is a **request** that `FsmMachine._request_transition(next, payload)` decides (yes by default).
- Own tick order (rollback, turns, deterministic sim): `run_physics` / `run_process` off and `step_physics(delta)` / `step_process(delta)`. Read: `current_name()`, `is_in(&"Hurt")`.
- The state uses `actor` / `machine`, not `get_parent()` as API.

When overriding `enter` / `exit`, call `super.enter()` if you want the signals.

## What belongs in a state

| Yes | No |
|-----|----|
| `enter` / `exit`, read `actor.velocity`, call `PlatMotor.request_jump()` | HP, score, spawn, scene change |
| `physics_update` for **this** verb | `match kind` for the whole actor |
| `entered` / `exited` signals | Autoload `StateManager` |

A new state = a new node, not another `elif`.

## MP

Simulation (which state you enter) is **host-authoritative**. Guests interpolate / paint. Do not put FsmKit in `addons/mp_kit`.

If the state itself replicates (a value the host owns): a script that `extends FsmMachine` overrides `_request_transition` to write the request where the host decides and return `false`; the replicated value's setter calls `transition_to()`. A peer that joins mid-match: `autostart = false` and `start(<the state the network says>)`.

Addon tests: `godot --headless --path <project> --script res://addons/fsm_kit/tests/fsm_test_runner.gd`. Upgrading from 0.1.0: `addons/fsm_kit/CHANGELOG.md` (breaking changes first).

## Anti-patterns

- Copy `fsm_machine.gd` into a feature “to tweak it a bit”.
- States that read `Input` **and** apply damage **and** spawn.
- Machine as a global title autoload.
