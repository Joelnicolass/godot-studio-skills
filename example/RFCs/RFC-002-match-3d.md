# RFC-002 — 3D match and shared spawn

**Complexity:** Medium  
**Predecessors:** RFC-001  
**Successors:** RFC-003  
**Features:** F6, F7, F8

**Type:** Godot game. Omitted: SQL, auth, browsers.

## Summary

Same fantasy in 3D (box placeholder + floor). Extract 1P spawn into `DemoMatch` used by both worlds. Lobby 2D/3D toggle works.

`DemoMatch` exports: `pawn_scene`, `actors`, `spawn_points`, `looks`. 3D `try_move` maps Vector2 input to XZ plus gravity. F6 on the 3D pawn adds a preview camera + floor if it is the current scene.

## Acceptance

1. `match_3d.tscn` and `pawn_3d.tscn` exist with `BoxMesh` placeholders, no `.glb`.
2. Lobby toggle sets `NetGlue.world_kind`. Play solo loads the matching scene.
3. `DemoMatch` is in **both** matches. 1P spawn is not duplicated in two long scripts.
4. `Marker2D` / `Marker3D` define positions.
5. F6 `pawn_3d` is controllable. F6 `match_3d` shows floor + pawn.
6. `MpSpawner.spawn_path` points at `Actors` (not `.`).
7. 3D gravity: pawn does not fall forever (floor + `move_and_slide`).

Manual: play solo 2D and 3D. F6 all four scenes (matches + pawns).
