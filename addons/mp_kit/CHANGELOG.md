# MpKit changelog

Versions before 0.19.0 are in the kit repo's git history (the "MpKit 0.x.y: …" commits).

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
