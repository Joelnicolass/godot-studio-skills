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

`transition(&"Hurt", payload)` carries generic data (a hitbox, a target); the kit does not interpret it and the state reads `machine.payload`. Asking for the current state again with a new payload does not exit / enter: the state gets `apply_payload(payload)`. The `transitioned(from, to, payload)` signal fires on every transition, a repeat included (`state_changed` only on a real change).

## Start

With `autostart` on (the default) the machine enters `initial_state` (or its first `FsmState` child) by itself, once it has a state and an actor (`actor` defaults to the parent). If the states or the actor come later, call `notify_actor_ready()` once they exist.

With `autostart` off nothing runs until you call `start(state, payload)`: an actor that sets itself up first, a pooled enemy, a character loaded from a save, a player who joins mid-match in the state the network says.

```gdscript
machine.start($States/Hurt, {"animate": false})   # once; false if there is no state or no actor yet
```

## Who changes the state

| Who | Call | What happens |
|---|---|---|
| The owner (the actor, the game) | `machine.transition(&"Hurt", payload)` or `transition_to(node, payload)` | Changes now |
| A state | `transition(&"Hurt", payload)` (its own) | A request: `FsmMachine._request_transition(next, payload)` decides. By default it says yes and the state changes now |

Override `_request_transition` (a script that `extends FsmMachine`) when the state belongs to someone else: a value the network replicates, a replay, a tutorial that only allows some steps. Write where the state lives and return `false`; whoever owns it calls `transition_to()` later.

```gdscript
extends FsmMachine

func _request_transition(next: FsmState, next_payload: Variant) -> bool:
	if not multiplayer.is_server():
		return false          # the server decides; its replicated value calls transition_to() here
	return true
```

## Ticking it yourself

The machine calls the current state's `physics_update` / `update` from its own `_physics_process` / `_process`. To tick in your own order (a rollback, a deterministic simulation, turns, pausing one actor) turn `run_physics` / `run_process` off and call `step_physics(delta)` / `step_process(delta)` where you need them. Leave the flag on **or** call the step, not both: both runs the state twice.

## Reading it

`current` (the node), `current_name()` (empty before it starts), `is_in(&"Hurt")`, `is_started()`, `payload`.

## Tests

```bash
godot --headless --path <project> --script res://addons/fsm_kit/tests/fsm_test_runner.gd
```

`FSMKIT TESTS PASS (n)`. The first time in a project, import it once (`godot --headless --path <project> --import`) so `FsmMachine` / `FsmState` are known.

Changes between versions, and what to update in your project: [CHANGELOG.md](CHANGELOG.md).

## Don’t

- A 200-line `enum` + `match` on the actor.
- Store HP / score / spawn in a state.
- Fork the addon per title.
