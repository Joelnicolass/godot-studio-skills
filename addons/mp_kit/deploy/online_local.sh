#!/usr/bin/env bash
# A local MpKit issuer and relay for your game's online tests, on this PC: never production. Starts both from this
# project's addons/mp_kit (copied to a cache folder, so npm never writes into addons/), with a key pair and a relay host
# secret made for this run (nothing is written to the project), and the issuer serving your game. Prints the commands
# for the game's copies and keeps running until Ctrl+C, which stops both.
#
#   bash addons/mp_kit/deploy/online_local.sh <game_id> [max_players]
#
# <game_id>: your MpNetConfig's game_id (the key the issuer serves). max_players: 4 by default.
# Environment: RELAY_PORT (8890), ISSUER_PORT (8891), WEB_ORIGINS (the pages a browser build may come from;
# http://127.0.0.1:8892), GODOT (the Godot binary), ONLINE_CACHE (where mpkit_online/ goes, with the issuer and the
# relay installed; default $TMPDIR). Needs Node 20+, npm and openssl.
set -euo pipefail

GAME="${1:-}"
PLAYERS="${2:-4}"
if [ -z "$GAME" ]; then
  echo "Usage: bash addons/mp_kit/deploy/online_local.sh <game_id> [max_players]" >&2
  exit 2
fi
KIT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$(cd "$KIT/../.." && pwd)"
RELAY_PORT="${RELAY_PORT:-8890}"
ISSUER_PORT="${ISSUER_PORT:-8891}"
WEB_ORIGINS="${WEB_ORIGINS:-http://127.0.0.1:8892}"
GODOT="${GODOT:-godot}"
CACHE="${ONLINE_CACHE:-${TMPDIR:-/tmp}}"; CACHE="${CACHE%/}/mpkit_online"
ISSUER_URL="http://127.0.0.1:$ISSUER_PORT"
PIDS=()

stop_all() {
  for pid in "${PIDS[@]:-}"; do
    [ -n "$pid" ] && kill "$pid" 2>/dev/null || true
  done
}
trap stop_all EXIT
trap 'exit 130' INT TERM

## A copy of the kit's server folder in the cache, with its packages from the lockfile (again when the lockfile changed).
install_server() {
  local name="$1"
  mkdir -p "$CACHE/$name"
  rsync -a --delete --exclude node_modules --exclude .gdignore "$KIT/$name/" "$CACHE/$name/"
  if [ ! -d "$CACHE/$name/node_modules" ] || ! cmp -s "$KIT/$name/package-lock.json" "$CACHE/$name/.installed-lock"; then
    npm ci --prefix "$CACHE/$name" --silent --no-fund --no-audit
    cp "$KIT/$name/package-lock.json" "$CACHE/$name/.installed-lock"
  fi
}

wait_health() {
  local port="$1" name="$2"
  for _ in $(seq 100); do
    curl -fs "http://127.0.0.1:$port/health" > /dev/null 2>&1 && return 0
    sleep 0.1
  done
  echo "FAIL: the $name on port $port did not start (log: $CACHE/$name.log)" >&2
  exit 1
}

install_server issuer
install_server relay

## ISSUER_PRIVATE_KEY (the issuer only) and RELAY_TOKEN_KEYS (the relay: public), fresh for this run.
eval "$(node "$CACHE/issuer/keys.mjs")"
RELAY_HOST_SECRET="$(openssl rand -hex 24)"

PORT="$RELAY_PORT" RELAY_HOST_SECRET="$RELAY_HOST_SECRET" RELAY_TOKEN_KEYS="$RELAY_TOKEN_KEYS" RELAY_QUIET=1 \
  node "$CACHE/relay/server.mjs" > "$CACHE/relay.log" 2>&1 &
PIDS+=($!)
wait_health "$RELAY_PORT" relay

ISSUER_PRIVATE_KEY="$ISSUER_PRIVATE_KEY" ISSUER_RELAY_URL="ws://127.0.0.1:$RELAY_PORT" PORT="$ISSUER_PORT" \
  ISSUER_GAMES="{\"$GAME\":{\"max_players\":$PLAYERS}}" ISSUER_ORIGINS="$WEB_ORIGINS" \
  ISSUER_ROOMS_PER_IP=10 ISSUER_RATE_LIST=600 ISSUER_RATE_JOIN=120 \
  node "$CACHE/issuer/server.mjs" > "$CACHE/issuer.log" 2>&1 &
PIDS+=($!)
wait_health "$ISSUER_PORT" issuer

cat <<INFO
MPKIT LOCAL ONLINE UP: issuer $ISSUER_URL and relay ws://127.0.0.1:$RELAY_PORT for "$GAME" (logs in $CACHE). Ctrl+C stops both.

Each copy needs --issuer-url (without it the game talks to the issuer in its game.tres) and its own --issuer-install
(16 to 64 letters, digits, - or _), or the issuer counts them as one PC:
  Host:     "$GODOT" --path "$PROJECT" -- --issuer-url=$ISSUER_URL --issuer-install=$GAME-local-host-0001
  Friend:   "$GODOT" --path "$PROJECT" -- --issuer-url=$ISSUER_URL --issuer-install=$GAME-local-friend-01
Bad network (a host's match process too): ... --net-lag-ms=50 --net-loss=0.02 --match-args=--net-lag-ms=50,--net-loss=0.02
Web build: serve it from one of $WEB_ORIGINS and open it with ?issuer=$ISSUER_URL in the address.
INFO

wait
