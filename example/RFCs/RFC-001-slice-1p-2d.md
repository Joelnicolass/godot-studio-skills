# RFC-001 — 1P 2D slice

**Complexity:** Medium  
**Predecessors:** none  
**Successors:** RFC-002  
**Features:** F1, F2, F3, F4, F5

**Type:** Godot game. Omitted: SQL, auth, browsers.

## Summary

Lobby + play solo + a 2D match with a placeholder pawn that moves. Do not call `MpKit.host()` on the 1P path. Copy MpKit because 1P is `leave()` + `OfflineMultiplayerPeer`.

File list, contracts (`NetGlue.play_solo`, `ActorLook`, `try_move`/`apply_move`), and UI rules match the implementation in `example/`. `try_move` may already branch on `MpAuthority.should_send_command()` so RFC-003 does not rewrite the pawn.

## Acceptance

1. `./install.sh --addon-only example` leaves `example/addons/mp_kit` and `.vscode` snippets.
2. `project.godot`: `MpKit` before `NetGlue`; plugin enabled; main scene boot; InputMap `move_*` + `emote`.
3. F5 opens the lobby. Play solo loads `match_2d.tscn` and spawns slot 1 with `look_a`.
4. WASD/arrows move the pawn. No scancode `Input.is_key_pressed`.
5. `ActorLook` + four `.tres`. No type-string branches on the pawn.
6. F6 on `pawn_2d.tscn` and `match_2d.tscn` works offline.
7. Visual = `PlaceholderTexture2D`.
8. `AGENTS.md` points at `RULES.md`.
9. `DemoCopy` holds product-language copy.
10. 1P does not call `MpKit.host()`.

Manual test: play solo, move, F6. No automated suite (F23).
