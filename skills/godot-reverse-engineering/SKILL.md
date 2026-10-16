---
name: godot-reverse-engineering
description: >-
  Investigates how a mechanic or feature of another game or app works
  (reverse engineering) with REA, to reimplement it cleanly in Godot 4.
  Deduces by observation or decompiles (native with Hopper / Ghidra / IDA,
  .NET / Unity Mono, JS / HTML5 / Electron, APK). Use when the user says
  "like in X", "I want Y's mechanic", "how does Z do it", or
  /reverse-engineer. Only software the user owns or is authorized to
  examine; extracts behavior, does not copy code or assets.
---

# Godot — reverse engineering (REA)

[REA](https://github.com/Joelnicolass/rea) (a fork of [morluto/rea](https://github.com/morluto/rea); npm package `rea-agents`) connects the agent to reverse-engineering tools over MCP: native binaries, .NET assemblies, JS / Electron apps, websites, APKs, network and process captures. It returns findings **with evidence and limits**.

In the kit it is for understanding **how** something the user wants in their game works (jump curve, damage formula, waves, camera, loot table) and turning it into an `F<n>` with numbers and criteria. Then it is implemented like any feature: composition, `@export`, `.tres`. Scoped request: command `/reverse-engineer`.

## Limits (mandatory)

- Only software the user owns or is authorized to examine (the license / EULA allows it, research, interoperability, preservation). If that is unclear, ask **before** opening the binary.
- You extract **behavior**: formulas, timings, states, event order, values. Not code or assets. Do not paste decompiled pseudocode into `src/`: rewrite it as your own GDScript. Do not copy the original's sprites, audio, levels, or text.
- No bypassing DRM, anti-cheat, or licenses. Commercial tools (IDA, Hopper, JEB) only with the user's own license.

## Deduce or decompile

Pick the lightest path that answers the question.

| Situation | Path |
|-----------|------|
| Visible while playing | **Deduce**: record, count frames, probe edges (does it still jump 6 frames after leaving the ledge?). With REA, process or browser capture if needed |
| Web / HTML5 / Electron game | REA: JS analysis (modules, source maps, routes) or site observation |
| Unity Mono (`Assembly-CSharp.dll`) or other .NET | REA: static managed analysis (metadata, CIL) |
| Native (C / C++, Unity IL2CPP `GameAssembly`) | REA native with Hopper / Ghidra / IDA: pseudocode, strings, references |
| Android | REA: APK with JADX |
| Another Godot game (`.pck`) | REA does not list it: deduce by observation |

## Install (only with OK)

```bash
npx rea-agents setup
```

Pick Claude Code and/or Cursor in the wizard: it registers REA's MCP server and its instructions. Restart the agent (Claude Code: new session; `/mcp` shows whether it connected). Needs Node.js 22.19+ or 24.11+. Native: Hopper, Ghidra, or IDA already installed. If you use the fork, follow its README. If REA's tools do not show up, do not fake the analysis: say what is missing.

## Flow

1. **Concrete question**: “how does X compute knockback from speed?”, not “decompile the game”.
2. **Authorization** confirmed and path chosen (table above).
3. **Investigation**: the orchestrator (this chat) runs it, not `studio-developer`. Summarize for the user; do not paste dumps.
4. **Report** in the `F<n>` of `FEATURES.md` (or `research/RE-<slug>.md` if it is long): what was observed, evidence (function, offset, capture, frame), the formula or value table, and what remains unknown.
5. **Reimplementation**: `/implement-feature`. The tech lead plans original pieces (numbers go to `@export` / `.tres`); the developer writes new GDScript; the reviewer marks **FAIL** for literally ported pseudocode or the original's assets.

Playtest criteria use the deduced values (“6-frame coyote time”, “knockback doubles at max speed”).
