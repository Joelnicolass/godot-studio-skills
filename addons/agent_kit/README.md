# AgentKit

Herramientas para **agentes de IA** (y humanos) que manejan un proyecto Godot 4: captura, flujos de clic, HTTP, inspect, diff de imágenes. **Cero gameplay.** Misma idea que MpKit: copiá el addon, enable del plugin; el juego no nombra puntaje acá.

No es un MCP. El agente corre el binario de Godot con flags. Las skills del studio kit dicen cuándo.

## Por qué existe

Un `extends SceneTree` en `/tmp` + `godot -s` rompe autoloads: los `class_name` del juego se compilan **antes** de `PortraitCache` / `DraftCopy`. Capturar desde un **autoload** del proyecto evita eso y **sobrevive** `change_scene`.

## Instalar

Desde el studio kit:

```bash
./install.sh --addon /path/to/godot-project agent_kit
```

Habilitá el plugin **AgentKit** (autoload `AgentKit`). Headless/CI:

```
AgentKit="*res://addons/agent_kit/agent_kit.gd"
```

Si no hay `--agent=`, F5 del juego no cambia.

## CLI

```bash
addons/agent_kit/cli.sh /path/to/godot-project VERB [flags]
# o:
godot --path PROJECT --resolution WxH -- --agent=VERB --out=/tmp/a.png
```

| Verb | Ventana | Qué hace |
|------|---------|----------|
| `info` | headless OK | JSON: versión, main scene, viewport |
| `capture` | **sí** | PNG del viewport (`--scene=` opcional, `--wait=`, `--out=`) |
| `flow` | **sí** | JSON de pasos (`--flow=`, `--out=` dir) |
| `fetch` | headless OK | HTTP GET/POST con User-Agent (`--url=`, `--out=`) |
| `inspect` | headless OK | Árbol o `%UniqueName` (`--unique`, `--node=`) |
| `diff` | headless OK | Diff de dos PNG (`--a=`, `--b=`, `--out=` overlay, `--threshold=`) |

Líneas para grep:

```
AGENT_OK capture /abs/path.png
AGENT_FAIL flow missing --flow=
AGENT_SHOT=...
AGENT_PRINT node=%Title prop=text value=...
AGENT_CLICK %BidButton
AGENT_SKIP try_click %PassButton
AGENT_REPEAT done iter=13
AGENT_DIFF changed=12 total=1000 percent=1.200
AGENT_JSON {...}
```

## Flow JSON

```json
{
  "scene": "res://scenes/ui/boot.tscn",
  "wait_first": 0.8,
  "steps": [
    { "shot": "01.png" },
    { "click": "%PlaySolo" },
    { "type": { "node": "%Ip", "text": "127.0.0.1" } },
    { "wait": 1.2 },
    { "wait_until": { "node": "%Status", "text_contains": "listo", "timeout": 5 } },
    { "assert": { "node": "%PlaySolo", "disabled": false } },
    { "print": { "node": "%Title", "prop": "text" } }
  ]
}
```

`click` emite `pressed` en el `BaseButton` (no apunta al píxel). `%Nombre` se busca en la escena y, si falta, en hijos (packed scenes).

Para un match o un HUD que aparece y desaparece:

```json
{
  "try_click": "%PassButton",
  "repeat": {
    "times": 80,
    "until": { "node": "%ResultsView", "visible": true },
    "steps": [
      { "try_click": "%PassButton" },
      { "wait": 0.2 },
      { "try_click": "%BidButton" },
      { "wait": 0.3 }
    ]
  }
}
```

`try_click` no falla si el nodo falta, está `disabled` o no está visible en el árbol (`AGENT_SKIP`). `repeat` corre `steps` hasta `times` o hasta que `until` (mismo shape que `assert`) pase. `assert` / `wait_until` también aceptan `visible_in_tree`.

Ejemplo del demo: `examples/boot_smoke.json`.

Editor de cables experimental: `experimental/agent-flow-editor/` en el studio kit (Vite, **pnpm**, localhost). No forma parte de `./install.sh`.

## Qué no es

- GUT / GdUnit4 (skill `godot-testing`)
- Playtest humano sin OK del usuario (skill `godot-playtest`)
- Pase visual sin `VISUAL.md` (skill `godot-visual-qa`)
- Transporte / salas (MpKit)

## Versión

0.1.1
