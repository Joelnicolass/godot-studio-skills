# Workspace AgentKit (este proyecto)

No es el addon. El plugin vive en `addons/agent_kit/` y no tiene gameplay.

- `flows/` — JSON de `--agent=flow`. Nombre corto: `cli.sh . flow --flow=boot_smoke.json`
- `harness/` — scripts GDScript que AgentKit monta **solo** si hay `--agent=`. El nodo se llama como el archivo (`hooks.gd` → `hooks`).
- `out/` — PNG / dumps del run (Godot ignora esta carpeta).

Nunca helpers de playtest en `src/` (spawn / forzar estado / contar / pausar para el flow; `agent_*` ni el mismo rol con otro nombre). Si hace falta un setup que no está en la UI, el helper va acá. Godot permite `call("_on_play")` a métodos que el producto ya tiene (`_` es convención, no un lock). No agregues un público nuevo en `src/` solo para el flow.

```json
{ "call": { "harness": "hooks", "method": "setup_slice" } }
```

```gdscript
# harness/hooks.gd — extends Node, sin class_name
extends Node

func setup_slice() -> String:
	var scene := get_tree().current_scene
	if scene == null:
		return "no_scene"
	if scene.has_method("_on_play"):
		scene.call("_on_play")
		return "called_private"
	return "ok"
```
