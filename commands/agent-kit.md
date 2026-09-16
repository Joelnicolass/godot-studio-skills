The user wants **screenshots, a UI flow, an HTTP fetch, an inspect, or a PNG diff** in a Godot 4 project — or is about to write an `extends SceneTree` script in `/tmp`.

Load the `godot-agent-kit` skill. If `addons/agent_kit/` is not in the Godot root (`project.godot`), install it:

```bash
./install.sh --addon /ABS/GODOT_ROOT agent_kit
```

from the `godot-studio-skills` repo, and enable the **AgentKit** plugin.

Do not use `godot -s /tmp/*.gd`. Use:

```bash
addons/agent_kit/cli.sh /ABS/GODOT_ROOT capture --out=/tmp/a.png --wait=1.1
addons/agent_kit/cli.sh /ABS/GODOT_ROOT flow --flow=res://addons/agent_kit/examples/boot_smoke.json --out=/tmp/flow
```

Set `GODOT=` if the binary is not found. Capture/flow **without** `--headless`. Report: `AGENT_OK` / `AGENT_FAIL` lines + PNG paths. A multi-turn flow: `try_click` + `repeat` (not a hard `click` on a `disabled` button).

Experimental cable editor: `experimental/agent-flow-editor/` (`pnpm install` && `pnpm dev`). Bind the Godot project and **Run flow** calls `cli.sh`. Same JSON as `--agent=flow` (includes `press`).

This does not replace GUT or a playtest without the user’s OK. It is not an MCP.
