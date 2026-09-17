---
name: godot-agent-kit
description: >-
  Drive a Godot 4 project with AgentKit (addon like MpKit): screenshots,
  click/type flows, HTTP fetch, node inspect, PNG diff. Use when capturing
  the game, writing res://agent/ flows or harnesses, or when tempted to add
  playtest helpers (spawn / force-state / count / pause for the flow) to src/.
  Not GUT. Not an MCP.
---

# AgentKit — tools for the agent (no MCP)

Addon `addons/agent_kit/` in the **game** project. Zero gameplay. The agent talks to Godot over CLI; `AGENT_OK` / `AGENT_FAIL` lines are the contract. JSON, harnesses, and dumps live in the game’s **`res://agent/`**, not inside the addon and not in `src/`.

If the addon is missing:

```bash
# from godot-studio-skills
./install.sh --addon /path/to/godot-project agent_kit
```

Enable the **AgentKit** plugin (autoload). With no `--agent=`, F5 is unchanged.

## Do not do this

```bash
godot --path game -s /tmp/capture.gd   # extends SceneTree
```

The game’s `class_name` scripts compile **before** autoloads → `PortraitCache` / `DraftCopy` missing. Capture with AgentKit.

## How to run

```bash
addons/agent_kit/cli.sh /ABS/PROJECT VERB [--flag=value ...]
# GODOT=/path/to/Godot if it is not on PATH / Applications / Downloads
```

`cli.sh` passes `--headless` for info/fetch/inspect/diff. It does **not** for capture/flow (you need a window for pixels).

| Verb | Flags |
|------|--------|
| `capture` | `--out=res://agent/out/a.png` `--scene=res://...` `--wait=1.1` `--fail-on-error` |
| `flow` | `--flow=boot_smoke.json` (or `res://agent/flows/…`) `--out=res://agent/out` `--fail-on-error` |
| `diff` | `--a=` `--b=` `--out=/tmp/diff.png` `--threshold=0.02` |
| `inspect` | `--unique` `--node=%CardView` `--scene=` |
| `fetch` | `--url=` `--out=` `--ua=` (Wikimedia requires User-Agent) |
| `info` | viewport, main scene, version, InputMap `actions` |

Grep: `AGENT_OK`, `AGENT_FAIL`, `AGENT_SHOT=`, `AGENT_PRINT`, `AGENT_CLICK`, `AGENT_PRESS`, `AGENT_SELECT`, `AGENT_RANGE`, `AGENT_SCROLL`, `AGENT_DRAG`, `AGENT_CALL`, `AGENT_HARNESS`, `AGENT_STEP`, `AGENT_STEP_ERROR`, `AGENT_ERRORS`, `AGENT_SKIP`, `AGENT_REPEAT`, `AGENT_DIFF`, `AGENT_JSON`.

JSON in `res://agent/flows/`. Helpers **only** in `res://agent/harness/*.gd`. Contract: [harness.md](harness.md) — read it **before** touching a product `.gd`. Spawn / force-state / count / pause for the flow do **not** belong in `src/` (`agent_*` or the same role under another name).

Long flows (a button that is not on your turn): `try_click` + `repeat` until `%ResultsView` is visible. API: `addons/agent_kit/README.md`. JSON detail: [flows.md](flows.md).

**Experimental** cable editor (localhost, not in `./install.sh`): `experimental/agent-flow-editor/` (`pnpm install` && `pnpm dev`) — bind the Godot project, paste `%UniqueName` / InputMap, **Run flow** runs the same JSON.

## When

- Playtest / visual: capture or flow, not a PNG from memory.
- Compare before/after a shader or layout: `capture` + `diff`.
- Download a thumb into `res://`: `fetch` (do not scrape by hand without UA).
- Understand a scene: `inspect --unique`.

Human playtest still needs OK (`godot-playtest`). Visual still needs `VISUAL.md` (`godot-visual-qa`). GUT tests: `godot-testing`.
