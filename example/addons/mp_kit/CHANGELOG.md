# Changelog de MpKit

Las versiones anteriores a 0.19.0 están en el historial de git del repo del kit (los commits «MpKit 0.x.y: …»).

## 0.25.2

- **Iconos propios en el editor:** cada nodo y recurso del kit tiene el suyo, del color del kit: se ven en el árbol de escena, en «Agregar nodo» y en el FileSystem.

Qué actualizar: nada en tu proyecto. `MpKit.VERSION` pasa a 0.25.2, así que servidor y clientes tienen que ir con el mismo build.

## 0.25.1

- **El asistente genera nombres únicos (`%`) en lugar de rutas `$`.** `Setup game...` escribe el script del jugador con `%MpActor`, `%MpInput` y `%Visual`, y marca esos nodos como nombre único en la escena (`unique_name_in_owner`). `examples/minimal_2d` queda igual a lo que genera. **MpKit: New session flow...** escribe `res://autoloads/session_flow.tscn` (más su `.gd`) en lugar de `res://glue/`, y las rutas de ejemplo del kit (`main/boot.tscn`, `levels/<nivel>/<nivel>.tscn`) siguen el layout por carpetas por tema. `examples/bots_2d`: el bot ya no busca el `MpInput` en su padre; `world.gd`, que lo crea, se lo pasa, y lleva su propio registro de peón a bot.

Qué actualizar: nada en tu proyecto. `MpKit.VERSION` pasa a 0.25.1, así que servidor y clientes tienen que ir con el mismo build.

## 0.25.0

- **Una sola línea de tiempo.** `MpActor › Smoothing › shared_timeline`: todo actor `BUFFERED` con esto prendido se dibuja en el mismo momento del servidor, al retraso adaptativo más grande que necesite alguno (sube y baja de a poco, como el de uno solo). Antes cada actor calculaba el suyo, y la pelota podía verse un tick corrida de los pies que la tocan. Apagado por defecto. Lo pidió futbolito-match.
- **Sin adivinar.** `MpActor › Smoothing › max_extrapolate_s` (0,1 s, como antes): pasado el último estado, cuánto sigue un proxy con su movimiento antes de esperar. En 0 espera enseguida.
- `MpActor.draw_delay()`: cuánto atrás se dibuja un proxy ahora.
- **La lista de salas desde el arranque.** Una llamada al emisor (`MpFlow.online_rooms()`, `host_online()`, `join_online()`) hecha desde el `_ready` de la escena de arranque nunca salía: el kit sumaba su `HTTPRequest` a la raíz mientras la raíz todavía armaba sus hijos, y fallaba con `ERR_UNCONFIGURED`. Ahora lo suma al frame siguiente y espera a que esté listo. Lo encontró futbolito-match.
- **GUIDE §7.8, «Sin predicción: todo en una línea de tiempo»**: cuándo conviene en un juego de pelota (el ping como lag de las teclas, sin saltos), cómo se configura, y el lag medido de la tecla a la pantalla a 80 ms por tramo con 2 % de pérdida: 290 ms con un buffer fijo de 0,1 s, 235 ms adaptativo y 200 ms sin buffer. Sin predicción, el servidor aplica las teclas más nuevas: no hay cola de teclas que acortar.
- `examples/sports_2d`: la pelota y los jugadores con `shared_timeline`. Su jugador anda también con la predicción apagada (el servidor corre el mismo `mp_move` en `_physics_process`): apagala en el inspector, guardá la escena y queda el caso de §7.8 «Sin predicción».
- **Tests:** 157 del kit (el jugador del ejemplo sin predicción corre y se barre; dos proxies que comparten se dibujan al mismo retraso, el que cubre al más lento; uno que no comparte sigue con el suyo; con `max_extrapolate_s` en 0 espera en el último estado). `mpkit_lab/probe/issuer_at_ready.tscn` (en `all.sh`) pide al emisor desde el `_ready` de la escena de arranque, contra un emisor de prueba local. `mpkit_lab/run/sports.sh` comprueba por red que la pelota y el portador se dibujan en el mismo momento (0 s de diferencia), y ahora pide que la carrera y la barrida propias se corrijan menos de dos ticks de su paso (con más corridas se vieron 5,4 px corriendo y 9 px en la barrida: un frame que el servidor tuvo que suponer, en un giro).

Qué actualizar: nada; lo nuevo está apagado por defecto. `MpKit.VERSION` pasa a 0.25.0, así que servidor y clientes tienen que ir con el mismo build.

## 0.24.0

