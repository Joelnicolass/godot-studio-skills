#!/usr/bin/env bash
# MpKit's server image (addons/mp_kit/deploy/fly/Dockerfile, what deploy/fly.sh deploys) end to end, with Docker on
# this machine. The lab project is built into the image exactly as a game is; the container connects out to a relay
# on this machine, as on Fly, and players here join through it:
#   dedicated   the container runs `--dedicated`: a player joins and plays (moves, scores)
#   rooms       the container runs `--room-server` (its match processes start inside the container): two players
#               meet in the lobby, the room fills, and they play the match it starts
# Without Docker running it says MPKIT DOCKER SKIP. Prints PASS / FAIL lines and MPKIT DOCKER PASS / FAIL.
. "$(dirname "$0")/lib.sh"
TAG="MPKIT DOCKER"
if ! docker info >/dev/null 2>&1; then echo "$TAG SKIP (Docker is not running)"; exit 0; fi
export TRANSPORT=relay
LIMIT_S="${PROBE_LIMIT_S:-300}"
PROC_MAX=6
OUT="$(mktemp -d "${TMPDIR:-/tmp}/mpkit_docker.XXXXXX")"
IMAGE="mpkit-lab-server:$$"
CONTAINERS=()
cleanup() {
  local c
  for c in "${CONTAINERS[@]}"; do docker rm -f "$c" >/dev/null 2>&1; done
  docker rmi -f "$IMAGE" >/dev/null 2>&1
  kill_pids
  net_stop
}
trap cleanup EXIT
net_guard
FAILS=0
check() { if eval "$1"; then echo "PASS $2"; else echo "FAIL $2"; FAILS=$((FAILS + 1)); fi; }

RELAY_QUIET=0 relay_up
## The relay as the container sees it (the host machine) and the room prefix every process here also uses.
ROOM="lab$$"
RELAY_FROM_CONTAINER="ws://host.docker.internal:$RELAY_PORT"
GODOT_VERSION="$("$GODOT" --version | sed -E 's/^([0-9]+\.[0-9]+(\.[0-9]+)?)\..*/\1/')"

echo "--- build (Godot $GODOT_VERSION, the lab project as the build context) ---"
## Symlinks (mpkit_lab/addons/mp_kit) resolved: the image gets real files, as a game's folder has.
rsync -aL --exclude .godot --exclude node_modules "$LAB/" "$OUT/project/"
if docker build -q -f "$LAB/addons/mp_kit/deploy/fly/Dockerfile" --build-arg GODOT_VERSION="$GODOT_VERSION" \
    -t "$IMAGE" "$OUT/project" > "$OUT/build.log" 2>&1; then
  echo "PASS the image builds (official Godot $GODOT_VERSION, checked against SHA512-SUMS, project imported)"
else
  echo "FAIL the image builds"; tail -n 20 "$OUT/build.log"; echo "$TAG FAIL: 1"; exit 1
fi

container() { # container <name> <GAME_ARGS>: the server image, as fly.toml runs it
  local name="mpkit-lab-$$-$1"
  docker run -d --name "$name" --add-host=host.docker.internal:host-gateway \
    -e MPKIT_RELAY_SECRET="$RELAY_SECRET" -e GAME_ARGS="$2" "$IMAGE" > /dev/null
  CONTAINERS+=("$name")
  LAST_CONTAINER="$name"
}
container_line() { # container_line <name> <regex> <timeout_s>
  for _ in $(seq 1 $(( $3 * 10 ))); do docker logs "$1" 2>&1 | grep -qE "$2" && return 0; sleep 0.1; done
  return 1
}

echo "--- dedicated in the container ---"
container dedicated "--dedicated --mp-port=7795 --start-seats=1 --transport=relay --relay-url=$RELAY_FROM_CONTAINER --relay-room=$ROOM"
DED=$LAST_CONTAINER
for _ in $(seq 1 300); do grep -q "host $ROOM-7795\$" "$OUT/relay.log" && break; sleep 0.1; done
check 'grep -q "host $ROOM-7795\$" "$OUT/relay.log"' "the dedicated in the container hosts its relay room (it connects out, no port)"
gd "$OUT/player.log" -- --client1 --transport=relay --mp-port=7795 --probe=basic --probe-timeout-s=30
wait_line "$OUT/player.log" "^PROBE basic (PASS|FAIL)" "$LAST_PID" 60
check 'grep -q "^PROBE basic PASS" "$OUT/player.log"' "a player here joined the dedicated through the relay and played"
docker logs "$DED" > "$OUT/dedicated.log" 2>&1
docker rm -f "$DED" > /dev/null 2>&1

echo "--- room server in the container ---"
container rooms "--room-server --lobby-port=7700 --match-port-min=7800 --match-port-max=7899 --matches-root=/home/game/matches --countdown-s=0.3 --result-quit-delay-s=1 --heartbeat-s=0.5 --poll-s=0.1 --transport=relay --relay-url=$RELAY_FROM_CONTAINER --relay-room=$ROOM"
ROOMS=$LAST_CONTAINER
container_line "$ROOMS" "^rooms ready port 7700" 60
check 'docker logs "$ROOMS" 2>&1 | grep -q "^rooms ready port 7700"' "the room server in the container is ready (lobby room $ROOM-7700)"
CLIENT=(--transport=relay --probe=lobby --probe-lobby=127.0.0.1:7700 --probe-timeout-s=40)
gd "$OUT/Ana.log" -- "${CLIENT[@]}" --probe-name=Ana --probe-create=Arena
ANA=$LAST_PID
wait_line "$OUT/Ana.log" "^PASS took a seat" "$ANA" 40
gd "$OUT/Bea.log" -- "${CLIENT[@]}" --probe-name=Bea
BEA=$LAST_PID
wait_line "$OUT/Ana.log" "^PROBE lobby (PASS|FAIL)" "$ANA" 90
wait_line "$OUT/Bea.log" "^PROBE lobby (PASS|FAIL)" "$BEA" 30
docker logs "$ROOMS" > "$OUT/rooms.log" 2>&1
check 'grep -qE "^match for room .* on port 78[0-9][0-9]" "$OUT/rooms.log"' "the room server started the match as a process inside the container"
check 'grep -q "^PROBE lobby PASS" "$OUT/Ana.log" && grep -q "^PROBE lobby PASS" "$OUT/Bea.log"' "two players here met in its lobby and played the match through the relay"
check '! grep -q "^SCRIPT ERROR" "$OUT"/*.log' "no script errors (here or in the container)"
for f in dedicated rooms; do grep -hE "^(rooms|room|match|SCRIPT ERROR)" "$OUT/$f.log" 2>/dev/null | sed "s/^/   $f: /" | head -n 6; done
for n in player Ana Bea; do grep -hE "^(FAIL|SCRIPT ERROR)" "$OUT/$n.log" | sed "s/^/   $n: /" | head -n 4; done
echo "--- verdict (logs in $OUT) ---"
if [ "$FAILS" = 0 ]; then echo "$TAG PASS"; exit 0; fi
echo "$TAG FAIL: $FAILS"
exit 1
