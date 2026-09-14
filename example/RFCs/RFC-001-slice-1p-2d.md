# RFC-001 — Slice 1P 2D

**Complejidad:** Medium  
**Predecesores:** ninguno  
**Sucesores:** RFC-002  
**Features:** F1, F2, F3, F4, F5

**Tipo:** juego Godot. Omitido: SQL, auth, browsers.

## Resumen

Lobby + jugar solo + un match 2D con un pawn placeholder que se mueve. Sin Host/Join todavía (botones pueden existir deshabilitados o no estar; no implementar F9–F10). Sin escena 3D. MpKit copiado y autoloadado porque el 1P del kit es `leave()` + OfflineMultiplayerPeer; no llamar `host()`.

## Enfoque

Arquitectura estándar. `NetGlue` solo `configure`, `play_solo`, `goto_world` (path 2D fijo en este RFC). `DemoCopy` con strings de lobby 1P. Looks `.tres`. Input en componente hijo.

## Archivos (todos en criterios)

```
example/addons/mp_kit/          # copia via install.sh --addon-only example
example/project.godot           # autoloads MpKit, NetGlue; plugin; main_scene boot; InputMap
example/glue/net_glue.gd
example/glue/demo_copy.gd
example/scenes/ui/boot.tscn
example/scenes/ui/boot.gd
example/scenes/world/match_2d.tscn
example/scenes/world/match_2d.gd
example/scenes/actors/pawn_2d.tscn
example/scenes/actors/pawn_2d.gd
example/scenes/components/pawn_input.gd
example/resources/looks/actor_look.gd
example/resources/looks/look_a.tres
example/resources/looks/look_b.tres
example/resources/looks/look_c.tres
example/resources/looks/look_d.tres
example/AGENTS.md
```

## Contratos

```gdscript
# NetGlue
var world_kind: String  # "2d" (RFC-002 añade "3d")
func play_solo() -> void
func goto_world() -> void
func return_to_boot() -> void  # puede quedar para F16; si existe, solo 1P

# ActorLook
@export var tint: Color
@export var badge: String
@export var move_speed: float

# Pawn2D
@export var player_slot: int
@export var look: ActorLook
func try_move(dir: Vector2) -> void
func apply_move(dir: Vector2) -> void
```

`try_move` en este RFC llama `apply_move` (aún no hay `submit_*`; eso es RFC-003). El método puede existir ya con el `if MpAuthority.should_send_command()` para no reescribir después, siempre que 1P siga el branch `apply`.

## UI / feel

- Boot: título, Jugar solo, label de estado (`DemoCopy.STATUS_IDLE`), IP local informativa (aunque Join no esté vivo).
- Toggle 2D/3D: si se muestra, 3D no carga escena inexistente (dejar 2D forzado o deshabilitar 3D hasta RFC-002).
- Pawn: cuadrado placeholder tintado, Label con badge.

## Criterios de aceptación

1. `./install.sh --addon-only example` deja `example/addons/mp_kit` y snippets `.vscode/`.
2. `project.godot`: `MpKit` antes de `NetGlue`; plugin `mp_kit` enabled; `run/main_scene` = boot; acciones `move_left/right/up/down` y `emote`.
3. F5 abre el lobby. Jugar solo carga `match_2d.tscn` y spawnea un pawn slot 1 con `look_a` (o looks[0]).
4. WASD/flechas mueven el pawn. No hay `Input.is_key_pressed` de scancodes.
5. `ActorLook` + cuatro `.tres` distintos. El pawn no ramifica por string de tipo.
6. F6 en `pawn_2d.tscn` mueve el cuerpo. F6 en `match_2d.tscn` spawnea offline.
7. Visual = `PlaceholderTexture2D` (no sprites de arte).
8. `AGENTS.md` apunta a `RULES.md`.
9. `DemoCopy` concentra el copy en español. Cero strings de puntaje/título de otro juego.
10. No se llama `MpKit.host()` en el camino 1P.
11. No existen aún (o no se usan) Host/Join funcionales, match 3D, dedicated, túnel broadcast, snapshot — eso es RFC-002+.

## Errores

Puerto no aplica. Si el addon falta, el proyecto no corre: el README llega en RFC-004; este RFC asume install hecho.

## Testing (manual; F23)

Jugar solo, mover, F6 pawn y match. Sin suite.

## Reglas aplicables

RULES §2 estándar, §3 composición, §4 1P sin host, F1–F5.
