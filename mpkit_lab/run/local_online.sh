#!/usr/bin/env bash
# The kit's local online tool (addons/mp_kit/deploy/online_local.sh), as a game uses it: it brings up an issuer and a
# relay for a game id, says so, and the issuer serves that game (a room is created) and no other. No Godot process.
# Needs Node 20+, npm and openssl. Prints PASS / FAIL lines and MPKIT LOCAL ONLINE PASS / FAIL (exit 0 / 1).
. "$(dirname "$0")/lib.sh"
TAG="MPKIT LOCAL ONLINE"
OUT="$(mktemp -d "${TMPDIR:-/tmp}/mpkit_local_online.XXXXXX")"
RELAY_PORT="${LOCAL_RELAY_PORT:-8990}"
ISSUER_PORT="${LOCAL_ISSUER_PORT:-8991}"
RELAY_PORT=$RELAY_PORT ISSUER_PORT=$ISSUER_PORT ONLINE_CACHE="$OUT" \
  bash "$LAB/addons/mp_kit/deploy/online_local.sh" lablocal 3 > "$OUT/tool.log" 2>&1 &
TOOL=$!
trap 'kill_tree $TOOL' EXIT
for _ in $(seq 600); do
  grep -q "MPKIT LOCAL ONLINE UP" "$OUT/tool.log" 2>/dev/null && break
  kill -0 $TOOL 2>/dev/null || break
  sleep 0.2
done
FAILS=0
check() { if eval "$1"; then echo "PASS $2"; else echo "FAIL $2"; FAILS=$((FAILS + 1)); fi; }
check 'grep -q "MPKIT LOCAL ONLINE UP" "$OUT/tool.log"' "the tool says the issuer and the relay are up"
check 'curl -fs "http://127.0.0.1:$RELAY_PORT/health" > /dev/null' "the relay answers"
room() { # room <game> -> the HTTP status of a room asked for that game
  curl -s -o "$OUT/room.json" -w "%{http_code}" -X POST "http://127.0.0.1:$ISSUER_PORT/v1/rooms" \
    -H "content-type: application/json" \
    -d "{\"game\":\"$1\",\"version\":\"1\",\"kit\":\"0.28.0\",\"platform\":\"lab\",\"install\":\"lab-local-online-01\",\"session\":\"lab-session-01\",\"name\":\"Lab\",\"max_players\":3,\"visibility\":\"private\",\"mode\":\"listen\"}"
}
check '[ "$(room lablocal)" = 201 ] && grep -q "\"code\"" "$OUT/room.json"' "the issuer serves the game it was given (a room)"
check '[ "$(room othergame)" = 404 ]' "and no other game (unknown_game)"
check 'grep -q -- "--issuer-url=http://127.0.0.1:$ISSUER_PORT" "$OUT/tool.log"' "it prints the commands for the game's copies"
kill_tree $TOOL
echo "--- verdict (logs in $OUT) ---"
if [ "$FAILS" = 0 ]; then echo "$TAG PASS"; exit 0; fi
echo "$TAG FAIL: $FAILS"
exit 1
