# FsmKit

Máquina de estados por **composición**: un `FsmMachine` y hijos `FsmState`. **Cero** reglas de partida, puntaje o copy. No hay autoload.

El actor es un contenedor flaco. Los estados **no** hacen `get_parent()` como API: el machine inyecta `actor`.

## Instalar

```bash
./install.sh --addon /path/to/godot-project fsm_kit
```

Habilitá el plugin **FsmKit** (tipos `FsmMachine` / `FsmState` en Create Node). Proyecto ▸ Herramientas ▸ *FsmKit: Add machine under selection* agrega `States` con `Idle` y `Move` bajo el nodo elegido (se deshace con Ctrl+Z).

## Ejemplo mínimo

`examples/minimal_2d/minimal_2d.tscn` (F6): un cuadrado con tres estados. Las flechas lo mueven (`Move`), Enter es un golpe que lo empuja (`Hurt`) y después vuelve a `Idle`. Usa las acciones `ui_*`, así corre en cualquier proyecto.

```
Minimal2D
├── Mover            # CharacterBody2D, mover.gd
│   ├── Shape, Body
│   └── States       # FsmMachine: actor = Mover, initial_state = Idle
│       ├── Idle     # states/idle.gd
│       ├── Move     # states/move.gd: @export speed
│       └── Hurt     # states/hurt.gd: @export duration, push_speed, tint
└── Hud/State        # Label que sigue state_changed
```

El actor solo traduce lo que pasa en el juego a una transición:

```gdscript
# mover.gd (lo esencial)
extends CharacterBody2D

@onready var states: FsmMachine = $States


func hit(push: Vector2) -> void:
	states.transition(&"Hurt", push)  # el dueño: cambia ya; el empuje viaja como payload
```

Cada estado hace su parte, con sus números en su propio inspector, y pide el siguiente:

```gdscript
# states/move.gd
extends FsmState

@export var speed := 220.0


func physics_update(_delta: float) -> void:
	var wish := Input.get_vector(&"ui_left", &"ui_right", &"ui_up", &"ui_down")
	if wish == Vector2.ZERO:
		transition(&"Idle")  # un pedido: pasa por _request_transition()
		return
	var body := actor as CharacterBody2D
	body.velocity = wish * speed
	body.move_and_slide()
```

```gdscript
# states/hurt.gd (lo esencial)
func enter() -> void:
	super()  # emite entered
	_start(machine.payload)


func apply_payload(next_payload: Variant) -> void:
	_start(next_payload)  # otro golpe estando herido: el mismo estado con un empuje nuevo
```

El resto del juego escucha la máquina, como el Label del ejemplo: `states.state_changed.connect(_show)`.

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

`transition(&"Hurt", payload)` lleva datos genéricos (un hitbox, un objetivo); el kit no los interpreta y el estado lee `machine.payload`. Pedir otra vez el estado actual con otro payload no hace exit / enter: el estado recibe `apply_payload(payload)`. La señal `transitioned(from, to, payload)` sale en cada transición, también en una repetición (`state_changed`, solo en un cambio real).

## Arranque

Con `autostart` prendido (por defecto) el machine entra solo a `initial_state` (o a su primer hijo `FsmState`) en cuanto tiene un estado y un actor (`actor` por defecto es el padre). Si los estados o el actor llegan después, llamá `notify_actor_ready()` cuando existan.

Con `autostart` apagado no corre nada hasta que llamás `start(state, payload)`: un actor que primero se arma, un enemigo de un pool, un personaje que carga de un save, un jugador que entra a mitad de partida en el estado que dice la red.

```gdscript
machine.start($States/Hurt, {"animate": false})   # una vez; false si todavía no hay estado o actor
```

## Quién cambia el estado

| Quién | Llamada | Qué pasa |
|---|---|---|
| El dueño (el actor, el juego) | `machine.transition(&"Hurt", payload)` o `transition_to(nodo, payload)` | Cambia ya |
| Un estado | `transition(&"Hurt", payload)` (el suyo) | Un pedido: decide `FsmMachine._request_transition(next, payload)`. Por defecto dice que sí y el estado cambia ya |

Overrideá `_request_transition` (un script que `extends FsmMachine`) cuando el estado es de otro: un valor que replica la red, un replay, un tutorial que solo deja algunos pasos. Escribí donde vive el estado y devolvé `false`; el dueño llama `transition_to()` después.

```gdscript
extends FsmMachine

func _request_transition(next: FsmState, next_payload: Variant) -> bool:
	if not multiplayer.is_server():
		return false          # decide el servidor; su valor replicado llama transition_to() acá
	return true
```

## Avanzarlo vos

El machine llama `physics_update` / `update` del estado actual desde su propio `_physics_process` / `_process`. Para avanzar en tu propio orden (un rollback, una simulación determinista, turnos, pausar un solo actor) apagá `run_physics` / `run_process` y llamá `step_physics(delta)` / `step_process(delta)` donde los necesites. Dejá el flag prendido **o** llamá el step, no las dos cosas: con las dos el estado corre dos veces.

## Leerlo

`current` (el nodo), `current_name()` (vacío antes de arrancar), `is_in(&"Hurt")`, `is_started()`, `payload`.

## Tests

```bash
godot --headless --path <proyecto> --script res://addons/fsm_kit/tests/fsm_test_runner.gd
```

En el repo del kit, el proyecto es `fsmkit_lab/` (ahí `addons/fsm_kit` es un symlink).

`FSMKIT TESTS PASS (n)`. También juegan el ejemplo mínimo con input. Un test que corta con un error de script, o que no llega a chequear nada, falla (los errores de script se ven desde Godot 4.5). La primera vez en un proyecto, importalo una vez (`godot --headless --path <proyecto> --import`) para que se conozcan `FsmMachine` / `FsmState`.

Cambios entre versiones, y qué actualizar en tu proyecto: [CHANGELOG.md](CHANGELOG.md).

## Tips y recomendaciones

- Cada número va en el estado que lo usa (`@export var speed` en `Move`), no en el actor: cambiar un valor abre un solo nodo.
- El actor queda flaco. Traduce lo que pasa en el juego (un golpe, una orden, un dato de la red) a `machine.transition(...)`; los estados usan `actor` y `machine`, nunca `get_parent()`.
- Llamá `super()` en `enter` / `exit` si alguien escucha `entered` / `exited`.
- Pedir el estado actual con otro payload no sale ni entra: llega como `apply_payload`. Sirve para "otro golpe mientras está herido" sin reiniciar la animación.
- Un estado nuevo es un nodo nuevo. Si aparece un `match state` en el actor, falta un estado.
- ¿Avanzar en tu propio orden (rollback, turnos, red)? Apagá `run_physics` / `run_process` y llamá `step_physics` / `step_process`: una cosa o la otra.
- ¿El estado lo decide otro (el servidor)? Un `extends FsmMachine` que overridea `_request_transition` y devuelve `false` (arriba, en [Quién cambia el estado](#quién-cambia-el-estado)).
- Un motor de movimiento (por ejemplo el `PlatMotor` de PlatKit) va como **otro** hijo del actor, con su lectura de input apagada; los estados le pasan la entrada. Los kits no se conocen entre sí: los une tu script.

## No hagas

- Un `enum` + `match` de 200 líneas en el actor.
- Guardar HP / puntaje / spawn en un estado.
- Fork del addon por título.
