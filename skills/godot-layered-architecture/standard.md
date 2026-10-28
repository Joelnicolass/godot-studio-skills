# Standard path — scenes and scripts

Use **only** if the user chose standard (or the repo already declares it). Do not create `src/domain/` or a session facade “just in case”.

Still required: simple and predictable, composition, editor, shared Resources, reuse, one responsibility per script, signals up / calls down ([godot-code-quality](../godot-code-quality/SKILL.md)).

## Project shape

Scene + script **together**, with its `.tres` files and art in the same entity folder when it helps.

```
scenes/
  actors/
    projectile/         # projectile.tscn + .gd + projectile_data.gd + projectile_fast.tres + projectile_slow.tres
    enemy/              # enemy.tscn + .gd + sprites
    actor/
  components/           # Health, Hitbox, Hurtbox (packed scenes)
  world/
  ui/
events.gd               # Events autoload (signals only), if needed
addons/mp_kit/
```

A separate data folder (`resources/<family>/`) only for types that several scenes share. Valid variant: folders per feature. Invalid: a thousand-line `Player.gd` and `match weapon`.

## Autonomous scenes

Each `.tscn` should open with **F6** and work (or warn). Docs: [scene organization](https://docs.godotengine.org/en/stable/tutorials/best_practices/scene_organization.html).

- Zero environment deps. What is missing, the parent injects: `@export var health: Health`, Callable, or Node.
- Signals in the **past tense** and typed. The **parent** does `child.died.connect(...)`. The child does not call `get_parent().on_died()`.
- Internals of *this* scene: `%UniqueName` (`%Sprite`). Between scenes: `@export` socket, not `get_node("../../Audio")`.
- If a required socket is empty: `@tool` + `_get_configuration_warnings()`.
- Relational, not spatial: should deleting the parent delete the child? If not, sibling. Relative position: `RemoteTransform2D` / `RemoteTransform3D`.
- `Main` (entry) → `World` (levels replace) + `GUI` (sibling; does not die with the level).

## One responsibility per script

- One node = one job. Movement ≠ HP ≠ shooting ≠ HUD.
- Extract a child packed scene when the script implements two systems.
- Shallow inheritance: `State extends Node`. Not `EliteFlyingEnemy extends FlyingEnemy extends Enemy`.
- The world **composes** spawners, camera, FX. It does not score in the same file that spawns.
- No line cap: a cohesive 400-line script is fine; two systems in 120 lines are not.

## Match state without domain

- Small `Match` node (child of the world). Autoload **only if** it survives scene change.
- Type catalog = Resource, not `enum` + `match` on Match.
- If networked: only the host mutates that state.

## Autoloads

See the table in `SKILL.md`. Yes: the `Events` bus (typed signals only), `MpKit`.  
No: `EnemyManager`, global projectile factory, run inventory if it can live in the tree. Audio: `AudioStreamPlayer` / `class_name` component in scene; sound autoload only if it is an isolated bus.

## Extra checklist

- [ ] Does the scene run with F6? Deps via `@export`? Warning if the socket is missing?
- [ ] Shared variants = `.tres` (or packed scene if the **structure** changes)? A value of a single scene = `@export`?
- [ ] Does changing a number open 2 files at most?
- [ ] Was `src/domain/` introduced without asking for Clean?
