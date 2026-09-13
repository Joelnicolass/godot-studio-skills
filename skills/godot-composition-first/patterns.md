# Composition patterns (Godot 4)

## StateMachine

Parent node with `@export var initial_state: State`. Children = states. `transition(&"Aiming")` looks up by node name.

- `State.enter` / `exit` / `update`.
- The state may ask for the actor with `machine.get_parent()`.
- Do not store score on a state.

## PostFx stack

```
PostFxStack (CanvasLayer, high layer)
├── RipplePass.tscn    # BackBufferCopy + ColorRect + ripple.gdshader
└── CrtPass.tscn       # BackBufferCopy + ColorRect + crt.gdshader
```

- Child order = composition order.
- A gameplay pickup **does not** put code in the CRT shader: the world calls `RipplePass.play()` (tween a uniform).
- `mouse_filter = IGNORE` on the whole stack.
- Toggle: show/hide the pass; no early `return` in `fragment()` that leaves the buffer blank.

## Physics pawn

- Physics and wrap on the body (`_integrate_forces` or `_physics_process`).
- Look (color, trail, aim preview) on children, tinted from a container method.
- Input on an external catcher that calls `apply_*` or `submit_*`.

## Editor preview

`@export_tool_button` to regenerate geometry (rings, meshes). Preview does not write `GameConstants` or start ENet.

## Resource template + scene

```
bullet.tscn          # RigidBody/Area + thin script
plasma.tres          # BulletData { damage, speed, scene? }
spread.tres
```

The weapon exports `BulletData`. It spawns `data.scene` (or the single scene) and assigns `data`. Guide: [resources.md](resources.md).

## When it does belong in code

- Physics layers shared with the rules (masks anti-cheat assumes).
- Multiplayer authority (`claim_server`, proxy freeze).
- **Round** values identical on host and guest (duration, lives).

Content types: Resource. Instance look: scene. Runtime: node.
