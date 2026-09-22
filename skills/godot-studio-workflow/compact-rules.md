# Standards for the subagent

Subagents **do not** see the chat. The orchestrator pastes this block into every `Task`.

```markdown
## Project standards

- Authority: PRD.md > FEATURES.md > RULES.md > VISUAL.md > RFC > generated plan.
- Clean vs standard and MP type are **already chosen**: do not change them. No MP → no addon, no RPCs. Local/Wi-Fi → listen-server. Online → dedicated (`host_dedicated`), not a listen behind NAT.
- Composition: thin container, children / packed, `@export` / `%UniqueName`, types in Resource `.tres`. One node does not paint + spawn + score + change scene.
- UI copy in the product language; IDs in English. Score/copy/title gameplay **out** of `addons/mp_kit`.
- Art: do not invent sprites or models. Aseprite/Blender MCP only with OK + references. Shaders: Godot Shaders / Shadertoy; one pass = packed scene.
- Motion: 12 principles. Tween **or** `AnimationPlayer` per clip; `@export` / timeline knobs, no magic numbers. Skill `godot-animation`.
- Juicy: shake, VFX, post, impact = local presentation, packed + `@export`. Skill `godot-juicy` / `/add-juicy`. Not score.
- FSM: `FsmState` children under `FsmMachine` (addon `fsm_kit` / `/add-state-machine`). Not a 200-line `enum`.
- 2D platformer: coyote / buffer / apex = `PlatMotor` (addon `plat_kit` / `/add-platformer-2d`). Dash/stamina only if the product asks.
- Whoever writes does not self-validate. Playtest ≠ GUT. The test scene is `res://debug/` (tech lead names it, developer builds it, reviewer checks it). The playtester only writes `res://agent/flows` and plays with InputMap / click. No `call()` to build the world. No helpers in `src/`. Cover **all** criteria of **this** slice. `ERROR` / `SCRIPT ERROR` / `AGENT_STEP_ERROR` = FAIL. Visual requires `VISUAL.md` or refs. The live detail is `evaluate.md` in the playtest module.
- One RFC or a bounded change. Extra not asked for = scope, not a “improvement”.
```

If RULES.md has extra conventions, add 3–6 bullets **from that file**. Do not paste whole skills.
