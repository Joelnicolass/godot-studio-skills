# MpKit — informal multiplayer kit (Godot 4)

Canonical copy: this repo (`addons/mp_kit`). Host-authoritative helpers. **No gameplay.** No scores, scenes, copy, or pawns.

Do **not** install for a 1P-only game.

Two server modes, **same ENet**, **same project** as the clients:

| Mode | API | Who is a player |
|------|-----|-----------------|
| **Listen-server** (LAN / same Wi-Fi) | `MpKit.host()` | The host process is slot 1 / peer 1 |
| **Dedicated** (online / VPS) | `MpKit.host_dedicated()` | Peer 1 is **not** a player. All slots go to `join()` clients |

Editor (enable the plugin):

- **Project → Tools → MpKit: Wire replication on selection** — adds `MpReplicate` + `MultiplayerSynchronizer`
- **MpKit: New replicated feature...** — writes `res://features/<id>/<id>.gd` + `.tscn`
- **MpKit: Install Cursor/VS Code snippets** — copies `.vscode/mpkit.code-snippets`
- Enable plugin registers autoload `MpKit`. Headless/CI: keep the autoload line in `project.godot` (do not also Enable if that would duplicate).

Nodes: `MpReplicate`, `MpSpawner`, `MpWorldReady`, `MpCustomPipe` (opaque `Dictionary` tunnel).

Online = dedicated server with a public IP + open UDP port. Develop locally (`--headless -- --dedicated` + clients on `127.0.0.1`).

Cursor skill: `skills/godot-mp-kit/`.

## Install

```bash
./install.sh --addon /path/to/godot-project
```

Or copy this folder to `res://addons/mp_kit/` and enable **MpKit** in Project → Settings → Plugins.

```
MpKit="*res://addons/mp_kit/mp_kit.gd"
```

1. `MpKit.configure(port, max_players)` before `host()` / `host_dedicated()` / `join()`.
2. Optional 4th arg: `PackedStringArray` of custom-tunnel channel names (empty = all allowed).
3. Do **not** put rules in `mp_kit.gd`.

## What you get

| Piece | Role |
|-------|------|
| `mp_kit.gd` | ENet + slots + session RPCs + custom Dictionary tunnel |
| `mp_ids.gd` | slot ↔ peer |
| `mp_boot.gd` | dedicated process detection |
| `mp_replicate.gd` | authority + sync + freeze |
| `mp_spawner.gd` | MultiplayerSpawner + hold until `world_ready` |
| `mp_world_ready.gd` | client handshake |
| `mp_custom_pipe.gd` | one named tunnel channel |
| `mp_lan.gd` / `mp_authority.gd` | IPv4 / authority helpers |

## Custom tunnel

Client → server: `MpKit.send_custom(channel, dict)` (offline/server: emits locally).  
Server → all: `broadcast_custom`. Server → one: `push_custom_to`.  
Signal: `custom_received(channel, data, from_peer)`. **No auto-reflect.** Glue decides.

## Handshake

1. Server `broadcast_load_world()` + glue loads the world on the server process.
2. Match scene: `MpSpawner` (`hold_until_world_ready` default) then `MpWorldReady`.
3. Listen host may `add_child` the local pawn in `_ready`; it spawns hidden to not-ready peers.
4. On `client_world_ready` the kit reveals synchronizers (`set_visibility_for`) → engine sends spawn + sync.
5. Spawn `occupied_slots()` only. Dedicated: no pawn for peer 1.
6. Do not unparent actors in glue.
