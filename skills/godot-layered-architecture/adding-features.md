# How to add a feature

Read `SKILL.md` first (Clean vs standard already chosen). Types: [resources.md](../godot-composition-first/resources.md). Tests: [godot-testing](../godot-testing/SKILL.md). Networking: `godot-mp-kit` **only if MpKit is present**.

If an item does not apply, write “N/A”. Do not skip it silently.

## 1P (always)

1. [ ] Explicit product scope.
2. [ ] Is it a **type** (another projectile, enemy, item)? → Resource `.tres` + the same scene. Not a script per stats skin.
3. [ ] **Round** rules (lives, duration, layers): `MatchRules.tres`. Instance look: `@export`.
4. [ ] InputMap: semantic actions (`move_left`, `attack`), not `KEY_*`. Hold in `_physics_process`; gameplay one-shot in `_unhandled_input`.
5. [ ] `@export` / `%UniqueName` sockets for own nodes. Scene playable with F6.
6. [ ] Clean: testable rule with no scene? → `src/domain/` + test. Standard: is World bloating? → component, not invented domain.
7. [ ] Local FX; UI copy in the product language; code in English.

## If networked (MpKit)

8. [ ] Local input distinguishes host vs guest (`rpc_id(1, …)`).
9. [ ] Client → server RPC: allowlist, `any_peer` + sender vs `MpKit.peer_id_for(slot)`. No `call_local` that duplicates damage/spawn.
10. [ ] Simulation spawn: **host only** + `MultiplayerSpawner` **before** `add_child`.
11. [ ] Transform: `MultiplayerSynchronizer` (or `MpAuthority.ensure_sync`).
12. [ ] Collision / `queue_free` / points: server authority.
13. [ ] Guest does not mutate lives/trackers.
14. [ ] 1P: same code (`OfflineMultiplayerPeer`), **without** `host()`.
15. [ ] 2P: actors are not duplicated. Rejoin: explicit decision.
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
