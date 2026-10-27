# MpKit issuer (rooms your players host)

A small Node + Express server that lets **players host the matches**: no game server of yours runs them, only this issuer and the relay. A player's game asks it for a room and gets a code plus a short token to host that room on the relay; friends ask it for a seat and get a token to join. It lists public rooms, keeps limits, and forgets the rooms whose host went quiet.

```
host's game ── POST /v1/rooms ─────────────► issuer (this)        signs with the Ed25519 PRIVATE key
            ◄─ code K7F3QX, host token ─────
            ── wss://relay/?role=host&room=p-K7F3QX&token=… ───► relay   checks with the PUBLIC key
friend      ── POST /v1/rooms/K7F3QX/join ─► issuer: a seat, a client token
            ── wss://relay/?role=client&room=p-K7F3QX&token=… ─► relay
```

On the Godot side it is `MpFlow.host_online()` / `join_online(code)` / `online_rooms()` (GUIDE section 10.3). A desktop host runs the match in a process of its own PC (`MpLocalServer`); a browser hosts it in its own tab and keeps simulating with the tab hidden (`MpWebKeepAlive`).

Node 20+. `npm install` once in this folder.

| File | What it does |
|---|---|
| `server.mjs` | Starts the issuer with the settings from the environment |
| `keys.mjs` | Makes the key pair: the private half for this issuer, the public half for the relay |
| `lib/config.mjs` | The environment variables and their defaults |
| `lib/tokens.mjs` | The relay tokens (JWT, EdDSA) |
| `lib/rooms.mjs` | The rules: rooms, seats, the list, versions, limits, silent hosts |
| `lib/app.mjs` | HTTP (Express): request checks, rate limits, CORS, the routes |
| `test/` | `npm test`: the rules with a fake clock, HTTP end to end, and the relay accepting these tokens |
| `Dockerfile`, `fly.toml` | To put it on Fly (or any Docker host) |

## 1. Try it on your machine

```bash
npm install
node keys.mjs                    # prints ISSUER_PRIVATE_KEY='…' and RELAY_TOKEN_KEYS='…'
```

Terminal 1, the relay (`addons/mp_kit/relay`), with the public key:

```bash
RELAY_TOKEN_KEYS='{"keys":[…]}' RELAY_HOST_SECRET=local-test PORT=8080 node server.mjs
```

Terminal 2, the issuer, with the private key:

```bash
ISSUER_PRIVATE_KEY='{…}' ISSUER_RELAY_URL=ws://127.0.0.1:8080 \
  ISSUER_GAMES='{"my-game":{"max_players":8}}' PORT=8090 node server.mjs
```

The game: `issuer_url = http://127.0.0.1:8090` and `game_id = my-game` in its `MpNetConfig` (or `--issuer-url=… --issuer-game=…`). The whole path is tested by `bash mpkit_lab/run/online.sh` in the kit repo.

## 2. Put it on Fly

