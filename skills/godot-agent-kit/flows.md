# Flows JSON

`--agent=flow --flow=res://path.json --out=/abs/dir`

```json
{
  "scene": "res://scenes/ui/boot.tscn",
  "wait_first": 0.8,
  "steps": [
    { "shot": "01.png" },
    { "click": "%PlaySolo" },
    { "type": { "node": "%Ip", "text": "127.0.0.1" } },
    { "wait": 1.0 },
    { "wait_until": { "node": "%Status", "text_contains": "ok", "timeout": 6 } },
    { "assert": { "node": "%PlaySolo", "disabled": false } },
    { "print": { "node": "%Title", "prop": "text" } }
  ]
}
```

`scene` vacío = main scene del proyecto. `click` dispara `BaseButton.pressed` (no hit-test de píxel).

`assert` / `wait_until` keys: `disabled`, `visible`, `text_contains`, `text_equals`, `texture_path_contains`. `wait_until` también acepta `contains` como alias de `text_contains`.

`print.prop` admite puntos: `texture.resource_path`.

El autoload **sobrevive** `change_scene` (Vs IA, Play solo, fade). Un script `-s` no.
