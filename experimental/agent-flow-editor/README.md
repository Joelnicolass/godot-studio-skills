# AgentKit flow editor (experimental)

A **small** app (Vite + React, localhost) to build `--agent=flow` JSON by **connecting cables**. Use it to see what the playtester will click / wait for.

Not an MCP. Not part of `./install.sh`. The contract is still the JSON in [flows.md](../../skills/godot-agent-kit/flows.md).

Use **pnpm** (not `npm`). `node_modules/` is not committed.

## Run

```bash
cd experimental/agent-flow-editor
pnpm install
pnpm dev
```

Open http://localhost:5173 — import `addons/agent_kit/examples/boot_smoke.json` or export to `res://…json` and run:

```bash
addons/agent_kit/cli.sh /ABS/GODOT_ROOT flow --flow=res://path.json --out=/tmp/flow
```

## What each box is

| Node | JSON |
|------|------|
| Flow | `scene`, `wait_first` (root) |
| Shot / Click / Try click / Wait / Type / Wait until / Assert / Print | one step |
| Repeat | `{ "repeat": { times, until, steps } }` — the **loop** cable (purple) is the body |

The **out** cable is order. A single path from Flow. Repeat nests the `loop` path.

## Out of scope (for now)

- Rich undo, multiplayer editing, validating `%` nodes against Godot.
- Does not replace a human playtest.
