# FsmKit changelog

## 0.2.1

- Minimal example `examples/minimal_2d/`: an actor with `Idle`, `Move` and `Hurt` (payload and `apply_payload`), and a Label that follows `state_changed`. The tests play it with input.
- The test runner fails a test that stops on a script error or made no check at all; it used to count it as a pass. Script errors are seen from Godot 4.5 on (with a `Logger`); on an older version only the checks count.

Nothing to update in your project.

## 0.2.0

From **0.1.0**, everything below. If your project has 0.1.0, check the four breaking changes first.

**Breaking**

1. `transition` and `transition_to` take a payload: `transition(state_name, next_payload := null)` on `FsmMachine` and `FsmState`, `transition_to(next, next_payload := null)`. A script that overrides one of them with the 0.1.0 signature (one argument) no longer parses ("the function signature doesn't match the parent"). Fix: add `next_payload: Variant = null`.
2. Asking for the current state is no longer a no-op. `transition(&"<current>")` keeps the state (no `exit` / `enter`) but sets `payload`, calls `apply_payload(payload)` on it and emits `transitioned(from, from, payload)`. `state_changed` still fires only on a real change. If you called it every frame "to make sure", call it only when the state should change, or check `is_in()` first.
3. `actor` defaults to the machine's parent, and the first `enter` waits until there is an actor and a state. In 0.1.0 the machine entered in `_ready` even with `actor` null.
4. A state's own `transition()` is a request: it goes through `FsmMachine.request()` and `_request_transition()`. The default says yes, so nothing changes unless you override it. The machine's `transition()` / `transition_to()` stay direct.

**New**

- `payload` on the machine, `apply_payload()` on the state, the `transitioned(from_name, to_name, next_payload)` signal, `notify_actor_ready()`.
- `autostart` (default on) and `start(state, payload)`: start when you say, in the state you say. `is_started()`.
- `_request_transition(next, payload) -> bool`: who owns the state decides a state's request.
- `step_physics(delta)` / `step_process(delta)`: tick the current state yourself (with `run_physics` / `run_process` off).
- `current_name()`, `is_in(name)`.
- A state added after the machine is ready gets its `machine` too.
- Tests: `addons/fsm_kit/tests/fsm_test_runner.gd`.

## 0.1.0

`FsmMachine` + `FsmState` children, transition by node name, `actor` injected, `state_changed`.
