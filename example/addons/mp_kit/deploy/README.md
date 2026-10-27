# Deploying an MpKit server on a VPS

One Linux binary does everything: client, room server (`--room-server`) and every match (`--dedicated`, started by the room server). On the VPS it runs under systemd, and several instances are several units.

## What you need

- A Linux x86_64 VPS with systemd (Ubuntu or Debian) and a user with `sudo` you reach over SSH.
- On your PC: the Linux export templates of your Godot version (Editor → Manage Export Templates).
- In the project: `MpFlow` with `room_server_path` pointing at your scene with `MpRoomServer` (for the lobby) and an `MpNetConfig`.

## 1. Export

Copy the presets of [export_presets.example.cfg](export_presets.example.cfg) into your `export_presets.cfg` (or create them in Project → Export) and export:

```bash
godot --headless --path . --export-release "Linux Server" build/server/game.x86_64
```

You get `game.x86_64` and `game.pck`, which go together.

## 2. Upload and install (one command)

```bash
addons/mp_kit/deploy/deploy.sh user@my-vps build/server --rooms 7700 --open-firewall
```

That creates the `game` user, copies the build to `/opt/game`, installs the units and starts `game-rooms@7700` (lobby on 7700, matches on 7800-7899). Run it again to update: it copies what is new and restarts everything. Try it first with `--dry-run`, which only prints the commands.

| You want | Option |
|---|---|
| More room servers on the same VPS | `--rooms 7700,7701,7702` (each gets 100 match ports of its own: 7800, 7900, 8000…) |
| Dedicated servers without a lobby (join with IP and port) | `--dedicated 7777,7787` (without `--rooms`, no rooms are installed; the LAN search uses 7778-7781) |
| Web clients | `--transport ws` (the lobby and the matches over TCP) |
| The script to open the ports | `--open-firewall` (ufw: UDP with ENet, TCP with WebSocket) |
| Web clients over https (`wss://`) | `--transport ws --tls-cert /etc/letsencrypt/live/DOMAIN/fullchain.pem --tls-key /etc/letsencrypt/live/DOMAIN/privkey.pem` |

Several matches at once on one room server is automatic: each full room starts its own process, up to `max_matches` of the `MpLobbyConfig` (or `--max-matches=N`). Every number of the `MpLobbyConfig` can be overridden by a flag with its name; for one instance, put it in `EXTRA_ARGS` of `/etc/game/rooms-7700.env` and restart.

## 3. Operate

```bash
ssh user@my-vps journalctl -u 'game-rooms@*' -f      # live logs: rooms, matches, results
ssh user@my-vps sudo systemctl restart game-rooms@7700
ssh user@my-vps sudo systemctl disable --now game-rooms@7701
```

If the room server goes down, systemd brings it back and its matches close by themselves within seconds (`parent_check_s`). A player who drops gets their seat back within `rejoin_grace_s`.

## Web over https

A page served over `https` only opens `wss://`. On the server, `deploy.sh … --transport ws --tls-cert … --tls-key …` (or `tls_certificate_path` / `tls_key_path` in the `MpLobbyConfig`, or the `--tls-certificate-path=` and `--tls-key-path=` flags): the lobby and every match use that certificate. On the client, `MpNetConfig.tls_client` on and the address of the certificate's domain (`game.example.com:7700`). The service user must be able to read the certificate and the key (with Let's Encrypt, for example, a group allowed into `/etc/letsencrypt/live` and `archive`).

## Relay (no open ports)

With `transport = relay` the server connects out to the relay: the VPS opens no port (`--open-firewall` opens nothing). The secret comes from `MPKIT_RELAY_SECRET` on **your** machine and is kept in `/etc/NAME/relay.env`, which only the service user reads; a redeploy without the variable leaves it alone.

```bash
MPKIT_RELAY_SECRET=the-key addons/mp_kit/deploy/deploy.sh user@vps build/server --rooms 7700 \
  --transport relay --relay-url wss://your-relay.up.railway.app
```

`--relay-room NAME` changes the prefix of the relay rooms if you do not want the game's. How to put the relay up: [../relay/README.md](../relay/README.md).

## Without a VPS: Fly.io

The same server on a Fly.io machine you never log into: no VPS, no export templates, no open port (it connects out to the relay). One command from your project folder:

```bash
MPKIT_RELAY_SECRET=<the relay's secret> addons/mp_kit/deploy/fly.sh --app my-game-server --relay-url wss://my-relay.fly.dev
```

It writes `fly.toml` in your project (from [fly/fly.toml](fly/fly.toml)), creates the app, stores the secret as a Fly secret through stdin, and deploys: Fly builds [fly/Dockerfile](fly/Dockerfile), which downloads the official headless Godot of your version (checked against the release's SHA-512 sums), copies your project, imports it once and runs `godot --headless --path /app -- --room-server …`. `--dedicated PORT` for a plain dedicated, `--region`, `--memory`, `--godot X.Y.Z`, `--dry-run`. The whole walkthrough (what you need, checking, updating, cost, useful commands, problems): [GUIDE 13.6](../GUIDE.md#136-without-a-vps-flyio).

To try the image on your PC first (Docker): `mpkit_lab/run/docker.sh` in the kit's repo builds it from the lab and plays through a dedicated and a room server in containers.

## Verified and not verified

Verified on a Mac: several `--room-server` instances side by side with their ranges (the lab e2e `run_mpkit_instances.sh`), rooms, private matches and web. Not verified: the Linux export (that Mac lacks the templates) and a real VPS.
