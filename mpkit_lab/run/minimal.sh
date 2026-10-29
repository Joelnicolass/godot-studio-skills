#!/usr/bin/env bash
# MpKit's minimal example (addons/mp_kit/examples/minimal_2d, what the setup wizard writes) over the network, as it is:
# a dedicated server and a client that moves and scores. Two Godot processes.
# Prints PASS / FAIL lines and MPKIT MINIMAL PASS / FAIL (exit 0 / 1).
. "$(dirname "$0")/lib.sh"
net_group 2 "$@"
TAG="MPKIT MINIMAL"
LIMIT_S="${PROBE_LIMIT_S:-120}"
PROC_MAX=3
PORT="${E2E_PORT:-7796}"
BOOT="res://addons/mp_kit/examples/minimal_2d/boot.tscn"
OUT="$(mktemp -d "${TMPDIR:-/tmp}/mpkit_minimal.XXXXXX")"
kill_all() { kill_pids; }
trap 'kill_all; net_stop' EXIT
net_guard
gd "$OUT/server.log" "$BOOT" -- --server --mp-port="$PORT" --start-seats=1 --probe=watch --probe-min-move=0.5 --probe-linger-s=5
SERVER=$LAST_PID
sleep 0.5
gd "$OUT/client.log" "$BOOT" -- --client1 --mp-port="$PORT" --probe=basic --probe-linger-s=3
CLIENT=$LAST_PID
wait_line "$OUT/client.log" "^PROBE basic (PASS|FAIL)" "$CLIENT" 60
wait_line "$OUT/server.log" "^PROBE watch (PASS|FAIL)" "$SERVER" 10
for p in $CLIENT $SERVER; do kill_tree "$p"; done
for r in server client; do grep -E "^(PASS|FAIL|SCRIPT ERROR)" "$OUT/$r.log" | sed "s/^/$r: /"; done
FAILS=0
check() { if eval "$1"; then echo "PASS $2"; else echo "FAIL $2"; FAILS=$((FAILS + 1)); fi; }
check 'grep -q "^PROBE basic PASS" "$OUT/client.log"' "the minimal example plays over the network (client)"
check 'grep -q "^PROBE watch PASS" "$OUT/server.log"' "its server saw the player move and score"
check '! grep -q "^SCRIPT ERROR" "$OUT"/*.log' "no script errors"
net_stop
echo "--- verdict (logs in $OUT) ---"
if [ "$FAILS" = 0 ]; then echo "$TAG PASS"; exit 0; fi
echo "$TAG FAIL: $FAILS"
exit 1
