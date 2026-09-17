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

Addon `addons/agent_kit/` in the **game** project. Cero gameplay. El agente habla con Godot por CLI; las líneas `AGENT_OK` / `AGENT_FAIL` son el contrato. JSON, harnesses y dumps viven en **`res://agent/`** del juego, no dentro del addon ni en `src/`.

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
| `flow` | `--flow=boot_smoke.json` (o `res://agent/flows/…`) `--out=res://agent/out` `--fail-on-error` |
| `capture` | `--out=res://agent/out/a.png` `--scene=res://...` `--wait=1.1` `--fail-on-error` |
| `diff` | `--a=` `--b=` `--out=/tmp/diff.png` `--threshold=0.02` |
| `inspect` | `--unique` `--node=%CardView` `--scene=` |
| `fetch` | `--url=` `--out=` `--ua=` (Wikimedia exige User-Agent) |
| `info` | viewport, main scene, versión, InputMap `actions` |

Grep: `AGENT_OK`, `AGENT_FAIL`, `AGENT_SHOT=`, `AGENT_PRINT`, `AGENT_CLICK`, `AGENT_PRESS`, `AGENT_SELECT`, `AGENT_RANGE`, `AGENT_SCROLL`, `AGENT_DRAG`, `AGENT_CALL`, `AGENT_HARNESS`, `AGENT_STEP`, `AGENT_STEP_ERROR`, `AGENT_ERRORS`, `AGENT_SKIP`, `AGENT_REPEAT`, `AGENT_DIFF`, `AGENT_JSON`.

JSON en `res://agent/flows/`. Helpers **solo** en `res://agent/harness/*.gd`. Contrato: [harness.md](harness.md) — leelo **antes** de tocar un `.gd` de producto. Spawn / forzar estado / contar / pausar para el flow **no** van en `src/` (`agent_*` ni el mismo rol con otro nombre).

Flows largos (botón que no está en tu turno): `try_click` + `repeat` hasta `%ResultsView` visible. API: `addons/agent_kit/README.md`. Detalle JSON: [flows.md](flows.md).

Editor de cables **experimental** (localhost, no va en `./install.sh`): `experimental/agent-flow-editor/` (`pnpm install` && `pnpm dev`) — bind al proyecto Godot, pegá `%UniqueName` / InputMap, **Run flow** corre el mismo JSON.

## Cuándo

- Playtest / visual: captura o flow, no un PNG de memoria.
- Comparar antes/después de un shader o layout: `capture` + `diff`.
- Bajar un thumb a `res://`: `fetch` (no scrapees a mano sin UA).
- Entender una escena: `inspect --unique`.

Playtest humano sigue pidiendo OK (`godot-playtest`). Visual sigue exigiendo `VISUAL.md` (`godot-visual-qa`). Tests GUT: `godot-testing`.
