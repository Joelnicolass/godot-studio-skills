# Standards for the subagent

Subagents **do not** see the chat. The orchestrator pastes this block into every subagent prompt.

```markdown
## Project standards

- Authority: PRD.md > FEATURES.md > RULES.md > VISUAL.md > RFC > generated plan.
- Clean vs standard and MP type are **already chosen**: do not change them. No MP → no addon, no RPCs. Local/Wi-Fi → listen-server. Online → dedicated (`host_dedicated`), not a listen behind NAT.
- Rule 0, simple and predictable: the value lives on the node that uses it (`@export`); a `.tres` only if several things share it or it is edited as a type; no pointers through tags or strings; changing a number opens 2 files at most.
- Composition: thin container, children / packed, `@export` / `%UniqueName`. One node does not paint + spawn + score + change scene.
- Patterns, proven ones only: past-tense typed signals, signal up / call down, an `Events` autoload with signals only for what crosses systems, FSM, component, command, pool, spawner. No registries, locators, or managers.
- GDScript (skill `godot-code-quality`): real typing (typed collections; no `.get("x")`, `has_method`, or `call` on known types; a class instead of a `Dictionary` with keys in a comment), no magic numbers, `##` only for the API and `#` inside functions, no line cap (split by responsibility).
- Code, comments, logs, and warnings in English; what the player sees goes through `tr()` in the product language. Score/copy/title gameplay **out** of `addons/mp_kit`.
- Art: do not invent sprites or models. Aseprite/Blender MCP only with OK + references. Procedural materials / textures: Material Maker only with OK + references; the surface type is a `.tres` (skill `godot-material-maker`). Shaders: Godot Shaders / Shadertoy; one pass = packed scene.
- A feature “like in X”: the orchestrator researches it (web, and decompiling the game when it can be opened). If the `F<n>` carries findings, use them: numbers in `@export` / `.tres`, code adapted to the project's layers. Ask before bringing in the original's assets.
- Motion: 12 principles. Tween **or** `AnimationPlayer` per clip; `@export` / timeline knobs, no magic numbers. Skill `godot-animation`.
- Juicy: shake, VFX, post, impact = local presentation, packed + `@export`. Skill `godot-juicy` / `/add-juicy`. Not score.
- FSM: `FsmState` children under `FsmMachine` (addon `fsm_kit` / `/add-state-machine`). Not a 200-line `enum`.
- 2D platformer: coyote / buffer / apex = `PlatMotor` (addon `plat_kit` / `/add-platformer-2d`). Dash/stamina only if the product asks.
- Whoever writes does not self-validate. Playtest ≠ GUT. The test scene is `res://debug/` (tech lead names it, developer builds it, reviewer checks it). The playtester only writes `res://agent/flows` and plays with InputMap / click. No `call()` to build the world. No helpers in `src/`. Cover **all** criteria of **this** slice. A PNG that does not show what the criterion named is FAIL, even if a number changed. `ERROR` / `SCRIPT ERROR` / `AGENT_STEP_ERROR` = FAIL. Palette and type are the visual pass, not this one. Visual requires `VISUAL.md` or refs. The live detail is `evaluate.md` in the playtest module.
- Approved tree = file contract. Touch only what is marked `[+]` / `[~]` / `[-]` in the tree. Need another file? Stop and return it to the orchestrator; do not create or edit it.
- One RFC or a bounded change. Extra not asked for = scope, not a “improvement”.
```

If RULES.md has extra conventions, add 3–6 bullets **from that file**. Do not paste whole skills.