1. `fly auth login`. Copy this folder (or deploy from it).
2. In `fly.toml`: `app` (a name of yours, global on Fly), `primary_region`, and under `[env]`: `ISSUER_RELAY_URL` (your relay's `wss://`), `ISSUER_GAMES`, `ISSUER_ORIGINS` (where the web build is served from).
3. `node keys.mjs` once. Keep its two lines out of the repo.
4. `fly apps create <your-app>`, then the private key through stdin (never on a command line, never in a file of the repo):
   ```bash
   printf 'ISSUER_PRIVATE_KEY=%s\n' '<the JSON keys.mjs printed>' | fly secrets import --app <your-app>
   ```
5. On the **relay**, the public key: `fly secrets set --app <your-relay> RELAY_TOKEN_KEYS='<the JSON keys.mjs printed>'` (it is public, a variable would do too), and redeploy the relay.
6. `fly deploy --ha=false` here: one machine, always on (the rooms live in its memory). `https://<your-app>.fly.dev/health` answers `ok`.

Cost: the smallest machine (256 MB) and very little traffic: the matches go through the relay, not through here.

**Rotating the key**: make a new pair; put both public keys in `RELAY_TOKEN_KEYS` (`{"keys":[old, new]}`), switch the issuer to the new private key, and remove the old public key a minute later (no token lives longer).

## 3. Settings

| Variable | Default | What it is |
|---|---|---|
| `ISSUER_PRIVATE_KEY` | (required) | The Ed25519 private JWK with its `kid`, from `keys.mjs`. A secret |
| `ISSUER_RELAY_URL` | (required) | The relay's `wss://` address: the issuer tells each player where to connect |
| `ISSUER_GAMES` | (required) | `{"<game_id>": {"min_version": "1.0.0", "max_players": 8, "max_rooms": 500}}`. Only these games get rooms |
| `ISSUER_ORIGINS` | none | Web origins allowed to call from a browser (`https://my-game.itch.io`, comma separated; `*` any). Desktop builds need none |
| `ISSUER_TRUST_PROXY` | `none` | Where the player's IP comes from: `fly` (the `Fly-Client-IP` header), `proxy` (the first `X-Forwarded-For` hop) or `none` (the connection) |
| `PORT` | `8090` | HTTP port |
| `ISSUER_TOKEN_TTL_S` | `60` | How long a relay token may wait before it is used (each one works once) |
| `ISSUER_HEARTBEAT_S` | `10` | How often a host says it is alive |
| `ISSUER_ROOM_SILENT_S` | `30` | A room whose host is silent that long is gone (a closed browser tab cannot say goodbye) |
| `ISSUER_ROOM_START_S` | `120` | A new room has this long to come up on the relay |
| `ISSUER_ROOM_MAX_S` | `21600` | The longest a room lives (6 h) |
| `ISSUER_ROOMS_PER_IP` / `ISSUER_ROOMS_PER_INSTALL` | `3` / `1` | Live rooms one IP / one install may host |
| `ISSUER_RATE_CREATE` / `_JOIN` / `_LIST` / `_HOST` | `10` / `30` / `60` / `60` | Requests per IP and minute on each kind of route |
| `ISSUER_BANNED` | none | IPs and install ids turned away, comma separated |
| `ISSUER_QUIET` | | `1`: no log lines |

The issuer refuses to start without the key, the relay URL or a game: it never runs open by mistake.

## 4. API (v1)

Every player request says who asks: `game`, `version` (the game's), `kit` (MpKit's), `platform`, `install` (random, kept by the game) and `session` (new in each process, so two copies of the game on one PC get two seats). The IP comes from the connection, never from the body. Answers are JSON; a refusal is `{"error": "<word>", …}`.

| Route | Who | What |
|---|---|---|
| `POST /v1/rooms` | host | Body: who + `name`, `max_players`, `visibility` (`public`/`private`), `mode` (`dedicated`: a match process hosts, `seats` = one admission ticket per seat but the host's; `listen`: the host's game hosts, no tickets). `201` → `code`, `room` (`p-<code>`), `relay_url`, `host_token`, `room_key` (the host's proof, shown once), `heartbeat_s`, `token_ttl_s`, `max_players` |
| `PUT /v1/rooms/:code` | host (`Authorization: Bearer <room_key>`) | Heartbeat: `players` (the host counts), `state` (`open`/`playing`), `taken` (the tickets connected). The first one makes the room **live**: before it, it is not listed and joins get `room_starting` |
| `POST /v1/rooms/:code/tokens` | host (Bearer) | `{"role": "host"|"client"}` → a fresh token (a reconnecting host; the host player of a dedicated room) |
| `DELETE /v1/rooms/:code` | host (Bearer) | Closes the room |
| `GET /v1/rooms?<who>` | player | `rooms`: the live public rooms of that game and **version** with a free seat, newest first |
| `POST /v1/rooms/:code/join` | player | Body: who. → `room`, `relay_url`, `token`, `ticket` (dedicated: the match admits it; `null` in listen), `mode`, `max_players`. The same process asking again gets the same seat while it is reserved (2 × the token's life) |
| `GET /health` | | `ok` |

Refusals: `bad_request` (400, with the `fields`), `banned` (403), `no_such_room` / `unknown_game` (404), `room_full` / `version_mismatch` (with `host_version`) / `room_starting` (409), `version_too_old` (426, with `min_version`), `too_many_rooms` / `rate_limited` (429), `no_room_left` (503), `too_large` (413). `MpFlow.online_texts` turns each into a sentence for the player.

## 5. Tokens (the contract with the relay)

A JWT signed with EdDSA (Ed25519), header `kid` = the key's id.

| Claim | Value |
|---|---|
| `iss` / `aud` | `mpkit-issuer` / `mpkit-relay` |
| `room` | `p-<code>`: the relay asks a token for these rooms, and only these |
| `role` | `host` or `client`: a token is good for that role only |
| `max` | host tokens: how many clients the relay lets in (a listen host plays, so `max_players - 1`) |
| `sub` | the install id that asked |
| `jti`, `iat`, `nbf`, `exp` | unique id, issued, not before, expiry (`ISSUER_TOKEN_TTL_S`) |

The relay checks the signature with the public key, `iss`, `aud`, `exp`, that `room` and `role` are the connection's, and spends the `jti` once the peer is seated (a host turned away because its room is busy keeps its token for the retry). A token goes in `?token=` (a browser cannot set headers) or the `X-Relay-Token` header; it works once and dies within a minute, so a URL in a log is useless to anyone.

## 6. What it does not

- It never relays game traffic: that is the relay's job. It never sees inputs or states.
- It keeps rooms in memory: one machine (a restart forgets the rooms; their matches go on, unlisted). Several machines would need a shared store (Redis) for the rooms and the rate limits.
- It does not stop a host from cheating: the host's game is the authority of its match. Competitive games against strangers want a dedicated server (GUIDE 13).
- A browser host on a phone freezes when the browser goes to the background (mobile browsers stop hidden tabs entirely); its players see "Waiting for the host…" (`MpKit.host_silent`) and give up after `MpFlow.host_silent_timeout_s`.
