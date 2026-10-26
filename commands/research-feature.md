---
description: "Research how a mechanic of a similar game works (web search, observation, decompiling it when possible), deduce its code and get it ready to write in Godot."
argument-hint: "<game> <what you want to understand>"
---

Understand **how** a mechanic or feature of a similar game works, from the web, from watching it and, when the game can be opened, from its code, and get it ready to build in the **game's Godot project**.

This does **not** implement the feature: it ends in a report and the `F<n>`. Then `/implement-feature`.

Load: `godot-feature-research`. If `godot-studio-workflow` is loaded, the orchestrator (this chat) runs the research, not a `studio-developer`.

## 1. Scope

If missing, ask in one batch (`AskUserQuestion` in Claude Code / `AskQuestion` in Cursor, if available):

1. Which game and **what** behavior (one concrete question).
2. What the user can add: do they play it, do they have its files, a video, a wiki or a talk about it.

## 2. Research

Search the web: the game's wiki and guides, devlogs and talks by its developers, source code (open-source games, mods, community repos), frame-data and speedrun pages, gameplay video, articles that analyze the mechanic. If the user has the game and it can be opened, offer to decompile it (ask before installing a tool). Sources table in [godot-feature-research](../skills/godot-feature-research/SKILL.md). Every conclusion with its source (a link, a timestamp, a counted frame, a file of the game). What no source shows stays **unknown**, not assumed.

## 3. Deduce

A formula, a value table or a state machine that explains what the sources show, or the code found. Mark every assumption.

## 4. Report

In `FEATURES.md` (a new or existing `F<n>`) or `research/<slug>.md`:

- What it does, in one sentence.
- Formula / value table / state machine, or the code found.
- Sources and unknowns.
- What becomes `@export` or `.tres` in Godot.

Assets of the original: ask before bringing them into the game.

## 5. Done when

- The user understands the mechanism and has numbers to tune.
- The `F<n>` has measurable criteria with those numbers.
- Proposed next step: `/implement-feature`.
