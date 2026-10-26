---
name: godot-feature-research
description: >-
  Researches how a mechanic or feature of a similar game works by searching
  the web (wikis, devlogs, talks, guides, gameplay video) and by watching and
  measuring it, then deduces the behavior and writes original code for it in
  Godot 4. Use when the user says "like in X", "I want Y's mechanic", "how
  does Z do it", or /research-feature. No reverse engineering: never opens,
  decompiles or disassembles another game; copies no code or assets.
---

# Godot — feature research (web + deduction)

To build something "like in X", understand **how it behaves** from public sources and from playing or watching it, then write it in Godot from scratch. Jump curve, damage formula, waves, camera, loot table: turn them into an `F<n>` with numbers and criteria, and implement it like any feature (composition, `@export`, `.tres`). Scoped request: command `/research-feature`.

## Limits (mandatory)

- **No reverse engineering.** Never open, decompile, disassemble, unpack or patch another game or app, nor read its files or memory. What is found comes from public sources and from observing it.
- You extract **behavior**: formulas, timings, states, event order, values. Code you write is your own GDScript. Do not paste code from articles or repos of the original; when a source shows code, describe what it does and write it again.
- Do not copy the original's sprites, audio, levels or text.

## Where to look

Search the web (the agent's search and fetch tools) and say where each fact comes from.

| Source | What it gives |
|--------|---------------|
| The game's wiki and community guides | Values players measured (frames, damage, speeds, drop rates) |
| Devlogs, postmortems, GDC / conference talks by its developers | How and why it was designed, sometimes the exact numbers |
| Speedrun and frame-data pages | Precise timings: coyote time, buffers, invulnerability frames |
| Gameplay videos | What you can measure frame by frame (count frames, compare positions) |
| Articles and tutorials that analyze the mechanic | Known models (curves, state machines) to compare against |
| Playing it, if the user has it | Probing edges by hand (does it still jump 6 frames after leaving the ledge?) |

When sources disagree, keep the most direct one (a developer, a frame count) and note the rest. What no source shows stays **unknown**: propose a reasonable value to tune, marked as an assumption.

## Flow

1. **A concrete question**: "how does X compute knockback from speed?", not "copy the game".
2. **Research**: the orchestrator (this chat) runs it, not `studio-developer`. Summarize for the user with the links; do not paste whole pages.
3. **Deduce** the model: a formula, a value table or a state machine that explains what the sources show, and the unknowns.
4. **Report** in the `F<n>` of `FEATURES.md` (or `research/<slug>.md` if it is long): what it does, the model, the sources, and what becomes `@export` / `.tres`.
5. **Implementation**: `/implement-feature`. The tech lead plans original pieces (the numbers go to `@export` / `.tres`); the developer writes new GDScript; the reviewer marks **FAIL** for code or assets taken from the original.

Playtest criteria use the deduced values ("6-frame coyote time", "knockback doubles at max speed").
