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
| Dedicated servers without a lobby (join with IP and port) | `--dedicated 7777,7778` |
| Web clients | `--transport ws` (the lobby and the matches over TCP) |
| The script to open the ports | `--open-firewall` (ufw: UDP with ENet, TCP with WebSocket) |

Several matches at once on one room server is automatic: each full room starts its own process, up to `max_matches` of the `MpLobbyConfig` (or `--max-matches=N`). Every number of the `MpLobbyConfig` can be overridden by a flag with its name; for one instance, put it in `EXTRA_ARGS` of `/etc/game/rooms-7700.env` and restart.

## 3. Operate

```bash
ssh user@my-vps journalctl -u 'game-rooms@*' -f      # live logs: rooms, matches, results
ssh user@my-vps sudo systemctl restart game-rooms@7700
ssh user@my-vps sudo systemctl disable --now game-rooms@7701
```

If the room server goes down, systemd brings it back and its matches close by themselves within seconds (`parent_check_s`). A player who drops gets their seat back within `rejoin_grace_s`.

## Web over https

A page served over `https` only opens `wss://`. For a dedicated without a lobby, `MpNetConfig.tls_certificate` and `tls_key` on the server and `tls_client` on the client are enough. The lobby does not take TLS yet: rooms with web clients served over https need a proxy per port, or serve the page over http meanwhile.

## Verified and not verified

Verified on a Mac: several `--room-server` instances side by side with their ranges (the lab e2e `run_mpkit_instances.sh`), rooms, private matches and web. Not verified: the Linux export (that Mac lacks the templates) and a real VPS.
