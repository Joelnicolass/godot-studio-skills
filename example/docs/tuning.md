# Where to change each thing

One row per design knob of the example. The player-facing texts are in `locale/texts.csv` (column `es` and column `en`). The branch language comes from `internationalization/locale/*` in `project.godot`.

| I want to change | File | Node | Property |
|---|---|---|---|
| The color of a pawn | `player/pawn_a_type.tres` (`b`, `c`, `d` for the other slots) | — | `tint` |
| The letter over a pawn | `player/pawn_a_type.tres` (same) | — | `badge` |
| A pawn's speed in the 2D world | `player/pawn_a_type.tres` (same) | — | `speed_2d_px_s` |
| A pawn's speed in the 3D world | `player/pawn_a_type.tres` (same) | — | `speed_3d_m_s` |
| How long the emote flash takes to reach white | `player/pawn_a_type.tres` (same) | — | `flash_in_s` |
| How long the emote flash takes to fade back | `player/pawn_a_type.tres` (same) | — | `flash_out_s` |
| Which type each slot takes, and in what order | `player/pawn_catalog.tres` | — | `types` |
| Force a type on a pawn in a scene | `player/pawn_2d.tscn` or `player/pawn_3d.tscn` | `Pawn2D` / `Pawn3D` | `type` |
| How many times per second the server sends the time | `match/demo_match.tscn` | `DemoMatch` | `snapshot_hz` |
| How many players fit | `autoloads/net_session.tscn` | `NetSession` | `max_players` |
| The name of the LAN room | `autoloads/net_session.tscn` | `NetSession` | `room_name` |
| Whether the room is announced on the LAN | `autoloads/net_session.tscn` | `NetSession` | `advertise_lan` |
| The tunnel channels | `autoloads/net_session.tscn` | `NetSession` | `custom_channels` |
| When the dedicated starts | `autoloads/net_session.tscn` | `NetSession` | `start_when` |
| Which scene is each world | `autoloads/net_session.tscn` | `NetSession` | `world_2d_path`, `world_3d_path` |
| Which scene opens when going back to the start | `autoloads/net_session.tscn` | `NetSession` | `boot_path` |
| Where each player spawns in 2D | `levels/match_2d/match_2d.tscn` | `SpawnPoints/P1`…`P4` | `position` |
| Where each player spawns in 3D | `levels/match_3d/match_3d.tscn` | `SpawnPoints/P1`…`P4` | `transform` |
| The color of the 3D floor | `levels/match_3d/floor_material.tres` | — | `albedo_color` |
| A UI text (or its translation) | `locale/texts.csv` | — | the key's row, column `es` or `en` |
| The language of this branch | `project.godot` | — | `internationalization/locale/fallback` and `locale/test` |
