# MpKit: matriz de casos

Cada caso del framework y la prueba que lo cubre. `run/all.sh` corre todo lo automático (una hora con la cola compartida); `run/all.sh --quick`, uno de cada tipo por ENet (unos minutos); `run/play.sh` lo muestra en ventanas.
Transportes: lo marcado **T** corre en ENet, WebSocket y relay (`TRANSPORT=enet|ws|relay`); **TLS** también por `wss://` (`TLS=1`).

## Sesión

| Caso | Prueba |
|---|---|
| Jugar solo, sin red | `--probe=solo` (all.sh) |
| LAN: host + cliente + tardío | `arena.sh` listen **T** |
| Dedicado + cliente + tardío | `arena.sh` dedicated **T** |
| Unirse a una dirección muerta: falla limpio y el menú sigue | `session.sh` deadjoin |
| Servidor lleno (`--max-players`): el que sobra queda afuera | `session.sh` full |
| Salir al menú (Leave) y volver a entrar | `session.sh` leave |
| El servidor se cae: el cliente vuelve al menú | `session.sh` lost |
| Descubrimiento LAN desde el menú, dos ventanas en la misma PC | `session.sh` lan |
| Transporte equivocado (ENet contra WS y al revés) | `session.sh` mismatch |
| Unirse con un nombre de host | `session.sh` hostname |
| Direcciones: IP, nombre, `:puerto`, `#CÓDIGO`, URL | `tests/test_address.gd` |

## Actores

| Caso | Prueba |
|---|---|
| Sync de posición y propiedades extra, al nacer y en vivo | `arena.sh` **T** |
| `to_server` del dueño (`mp_sv_*`) | `arena.sh` recolor **T** |
| `to_all` (`mp_all_*`) | `arena.sh` flash **T** |
| El servidor rechaza `mp_sv_*` de quien no es dueño (RPC directo) | `arena.sh` listen, rejoin **T** |
| Actor sin dueño con `callers = ANYONE` y `sender_slot` | `arena.sh` bell **T** |
| `spawn_actor` y `despawn` en todos; el que vuelve no ve restos | `arena.sh` shot, rejoin **T** |
| Nodo solo del servidor en `spawn_path`: sin gate, sin romper clientes | `arena.sh` watch `--probe-server-node` **T** |
| `MpInput.set_value` llega al servidor | `arena.sh` watch (aim) **T** |
| Predicción: respuesta inmediata y corrección ~0 con lag, jitter y pérdida | `arena.sh` lag **T** |
| Una red mucho peor (60 ms + 60 ms de jitter, 15 % de pérdida): ninguna corrección (no se pierde ni se saltea ningún frame) y el otro jugador se sigue moviendo parejo | `arena.sh` lossy **T** |
| Un teletransporte con solo `net.snap()` en el servidor: el propio jugador y otro ven un salto, nunca un deslizamiento; el control sin él lo ve dibujado a mitad de camino | `arena.sh` teleport **T** |
| Rejoin a un peón que el servidor conservó (despawn_on_leave apagado): sin conexión no tiene teclas apretadas; al volver, el input de la conexión nueva (desde seq 1) lo mueve al instante | `arena.sh` keeppawn **T** |
| Una corrección que el dueño no puede predecir (el servidor lo empuja) se desvanece en pantalla; también con la physics interpolation del motor; el control sin suavizado ve un salto | `arena.sh` correct **T** |
| Demora con que aparece el movimiento de otro jugador (`remote_delay_ms`; tope con `MAX_REMOTE_DELAY_MS`) | `arena.sh` lag **T** |
| `Mp.net_quality()` mide el RTT, la pérdida y el jitter de la red simulada | `arena.sh` lag **T** |
| Compensación de lag: disparos con anticipación a un blanco que camina aciertan; con `--lag-comp=off`, la mayoría erra | `arena.sh` lagshot **T** |
| Buffers adaptativos, calidad de red, historial de poses y frame con el momento visto | `tests/test_input_queue.gd`, `test_net_quality.gd`, `test_lag_comp.gd`, `test_input_frame_view.gd` |
| Suavizado con buffer: el otro jugador se ve parejo | `arena.sh` lag (observe) **T** |
| Inundación de túnel y de `mp_sv_*`: solo pasan las ráfagas | `arena.sh` flood **T** |
| Reglas de sync, cola de input, interpolador, reloj, llamadas, tope | `tests/*.gd` |
| Qué nodos replica el spawner (hechos públicos) | `tests/test_spawner_rule.gd` |

