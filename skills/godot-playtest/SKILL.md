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

**Todos** los criterios de aceptación de **este** slice (`FEATURES.md` `F<n>`, RFC, o el pedido). No un muestreo de 3–7. Si no entran en ~15 pasos, el corte era grande: cubrí el slice y listá lo que quedó fuera. Cada acción debe **fallar a la vista** si el bug sigue.

Si hay `addons/agent_kit/`: `inspect --unique` y escribí el flow en `res://agent/flows/` con esos `%`. Helpers en `res://agent/harness/`, nunca `func agent_*` en `src/`.

## 2. Cómo lanzar Godot 4

1. Binario: `Godot.app/Contents/MacOS/Godot` (macOS), o el path que use el repo (`README`, CI).
2. `--path` = carpeta con `project.godot` (a menudo `game/`).
3. Preferí **ventana** (`--resolution WxH` del `project.godot`) para input y captura. Headless solo para cargar escena / parse errors.
4. `--quit-after` para smoke de carga. Para jugar: dejá la ventana el tiempo del flujo.

Errores `HubGlue` / dedicated sin `--dedicated` pueden ser esperados; no los trates como fallo de la feature salvo que el RFC sea de hub.

## 3. Captura (preferí AgentKit)

Si el proyecto tiene `addons/agent_kit/`:

```bash
addons/agent_kit/cli.sh /ABS/GODOT_ROOT inspect --unique
addons/agent_kit/cli.sh /ABS/GODOT_ROOT capture --out=res://agent/out/playtest.png --wait=1.1 --fail-on-error
addons/agent_kit/cli.sh /ABS/GODOT_ROOT flow --flow=boot_smoke.json --out=res://agent/out --fail-on-error
```

Skill: `godot-agent-kit`. Grep `AGENT_OK`, `AGENT_FAIL`, `AGENT_STEP`, `AGENT_STEP_ERROR`, `AGENT_ERRORS`, `ERROR:`, `SCRIPT ERROR:`, `WARNING:`. Un match completo: `try_click` + `repeat` hasta resultados, no `click` a un botón fuera de turno. **No** `godot -s /tmp/capture.gd` (`class_name` vs autoloads).

`--fail-on-error` tumba el flow si Godot logueó ERROR / SCRIPT ERROR aunque los clicks hayan “pasado”. Incluí ese log en el informe igual.

Si el addon no está, receta mínima (script **temporal**, borralo): [capture.md](capture.md). Headless no da píxeles.

## 4. Informe (al orquestador)

- Qué corriste (comando, escena, JSON).
- Cada criterio / step: PASS / FAIL + evidencia (captura, `AGENT_PRINT`, consola).
- Consola: `AGENT_ERRORS` y líneas `ERROR:` / `SCRIPT ERROR:` / `WARNING:`. Un error de script es FAIL.
- Qué no pudiste ejercer (sin display, falta save, etc.).
- No reescribas sistemas. No evalúes look (eso es `studio-visual`).
