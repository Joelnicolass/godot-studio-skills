# Glue del juego (lo que vos escribís)

El kit no es tu juego. Mínimo dos piezas (pueden ser autoloads o un solo `NetGlue.gd` en un título chico):

1. **Flow** — escucha `load_world`, `snapshot_received`, `session_ended`, `server_lost`. Cambia escenas.
2. **Lobby / policy** — `host()` / `host_dedicated()` / `join()`, cuándo arranca la ronda, handshake de spawn.

Clean: `GameSession` + `SceneDirector`. Estándar: un nodo `Match` en el mundo (o glue único). El kit no cambia.

Orden de autoload sugerido: `MpKit` → (sesión si Clean) → flow → glue de red.

Dedicated / VPS: [dedicated.md](dedicated.md).

## Configurar

```gdscript
func _ready() -> void:
	var port := int(MpBoot.user_value("mp-port", "7777"))
	MpKit.configure(port, 4, 1)
	MpKit.peer_joined.connect(_on_peer_joined)
	MpKit.peer_left.connect(_on_peer_left)
	MpKit.client_world_ready.connect(_on_client_world_ready)
	MpKit.join_failed.connect(_on_join_failed)

	if MpBoot.is_dedicated_process():
		var err := MpKit.host_dedicated()
		if err != OK:
			push_error("dedicated bind failed: %s" % err)
			get_tree().quit(1)
		return
```

Jugar solo: `MpKit.leave()` (deja offline) y cargar el mundo **sin** `host()`.

Lobby LAN: `"%s:%d" % [MpLan.get_local_ipv4(), port]`. Online: campo IP (dev: `127.0.0.1`). Validar IP antes de `join`.

## Política de arranque (producto, no kit)

Listen: una política válida es arrancar al conectar el 2.º peer (el host ya está). Dedicated: el servidor empieza vacío; arrancá al N-ésimo cliente o con un “listo”.

```gdscript
func _on_peer_joined(peer_id: int, slot: int) -> void:
	if game_session.is_running:
		MpKit.push_snapshot_to(peer_id, game_session.to_snapshot())
		MpKit.load_world_to(peer_id)
		return
	var slots := MpKit.occupied_slots()
	if MpKit.is_dedicated() and slots.size() < 2:
		return  # ejemplo: esperar 2 clientes
	game_session.start(slots)
	MpKit.push_snapshot_to(peer_id, game_session.to_snapshot())
	MpKit.broadcast_load_world()
	flow.goto_world()  # el servidor no recibe rpc_load_world
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

Al terminar en servidor: `broadcast_session_ended` + ir a resultados.  
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

	# Listen host: pawn local en _ready. MpSpawner no lo manda hasta world_ready.
	if MpKit.is_listen_host():
		_ensure_pawn(MpKit.local_slot())
```

`add_child(node, true)` — nombre estable. Colocá posición/slot **antes** de `add_child`.

```gdscript
func _on_client_world_ready(peer_id: int) -> void:
	_ensure_pawn(MpKit.slot_for_peer(peer_id))
```

Dedicated: **no** spawnees un pawn para `local_slot() == 0`.

`MpSpawner` revela los actores al peer listo (visibilidad nativa del synchronizer). No hagas `remove_child` + `add_child` en glue.

## Desconexión (definí producto)

| Signal | El kit | Vos |
|--------|--------|-----|
| `peer_left` | Limpia mapping | ¿Seguir? ¿Pausar? ¿Marcar ausente? Dedicated con 0 clientes: ¿apagar ronda? |
| `server_lost` | Ya `leave()` | Notice + menú |
| `join_failed` | Nada más | Notice + menú |

Una política válida: guest drop no pausa el timer y deja el pawn ausente. Otro género puede pausar. No lo pongas en el kit.

## Pawns

Preferí un hijo `MpReplicate` (Tools → Wire replication, o el scaffold). Equivale a:

```gdscript
MpAuthority.claim_server(self)
MpAuthority.ensure_sync(self, PackedStringArray([".:position", ".:rotation", ".:visible"]))
MpAuthority.freeze_rigid_proxy(self)
```

Componer trail/FSM/FX como hijos. La red no justifica un pawn monolítico. Túnel manual: [editor.md](editor.md).

## Snapshot periódico

Nodo vuestro en el mundo, solo servidor, 2–10 Hz:

```gdscript
if MpKit.is_server() and game_session.is_running:
	MpKit.push_snapshot(game_session.to_snapshot())
```
