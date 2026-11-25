# Cómo agregar una feature

En el juego: command `/implement-feature` (orquestador). No regeneres el PRD.

Leer primero `SKILL.md` (el tamaño y el tipo de MP ya están elegidos). Dónde vive cada número: regla 0 de [godot-code-quality](../godot-code-quality/SKILL.md). Tipos: [resources.md](../godot-composition-first/resources.md). Tests: [godot-testing](../godot-testing/SKILL.md). Red: `godot-mp-kit` **solo** si hay MP (local = listen; online = dedicated). Si no hay MP, el bloque de red es N/A.

Si un ítem no aplica, escribir “N/A”. No saltearlo en silencio.

## 1P (siempre)

1. [ ] Alcance de producto explícito. Si es un RFC del studio: el tech-lead mostró árbol + responsabilidades **antes** del OK.
2. [ ] ¿Es un **tipo** con variantes (otro proyectil, enemigo, item)? Otros números: otro `_type.tres` y la misma escena. Otra estructura u otro arte: una escena heredada de la base (*New Inherited Scene*), un solo nivel. No un script por variante.
3. [ ] Cada número de diseño tiene **un** dueño (el `.tres` del tipo, o la raíz de la escena) y cambiarlo abre como mucho 2 archivos. Reglas de partida: `@export` de `match.tscn`, o `match_config.tres`.
4. [ ] `docs/tuning.md` tiene una fila por cada perilla de diseño nueva (quiero cambiar → archivo → nodo → propiedad).
5. [ ] Cada `@export` nuevo tiene `##`, rango y unidad. Cada archivo nuevo está en su carpeta, con su sufijo.
6. [ ] InputMap: acciones con nombre de lo que hacen (`move_left`, `attack`), no `KEY_*`. Mantener apretado en `_physics_process`; una pulsación de gameplay en `_unhandled_input`.
7. [ ] Referencias `@export` / `%UniqueName` para nodos propios. Escena jugable con F6 y que se ve en el editor como en el juego. FSM: addon `fsm_kit` si hay estados. Platformer 2D: `plat_kit` (coyote/buffer), no `is_on_floor()` pelado. Selección / órdenes de RTS: `rts_kit`, no un rectángulo de selección hecho a mano. Props plantados y su navmesh: `prop_kit`, no miles de props puestos a mano ni una región entera rehorneada.
8. [ ] ¿Regla que merece un test sin escena? Núcleo puro al lado del nodo + test. ¿El mundo se hincha? Un componente, no una capa nueva.
9. [ ] Efectos locales; shaders de [Godot Shaders](https://godotshaders.com/shader/?orderby=date&order=DESC) / [Shadertoy](https://www.shadertoy.com). Sprites 2D: ¿el usuario quiere MCP/arte? Si sí, referencias + [godot-animation](../godot-animation/SKILL.md). Si la feature es **3D**: ¿quiere MCP Blender? Si sí, referencias + [assets.md](../godot-composition-first/assets.md). Si no, placeholder. Textos de la UI en el archivo de traducciones, en el idioma del producto; código en inglés. HUD: no inventar look; `VISUAL.md` o refs.

## Si hay red (MpKit)

Si eligieron **local / WiFi** o **online**. Si no hay MP: N/A. Online: dedicated, ver [dedicated.md](../godot-mp-kit/dedicated.md).

10. [ ] Input del jugador: hijo `MpInput`; el servidor lee `input.get_vector(...)` / `is_action_just_pressed(...)` (o `mp_move(keys, delta)` con predicción). Una orden puntual: `net.to_server(&"x", args)` → `mp_sv_x(args)`. Túnel `send_custom` solo si no alcanzan.
11. [ ] Solo el dueño pide los `mp_sv_*` de su actor (`MpActor › Owner › callers`); validá lo que piden adentro. Sin `@rpc` a mano salvo un caso que los nodos no cubren (anotalo).
12. [ ] Spawn de simulación: **solo el servidor**, con `MpSpawner.spawn_actor(escena, {...})` (la escena en *Extra Scenes*).
13. [ ] Lo que se ve igual en todos: tildado en `MpActor › Sync` (no un `MultiplayerSynchronizer` armado a mano).
14. [ ] Colisión / `queue_free` / puntos: autoridad del servidor (`net.is_authority()`).
15. [ ] El cliente no muta vidas ni puntaje: `Mp.state()` lo escribe el servidor.
16. [ ] 1P: mismo código (`Mp.play_solo()`), **sin** `host()`.
17. [ ] 2P: no se duplican actores. Rejoin: decisión explícita. Dedicated: sin pawn para el server (`local_slot() == 0`).
18. [ ] El actor no tiene RPC de score.

## Pipeline de input

```
1. InputMap (acciones), no scancodes
2. if not puede_actuar(): return
3. Sin red: el actor lee Input y aplica.
   Con MpKit: el MpInput del actor manda las acciones del dueño; el servidor las lee
   (input.is_action_just_pressed(...)) y aplica. Una orden puntual: net.to_server(&"use", payload).
```

El nodo de input **no** instancia proyectiles ni suma puntos. Solo pide.

## Presentación

- Post-proceso, flashes: cada peer. No van en el snapshot de reglas.
- Un pass FX = una packed scene.
- HUD: `mouse_filter = IGNORE` salvo controles que traguen el pointer.
