# How to add a feature

Read `SKILL.md` first (Clean vs standard and MP type already chosen). Types: [resources.md](../godot-composition-first/resources.md). Tests: [godot-testing](../godot-testing/SKILL.md). Networking: `godot-mp-kit` **only** if there is MP (local = listen; online = dedicated). If no MP, the network block is N/A.

If an item does not apply, write “N/A”. Do not skip it silently.

## 1P (always)

1. [ ] Explicit product scope. If this is a studio RFC: the tech lead showed a tree + responsibilities **before** OK.
2. [ ] Is it a **type** with variants (another projectile, enemy, item)? → Resource `.tres` + the same scene. Not a script per stats skin. Does a single scene use it? → an `@export` on the node, no `.tres`.
3. [ ] **Round** rules (lives, duration, layers): `@export` on the `Match` node (or `MatchRules.tres` if several pieces read it). Instance look: `@export`. Changing any number of the feature opens 2 files at most.
4. [ ] InputMap: semantic actions (`move_left`, `attack`), not `KEY_*`. Hold in `_physics_process`; gameplay one-shot in `_unhandled_input`.
5. [ ] `@export` / `%UniqueName` sockets for own nodes. Scene playable with F6. FSM: addon `fsm_kit` if there are states. 2D platformer: `plat_kit` (coyote/buffer), not a bare `is_on_floor()`. RTS selection / orders: `rts_kit`, not a hand-made box select. Scattered props and their navmesh: `prop_kit`, not props placed by hand by the thousand or one region re-baked whole.
6. [ ] Clean: testable rule with no scene? → `src/domain/` + test. Standard: is World bloating? → component, not invented domain.
7. [ ] Local FX; shaders from [Godot Shaders](https://godotshaders.com/shader/?orderby=date&order=DESC) / [Shadertoy](https://www.shadertoy.com). 2D sprites: does the user want MCP/art? If yes, references + [godot-animation](../godot-animation/SKILL.md). If the feature is **3D**: do they want Blender MCP? If yes, references + [assets.md](../godot-composition-first/assets.md). If no, placeholder. UI copy in the product language; code in English. HUD: do not invent look; `VISUAL.md` or refs.

## If networked (MpKit)

Only if they chose **local / Wi-Fi** or **online**. If no MP: N/A. Online: dedicated, see [dedicated.md](../godot-mp-kit/dedicated.md).

8. [ ] The player's input: an `MpInput` child; the server reads `input.get_vector(...)` / `is_action_just_pressed(...)` (or `mp_move(keys, delta)` with prediction). A one-off order: `net.to_server(&"x", args)` → `mp_sv_x(args)`. `send_custom` tunnel only if those are not enough.
9. [ ] Only the owner asks for its actor's `mp_sv_*` (`MpActor › Owner › callers`); validate what they ask inside. No hand-written `@rpc` unless the nodes do not cover the case (note why).
10. [ ] Simulation spawn: **the server only**, with `MpSpawner.spawn_actor(scene, {...})` (the scene in *Extra Scenes*).
11. [ ] What looks the same for everyone: ticked in `MpActor › Sync` (not a hand-built `MultiplayerSynchronizer`).
12. [ ] Collision / `queue_free` / points: server authority (`net.is_authority()`).
13. [ ] The client does not mutate lives or score: `Mp.state()` is written by the server.
14. [ ] 1P: same code (`Mp.play_solo()`), **without** `host()`.
15. [ ] 2P: actors are not duplicated. Rejoin: explicit decision. Dedicated: no pawn for the server (`local_slot() == 0`).
16. [ ] The actor has no score RPC.

## Input pipeline

```
1. InputMap (actions), not scancodes
2. if not can_act(): return
3. No network: the actor reads Input and applies.
   With MpKit: the actor's MpInput sends the owner's actions; the server reads them
   (input.is_action_just_pressed(...)) and applies. A one-off order: net.to_server(&"use", payload).
```

The input node **does not** instantiate projectiles or add points. It only asks.

## Presentation

- Post-process, flashes: every peer. They do not go in the rules snapshot.
- One FX pass = one packed scene.
- HUD: `mouse_filter = IGNORE` except controls that swallow the pointer.
