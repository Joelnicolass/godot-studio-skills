---
name: godot-agent-kit
description: >-
  Drive a Godot 4 project with AgentKit (addon like MpKit): screenshots,
  click/type flows, HTTP fetch, node inspect, PNG diff. Use when capturing
  the game, comparing frames, probing UI, downloading a URL into res://,
  or when tempted to write a /tmp SceneTree -s script. Not GUT. Not an MCP.
---

# AgentKit — tools for the agent (no MCP)

Addon `addons/agent_kit/` in the **game** project. Zero gameplay. The agent talks to Godot over CLI; `AGENT_OK` / `AGENT_FAIL` lines are the contract.

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
| `capture` | `--out=/tmp/a.png` `--scene=res://...` `--wait=1.1` |
| `flow` | `--flow=res://...json` `--out=/tmp/dir` |
| `diff` | `--a=` `--b=` `--out=/tmp/diff.png` `--threshold=0.02` |
| `inspect` | `--unique` `--node=%CardView` `--scene=` |
| `fetch` | `--url=` `--out=` `--ua=` (Wikimedia requires User-Agent) |
| `info` | viewport, main scene, version |

Grep: `AGENT_OK`, `AGENT_FAIL`, `AGENT_SHOT=`, `AGENT_PRINT`, `AGENT_CLICK`, `AGENT_SKIP`, `AGENT_REPEAT`, `AGENT_DIFF`, `AGENT_JSON`.

Long flows (a button that is not on your turn): `try_click` + `repeat` until `%ResultsView` is visible. API: `addons/agent_kit/README.md`. JSON detail: [flows.md](flows.md).

**Experimental** cable editor (localhost, not in `./install.sh`): `experimental/agent-flow-editor/` (`pnpm install` && `pnpm dev`) — build the same JSON to see what the playtester will press.

## When

- Playtest / visual: capture or flow, not a PNG from memory.
- Compare before/after a shader or layout: `capture` + `diff`.
- Download a thumb into `res://`: `fetch` (do not scrape by hand without UA).
- Understand a scene: `inspect --unique`.

Human playtest still needs OK (`godot-playtest`). Visual still needs `VISUAL.md` (`godot-visual-qa`). GUT tests: `godot-testing`.
