# Determinism module — reference

Everything lives in `addons/agent_kit/determinism/`. No game names, no scoring.

## Files of the module

| File | What |
|------|------|
| `det_recorder.gd` | `DetRecorder` node: record + sha256 |
| `det_cli.gd` | `DetCli` static helpers for `--key=value` args |
| `det_run.sh` | The runner: modes, watchdog, baseline, `quick`, `bless`, `table` |
| `det_report.py` | Table and verdict (`DETERMINISM PASS/FAIL`) |
| `harness/godot_run.sh` | FIFO queue for every Godot launch |
| `harness/godot_busy.sh` | "Is another Godot running?" probe used before an import |
| `det_selftest.sh` | Self-test of the module with its own scene |
| `example/` | `det_selftest.tscn`, `det.cfg`, `det_cases.txt` |

## DetRecorder API

`class_name DetRecorder extends Node`.

- `@export var keep_lines := false`: keep every line (needed for `--events=` and for the first-different-line report).
- `@export var self_tick := true`: the node counts physics ticks itself. With `false`, the owner calls `advance()`.
- `@export var position_decimals := 1`: decimals used by `sample()`.
- `start()`, `stop()`, `advance()`.
- `record(kind: String, text: String)`: writes `"<tick> <kind> <text>"` and hashes it plus a newline. Ignored when not running.
- `sample(bodies: Array)`: one `pos` line per valid body, sorted by name.
- `digest() -> String`: sha256 hex of all lines. The first call fixes the value.
- `write_outputs(report: Dictionary)`: adds `digest`, `events` (line count), `end_tick`; writes `--out=*.json` and `--events=*` if given; emits `finished(digest)`.
- Properties: `tick`, `running`, `line_count`, `lines`.

## DetCli API

`class_name DetCli`, all static:

- `args() -> Dictionary`: every `--key=value` (or bare `--flag` = true) after `--`.
- `out_path()`, `events_path()`: where the runner wants the report and the lines (`""` if not asked).
- `absolute(path)`: relative paths are relative to the project.

## det_run.sh CLI

```
det_run.sh CASES CASE|all [MODE...] [--no-window]
det_run.sh CASES quick [--no-window]
det_run.sh CASES table [CASE...]
det_run.sh CASES bless
```

- `CASE`: run that case in the listed modes. `all`: every case with `set=all`.
- `quick`: deletes old results of the quick cases, runs them, compares each `fixed` digest with the baseline (`baseline CASE OK|FAIL`), requires two fresh modes per case, prints `QUICK PASS` or `QUICK FAIL`.
- `table`: verdict and markdown table from what is on disk.
- `bless`: writes the baseline from the `fixed` results of the quick cases. Fails if one is missing.
- `--no-window`: headless only (`fixed fixed2 stress`); the default set with a window is `fixed stress window`.
- `fixed` always runs, and a verdict needs at least two fresh modes.

## det.cfg variables

Shell file, sourced; looked up next to the cases file or at `$DET_CFG`. Paths relative to the project.

| Variable | Default |
|----------|---------|
| `DET_SCENE` | required, `res://...` |
| `DET_PROJECT` | folder with `project.godot` above the cases file |
| `DET_OUT` | `agent/out/det` |
| `DET_BASELINE` | `agent/det_baseline.txt` (lines `case digest`) |
| `DET_RSS_LIMIT_KB` | 2500000 |
| `DET_LIMIT_FIXED` / `_STRESS` / `_WINDOW` | 600 / 900 / 900 seconds |
| `DET_STRESS_FPS` | 6 |
| `DET_WINDOW_RES`, `DET_WINDOW_ARGS` | `1280x720`, `--autostart --quit` |
| `DET_JOBS` | 3 (case/mode runs at once, at most 3; `1` = one at a time) |
| `GODOT_BIN`, `GODOT_RUN_NS` | PATH lookup; queue namespace |

`DET_OUT` and `DET_BASELINE` from the environment win over the cfg.

## det_cases.txt format

`name|args|quick|set`, `#` comments and blank lines ignored.

- `quick`: `all` | `fixed` | empty.
- `set`: `all` | empty.
- `args`: passed to the scene after `--`, split on spaces.

## Modes

| Mode | What |
|------|------|
| `fixed` | `--headless --fixed-fps 60`: as fast as possible, 1/60 per frame. The reference. |
| `fixed2` | `fixed` again: a run must repeat itself. |
| `stress` | headless, real time, `--max-fps $DET_STRESS_FPS`: several physics steps per frame, so render clock != tick clock. |
| `window` | a real window, `--max-fps 60`. Comparable only if the scene autostarts and quits by itself. Never two at once. |

## Output files

In `$DET_OUT`, per `<case>_<mode>`: `.json` (report with `digest`, `end_tick`, `events`), `.events` (lines, if `keep_lines`), `.log` (Godot output), `.meta` (`wall_s rss_max_kb contaminated watchdog`).

Table columns: case, mode, sha256, end_tick, lines, vs fixed, wall, RSS max, warnings, first different line.

## Watchdog and CONTAMINATED

The runner watches the Godot child process each second:

- `rss_kill`: RSS above `DET_RSS_LIMIT_KB`.
- `timeout_kill`: wall time (from when Godot actually starts, not the queue wait) above the limit of the mode.
- `script_error_kill`: `Parse Error`, `Compile Error` or `Failed to load script` in the log. Killed at once.
- `none`: normal.

`contaminated=1` means a Godot process that is not this bench's (nor an editor) appeared during the run; the bench's own parallel runs (their `--out=` is in `DET_OUT`) and the queue's import of the project do not count. It is a warning only: a digest does not depend on the load, so it never fails the verdict; that run's wall time and RSS are not comparable. A watchdog kill fails the verdict.

## godot_run.sh queue

`godot_run.sh <godot command...>` runs one Godot under a machine-wide scheme:

- FIFO tickets: a stream of windows cannot starve headless waiters.
- Headless: up to `HEADLESS_SLOTS` (3). Window: one at a time, alongside headless. Import (`--import`): alone. At most `GODOT_MAX` (4) Godots.
- Locks are directories under `/tmp/<GODOT_RUN_NS>_godot.*`; a lock whose holder died is removed.
- A window run has a wall cap `GODOT_WINDOW_MAX_S` (600; 0 = none).
- A `class_name` preflight reports `clases sin importar` when the cache is stale; import once and retry. `GODOT_RUN_NO_PREFLIGHT=1` skips it; `GODOT_RUN_PREFLIGHT_EXCLUDE` lists folders to ignore.
- Same `GODOT_RUN_NS` for every script on the machine that launches Godot, so they share the budget. Parallel agents use separate worktrees (one `.godot/` each).

## Self-test

`bash addons/agent_kit/determinism/det_selftest.sh` (needs Godot, a few minutes) runs the example scene (20 rigid bodies, fixed seed) in a scratch folder and checks: same digest in `fixed`/`fixed2`/`stress`; `bless` then `quick` passes; a false baseline digest gives `QUICK FAIL`; `--break` is killed by `script_error_kill`. Prints `SELFTEST PASS` or `SELFTEST FAIL`.
