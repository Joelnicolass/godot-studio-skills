#!/usr/bin/env bash
# MpKit online rooms e2e (no game code), in mpkit_lab: the MpKit issuer and relay run here, each with its half of a key
# pair made for this run (issuer/keys.mjs), and players host and join through them as they would online.
# Part 1, a desktop host (a match process on its PC, MpLocalServer): a friend finds its room in the issuer's list and
# joins; the host wins and the issuer forgets the room. Part 2, a host in its own game (the way a browser hosts): a
# friend joins with the code (typed "abc-def"), the host process freezes for 3 s (SIGSTOP), the friend waits for it
# (host_silent / host_back) and the match goes on; a third player is told the room is full, a made-up code is unknown.
# Part 3, a browser hosts: the lab's web export in a headless Chrome opens a room (CORS to the issuer, the relay token
# in the URL) and a desktop friend finds it in the list by name and plays it (ONLINE_WEB=0, or no Chrome/Chromium:
# skipped; BROWSER=/path picks one). Never more than 3 headless Godot at once (a match process counts). Needs npm (the issuer's and relay's packages, installed from their lockfiles once).
# Prints PASS / FAIL lines and MPKIT ONLINE PASS / MPKIT ONLINE FAIL (exit 0 / 1).
. "$(dirname "$0")/lib.sh"
net_group 4 "$@"
TAG="MPKIT ONLINE"
LIMIT_S="${PROBE_LIMIT_S:-300}"
PROC_MAX=3
TRANSPORT=relay
OUT="$(mktemp -d "${TMPDIR:-/tmp}/mpkit_online.XXXXXX")"
MATCHES="$OUT/matches"
ISSUER_DIR="$LAB/addons/mp_kit/issuer"
ISSUER_PORT="${ISSUER_PORT:-$((RELAY_PORT + 1))}"
ISSUER="http://127.0.0.1:$ISSUER_PORT"
HTTP_PORT="${HTTP_PORT:-$((RELAY_PORT + 2))}"
WEB="$ROOT/scratch/web"
find_browser() {
  [ -n "${BROWSER:-}" ] && { [ "$BROWSER" = none ] || echo "$BROWSER"; return; }
  local c
  for c in "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" "/Applications/Chromium.app/Contents/MacOS/Chromium" \
      "$(command -v google-chrome 2>/dev/null)" "$(command -v chromium 2>/dev/null)" "$(command -v chromium-browser 2>/dev/null)"; do
    [ -n "$c" ] && [ -x "$c" ] && { echo "$c"; return; }
  done
}
kill_stray() {
  local p
  for p in $(ps -axo pid=,args= | awk -v m="$MATCHES" '$2 ~ /\/Godot$/ && index($0, m) {print $1}'); do kill "$p" 2>/dev/null; done
}
kill_all() { kill -CONT "${LHOST:-0}" 2>/dev/null; kill_pids; kill_stray; [ -n "${HTTP:-}" ] && kill "$HTTP" 2>/dev/null; }
trap 'kill_all; net_stop' EXIT
net_guard

[ -d "$ISSUER_DIR/node_modules/jose" ] || npm ci --prefix "$ISSUER_DIR" --silent --no-fund --no-audit || echo "FAIL npm ci for the issuer"
relay_deps || echo "FAIL npm ci for the relay"
## ISSUER_PRIVATE_KEY (the issuer only) and RELAY_TOKEN_KEYS (the relay: public), fresh for this run.
eval "$(node "$ISSUER_DIR/keys.mjs")"
export RELAY_TOKEN_KEYS
RELAY_QUIET=0 relay_up
GAME="lab$$"
ISSUER_PRIVATE_KEY="$ISSUER_PRIVATE_KEY" ISSUER_RELAY_URL="ws://127.0.0.1:$RELAY_PORT" PORT="$ISSUER_PORT" \
  ISSUER_GAMES="{\"$GAME\":{\"max_players\":8}}" ISSUER_ROOMS_PER_IP=10 ISSUER_RATE_LIST=600 ISSUER_RATE_JOIN=120 \
  ISSUER_ORIGINS="http://127.0.0.1:$HTTP_PORT" \
  node "$ISSUER_DIR/server.mjs" > "$OUT/issuer.log" 2>&1 &
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

## No --transport: every process stays on ENet, as a game does; an issuer room's connection goes through the relay by
## itself (MpTransport.use_relay_room), and LAN afterwards is ENet still.
COMMON=(--issuer-url="$ISSUER" --probe-timeout-s=45 --matches-root="$MATCHES" --result-quit-delay-s=1)
TICKET='{"mode":"duel","options":{"map":"lab-map"},"seats":[{"slot":1,"meta":{"pick":"red"}},{"slot":2,"meta":{"pick":"blue"}}]}'
CODE1="$OUT/code1.txt"
CODE2="$OUT/code2.txt"

