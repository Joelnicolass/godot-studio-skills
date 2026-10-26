# AgentKit

CLI para agentes (y humanos) sobre un proyecto Godot 4: captura, flows de clic, HTTP, inspect, diff de PNG. **Cero gameplay.**

No es un MCP. El agente corre el binario de Godot. Las skills `godot-agent-kit` y `godot-playtest` dicen cuándo.

## Por qué existe

`godot -s /tmp` + `extends SceneTree` rompe autoloads: los `class_name` del juego se compilan **antes**. El autoload AgentKit captura desde el proyecto y **sobrevive** `change_scene`.

## Instalar

```bash
./install.sh --addon /path/to/godot-project
```

Habilitá el plugin **AgentKit**. CI/headless:

```
AgentKit="*res://addons/agent_kit/agent_kit.gd"
```

Sin `--agent=`, F5 no cambia.

Workspace del **juego**: `res://agent/` (lo crea `install.sh`). **Todo** lo que el agente cree para AgentKit (JSON, harness, fixtures `.tscn`, PNG) va ahí. Cero escenas de test en `scenes/`. Contrato: `skills/godot-agent-kit/harness.md`. El instalador copia `.cursor/rules/agent-kit-workspace.mdc`.

## CLI

```bash
addons/agent_kit/cli.sh /path/to/godot-project VERB [flags]
```

| Verb | Ventana | Qué hace |
|------|---------|----------|
| `info` | headless OK | versión, main scene, viewport |
| `capture` | **sí** | PNG (`--scene=`, `--wait=`, `--out=`) |
| `flow` | **sí** | JSON (`--flow=`, `--out=` dir) |
| `fetch` | headless OK | HTTP (`--url=`, `--out=`, `--ua=`) |
| `inspect` | headless OK | árbol o `%UniqueName` |
| `diff` | headless OK | dos PNG (`--a=`, `--b=`, `--out=`, `--threshold=`) |

Líneas para grep: `AGENT_OK`, `AGENT_FAIL`, `AGENT_SHOT=`, `AGENT_PRINT`, `AGENT_CLICK`, `AGENT_PRESS`, `AGENT_STEP`, `AGENT_STEP_ERROR`, `AGENT_ERRORS`, `AGENT_SKIP`, `AGENT_REPEAT`, `AGENT_DIFF`, `AGENT_JSON`, `AGENT_CALL`.

## Flow JSON

```json
{
  "scene": "res://scenes/ui/boot.tscn",
  "wait_first": 0.8,
  "steps": [
    { "shot": "01.png" },
    { "click": "%PlaySolo" },
    { "press": "ui_accept" },
    { "wait": 0.4 },
    { "assert": { "node": "%AfterPlay", "visible": true } },
    { "print": { "node": "%Status", "prop": "text" } }
  ]
}
```

`click` pone el puntero en el centro del control y falla si no dispara `pressed`. `%Nombre` se busca en la escena y en hijos. `press` solo acepta una acción que **ya** está en el InputMap; si no existe, falla con `unmapped input`. `call` sobre un nodo del producto, `seed` y `time_scale` fallan. `--fail-on-error` falla si el engine logueó ERROR / SCRIPT ERROR. `--flow=boot_smoke.json` busca en `res://agent/flows/`. `--out=` default: `res://agent/out`.

El harness no mueve actores. AgentKit lo monta **solo** con `--agent=`. F5 de un jugador no lo carga.

UI que aparece y desaparece:

```json
{
  "try_click": "%PlaySolo",
  "repeat": {
    "times": 80,
    "until": { "node": "%AfterPlay", "visible": true },
    "steps": [
      { "try_click": "%PlaySolo" },
      { "wait": 0.2 }
    ]
  }
}
```

`try_click` no falla si el nodo falta, está `disabled` o no está visible (`AGENT_SKIP`). Detalle de steps: `skills/godot-agent-kit/flows.md`. Demo: `example/agent/flows/`.

Editor experimental: `experimental/agent-flow-editor/` (Vite, **pnpm**). No entra en `./install.sh`.

## Determinismo

Banco de humo para simulaciones: `addons/agent_kit/determinism/`. Un nodo `DetRecorder` registra la partida en un sha256 y `det_run.sh` compara el digest entre relojes (`fixed`, `fixed2`, `stress`, `window`) y contra una base guardada.

```bash
bash addons/agent_kit/determinism/det_run.sh agent/det_cases.txt quick --no-window   # humo en cada corte
bash addons/agent_kit/determinism/det_run.sh agent/det_cases.txt bless               # regrabar la base tras un cambio a propósito
bash addons/agent_kit/determinism/det_run.sh agent/det_cases.txt table               # veredicto de lo que hay en disco
```

- Casos en `agent/det_cases.txt` (`nombre|args|quick|set`), config en `agent/det.cfg` (`DET_SCENE`, `DET_OUT`, `DET_BASELINE`).
- Todo Godot pasa por `harness/godot_run.sh` (cola FIFO). Ninguna ventana corre en paralelo con el banco; una corrida marcada `CONTAMINATED` o con `watchdog` no cuenta.
- Es una prueba de humo, no byte a byte: si un digest cambia por un cambio hecho a propósito, verificá que `fixed` y `fixed2` coincidan y regrabá con `bless`.
- Autoprueba sin juego: `det_selftest.sh`. Guía completa: skill `godot-determinism`.

## Qué no es

No es un runner de tests unitarios. No es un MCP. No es un motor de juego. El playtest no pide OK: solo escribe en `res://agent/` y no cambia reglas de negocio.

## Versión

0.1.4
