---
name: godot-playtest
description: >-
  Launch the Godot 4 project and exercise a feature like a player (run scene,
  click/play, screenshot). Not GUT/unit tests. Use when the user agrees to a
  playtest after an iteration, or when studio-playtester is invoked.
---

# Playtest en el binario

No es `godot-testing` (GUT/GdUnit4). Esto es **levantar el juego** y comprobar el criterio de aceptación como lo haría un humano.

Leé esto cuando el usuario **aceptó** un playtest post-iteración. El orquestador pregunta; no asumas que sí.

## 1. Qué ejercer

Lista corta del RFC / pedido: 3–7 acciones (abrir escena, pujar, pasar, ver HUD…). Cada una debe **fallar a la vista** si el bug sigue.

## 2. Cómo lanzar Godot 4

1. Binario: `Godot.app/Contents/MacOS/Godot` (macOS), o el path que use el repo (`README`, CI).
2. `--path` = carpeta con `project.godot` (a menudo `game/`).
3. Preferí **ventana** (`--resolution WxH` del `project.godot`) para input y captura. Headless solo para cargar escena / parse errors.
4. `--quit-after` para smoke de carga. Para jugar: dejá la ventana el tiempo del flujo.

Errores `HubGlue` / dedicated sin `--dedicated` pueden ser esperados; no los trates como fallo de la feature salvo que el RFC sea de hub.

## 3. Captura (opcional pero útil)

Script `SceneTree` **temporal** (`/tmp` o `user://`), no lo dejes en el repo:

1. `DisplayServer.window_set_size` al viewport del juego.
2. `load("res://…").instantiate()` en `root`.
3. Esperá layout (`create_timer` ~0.8–1.2 s).
4. `root.get_viewport().get_texture().get_image().save_png(...)`.
5. `quit`. Borrá el `.gd` temporal.

Si el flujo necesita clics, usá la ventana real o herramientas de browser **solo** si el target es web. En Godot nativo: ventana + captura.

Detalle de receta: [capture.md](capture.md).

## 4. Informe (al orquestador)

- Qué corriste (comando, escena).
- Cada acción: PASS / FAIL + evidencia (captura o log).
- Qué no pudiste ejercer (sin display, falta save, etc.).
- No reescribas sistemas. No evalúes look (eso es `studio-visual`).
