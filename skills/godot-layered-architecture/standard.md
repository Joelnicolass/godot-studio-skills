# Standard path — scenes and scripts

Use **only** if the user chose standard (or the repo already declares it). Do not create `src/domain/` or a session facade “just in case”.

Composition, editor, Resources, reuse, small scripts, signals up / calls down still apply. Only the Clean split is omitted.

## Project shape (idiomatic Godot)

Scene + script **together**. Not a `scripts/` dump of 200 files disconnected from their `.tscn`.

```
scenes/                 # or res:// with folders by area
  actors/
    bullet.tscn + .gd   # one body; type arrives via Resource
    enemy.tscn + .gd
    pawn.tscn + .gd
  components/           # Health, Hitbox, Hurtbox, Trail (packed scenes)
  world/
  ui/
resources/
  bullets/              # bullet_data.gd + plasma.tres + spread.tres
  enemies/
  powerups/
addons/mp_kit/
```

Valid variant: folders per feature (`actors/bullet/`) with scene, script, and `.tres` inside. Invalid: a thousand-line `Player.gd` and `match weapon`.

## Small scripts and responsibilities

- One node = one job. Movement ≠ HP ≠ fire ≠ HUD.
- Extract a component (child scene) when the script goes from orchestrating to implementing two systems.
- Thin inheritance: `State extends Node`. Not `EliteFlyingEnemy extends FlyingEnemy extends Enemy`.
- The world **composes** spawners, camera, FX. It does not score in the same file that spawns.

Communication (Godot docs — scene organization):

- Signals **upward** (the child does not name the parent).
- Methods **downward** (the parent uses the child’s public API).
- Event autoload only between systems that are not parent-child.

Scenes as autonomous as possible: what they need, they own or receive via `@export`.

## Match state without domain

If there is score / lives / timer:

- A small `Match` node (child of the world, or autoload **only if** it survives scene change), not loose variables on every enemy.
- Type catalog is still a Resource, not `enum` + `match` on Match.
- With networking: the host is still the only one that mutates that state (MpKit skill). Standard does not let the client simulate.

## Autoloads

Yes: `GameEvents` (bus), audio, scene director, `MpKit`.  
No: `EnemyManager`, global `BulletFactory`, run inventory if it can live in the match tree.

## Extra checklist for this path

- [ ] Can each `.tscn` be understood opened alone?
- [ ] Are variants `.tres` (or another packed scene if the **structure** changes), not `if type`?
- [ ] Does the script fit a short read? If not, compose.
- [ ] Was `src/domain/` not introduced without the user asking for Clean?
