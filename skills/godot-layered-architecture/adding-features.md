# How to add a feature

Read `SKILL.md` first (the size and the MP type are already chosen). Where each number lives: rule 0 of [godot-code-quality](../godot-code-quality/SKILL.md). Types: [resources.md](../godot-composition-first/resources.md). Tests: [godot-testing](../godot-testing/SKILL.md). Networking: `godot-mp-kit` **only** if there is MP (local = listen; online = dedicated). If no MP, the network block is N/A.

If an item does not apply, write “N/A”. Do not skip it silently.

## 1P (always)

1. [ ] Explicit product scope. If this is a studio RFC: the tech lead showed a tree + responsibilities **before** OK.
2. [ ] Is it a **type** with variants (another projectile, enemy, item)? Other numbers: another `_type.tres` and the same scene. Another structure or other art: a scene inherited from the base (*New Inherited Scene*), one level only. Not a script per variant.
3. [ ] Each design number has **one** owner (the type's `.tres`, or the scene root) and changing it opens 2 files at most. Match rules: `@export` on `match.tscn`, or `match_config.tres`.
4. [ ] `docs/tuning.md` has a row for each new design knob (I want to change → file → node → property).
5. [ ] Each new `@export` has a `##`, a range, and a unit. Each new file is in its folder, with its suffix.
6. [ ] InputMap: actions named after what they do (`move_left`, `attack`), not `KEY_*`. Hold in `_physics_process`; a gameplay press in `_unhandled_input`.
7. [ ] `@export` / `%UniqueName` references for own nodes. Scene playable with F6, and it looks in the editor the way it does in the game. FSM: addon `fsm_kit` if there are states. 2D platformer: `plat_kit` (coyote/buffer), not a bare `is_on_floor()`. RTS selection / orders: `rts_kit`, not a hand-made box select. Scattered props and their navmesh: `prop_kit`, not props placed by hand by the thousand or one region re-baked whole.
8. [ ] A rule that deserves a test without a scene? A pure core next to the node + a test. Is the world bloating? A component, not a new layer.
9. [ ] Local effects; shaders from [Godot Shaders](https://godotshaders.com/shader/?orderby=date&order=DESC) / [Shadertoy](https://www.shadertoy.com). 2D sprites: does the user want MCP/art? If yes, references + [godot-animation](../godot-animation/SKILL.md). If the feature is **3D**: do they want Blender MCP? If yes, references + [assets.md](../godot-composition-first/assets.md). If no, placeholder. UI text in the translation file, in the product language; code in English. HUD: do not invent look; `VISUAL.md` or refs.

## If networked (MpKit)

Only if they chose **local / Wi-Fi** or **online**. If no MP: N/A. Online: dedicated, see [dedicated.md](../godot-mp-kit/dedicated.md).

10. [ ] The player's input: an `MpInput` child; the server reads `input.get_vector(...)` / `is_action_just_pressed(...)` (or `mp_move(keys, delta)` with prediction). A one-off order: `net.to_server(&"x", args)` → `mp_sv_x(args)`. `send_custom` tunnel only if those are not enough.
11. [ ] Only the owner asks for its actor's `mp_sv_*` (`MpActor › Owner › callers`); validate what they ask inside. No hand-written `@rpc` unless the nodes do not cover the case (note why).
12. [ ] Simulation spawn: **the server only**, with `MpSpawner.spawn_actor(scene, {...})` (the scene in *Extra Scenes*).
13. [ ] What looks the same for everyone: ticked in `MpActor › Sync` (not a hand-built `MultiplayerSynchronizer`).
14. [ ] Collision / `queue_free` / points: server authority (`net.is_authority()`).
15. [ ] The client does not mutate lives or score: `Mp.state()` is written by the server.
16. [ ] 1P: same code (`Mp.play_solo()`), **without** `host()`.
17. [ ] 2P: actors are not duplicated. Rejoin: explicit decision. Dedicated: no pawn for the server (`local_slot() == 0`).
18. [ ] The actor has no score RPC.

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
