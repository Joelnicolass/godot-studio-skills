# FsmKit

State machine by **composition**: one `FsmMachine` and `FsmState` children. **No** match rules, score, or copy. No autoload.

The actor is a thin container. States do **not** use `get_parent()` as API: the machine injects `actor`.

## Install

```bash
./install.sh --addon /path/to/godot-project fsm_kit
```

Enable the **FsmKit** plugin (`FsmMachine` / `FsmState` in Create Node). Project ▸ Tools ▸ *FsmKit: Add machine under selection* adds `States` with `Idle` and `Move` under the selected node (Ctrl+Z undoes it).

## Minimal example

`examples/minimal_2d/minimal_2d.tscn` (F6): a square with three states. The arrows move it (`Move`), Enter is a hit that pushes it (`Hurt`), and then it goes back to `Idle`. It uses the `ui_*` actions, so it runs in any project.

```
Minimal2D
├── Mover            # CharacterBody2D, mover.gd
│   ├── Shape, Body
│   └── States       # FsmMachine: actor = Mover, initial_state = Idle
│       ├── Idle     # states/idle.gd
│       ├── Move     # states/move.gd: @export speed
│       └── Hurt     # states/hurt.gd: @export duration, push_speed, tint
└── Hud/State        # a Label that follows state_changed
```

The actor only turns what happens in the game into a transition:

```gdscript
# mover.gd (the essentials)
extends CharacterBody2D

@onready var states: FsmMachine = $States


func hit(push: Vector2) -> void:
	states.transition(&"Hurt", push)  # the owner: changes now; the push travels as the payload
```

Each state does its part, with its numbers in its own inspector, and asks for the next one:

```gdscript
# states/move.gd
extends FsmState

@export var speed := 220.0


func physics_update(_delta: float) -> void:
	var wish := Input.get_vector(&"ui_left", &"ui_right", &"ui_up", &"ui_down")
	if wish == Vector2.ZERO:
		transition(&"Idle")  # a request: it goes through _request_transition()
		return
	var body := actor as CharacterBody2D
	body.velocity = wish * speed
	body.move_and_slide()
```

```gdscript
# states/hurt.gd (the essentials)
func enter() -> void:
	super()  # emits entered
	_start(machine.payload)


func apply_payload(next_payload: Variant) -> void:
	_start(next_payload)  # another hit while hurt: the same state with a new push
```

The rest of the game listens to the machine, like the example's Label: `states.state_changed.connect(_show)`.

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

In the kit's repo, the project is `fsmkit_lab/` (where `addons/fsm_kit` is a symlink).

`FSMKIT TESTS PASS (n)`. They also play the minimal example with input. A test that stops on a script error, or never gets to check anything, fails (script errors are seen from Godot 4.5 on). The first time in a project, import it once (`godot --headless --path <project> --import`) so `FsmMachine` / `FsmState` are known.

Changes between versions, and what to update in your project: [CHANGELOG.md](CHANGELOG.md).

## Tips and recommendations

- Each number goes on the state that uses it (`@export var speed` on `Move`), not on the actor: changing a value opens one node.
- The actor stays thin. It turns what happens in the game (a hit, an order, a value from the network) into `machine.transition(...)`; states use `actor` and `machine`, never `get_parent()`.
- Call `super()` in `enter` / `exit` if anything listens to `entered` / `exited`.
- Asking for the current state with another payload does not exit or enter: it arrives as `apply_payload`. Use it for "another hit while hurt" without restarting the animation.
- A new state is a new node. If a `match state` shows up on the actor, a state is missing.
- Ticking in your own order (rollback, turns, network)? Turn `run_physics` / `run_process` off and call `step_physics` / `step_process`: one or the other.
- Someone else decides the state (the server)? An `extends FsmMachine` that overrides `_request_transition` and returns `false` (above, in [Who changes the state](#who-changes-the-state)).
- A movement motor (PlatKit's `PlatMotor`, for example) goes as **another** child of the actor, with its own input reading off; the states feed it. Kits do not know each other: your script joins them.

## Don’t

- A 200-line `enum` + `match` on the actor.
- Store HP / score / spawn in a state.
- Fork the addon per title.
