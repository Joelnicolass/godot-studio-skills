# MpKit changelog

Versions before 0.19.0 are in the kit repo's git history (the "MpKit 0.x.y: …" commits).

## 0.25.0

- **One timeline.** `MpActor › Smoothing › shared_timeline`: every `BUFFERED` actor with it on is drawn at the same moment of the server, at the largest adaptive delay any of them needs (it rises and falls gently, as one actor's own does). Before, each actor worked out its own, and the ball could show a tick apart from the feet that touch it. Off by default. Asked for by futbolito-match.
- **No guessing.** `MpActor › Smoothing › max_extrapolate_s` (0.1 s, as before): past the newest state, how long a proxy goes on along its motion before it waits. At 0 it waits at once.
- `MpActor.draw_delay()`: how far in the past a proxy is drawn now.
- **GUIDE §7.8, "Without prediction: everything on one timeline"**: when it suits a ball game (the ping felt as key lag, with no jumps), how to set it up, and the key-to-screen lag measured at 80 ms each way with 2 % loss: 290 ms with a fixed 0.1 s buffer, 235 ms adaptive and 200 ms with no buffer. Without prediction the server applies the newest keys: there is no key queue to shorten.
- `examples/sports_2d`: the ball and the players with `shared_timeline`.
- **Tests:** 156 in the kit (two sharing proxies are drawn at the same delay, the one that covers the slower; one that does not share keeps its own; with `max_extrapolate_s` at 0 it waits at the newest state). `mpkit_lab/run/sports.sh` checks over the network that the ball and the carrier are drawn at the same moment (0 s apart), and now asks that its own running and slide be corrected less than two ticks of their step (more runs showed 5.4 px running and 9 px sliding: a frame the server had to guess, at a turn).

What to update: nothing; what is new is off by default. `MpKit.VERSION` goes to 0.25.0, so server and clients must run the same build.

## 0.24.0

- **Prediction is no longer corrected on every action.** In an `MpActor` with prediction, each `sync_extra` value that was not a pose or a velocity (a dash or slide counter, a stun, the direction) was sent when it changed, in another packet than the pose. The reconciliation went back to the server's pose and replayed the keys from another tick's state. Measured with a dash counted in `sync_extra`, at 40 ms with jitter: 35 px of correction on average (peaks of 133 px) over ENet and over WebSocket. Now, with prediction, all of `sync_extra` travels with the pose on every send, and the correction drops to 0.5-1.3 px. Found by futbolito-match: its slides looked late and its player was corrected all the time.
- **A real-time sports game.** New example `examples/sports_2d/`: two against two, with a server ball drawn `BUFFERED` and, on its carrier's own screen, at its feet. Running and sliding are predicted, with their state in `sync_extra`. A tackle is judged against where the slider saw the rival (`seen_position_of`), and the match starts once everyone is in. The GUIDE adds §7.8, with the case, the seven rules and what to do with a central engine.
- **Tests:** 154 in the kit:
  - with prediction, `sync_extra` rides with the pose, and an old scene no longer matches (it warns);
  - the example saved for prediction;
  - a solo match with a slide, a dribble, a kick and a goal.
- **Lab:** `mpkit_lab/run/sports.sh` plays the example with a dedicated server and two clients, at 40 ms each way with jitter, over ENet and over WebSocket:
  - the slides that touched on the slider's screen win the ball 6 out of 6 with lag compensation, and between 0 and 3 out of 6 without it;
  - its own running and slide are corrected less than one tick of their step (4 to 6 px). With the old send, its own slide was corrected 70 px.

What to update: open in the editor each scene with an `MpActor` with prediction and `sync_extra`, and save it (MpKit warns while playing: "its saved MpSync is out of date"). Until you save it, it still sends those values apart. What is sent changes, so `MpKit.VERSION` goes to 0.24.0: server and clients must run the same build.

## 0.23.0

- **Removing a connected player's pawn leaves no errors.** Until now, after `MpActor.despawn()` the server logged, per pawn, `Node not found: ".../Pawn_N/MpInput"`, `Failed to get cached node` and `Invalid packet received`. Those were the keys the client sent before it heard the pawn was gone. A host run with `--fail-on-error` (a CI, a test harness) stopped there, and the editor's debugger showed them in red each time a player died. Now `MpInput`'s input frames and `MpActor.to_server` calls travel through `MpKit`, which is always there, with a key per node (`MpKit.route_key`: its path, the same on every peer). What arrives for a node that is gone (it died) or not there yet is dropped without a word. Asked for by El Eternauta: its RFC-020A playtest runs with `--fail-on-error`.
- **Nothing changes for your game:** `to_server`, `MpInput` and how you read it stay the same, and so do who may call (`callers`), the size cap and the call limit.
- **Protocol change:** the internal RPCs `MpInput.rpc_frames` / `rpc_slack` and `MpActor.rpc_server_call` / `rpc_server_call_seen` become `MpKit.rpc_input_frames`, `rpc_input_slack` and `rpc_actor_call`. A 0.22 build and a 0.23 build do not understand each other.
- **Tests:** 151 of the kit (`test_routes.gd`: each `MpInput` and `MpActor` takes its key as it enters and gives it back as it leaves; a frame, a call or a pacing word for a pawn that is gone is dropped with no error; a pawn made again with the same name takes the same key). `mpkit_lab/run/arena.sh respawn` now removes the pawn while its player presses keys and demands zero `Node not found` on the server and the client. All of `arena.sh` passes over ENet, and `dedicated`, `respawn`, `lag` and `flood` over WebSocket and the relay; so do `rooms.sh` (public, rejoin, abandon), `private.sh`, `finish.sh`, `online.sh`, `late.sh` and `session.sh`.

What to update: `MpKit.VERSION` goes to 0.23.0, so the server and the clients must run the same build. If your game called `rpc_server_call` or `rpc_frames` by hand (they were not documented), use `to_server` and `MpInput`.

## 0.22.1

- **A pawn your game frees is forgotten.** Until now, after `MpActor.despawn()` (it died) the `MpSlotSpawner` kept the freed pawn. `pawn_for(slot)` and `spawn_slot(slot)` failed on the server (`Trying to return a previously freed instance`), and so did that player leaving (`despawn_on_leave`). Now `pawn_for` gives `null`, `spawn_slot` makes a new one and a player who leaves leaves nothing to free. A pawn that comes back in the same frame it died enters as soon as the old one is out (from the next frame) and keeps the name `Pawn_<slot>` on every peer; before, it came out `Pawn_3`. Found by El Eternauta: its dead player keeps watching and then leaves.
- **Tests:** 148 of the kit (4 new in `test_slot_spawner.gd`; the 3 that touch the freed pawn fail with the 0.22.0 spawner). `mpkit_lab/run/arena.sh respawn`: a dedicated removes P1's pawn and makes it again in the same frame; the client sees the new `Pawn_1` and moves it; then it dies for good, the seat closes and the player leaves, with no errors. It passes over ENet, WebSocket and the relay; `dedicated`, `keeppawn`, `latejoin` and `late.sh` are still green.

What to update: nothing. `MpKit.VERSION` goes to 0.22.1, so the server and the clients must run the same build.

## 0.22.0

- **A seat that closes.** `Mp.gate().close_seat(slot)` (server): nobody sits in that seat again this match. Not a newcomer (`late_join`), not a bot of yours (`vacant_slots()` no longer gives it), not its own player once it left: it is turned away with `seat_closed`, and the flow shows it with `seat_closed_status`. Call it when the seat's pawn is out of the match for good (it died, it escaped) and your game removed it. Its player, while still connected, stays: your game decides what it sees (a spectator camera, its end screen). When it leaves, the seat is abandoned at once (`player_abandoned`, reason `seat_closed`): there is no grace to wait for. Before the start, the match stops waiting for it. An online or private room stops handing it out (`closed_slots()`), and `held_slots()` no longer counts it. New signal `seat_closed(slot)`. Asked for by El Eternauta: a player who died or escaped does not come back into a seat with no pawn.
- **Ending is not "lost the server".** When the server goes away after the match ended (`MpMatch.finish`), the client no longer gets `MpKit.server_lost`: it gets the new signal `MpKit.server_closed`, and the `MpFlow` goes back to the lobby or the menu without the "Lost the server" status. The same if, after the end, the host goes quiet until `host_silent_timeout_s`. `server_lost` is kept for a real drop, with the match on.
- **The end screen waits for the player.** New knob `stay_after_finish_s` on the `MpFlow` (new **Match end** group, `--stay-after-finish-s=`), 0 by default. Above 0, a finished match on the host's PC (private or online, `MpLocalServer`) stays up while its players are still in it: they read your end screen and leave on a click (`leave_match()`, `MpLeaveButton`). The process closes once the last one left, never before `result_quit_delay_s` and at most after `stay_after_finish_s`. At 0, as before: it closes `result_quit_delay_s` (3 s) after the result and whoever is still in goes back to the lobby or the menu. A room server's match takes it from its `MpLobbyConfig.stay_after_finish_s` (in `agent_fields`). Asked for by El Eternauta: its end screen stays until the player clicks.
- **A finished match still up is not the running one.** `MpLocalServer.running()` no longer gives it back, `is_finished()` says it ended and `invites()` is empty. `MpLocalServer.start_on()` and `MpFlow.host_online()` close it and open a new one; whoever was still reading goes back to the menu without "lost the server". The online room hands out no more seats (`MpOnline.is_finished()`) and closes on the issuer once its match process is gone. `MpMatchLauncher.is_finished(id)`.
- **Tests:** 144 of the kit:
  - `close_seat`: the player stays until it leaves and is turned away after; the seat is never free again with late join; with a ticket; before the start; in the next match.
  - `server_closed` against `server_lost`.
  - `stay_after_finish_s` travels to the match.

  `mpkit_lab/run/finish.sh`: a friend with its end screen, in four modes (`quit`, `leave`, `again`, `online`). It passes over ENet; `quit`, `leave` and `again` over WebSocket and the relay too; `online` through the run's issuer and relay. `private.sh`, `online.sh`, `late.sh`, `rooms.sh public`, `session.sh lost` and `arena.sh latejoin` are still green.

What to update: `MpKit.VERSION` goes to 0.22.0, so the server and the clients must run the same build. If your game listened to `MpKit.server_lost` to know the match ended, listen to `MpMatch.finished` (or `MpKit.server_closed`). For an end screen that waits for the click, set `stay_after_finish_s` (for instance 120) and call `leave_match()` from your button.

## 0.21.0

- **A lobby you walk.** New knob `pause_while_waiting` on the `MpFlow` (**Match start** group, `--pause-while-waiting=false`), on by default. Off, nobody pauses while the match waits for its seats: the players who loaded move their pawn, predicted, as after the start, while the others come in. The gate does not change: it counts the loads (with `world_reports_loaded` too), starts on `all_loaded`, Start now or `load_timeout_s`, and whoever comes in while it waits sits and walks. Asked for by El Eternauta: its shelter, with a map on a lectern, is walked while the others come in.
- **What the game does:** hold its own systems (the day clock, the threats, the bots) until the start, with `MpMatch.waiting`, `waiting_changed` (every peer) and `all_loaded` (the server). Explained in [GUIDE 7.5](GUIDE.md#75-start-and-end-mpmatch), "A lobby you walk".
- **It travels to each match:** a match on the host's PC (private or online) takes it from the game's `MpFlow`; a room server's match, from its `MpLobbyConfig` (`pause_while_waiting`, in `agent_fields`). `MpMatchGate.pause_while_waiting`; `pause_clients` only counts with the pause on.
- **Tests:** 136 of the kit (the gate without the pause: it waits, starts by load, by the host and by time, solo; a client pauses only if the server asks; the knob travels to the match). `mpkit_lab/run/arena.sh lobbywalk`: a dedicated that waits for two seats without the pause, the first walks predicted while it waits, the second comes in and it starts; and the control with the pause. It passes over ENet, WebSocket and the relay.

What to update: nothing. For a lobby you walk, turn `pause_while_waiting` off and hold what belongs to the match until `MpMatch.all_loaded`.

## 0.20.1

- **The host starts its match only if the game asks for it.** New knob `host_can_start` on the `MpFlow` (**Match start** group, `--host-can-start=true`), off by default. On, the player who opened a match on its PC (private or online, slot 1) sees **Start now** and starts it with whoever loaded. In 0.19.0 and 0.20.0 that was always on; now, by default, a match on the host's PC starts as in 0.18: once every seat loaded or the load time passed. With `start_on_timeout` off turn `host_can_start` on too: otherwise nobody starts a match a seat never comes to. A listen host (Host LAN, a browser that hosts) may start as it always could.
- **Example** `examples/bots_2d/`: a match that waits in the world until the host starts it (`start_on_timeout` off, `host_can_start`), with a bot in every free seat (`world.gd`, `bot.gd`: it presses the player's keys with `MpInput.bot_press`) and players who come in late and take a bot's place (`late_join`). It uses `minimal_2d`'s player. `tests/test_examples.gd` plays it.
- **Issuer: a seat the host lets go is free at once.** If a player dropped and its grace ended before its issuer reservation ran out (2 × `ISSUER_TOKEN_TTL_S`, 2 minutes from its join), a late player got `room_full` though the host already reported that seat free. Now, when the host stops reporting it in `held`, its reservation is let go too. A host with no `held` (MpKit 0.19 or older) stays as before. Found by El Eternauta.
- **Tests:** 133 kit tests, 31 issuer tests.

What to update: if you used 0.19's or 0.20's host start in a match on the host's PC, turn `host_can_start` on in the `MpFlow`.

## 0.20.0

- **Each player has its seat in an online room.** The ticket the issuer gives a player on joining is its own. While it is in the match or away within the grace, the issuer gives that seat to nobody else: not from the list, not with the room's code, not to a late player. The host tells the issuer in each heartbeat (`held`). Back comes the same game (the kit remembers the ticket), the same game reopened on the same PC (the issuer knows the install), or whoever shows the ticket: `MpIssuer.seat_ticket(code)` and `MpFlow.join_online(code, ticket)`. Past the grace the seat is free (with `late_join`) or closed.
- **Issuer:** `PUT /v1/rooms/:code` takes `held` (optional) and `POST /v1/rooms/:code/join` takes `ticket` (new refusal: `bad_ticket`). The hold needs the new issuer deployed; with the previous issuer the kit works as in 0.19.
- **Tests:** 132 kit tests, 30 issuer tests; `mpkit_lab/run/late.sh` part 3.

## 0.19.0

- **Explicit start:** `start_on_timeout` (`MpFlow`, `MpLobbyConfig`, `--start-on-timeout=false`). Off, the match never starts by time: it waits for everyone, or for the host to start it.
- **Late join with a ticket:** `late_join` works in a match on the host's PC too (private or online). The newcomer takes its ticket's seat and the gate emits `joined_late(slot)`. An online room with late join stays listed while it has free seats.
- **Bots in the free seats:** `Mp.gate().vacant_slots()` says which seats nobody holds. `MpInput.bot_press` / `bot_release` / `bot_release_all` / `bot_set_value` are a bot's keys on the server (and solo), read like a player's: the same `mp_move`. `MpInput.has_player()` says whether a player plays that seat. Whoever takes the seat keeps the pawn as it is.
- **MpRelayPeer** drops the queued packets of a peer that left or that the host closed: `!connected_peers.has(sender)` no longer shows in the log.
- **Tests:** 130; new e2e `mpkit_lab/run/late.sh`.

## Behavior changes (0.19.0 and 0.20.0)

What is new is optional and comes off (`start_on_timeout` on, `late_join` and `host_can_start` off). This, though, changed for everyone; they are fixes:

- **A valid ticket no longer expires.** Before, the ticket of a seat nobody took expired `ticket_ttl_s` (60 s) after the match was made, and whoever came heard `rejected`. Now the gate decides: `match_started` if the match started without late join, or it comes in with late join. `rejected` is left for a ticket that is no seat at all. `ticket_ttl_s` only ends a match nobody ever came into.
- **Without late join, an online room leaves the list when it starts.** The issuer hands out no more seats (`room_full`); before, the room stayed listed and whoever came in was turned away. In a browser that hosts, seats away within their grace count as taken.
- **A player's seat in its grace is not handed to someone else.** Before, past the issuer's reservation (2 minutes), another player could get a dropped player's ticket, come in as if coming back, and keep its pawn and data. With the 0.20.0 issuer it never happens (see 0.20.0).
- **Network: every player needs the same MpKit version.** 0.19.0 changed the start gate's RPCs (`rpc_state`, `rpc_start`): a build with MpKit 0.18 does not play with one with 0.19 or newer. The issuer compares the game's version, not the kit's, so when you update MpKit raise **Project Settings › Application › Config › Version**: two different builds never meet in an online room. On LAN there is no such check: update every copy together.
