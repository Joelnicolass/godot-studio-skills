# Workspace AgentKit (este proyecto)

No es el addon. El plugin vive en `addons/agent_kit/` y **no** guarda JSON ni helpers de playtest.

- `flows/` — JSON de `--agent=flow`. `cli.sh . flow --flow=boot_smoke.json --fail-on-error`
- `harness/` — GDScript que AgentKit monta **solo** con `--agent=`. Nodo = basename (`wild_hooks.gd` → `wild_hooks`). Sin `class_name`.
- `out/` — PNG del run (Godot ignora esta carpeta).

Nunca `func agent_*` en `src/` ni en glue de producto. Si hace falta un setup que no está en la UI:

```json
{ "call": { "harness": "wild_hooks", "method": "place_wild_beside_player" } }
```
