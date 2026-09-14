# RFC-004 — Dedicated, tunnel, snapshot, guide

**Complexity:** Medium  
**Predecessors:** RFC-003  
**Successors:** none  
**Features:** F13, F14, F15, F17, F18

**Type:** Godot game. Omitted: SQL, auth, browsers.  
Online glue is this RFC, not RFC-001.

## Summary

Dedicated server (same project), emote via `Dictionary` tunnel, `elapsed` snapshot, HUD, README. Product artifacts (F18) stay in the tree.

Dedicated: `MpBoot.is_dedicated_process()` → `configure` with `emote` allowlist → `host_dedicated()` → on first `peer_joined`, start match. User args `--dedicated`, `--world=2d|3d`, `--mp-port=`. Do not treat `--headless` alone as dedicated.

Tunnel: client/1P `pipe.send`; listen host `pipe.broadcast`; glue reflects only `from_peer != 1`. Snapshot ~5 Hz; client applies and does not tick.

Kit bugfixes (spawner `.` warning, `broadcast_custom` re-entrancy, tunnel docs) live in the canonical addon, then re-copy.

## Acceptance

1. `godot --headless --path example -- --dedicated` binds, no lobby. First Join client sees the match. Dedicated process has **no** pawn (`local_slot()==0`).
2. `--world=3d` loads the 3D match.
3. `emote` allowlist. E on a client is visible on the other. Listen host emote replicates.
4. `broadcast_custom` from glue does not recurse forever.
5. HUD shows mode, elapsed, `occupied_slots()`, last tunnel packet. Dedicated copy is “no local player”, not “player 1”.
6. Client does not tick `elapsed`.
7. `example/README.md` documents 1P, LAN, dedicated, F6, addon re-copy.
8. F18 artifacts remain.
9. No score, Steam, or prediction (F19–F21).

Manual: dedicated headless + 2 clients. Emote. LAN host emote. HUD elapsed.
