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

## 3. Captura (preferí AgentKit)

Si el proyecto tiene `addons/agent_kit/`:

```bash
addons/agent_kit/cli.sh /ABS/GODOT_ROOT capture --out=/tmp/playtest.png --wait=1.1
addons/agent_kit/cli.sh /ABS/GODOT_ROOT flow --flow=res://…json --out=/tmp/playtest
```

Skill: `godot-agent-kit`. Grep `AGENT_OK` / `AGENT_FAIL`. **No** `godot -s /tmp/capture.gd` (`class_name` vs autoloads).

Si el addon no está, receta mínima (script **temporal**, borralo): [capture.md](capture.md). Headless no da píxeles.

## 4. Informe (al orquestador)

- Qué corriste (comando, escena).
- Cada acción: PASS / FAIL + evidencia (captura o log).
- Qué no pudiste ejercer (sin display, falta save, etc.).
- No reescribas sistemas. No evalúes look (eso es `studio-visual`).
