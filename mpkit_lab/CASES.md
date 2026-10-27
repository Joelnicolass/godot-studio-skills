# MpKit: the case matrix

Every case of the framework and the test that covers it. `run/all.sh` runs everything automatic (an hour with a shared queue); `run/all.sh --quick`, one of each kind over ENet (a few minutes); `run/play.sh` shows it in windows.
Transports: what is marked **T** runs over ENet, WebSocket and the relay (`TRANSPORT=enet|ws|relay`); **TLS** also over `wss://` (`TLS=1`).

## Session

| Case | Test |
|---|---|
| Play solo, no network | `--probe=solo` (all.sh) |
| LAN: host + client + late joiner | `arena.sh` listen **T** |
| Dedicated + client + late joiner | `arena.sh` dedicated **T** |
| Joining a dead address: fails cleanly and the menu carries on | `session.sh` deadjoin |
| A full server (`--max-players`): the extra player stays out | `session.sh` full |
| Leaving to the menu (Leave) and entering again | `session.sh` leave |
| The server goes down: the client goes back to the menu | `session.sh` lost |
| LAN discovery from the menu, two windows on the same PC | `session.sh` lan |
| The wrong transport (ENet against WS and the other way round) | `session.sh` mismatch |
| Joining with a host name | `session.sh` hostname |
| Addresses: IP, name, `:port`, `#CODE`, URL | `tests/test_address.gd` |

## Actors

| Case | Test |
|---|---|
| Sync of position and extra properties, on spawn and live | `arena.sh` **T** |
| The owner's `to_server` (`mp_sv_*`) | `arena.sh` recolor **T** |
| `to_all` (`mp_all_*`) | `arena.sh` flash **T** |
| The server refuses `mp_sv_*` from a non-owner (a direct RPC) | `arena.sh` listen, rejoin **T** |
| An ownerless actor with `callers = ANYONE` and `sender_slot` | `arena.sh` bell **T** |
| `spawn_actor` and `despawn` everywhere; the one coming back sees no leftovers | `arena.sh` shot, rejoin **T** |
| A server-only node under `spawn_path`: no gate, clients unbroken | `arena.sh` watch `--probe-server-node` **T** |
| `MpInput.set_value` reaches the server | `arena.sh` watch (aim) **T** |
| Prediction: an immediate answer and a ~0 correction with lag, jitter and loss | `arena.sh` lag **T** |
| How late another player's move shows (`remote_delay_ms`; a cap with `MAX_REMOTE_DELAY_MS`) | `arena.sh` lag **T** |
| `Mp.net_quality()` measures the simulated network's RTT, loss and jitter | `arena.sh` lag **T** |
| Lag compensation: led shots at a walking target hit; with `--lag-comp=off`, most miss | `arena.sh` lagshot **T** |
| Adaptive buffers, network quality, pose history and the frame's view time | `tests/test_input_queue.gd`, `test_net_quality.gd`, `test_lag_comp.gd`, `test_input_frame_view.gd` |
| Buffered smoothing: the other player looks steady | `arena.sh` lag (observe) **T** |
| Flooding the tunnel and `mp_sv_*`: only the bursts get through | `arena.sh` flood **T** |
| Sync rules, input queue, interpolator, clock, calls, rate cap | `tests/*.gd` |
| Which nodes the spawner replicates (public facts) | `tests/test_spawner_rule.gd` |

## Match

