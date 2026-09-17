# AgentKit workspace (this project)

This is not the addon. The plugin lives in `addons/agent_kit/` and does **not** store playtest JSON or helpers.

- `flows/` — `--agent=flow` JSON. `cli.sh . flow --flow=boot_smoke.json --fail-on-error`
- `harness/` — GDScript AgentKit mounts **only** with `--agent=`. Node name = basename (`hooks.gd` → `hooks`). No `class_name`.
- `out/` — run PNGs (Godot ignores this folder).

Never playtest helpers in `src/` (spawn / force-state / count / pause for the flow; `agent_*` or the same role under another name). Contract: `skills/godot-agent-kit/harness.md`. If setup is not in the UI, **only** in the harness:

```json
{ "call": { "harness": "hooks", "method": "setup_slice" } }
```
