---
name: godot-feature-research
description: >-
  Researches how a mechanic or feature of a similar game works and deduces the
  code for it in Godot 4: web search (wikis, devlogs, talks, guides, source
  code, gameplay video), watching and measuring it, and opening or decompiling
  the game when that is possible. Use when the user says "like in X", "I want
  Y's mechanic", "how does Z do it", or /research-feature.
---

# Godot — feature research

To build something "like in X", find out **how it works** and bring it to Godot. Jump curve, damage formula, waves, camera, loot table: turn them into an `F<n>` with numbers and criteria, and implement it like any feature (composition, `@export`, `.tres`). Scoped request: command `/research-feature`.

## Where to look

Search the web (the agent's search and fetch tools) and say where each fact comes from.

| Source | What it gives |
|--------|---------------|
| The game's wiki and community guides | Values players measured (frames, damage, speeds, drop rates) |
| Devlogs, postmortems, GDC / conference talks by its developers | How and why it was designed, sometimes the exact numbers |
| Source code: open-source games, mods, community repos and tutorials | The logic itself, ready to adapt |
| Speedrun and frame-data pages | Precise timings: coyote time, buffers, invulnerability frames |
| Gameplay videos | What you can measure frame by frame (count frames, compare positions) |
| Opening the game, when the user has its files | Real code and values. A Godot `.pck` opens with gdsdecomp; Unity / .NET with ILSpy or dnSpy; other engines with their decompiler. Ask before installing a tool. |
| Playing it, if the user has it | Probing edges by hand (does it still jump 6 frames after leaving the ledge?) |

When sources disagree, keep the most direct one (the game's code, a developer, a frame count) and note the rest. What no source shows stays **unknown**: propose a reasonable value to tune, marked as an assumption.

Code found in a source or in the game can be used: adapt it to the project's layers and composition, with the numbers in `@export` / `.tres`. Assets of the original (sprites, audio, levels, text): ask the user before bringing them into the game.

## Flow

1. **A concrete question**: "how does X compute knockback from speed?", not "copy the game".
2. **Research**: the orchestrator (this chat) runs it, not `studio-developer`. Web first; if the user has the game and it can be opened, offer to decompile it. Summarize for the user with the links; do not paste whole pages.
3. **Deduce** the model: a formula, a value table or a state machine that explains what the sources show (or the code found), and the unknowns.
4. **Report** in the `F<n>` of `FEATURES.md` (or `research/<slug>.md` if it is long): what it does, the model or the code, the sources, and what becomes `@export` / `.tres`.
5. **Implementation**: `/implement-feature`. The tech lead plans pieces that fit the project's layers (the numbers go to `@export` / `.tres`); the developer writes or adapts the code.

Playtest criteria use the values found ("6-frame coyote time", "knockback doubles at max speed").
