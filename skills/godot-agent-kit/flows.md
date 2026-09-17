# Flows JSON

`--agent=flow --flow=res://agent/flows/boot_smoke.json --out=res://agent/out`

Nombre corto: `--flow=boot_smoke.json` (busca en `res://agent/flows/`).

```json
{
  "scene": "res://scenes/ui/boot.tscn",
  "wait_first": 0.8,
  "steps": [
    { "shot": "01.png" },
    { "click": "%PlaySolo" },
    { "press": "ui_accept" },
    { "type": { "node": "%Ip", "text": "127.0.0.1" } },
    { "wait": 1.0 },
    { "wait_until": { "node": "%Status", "text_contains": "ok", "timeout": 6 } },
    { "assert": { "node": "%PlaySolo", "disabled": false } },
    { "print": { "node": "%Title", "prop": "text" } }
  ]
}
```

Match / turnos (el panel de puja se oculta fuera de turno):

```json
{
  "repeat": {
    "times": 180,
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

`scene` vacío en la raíz = main scene. Un step `{ "scene": "res://…" }` cambia a mitad del flow. `click` dispara `BaseButton.pressed` (no hit-test de píxel). `press` es InputMap: `"ui_accept"` o `{ "name": "move_left", "hold": 0.4 }` (hold = down, espera, up). `%Nombre` se resuelve en la escena y, si falta, en hijos. `try_click` no falla si el nodo falta, está `disabled` o no está visible (`AGENT_SKIP`). `repeat` corre `steps` hasta `times` o hasta que `until` (mismo shape que `assert`) pase.

Otros steps: `{ "select": { "node": "%Rooms", "index": 0 } }` o `"text"` (ItemList / OptionButton); `{ "range": { "node": "%Vol", "value": 0.5 } }`; `{ "scroll": { "node": "%List", "vertical": 80 } }`; `{ "drag": { "node": "%Pad", "from_x": 8, "from_y": 8, "to_x": 80, "to_y": 8 } }`; `{ "call": { "harness": "hooks", "method": "setup_slice" } }` (solo `res://agent/harness/`; ver [harness.md](harness.md)); `{ "call": { "node": "%Title", "method": "set", "args": ["text", "ok"] } }` (no `free` / `queue_free`); `{ "shot": { "name": "hud.png", "node": "%Status" } }` recorta un Control; `{ "diff": { "a": "01.png", "b": "02.png", "max_percent": 0 } }` compara PNGs del `--out=`; `{ "seed": 1 }`; `{ "time_scale": 0.5 }` (se restaura al terminar).

`assert` / `wait_until` keys: `disabled`, `visible`, `visible_in_tree`, `text_contains`, `text_equals`, `texture_path_contains`. `wait_until` también acepta `contains` como alias de `text_contains`, o `{ "node": "%PlaySolo", "signal": "pressed", "timeout": 5 }`.

Cada step imprime `AGENT_STEP n kind`. Errores del engine: `AGENT_STEP_ERROR` y al final `AGENT_ERRORS […]`. `--fail-on-error` tumba el flow si hubo ERROR / SCRIPT ERROR.

`print.prop` admite puntos: `texture.resource_path`.

El autoload **sobrevive** `change_scene`. Un script `-s` no.

Editor visual experimental: `experimental/agent-flow-editor/` (cables → este JSON). Bind al proyecto Godot, pegá `%` / acciones, **Run flow** ejecuta AgentKit con `--fail-on-error`.
