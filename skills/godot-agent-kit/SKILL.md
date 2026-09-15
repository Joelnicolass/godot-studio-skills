---
name: godot-agent-kit
description: >-
  Drive a Godot 4 project with AgentKit (addon like MpKit): screenshots,
  click/type flows, HTTP fetch, node inspect, PNG diff. Use when capturing
  the game, comparing frames, probing UI, downloading a URL into res://,
  or when tempted to write a /tmp SceneTree -s script. Not GUT. Not an MCP.
---

# AgentKit — tools for the agent (no MCP)

Addon `addons/agent_kit/` in the **game** project. Cero gameplay. El agente habla con Godot por CLI; las líneas `AGENT_OK` / `AGENT_FAIL` son el contrato.

Si el addon no está:

```bash
# desde godot-studio-skills
./install.sh --addon /path/to/godot-project agent_kit
```

Enable plugin **AgentKit** (autoload). Sin `--agent=`, F5 no cambia.

## No hagas esto

```bash
godot --path game -s /tmp/capture.gd   # extends SceneTree
```

Los `class_name` del juego se compilan **antes** que los autoloads → `PortraitCache` / `DraftCopy` missing. Capturá con AgentKit.

## Cómo correr

```bash
addons/agent_kit/cli.sh /ABS/PROJECT VERB [--flag=value ...]
# GODOT=/path/to/Godot si no está en PATH / Applications / Downloads
```

`cli.sh` pone `--headless` en info/fetch/inspect/diff. **No** lo pone en capture/flow (hace falta ventana para píxeles).

| Verb | Uso |
|------|-----|
| `capture` | `--out=/tmp/a.png` `--scene=res://...` `--wait=1.1` |
| `flow` | `--flow=res://...json` `--out=/tmp/dir` |
| `diff` | `--a=` `--b=` `--out=/tmp/diff.png` `--threshold=0.02` |
| `inspect` | `--unique` `--node=%CardView` `--scene=` |
| `fetch` | `--url=` `--out=` `--ua=` (Wikimedia exige User-Agent) |
| `info` | viewport, main scene, versión |

Grep: `AGENT_OK`, `AGENT_FAIL`, `AGENT_SHOT=`, `AGENT_PRINT`, `AGENT_DIFF`, `AGENT_JSON`.

API humana: `addons/agent_kit/README.md`. Flows: [flows.md](flows.md).

## Cuándo

- Playtest / visual: captura o flow, no un PNG de memoria.
- Comparar antes/después de un shader o layout: `capture` + `diff`.
- Bajar un thumb a `res://`: `fetch` (no scrapees a mano sin UA).
- Entender una escena: `inspect --unique`.

Playtest humano sigue pidiendo OK (`godot-playtest`). Visual sigue exigiendo `VISUAL.md` (`godot-visual-qa`). Tests GUT: `godot-testing`.