## Partida

| Caso | Prueba |
|---|---|
| `MpState` y el que vuelve: mismo slot con la credencial del asiento, puntos y campana siguen, `player_back` | `arena.sh` rejoin (LAN y dedicado) **T** |
| Puerta de arranque: el que llega después del arranque se rechaza (`match_started`), sin slot ni mundo, y el flow muestra el motivo | `arena.sh` late **T** |
| `late_join`: un recién llegado después del arranque igual se sienta y juega | `arena.sh` latejoin **T** |
| Timeouts de red con el reloj real: un servidor cuyo reloj de juego se adelanta (`--fixed-fps`) igual admite a un cliente a 150 ms | `arena.sh` fastclock **T** |
| Pantalla de carga (`--world-reports-loaded`): el dedicado, el cliente y solo esperan a que su mundo avise que cargó, y después juegan | `arena.sh` reports **T** |
| Un dedicado a mano (`--dedicated`, asientos por defecto) sirve una partida tras otra: mundo nuevo después de una partida terminada cuando se fueron todos, y después de que todos se cayeron pasada la gracia | `arena.sh` survive **T** |
| Reglas de la puerta (llenar, lleno, `need`, gracia, asiento vivo, ticket, `load_timeout`, `all_gone`, `reset`, `late_join`, una credencial o ticket que desplaza una conexión vieja, el mundo del propio servidor: `wait_host`, solo, su timeout) | `tests/test_match_gate.gd` |
| `MpMatch.finish` llega a todos y a la sala | `rooms.sh` public **T TLS** |
| Volver a la partida (botón del lobby) dentro de la gracia | `rooms.sh` rejoin **T** |
| Abandono pasada la gracia: gana el otro | `rooms.sh` abandon **T** |
| El mundo espera pausado (en todos) a que carguen los asientos | `rooms.sh` wait **T** |

## Salas y servidores

