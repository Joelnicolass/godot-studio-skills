# AgentKit flow editor (experimental)

App **chica** (Vite + React, localhost) para armar el JSON de `--agent=flow` **conectando cables**, vincular `%UniqueName` / InputMap del proyecto Godot y **lanzar** el flow con AgentKit.

No es un MCP. No entra en `./install.sh`. El contrato sigue siendo el JSON de [flows.md](../../skills/godot-agent-kit/flows.md).

**pnpm** (no `npm`). `node_modules/` no se versiona.

## Correr

```bash
cd experimental/agent-flow-editor
pnpm install
pnpm dev
```

Abrí http://localhost:5173. Por defecto se bindea a `example/` del kit.

1. **Scan scenes** — lee `.tscn` (`unique_name_in_owner`) y `[input]` de `project.godot`.
2. **Live inspect** — corre `cli.sh inspect --unique` + `info` (nodos vivos + acciones built-in).
3. Seleccioná un nodo Click/Type/Press y pegá un `%` o una acción del catálogo.
4. **Run flow** — escribe un JSON temporal y corre `addons/agent_kit/cli.sh PROJECT flow --flow=/abs.json --out=…`.

También podés exportar JSON y correr a mano:

```bash
addons/agent_kit/cli.sh /ABS/GODOT_ROOT flow --flow=res://path.json --out=/tmp/flow
```

## Qué representa cada caja

| Nodo | JSON |
|------|------|
| Flow | `scene`, `wait_first` (raíz) |
| Shot / Click / Try click / Press / Wait / Type / Wait until / Assert / Print | un step |
| Repeat | `{ "repeat": { times, until, steps } }` — el cable **loop** (púrpura) es el cuerpo |

El cable **out** (claro) es el orden. Un solo camino desde Flow. Repeat anida el camino `loop`.

## Componentes

`Palette`, `Toolbar`, `Canvas` (`FlowNode`, `Cables`), `Inspector` (`NodeFields`, `GodotBinder`, `RunPanel`). El puente Vite está en `godotBridge.js` (`/api/scan`, `/api/inspect`, `/api/run`).

## Fuera de alcance (por ahora)

- Undo rico, multiplayer de edición.
- No reemplaza un playtest humano.
