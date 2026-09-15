# JSON flows

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

Empty `scene` = the project’s main scene. `click` fires `BaseButton.pressed` (not a pixel hit-test).

`assert` / `wait_until` keys: `disabled`, `visible`, `text_contains`, `text_equals`, `texture_path_contains`. `wait_until` also accepts `contains` as an alias of `text_contains`.

`print.prop` allows dots: `texture.resource_path`.

The autoload **survives** `change_scene` (vs AI, Play solo, fade). A `-s` script does not.
