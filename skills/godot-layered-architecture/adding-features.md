# How to add a feature (1P + LAN)

Read `SKILL.md` first (Clean vs standard already chosen). Networking: `godot-mp-kit`. Entity types: `godot-composition-first/resources.md`.

## Checklist

If an item does not apply, write “N/A”. Do not skip it silently.

1. [ ] Explicit product scope.
2. [ ] Is it a **type** (another bullet, enemy, power-up)? → Resource `.tres` + the same scene. Not a new script per stats skin.
3. [ ] **Round** rules (lives, duration, layers): one place (`GameConstants` / `MatchRules.tres`). Instance look: `@export` on the node.
4. [ ] Clean: rule testable without a scene? → `src/domain/` + test. Standard: is World bloating? → new node/component, not invented domain.
5. [ ] Local input distinguishes host vs guest (`rpc_id(1, …)`).
6. [ ] Client → server RPC: allowlist, `any_peer` + `get_remote_sender_id()` vs `MpKit.peer_id_for(slot)`. No `call_local` that duplicates damage/spawn.
7. [ ] Simulation spawn: **host only** + `MultiplayerSpawner` registered **before** `add_child`.
8. [ ] Transform: `MultiplayerSynchronizer` (or `MpAuthority.ensure_sync`).
9. [ ] Collision / `queue_free` / points: server authority.
10. [ ] Guest does not mutate score/lives/trackers.
11. [ ] 1P: same code (`OfflineMultiplayerPeer`).
12. [ ] 2P: actors are not duplicated.
13. [ ] Rejoin: explicit decision.
14. [ ] Local FX; UI copy in the product language; code in English.
15. [ ] The pawn has no score RPC.

## Input pipeline

```
Client (or 1P):
  1. Read local control
  2. if not can_act(local_slot()): return
  3. if MpAuthority.should_send_command():
        rpc_id(1, submit_X, payload)
     else:
        apply_on_host(payload)

Host:
  4. Validate sender == MpKit.peer_id_for(slot)
  5. Validate cooldown / ammo (session or Match node)
  6. Mutate physics or spawn (the type Resource decides damage/speed/scene)
  7. Points/lives: one state owner → events
  8. Local FX + discrete presentation RPC if needed
```

The input node **does not** instantiate projectiles or add points. It only asks.

## Presentation

- Post-process, flashes: each peer. They do not go in the score snapshot.
- Passes/FX as swappable nodes.
- HUD: `mouse_filter = IGNORE` except controls that should eat the pointer.
