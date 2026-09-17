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
- Whoever writes does not self-validate. Playtest ≠ GUT. If `addons/agent_kit/` is present: `inspect --unique`, `cli.sh flow --fail-on-error`, JSON/harness **only** in `res://agent/`. **Never** playtest helpers in `src/` (spawn / force-state / count / pause for the flow; `agent_*` or the same role under another name). `call()` on `_privates`, `extends` the product class from `agent/`, or `set("_…")` does **not** keep `src/` clean. No product API whose only caller is the flow. Cover **all** criteria of **this** slice. Console `ERROR`/`SCRIPT ERROR`/`AGENT_STEP_ERROR` = FAIL. Turns: `try_click` + `repeat`. Visual requires `VISUAL.md` or refs.
- One RFC or a bounded change. Extra not asked for = scope, not a “improvement”.
```

If RULES.md has extra conventions, add 3–6 bullets **from that file**. Do not paste whole skills.
