# Standard path — scenes and scripts

Use **only** if the user chose standard (or the repo already declares it). Do not create `src/domain/` or a session facade “just in case”.

Still required: composition, editor, Resources, reuse, small scripts, signals up / calls down.

## Project shape

Scene + script **together**.

```
scenes/
  actors/
    projectile.tscn + .gd
    enemy.tscn + .gd
    actor.tscn + .gd
  components/           # Health, Hitbox, Hurtbox (packed scenes)
  world/
  ui/
resources/
  projectiles/          # projectile_data.gd + projectile_fast.tres + projectile_slow.tres
  enemies/
addons/mp_kit/
```

Valid variant: folders per feature. Invalid: a thousand-line `Player.gd` and `match weapon`.

## Autonomous scenes

Each `.tscn` should open with **F6** and work (or warn). Docs: [scene organization](https://docs.godotengine.org/en/stable/tutorials/best_practices/scene_organization.html).

- Zero environment deps. What is missing, the parent injects: `@export var health: Health`, Callable, or Node.
- Signals in the **past tense** and typed. The **parent** does `child.died.connect(...)`. The child does not call `get_parent().on_died()`.
- Internals of *this* scene: `%UniqueName` (`%Sprite`). Between scenes: `@export` socket, not `get_node("../../Audio")`.
- If a required socket is empty: `@tool` + `_get_configuration_warnings()`.
- Relational, not spatial: should deleting the parent delete the child? If not, sibling. Relative position: `RemoteTransform2D` / `RemoteTransform3D`.
- `Main` (entry) → `World` (levels replace) + `GUI` (sibling; does not die with the level).

## Small scripts

- One node = one job. Movement ≠ HP ≠ shooting ≠ HUD.
- Extract a child packed scene when the script implements two systems.
- Shallow inheritance: `State extends Node`. Not `EliteFlyingEnemy extends FlyingEnemy extends Enemy`.
- The world **composes** spawners, camera, FX. It does not score in the same file that spawns.

## Match state without domain

- Small `Match` node (child of the world). Autoload **only if** it survives scene change.
- Type catalog = Resource, not `enum` + `match` on Match.
- If networked: only the host mutates that state.

## Autoloads

See the table in `SKILL.md`. Yes: event bus, `MpKit`.  
No: `EnemyManager`, global projectile factory, run inventory if it can live in the tree. Audio: `AudioStreamPlayer` / `class_name` component in scene; sound autoload only if it is an isolated bus.

## Extra checklist

- [ ] Does the scene run with F6? Deps via `@export`? Warning if the socket is missing?
- [ ] Variants = `.tres` (or packed scene if the **structure** changes)?
- [ ] Does the script fit in a short read?
- [ ] Was `src/domain/` introduced without asking for Clean?
