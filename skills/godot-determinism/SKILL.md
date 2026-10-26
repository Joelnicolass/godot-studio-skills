---
name: godot-determinism
description: >-
  Add a determinism smoke bench to a Godot 4 project with the AgentKit
  determinism module (DetRecorder, det_run.sh, det_cases.txt, baseline). Use for
  networked games (lockstep, client prediction, host-authoritative simulation
  that must match), replays and recorded runs, and regression smoke ("did my
  change move the simulation?"). Covers wiring the recorder, writing cases,
  blessing the baseline, reading CONTAMINATED and the watchdog, the Godot queue,
  and the usual sources of nondeterminism.
---

# Godot — determinism bench

The same run, from the same inputs, must give the same digest whatever the render clock. The bench records the simulation into a sha256 and compares it across clocks (`fixed`, `fixed2`, `stress`, optionally `window`) and against a stored baseline. It is a **smoke test**, not a byte-exact contract.

Module: `addons/agent_kit/determinism/` (part of AgentKit). Full API and flags: [reference.md](reference.md). Tests of rules and units: [godot-testing](../godot-testing/SKILL.md). Multiplayer design: [godot-mp-kit](../godot-mp-kit/SKILL.md). Driving the game with flows: [godot-agent-kit](../godot-agent-kit/SKILL.md).

## When to use it

- **Network:** lockstep, rollback or host-authoritative games where two machines must compute the same thing, or where a replay of inputs must reproduce the match.
- **Replays:** any feature that records inputs or seeds and plays them back.
- **Regression smoke:** a cheap check on every slice that a refactor did not move the simulation.

Do **not** use it for: pure UI, one-shot visuals, or code with no simulation to record. Ask first if the project has no headless-runnable scene; the bench needs one.

## How it works

1. A **bench scene** starts the simulation from CLI args (`--seed=7`, a scenario name), without a human.
2. A `DetRecorder` node writes one line per notable event, `"<tick> <kind> <text>"`, and hashes them in order.
3. When the scene ends it calls `write_outputs(report)`: a JSON with the digest, optionally the lines.
4. `det_run.sh` launches the scene several times with different clocks and compares the digests.
5. A stored **baseline** (`case digest` per line) tells you if today's reference run still equals the last accepted one.

## Wire DetRecorder

- Add a `DetRecorder` child to the bench scene (or to your match/audit node). Put it **before** the nodes it watches in the tree if you use `self_tick = true`, so the tick moves first.
- If tree order of `_physics_process` matters to you, set `self_tick = false` and call `recorder.advance()` once per physics step at the point where the clock must move.
- At start: `recorder.keep_lines = not DetCli.events_path().is_empty()`, then `recorder.start()`.
- During the run: `recorder.record("kind", "text")` for events (spawns, deaths, damage, phase changes) and `recorder.sample(bodies)` every N ticks for positions (rounded, sorted by name).
- At the end: `recorder.stop()`, `recorder.write_outputs({"seed": seed})`, then `get_tree().quit()`.
- Lines must contain **game state only**: no wall-clock time, no object ids, no dictionary iteration that depends on insertion luck, no float with unbounded precision.
- The recorder only watches. It never decides or mutates the game.

## Write det_cases.txt

One case per line, `name|args|quick|set`:

```
# name|args|quick|set
seed1|--seed=1|all|all
seed7|--seed=7|fixed|all
heavy|--seed=3 --units=200||all
```

- `args` go to the scene after `--` and are read with `DetCli.args()`.
- `quick`: `all` (every mode), `fixed` (reference only, cheapest) or empty (not in `quick`).
- `set`: `all` means part of the full `all` run (use it at the close of a milestone).
- Keep `quick` small: a few short cases that cover the main systems. Each run should be under a minute.

## Configure det.cfg

A shell file next to `det_cases.txt`, sourced by the runner:

```
DET_SCENE=res://debug/bench.tscn
DET_OUT=agent/out/det
DET_BASELINE=agent/det_baseline.txt
```

Optional: `DET_RSS_LIMIT_KB`, `DET_LIMIT_FIXED/STRESS/WINDOW` (seconds), `DET_STRESS_FPS`, `GODOT_BIN`, `GODOT_RUN_NS`. Details in [reference.md](reference.md).

## Run the bench

```
bash addons/agent_kit/determinism/det_run.sh agent/det_cases.txt quick --no-window
bash addons/agent_kit/determinism/det_run.sh agent/det_cases.txt seed1 fixed fixed2
bash addons/agent_kit/determinism/det_run.sh agent/det_cases.txt all fixed fixed2 stress
bash addons/agent_kit/determinism/det_run.sh agent/det_cases.txt table
```

Wrap it in a project script (`agent/run_determinism.sh`) so people type one short command.

## Create the baseline (bless)

1. Run `quick` (or the cases by hand) so `fixed` results exist.
2. Check the moved cases equal across `fixed` and `fixed2` (see the policy below).
3. `det_run.sh agent/det_cases.txt bless` writes `DET_BASELINE` from the `fixed` digest of every quick case.
4. Commit the baseline file with the change that caused it, and note one line saying why.

`quick` then prints `baseline CASE OK|FAIL` per case and `QUICK PASS` or `QUICK FAIL`.

## Read the result

- `DETERMINISM PASS`: every mode of every case matched `fixed`, nothing flagged.
- `!=` in the table: that mode diverged. If an `.events` file exists, the last column shows the first different line.
- **CONTAMINATED**: another Godot (not an editor) was alive while this run was measured. The digest may still be right, but the run does not count; rerun it alone.
- **watchdog**: `rss_kill` (memory over the limit), `timeout_kill` (time limit of the mode), `script_error_kill` (parse/compile error in the log: killed at once, fix the script). Any of them fails the verdict.
- `quick` needs at least two fresh modes per case; stale files from an older run never count.

## One Godot queue, no window in parallel

Every Godot launched by the bench goes through `harness/godot_run.sh`: a FIFO queue, up to 3 headless at once, one window at a time, an import alone, never more than 4 Godots. Use the same `GODOT_RUN_NS` for everything on the machine that runs Godot so they share the budget.

**No window runs in parallel with the bench.** A window and a headless bench at the same time distort timing and mark runs CONTAMINATED; two windows can hang the machine. Run the headless bench first, the window case alone afterwards (a window case must autostart and quit by itself).

## Light policy

The bench is a smoke test:

- `quick` on every slice. `all` only when closing a milestone.
- If a digest changed because of an **intentional** change: confirm `fixed` and `fixed2` give the same new digest for every moved case (the run still repeats itself), then `bless` and write one line saying what changed.
- If `fixed` and `fixed2` disagree, that is a real bug (nondeterminism), not a re-bless.
- No first-tick-different report and no four-mode ceremony for ordinary changes. Byte-exact work is for when the product needs it (rollback, ranked replays).

## Common sources of nondeterminism

- **Unseeded RNG:** `randi()`, `randf()`, `shuffle()` on the global generator. Use a `RandomNumberGenerator` with an explicit seed, owned by the match.
- **Frame-rate dependence:** `_process(delta)` for gameplay, `delta` from the render clock, `Time.get_ticks_msec()`, timers in wall time. Move to `_physics_process` with fixed ticks and count ticks.
- **Node order:** `get_children()`, groups, signals fired in tree order, `_physics_process` order between siblings. Sort by a stable key (name, id) before iterating; change order only on purpose.
- **Async navigation / region iterations:** `NavigationServer` maps sync over several frames, agents that wait for a path, baked regions finishing at different times. Wait for the map to be ready before ticking, and keep path queries inside the tick.
- **Avoidance threads:** avoidance velocities arrive on a callback, computed on a thread. Apply them at a fixed point of the tick; turn avoidance threading off in the project settings if results vary.
- **Physics timing:** variable `physics_ticks_per_second` in the editor vs bench, `max_physics_steps_per_frame` capping steps in `stress`, bodies that sleep. Keep project settings identical in every mode.
- **Dictionary / Array of objects:** hashing on object ids, iteration of unordered sets built from `instance_id`.
- **Threads and `await`:** work that finishes "when it finishes". Join it inside the tick, or record it only after a fixed delay in ticks.
- **Floats in lines:** print with fixed decimals (`position_decimals`) so noise below the threshold does not enter the digest.

## Anti-patterns

- Recording wall-clock time or object ids in lines.
- Re-blessing without checking `fixed` against `fixed2`.
- Running a window while the headless bench runs.
- Raising time limits to hide a hang instead of reading the watchdog.
- Putting game names or scoring into the module; cases and baseline live in the project.
- Forking `det_run.sh` per project instead of using `det.cfg`.

## Checklist

- [ ] Bench scene runs headless from CLI args and quits by itself.
- [ ] `DetRecorder` wired; lines contain game state only.
- [ ] `det_cases.txt` and `det.cfg` in the project (`agent/`).
- [ ] `fixed` == `fixed2` for every quick case.
- [ ] Baseline blessed and committed with a one-line reason.
- [ ] `quick --no-window` prints `QUICK PASS`.
- [ ] No other Godot or window ran during the bench (no CONTAMINATED).
