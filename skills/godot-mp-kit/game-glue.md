# Glue del juego (lo que vos escribís)

El kit no es tu juego. Mínimo dos piezas (pueden ser autoloads o un solo `NetGlue.gd` en un título chico):

1. **Flow** — escucha `load_world`, `snapshot_received`, `session_ended`, `server_lost`. Cambia escenas.
2. **Lobby / policy** — `host()`/`join()`, cuándo `GameSession.start`, handshake de spawn.

Orden de autoload sugerido: `MpKit` → `GameSession` → `SceneDirector` → glue de red.

## Configurar

```gdscript
func _ready() -> void:
	MpKit.configure(7777, 2, 1)
	MpKit.peer_joined.connect(_on_peer_joined)
	MpKit.peer_left.connect(_on_peer_left)
	MpKit.client_world_ready.connect(_on_client_world_ready)
	MpKit.join_failed.connect(_on_join_failed)
```

Jugar solo: `MpKit.leave()` (deja offline) y cargar el mundo **sin** `host()`.

Lobby host: `"%s:%d" % [MpLan.get_local_ipv4(), port]`. Validar IP antes de `join`.

## Política de arranque (producto, no kit)

El ejemplar arranca al conectar el 2.º peer. Un shooter puede esperar “listo”. Eso vive en glue.

```gdscript
func _on_peer_joined(peer_id: int, slot: int) -> void:
	if game_session.is_running:
		MpKit.push_snapshot_to(peer_id, game_session.to_snapshot())
		MpKit.load_world_to(peer_id)
		return
	game_session.start([1, 2])  # o 1..N
	MpKit.push_snapshot_to(peer_id, game_session.to_snapshot())
	MpKit.broadcast_load_world()
	flow.goto_world()  # el host no recibe rpc_load_world
```

## Flow

```gdscript
func _ready() -> void:
	game_session.finished.connect(_on_finished)
	MpKit.load_world.connect(goto_world)
	MpKit.snapshot_received.connect(game_session.apply_snapshot)
	MpKit.session_ended.connect(_on_remote_ended)
	MpKit.server_lost.connect(_on_server_lost)
```

Al terminar en host: `broadcast_session_ended` + ir a resultados.  
`apply_snapshot` en cliente: `set_process(false)` en la sesión.

## Mundo (`_ready`)

```gdscript
func _ready() -> void:
	$PawnSpawner.add_spawnable_scene("res://pawns/pawn.tscn")
	# FX locales acá (también el cliente)

	if not MpKit.is_networked():
		_spawn_world()
		game_session.start([MpKit.local_slot()])
		return

	if not MpKit.is_server():
		MpKit.request_world_ready()
		return

	# Host: spawnea en _on_client_world_ready, no acá
```

`add_child(node, true)` — nombre estable para el spawner.

Rejoin con mundo vivo: `remove_child` + `add_child(..., true)` para reenviar spawn.

## Desconexión (definí producto)

| Signal | El kit | Vos |
|--------|--------|-----|
| `peer_left` | Limpia mapping | ¿Seguir 1P? ¿Pausar? ¿Marcar ausente? |
| `server_lost` | Ya `leave()` | Notice + menú |
| `join_failed` | Nada más | Notice + menú |

El ejemplar: guest drop no pausa el timer y deja la nave ausente. Otro género puede pausar. No lo pongas en el kit.

## Pawns

En `_ready` del actor replicado:

```gdscript
MpAuthority.claim_server(self)
MpAuthority.ensure_sync(self, PackedStringArray([".:position", ".:rotation", ".:visible"]))
MpAuthority.freeze_rigid_proxy(self)
```

Componer trail/FSM/FX como hijos. La red no justifica un pawn monolítico.

## Snapshot periódico

Nodo vuestro en el mundo, solo host, 2–10 Hz:

```gdscript
if MpKit.is_server() and game_session.is_running:
	MpKit.push_snapshot(game_session.to_snapshot())
```
