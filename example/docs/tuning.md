# Dónde se cambia cada cosa

Una fila por cada perilla de diseño del ejemplo. Los textos del jugador están en `locale/texts.csv` (columna `es` y columna `en`). El idioma de la rama sale de `internationalization/locale/*` en `project.godot`.

| Quiero cambiar | Archivo | Nodo | Propiedad |
|---|---|---|---|
| El color de un peón | `player/pawn_a_type.tres` (`b`, `c`, `d` para los otros slots) | — | `tint` |
| La letra sobre un peón | `player/pawn_a_type.tres` (idem) | — | `badge` |
| La velocidad de un peón en el mundo 2D | `player/pawn_a_type.tres` (idem) | — | `speed_2d_px_s` |
| La velocidad de un peón en el mundo 3D | `player/pawn_a_type.tres` (idem) | — | `speed_3d_m_s` |
| Cuánto tarda el destello del emote en subir a blanco | `player/pawn_a_type.tres` (idem) | — | `flash_in_s` |
| Cuánto tarda el destello del emote en volver al color | `player/pawn_a_type.tres` (idem) | — | `flash_out_s` |
| Qué tipo toma cada slot, y en qué orden | `player/pawn_catalog.tres` | — | `types` |
| Forzar un tipo en un peón de una escena | `player/pawn_2d.tscn` o `player/pawn_3d.tscn` | `Pawn2D` / `Pawn3D` | `type` |
| Cuántas veces por segundo el servidor manda el tiempo | `match/demo_match.tscn` | `DemoMatch` | `snapshot_hz` |
| Cuántos jugadores entran | `autoloads/net_session.tscn` | `NetSession` | `max_players` |
| El nombre de la sala LAN | `autoloads/net_session.tscn` | `NetSession` | `room_name` |
| Si la sala se anuncia en la LAN | `autoloads/net_session.tscn` | `NetSession` | `advertise_lan` |
| Los canales del túnel | `autoloads/net_session.tscn` | `NetSession` | `custom_channels` |
| Cuándo arranca el dedicated | `autoloads/net_session.tscn` | `NetSession` | `start_when` |
| Qué escena es cada mundo | `autoloads/net_session.tscn` | `NetSession` | `world_2d_path`, `world_3d_path` |
| Qué escena abre al volver al inicio | `autoloads/net_session.tscn` | `NetSession` | `boot_path` |
| Dónde aparece cada jugador en 2D | `levels/match_2d/match_2d.tscn` | `SpawnPoints/P1`…`P4` | `position` |
| Dónde aparece cada jugador en 3D | `levels/match_3d/match_3d.tscn` | `SpawnPoints/P1`…`P4` | `transform` |
| El color del piso 3D | `levels/match_3d/floor_material.tres` | — | `albedo_color` |
| Un texto de la UI (o su traducción) | `locale/texts.csv` | — | la fila de la clave, columna `es` o `en` |
| El idioma de esta rama | `project.godot` | — | `internationalization/locale/fallback` y `locale/test` |