## At most 3 headless Godot at once on this machine (a match process counts).
echo "--- part 1: a desktop host (a match process on its PC); a friend finds the room in the issuer's list"
gd "$OUT/host.log" -- "${COMMON[@]}" --probe=online_host --online-mode=dedicated --probe-players=2 \
  --probe-code-file="$CODE1" --probe-ticket="$TICKET" --issuer-install=lab-host-install-0001
HOST=$LAST_PID
wait_line "$OUT/host.log" "^PASS the online room is up" "$HOST" 60
## The match process's ticket: the game's keys and seat meta, the kit's tokens and relay block.
python3 - "$MATCHES" > "$OUT/ticket_check.txt" <<'PYEOF'
import glob, json, sys
found = glob.glob(sys.argv[1] + "/**/ticket.json", recursive=True)
t = json.load(open(found[0])) if found else {}
seats = {s.get("slot"): s for s in t.get("seats", [])}
ok = (t.get("mode") == "duel" and t.get("options") == {"map": "lab-map"}
      and seats.get(1, {}).get("meta") == {"pick": "red"} and seats.get(2, {}).get("meta") == {"pick": "blue"}
      and all("token_sha256" in s for s in seats.values()) and str(t.get("relay", {}).get("room", "")).startswith("p-"))
print("ticket ok" if ok else "ticket wrong: %s" % json.dumps(t)[:400])
PYEOF
gd "$OUT/lister.log" -- "${COMMON[@]}" --probe=online_list --probe-code-file="$CODE1" --issuer-install=lab-lister-install-01
LISTER=$LAST_PID
for p in $LISTER $HOST; do wait_pid "$p" 90; done
wait_gone "match-ticket-file=$MATCHES" 15
python3 - "$ISSUER" "$(cat "$CODE1" 2>/dev/null)" "$GAME" > "$OUT/gone.txt" <<'PYEOF'
import json, sys, urllib.request, urllib.error
issuer, code, game = sys.argv[1:4]
body = json.dumps({"game": game, "version": "0", "kit": "0", "platform": "Linux", "install": "lab-check-install-001"}).encode()
req = urllib.request.Request("%s/v1/rooms/%s/join" % (issuer, code), body, {"content-type": "application/json"})
try:
    urllib.request.urlopen(req, timeout=5); print("still there")
except urllib.error.HTTPError as e:
    print("gone" if e.code == 404 else "status %d" % e.code)
PYEOF

echo "--- part 2: a host in its own game (the way a browser hosts): a friend with the code, the host frozen 3 s, a full room, an unknown code"
gd "$OUT/lhost.log" -- "${COMMON[@]}" --probe=online_host --online-mode=listen --probe-players=2 \
  --probe-code-file="$CODE2" --probe-wait-file="$OUT/go2" --issuer-install=lab-lhost-install-001
LHOST=$LAST_PID
wait_line "$OUT/lhost.log" "^PASS the online room is up" "$LHOST" 60
gd "$OUT/lfriend.log" -- "${COMMON[@]}" --probe=online_join --probe-expect-silence --probe-code-file="$CODE2" --issuer-install=lab-lfriend-install-1
LFRIEND=$LAST_PID
wait_line "$OUT/lfriend.log" "^PROBE online_join seated" "$LFRIEND" 60
sleep 1
kill -STOP "$LHOST"
sleep 3
kill -CONT "$LHOST"
wait_line "$OUT/lfriend.log" "host froze (host_silent) and came back" "$LFRIEND" 30
gd "$OUT/full.log" -- "${COMMON[@]}" --probe=online_refused --probe-expect=room_full --probe-code-file="$CODE2" --issuer-install=lab-full-install-0001
wait_pid "$LAST_PID" 60
gd "$OUT/nocode.log" -- "${COMMON[@]}" --probe=online_refused --probe-room=ZZZZZZ --probe-expect=no_such_room --issuer-install=lab-nocode-install-01
wait_pid "$LAST_PID" 60
touch "$OUT/go2"
for p in $LFRIEND $LHOST; do wait_pid "$p" 90; done

BROWSER_BIN="$(find_browser)"
if [ "${ONLINE_WEB:-1}" = 0 ] || [ -z "$BROWSER_BIN" ]; then
  echo "SKIP part 3 (a browser host): ONLINE_WEB=0 or no Chrome/Chromium"
  WEB_SKIP=1
