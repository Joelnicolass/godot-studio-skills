# Arquitectura del ejemplo

Tamaño **por entidad**: una carpeta por tema en la raíz, con todo lo de esa entidad adentro.

```
example/
├── main/            boot.tscn, boot.gd                       # entrada: el inicio (Jugar solo, Host, Unirse)
├── player/          pawn_2d.*, pawn_3d.*, pawn_type.gd,      # el peón y sus tipos
│                    pawn_{a,b,c,d}_type.tres, pawn_catalog.*, pawn_material.tres
├── match/           demo_match.tscn, demo_match.gd           # el estado de la partida: tiempo y snapshot
├── levels/
│   ├── match_2d/    match_2d.tscn                            # mundo 2D: spawner, spawn points, HUD
│   └── match_3d/    match_3d.tscn, floor_material.tres       # mundo 3D
├── ui/hud/          match_hud.tscn, match_hud.gd
├── shared/
│   └── components/  pawn_input.gd                            # lo usan pawn_2d y pawn_3d
├── locale/          texts.csv                                # los textos del jugador (es, en)
├── autoloads/       net_session.tscn, net_session.gd               # conecta MpKit con el juego
├── debug/           pawn_3d_preview.tscn, spawn_lab/         # escenas de prueba, fuera del export
├── agent/           flows/, scripts del playtest             # AgentKit
├── docs/            architecture.md, tuning.md, .gdignore
└── addons/          mp_kit/, agent_kit/
```

- **Un dueño por número.** El peón tiene tipo: sus números están en `player/pawn_*_type.tres`, no en la escena. `DemoMatch` y `NetSession` no tienen tipo: sus números son `@export` de su raíz. Todo está en [tuning.md](tuning.md).
- **Textos.** Un `Control` usa la clave de `locale/texts.csv` como texto; el código usa `tr("CLAVE")`. Cada rama fija su idioma en `project.godot`.
- **Autoloads.** `MpKit` va antes de `NetSession`; `AgentKit` al final. `NetSession` se registra como escena para que sus números se vean en el inspector.
- **Debug.** Nada del juego nombra `res://debug`; `debug/*` va en el filtro de exclusión de los presets de export.
