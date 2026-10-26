# MpKit relay (WebSocket tunnel)

A small Node server that tunnels between your Godot server and the players. The Godot server connects **out** to the relay, so it needs no public IP and no open ports: it can run on your PC behind the router. Players (web or desktop) connect to the same relay. Railway, Render, Fly or any VPS with Node can run it.

```
web player  ─┐
PC player   ─┼── wss://your-relay.up.railway.app ──── Godot server (your PC, a VPS, anywhere)
PC player   ─┘          (room game-7777)                connects as the host of the room
```

No dependencies: `server.mjs` only needs Node 18+.

## 1. Put it on Railway

1. Make a repo (or a folder in yours) with `server.mjs` and `package.json` from this folder.
2. On Railway: **New Project › Deploy from GitHub repo** and pick that repo. Railway detects Node and runs `npm start`.
3. Under **Variables**: `RELAY_HOST_SECRET` = a long random key. Without it the relay lets nobody host.
4. Under **Settings › Networking**: **Generate Domain**. You get something like `your-relay.up.railway.app`. Railway adds TLS: the address is `wss://your-relay.up.railway.app`.
5. Healthcheck (optional): path `/health`.

Try it locally first: `PORT=8080 RELAY_HOST_SECRET=test node server.mjs` and `ws://127.0.0.1:8080`. For tests on your machine, `RELAY_OPEN=1` allows hosting without a secret; never use it on a public relay.

## 2. Set up the game

In the game's `game.tres` (an `MpGame`; or the `MpNetConfig` you use):

| Field | Value |
|---|---|
| `transport` | `relay` |
| `relay_url` | `wss://your-relay.up.railway.app` |
| `relay_room` | your game's name (`my-game`); each port is the room `my-game-<port>` |

The secret does **not** go in the `.tres` (it travels with the clients). It is one key with two names: `RELAY_HOST_SECRET` on the relay and `MPKIT_RELAY_SECRET` on the Godot server, which gets it from the environment or a flag:

```bash
MPKIT_RELAY_SECRET=the-key godot --headless --path . -- --dedicated          # a dedicated server
MPKIT_RELAY_SECRET=the-key godot --headless --path . -- --room-server        # rooms: lobby and matches through the relay
```

The matches a room server starts inherit the secret and the relay settings by themselves. Players need nothing: the menu joins with the usual address (with the relay the host part is ignored; the port picks the room).

Equivalent flags: `--transport=relay --relay-url=wss://… --relay-room=my-game --relay-secret=…`.

## 3. What it does and does not

- It passes packets between a room's host and its clients (all over WebSocket: reliable and ordered). The host is peer 1; clients get 2, 3…
- The host sends the secret in the `X-Relay-Secret` header, not in the URL, so it never lands in access logs.
- A room with a live host is **taken**, like a port in use: a second host is refused (`4009`). The kit treats it that way: a match of a room server or a private match tries the next port; a dedicated server or a lobby says the port is in use and stops. Through the relay each server searches for a port from a random one in its range, so two players opening a private match rarely meet.
- The relay pings every host every 5 s; one that does not answer for `RELAY_HOST_SILENT_MS` (15 s) is dropped (`4010`) and its room is free again. So a server that died without closing never blocks its room for good.
- A client of a room without a host is refused (`4004`); when the host leaves, its clients are closed (`4005`). The host can kick a client (`4007`): that is how "server full" and ticket admission work.
- Limits from the environment: `RELAY_MAX_CLIENTS` per room (64), `RELAY_MAX_MESSAGE` in bytes (262144).
- It stores nothing, never sees the game, never mixes rooms. Latency: the relay's hop in the middle (pick a region near your players).

## 4. Protocol (to write another relay)

Binary messages, little-endian:

| Direction | Message |
|---|---|
| relay → peer | `0x01 WELCOME u32 your_id` · `0x02 JOIN u32 id` (to the host) · `0x03 LEAVE u32 id` (to the host) · `0x04 DATA u32 from u8 channel u8 mode bytes…` |
| peer → relay | `0x04 DATA i32 to u8 channel u8 mode bytes…` (host: an id, `0` = everyone, `-id` = everyone but id; client: always to the host) · `0x05 KICK u32 id` (host only) |

Connection: `wss://relay/?role=host&room=ROOM` with the header `X-Relay-Secret: KEY` (`&secret=KEY` is accepted too), or `?role=client&room=ROOM`.

## Verified

On a Mac, with the relay running locally: arena (dedicated, LAN, late joiner, lag, flood), rooms (seven scenarios) and the private match through the relay. Railway itself was not tested from here: the relay is the same file.