| Case | Test |
|---|---|
| `MpState` and the one coming back: same slot with the seat's credential, score and bell still there, `player_back` | `arena.sh` rejoin (LAN and dedicated) **T** |
| Start gate: whoever arrives after the start is turned away (`match_started`), with no slot nor world, and the flow shows the reason | `arena.sh` late **T** |
| `late_join`: a newcomer after the start still sits and plays | `arena.sh` latejoin **T** |
| Network timeouts on the real clock: a server whose game clock races ahead (`--fixed-fps`) still admits a client 150 ms away | `arena.sh` fastclock **T** |
| Loading screen (`--world-reports-loaded`): the dedicated, the client and solo hold until their world reports itself loaded, then play | `arena.sh` reports **T** |
| A dedicated by hand (`--dedicated`, default seats) serves one match after another: a fresh world after a finished match once everyone left, and after everyone dropped past the grace | `arena.sh` survive **T** |
| The gate's rules (filling, full, `need`, grace, a live seat, ticket, `load_timeout`, `all_gone`, `reset`, `late_join`, a credential or ticket displacing a stale connection, the server's own world: `wait_host`, solo, its timeout) | `tests/test_match_gate.gd` |
| `MpMatch.finish` reaches everyone and the room | `rooms.sh` public **T TLS** |
| Going back to the match (the lobby's button) within the grace | `rooms.sh` rejoin **T** |
| Abandoning past the grace: the other one wins | `rooms.sh` abandon **T** |
| The world waits paused (on everyone) until the seats load | `rooms.sh` wait **T** |

## Rooms and servers

| Case | Test |
|---|---|
| A public room from the list | `rooms.sh` public **T TLS** |
| A private room by code, leaving and coming back, chat | `rooms.sh` private **T** |
| Two rooms at once on one room server | `rooms.sh` tworooms **T** |
| The `max_matches` cap | `rooms.sh` cap **T** |
| A client without TLS against a `wss://` lobby | `rooms.sh` public `TLS=1` |
| A private match on the PC with a code; a wrong code stays out | `private.sh` **T** |
| Two room servers on one machine (a systemd line) | `instances.sh` |
| Wizard: a new 2D and 3D game playable over the network (`game.tres` + `MpWorld`) | `wizard.sh` |
| Wizard: the new game's rooms (the menu's *Online rooms*, the match, `Mp.leave()` to the lobby, Back to the boot) | `wizard.sh` |
| `MpWorld` in the real editor: builds its pieces when the scene opens and when it is added; they are saved | `editor.sh` |
| The wizard running inside the editor | `editor.sh` |
| `MpGame` fills the flow; `Mp` without a network; `MpWorld` builds, packs and loads back | `tests/test_mp_facade.gd`, `tests/test_mp_world.gd` |
| `MpState.watch` (current value, then each change), `MpLocalSeat` (the seat on this screen, `preview_slot` solo), `MpSpawner.spawn_here` solo | `tests/test_world_helpers.gd` |
| A web client (browser) against a WebSocket dedicated | `web.sh` (headless Chrome, or open the URL by hand) |
| A web client through the relay (the server hosts a relay room) | `TRANSPORT=relay web.sh` |
| Relay: only whoever has the secret hosts (header or query); without a secret nobody, unless `RELAY_OPEN=1` | `relay.sh` |
| Relay: a room with a live host refuses a second host (4009, like a port in use) | `relay.sh` |
| Relay: a refused match is launched again on another port and only the one that listens is announced | `tests/test_launcher_relay_retry.gd` |
| Relay end to end: with every port but one taken, the private match starts on the free one and is played | `relayfault.sh` clash |
| Relay: a dedicated killed (kill -9) and started again at once gets its room back | `relayfault.sh` restart |
| Relay: with the host frozen, another dedicated is refused and stops; once the relay drops the silent one, a third gets in | `relayfault.sh` frozen |
| Visible windows: LAN, dedicated and rooms, also through the relay (`play.sh … --watch`) | `play.sh` |
| Private match: the invite in the HUD, a second click, another private match on the same PC (through the relay too) | `private.sh` **T** |
| The Leave button while the match waits for seats (paused world) | `rooms.sh` wait |
| `deploy.sh` (the commands it would run), also with `--transport relay` and the secret apart | `deploy.sh … --dry-run` |

## Not covered here (and why)

| Case | Reason |
|---|---|
| A Linux export and a real VPS | they need the Linux export templates and a test VPS |
| The relay running on Railway | it is the same `server.mjs` tested locally; Railway is not reached from here |
| Web clients through the relay with a public `wss://` | it needs the Railway domain (over a local `ws://` it is covered: `TRANSPORT=relay web.sh`) |
| A *Dedicated Server* export started without `--dedicated` | the `dedicated_server` tag only exists in an export |
