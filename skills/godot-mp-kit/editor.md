# Editor, scaffold y túnel

El plugin, habilitado, registra el autoload y el menú **Project → Tools**.

| Acción | Qué hace |
|--------|----------|
| **Setup game...** | Un juego multijugador entero desde un diálogo: `game.tres`, boot, mundo con `MpWorld`, jugador predicho, salas opcionales. Muestra el árbol (`[+]` / `[~]`) y nunca pisa un archivo. `addons/mp_kit/examples/minimal_2d/` es lo que escribe en 2D sin salas. |
| **Make selection a network actor** | Hijo `MpActor` (su `MpSync` se arma y se guarda con la escena) y, en un `CharacterBody`, `MpInput` (undo). El camino de código nuevo. |
| **New replicated feature...** | Bajo nivel: crea `res://features/<id>/` (o la carpeta que indiques), `.gd` + `.tscn` con `MpReplicate`, sync, `submit_*` / `apply_*` y opcional `MpCustomPipe`. |
| **New session flow...** | Escribe `res://glue/session_flow.tscn` + `.gd` (`extends MpFlow`) y lo registra como autoload. |
| **Install Cursor/VS Code snippets** | Copia `.vscode/mpkit.code-snippets`. Recargá la ventana del editor. Prefijos: `mpkit-submit`, `mpkit-custom`, `mpkit-boot`, `mpkit-flow`, `mpkit-lan-adv`, `mpkit-lan-browse`. |

Al Enable también copia **script templates** a `res://script_templates/` (con `.gdignore`). Al adjuntar un script: **MpKit actor** (`CharacterBody2D/3D`: reglas en el servidor, `mp_sv_*` / `mp_all_*`; necesita los hijos `MpActor` + `MpInput`) o, de bajo nivel, **MpKit replicated** (`submit_*` / `apply_*`).

CI/headless: autoload en `project.godot`. No dupliques Enable + línea manual.

Sin Godot abierto (Claude Code o Cursor): command `/new-mp-feature` (un actor con `MpActor` + `MpInput`; el scaffold de bajo nivel solo si se pide). `./install.sh --addon` también instala los snippets en `.vscode/`.

## Nodos (Create New Node)

| Nodo | Uso |
|------|-----|
| `MpReplicate` | Hijo del actor. Authority peer 1, props de sync, freeze RigidBody proxy. `interpolate` opcional en proxies. |
| `MpSpawner` | `MultiplayerSpawner` + `extra_scenes`. `spawn_path` = padre de actores. Retiene por peer sus synchronizers (spawneados y estáticos); el cliente avisa que está listo. `room_id` para salas hub. Un nodo por mundo (o por sala). |
| `MpSlotSpawner` | Igual + un `pawn_scene` por slot ocupado (`Pawn_<n>`). Dedicated no spawnea slot 0. |
| `MpBootMenu` | Lobby drop-in. Usa `MpFlow` si está en el árbol; si no, `world_scene` para zero-glue. Copy por `@export`. |
| `MpFlow` | Autoload de sesión: boot/world(s), host/join/1P, arma la puerta de arranque (rejoin dentro de la gracia; `late_join` apagado por defecto; un dedicado a mano abre solo la partida siguiente); carga el mundo en un hilo con pantalla de carga opcional (`world_reports_loaded`, `world_load_progressed`). Varios mapas: `add_world` / `select_world`. |
| `MpWorldReady` | Legado. No hace falta si hay `MpSpawner`. |
| `MpCustomPipe` | Un canal del túnel `Dictionary`. |

LAN y dedicated: el mismo árbol. El boot elige `host()` / `host_dedicated()`.

## Túnel `Dictionary` (bajo nivel, controlado)

El kit **no** interpreta el dict. No hay reflect automático (el servidor decide si reenvía).

```
Cliente / 1P / servidor local    MpKit.send_custom(channel, data)
Servidor → todos                 MpKit.broadcast_custom(channel, data)
Servidor → un peer               MpKit.push_custom_to(peer_id, channel, data)
Señal                            custom_received(channel, data, from_peer)
```

Allowlist opcional en `configure(..., custom_channels)`. Vacío = todos los nombres. No vacío = se descarta lo que no está en la lista.

O un nodo `MpCustomPipe` por feature (`@export channel`, signal `packet`).

No metas meshes, puntaje ni `kind` de bala acá: Resources + `net.to_server(&"x")` / `Mp.state()`. El túnel es el escape hatch (emote, debug, un handshake vuestro).

Paso a paso humano (mandar / recibir / reenviar al servidor, salas hub y cola, con diagramas): `addons/mp_kit/README.md`.

## Estructura de una feature

Con nodos (código nuevo):

```
res://features/<id>/
  <id>.gd      plantilla MpKit actor: reglas tras net.is_authority(), mp_sv_* / mp_all_*
  <id>.tscn    root + MpActor (+ MpSync guardado) [+ MpInput si lo maneja un jugador]
```

De bajo nivel (*New replicated feature...*):

```
res://features/<id>/
  <id>.gd      try_/submit_/apply_  (y send_manual si hay pipe)
  <id>.tscn    root + MpReplicate + MultiplayerSynchronizer [+ MpCustomPipe]
```

Después: la escena en las *Extra Scenes* del `MpSpawner` (`spawn_actor(escena, {...})`). Tipos de contenido = `.tres` del juego, no un canal por `kind`.
