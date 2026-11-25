# Patrones de composición (Godot 4)

## StateMachine

Addon `fsm_kit`: padre `FsmMachine` con `@export var initial_state: FsmState`. Hijos = estados. `transition(&"Hurt")` busca por nombre de nodo.

- `FsmState.enter` / `exit` / `update` / `physics_update`.
- El actor se **inyecta**: `@export var actor: Node`. No `machine.get_parent()` como API.
- No guardar score en un estado.
- Command: `/add-state-machine`.

Plataformas 2D (coyote, buffer): addon `plat_kit` / `/add-platformer-2d`. El motor es **otro** hijo.

## Health / Hitbox / Hurtbox

`Health` (nodo `class_name`): si la entidad tiene un tipo, `max_hp` sale del tipo (`health.setup(type.max_hp)`) y la escena no lo pisa en el inspector de `Health`; si no tiene tipo, es el `@export` de `Health`. Nunca los dos. `hp` actual en el nodo. `signal damaged(amount: int)` / `signal died`. El padre orquesta (animación, `queue_free`).

Hitbox / Hurtbox = `Area2D` packed scenes. Opcional: grupo `"hurtbox"` si el tipo exacto no importa; las referencias `@export` ganan.

## PostFx stack

```
PostFxStack (CanvasLayer, layer alta)
├── BloomPass.tscn     # BackBufferCopy + ColorRect + shader
└── GrainPass.tscn
```

- Orden de hijos = orden de composición.
- Gameplay **no** mete código en el shader de otro pass: tweenea el pass que corresponde.
- `mouse_filter = IGNORE`.
- Toggle: mostrar/ocultar el pass; no early-`return` en `fragment()` que deje el buffer en blanco.
- Fuente: Godot Shaders / Shadertoy portado. Ver [assets.md](assets.md).

## Actor con física

- Simulación en `_physics_process` (o `_integrate_forces` si es `RigidBody`).
- Look en hijos. Input en un catcher que usa InputMap y llama `apply_*` (en red: `MpInput` + `net.to_server`).
- Si el body es `RigidBody`, `MpAuthority.freeze_rigid_proxy` en proxies. No asumas RigidBody en todo actor.

## Preview en editor

`@export_tool_button` para regenerar geometría. La preview no toca las reglas de la partida ni arranca la red. Reglas completas: [SKILL.md](SKILL.md) §7.

## Tipo + escena

```
projectile.tscn
projectile_type.gd                 # class_name ProjectileType
fast/fast_projectile_type.tres     # { damage, speed, scene? }
slow/slow_projectile_type.tres
```

El arma exporta `ProjectileType`. Crea `type.scene` (o la escena única) y le asigna `type`.

## Variante con otra estructura

*New Inherited Scene* de la base (`tank.tscn` heredada de `enemy.tscn`): cambia la malla, suma una partícula, y el resto sigue a la base. Un nivel de herencia.

## Cuándo sí va en código

- Layers de física compartidas con las reglas.
- Autoridad multiplayer.
- Valores de **ronda** idénticos en host y guest.

Dónde vive cada número: regla 0. Lo que cambia al correr: variable del nodo. Comunicación (señales, bus `Events`, command, pool, spawner): [godot-code-quality](../godot-code-quality/SKILL.md).
