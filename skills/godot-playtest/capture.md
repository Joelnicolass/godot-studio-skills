# Godot capture (playtest / visual)

Minimal script (`extends SceneTree`). Keep it outside the project or in `user://` and **delete** the `.gd` when done.

```gdscript
extends SceneTree

func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(720, 1280)) # or the project.godot viewport
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

`create_timer` in `SceneTree._initialize` works; a child `Timer` is sometimes not in the tree yet (`start` fails).

Do not use `--headless` if you need real renderer pixels. Headless is for parse / `--quit-after` of the scene.
