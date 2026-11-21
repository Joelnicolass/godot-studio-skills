#!/usr/bin/env bash
# MpKit's sports example (addons/mp_kit/examples/sports_2d) over a bad network, as a person plays it: a dedicated server
# and two clients, 40 ms each way with jitter. The carrier runs with the ball; the tackler chases what it sees on its
# screen and slides into it. Checks that both players' own running and sliding are predicted (barely corrected: their
# state rides with the pose) and that the slides that touched on the tackler's screen win the ball (lag compensation),
# then the same without lag compensation, for comparison. Three Godot processes at a time.
# Prints PASS / FAIL lines and MPKIT SPORTS PASS / FAIL (exit 0 / 1).
. "$(dirname "$0")/lib.sh"
net_group 3 "$@"
TAG="MPKIT SPORTS"
LIMIT_S="${PROBE_LIMIT_S:-300}"
PROC_MAX=4
PORT="${E2E_PORT:-7795}"
LAG_MS="${LAG_MS:-40}"
JITTER_MS="${JITTER_MS:-5}"
TRANSPORT="${TRANSPORT:-enet}"
BOOT="res://addons/mp_kit/examples/sports_2d/boot.tscn"
OUT="$(mktemp -d "${TMPDIR:-/tmp}/mpkit_sports.XXXXXX")"
kill_all() { kill_pids; }
trap 'kill_all; net_stop' EXIT
net_guard
FAILS=0
common=(--transport="$TRANSPORT" --mp-port="$PORT" --net-lag-ms="$LAG_MS" --net-jitter-ms="$JITTER_MS")
for mode in ${SPORTS_MODES:-on off}; do
  gd "$OUT/server_$mode.log" "$BOOT" --max-fps 120 -- --server "${common[@]}" --start-seats=2 --lag-comp="$mode"
  SERVER=$LAST_PID
  sleep 0.5
  gd "$OUT/tackler_$mode.log" "$BOOT" --max-fps 120 -- --client1 "${common[@]}" --probe=sports_tackler \
    $([ "$mode" = off ] && echo --probe-expect-misses)
  TACKLER=$LAST_PID
  wait_line "$OUT/tackler_$mode.log" "^PASS the tackler got a slot" "$TACKLER" 20
  gd "$OUT/carrier_$mode.log" "$BOOT" --max-fps 120 -- --client2 "${common[@]}" --probe=sports_carrier --probe-seconds=45
  CARRIER=$LAST_PID
  wait_line "$OUT/tackler_$mode.log" "^PROBE sports_tackler (PASS|FAIL)" "$TACKLER" 70
  wait_line "$OUT/carrier_$mode.log" "^PROBE sports_carrier (PASS|FAIL)" "$CARRIER" 60
  for p in $CARRIER $TACKLER $SERVER; do kill_tree "$p"; done
  echo "--- sports ($TRANSPORT, ${LAG_MS} ms + ${JITTER_MS} ms each way, lag compensation $mode) ---"
  for r in tackler carrier; do grep -E "^(PASS|FAIL|METRIC|SCRIPT ERROR)" "$OUT/${r}_$mode.log" | sed "s/^/$r: /" | head -n 20; done
  for r in tackler carrier; do
    if grep -q "^PROBE sports_$r PASS" "$OUT/${r}_$mode.log"; then echo "PASS sports ($mode): the $r"; else echo "FAIL sports ($mode): the $r"; FAILS=$((FAILS + 1)); fi
  done
done
if grep -qE "^SCRIPT ERROR" "$OUT"/*.log; then echo "FAIL sports: script errors"; FAILS=$((FAILS + 1)); fi
net_stop
echo "--- verdict (logs in $OUT) ---"
if [ "$FAILS" = 0 ]; then echo "$TAG PASS"; exit 0; fi
echo "$TAG FAIL: $FAILS"
exit 1
