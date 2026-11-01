#!/usr/bin/env bash
# MpKit e2e: how an online room's match starts and takes late players (no game code), through the MpKit issuer and relay run
# here, as online.sh does. Part 1, late join: a desktop host opens a room for 3 with `--start-on-timeout=false --late-join`;
# its match still waits past the load timeout, the host starts it alone with the HUD's Start button, a bot (in the match
# process: --match-args) walks each free seat, and a late player finds the running room in the list, takes a bot's seat
# (joined_late) and gets that pawn where the bot left it, moved by its own keys from then on; the host wins. Part 2, no late
# join: a room for 3 starts by time with the host alone, then leaves the issuer's list and hands out no more seats.
# Never more than 3 headless Godot at once (a match process counts). Needs npm (the issuer's and relay's packages).
# Prints PASS / FAIL lines and MPKIT LATE PASS / MPKIT LATE FAIL (exit 0 / 1).
. "$(dirname "$0")/lib.sh"
net_group 3 "$@"
TAG="MPKIT LATE"
LIMIT_S="${PROBE_LIMIT_S:-240}"
PROC_MAX=3
TRANSPORT=relay
OUT="$(mktemp -d "${TMPDIR:-/tmp}/mpkit_late.XXXXXX")"
MATCHES="$OUT/matches"
ISSUER_DIR="$LAB/addons/mp_kit/issuer"
ISSUER_PORT="${ISSUER_PORT:-$((RELAY_PORT + 1))}"
ISSUER="http://127.0.0.1:$ISSUER_PORT"
kill_stray() {
  local p
  for p in $(ps -axo pid=,args= | awk -v m="$MATCHES" '$2 ~ /\/Godot$/ && index($0, m) {print $1}'); do kill "$p" 2>/dev/null; done
}
trap 'kill_pids; kill_stray; net_stop' EXIT
net_guard

[ -d "$ISSUER_DIR/node_modules/jose" ] || npm ci --prefix "$ISSUER_DIR" --silent --no-fund --no-audit || echo "FAIL npm ci for the issuer"
relay_deps || echo "FAIL npm ci for the relay"
eval "$(node "$ISSUER_DIR/keys.mjs")"
export RELAY_TOKEN_KEYS
RELAY_QUIET=0 relay_up
GAME="lab$$"
## A heartbeat a second: the issuer hears soon that a match started.
ISSUER_PRIVATE_KEY="$ISSUER_PRIVATE_KEY" ISSUER_RELAY_URL="ws://127.0.0.1:$RELAY_PORT" PORT="$ISSUER_PORT" \
  ISSUER_GAMES="{\"$GAME\":{\"max_players\":8}}" ISSUER_ROOMS_PER_IP=10 ISSUER_RATE_LIST=600 ISSUER_RATE_JOIN=120 \
  ISSUER_RATE_HOST=600 ISSUER_HEARTBEAT_S=1 node "$ISSUER_DIR/server.mjs" > "$OUT/issuer.log" 2>&1 &
echo $! >> "$OUT/pids"
python3 - "$ISSUER_PORT" <<'PYEOF' || echo "FAIL the issuer did not start"
import sys, time, urllib.request
for _ in range(100):
    try:
        urllib.request.urlopen("http://127.0.0.1:%s/health" % sys.argv[1], timeout=0.5); sys.exit(0)
    except Exception:
        time.sleep(0.1)
sys.exit(1)
PYEOF

COMMON=(--issuer-url="$ISSUER" --probe-timeout-s=45 --matches-root="$MATCHES" --result-quit-delay-s=1 --load-timeout-s=2)
CODE1="$OUT/code1.txt"
CODE2="$OUT/code2.txt"

echo "--- part 1: late join; the host starts its room alone, bots play the free seats, a late player takes one"
gd "$OUT/starter.log" -- "${COMMON[@]}" --probe=online_starter --online-mode=dedicated --probe-players=3 \
  --late-join --start-on-timeout=false --probe-code-file="$CODE1" --probe-wait-file="$OUT/go1" \
  --match-args="--probe=botseat,--probe-no-quit,--probe-timeout-s=60,--probe-copy-file=$OUT/botseat.txt" \
  --issuer-install=lab-starter-install-1
