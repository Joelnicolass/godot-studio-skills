# Workspace AgentKit (este proyecto)

No es el addon. El plugin vive en `addons/agent_kit/` y **no** guarda JSON ni helpers de playtest.

- `flows/` — JSON de `--agent=flow`. `cli.sh . flow --flow=boot_smoke.json --fail-on-error`
- `harness/` — GDScript que AgentKit monta **solo** con `--agent=`. Nodo = basename (`hooks.gd` → `hooks`). Sin `class_name`.
- `out/` — PNG del run (Godot ignora esta carpeta).

Nunca helpers de playtest en `src/` (spawn / forzar estado / contar / pausar para el flow; `agent_*` ni el mismo rol con otro nombre). Contrato: `skills/godot-agent-kit/harness.md`. Si hace falta un setup que no está en la UI, **solo** en el harness:

```json
{ "call": { "harness": "hooks", "method": "setup_slice" } }
```
