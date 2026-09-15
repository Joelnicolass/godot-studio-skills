# Estándares para el subagente

Los subagentes **no** ven el chat. El orquestador pega este bloque en cada `Task`.

```markdown
## Estándares del proyecto

- Autoridad: PRD.md > FEATURES.md > RULES.md > VISUAL.md > RFC > plan generado.
- Clean vs estándar y tipo de MP **ya elegidos**: no los cambies. Sin MP → ni addon ni RPCs. Local/WiFi → listen-server. Online → dedicated (`host_dedicated`), no un listen detrás de NAT.
- Composición: contenedor flaco, hijos / packed, `@export` / `%UniqueName`, tipos en Resource `.tres`. Un nodo no pinta + spawnea + puntúa + cambia de escena.
- Copy de UI en el idioma del producto; IDs en inglés. Puntaje/copy/fútbol **fuera** de `addons/mp_kit`.
- Arte: no inventar sprites ni modelos. MCP Aseprite/Blender solo con OK + referencias. Shaders: Godot Shaders / Shadertoy; un pass = packed scene.
- Quien escribe no se auto-valida. Playtest ≠ GUT. Visual exige `VISUAL.md` o refs; si faltan, parar y pedirlas.
- Un RFC o un cambio acotado. Extra no pedido = alcance, no “mejora”.
```

Si RULES.md tiene convenciones extra, sumá 3–6 viñetas **de ese archivo**. No pegues skills enteras.
