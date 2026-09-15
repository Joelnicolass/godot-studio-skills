# How to add a feature

Read `SKILL.md` first (Clean vs standard and MP type already chosen). Types: [resources.md](../godot-composition-first/resources.md). Tests: [godot-testing](../godot-testing/SKILL.md). Networking: `godot-mp-kit` **only** if there is MP (local = listen; online = dedicated). If no MP, the network block is N/A.

If an item does not apply, write “N/A”. Do not skip it silently.

## 1P (always)

1. [ ] Explicit product scope. If this is a studio RFC: the tech lead showed a tree + responsibilities **before** OK.
2. [ ] Is it a **type** (another projectile, enemy, item)? → Resource `.tres` + the same scene. Not a script per stats skin.
3. [ ] **Round** rules (lives, duration, layers): `MatchRules.tres`. Instance look: `@export`.
4. [ ] InputMap: semantic actions (`move_left`, `attack`), not `KEY_*`. Hold in `_physics_process`; gameplay one-shot in `_unhandled_input`.
5. [ ] `@export` / `%UniqueName` sockets for own nodes. Scene playable with F6.
6. [ ] Clean: testable rule with no scene? → `src/domain/` + test. Standard: is World bloating? → component, not invented domain.
7. [ ] Local FX; shaders from [Godot Shaders](https://godotshaders.com/shader/?orderby=date&order=DESC) / [Shadertoy](https://www.shadertoy.com). 2D sprites: does the user want MCP/art? If yes, references + [godot-animation](../godot-animation/SKILL.md). If the feature is **3D**: do they want Blender MCP? If yes, references + [assets.md](../godot-composition-first/assets.md). If no, placeholder. UI copy in the product language; code in English. HUD: do not invent look; `VISUAL.md` or refs.

## If networked (MpKit)

Only if they chose **local / Wi-Fi** or **online**. If no MP: N/A. Online: dedicated, see [dedicated.md](../godot-mp-kit/dedicated.md).

8. [ ] Local input distinguishes host vs guest (`rpc_id(1, …)`). `send_custom` tunnel only if `submit_*` / Resource is not enough.
9. [ ] Client → server RPC: allowlist, `any_peer` + sender vs `MpKit.peer_id_for(slot)`. No `call_local` that duplicates damage/spawn.
10. [ ] Simulation spawn: **host only** + `MultiplayerSpawner` **before** `add_child`.
11. [ ] Transform: `MultiplayerSynchronizer` (or `MpAuthority.ensure_sync`).
12. [ ] Collision / `queue_free` / points: server authority.
13. [ ] Guest does not mutate lives/trackers.
14. [ ] 1P: same code (`OfflineMultiplayerPeer`), **without** `host()`.
15. [ ] 2P: actors are not duplicated. Rejoin: explicit decision. Dedicated: no pawn for the server (`local_slot() == 0`).
16. [ ] The actor has no score RPC.

## Input pipeline

```
1. InputMap (actions), not scancodes
2. if not can_act(): return
3. if networked and MpAuthority.should_send_command():
      rpc_id(1, submit_action, payload)
   else:
      apply_action(payload)
```

The input node **does not** instantiate projectiles or add points. It only asks.

## Presentation

- Post-process, flashes: every peer. They do not go in the rules snapshot.
- One FX pass = one packed scene.
- HUD: `mouse_filter = IGNORE` except controls that swallow the pointer.
