---
name: godot-playtest
description: >-
  Launch the Godot 4 project and exercise a feature like a player (run scene,
  click/play, screenshot). Not GUT. Use when the user agrees to a playtest,
  studio-playtester is invoked, or when writing AgentKit flows/harnesses
  (never playtest helpers — spawn/force/count/pause for the flow — in src/).
---

# Playtest in the binary

This is not `godot-testing` (GUT/GdUnit4). This is **launching the game** and checking acceptance the way a human would.

Read this when the user **agreed** to a post-iteration playtest. The orchestrator asks; do not assume yes.

## 1. What to exercise

**All** acceptance criteria of **this** slice (`FEATURES.md` `F<n>`, RFC, or the request). Not a 3–7 sample. If it will not fit in ~15 steps, the cut was large: cover the slice and list what was left out. Each action must **fail in plain sight** if the bug remains.

If `addons/agent_kit/` is present: `inspect --unique` and write the flow in `res://agent/flows/`. Helpers **only** in `res://agent/harness/` ([harness.md](../godot-agent-kit/harness.md)). Spawn / force-state / count / pause for the flow do **not** belong in `src/`.

## 2. How to launch Godot 4

1. Binary: `Godot.app/Contents/MacOS/Godot` (macOS), or the path the repo uses (`README`, CI).
2. `--path` = folder with `project.godot` (often `game/`).
3. Prefer a **window** (`--resolution WxH` from `project.godot`) for input and capture. Headless only for scene load / parse errors.
4. `--quit-after` for a load smoke. To play: leave the window up for the length of the flow.

`HubGlue` / dedicated errors without `--dedicated` can be expected; do not treat them as a feature failure unless the RFC is about the hub.

## 3. Capture (prefer AgentKit)

If the project has `addons/agent_kit/`:

```bash
addons/agent_kit/cli.sh /ABS/GODOT_ROOT inspect --unique
addons/agent_kit/cli.sh /ABS/GODOT_ROOT capture --out=res://agent/out/playtest.png --wait=1.1 --fail-on-error
addons/agent_kit/cli.sh /ABS/GODOT_ROOT flow --flow=boot_smoke.json --out=res://agent/out --fail-on-error
```

Skill: `godot-agent-kit`. Grep `AGENT_OK`, `AGENT_FAIL`, `AGENT_STEP`, `AGENT_STEP_ERROR`, `AGENT_ERRORS`, `ERROR:`, `SCRIPT ERROR:`, `WARNING:`. A full match: `try_click` + `repeat` until results, not a `click` on a button off-turn. Do **not** `godot -s /tmp/capture.gd` (`class_name` vs autoloads).

`--fail-on-error` fails the flow if Godot logged ERROR / SCRIPT ERROR even when clicks “worked”. Include that log in the report anyway.

If the addon is missing, minimal recipe (temporary script, delete it): [capture.md](capture.md). Headless has no pixels.

## 4. Report (to the orchestrator)

- What you ran (command, scene, JSON).
- Each criterion / step: PASS / FAIL + evidence (screenshot, `AGENT_PRINT`, console).
- Console: `AGENT_ERRORS` and `ERROR:` / `SCRIPT ERROR:` / `WARNING:` lines. A script error is FAIL.
- What you could not exercise (no display, missing save, etc.).
- Do not rewrite systems. Do not judge look (that is `studio-visual`).
