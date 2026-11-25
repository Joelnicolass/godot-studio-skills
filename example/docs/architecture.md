# Example architecture

**By entity** size: one folder per topic at the root, with everything of that entity inside.

```
example/
├── main/            boot.tscn, boot.gd                       # entry: the start screen (Play solo, Host, Join)
├── player/          pawn_2d.*, pawn_3d.*, pawn_type.gd,      # the pawn and its types
│                    pawn_{a,b,c,d}_type.tres, pawn_catalog.*, pawn_material.tres
├── match/           demo_match.tscn, demo_match.gd           # the match state: time and snapshot
├── levels/
│   ├── match_2d/    match_2d.tscn                            # 2D world: spawner, spawn points, HUD
│   └── match_3d/    match_3d.tscn, floor_material.tres       # 3D world
├── ui/hud/          match_hud.tscn, match_hud.gd
├── shared/
│   └── components/  pawn_input.gd                            # used by pawn_2d and pawn_3d
├── locale/          texts.csv                                # the player-facing texts (es, en)
├── autoloads/       net_session.tscn, net_session.gd               # connects MpKit to the game
├── debug/           pawn_3d_preview.tscn, spawn_lab/         # test scenes, outside the export
├── agent/           flows/, playtest scripts                 # AgentKit
├── docs/            architecture.md, tuning.md, .gdignore
└── addons/          mp_kit/, agent_kit/
```

- **One owner per number.** The pawn has a type: its numbers are in `player/pawn_*_type.tres`, not in the scene. `DemoMatch` and `NetSession` have no type: their numbers are `@export` on their root. Everything is in [tuning.md](tuning.md).
- **Texts.** A `Control` uses the key from `locale/texts.csv` as its text; code uses `tr("KEY")`. Each branch sets its language in `project.godot`.
- **Autoloads.** `MpKit` goes before `NetSession`; `AgentKit` last. `NetSession` is registered as a scene so its numbers show in the inspector.
- **Debug.** Nothing in the game names `res://debug`; `debug/*` goes in the exclude filter of the export presets.
