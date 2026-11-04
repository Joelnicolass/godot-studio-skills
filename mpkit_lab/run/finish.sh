#!/usr/bin/env bash
# MpKit end of a private match e2e, in mpkit_lab: a host starts MpLocalServer, a friend joins with the code and keeps its end
# screen up like a game that waits for a click; the host wins. MODE (default: every one):
#   quit   stay_after_finish_s 0: the match process closes result_quit_delay_s after the result, the friend is back on the
#          menu and nobody hears «server lost»
#   leave  --stay-after-finish-s=30: the match is still up past result_quit_delay_s, the friend leaves on its click and the
#          process closes then, long before 30 s
#   again  the same, but the host opens a new private match while the friend still reads: the finished one gives way and the
#          friend is back on the menu without «server lost»
#   online again, through an online room (MpOnline): the MpKit issuer and relay run here, as in online.sh (needs npm)
# TRANSPORT=ws|relay runs the private modes over WebSocket or the relay. Prints PASS / FAIL lines and MPKIT FINISH PASS / FAIL
# (exit 0 / 1).
. "$(dirname "$0")/lib.sh"
net_group 3 "$@"
TAG="MPKIT FINISH"
LIMIT_S="${PROBE_LIMIT_S:-240}"
PROC_MAX=4
TRANSPORT="${TRANSPORT:-enet}"
MODES="${MODE:-quit leave again online}"
OUT="$(mktemp -d "${TMPDIR:-/tmp}/mpkit_finish.XXXXXX")"
kill_stray() {
  local p
  for p in $(ps -axo pid=,args= | awk -v m="$OUT" '$2 ~ /\/Godot$/ && index($0, m) {print $1}'); do kill "$p" 2>/dev/null; done
}
kill_all() { kill_pids; kill_stray; }
trap 'kill_all; net_stop' EXIT
net_guard
relay_up

FAILS=0
check() { if eval "$1"; then echo "PASS $2"; else echo "FAIL $2"; FAILS=$((FAILS + 1)); fi; }
## online: the issuer and the relay of this run (each with its half of a fresh key pair), as online.sh starts them.
NET_FLAGS=(--transport="$TRANSPORT")
case " $MODES " in *" online "*)
  ISSUER_DIR="$LAB/addons/mp_kit/issuer"
  ISSUER_PORT="${ISSUER_PORT:-$((RELAY_PORT + 1))}"
  ISSUER="http://127.0.0.1:$ISSUER_PORT"
  [ -d "$ISSUER_DIR/node_modules/jose" ] || npm ci --prefix "$ISSUER_DIR" --silent --no-fund --no-audit || echo "FAIL npm ci for the issuer"
  relay_deps || echo "FAIL npm ci for the relay"
  eval "$(node "$ISSUER_DIR/keys.mjs")"
  export RELAY_TOKEN_KEYS
  [ "$TRANSPORT" = relay ] || TRANSPORT=relay relay_up
  GAME="lab$$"
  ISSUER_PRIVATE_KEY="$ISSUER_PRIVATE_KEY" ISSUER_RELAY_URL="ws://127.0.0.1:$RELAY_PORT" PORT="$ISSUER_PORT" \
    ISSUER_GAMES="{\"$GAME\":{\"max_players\":8}}" ISSUER_ROOMS_PER_IP=10 node "$ISSUER_DIR/server.mjs" > "$OUT/issuer.log" 2>&1 &
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
  ;;
esac
for mode in $MODES; do
  CODE="$OUT/$mode.code"
  MATCHES="$OUT/$mode.matches"
  STAY=0
  [ "$mode" != quit ] && STAY=30
  COMMON=(--probe-code-file="$CODE" --probe-timeout-s=30 --matches-root="$MATCHES" --result-quit-delay-s=1 --probe-finish="$mode")
  READY="the private match process listens"
  ## An online room: every process stays on ENet, as a game does; the room's connection goes through the relay by itself.
  if [ "$mode" = online ]; then COMMON+=(--issuer-url="$ISSUER"); READY="the online room is up"; else COMMON+=("${NET_FLAGS[@]}"); fi
  gd "$OUT/$mode.host.log" -- "${COMMON[@]}" --stay-after-finish-s="$STAY" --probe=finish_host --issuer-install=lab-finish-host-0001
  HOST=$LAST_PID
  wait_line "$OUT/$mode.host.log" "^PASS $READY" "$HOST" 40
  gd "$OUT/$mode.friend.log" -- "${COMMON[@]}" --probe=finish_friend --issuer-install=lab-finish-friend-001
  FRIEND=$LAST_PID
  for p in $FRIEND $HOST; do wait_pid "$p" 90; done
  wait_gone "match-ticket-file=$MATCHES" 15
  for r in host friend; do grep -E "^(PASS|FAIL|SCRIPT ERROR|METRIC)" "$OUT/$mode.$r.log" | sed "s/^/$mode $r: /"; done
  check 'grep -q "^PROBE finish_host PASS" "$OUT/$mode.host.log"' "$mode: the host played to the win and its private match ended as it should"
  check 'grep -q "^PROBE finish_friend PASS" "$OUT/$mode.friend.log"' "$mode: the friend's end screen stayed until the normal end"
  check '! grep -q "^SCRIPT ERROR" "$OUT/$mode".*.log' "$mode: no script errors"
  check '[ "$(godots_with "$MATCHES")" = 0 ]' "$mode: no match process left"
done
net_stop
echo "--- verdict (logs in $OUT) ---"
if [ "$FAILS" = 0 ]; then echo "$TAG PASS"; exit 0; fi
echo "$TAG FAIL: $FAILS"
exit 1