STARTER=$LAST_PID
wait_line "$OUT/starter.log" "^PASS the host started the match" "$STARTER" 90
gd "$OUT/late.log" -- "${COMMON[@]}" --probe=online_late --probe-code-file="$CODE1" --probe-go-file="$OUT/go1" \
  --issuer-install=lab-late-install-00001
LATE=$LAST_PID
for p in $LATE $STARTER; do wait_pid "$p" 120; done
wait_gone "match-ticket-file=$MATCHES" 15

echo "--- part 2: no late join; a room for 3 starts by time with the host alone and leaves the list"
gd "$OUT/closed.log" -- "${COMMON[@]}" --probe=online_starter --online-mode=dedicated --probe-players=3 \
  --probe-start-by=timeout --probe-expect-closed --probe-code-file="$CODE2" --issuer-install=lab-closed-install-01
wait_pid "$LAST_PID" 90
wait_gone "match-ticket-file=$MATCHES" 15

for r in starter late closed; do [ -f "$OUT/$r.log" ] || continue; grep -E "^(PASS|FAIL|SCRIPT ERROR)" "$OUT/$r.log" | sed "s/^/$r: /"; done
[ -f "$OUT/botseat.txt" ] && sed "s/^/botseat: /" "$OUT/botseat.txt"
FAILS=0
check() { if eval "$1"; then echo "PASS $2"; else echo "FAIL $2"; FAILS=$((FAILS + 1)); fi; }
check 'grep -q "^PASS .* past the load timeout it still waits" "$OUT/starter.log"' "with start_on_timeout off the match waited past the load timeout"
check 'grep -q "^PASS the host started the match: it runs" "$OUT/starter.log"' "the host started its room alone with the Start button (late join)"
check 'grep -q "^PROBE online_starter PASS" "$OUT/starter.log"' "the host saw the bots, then scored and won"
check 'grep -q "^PASS bots play the vacant seats" "$OUT/botseat.txt" 2>/dev/null' "the match process put a bot in each vacant seat (vacant_slots, MpInput.bot_press)"
check 'grep -q "^PASS a player took a bot.s seat (joined_late)" "$OUT/botseat.txt" 2>/dev/null && grep -q "^PASS seat .*(has_player)" "$OUT/botseat.txt"' "the server heard the late player (joined_late) and the seat's input became the player's"
check 'grep -q "^PASS the running room is still in the list, as playing" "$OUT/late.log"' "the running room stayed listed as playing (late join)"
check 'grep -q "^PASS the match let it in" "$OUT/late.log"' "the late player was let in after the start (not rejected)"
check 'grep -q "^PASS the pawn is where the bot walked it" "$OUT/late.log" && grep -q "^PASS its own keys move it left" "$OUT/late.log"' "it took the bot's pawn as it was and moved it with its own keys"
check 'grep -q "^PROBE online_late PASS" "$OUT/late.log"' "the late player saw the match end"
check 'grep -q "^PASS the started room left the issuer.s list" "$OUT/closed.log" && grep -q "^PASS a join of the started room is full" "$OUT/closed.log"' "without late join the started room left the list and handed out no more seats"
check 'grep -q "^PROBE online_starter PASS" "$OUT/closed.log"' "the host of that room closed it cleanly"
check '! grep -q "refused" "$OUT/relay.log"' "the relay refused no token of this run"
check '! grep -q "^SCRIPT ERROR" "$OUT"/*.log' "no script errors"
check '[ "$(godots_with "$MATCHES")" = 0 ]' "no match process left"
net_stop
echo "--- verdict (logs in $OUT) ---"
if [ "$FAILS" = 0 ]; then echo "$TAG PASS"; exit 0; fi
echo "$TAG FAIL: $FAILS"
exit 1
