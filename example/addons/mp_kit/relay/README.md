# MpKit relay (WebSocket tunnel)

A small Node server that tunnels between your Godot server and the players. The Godot server connects **out** to the relay, so it needs no public IP and no open ports: it can run on your PC behind the router. Players (web or desktop) connect to the same relay. Railway, Render, Fly or any VPS with Node can run it.

```
web player  ─┐
PC player   ─┼── wss://your-relay.up.railway.app ──── Godot server (your PC, a VPS, anywhere)
PC player   ─┘          (room game-7777)                connects as the host of the room
```

Node 18+ and one dependency, [`ws`](https://github.com/websockets/ws) (the usual WebSocket library for Node): run `npm install` once in this folder. The code is short and split by job:

| File | What it does |
|---|---|
| `server.mjs` | Starts the relay with the settings from the environment |
| `lib/config.mjs` | The environment variables and their defaults |
| `lib/protocol.mjs` | The binary messages and close codes (section 4) |
| `lib/rooms.mjs` | The rules: who hosts a room, who joins, where each message goes, silent hosts |
| `lib/relay.mjs` | HTTP, `/health`, the host secret, each WebSocket handed to the rules |
| `test/` | `npm test`: the rules with fake peers, and the relay end to end |

## 1. Put it on Railway

1. Make a repo (or a folder in yours) with this folder's files: `server.mjs`, `lib/`, `package.json` and `package-lock.json` (not `node_modules/`).
2. On Railway: **New Project › Deploy from GitHub repo** and pick that repo. Railway detects Node, installs `ws` and runs `npm start`.
3. Under **Variables**: `RELAY_HOST_SECRET` = a long random key. Without it the relay lets nobody host.
4. Under **Settings › Networking**: **Generate Domain**. You get something like `your-relay.up.railway.app`. Railway adds TLS: the address is `wss://your-relay.up.railway.app`.
5. Healthcheck (optional): path `/health`.

Try it locally first: `npm install`, then `PORT=8080 RELAY_HOST_SECRET=test node server.mjs` and `ws://127.0.0.1:8080`. For tests on your machine, `RELAY_OPEN=1` allows hosting without a secret; never use it on a public relay.

### Or on Fly.io (a region near your players, e.g. São Paulo)

Fly has regions Railway does not (`gru` for South America; Railway's are in the US, Europe and Asia). [relay-godot](https://github.com/Joelnicolass/relay-godot) has these same files and the `Dockerfile` + `fly.toml` for Fly, ready to clone.

1. Install `flyctl` and log in: `fly auth login`.
2. In `fly.toml`, set `app` to a name of yours (it is global on Fly) and `primary_region` to the region nearest your players (`fly platform regions`).
3. `fly apps create <your-app>`, then the host secret (never in a file of the repo): `fly secrets set --app <your-app> RELAY_HOST_SECRET=<a long random key>`.
4. `fly deploy --ha=false`: one machine (rooms live in its memory). The address is `wss://<your-app>.fly.dev`; `/health` answers `ok`.

`fly.toml` keeps the machine on (`auto_stop_machines = "off"`, `min_machines_running = 1`): an idle stop would cut the open WebSockets. Cost: the smallest machine plus outbound traffic per GB; the kit's arena example moves about 0.15 GB per player per hour through the relay.

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
| peer → relay | `0x04 DATA i32 to u8 channel u8 mode bytes…` (host: an id, `0` = everyone, `-id` = everyone but id; client: always to the host) · `0x05 KICK u32 id [reason]` (host only; the relay closes that client with `4007` and the reason, so it learns why it was turned away) |

Connection: `wss://relay/?role=host&room=ROOM` with the header `X-Relay-Secret: KEY` (`&secret=KEY` is accepted too), or `?role=client&room=ROOM`.

## 5. Useful commands

A host secret (copy it into the relay and into the Godot server, nowhere else):

```bash
openssl rand -hex 24
```

The relay on your machine:

```bash
npm install --prefix addons/mp_kit/relay    # once: the ws dependency
npm test --prefix addons/mp_kit/relay       # the relay's own tests
PORT=8080 RELAY_HOST_SECRET=test node addons/mp_kit/relay/server.mjs   # ws://127.0.0.1:8080
RELAY_OPEN=1 PORT=8080 node addons/mp_kit/relay/server.mjs             # anyone may host: local tests only
curl http://127.0.0.1:8080/health   # ok
```

On Fly.io (`<your-app>` = `app` in `fly.toml`):

```bash
fly auth login
fly apps create <your-app>
fly secrets set --app <your-app> RELAY_HOST_SECRET=<key>   # add --stage before the first deploy
fly deploy --ha=false                 # deploy or update, one machine
fly status --app <your-app>           # the machine, its region, the /health check
fly logs --app <your-app>             # live log: hosts in, refused hosts, rooms
curl https://<your-app>.fly.dev/health   # ok
fly secrets list --app <your-app>     # names and digests, never the values
fly scale count 0 --app <your-app>    # stop it (no machine billed)
fly scale count 1 --app <your-app>    # start it again
fly platform regions                  # region codes (gru = São Paulo)
fly apps destroy <your-app>           # remove it for good
```

On Railway: **Variables** (`RELAY_HOST_SECRET`), **Deployments › View logs**, **Settings › Networking** (the domain).

The Godot server through the relay (the secret by environment, never in the `.tres`):

```bash
MPKIT_RELAY_SECRET=<key> godot --headless --path . -- --dedicated --transport=relay --relay-url=wss://<your-relay> --relay-room=my-game
MPKIT_RELAY_SECRET=<key> godot --headless --path . -- --room-server   # with relay_url / relay_room in game.tres
```

Check the relay's rules from the kit repo: `bash mpkit_lab/run/relay.sh` (host secret, busy room) and `bash mpkit_lab/run/relayfault.sh` (a host that dies, freezes or restarts); the whole game through a local relay: `TRANSPORT=relay bash mpkit_lab/run/arena.sh`.

## Verified

With the relay running locally: arena (dedicated, LAN, rejoin, lag, flood), rooms (seven scenarios) and the private match through the relay. On Fly.io (`gru`), tested from Argentina: arena, rooms, the private match and a web client pass through it; the kit measured a 59 ms round trip through the relay (Railway, in the US: about 300 ms).
