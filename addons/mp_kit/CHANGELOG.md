# Changelog de MpKit

Las versiones anteriores a 0.19.0 están en el historial de git del repo del kit (los commits «MpKit 0.x.y: …»).

## 0.21.0

- **Un lobby que se camina.** Nuevo knob `pause_while_waiting` en el `MpFlow` (grupo **Match start**, `--pause-while-waiting=false`), prendido por defecto. Apagado, nadie se pausa mientras la partida espera a sus asientos: los jugadores que ya cargaron mueven su peón, con predicción, igual que después del arranque, mientras llegan los demás. La puerta no cambia: cuenta las cargas (también con `world_reports_loaded`), arranca por `all_loaded`, Start now o `load_timeout_s`, y el que llega durante la espera se sienta y camina. Lo pidió El Eternauta: su refugio, con un mapa en un atril, se camina mientras llegan los demás.
- **Lo que le toca al juego:** frenar sus propios sistemas (el reloj del día, las amenazas, los bots) hasta el arranque, con `MpMatch.waiting`, `waiting_changed` (todos los peers) y `all_loaded` (servidor). Explicado en [GUIDE 7.5](GUIDE.md#75-inicio-y-fin-mpmatch), «Un lobby que se camina».
- **Viaja a cada partida:** una partida en la PC del host (privada u online) lo toma del `MpFlow` del juego; la de un servidor de salas, de su `MpLobbyConfig` (`pause_while_waiting`, en `agent_fields`). `MpMatchGate.pause_while_waiting`; `pause_clients` solo cuenta con la pausa prendida.
- **Tests:** 136 del kit (la puerta sin pausa: espera, arranca por carga, por el host y por tiempo, solo; un cliente se pausa solo si el servidor lo pide; el knob viaja a la partida). `mpkit_lab/run/arena.sh lobbywalk`: un dedicado que espera dos asientos sin pausa, el primero camina con predicción mientras espera, el segundo entra y arranca; y el control con la pausa. Pasa por ENet, WebSocket y el relay.

Qué actualizar: nada. Para un lobby que se camina, apagá `pause_while_waiting` y frená lo que es de la partida hasta `MpMatch.all_loaded`.

## 0.20.1

- **El host arranca su partida solo si el juego lo pide.** Nuevo knob `host_can_start` en el `MpFlow` (grupo **Match start**, `--host-can-start=true`), apagado por defecto. Prendido, el que abrió una partida en su PC (privada u online, el slot 1) ve **Start now** y la arranca con los que ya cargaron. En 0.19.0 y 0.20.0 eso estaba siempre prendido; ahora, por defecto, una partida en la PC del host arranca como en 0.18: cuando cargaron todos o pasó el tiempo de carga. Con `start_on_timeout` apagado prendé también `host_can_start`: si no, nadie arranca una partida a la que un asiento nunca llega. El listen host (Host LAN, un navegador que hospeda) puede arrancar como siempre.
- **Ejemplo** `examples/bots_2d/`: una partida que espera en el mundo hasta que el host la arranca (`start_on_timeout` apagado, `host_can_start`), con un bot en cada asiento libre (`world.gd`, `bot.gd`: aprieta las teclas del jugador con `MpInput.bot_press`) y jugadores que entran tarde y toman el lugar de un bot (`late_join`). Usa el jugador de `minimal_2d`. Lo juega `tests/test_examples.gd`.
- **Emisor: un asiento que el host suelta queda libre enseguida.** Si un jugador se caía y su gracia terminaba antes de que venciera su reserva del emisor (2 × `ISSUER_TOKEN_TTL_S`, 2 minutos desde que entró), el que llegaba tarde recibía `room_full` aunque el host ya informaba ese asiento como libre. Ahora, cuando el host deja de informarlo en `held`, su reserva se suelta también. Un host sin `held` (MpKit 0.19 o anterior) sigue como antes. Lo encontró El Eternauta.
- **Tests:** 133 del kit, 31 del emisor.

Qué actualizar: si usabas el arranque por el host de 0.19 o 0.20 en una partida en la PC del host, prendé `host_can_start` en el `MpFlow`.

## 0.20.0

- **Cada jugador tiene su asiento en una sala online.** El ticket que el emisor le da al entrar es el suyo. Mientras está en la partida o ausente dentro de la gracia, el emisor no le da ese asiento a nadie más: ni desde la lista, ni con el código de sala, ni a uno que llega tarde. El host se lo informa al emisor en cada latido (`held`). Vuelve el mismo juego (el kit recuerda el ticket), el mismo juego reabierto en la misma PC (el emisor reconoce la instalación) o quien muestre el ticket: `MpIssuer.seat_ticket(code)` y `MpFlow.join_online(code, ticket)`. Pasada la gracia el asiento queda libre (con `late_join`) o cerrado.
- **Emisor:** `PUT /v1/rooms/:code` acepta `held` (opcional) y `POST /v1/rooms/:code/join` acepta `ticket` (rechazo nuevo: `bad_ticket`). Para que la reserva valga hay que desplegar el emisor nuevo; con el emisor anterior el kit anda como en 0.19.
- **Tests:** 132 del kit, 30 del emisor; `mpkit_lab/run/late.sh` parte 3.

## 0.19.0

- **Arranque explícito:** `start_on_timeout` (`MpFlow`, `MpLobbyConfig`, `--start-on-timeout=false`). Apagado, la partida nunca arranca por tiempo: espera a todos, o a que el host la arranque.
- **Unirse tarde con ticket:** `late_join` vale también en una partida en la PC del host (privada u online). El que llega entra al asiento de su ticket y la puerta emite `joined_late(slot)`. Una sala online con late join sigue en la lista mientras tenga asientos libres.
- **Bots en los asientos libres:** `Mp.gate().vacant_slots()` dice qué asientos nadie ocupa. `MpInput.bot_press` / `bot_release` / `bot_release_all` / `bot_set_value` son las teclas de un bot en el servidor (y en solo), leídas como las de un jugador: el mismo `mp_move`. `MpInput.has_player()` dice si un jugador juega ese asiento. El que toma el asiento se queda con el peón tal cual.
- **MpRelayPeer** descarta los paquetes en cola de un peer que se fue o que el host echó: ya no aparece `!connected_peers.has(sender)` en el log.
- **Tests:** 130; e2e nueva `mpkit_lab/run/late.sh`.

## Cambios de comportamiento (0.19.0 y 0.20.0)

Lo nuevo es opcional y viene apagado (`start_on_timeout` prendido, `late_join` y `host_can_start` apagados). Esto, en cambio, cambió para todos; son correcciones:

- **Un ticket válido ya no vence.** Antes, el ticket de un asiento que nadie tomó vencía a los `ticket_ttl_s` (60 s) de creada la partida, y el que llegaba oía `rejected`. Ahora decide la puerta: `match_started` si la partida arrancó sin late join, o entra con late join. `rejected` queda solo para un ticket que no es de ningún asiento. `ticket_ttl_s` solo cierra una partida a la que nunca entró nadie.
- **Sin late join, una sala online sale de la lista al arrancar.** El emisor no reparte más asientos (`room_full`); antes la sala seguía listada y el que entraba era rechazado. En un navegador que hospeda, los asientos en gracia cuentan como ocupados.
- **El asiento de un jugador en gracia no se le da a otro.** Antes, pasada la reserva del emisor (2 minutos), otro jugador podía recibir el ticket de un jugador caído, entrar como si volviera y quedarse con su peón y sus datos. Con el emisor de 0.20.0 nunca pasa (ver 0.20.0).
- **Red: todos los jugadores necesitan la misma versión de MpKit.** 0.19.0 cambió los RPC de la puerta de arranque (`rpc_state`, `rpc_start`): un build con MpKit 0.18 no juega con uno con 0.19 o más nuevo. El emisor compara la versión del juego, no la del kit, así que al actualizar MpKit subí **Project Settings › Application › Config › Version**: dos builds distintos no se cruzan en una sala online. En LAN no hay ese chequeo: actualizá todas las copias juntas.
