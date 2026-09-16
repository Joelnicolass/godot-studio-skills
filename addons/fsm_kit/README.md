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

## Don’t

- A 200-line `enum` + `match` on the actor.
- Store HP / score / spawn in a state.
- Fork the addon per title.

Skill: `godot-fsm`. Command: `/add-state-machine`.