else
  echo "--- part 3: a browser hosts (the lab's web export in a headless Chrome); a desktop friend finds it by name in the list"
  mkdir -p "$WEB"
  run_godot --headless --path "$ROOT" --export-debug "Web" "$WEB/index.html" > "$OUT/export.log" 2>&1
  [ -f "$WEB/index.wasm" ] || echo "FAIL web export (see $OUT/export.log)"
  python3 - "$WEB" "$ISSUER" "$RELAY_PORT" "lab$$" <<'PYEOF'
import sys, os, json
web, issuer, relay_port, room = sys.argv[1:5]
s = open(os.path.join(web, "index.html")).read()
user = ["--probe=online_host", "--probe-players=2", "--probe-room-name=Web room", "--issuer-url=" + issuer,
        "--transport=relay", "--relay-url=ws://127.0.0.1:" + relay_port, "--relay-room=" + room,
        "--issuer-install=lab-web-host-install-1", "--probe-timeout-s=90", "--probe-linger-s=5"]
open(os.path.join(web, "online.html"), "w").write(s.replace('"args":[]', '"args":' + json.dumps(["--"] + user)))
PYEOF
  ( cd "$WEB" && exec python3 -m http.server "$HTTP_PORT" --bind 127.0.0.1 > "$OUT/http.log" 2>&1 ) &
  HTTP=$!
  "$BROWSER_BIN" --headless=new --user-data-dir="$OUT/browser" --no-first-run --no-default-browser-check \
    --use-angle=swiftshader --enable-unsafe-swiftshader --window-size=1024,768 --enable-logging=stderr \
    "http://127.0.0.1:$HTTP_PORT/online.html" > "$OUT/browser.log" 2>&1 &
  echo $! >> "$OUT/pids"
  gd "$OUT/wfriend.log" -- "${COMMON[@]}" --probe=online_list --probe-find-name="Web room" --issuer-install=lab-wfriend-install-1
  wait_pid "$LAST_PID" 150
fi

for r in host lister lhost lfriend full nocode wfriend; do [ -f "$OUT/$r.log" ] || continue; grep -E "^(PASS|FAIL|SCRIPT ERROR)" "$OUT/$r.log" | sed "s/^/$r: /"; done
FAILS=0
check() { if eval "$1"; then echo "PASS $2"; else echo "FAIL $2"; FAILS=$((FAILS + 1)); fi; }
check 'grep -q "^PROBE online_host PASS" "$OUT/host.log"' "a desktop host opened a room through the issuer (a match process on its PC), played it and won"
check 'grep -q "^PROBE online_list PASS" "$OUT/lister.log"' "a friend found the room in the issuer's list and joined it"
check 'grep -qx "ticket ok" "$OUT/ticket_check.txt"' "the match process got the game's ticket (mode, options, each seat's pick) with the kit's tokens and relay room"
check 'grep -qx "gone" "$OUT/gone.txt"' "the issuer forgot the room once its match ended"
check 'grep -q "^PROBE online_host PASS" "$OUT/lhost.log"' "a host in its own game opened a room, froze 3 s and still finished the match"
check 'grep -q "^PROBE online_join PASS" "$OUT/lfriend.log"' "a friend joined with the code (typed abc-def), waited for the frozen host, saw the match end, and its game's transport was still ENet"
check 'grep -q "^PROBE online_refused PASS" "$OUT/full.log"' "a third player was told the room is full"
check 'grep -q "^PROBE online_refused PASS" "$OUT/nocode.log"' "a made-up code was told there is no such room"
if [ -z "${WEB_SKIP:-}" ]; then
  check 'grep -q "listen, 2 players, listed) by Web" "$OUT/issuer.log"' "a browser opened a room on the issuer (CORS, its own game hosting)"
  check 'grep -q "^PROBE online_list host Web" "$OUT/wfriend.log" && grep -q "^PROBE online_list PASS" "$OUT/wfriend.log"' "a desktop friend found the browser's room by name, joined it and saw the match end"
fi
check '! grep -q "refused" "$OUT/relay.log"' "the relay refused no token of this run"
check '! grep -q "^SCRIPT ERROR" "$OUT"/*.log' "no script errors"
check '[ "$(godots_with "$MATCHES")" = 0 ]' "no match process left"
net_stop
echo "--- verdict (logs in $OUT) ---"
if [ "$FAILS" = 0 ]; then echo "$TAG PASS"; exit 0; fi
echo "$TAG FAIL: $FAILS"
exit 1
