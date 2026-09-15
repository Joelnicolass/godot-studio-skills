---
name: godot-playtest
description: >-
  Launch the Godot 4 project and exercise a feature like a player (run scene,
  click/play, screenshot). Not GUT/unit tests. Use when the user agrees to a
  playtest after an iteration, or when studio-playtester is invoked.
---

# Playtest in the binary

This is not `godot-testing` (GUT/GdUnit4). This is **launching the game** and checking acceptance the way a human would.

Read this when the user **agreed** to a post-iteration playtest. The orchestrator asks; do not assume yes.

## 1. What to exercise

Short list from the RFC / request: 3–7 actions (open scene, use HUD, trigger the feature…). Each must **fail in plain sight** if the bug remains.

## 2. How to launch Godot 4

1. Binary: `Godot.app/Contents/MacOS/Godot` (macOS), or the path the repo uses (`README`, CI).
2. `--path` = folder with `project.godot` (often `game/`).
3. Prefer a **window** (`--resolution WxH` from `project.godot`) for input and capture. Headless only for scene load / parse errors.
4. `--quit-after` for a load smoke. To play: leave the window up for the length of the flow.

`HubGlue` / dedicated errors without `--dedicated` can be expected; do not treat them as a feature failure unless the RFC is about the hub.

## 3. Capture (prefer AgentKit)

If the project has `addons/agent_kit/`:

```bash
addons/agent_kit/cli.sh /ABS/GODOT_ROOT capture --out=/tmp/playtest.png --wait=1.1
addons/agent_kit/cli.sh /ABS/GODOT_ROOT flow --flow=res://…json --out=/tmp/playtest
```

Skill: `godot-agent-kit`. Grep `AGENT_OK` / `AGENT_FAIL`. A full match: `try_click` + `repeat` until results, not a `click` on a button off-turn. Do **not** `godot -s /tmp/capture.gd` (`class_name` vs autoloads).

If the addon is missing, minimal recipe (temporary script, delete it): [capture.md](capture.md). Headless has no pixels.

## 4. Report (to the orchestrator)

- What you ran (command, scene).
- Each action: PASS / FAIL + evidence (screenshot or log).
- What you could not exercise (no display, missing save, etc.).
- Do not rewrite systems. Do not judge look (that is `studio-visual`).
