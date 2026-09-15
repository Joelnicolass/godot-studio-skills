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

Match / turns (the bid panel hides off-turn):

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

Empty `scene` = the project’s main scene. `click` fires `BaseButton.pressed` (not a pixel hit-test). `%Name` resolves on the scene and, if missing, in children. `try_click` does not fail if the node is missing, `disabled`, or not visible in the tree (`AGENT_SKIP`). `repeat` runs `steps` until `times` or until `until` (same shape as `assert`) passes. Leave a `wait` between `try_click`s if the network snapshot is slow; do not fire Pass and Bid in the same frame.

`assert` / `wait_until` keys: `disabled`, `visible`, `visible_in_tree`, `text_contains`, `text_equals`, `texture_path_contains`. `wait_until` also accepts `contains` as an alias of `text_contains`.

`print.prop` allows dots: `texture.resource_path`.

The autoload **survives** `change_scene` (vs AI, Play solo, fade). A `-s` script does not.
