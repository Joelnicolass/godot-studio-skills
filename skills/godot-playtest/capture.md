# Captura Godot (playtest / visual)

**Preferí AgentKit** (`godot-agent-kit`): autoload, sobrevive `change_scene`, no rompe `DraftCopy` / `PortraitCache`.

```bash
addons/agent_kit/cli.sh /abs/game capture --scene=res://src/features/draft_table/draft_table.tscn --out=res://agent/out/table.png
```

Fallback **solo** si el addon no está. Script `SceneTree` temporal (`/tmp`), **borra** al terminar. No referencies `class_name` del juego en ese script.

```gdscript
extends SceneTree

func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(720, 1280)) # o el viewport del project.godot
	var packed := load("res://path/to/scene.tscn") as PackedScene
	root.add_child(packed.instantiate())
	create_timer(1.1).timeout.connect(_shot)

func _shot() -> void:
	var img := root.get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path("user://playtest.png")
	img.save_png(path)
	print("saved ", path)
	quit(0)
```

```bash
Godot --path /abs/game --resolution 720x1280 -s /tmp/capture.gd
```

`create_timer` en `_initialize` del `SceneTree` sí funciona; un `Timer` hijo a veces no está en el árbol todavía (`start` falla).

No uses `--headless` si necesitás pixels reales del renderer. Headless sirve para parse/`--quit-after` de la escena.
