#!/usr/bin/env bash
# MpKit's card example (addons/mp_kit/examples/cards_2d: high card for three seats with no pawns; MpOrders, MpSeatState,
# MpSeatBots) over the network: a listen host starts alone with bots in the free seats; a client joins late and takes a
# bot's seat with the hand it had (the bot leaves). Each one's hand is its own (the other hands never reach it); a card
# not in the hand is refused; the client leaves after its second card and joins again, and gets the same hand and every
# move back. Two rounds; both end with the same tricks.
# Two Godot processes. Prints PASS / FAIL lines and MPKIT CARDS PASS / FAIL (exit 0 / 1).
. "$(dirname "$0")/lib.sh"
net_group 2 "$@"
TAG="MPKIT CARDS"
LIMIT_S="${PROBE_LIMIT_S:-180}"
PROC_MAX=3
PORT="${E2E_PORT:-7798}"
BOOT="res://addons/mp_kit/examples/cards_2d/boot.tscn"
OUT="$(mktemp -d "${TMPDIR:-/tmp}/mpkit_cards.XXXXXX")"
trap 'kill_pids; net_stop' EXIT
net_guard
## The host starts alone (bots in seats 2 and 3); the client joins late, takes a bot's seat with its hand, then leaves
## after its second card and comes back.
gd "$OUT/host.log" "$BOOT" -- --listen-host --mp-port="$PORT" --probe=cards_player --probe-start-alone --probe-linger-s=6
HOST=$LAST_PID
sleep 3
gd "$OUT/client.log" "$BOOT" -- --client1 --mp-port="$PORT" --probe=cards_player --probe-late --probe-rejoin --probe-linger-s=2
CLIENT=$LAST_PID
wait_line "$OUT/client.log" "^PROBE cards_player (PASS|FAIL)" "$CLIENT" 120
wait_line "$OUT/host.log" "^PROBE cards_player (PASS|FAIL)" "$HOST" 30
for p in $CLIENT $HOST; do kill_tree "$p"; done
for r in host client; do grep -E "^(PASS|FAIL|SCRIPT ERROR|CARDS TRICKS)" "$OUT/$r.log" | sed "s/^/$r: /"; done
FAILS=0
check() { if eval "$1"; then echo "PASS $2"; else echo "FAIL $2"; FAILS=$((FAILS + 1)); fi; }
HT="$(grep -m1 "^CARDS TRICKS" "$OUT/host.log")"
CT="$(grep -m1 "^CARDS TRICKS" "$OUT/client.log")"
check 'grep -q "^PROBE cards_player PASS" "$OUT/host.log"' "the host played its hands, a bot in the third seat"
check 'grep -q "^PROBE cards_player PASS" "$OUT/client.log"' "the client played, left, got its hand back and played on"
check '[ -n "$HT" ] && [ "$HT" = "$CT" ]' "both counted the same tricks ($HT | $CT)"
HL="$(grep -m1 "^CARDS LATE HAND" "$OUT/host.log")"
CL="$(grep -m1 "^CARDS LATE HAND" "$OUT/client.log")"
check '[ -n "$HL" ] && [ "$HL" = "$CL" ]' "the late player got the bot's seat with the hand it had ($HL | $CL)"
check '! grep -q "^SCRIPT ERROR" "$OUT"/*.log' "no script errors"
net_stop
echo "--- verdict (logs in $OUT) ---"
if [ "$FAILS" = 0 ]; then echo "$TAG PASS"; exit 0; fi
echo "$TAG FAIL: $FAILS"
exit 1
