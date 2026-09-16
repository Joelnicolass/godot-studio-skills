# AgentKit flow editor (experimental)

App **chica** (Vite + React, localhost) para armar el JSON de `--agent=flow` **conectando cables**. Sirve para ver qué va a pulsar / esperar el playtester.

No es un MCP. No entra en `./install.sh`. El contrato sigue siendo el JSON de [flows.md](../../skills/godot-agent-kit/flows.md).

**pnpm** (no `npm`). `node_modules/` no se versiona.

## Correr

```bash
cd experimental/agent-flow-editor
pnpm install
pnpm dev
```

Abrí http://localhost:5173 — Importá `addons/agent_kit/examples/boot_smoke.json` o exportá a `res://…json` y corré:

```bash
addons/agent_kit/cli.sh /ABS/GODOT_ROOT flow --flow=res://path.json --out=/tmp/flow
```

## Qué representa cada caja

| Nodo | JSON |
|------|------|
| Flow | `scene`, `wait_first` (raíz) |
| Shot / Click / Try click / Wait / Type / Wait until / Assert / Print | un step |
| Repeat | `{ "repeat": { times, until, steps } }` — el cable **loop** (púrpura) es el cuerpo |

El cable **out** (claro) es el orden. Un solo camino desde Flow. Repeat anida el camino `loop`.

## Fuera de alcance (por ahora)

- Undo rico, multiplayer de edición, validar nodos `%` contra Godot.
- No reemplaza un playtest humano.
