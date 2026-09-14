# Editor, scaffold, and tunnel

With the plugin enabled, the autoload is registered and **Project → Tools** gains MpKit actions.

| Action | What it does |
|--------|----------|
| **Wire replication on selection** | Child `MpReplicate` + `MultiplayerSynchronizer` (undo). Does not clone Godot’s Replication dock. |
| **New replicated feature...** | Writes `res://features/<id>/` (or the folder you pick): `.gd` + `.tscn` with replicate, sync, and optional `MpCustomPipe`. |
| **Install Cursor/VS Code snippets** | Copies `.vscode/mpkit.code-snippets`. Reload the Cursor window. Prefixes: `mpkit-submit`, `mpkit-custom`, `mpkit-boot`, `mpkit-lan-adv`, `mpkit-lan-browse`. |

Enable also copies **script templates** to `res://script_templates/` (with `.gdignore`). When attaching a script to `CharacterBody2D/3D` or `Node2D/3D`, template **MpKit replicated**.

CI/headless: autoload in `project.godot`. Do not duplicate Enable + a manual line.

Cursor without Godot open: command `/new-mp-feature` (same file layout). `./install.sh --addon` also installs snippets into `.vscode/`.

## Nodes (Create New Node)

| Node | Use |
|------|-----|
| `MpReplicate` | Child of the actor. Authority peer 1, sync props, freeze RigidBody proxy. Optional `interpolate` on proxies. |
| `MpSpawner` | `MultiplayerSpawner` + `extra_scenes`. `spawn_path` = actor parent. Hold + client `request_world_ready`. One node is enough. |
| `MpSlotSpawner` | Same + one `pawn_scene` per occupied slot (`Pawn_<n>`). Dedicated does not spawn slot 0. |
| `MpBootMenu` | Drop-in lobby. `world_scene` for zero-glue; copy via `@export`. |
| `MpWorldReady` | Leftover. Not needed if an `MpSpawner` is present. |
| `MpCustomPipe` | One Dictionary-tunnel channel. |

LAN and dedicated: the same tree. Boot chooses `host()` / `host_dedicated()`.

## Dictionary tunnel (low-level, controlled)

The kit **does not** interpret the dict. No automatic reflect (the server decides whether to forward).

```
Client / 1P / local server    MpKit.send_custom(channel, data)
Server → everyone             MpKit.broadcast_custom(channel, data)
Server → one peer             MpKit.push_custom_to(peer_id, channel, data)
Signal                        custom_received(channel, data, from_peer)
```

Optional allowlist in `configure(..., custom_channels)`. Empty = all names. Non-empty = drop anything not listed.

Or one `MpCustomPipe` node per feature (`@export channel`, signal `packet`).

Do not put meshes, score, or bullet `kind` here: Resources + actor `submit_*`. The tunnel is the escape hatch (emote, debug, your own handshake).

## Feature layout

```
res://features/<id>/
  <id>.gd      try_/submit_/apply_  (and send_manual if there is a pipe)
  <id>.tscn    root + MpReplicate + MultiplayerSynchronizer [+ MpCustomPipe]
```

Then register the packed scene on the match `MpSpawner`. Content types = the game’s `.tres`, not a channel per `kind`.
