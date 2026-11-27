#!/usr/bin/env bash
# MpKit's turn-based example (addons/mp_kit/examples/turns_2d: three in a row, no pawns, MpOrders) over the network: a
# listen host and a client play a game to the end. Each sends one move that is never legal and gets the refusal alone;
# the client leaves after its second move and joins again, gets every move back and plays on. Both end with the same
# board, hash and number of moves. The client also sends 80 moves at once (more than the tunnel's 30 a second): every one
# reaches the judge and comes back refused, none is lost; back after the rejoin it gets caught_up once.
# Two Godot processes.
# Prints PASS / FAIL lines and MPKIT TURNS PASS / FAIL (exit 0 / 1).
. "$(dirname "$0")/lib.sh"
net_group 2 "$@"
TAG="MPKIT TURNS"
LIMIT_S="${PROBE_LIMIT_S:-150}"
PROC_MAX=3
PORT="${E2E_PORT:-7797}"
BOOT="res://addons/mp_kit/examples/turns_2d/boot.tscn"
OUT="$(mktemp -d "${TMPDIR:-/tmp}/mpkit_turns.XXXXXX")"
trap 'kill_pids; net_stop' EXIT
net_guard
gd "$OUT/host.log" "$BOOT" -- --listen-host --mp-port="$PORT" --probe=turns_player --probe-linger-s=6
HOST=$LAST_PID
sleep 0.5
gd "$OUT/client.log" "$BOOT" -- --client1 --mp-port="$PORT" --probe=turns_player --probe-rejoin --probe-burst=80 --probe-linger-s=2
CLIENT=$LAST_PID
wait_line "$OUT/client.log" "^PROBE turns_player (PASS|FAIL)" "$CLIENT" 90
wait_line "$OUT/host.log" "^PROBE turns_player (PASS|FAIL)" "$HOST" 20
for p in $CLIENT $HOST; do kill_tree "$p"; done
for r in host client; do grep -E "^(PASS|FAIL|SCRIPT ERROR|TURNS BOARD)" "$OUT/$r.log" | sed "s/^/$r: /"; done
FAILS=0
check() { if eval "$1"; then echo "PASS $2"; else echo "FAIL $2"; FAILS=$((FAILS + 1)); fi; }
HB="$(grep -m1 "^TURNS BOARD" "$OUT/host.log")"
CB="$(grep -m1 "^TURNS BOARD" "$OUT/client.log")"
check 'grep -q "^PROBE turns_player PASS" "$OUT/host.log"' "the host played its seat to the end"
check 'grep -q "^PROBE turns_player PASS" "$OUT/client.log"' "the client played, left, came back and played on"
check '[ -n "$HB" ] && [ "$HB" = "$CB" ]' "both ended with the same board, hash and moves ($HB | $CB)"
check '! grep -q "^SCRIPT ERROR" "$OUT"/*.log' "no script errors"
net_stop
echo "--- verdict (logs in $OUT) ---"
if [ "$FAILS" = 0 ]; then echo "$TAG PASS"; exit 0; fi
echo "$TAG FAIL: $FAILS"
exit 1
