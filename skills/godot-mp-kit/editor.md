# Editor, scaffold, and tunnel

With the plugin enabled, the autoload is registered and **Project → Tools** gains MpKit actions.

| Action | What it does |
|--------|----------|
| **Setup game...** | A whole multiplayer game from one dialog: `game.tres`, the boot, a world with `MpWorld`, a predicted player, optional rooms. It shows the tree (`[+]` / `[~]`) and never overwrites a file. `addons/mp_kit/examples/minimal_2d/` is what it writes in 2D without rooms. |
| **Make selection a network actor** | Child `MpActor` (its `MpSync` built and saved with the scene) and, on a `CharacterBody`, `MpInput` (undo). The path for new code. |
| **New replicated feature...** | Low level: writes `res://features/<id>/` (or the folder you pick), `.gd` + `.tscn` with `MpReplicate`, sync, `submit_*` / `apply_*` and an optional `MpCustomPipe`. |
| **New session flow...** | Writes `res://glue/session_flow.tscn` + `.gd` (`extends MpFlow`) and registers it as an autoload. |
| **Install Cursor/VS Code snippets** | Copies `.vscode/mpkit.code-snippets`. Reload the editor window. Prefixes: `mpkit-submit`, `mpkit-custom`, `mpkit-boot`, `mpkit-flow`, `mpkit-lan-adv`, `mpkit-lan-browse`. |

Enable also copies **script templates** to `res://script_templates/` (with `.gdignore`). When attaching a script: **MpKit actor** (`CharacterBody2D/3D`: rules on the server, `mp_sv_*` / `mp_all_*`; needs the `MpActor` + `MpInput` children) or, low level, **MpKit replicated** (`submit_*` / `apply_*`).

CI/headless: autoload in `project.godot`. Do not duplicate Enable + a manual line.

Without Godot open (Claude Code or Cursor): command `/new-mp-feature` (an actor with `MpActor` + `MpInput`; the low-level scaffold only when asked). `./install.sh --addon` also installs snippets into `.vscode/`.

## Nodes (Create New Node)

| Node | Use |
|------|-----|
| `MpReplicate` | Child of the actor. Authority peer 1, sync props, freeze RigidBody proxy. Optional `interpolate` on proxies. |
| `MpSpawner` | `MultiplayerSpawner` + `extra_scenes`. `spawn_path` = actor parent. Holds its synchronizers (spawned and static) per peer; the client reports ready. `room_id` for hub rooms. One node per world (or per room). |
| `MpSlotSpawner` | Same + one `pawn_scene` per occupied slot (`Pawn_<n>`). Dedicated does not spawn slot 0. |
| `MpBootMenu` | Drop-in lobby. Uses `MpFlow` if present; otherwise `world_scene` for zero-glue. Copy via `@export`. |
| `MpFlow` | Session autoload: boot/world(s), host/join/1P, arms the start gate (rejoin within the grace; `late_join` off by default; a dedicated by hand opens the next match by itself); loads the world on a thread with an optional loading screen (`world_reports_loaded`, `world_load_progressed`). Several maps: `add_world` / `select_world`. |
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

Do not put meshes, score, or bullet `kind` here: Resources + `net.to_server(&"x")` / `Mp.state()`. The tunnel is the escape hatch (emote, debug, your own handshake).

Human step-by-step (send / receive / server forward, hub rooms and queue, with diagrams): `addons/mp_kit/README.md`.

## Feature layout

With nodes (new code):

```
res://features/<id>/
  <id>.gd      MpKit actor template: rules behind net.is_authority(), mp_sv_* / mp_all_*
  <id>.tscn    root + MpActor (+ saved MpSync) [+ MpInput if a player drives it]
```

Low level (*New replicated feature...*):

```
res://features/<id>/
  <id>.gd      try_/submit_/apply_  (and send_manual if there is a pipe)
  <id>.tscn    root + MpReplicate + MultiplayerSynchronizer [+ MpCustomPipe]
```

Then: the scene in the `MpSpawner`'s *Extra Scenes* (`spawn_actor(scene, {...})`). Content types = the game’s `.tres`, not a channel per `kind`.
