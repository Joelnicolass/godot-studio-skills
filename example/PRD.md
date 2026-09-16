# PRD — MpKit Example

**Product type:** Godot game (framework demo / guide). The file is named `PRD.md` because the rest of the flow looks for it; the content is a **short GDD**.

**Controls omitted (do not apply):** business model, SQL/injection, user auth, responsive web, REST APIs, marketing personas, compliance, web WCAG, SaaS cloud infra. Instead: loop, feel, types-as-data, what is out of the slice.

**Decisions already taken (do not re-interview):**

| Topic | Choice |
|-------|--------|
| Architecture | **Standard Godot** (`scenes/` + script next to the scene). Not Clean, no `src/domain/`. |
| Multiplayer | **All three modes** in one demo: 1P (no `host()`), local/Wi-Fi (`MpKit.host()`), online (`MpKit.host_dedicated()` + `join`). |
| Dimension | **2D and 3D** (two match scenes). |
| Art | **Placeholders** (`PlaceholderTexture2D`, `BoxMesh`). No Aseprite, no Blender MCP. |
| Tests | Not requested. No GUT/GdUnit4 in this slice. |

**Reference implementation (extracted from):** the canonical addon `../addons/mp_kit/` in this repo. The empty project already exists at `example/project.godot` (Godot **4.7**, mobile renderer, Jolt 3D).

---

## Summary

A minimal playable demo that teaches **MpKit** and the studio skills (standard architecture, composition, Resources, host-authoritative) **without being a real game**. Lobby, a placeholder pawn that moves, an emote on the `Dictionary` tunnel, and the same tree for 1P, LAN listen-server, and dedicated.

Value: clone the kit, open `example/`, follow this PRD → RFCs → code, and see where the addon ends and title glue begins.

## Goals

1. Play solo (F5) and move a 2D or 3D pawn in under a minute.
2. Two instances on one machine: **Host LAN + Join** (`127.0.0.1`) with replicated pawns (not duplicated).
3. `godot --headless --path example -- --dedicated` + a client shows **online** (dedicated, peer 1 is not a player).
4. No score, title copy, or round rules inside `addons/mp_kit`.
5. Relevant packed scenes run with **F6** (or warn). Look types = `.tres`, not `if kind`.

## Scope

### In

- Lobby: Play solo, Host LAN, Join (IP), 2D/3D toggle, local IP, Leave.
- Match 2D and 3D with placeholders, `MpSpawner`, `MpWorldReady`, per-slot spawn.
- Pawn 2D / 3D: host-authoritative `submit_*` / `apply_*`, `MpReplicate`, look Resource.
- `MpCustomPipe` channel `emote` (server decides broadcast; no auto-reflect).
- Minimal snapshot (`elapsed`); the client does not tick the clock.
- Dedicated boot via `MpBoot`.
- UI copy in the product language (`DemoCopy`); code IDs in English.
- Demo README.

### Out (Won't)

- A real game (score, lives, win/lose, weapons, enemies, levels).
- Steam, WebRTC, matchmaking, NAT traversal beyond public IP + UDP.
- Advanced interpolation, client prediction, lag compensation.
- Production art, custom shaders, character AnimationPlayer.
- Clean Architecture / `GameSession` autoload / `src/domain/`.
- Automated tests (not requested).
- VPS export presets in this repo (headless command is documented).

## Audience

1. A **Godot developer** copying MpKit into a title who needs a reference tree, not a paper.
2. A **Cursor agent / human** following skills + commands: this project is the visible PRD → RFC result.

## Functional requirements

MoSCoW detail is in `FEATURES.md`.

| Priority | Capability |
|----------|------------|
| Must | Lobby + 1P + 2D/3D match + placeholder pawns + InputMap + look Resources |
| Must | Listen-server: host is a player (slot 1); spawn handshake; `submit_move` |
| Must | Dedicated: `local_slot() == 0`, no server pawn; clients `join` |
| Must | Emote tunnel + elapsed snapshot + mode/slots HUD |
| Must | Disconnect: `server_lost` / `join_failed` return to lobby |
| Should | README + product artifacts as a guide |
| Won't | See Scope / Out |

## Non-functional

- Godot **4.7** (`project.godot`). GDScript. 3D physics: Jolt.
- Autoload: `MpKit` **before** `NetGlue`. MpKit plugin enabled.
- Default port **7777**; override `MpBoot.user_value("mp-port", "7777")`.
- Max **4** players.
- Copy the kit with `./install.sh --addon-only example`; do not fork.
- UI in English on `main`; Spanish on `release/spanish`.
- No secrets; no network beyond ENet UDP.

## User journeys

1. **1P:** open project → F5 → Play solo → 2D or 3D → WASD/arrows → E emote → Leave.
2. **LAN:** instance A Host LAN → instance B Join `127.0.0.1` → two tinted pawns → move → emote replicates.
3. **Dedicated:** `godot --headless --path example -- --dedicated` → client Join → server has no pawn.
4. **F6:** `pawn_2d.tscn` / `match_2d.tscn` run offline.

## Feel

- Fixed 2D camera / simple 3D view on the origin. No title juicy.
- How-to-fail: bad IP, busy port, lost server → lobby message, no crash.
- Session: minutes. `elapsed` is not a win timer.

## Platforms and input

Desktop. Keyboard. Actions: `move_left`, `move_right`, `move_up`, `move_down`, `emote`.

## Success metrics

- All three modes demo on one machine.
- A reader can tell `addons/mp_kit` (transport) from `glue/` + `scenes/` (game).
- No `if look_id ==` and no score in the addon.

## Schedule

| Milestone | Delivery |
|-----------|----------|
| RFC-001 | Playable 1P 2D slice |
| RFC-002 | 3D match + shared spawn runtime |
| RFC-003 | Listen-server + authority + handshake |
| RFC-004 | Dedicated + tunnel + snapshot + README |

Implement with `/implement-rfc` in order.

## Open questions / assumptions

| Item | Resolution |
|------|------------|
| Clean vs standard? | Standard. |
| One MP type or three? | Three, as a guide. Listen starts on host; dedicated starts on the **first** client. |
| Art? | Placeholders. |
| Tests? | No. |
| Where do product artifacts live? | In `example/` (the Godot project is the sample title). |
| Rejoin | Kit reserves the slot. Pawn is freed on `peer_left` and spawned again on world_ready. |
