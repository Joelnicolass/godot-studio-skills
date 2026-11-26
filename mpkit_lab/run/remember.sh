#!/usr/bin/env bash
# A LAN seat a game gets back after it was closed and opened again (MpFlow.remember_seats / --remember-seats), on the
# turn-based example, and the host's seat log (--seat-log). A listen host and a client play; the client is killed after
# its first move (SIGKILL: nothing is said). A new copy with no credential is turned away (match_started: the seat waits
# for its player); a new copy with the first one's seat file is back in seat 2 and plays the game to the end. The host's
# log tells the seat's story: in, away, back. At most three Godot processes at once.
# Prints PASS / FAIL lines and MPKIT REMEMBER PASS / FAIL (exit 0 / 1).
. "$(dirname "$0")/lib.sh"
net_group 3 "$@"
TAG="MPKIT REMEMBER"
LIMIT_S="${PROBE_LIMIT_S:-200}"
PROC_MAX=3
PORT="${E2E_PORT:-7799}"
BOOT="res://addons/mp_kit/examples/turns_2d/boot.tscn"
OUT="$(mktemp -d "${TMPDIR:-/tmp}/mpkit_remember.XXXXXX")"
SEATS="$OUT/seats.cfg"
trap 'kill_pids; net_stop' EXIT
net_guard
gd "$OUT/host.log" "$BOOT" -- --listen-host --mp-port="$PORT" --seat-log --probe=turns_player --probe-timeout-s=40 --probe-linger-s=4
HOST=$LAST_PID
sleep 0.5
gd "$OUT/first.log" "$BOOT" -- --client1 --mp-port="$PORT" --remember-seats --seat-file="$SEATS" --probe=turns_player --probe-announce-move
FIRST=$LAST_PID
wait_line "$OUT/first.log" "^TURNS MOVED" "$FIRST" 60
for p in $(descendants "$FIRST" | sort -rn); do kill -9 "$p" 2>/dev/null; done  # SIGKILL: the game says nothing
sleep 1
gd "$OUT/stranger.log" "$BOOT" -- --mp-port="$PORT" --probe-join="127.0.0.1:$PORT" --probe=late --probe-reason=match_started
STRANGER=$LAST_PID
wait_line "$OUT/stranger.log" "^PROBE late (PASS|FAIL)" "$STRANGER" 40
gd "$OUT/again.log" "$BOOT" -- --client1 --mp-port="$PORT" --remember-seats --seat-file="$SEATS" --probe=turns_player --probe-expect-seat=2 --probe-linger-s=2
AGAIN=$LAST_PID
wait_line "$OUT/again.log" "^PROBE turns_player (PASS|FAIL)" "$AGAIN" 90
wait_line "$OUT/host.log" "^PROBE turns_player (PASS|FAIL)" "$HOST" 20
for p in $AGAIN $STRANGER $HOST; do kill_tree "$p"; done
for r in host first stranger again; do grep -E "^(PASS|FAIL|SCRIPT ERROR|TURNS BOARD|MpKit seats)" "$OUT/$r.log" | sed "s/^/$r: /"; done
FAILS=0
check() { if eval "$1"; then echo "PASS $2"; else echo "FAIL $2"; FAILS=$((FAILS + 1)); fi; }
check 'grep -q "^TURNS MOVED 2" "$OUT/first.log"' "the first copy played seat 2 once"
check '[ -s "$SEATS" ]' "it kept its seat's credential in the seat file"
check 'grep -q "^PROBE late PASS" "$OUT/stranger.log"' "a copy with no credential is turned away (match_started)"
check 'grep -q "^PROBE turns_player PASS" "$OUT/again.log"' "the copy opened again is back in seat 2 and plays to the end"
check 'grep -q "^PROBE turns_player PASS" "$OUT/host.log"' "the host played the game to the end"
check 'grep -q "^MpKit seats: seat 2 in" "$OUT/host.log" && grep -q "^MpKit seats: seat 2 away" "$OUT/host.log" && grep -q "^MpKit seats: seat 2 back" "$OUT/host.log"' "the host's seat log: seat 2 in, away, back"
check 'grep -q "^MpKit seats: match started" "$OUT/host.log"' "and the match's start"
check '! grep -q "^SCRIPT ERROR" "$OUT"/*.log' "no script errors"
net_stop
echo "--- verdict (logs in $OUT) ---"
if [ "$FAILS" = 0 ]; then echo "$TAG PASS"; exit 0; fi
echo "$TAG FAIL: $FAILS"
exit 1
