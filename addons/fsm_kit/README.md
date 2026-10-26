# FsmKit

State machine by **composition**: one `FsmMachine` and `FsmState` children. **No** match rules, score, or copy. No autoload.

The actor is a thin container. States do **not** use `get_parent()` as API: the machine injects `actor`.

## Install

```bash
./install.sh --addon /path/to/godot-project fsm_kit
```

Enable the **FsmKit** plugin (`FsmMachine` / `FsmState` in Create Node). Tools → `FsmKit: Add machine under selection`.

## Tree

```
Actor (CharacterBody2D / …)
├── Visual
└── States          # FsmMachine, @export actor = Actor, initial_state = Idle
    ├── Idle        # FsmState
    ├── Move
    └── Hurt
```

`transition(&"Hurt")` looks up the **node name**. Each state overrides `enter` / `exit` / `update` / `physics_update` / `handle_input`.

`transition(&"Hurt", payload)` carries generic data (a hitbox, a target); the kit does not interpret it and the state reads `machine.payload`. Asking for the current state again with a new payload does not exit / enter: the state gets `apply_payload(payload)`. The `transitioned(from, to, payload)` signal fires on every transition, a repeat included (`state_changed` only on a real change). If the states (or the actor) are added after the machine is ready, call `notify_actor_ready()` once they exist: the first `enter` waits for them.

## Don’t

- A 200-line `enum` + `match` on the actor.
- Store HP / score / spawn in a state.
- Fork the addon per title.
