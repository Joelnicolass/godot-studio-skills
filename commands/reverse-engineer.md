---
description: "Reverse engineer a mechanic from another game or app with REA (deduce or decompile) to reimplement it in Godot."
argument-hint: "<game or app> <what you want to understand>"
---

Understand **how** a mechanic or feature of another game / app works and get it ready to reimplement in the **game's Godot project**. Tool: [REA](https://github.com/Joelnicolass/rea).

This does **not** implement the feature: it ends in a report and the `F<n>`. Then `/implement-feature`.

Load: `godot-reverse-engineering`. If `godot-studio-workflow` is loaded, the orchestrator (this chat) runs the investigation, not a `studio-developer`.

## 1. Scope

If missing, ask in one batch (`AskUserQuestion` in Claude Code / `AskQuestion` in Cursor, if available):

1. Which game / app and **what** behavior (one concrete question).
2. Do you own it or are you authorized to analyze it (license / EULA)? Without a clear yes, stay with **deducing** by observation.
3. What is available: web build, `.exe`, `Assembly-CSharp.dll`, APK, only video / gameplay.

## 2. Pick a path

Deduce (observe, measure) before decompiling. Table in [godot-reverse-engineering](../skills/godot-reverse-engineering/SKILL.md). If REA is needed and its tools are missing: ask for OK to run `npx rea-agents setup`; do not install it on your own.

## 3. Investigate

Evidence for every conclusion (function, offset, capture, frame). What could not be seen stays **unknown**, not assumed.

## 4. Report

In `FEATURES.md` (a new or existing `F<n>`) or `research/RE-<slug>.md`:

- What it does, in one sentence.
- Formula / value table / state machine.
- Evidence and unknowns.
- What becomes `@export` or `.tres` in Godot.

No decompiled code and none of the original's assets.

## 5. Done when

- The user understands the mechanism and has numbers to tune.
- The `F<n>` has measurable criteria with those numbers.
- Proposed next step: `/implement-feature`.
