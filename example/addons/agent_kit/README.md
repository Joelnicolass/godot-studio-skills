# AgentKit

A CLI for agents (and people) over a Godot 4 project: capture, click flows, HTTP, inspect, PNG diff. **Zero gameplay.**

It is not an MCP. The agent runs the Godot binary. The `godot-agent-kit` and `godot-playtest` skills say when.

## Why it exists

`godot -s /tmp` + `extends SceneTree` breaks autoloads: the game's `class_name`s compile **first**. The AgentKit autoload captures from the project and **survives** `change_scene`.

## Install

```bash
./install.sh --addon /path/to/godot-project
```

Enable the **AgentKit** plugin. CI/headless:

```
AgentKit="*res://addons/agent_kit/agent_kit.gd"
```

Without `--agent=`, F5 does not change.

The **game's** workspace: `res://agent/` (`install.sh` creates it). **Everything** the agent creates for AgentKit (JSON, harness, `.tscn` fixtures, PNG) goes there. Zero test scenes in `scenes/`. Contract: `skills/godot-agent-kit/harness.md`. The installer copies `.cursor/rules/agent-kit-workspace.mdc`.

## CLI

```bash
addons/agent_kit/cli.sh /path/to/godot-project VERB [flags]
```

| Verb | Window | What it does |
|------|---------|----------|
| `info` | headless OK | version, main scene, viewport |
| `capture` | **yes** | PNG (`--scene=`, `--wait=`, `--out=`) |
| `flow` | **yes** | JSON (`--flow=`, `--out=` dir) |
| `fetch` | headless OK | HTTP (`--url=`, `--out=`, `--ua=`) |
| `inspect` | headless OK | the tree or `%UniqueName` |
| `diff` | headless OK | two PNGs (`--a=`, `--b=`, `--out=`, `--threshold=`) |

Lines to grep: `AGENT_OK`, `AGENT_FAIL`, `AGENT_SHOT=`, `AGENT_PRINT`, `AGENT_CLICK`, `AGENT_PRESS`, `AGENT_STEP`, `AGENT_STEP_ERROR`, `AGENT_ERRORS`, `AGENT_SKIP`, `AGENT_REPEAT`, `AGENT_DIFF`, `AGENT_JSON`, `AGENT_CALL`.

## Flow JSON

```json
{
  "scene": "res://scenes/ui/boot.tscn",
  "wait_first": 0.8,
  "steps": [
    { "shot": "01.png" },
    { "click": "%PlaySolo" },
    { "press": "ui_accept" },
    { "wait": 0.4 },
    { "assert": { "node": "%AfterPlay", "visible": true } },
    { "print": { "node": "%Status", "prop": "text" } }
  ]
}
```

`click` puts the pointer at the control's center and fails if it does not fire `pressed`. `%Name` is searched in the scene and its children. `press` only accepts an action that is **already** in the InputMap; if it does not exist, it fails with `unmapped input`. `call` on a product node, `seed` and `time_scale` fail. `--fail-on-error` fails if the engine logged ERROR / SCRIPT ERROR. `--flow=boot_smoke.json` looks in `res://agent/flows/`. `--out=` default: `res://agent/out`.

The harness does not move actors. AgentKit mounts it **only** with `--agent=`. A player's F5 does not load it.

UI that shows up and goes away:

```json
{
  "try_click": "%PlaySolo",
  "repeat": {
    "times": 80,
    "until": { "node": "%AfterPlay", "visible": true },
    "steps": [
      { "try_click": "%PlaySolo" },
      { "wait": 0.2 }
    ]
  }
}
```

`try_click` does not fail if the node is missing, `disabled` or not visible (`AGENT_SKIP`). Step details: `skills/godot-agent-kit/flows.md`. Demo: `example/agent/flows/`.

Experimental editor: `experimental/agent-flow-editor/` (Vite, **pnpm**). It is not part of `./install.sh`.

## Determinism

Smoke bench for simulations: `addons/agent_kit/determinism/`. A `DetRecorder` node records the run into a sha256 and `det_run.sh` compares the digest across clocks (`fixed`, `fixed2`, `stress`, `window`) and against a stored baseline.

```bash
bash addons/agent_kit/determinism/det_run.sh agent/det_cases.txt quick --no-window   # smoke on every slice
bash addons/agent_kit/determinism/det_run.sh agent/det_cases.txt bless               # re-record the baseline after an intentional change
bash addons/agent_kit/determinism/det_run.sh agent/det_cases.txt table               # verdict from what is on disk
```

- Cases in `agent/det_cases.txt` (`name|args|quick|set`), config in `agent/det.cfg` (`DET_SCENE`, `DET_OUT`, `DET_BASELINE`).
- Every Godot goes through `harness/godot_run.sh` (FIFO queue). No window runs in parallel with the bench; a run flagged `CONTAMINATED` or with a `watchdog` does not count.
- It is a smoke test, not byte-exact: when a digest moves because of an intentional change, check that `fixed` and `fixed2` agree and re-record with `bless`.
- Self-test without a game: `det_selftest.sh`. Full guide: skill `godot-determinism`.

## What it is not

Not a unit test runner. Not an MCP. Not a game engine. The playtest asks for no OK: it only writes in `res://agent/` and does not change business rules.

## Version

0.1.4
