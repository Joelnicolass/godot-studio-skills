# Estándares para el subagente

Los subagentes **no** ven el chat. El orquestador pega este bloque en cada `Task`.

```markdown
## Estándares del proyecto

- Autoridad: PRD.md > FEATURES.md > RULES.md > VISUAL.md > RFC > plan generado.
- Clean vs estándar y tipo de MP **ya elegidos**: no los cambies. Sin MP → ni addon ni RPCs. Local/WiFi → listen-server. Online → dedicated (`host_dedicated`), no un listen detrás de NAT.
- Composición: contenedor flaco, hijos / packed, `@export` / `%UniqueName`, tipos en Resource `.tres`. Un nodo no pinta + spawnea + puntúa + cambia de escena.
- Copy de UI en el idioma del producto; IDs en inglés. Puntaje/copy/fútbol **fuera** de `addons/mp_kit`.
- Arte: no inventar sprites ni modelos. MCP Aseprite/Blender solo con OK + referencias. Shaders: Godot Shaders / Shadertoy; un pass = packed scene.
- Motion: 12 principios. Tween **o** `AnimationPlayer` según el clip; knobs `@export` / timeline, sin números mágicos. Skill `godot-animation`.
- Juicy (jugoso): shake, VFX, post, impacto = presentación local, packed + `@export`. Skill `godot-juicy` / `/add-juicy`. No es puntaje.
- FSM: hijos `FsmState` bajo `FsmMachine` (addon `fsm_kit` / `/add-state-machine`). No un `enum` de 200 líneas.
- Plataformas 2D: coyote / buffer / apex = `PlatMotor` (addon `plat_kit` / `/add-platformer-2d`). Dash/stamina solo si el producto los pide.
- Playtest ≠ GUT. Si hay `addons/agent_kit/`: `inspect --unique`, `cli.sh flow --fail-on-error`, JSON/harness **solo** en `res://agent/`. **Nunca** helpers de playtest en `src/` (spawn / forzar estado / contar / pausar para el flow; `agent_*` ni el mismo rol con otro nombre). `call()` a `_privados`, `extends` la clase de producto desde `agent/`, o `set("_…")` **no** limpia. No API de producto cuyo único caller sea el flow. Cubrir **todos** los criterios de **este** slice. Consola `ERROR`/`SCRIPT ERROR`/`AGENT_STEP_ERROR` = FAIL. Turnos: `try_click` + `repeat`. Visual exige `VISUAL.md` o refs.
- Un RFC, una feature (`/implement-feature`) o un cambio acotado. Extra no pedido = alcance, no “mejora”.
```

Si RULES.md tiene convenciones extra, sumá 3–6 viñetas **de ese archivo**. No pegues skills enteras.
