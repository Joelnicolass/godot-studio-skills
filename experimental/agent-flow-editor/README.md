# AgentKit flow editor (experimental)

A **small** app (Vite + React, localhost) to build `--agent=flow` JSON by **connecting cables**, bind `%UniqueName` / InputMap from the Godot project, and **run** the flow with AgentKit.

Not an MCP. Not part of `./install.sh`. The contract is still the JSON in [flows.md](../../skills/godot-agent-kit/flows.md).

Use **pnpm** (not `npm`). `node_modules/` is not committed.

## Run

```bash
cd experimental/agent-flow-editor
pnpm install
pnpm dev
```

Open http://localhost:5173. It binds to the kit `example/` by default.

1. **Scan scenes** — reads `.tscn` (`unique_name_in_owner`) and `[input]` from `project.godot`.
2. **Live inspect** — runs `cli.sh inspect --unique` + `info` (live nodes + built-in actions).
3. Select a Click/Type/Press node and paste a `%` or an action from the catalog.
4. **Run flow** — writes a temp JSON and runs `cli.sh … flow --fail-on-error`. The log colors `AGENT_STEP`, `ERROR`, and `AGENT_ERRORS`.

You can still export JSON and run it by hand:

```bash
addons/agent_kit/cli.sh /ABS/GODOT_ROOT flow --flow=res://path.json --out=/tmp/flow --fail-on-error
```

## What each box is

| Node | JSON |
|------|------|
| Flow | `scene`, `wait_first` (root) |
| Shot / Click / Try click / Press (hold) / Wait / Type / Select / Range / Scroll / Drag / Call / Scene / Seed / Time scale / Diff / Wait until (property or signal) / Assert / Print | one step |
| Repeat | `{ "repeat": { times, until, steps } }` — the **loop** cable (purple) is the body |

The **out** cable is order. A single path from Flow. Repeat nests the `loop` path.

## Components

`Palette`, `Toolbar`, `Canvas` (`FlowNode`, `Cables`), `Inspector` (`NodeFields`, `GodotBinder`, `RunPanel`). The Vite bridge is `godotBridge.js` (`/api/scan`, `/api/inspect`, `/api/run`).

## Out of scope (for now)

- Rich undo, multiplayer editing.
- Does not replace a human playtest.
