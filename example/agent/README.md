# AgentKit workspace (this project)

This is not the addon. The plugin lives in `addons/agent_kit/` and does **not** store playtest JSON or helpers.

- `flows/` — `--agent=flow` JSON. `cli.sh . flow --flow=boot_smoke.json --fail-on-error`
- `harness/` — GDScript AgentKit mounts **only** with `--agent=`. Node name = basename (`wild_hooks.gd` → `wild_hooks`). No `class_name`.
- `out/` — run PNGs (Godot ignores this folder).

Never `func agent_*` in `src/` or product glue. If setup is not in the UI:

```json
{ "call": { "harness": "wild_hooks", "method": "place_wild_beside_player" } }
```