- **La predicción ya no se corrige en cada acción.** En un `MpActor` con predicción, cada valor de `sync_extra` que no era una pose ni una velocidad (un contador de dash o de barrida, un stun, la dirección) se mandaba cuando cambiaba, en otro paquete que la pose. La reconciliación volvía a la pose del servidor y repetía las teclas desde el estado de otro tick. Medido con un dash contado en `sync_extra`, a 40 ms con jitter: 35 px de corrección promedio (picos de 133 px) por ENet y por WebSocket. Ahora, con predicción, todo `sync_extra` viaja con la pose en cada envío, y la corrección baja a 0,5-1,3 px. Lo encontró futbolito-match: sus barridas se veían tarde y su jugador se corregía todo el tiempo.
- **Un deportivo en tiempo real.** Ejemplo nuevo `examples/sports_2d/`: dos contra dos, con una pelota del servidor dibujada `BUFFERED` y, en los pies del que la lleva, en su propia pantalla. La carrera y la barrida son predichas, con su estado en `sync_extra`. El quite se juzga contra donde el que se barre veía al rival (`seen_position_of`), y el partido arranca cuando entraron todos. La GUIDE suma §7.8, con el caso, las siete reglas y qué hacer con un motor central.
- **Tests:** 154 del kit:
  - con predicción, `sync_extra` va con la pose, y una escena vieja ya no coincide (avisa);
  - el ejemplo guardado para predecir;
  - un partido solo con barrida, gambeta, patada y gol.
- **Lab:** `mpkit_lab/run/sports.sh` juega el ejemplo con un dedicado y dos clientes, a 40 ms por tramo con jitter, por ENet y por WebSocket:
  - las barridas que tocaron en la pantalla de quien barre ganan la pelota 6 de 6 con compensación de lag, y entre 0 y 3 de 6 sin ella;
  - la carrera y la barrida propias se corrigen menos de un tick de su paso (4 a 6 px). Con el envío viejo, la barrida propia se corregía 70 px.

Qué actualizar: abrí en el editor cada escena con un `MpActor` con predicción y `sync_extra`, y guardala (MpKit avisa al jugar: «its saved MpSync is out of date»). Hasta que la guardes, sigue mandando esos valores aparte. Cambia lo que se manda, así que `MpKit.VERSION` pasa a 0.24.0: servidor y clientes tienen que ir con el mismo build.

## 0.23.0

- **Sacar el peón de un jugador conectado no deja errores.** Hasta acá, después de `MpActor.despawn()` el servidor escribía, por cada peón, `Node not found: ".../Pawn_N/MpInput"`, `Failed to get cached node` e `Invalid packet received`. Eran las teclas que el cliente mandó antes de enterarse de que el peón ya no estaba. Un host corrido con `--fail-on-error` (un CI, un harness de pruebas) se cortaba ahí, y el depurador del editor las mostraba en rojo cada vez que moría un jugador. Ahora los cuadros de entrada de `MpInput` y las llamadas `MpActor.to_server` viajan por `MpKit`, que vive siempre, con una clave por nodo (`MpKit.route_key`: su camino, igual en todos los peers). Lo que llega para un nodo que ya no está (murió) o que todavía no llegó se descarta sin decir nada. Lo pidió El Eternauta: su prueba de RFC-020A corre con `--fail-on-error`.
- **Para tu juego no cambia nada:** `to_server`, `MpInput` y su lectura siguen igual, también la lista de quién puede llamar (`callers`), el tope de tamaño y el límite de llamadas.
- **Cambio de protocolo:** los RPC internos `MpInput.rpc_frames` / `rpc_slack` y `MpActor.rpc_server_call` / `rpc_server_call_seen` pasan a `MpKit.rpc_input_frames`, `rpc_input_slack` y `rpc_actor_call`. Un build de 0.22 y uno de 0.23 no se entienden.
- **Tests:** 151 del kit (`test_routes.gd`: cada `MpInput` y `MpActor` toma su clave al entrar y la devuelve al salir; un cuadro, una llamada o un aviso de pacing para un peón que ya no está se descarta sin error; un peón hecho de nuevo con el mismo nombre toma la misma clave). `mpkit_lab/run/arena.sh respawn` ahora saca el peón mientras su jugador aprieta teclas y exige cero `Node not found` en el servidor y en el cliente. Pasa todo `arena.sh` por ENet, y `dedicated`, `respawn`, `lag` y `flood` por WebSocket y el relay; también `rooms.sh` (public, rejoin, abandon), `private.sh`, `finish.sh`, `online.sh`, `late.sh` y `session.sh`.

Qué actualizar: `MpKit.VERSION` pasa a 0.23.0, así que servidor y clientes tienen que ir con el mismo build. Si tu juego llamaba a mano a `rpc_server_call` o `rpc_frames` (no estaban documentados), usá `to_server` y `MpInput`.

## 0.22.1

