# Patrones de composición (ejemplar Godot 4)

## StateMachine

Nodo padre con `@export var initial_state: State`. Hijos = estados. `transition(&"Aiming")` busca por nombre de nodo.

- `State.enter` / `exit` / `update`.
- El estado puede pedir el actor con `machine.get_parent()`.
- No guardar score en un estado.

## PostFx stack

```
PostFxStack (CanvasLayer, layer alta)
├── RipplePass.tscn    # BackBufferCopy + ColorRect + ripple.gdshader
└── CrtPass.tscn       # BackBufferCopy + ColorRect + crt.gdshader
```

- Orden de hijos = orden de composición.
- Un pickup de gameplay **no** mete código en el shader CRT: el mundo llama `RipplePass.play()` (tween de un uniform).
- `mouse_filter = IGNORE` en todo el stack.
- Toggle: mostrar/ocultar el pass; no early-`return` en `fragment()` que deje el buffer en blanco.

## Pawn inercial

- Física y wrap en el body (`_integrate_forces`).
- Look (color, trail, aim preview) en hijos, tinted desde un método del contenedor.
- Input en un catcher externo que llama `apply_*` o `submit_*`.

## Preview en editor

`@export_tool_button` para regenerar geometría (anillos, meshes). El preview no escribe `GameConstants` ni arranca ENet.

## Plantilla Resource + escena

```
bullet.tscn          # RigidBody/Area + script delgado
plasma.tres          # BulletData { damage, speed, scene? }
spread.tres
```

El arma exporta `BulletData`. Spawnea `data.scene` (o la escena única) y asigna `data`. Guía: [resources.md](resources.md).

## Cuándo sí va en código

- Layers de física compartidas con las reglas (máscaras que el anti-cheat asume).
- Autoridad multiplayer (`claim_server`, freeze del proxy).
- Valores de **ronda** idénticos en host y guest (duración, vidas).

Tipos de contenido: Resource. Look de instancia: escena. Runtime: nodo.
