# JSON flows

`--agent=flow --flow=res://agent/flows/boot_smoke.json --out=res://agent/out`

Short name: `--flow=boot_smoke.json` (looks in `res://agent/flows/`).

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

Empty `scene` at the root = the project’s main scene. A `{ "scene": "res://…" }` step changes scene mid-flow. `click` fires `BaseButton.pressed` (not a pixel hit-test). `press` is InputMap: `"ui_accept"` or `{ "name": "move_left", "hold": 0.4 }` (hold = down, wait, up). `%Name` resolves on the scene and, if missing, in children. `try_click` does not fail if the node is missing, `disabled`, or not visible (`AGENT_SKIP`). `repeat` runs `steps` until `times` or until `until` (same shape as `assert`) passes.

Other steps: `{ "select": { "node": "%Rooms", "index": 0 } }` or `"text"` (ItemList / OptionButton); `{ "range": { "node": "%Vol", "value": 0.5 } }`; `{ "scroll": { "node": "%List", "vertical": 80 } }`; `{ "drag": { "node": "%Pad", "from_x": 8, "from_y": 8, "to_x": 80, "to_y": 8 } }`; `{ "call": { "harness": "hooks", "method": "setup_slice" } }` (`res://agent/harness/` only; see [harness.md](harness.md)); `{ "call": { "node": "%Title", "method": "set", "args": ["text", "ok"] } }` (not `free` / `queue_free`); `{ "shot": { "name": "hud.png", "node": "%Status" } }` crops a Control; `{ "diff": { "a": "01.png", "b": "02.png", "max_percent": 0 } }` compares PNGs under `--out=`; `{ "seed": 1 }`; `{ "time_scale": 0.5 }` (restored when the flow ends).

`assert` / `wait_until` keys: `disabled`, `visible`, `visible_in_tree`, `text_contains`, `text_equals`, `texture_path_contains`. `wait_until` also accepts `contains` as an alias of `text_contains`, or `{ "node": "%PlaySolo", "signal": "pressed", "timeout": 5 }`.

Each step prints `AGENT_STEP n kind`. Engine errors: `AGENT_STEP_ERROR` and a final `AGENT_ERRORS […]`. `--fail-on-error` fails the flow if there was ERROR / SCRIPT ERROR.

`print.prop` allows dots: `texture.resource_path`.

The autoload **survives** `change_scene`. A `-s` script does not.

Experimental visual editor: `experimental/agent-flow-editor/` (cables → this JSON). Bind the Godot project, paste `%` / actions, **Run flow** executes AgentKit with `--fail-on-error`.
