# FEATURES — MpKit Example

**Product (from PRD):** Godot 4.7 demo teaching MpKit + skills (standard, composition, Resources) with 1P, listen-server, and dedicated; 2D and 3D matches with placeholders. Not a real game.

IDs are **permanent**. Do not renumber.

## Summary (recounted from the list)

| Priority | Count |
|----------|-------|
| Must have | 16 |
| Should have | 2 |
| Could have | 0 |
| Won't have | 5 |
| **Total** | **23** (F1–F23) |

| Category | Must | Should | Could | Won't | IDs |
|----------|------|--------|-------|-------|-----|
| Lobby / flow | 5 | 0 | 0 | 0 | F1, F2, F9, F10, F16 |
| 2D world | 2 | 0 | 0 | 0 | F3, F4 |
| 3D world | 2 | 0 | 0 | 0 | F6, F7 |
| Composition / data | 2 | 0 | 0 | 0 | F5, F8 |
| Net | 5 | 0 | 0 | 0 | F11–F15 |
| Guide | 0 | 2 | 0 | 0 | F17, F18 |
| Out of scope | 0 | 0 | 0 | 5 | F19–F23 |

## Must

- **F1 Lobby** — Boot UI; dedicated process hides it. Copy via `DemoCopy`.
- **F2 Play solo** — No `host()`. Offline peer. Load current `world_kind`.
- **F3 Match 2D** — Placeholders, `MpSpawner` → `Actors`, `MpWorldReady` after spawner, F6.
- **F4 Pawn 2D** — `CharacterBody2D`, `PlaceholderTexture2D`, InputMap, `MpReplicate`.
- **F5 ActorLook** — Resource + `look_a`…`look_d.tres`. No `if kind`.
- **F6 Match 3D** — Floor `BoxMesh`, camera, light, same spawn contract as F3.
- **F7 Pawn 3D** — `CharacterBody3D` + `BoxMesh`. F6 adds preview camera/floor.
- **F8 DemoMatch** — Shared spawn. Listen host pawn in `_ready`. Clients on `client_world_ready`. No pawn for slot 0.
- **F9 Host LAN** — `MpKit.host()`. Host is a player. Match starts immediately.
- **F10 Join** — `MpLan` IPv4 then `join`. Late join `load_world_to`.
- **F11 submit/apply** — `should_send_command` → `rpc_id(1)`. Validate sender vs slot. No `call_local`.
- **F12 MpReplicate** — Server authority, sync transform.
- **F13 Dedicated** — `MpBoot` / `host_dedicated`. `local_slot()==0`. Starts on first client.
- **F14 Emote tunnel** — Channel `emote`. Reflect only `from_peer != 1`. Listen host broadcasts.
- **F15 Snapshot HUD** — Server ticks `elapsed`; client applies snapshot and does not tick.
- **F16 Leave** — `leave` + boot. `server_lost` / `join_failed`. `peer_left` frees the pawn.

## Should

- **F17 README** — How to run 1P, LAN, dedicated, F6, re-copy addon.
- **F18 Product artifacts** — PRD, FEATURES, RULES, RFCs, reviews in `example/`.

## Could

None.

## Won't

- **F19** Real game loop (score/lives/weapons).
- **F20** Steam / WebRTC / matchmaking.
- **F21** Prediction / advanced interpolation.
- **F22** Production art.
- **F23** Automated tests.

## Autocheck

Must 16, Should 2, Could 0, Won't 5. Category table 5+2+2+2+5+2+5 = 23. IDs match RFCS.md.
