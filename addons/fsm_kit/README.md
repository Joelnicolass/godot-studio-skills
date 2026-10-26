# FsmKit

Máquina de estados por **composición**: un `FsmMachine` y hijos `FsmState`. **Cero** reglas de partida, puntaje o copy. No hay autoload.

El actor es un contenedor flaco. Los estados **no** hacen `get_parent()` como API: el machine inyecta `actor`.

## Instalar

```bash
./install.sh --addon /path/to/godot-project fsm_kit
```

Habilitá el plugin **FsmKit** (tipos `FsmMachine` / `FsmState` en Create Node). Tools → `FsmKit: Add machine under selection`.

## Árbol

```
Actor (CharacterBody2D / …)
├── Visual
└── States          # FsmMachine, @export actor = Actor, initial_state = Idle
    ├── Idle        # FsmState
    ├── Move
    └── Hurt
```

`transition(&"Hurt")` busca el **nombre del nodo**. Cada estado overridea `enter` / `exit` / `update` / `physics_update` / `handle_input`.

`transition(&"Hurt", payload)` lleva datos genéricos (un hitbox, un objetivo); el kit no los interpreta y el estado lee `machine.payload`. Pedir otra vez el estado actual con otro payload no hace exit / enter: el estado recibe `apply_payload(payload)`. La señal `transitioned(from, to, payload)` sale en cada transición, también en una repetición (`state_changed`, solo en un cambio real). Si los estados (o el actor) se agregan después de que el machine está listo, llamá `notify_actor_ready()` cuando existan: el primer `enter` los espera.

## No hagas

- Un `enum` + `match` de 200 líneas en el actor.
- Guardar HP / puntaje / spawn en un estado.
- Fork del addon por título.