- **Un peón que tu juego libera se olvida.** Hasta acá, después de `MpActor.despawn()` (murió) el `MpSlotSpawner` guardaba el peón liberado. `pawn_for(slot)` y `spawn_slot(slot)` fallaban en el servidor (`Trying to return a previously freed instance`), y también cuando ese jugador se iba (`despawn_on_leave`). Ahora `pawn_for` da `null`, `spawn_slot` crea uno nuevo y el que se va no deja nada que liberar. Un peón que vuelve en el mismo frame en que murió entra apenas sale el viejo (desde el frame siguiente) y conserva el nombre `Pawn_<slot>` en todos los peers; antes salía `Pawn_3`. Lo encontró El Eternauta: su jugador muerto sigue mirando y después se va.
- **Tests:** 148 del kit (4 nuevos en `test_slot_spawner.gd`; los 3 que tocan el peón liberado fallan con el spawner de 0.22.0). `mpkit_lab/run/arena.sh respawn`: un dedicado saca el peón de P1 y lo vuelve a crear en el mismo frame; el cliente ve el `Pawn_1` nuevo y lo mueve; después muere del todo, se cierra el asiento y el jugador se va, sin errores. Pasa por ENet, WebSocket y el relay; `dedicated`, `keeppawn`, `latejoin` y `late.sh` siguen en verde.

Qué actualizar: nada. `MpKit.VERSION` pasa a 0.22.1, así que servidor y clientes tienen que ir con el mismo build.

## 0.22.0

- **Un asiento que se cierra.** `Mp.gate().close_seat(slot)` (servidor): nadie vuelve a sentarse en ese asiento en esta partida. Ni un recién llegado (`late_join`), ni un bot tuyo (`vacant_slots()` ya no lo da), ni su propio jugador cuando se fue: se lo rechaza con `seat_closed`, y el flow lo muestra con `seat_closed_status`. Llamalo cuando el peón de ese asiento quedó afuera de la partida para siempre (murió, escapó) y tu juego lo sacó. Su jugador, mientras siga conectado, se queda: tu juego decide qué ve (una cámara de espectador, su pantalla de fin). Cuando se va, el asiento abandona al instante (`player_abandoned`, motivo `seat_closed`): no hay gracia que esperar. Antes del arranque, la partida deja de esperarlo. Una sala online o privada deja de repartirlo (`closed_slots()`), y `held_slots()` ya no lo cuenta. Señal nueva `seat_closed(slot)`. Lo pidió El Eternauta: el que murió o escapó no vuelve a entrar a un asiento sin peón.
- **Terminar no es «se perdió el servidor».** Si el servidor se va después de que la partida terminó (`MpMatch.finish`), el cliente ya no recibe `MpKit.server_lost`: recibe la señal nueva `MpKit.server_closed`, y el `MpFlow` vuelve al lobby o al menú sin el aviso «Lost the server». Lo mismo si después del final el host queda en silencio hasta `host_silent_timeout_s`. `server_lost` queda para la caída de verdad, con la partida en curso.
- **La pantalla de fin espera al jugador.** Knob nuevo `stay_after_finish_s` en el `MpFlow` (grupo nuevo **Match end**, `--stay-after-finish-s=`), 0 por defecto. Con más de 0, una partida terminada en la PC del host (privada u online, `MpLocalServer`) sigue arriba mientras sus jugadores estén adentro: leen tu pantalla de fin y salen con un clic (`leave_match()`, `MpLeaveButton`). El proceso se cierra cuando se va el último, nunca antes de `result_quit_delay_s` y como mucho a los `stay_after_finish_s`. En 0, como antes: se cierra `result_quit_delay_s` (3 s) después del resultado y el que sigue adentro vuelve al lobby o al menú. La partida de un servidor de salas lo toma de su `MpLobbyConfig.stay_after_finish_s` (en `agent_fields`). Lo pidió El Eternauta: su pantalla de fin queda hasta que el jugador hace clic.
- **Una partida terminada que sigue arriba no es la que corre.** `MpLocalServer.running()` ya no la devuelve, `is_finished()` dice que terminó e `invites()` queda vacío. `MpLocalServer.start_on()` y `MpFlow.host_online()` la cierran y abren una nueva; los que seguían leyendo vuelven al menú sin «server lost». La sala online deja de repartir asientos (`MpOnline.is_finished()`) y se cierra en el emisor cuando se va su proceso de partida. `MpMatchLauncher.is_finished(id)`.
- **Tests:** 144 del kit:
  - `close_seat`: el jugador se queda hasta que se va y después se lo rechaza; el asiento nunca vuelve a quedar libre con late join; con ticket; antes del arranque; en la partida siguiente.
  - `server_closed` contra `server_lost`.
  - `stay_after_finish_s` viaja a la partida.

  `mpkit_lab/run/finish.sh`: un amigo con su pantalla de fin, en cuatro modos (`quit`, `leave`, `again`, `online`). Pasa por ENet; `quit`, `leave` y `again` también por WebSocket y el relay; `online`, por el emisor y el relay de la corrida. `private.sh`, `online.sh`, `late.sh`, `rooms.sh public`, `session.sh lost` y `arena.sh latejoin` siguen en verde.

Qué actualizar: `MpKit.VERSION` pasa a 0.22.0, así que servidor y clientes tienen que ir con el mismo build. Si tu juego escuchaba `MpKit.server_lost` para saber que la partida terminó, escuchá `MpMatch.finished` (o `MpKit.server_closed`). Para una pantalla de fin que espera el clic, poné `stay_after_finish_s` (por ejemplo 120) y llamá a `leave_match()` desde tu botón.

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
