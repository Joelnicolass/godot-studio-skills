# Estándares para el subagente

Los subagentes **no** ven el chat. El orquestador pega este bloque en el prompt de cada subagente.

```markdown
## Estándares del proyecto

- Autoridad: PRD.md > FEATURES.md > RULES.md > VISUAL.md > RFC > plan generado.
- Tamaño del proyecto (por entidad, o sistemas + contenido; Clean solo si el repo ya lo declara) y tipo de MP **ya elegidos**: no los cambies. Carpetas y sufijos de archivo según RULES.md (skill `godot-code-quality` §1). Sin MP → ni addon ni RPCs. Local/WiFi → listen-server. Online → dedicated (`host_dedicated`), no un listen detrás de NAT.
- Regla 0 (skill `godot-code-quality` §0): un dueño por número de diseño (el `.tres` del tipo, o la raíz de la escena); catálogos tipados sí, tablas ciegas no; cambiar un número abre como mucho 2 archivos; cada perilla nueva tiene su fila en `docs/tuning.md`.
- Editor: cada `@export` con `##`, rango y unidad; lo que se ve al correr se ve al abrir la escena; variantes de estructura por escena heredada.
- Composición: contenedor flaco, hijos / packed, `@export` / `%UniqueName`. Un nodo no pinta + spawnea + puntúa + cambia de escena.
- Patrones, solo los probados: señales en pasado y tipadas, signal up / call down, autoload `Events` solo con señales para lo que cruza sistemas, FSM, componente, command, pool, spawner. Nada de registries, locators ni managers.
- GDScript (skill `godot-code-quality`): tipado real (colecciones tipadas; sin `.get("x")`, `has_method` ni `call` sobre tipos conocidos; una clase en vez de un `Dictionary` con claves en un comentario), sin números mágicos, `##` solo para la API y `#` dentro de funciones, sin tope de líneas (se parte por responsabilidad).
- Código, comentarios, logs y avisos en inglés; lo que ve el jugador, en el archivo de traducciones (`tr()`), en el idioma del producto. Puntaje/copy/fútbol **fuera** de `addons/mp_kit`.
- Arte: no inventar sprites ni modelos. MCP Aseprite/Blender solo con OK + referencias. Materiales / texturas procedurales: Material Maker solo con OK + referencias; el tipo de superficie es un `_material.tres` (skill `godot-material-maker`). Shaders: Godot Shaders / Shadertoy; un pass = packed scene.
- Una feature “como en X”: la investiga el orquestador (web, y decompilar el juego si se puede abrir). Si el `F<n>` trae hallazgos, usalos: cada número en su dueño (regla 0), código adaptado a las carpetas del proyecto. Preguntá antes de traer assets del original.
- Motion: 12 principios. Tween **o** `AnimationPlayer` según el clip; perillas `@export` / timeline, sin números mágicos ni curvas (`TRANS_*`, `EASE_*`) en el código. Skill `godot-animation`.
- Juicy (jugoso): shake, VFX, post, impacto = presentación local, packed + `@export`. Skill `godot-juicy` / `/add-juicy`. No es puntaje.
- FSM: hijos `FsmState` bajo `FsmMachine` (addon `fsm_kit` / `/add-state-machine`). No un `enum` de 200 líneas.
- Plataformas 2D: coyote / buffer / apex = `PlatMotor` (addon `plat_kit` / `/add-platformer-2d`). Dash/stamina solo si el producto los pide.
- Controles de RTS: `RtsUnit` en cada unidad + el equipo de RtsKit (addon `rts_kit` / `/add-rts-controls`). El kit manda, el juego mueve y pelea; nada de red dentro del addon.
- Props: plantados como nodos guardados (`PropScatter3D` / `PropScatter2D`), dibujados en lotes (`PropBatch3D`), cortando un navmesh horneado por zonas (`PropNavZones3D` / `PropNavZones2D`; addon `prop_kit` / `/add-props`). Los props van en el grupo `prop_obstruction`, en una capa que el navmesh no parsea; un cambio rehornea solo sus zonas.
- Playtest ≠ GUT. La escena de prueba es `res://debug/` (la nombra el tech lead, la arma el developer, la revisa el reviewer). El playtester solo escribe `res://agent/flows` y juega con InputMap / click. No `call()` para construir el mundo. No helpers fuera de `res://agent/`. Cubrir **todos** los criterios de **este** slice. Un PNG que no muestra lo que el criterio nombra es FAIL, aunque haya cambiado un número. `ERROR` / `SCRIPT ERROR` / `AGENT_STEP_ERROR` = FAIL. Look (paleta, tipografía) es el pase visual, no este. Visual exige `VISUAL.md` o refs.
- Árbol aprobado = contrato de archivos. Solo tocás lo que tiene `[+]` / `[~]` / `[-]` en el árbol. ¿Hace falta otro archivo? Pará y devolvelo al orquestador; no lo crees ni lo edites.
- Un RFC, una feature (`/implement-feature`) o un cambio acotado. Extra no pedido = alcance, no “mejora”.
```

Si RULES.md tiene convenciones extra, sumá 3–6 viñetas **de ese archivo**. No pegues skills enteras.
