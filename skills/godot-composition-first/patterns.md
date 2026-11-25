# Composition patterns (Godot 4)

## StateMachine

Addon `fsm_kit`: parent `FsmMachine` with `@export var initial_state: FsmState`. Children = states. `transition(&"Hurt")` looks up by node name.

- `FsmState.enter` / `exit` / `update` / `physics_update`.
- The actor is **injected**: `@export var actor: Node`. Not `machine.get_parent()` as API.
- Do not store score in a state.
- Command: `/add-state-machine`.

2D platformer (coyote, buffer): addon `plat_kit` / `/add-platformer-2d`. The motor is **another** child.

## Health / Hitbox / Hurtbox

`Health` (`class_name` node): if the entity has a type, `max_hp` comes from the type (`health.setup(type.max_hp)`) and the scene does not override it in the `Health` inspector; if it has no type, it is the `@export` on `Health`. Never both. Current `hp` on the node. `signal damaged(amount: int)` / `signal died`. The parent orchestrates (animation, `queue_free`).

Hitbox / Hurtbox = `Area2D` packed scenes. Optional: `"hurtbox"` group if the exact type does not matter; `@export` references win.

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
- Look on children. Input on a catcher that uses InputMap and calls `apply_*` (on a network: `MpInput` + `net.to_server`).
- If the body is a `RigidBody`, `MpAuthority.freeze_rigid_proxy` on proxies. Do not assume RigidBody on every actor.

## Editor preview

`@export_tool_button` to regenerate geometry. The preview does not touch the match rules or start the network. Full rules: [SKILL.md](SKILL.md) §7.

## Type + scene

```
projectile.tscn
projectile_type.gd                 # class_name ProjectileType
fast/fast_projectile_type.tres     # { damage, speed, scene? }
slow/slow_projectile_type.tres
```

The weapon exports `ProjectileType`. It spawns `type.scene` (or the single scene) and assigns `type`.

## A variant with another structure

*New Inherited Scene* of the base (`tank.tscn` inherited from `enemy.tscn`): it swaps the mesh, adds a particle, and the rest follows the base. One level of inheritance.

## When it does belong in code

- Physics layers shared with the rules.
- Multiplayer authority.
- **Round** values identical on host and guest.

Where each number lives: rule 0. What changes at runtime: a variable on the node. Communication (signals, `Events` bus, command, pool, spawner): [godot-code-quality](../godot-code-quality/SKILL.md).
