# RFC-002 — Match 3D y spawn compartido

**Complejidad:** Medium  
**Predecesores:** RFC-001  
**Sucesores:** RFC-003  
**Features:** F6, F7, F8

**Tipo:** juego Godot. Omitido: SQL, auth, browsers.

## Resumen

Misma fantasía en 3D (caja placeholder + piso). Extraer el spawn 1P del match 2D a un nodo `DemoMatch` reusado por ambos mundos. Toggle 2D/3D en el lobby funciona.

## Archivos

```
example/scenes/world/demo_match.gd          # nuevo
example/scenes/world/match_2d.tscn          # hijo DemoMatch; quitar spawn inline
example/scenes/world/match_2d.gd            # delgado o vacío
example/scenes/world/match_3d.tscn
example/scenes/world/match_3d.gd
example/scenes/actors/pawn_3d.tscn
example/scenes/actors/pawn_3d.gd
example/glue/net_glue.gd                    # world_kind 2d|3d, paths
example/scenes/ui/boot.gd                   # toggle
example/glue/demo_copy.gd                   # WORLD_2D / WORLD_3D si faltan
```

## Contratos

```gdscript
class_name DemoMatch
extends Node
@export var pawn_scene: PackedScene
@export var actors: Node
@export var spawn_points: Node
@export var looks: Array[ActorLook]
func ensure_pawn(slot: int) -> void
```

En este RFC `DemoMatch` solo spawnea el slot local 1P (y F6). `client_world_ready` se puede conectar ya pero no spawnea clientes hasta RFC-003.

Pawn 3D: `try_move`/`apply_move` con `Vector2` de input mapeado a XZ; gravedad en Y.

F6 pawn 3D: si `current_scene == self`, añadir `Camera3D` + piso temporal (no ensuciar el packed scene de producción con cámara current=true).

## Criterios de aceptación

1. Existen `match_3d.tscn` y `pawn_3d.tscn` con placeholders (`BoxMesh`), sin `.glb`.
2. Lobby toggle 2D/3D cambia `NetGlue.world_kind`. Jugar solo carga la escena correspondiente.
3. `DemoMatch` está en **ambos** matches. Spawn 1P no está duplicado en dos scripts largos.
4. Markers 2D (`Marker2D`) / 3D (`Marker3D`) definen posiciones; el script no hardcodea Vector mágicos salvo fallback si no hay markers.
5. F6 `pawn_3d` es controlable. F6 `match_3d` muestra piso + pawn.
6. `MpSpawner.spawn_path` apunta a `Actors` (no al default `.` del spawner).
7. Gravedad 3D: el pawn no cae al infinito (piso + `move_and_slide`).
8. No Host/Join, dedicated, emote de red ni snapshot (RFC-003/004).

## Testing manual

Jugar solo 2D y 3D. F6 de las cuatro escenas (matches + pawns).

## Reglas aplicables

RULES §3 placeholders 3D, F6–F8. Composición: DemoMatch es el “Match” del camino estándar.
