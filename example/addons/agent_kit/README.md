# AgentKit

Tools for **AI agents** (and humans) driving a Godot 4 project: screenshot, click flows, HTTP, inspect, image diff. **Zero gameplay.** Same idea as MpKit: copy the addon, enable the plugin; the game does not put score here.

This is not an MCP. The agent runs the Godot binary with flags. Studio kit skills say when.

## Why it exists

An `extends SceneTree` script in `/tmp` plus `godot -s` breaks autoloads: the game’s `class_name` scripts compile **before** `PortraitCache` / `DraftCopy`. Capturing from a project **autoload** avoids that and **survives** `change_scene`.

## Install

From the studio kit:

```bash
./install.sh --addon /path/to/godot-project agent_kit
```

Enable the **AgentKit** plugin (autoload `AgentKit`). Headless/CI:

```
AgentKit="*res://addons/agent_kit/agent_kit.gd"
```

With no `--agent=`, F5 of the game is unchanged.

## CLI

```bash
addons/agent_kit/cli.sh /path/to/godot-project VERB [flags]
# or:
godot --path PROJECT --resolution WxH -- --agent=VERB --out=/tmp/a.png
```

| Verb | Window | What it does |
|------|--------|----------------|
| `info` | headless OK | JSON: version, main scene, viewport |
| `capture` | **yes** | Viewport PNG (`--scene=` optional, `--wait=`, `--out=`) |
| `flow` | **yes** | JSON steps (`--flow=`, `--out=` dir) |
| `fetch` | headless OK | HTTP GET/POST with User-Agent (`--url=`, `--out=`) |
| `inspect` | headless OK | Tree or `%UniqueName` (`--unique`, `--node=`) |
| `diff` | headless OK | Diff two PNGs (`--a=`, `--b=`, `--out=` overlay, `--threshold=`) |

Lines to grep:

```
AGENT_OK capture /abs/path.png
AGENT_FAIL flow missing --flow=
AGENT_SHOT=...
AGENT_PRINT node=%Title prop=text value=...
AGENT_CLICK %BidButton
AGENT_PRESS ui_accept pressed=true
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
    { "press": "ui_accept" },
    { "type": { "node": "%Ip", "text": "127.0.0.1" } },
    { "wait": 1.2 },
    { "wait_until": { "node": "%Status", "text_contains": "ready", "timeout": 5 } },
    { "assert": { "node": "%PlaySolo", "disabled": false } },
    { "print": { "node": "%Title", "prop": "text" } }
  ]
}
```

`click` emits `pressed` on the `BaseButton` (it does not aim at a pixel). `%Name` is resolved on the scene and, if missing, in children (packed scenes). `press` fires an InputMap `InputEventAction` (`"ui_accept"` or `{ "name": "jump", "pressed": true }`). `inspect --unique` also prints `AGENT_JSON` with those `%` names (click/type). `info` includes `actions`.

For a match or HUD that appears and disappears:

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

`try_click` does not fail if the node is missing, `disabled`, or not visible in the tree (`AGENT_SKIP`). `repeat` runs `steps` until `times` or until `until` (same shape as `assert`) passes. `assert` / `wait_until` also accept `visible_in_tree`.

Demo example: `examples/boot_smoke.json`.

Experimental cable editor: `experimental/agent-flow-editor/` in the studio kit (Vite, **pnpm**, localhost). Bind the `project.godot` dir, Scan / Live inspect to paste `%UniqueName` and InputMap actions, **Run flow** calls `cli.sh`. Not part of `./install.sh`.

## What it is not

- GUT / GdUnit4 (skill `godot-testing`)
- Human playtest without the user’s OK (skill `godot-playtest`)
- Visual pass without `VISUAL.md` (skill `godot-visual-qa`)
- Transport / rooms (MpKit)

## Version

0.1.2
