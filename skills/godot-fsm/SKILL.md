---
name: godot-fsm
description: >-
  Agrega una máquina de estados por composición en Godot 4 (addon FsmKit:
  FsmMachine + hijos FsmState, socket actor, transición por nombre de nodo).
  Usar cuando el usuario quiere una state machine, FSM, estados Idle/Move/Hurt
  o /add-state-machine. No es un motor de plataformas. No son reglas de juego.
---

# Godot — máquina de estados (FsmKit)

Estados = **nodos hijos**, no un `enum` en el actor. Addon `addons/fsm_kit/` en el **proyecto del juego**.

Si el addon no está:

```bash
./install.sh --addon /path/to/godot-project fsm_kit
```

Enable plugin **FsmKit**. Pedido acotado: `/add-state-machine`. Sin subagente extra: `studio-developer` (o este chat si 1–3 archivos).

Composición: [godot-composition-first](../godot-composition-first/SKILL.md). Plataformas 2D (coyote, buffer): [godot-platformer-2d](../godot-platformer-2d/SKILL.md) — el motor es **otro** hijo; los estados lo llaman.

## Árbol

```
Actor
├── Visual
├── PlatMotor          # opcional, otro addon
└── States             # FsmMachine
    ├── Idle
    ├── Move
    └── Hurt
```

- `@export var actor` en el machine (el contenedor).
- `@export var initial_state`.
- `transition(&"Hurt")` = nombre de nodo. `transition(&"Hurt", payload)` lleva datos genéricos (`machine.payload`); el mismo estado otra vez solo llama `apply_payload`. Estados o actor agregados después: `notify_actor_ready()`.
- Arranque: `autostart` (prendido) entra solo a `initial_state`. Apagado: `start(state, payload)` cuando el actor está listo (de un pool, cargado de un save, entró a mitad de partida).
- Quién lo cambia: el dueño llama `machine.transition()` (directo). El `transition()` de un estado es un **pedido** que decide `FsmMachine._request_transition(next, payload)` (por defecto sí).
- Orden de avance propio (rollback, turnos, simulación determinista): `run_physics` / `run_process` apagados y `step_physics(delta)` / `step_process(delta)`. Leer: `current_name()`, `is_in(&"Hurt")`.
- El estado usa `actor` / `machine`, no `get_parent()` como API.

Al overridear `enter` / `exit`, llamá `super.enter()` si querés las señales.

## Qué va en un estado

| Sí | No |
|----|----|
| `enter` / `exit`, pedir `actor.velocity`, llamar `PlatMotor.request_jump()` | HP, puntaje, spawn, cambio de escena |
| `physics_update` de **este** verbo | `match kind` de todo el actor |
| Señales `entered` / `exited` | Autoload `StateManager` |

Un estado nuevo = un nodo nuevo, no un `elif` más.

## MP

La simulación (a qué estado pasás) es **autoridad del host**. Los guests interpolan / pintan. No metas FsmKit en `addons/mp_kit`.

Si el estado mismo se replica (un valor del host): un script que `extends FsmMachine` overridea `_request_transition` para escribir el pedido donde decide el host y devolver `false`; el setter del valor replicado llama `transition_to()`. Un peer que entra a mitad de partida: `autostart = false` y `start(<el estado que dice la red>)`.

Tests del addon: `godot --headless --path <proyecto> --script res://addons/fsm_kit/tests/fsm_test_runner.gd`. Si venís de 0.1.0: `addons/fsm_kit/CHANGELOG.md` (primero lo que rompe).

## Anti-patrones

- Copiar `fsm_machine.gd` al feature “para cambiarlo un toque”.
- Estados que leen `Input` **y** aplican daño **y** spawnean.
- Machine como autoload global del título.
