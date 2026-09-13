# Composition patterns (Godot 4)

## StateMachine

Parent with `@export var initial_state: State`. Children = states. `transition(&"Hurt")` looks up by node name.

- `State.enter` / `exit` / `update`.
- The actor is **injected**: `@export var actor: Node` (the parent assigns it). Not `machine.get_parent()` as API.
- Do not store score in a state.

## Health / Hitbox / Hurtbox

`Health` (`class_name` node): `max_hp` may come from the type Resource; current `hp` on the node. `signal damaged(amount: int)` / `signal died`. The parent orchestrates (animation, `queue_free`).

Hitbox / Hurtbox = `Area2D` packed scenes. Optional: `"hurtbox"` group if the exact type does not matter; `@export` sockets win.

## PostFx stack

```
PostFxStack (CanvasLayer, high layer)
├── BloomPass.tscn     # BackBufferCopy + ColorRect + shader
└── GrainPass.tscn
```

- Child order = composition order.
- Gameplay **does not** put code in another pass’s shader: it tweens the matching pass.
- `mouse_filter = IGNORE`.
- Toggle: show/hide the pass; no early-`return` in `fragment()` that leaves the buffer blank.
- Source: Godot Shaders / ported Shadertoy. See [assets.md](assets.md).

## Actor with physics

- Simulation in `_physics_process` (or `_integrate_forces` if it is a `RigidBody`).
- Look on children. Input on a catcher that uses InputMap and calls `apply_*` / `submit_*`.
- If the body is a `RigidBody`, `MpAuthority.freeze_rigid_proxy` on proxies. Do not assume RigidBody on every actor.

## Editor preview

`@export_tool_button` to regenerate geometry. Preview does not write `MatchRules` or start ENet.

## Resource template + scene

```
projectile.tscn
projectile_fast.tres    # ProjectileData { damage, speed, scene? }
projectile_slow.tres
```

The weapon exports `ProjectileData`. It spawns `data.scene` (or the single scene) and assigns `data`.

## When it does belong in code

- Physics layers shared with the rules.
- Multiplayer authority.
- **Round** values identical on host and guest.

Types: Resource. Instance look: scene. Runtime: node.
