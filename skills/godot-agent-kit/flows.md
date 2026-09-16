# Flows JSON

`--agent=flow --flow=res://path.json --out=/abs/dir`

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

`scene` vacío = main scene del proyecto. `click` dispara `BaseButton.pressed` (no hit-test de píxel). `press` es una acción del InputMap (`"ui_accept"` o `{ "name": "jump", "pressed": true }`). `%Nombre` se resuelve en la escena y, si falta, en hijos. `try_click` no falla si el nodo falta, está `disabled` o no está visible en el árbol (`AGENT_SKIP`). `repeat` corre `steps` hasta `times` o hasta que `until` (mismo shape que `assert`) pase. Dejá un `wait` entre `try_click` si el snapshot de red tarda; no pises Pass y Bid en el mismo frame.

`assert` / `wait_until` keys: `disabled`, `visible`, `visible_in_tree`, `text_contains`, `text_equals`, `texture_path_contains`. `wait_until` también acepta `contains` como alias de `text_contains`.

`print.prop` admite puntos: `texture.resource_path`.

El autoload **sobrevive** `change_scene` (Vs IA, Play solo, fade). Un script `-s` no.

Editor visual experimental: `experimental/agent-flow-editor/` (cables → este JSON). Bind al proyecto Godot, pegá `%` / acciones, **Run flow** ejecuta AgentKit.
