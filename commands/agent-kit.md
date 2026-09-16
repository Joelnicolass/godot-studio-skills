El usuario quiere **capturas, un flow de UI, un fetch HTTP, un inspect o un diff de PNGs** en un proyecto Godot 4 — o está a punto de escribir un `extends SceneTree` en `/tmp`.

Cargá la skill `godot-agent-kit`. Si `addons/agent_kit/` no está en la raíz Godot (`project.godot`), instalalo:

```bash
./install.sh --addon /ABS/GODOT_ROOT agent_kit
```

desde el repo `godot-studio-skills`, y pedí enable del plugin **AgentKit**.

No uses `godot -s /tmp/*.gd`. Usá:

```bash
addons/agent_kit/cli.sh /ABS/GODOT_ROOT capture --out=/tmp/a.png --wait=1.1
addons/agent_kit/cli.sh /ABS/GODOT_ROOT flow --flow=res://addons/agent_kit/examples/boot_smoke.json --out=/tmp/flow
```

`GODOT=` si el binario no se encuentra. Capture/flow **sin** `--headless`. Informe: líneas `AGENT_OK` / `AGENT_FAIL` + paths de PNG. Un flow de varios turnos: `try_click` + `repeat` (no un `click` duro a un botón `disabled`).

Editor de cables experimental: `experimental/agent-flow-editor/` (`pnpm install` && `pnpm dev`). Bind al proyecto Godot y **Run flow** llama `cli.sh`. El JSON es el mismo que `--agent=flow` (incluye `press`).

Esto no reemplaza GUT ni un playtest sin OK del usuario. No es un MCP.