| Caso | Prueba |
|---|---|
| Sala pública desde la lista | `rooms.sh` public **T TLS** |
| Sala privada por código, salir y volver, chat | `rooms.sh` private **T** |
| Dos salas a la vez en un servidor de salas | `rooms.sh` tworooms **T** |
| Tope `max_matches` | `rooms.sh` cap **T** |
| Cliente sin TLS contra lobby `wss://` | `rooms.sh` public `TLS=1` |
| Partida privada en la PC con código; código equivocado afuera | `private.sh` **T** |
| Una sala que hospeda un jugador de escritorio por el emisor (el proceso de partida de su PC); un amigo la encuentra en la lista y entra; el emisor la olvida al terminar | `online.sh` |
| Una sala que hospeda el propio juego del host (la forma del navegador): un amigo entra con el código escrito `abc-def`; el host se congela 3 s (SIGSTOP), el amigo espera (`host_silent` / `host_back`) y la partida termina normal; un tercero oye "sala llena", un código inventado "no existe" | `online.sh` |
| Un navegador hospeda una sala (el export web en un Chrome headless: CORS al emisor, el token del relay en la URL); un amigo de escritorio la encuentra por nombre y la juega | `online.sh` (SKIP sin Chrome) |
| Las reglas del emisor (salas, asientos, versiones, límites, la lista, hosts en silencio) y HTTP (chequeos, rate limits, CORS, la IP de Fly, los tokens), en Node; el relay aceptando sus tokens | `npm test` en `addons/mp_kit/issuer` |
| Relay: las salas de jugadores piden el token del emisor (ninguno, el secreto, de otra sala, de cliente, de otra clave, vencido → 403), una vez, `max` limita la sala, un host rechazado 4009 lo conserva | `npm test` en `addons/mp_kit/relay` |
| Un host en el navegador con la pestaña oculta sigue simulando (`MpWebKeepAlive`): 60 ticks/s más de 8 minutos en Chromium | medido a mano (una pestaña oculta no se maneja headless) |
| Dos servidores de salas en una máquina (línea de systemd) | `instances.sh` |
| La imagen del servidor (deploy/fly/Dockerfile) construida con el lab: un dedicado y un servidor de salas (sus partidas dentro del contenedor) detrás de un relay local, jugados a través | `docker.sh` (SKIP sin Docker) |
| Asistente: juego nuevo 2D y 3D jugable en red (`game.tres` + `MpWorld`) | `wizard.sh` |
| Asistente: las salas del juego nuevo (menú *Online rooms*, partida, `Mp.leave()` al lobby, Back al boot) | `wizard.sh` |
| `MpWorld` en el editor real: arma sus piezas al abrir la escena y al agregarlo; se guardan | `editor.sh` |
| El asistente corriendo dentro del editor | `editor.sh` |
| `MpGame` llena el flow; `Mp` sin red; `MpWorld` arma, empaqueta y vuelve a cargar | `tests/test_mp_facade.gd`, `tests/test_mp_world.gd` |
| `MpState.watch` (valor actual y después cada cambio), `MpLocalSeat` (el asiento de esta pantalla, `preview_slot` en solo), `MpSpawner.spawn_here` en solo | `tests/test_world_helpers.gd` |
| Cliente web (navegador) contra dedicado WebSocket | `web.sh` (Chrome headless, o abrir la URL a mano) |
| Cliente web por el relay (el servidor hostea una sala del relay) | `TRANSPORT=relay web.sh` |
| Relay: solo hostea quien tiene el secreto (header o query); sin secreto nadie, salvo `RELAY_OPEN=1` | `relay.sh` |
| Relay: una sala con host vivo rechaza a un segundo host (4009, como un puerto en uso) | `relay.sh` |
| Relay: sus reglas (peers falsos) y de punta a punta con clientes ws, en Node (`npm test` en `addons/mp_kit/relay`) | `relay.sh` |
| Relay: una partida rechazada vuelve a lanzarse en otro puerto y solo se anuncia la que escucha | `tests/test_launcher_relay_retry.gd` |
| Relay de punta a punta: con todos los puertos menos uno tomados, la partida privada arranca en el libre y se juega | `relayfault.sh` clash |
| Relay: un dedicado muerto (kill -9) y arrancado otra vez enseguida vuelve a tener su sala | `relayfault.sh` restart |
| Relay: con el host congelado, otro dedicado se rechaza y se cierra; cuando el relay suelta al mudo, un tercero entra | `relayfault.sh` frozen |
| Ventanas visibles: LAN, dedicado y salas, también por relay (`play.sh … --watch`) | `play.sh` |
| Partida privada: invitación en el HUD, segundo clic, otra partida privada en la misma PC (también por relay) | `private.sh` **T** |
| Botón Leave mientras la partida espera asientos (mundo pausado) | `rooms.sh` wait |
| `deploy.sh` (comandos que correría), también con `--transport relay` y el secreto aparte | `deploy.sh … --dry-run` |

## No cubierto acá (y por qué)

| Caso | Motivo |
|---|---|
| Export de Linux y un VPS real | requieren las plantillas de export de Linux y un VPS de prueba |
| El relay corriendo en Railway | es el mismo `server.mjs` que se prueba local; Railway no se toca desde acá |
| Clientes web por el relay con `wss://` público | requiere el dominio de Railway (por `ws://` local sí: `TRANSPORT=relay web.sh`) |
| Export *Dedicated Server* arrancado sin `--dedicated` | la etiqueta `dedicated_server` solo existe en un export |
