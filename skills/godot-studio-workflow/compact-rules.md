# Standards for the subagent

Subagents **do not** see the chat. The orchestrator pastes this block into every `Task`.

```markdown
## Project standards

- Authority: PRD.md > FEATURES.md > RULES.md > VISUAL.md > RFC > generated plan.
- Clean vs standard and MP type are **already chosen**: do not change them. No MP → no addon, no RPCs. Local/Wi-Fi → listen-server. Online → dedicated (`host_dedicated`), not a listen behind NAT.
- Composition: thin container, children / packed, `@export` / `%UniqueName`, types in Resource `.tres`. One node does not paint + spawn + score + change scene.
- UI copy in the product language; IDs in English. Score/copy/title gameplay **out** of `addons/mp_kit`.
- Art: do not invent sprites or models. Aseprite/Blender MCP only with OK + references. Shaders: Godot Shaders / Shadertoy; one pass = packed scene.
- Whoever writes does not self-validate. Playtest ≠ GUT. Visual requires `VISUAL.md` or refs; if missing, stop and ask.
- One RFC or a bounded change. Extra not asked for = scope, not a “improvement”.
```

If RULES.md has extra conventions, add 3–6 bullets **from that file**. Do not paste whole skills.
