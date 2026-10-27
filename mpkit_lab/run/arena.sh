#!/usr/bin/env bash
# MpKit framework e2e (no game code): the arena_2d example of the kit, run in the lab project (mpkit_lab), where
# only MpKit and the lab probe are autoloads. Each scenario is three processes inside ONE group reservation of the queue:
#   dedicated: server (--server) + first client, which plays, leaves and comes back (rejoin) + a late client;
#   listen:    host (--listen-host) + first client (plays, rejoins) + a late client.
# The server starts the match with one loaded client (--start-seats=1, the start gate). The probes (mpkit_lab/probe/lab_probe.gd)
# press keys and check: remote input moves the pawn on the server and it syncs back, MpState score, a to_all event, a to_server
# call; the first client leaves and joins again: the same slot, its score and the bell still there, the comeback counted; the late
# client, which joins after the start, is turned away (match_started), never gets a slot nor the world.
#   keeppawn:  as dedicated, but the server keeps a dropped player's pawn for its rejoin (despawn_on_leave off): the
#              player leaves holding a key and the kept pawn stops (no keys without a connection); back, the new
#              connection's keys (counted from 1 again) move it at once.
#   lag:       dedicated (--start-seats=2) + an observer + a predicted player, every process with MpLagPeer (LAG_MS one way, JITTER_MS,
#              LOSS of unreliable packets): the player answers its keys at once and is barely corrected; the observer
#              sees it move steadily. Prints METRIC lines.
#              The observer also measures how late the other player's move shows (remote_delay_ms;
#              MAX_REMOTE_DELAY_MS sets a cap) and checks MpNetQuality against the simulated network (RTT, loss, jitter).
#   lossy:     lag on a much worse network (60 ms + 60 ms jitter, 15 % loss): still no correction (every unconfirmed
#              frame is sent again until the server has it; a late one is guessed) and the other player moves steadily.
#   lagshot:   dedicated (--start-seats=2) + a target walking past + a shooter that leads it, every process at SHOT_LAG_MS: with lag
#              compensation the shots hit; the same with the server's --lag-comp=off, most miss (the control).
#   correct:   dedicated that pushes its one predicted player sideways every 0.5 s (a move the owner cannot predict), 40 ms
#              away: the corrections fade on screen (no frame jumps much more than a walking step); the control with
#              --correction-smoothing-s=0 sees the same pushes as jumps. Also with the engine's physics interpolation on.
#   teleport:  dedicated that teleports a walking predicted player (150 px, 4 times) with only net.snap() after moving
#              it: the player itself and an observer each see 4 one-frame jumps and no frame partway; the control
#              without net.snap() sees them drawn partway.
#   flood:     a client sends 500 tunnel messages and 500 to_server calls at once: only the burst gets through.
#   latejoin:  dedicated with --late-join: the first client starts the match, a newcomer after the start still sits and plays.
#   reports:   --world-reports-loaded (a loading screen): the dedicated and the client each report their world loaded 1.5 s
#              after it enters; the gate holds until both did, then they play. Solo too: play_solo holds until the report.
#   fastclock: a dedicated whose game clock runs far ahead of real time (`--fixed-fps 60` stops syncing to the clock) and a
#              client 150 ms away: the admission timeout is real time, so the client still gets in and plays.
#   survive:   a dedicated started the way a VPS starts it (`--dedicated`, every seat by default) serves one match after
#              another: a player wins (first to 3) and leaves, so the next match opens at once; a new player starts from a
#              fresh world (score 0) and drops mid-match, so past the grace the next one opens; a third plays from zero too.
# TRANSPORT=ws runs everything over WebSocket (TCP) instead of ENet (UDP). SCENARIOS="dedicated listen keeppawn lag lossy lagshot correct teleport flood latejoin reports fastclock survive" (default all).
# Prints PASS / FAIL lines and MPKIT ARENA PASS / MPKIT ARENA FAIL (exit 0 / 1).
. "$(dirname "$0")/lib.sh"
net_group 3 "$@"
TAG="MPKIT ARENA"
LIMIT_S="${PROBE_LIMIT_S:-300}"
PROC_MAX=4
TRANSPORT="${TRANSPORT:-enet}"
PORT="${E2E_PORT:-7790}"
SCENARIOS="${SCENARIOS:-dedicated listen keeppawn lag lossy lagshot correct teleport flood latejoin reports fastclock survive}"
SHOT_LAG_MS="${SHOT_LAG_MS:-100}"
LAG_MS="${LAG_MS:-60}"
JITTER_MS="${JITTER_MS:-30}"
LOSS="${LOSS:-0.03}"
OUT="$(mktemp -d "${TMPDIR:-/tmp}/mpkit_arena.XXXXXX")"
kill_all() { kill_pids; }
trap 'kill_all; net_stop' EXIT
net_guard
relay_up

FAILS=0
verdict() { # verdict <log> <role>
  if grep -q "^PROBE $2 PASS" "$1"; then echo "PASS $3"; else echo "FAIL $3"; FAILS=$((FAILS + 1)); fi
}

run_scenario() { # run_scenario <name> <server flag> [more server flags…]
  local name="$1" flag="$2" dir="$OUT/$1"
  shift 2
  mkdir -p "$dir"
  local common=(--transport="$TRANSPORT" --mp-port="$PORT")
  gd "$dir/server.log" -- "$flag" "${common[@]}" --start-seats=1 --probe=watch --probe-server-node --probe-linger-s=60 "$@"
  local server=$LAST_PID
  sleep 0.5
  gd "$dir/client.log" -- --client1 "${common[@]}" --probe=client --probe-rejoin --probe-linger-s=60 ${CLIENT_FLAGS:-}
  local client=$LAST_PID
  wait_line "$dir/client.log" "^PROBE client (PASS|FAIL)" "$client" 60
  # the late client joins the way a person types it: "host:port" in the address field (MpFlow.join_address)
  gd "$dir/late.log" -- "${common[@]}" --probe-join="127.0.0.1:$PORT" --probe=late
  local late=$LAST_PID
  wait_line "$dir/late.log" "^PROBE late (PASS|FAIL)" "$late" 40
  wait_line "$dir/server.log" "^PROBE watch (PASS|FAIL)" "$server" 5
  for p in $late $client $server; do kill_tree "$p"; done
  echo "--- $name ($TRANSPORT) ---"
  for r in server client late; do
    grep -E "^(PASS|FAIL|SCRIPT ERROR|ERROR)" "$dir/$r.log" | sed "s/^/$r: /" | head -n 20
  done
  verdict "$dir/server.log" watch "$name: the server saw the remote player move and score"
  verdict "$dir/client.log" client "$name: the first client played over the network, left and came back to its seat"
  verdict "$dir/late.log" late "$name: the late client was turned away (the match had started)"
  if grep -qE "^SCRIPT ERROR" "$dir"/*.log; then echo "FAIL $name: script errors"; FAILS=$((FAILS + 1)); fi
  if grep -qE "Node not found|Failed to get cached path" "$dir"/*.log; then
    echo "FAIL $name: a peer got a packet for a node it does not have"; grep -hE "Node not found|cached path" "$dir"/*.log | sort | uniq -c | head -3
    FAILS=$((FAILS + 1))
  fi
}

run_lagshot() { # dedicated + a walking target + a shooter that leads it; with and without lag compensation
  local dir="$OUT/lagshot" mode
  mkdir -p "$dir"
  local common=(--transport="$TRANSPORT" --mp-port="$PORT" --net-lag-ms="$SHOT_LAG_MS" --net-jitter-ms=5)
  for mode in ${LAGSHOT_MODES:-on off}; do
    gd "$dir/server_$mode.log" --max-fps 120 -- --server "${common[@]}" --start-seats=2 --lag-comp="$mode"
    local server=$LAST_PID
    sleep 0.5
    gd "$dir/shooter_$mode.log" --max-fps 120 -- --client1 "${common[@]}" --probe=lagshooter \
      $([ "$mode" = off ] && echo --probe-expect-misses)
    local shooter=$LAST_PID
    wait_line "$dir/shooter_$mode.log" "^PASS the shooter got a slot" "$shooter" 20
    gd "$dir/target_$mode.log" --max-fps 120 -- --client2 "${common[@]}" --probe=lagtarget
    local target=$LAST_PID
    wait_line "$dir/shooter_$mode.log" "^PROBE lagshooter (PASS|FAIL)" "$shooter" 60
    for p in $target $shooter $server; do kill_tree "$p"; done
    echo "--- lagshot ($TRANSPORT, ${SHOT_LAG_MS} ms each way, lag compensation $mode) ---"
    grep -E "^(PASS|FAIL|METRIC|SCRIPT ERROR|LAGSHOT)" "$dir/shooter_$mode.log" | sed "s/^/shooter: /" | head -n 20
    verdict "$dir/shooter_$mode.log" lagshooter "lagshot: led shots at a moving target, lag compensation $mode"
  done
  if grep -qE "^SCRIPT ERROR" "$dir"/*.log; then echo "FAIL lagshot: script errors"; FAILS=$((FAILS + 1)); fi
}

run_lag() { # run_lag [name]: dedicated + an observer (slot 1) + a predicted player (slot 2), every process on a bad network
  local name="${1:-lag}"
  local dir="$OUT/$name"
  mkdir -p "$dir"
  local common=(--transport="$TRANSPORT" --mp-port="$PORT" --net-lag-ms="$LAG_MS" --net-jitter-ms="$JITTER_MS" --net-loss="$LOSS")
  gd "$dir/server.log" --max-fps 120 -- --server "${common[@]}" --start-seats=2
  local server=$LAST_PID
  sleep 0.5
  gd "$dir/observer.log" --max-fps 120 -- --client1 "${common[@]}" --probe=observe --probe-watch-slot=2 \
    --probe-press-file="$dir/press.txt" ${MAX_REMOTE_DELAY_MS:+--probe-max-remote-delay-ms=$MAX_REMOTE_DELAY_MS} \
    --probe-rtt-min-ms=$((2 * LAG_MS)) --probe-rtt-max-ms=$((2 * LAG_MS + 2 * JITTER_MS + 40)) \
    --probe-loss-expected="$(python3 -c "print(1 - (1 - $LOSS) ** 2)")" $([ "$JITTER_MS" -gt 0 ] && echo --probe-expect-jitter)
  local observer=$LAST_PID
  wait_line "$dir/observer.log" "^PASS the observer got a slot" "$observer" 20
  gd "$dir/player.log" --max-fps 120 -- --client2 "${common[@]}" --probe=lag --probe-press-file="$dir/press.txt"
  local player=$LAST_PID
  wait_line "$dir/player.log" "^PROBE lag (PASS|FAIL)" "$player" 40
  wait_line "$dir/observer.log" "^PROBE observe (PASS|FAIL)" "$observer" 10
  for p in $player $observer $server; do kill_tree "$p"; done
  echo "--- $name ($TRANSPORT, ${LAG_MS} ms + ${JITTER_MS} ms jitter, loss $LOSS, every process) ---"
  for r in observer player; do
    grep -E "^(PASS|FAIL|METRIC|SCRIPT ERROR|ERROR)" "$dir/$r.log" | sed "s/^/$r: /" | head -n 20
  done
  verdict "$dir/player.log" lag "$name: the predicted player answers at once and is barely corrected"
  verdict "$dir/observer.log" observe "$name: another player moves steadily on screen (buffered interpolation)"
  if grep -qE "^SCRIPT ERROR" "$dir"/*.log; then echo "FAIL $name: script errors"; FAILS=$((FAILS + 1)); fi
}

run_correct() { # dedicated that pushes its one player sideways (a move the owner cannot predict), with and without smoothing
  local dir="$OUT/correct" mode
  mkdir -p "$dir"
  local common=(--transport="$TRANSPORT" --mp-port="$PORT" --net-lag-ms=40 --net-jitter-ms=10)
  for mode in smooth interpolated off; do
    gd "$dir/server_$mode.log" --max-fps 120 -- --server "${common[@]}" --start-seats=1 --probe=pusher --probe-linger-s=10
    local server=$LAST_PID
    sleep 0.5
    if [ "$mode" = smooth ]; then
      gd "$dir/player_$mode.log" --max-fps 120 -- --client1 "${common[@]}" --probe=correct
    elif [ "$mode" = interpolated ]; then
      gd "$dir/player_$mode.log" --max-fps 120 -- --client1 "${common[@]}" --probe=correct --probe-physics-interpolation
    else
      gd "$dir/player_$mode.log" --max-fps 120 -- --client1 "${common[@]}" --probe=correct --correction-smoothing-s=0 --probe-expect-jump
    fi
    local player=$LAST_PID
    wait_line "$dir/player_$mode.log" "^PROBE correct (PASS|FAIL)" "$player" 40
    for p in $player $server; do kill_tree "$p"; done
    echo "--- correct ($TRANSPORT, 40 ms + 10 ms jitter, server pushes, correction smoothing $mode) ---"
    grep -hE "^(PASS|FAIL|METRIC|SCRIPT ERROR)" "$dir/player_$mode.log" | sed "s/^/player: /"
  done
  verdict "$dir/player_smooth.log" correct "correct: a server correction of the own player fades instead of jumping"
  verdict "$dir/player_interpolated.log" correct "correct: the same with the engine's physics interpolation on (faded per tick)"
  verdict "$dir/player_off.log" correct "correct: control, without smoothing the same correction is a jump"
  if grep -qE "^SCRIPT ERROR" "$dir"/*.log; then echo "FAIL correct: script errors"; FAILS=$((FAILS + 1)); fi
}

run_teleport() { # dedicated that teleports a walking predicted player with only net.snap(); it and an observer check it
  local dir="$OUT/teleport" mode
  mkdir -p "$dir"
  local common=(--transport="$TRANSPORT" --mp-port="$PORT" --net-lag-ms=40 --net-jitter-ms=10)
  for mode in snap nosnap; do
    local server_flags=() client_flags=()
    [ "$mode" = nosnap ] && server_flags=(--probe-no-snap) && client_flags=(--probe-expect-slide)
    gd "$dir/server_$mode.log" --max-fps 120 -- --server "${common[@]}" --start-seats=2 --probe=teleporter --probe-linger-s=10 "${server_flags[@]}"
    local server=$LAST_PID
    sleep 0.5
    gd "$dir/observer_$mode.log" --max-fps 120 -- --client1 "${common[@]}" --probe=seeteleport --probe-watch-slot=2 --probe-linger-s=5 "${client_flags[@]}"
    local observer=$LAST_PID
    wait_line "$dir/observer_$mode.log" "^PASS this client got a slot" "$observer" 20
    gd "$dir/player_$mode.log" --max-fps 120 -- --client2 "${common[@]}" --probe=teleported --probe-linger-s=5 "${client_flags[@]}"
    local player=$LAST_PID
    wait_line "$dir/player_$mode.log" "^PROBE teleported (PASS|FAIL)" "$player" 40
    wait_line "$dir/observer_$mode.log" "^PROBE seeteleport (PASS|FAIL)" "$observer" 15
    for p in $player $observer $server; do kill_tree "$p"; done
    echo "--- teleport ($TRANSPORT, 40 ms + 10 ms jitter, the server teleports P2, $([ "$mode" = snap ] && echo "then net.snap()" || echo "control: no net.snap()")) ---"
    for r in player observer; do
      grep -E "^(PASS|FAIL|METRIC|SCRIPT ERROR)" "$dir/${r}_$mode.log" | sed "s/^/$r: /" | head -n 12
    done
  done
  verdict "$dir/player_snap.log" teleported "teleport: the teleported player itself jumps at once (no fade, no slide)"
  verdict "$dir/observer_snap.log" seeteleport "teleport: another player sees it jump, never slide"
  verdict "$dir/player_nosnap.log" teleported "teleport: control, without net.snap() the player fades there"
  verdict "$dir/observer_nosnap.log" seeteleport "teleport: control, without net.snap() another player sees it slide"
  if grep -qE "^SCRIPT ERROR" "$dir"/*.log; then echo "FAIL teleport: script errors"; FAILS=$((FAILS + 1)); fi
}

run_flood() { # dedicated server + one client that floods the tunnel and to_server
  local dir="$OUT/flood"
  mkdir -p "$dir"
  local common=(--transport="$TRANSPORT" --mp-port="$PORT")
  gd "$dir/server.log" -- --server "${common[@]}" --probe=floodwatch
  local server=$LAST_PID
  sleep 0.5
  gd "$dir/client.log" -- --client1 "${common[@]}" --probe=flood --probe-linger-s=8
  local client=$LAST_PID
  wait_line "$dir/server.log" "^PROBE floodwatch (PASS|FAIL)" "$server" 40
  for p in $client $server; do kill_tree "$p"; done
  echo "--- flood ($TRANSPORT) ---"
  grep -hE "^(PASS|FAIL|METRIC|SCRIPT ERROR)" "$dir/server.log" | sed "s/^/server: /"
  verdict "$dir/server.log" floodwatch "flood: the server only lets in what the limits allow"
}

run_latejoin() { # --late-join: the match started with one client, a newcomer still gets a free seat and plays
  local dir="$OUT/latejoin"
  mkdir -p "$dir"
  local common=(--transport="$TRANSPORT" --mp-port="$PORT")
  gd "$dir/server.log" -- --server "${common[@]}" --start-seats=1 --late-join
  local server=$LAST_PID
  sleep 0.5
  gd "$dir/first.log" -- --client1 "${common[@]}" --probe=basic --probe-linger-s=20
  local first=$LAST_PID
  wait_line "$dir/first.log" "^PROBE basic (PASS|FAIL)" "$first" 40
  gd "$dir/late.log" -- "${common[@]}" --probe-join="127.0.0.1:$PORT" --probe=basic --probe-timeout-s=30
  wait_line "$dir/late.log" "^PROBE basic (PASS|FAIL)" "$LAST_PID" 40
  for p in $first $server; do kill_tree "$p"; wait "$p" 2>/dev/null; done
  echo "--- latejoin ($TRANSPORT) ---"
  grep -hE "^(PASS|FAIL|SCRIPT ERROR)" "$dir/late.log" | sed "s/^/late: /" | head -n 12
  verdict "$dir/first.log" basic "latejoin: the first client started the match and played"
  verdict "$dir/late.log" basic "latejoin: a newcomer after the start sat in a free seat and played"
}

run_reports() { # --world-reports-loaded: the gate counts a world once it reports itself loaded (a loading screen), solo too
  local dir="$OUT/reports"
  mkdir -p "$dir"
  local common=(--transport="$TRANSPORT" --mp-port="$PORT" --world-reports-loaded --probe-report-after=1.5)
  gd "$dir/server.log" -- --dedicated "${common[@]}" --start-seats=1 --probe=watch --probe-min-move=0.5 --probe-linger-s=3
  local server=$LAST_PID
  sleep 0.5
  gd "$dir/client.log" -- "${common[@]}" --probe-join="127.0.0.1:$PORT" --probe=basic --probe-timeout-s=30
  wait_line "$dir/client.log" "^PROBE basic (PASS|FAIL)" "$LAST_PID" 60
  wait_line "$dir/server.log" "^PROBE watch (PASS|FAIL)" "$server" 10
  kill_tree "$server"; wait "$server" 2>/dev/null
  gd "$dir/solo.log" -- --world-reports-loaded --probe-report-after=1.5 --probe=solo --probe-timeout-s=30
  wait_line "$dir/solo.log" "^PROBE solo (PASS|FAIL)" "$LAST_PID" 60
  echo "--- reports ($TRANSPORT) ---"
  for r in server client solo; do
    grep -E "^(PASS|FAIL|SCRIPT ERROR)" "$dir/$r.log" | grep -E "FAIL|reported|SCRIPT" | sed "s/^/$r: /" | head -n 8
  done
  verdict "$dir/server.log" watch "reports: the dedicated held until its world and the client's reported, then saw the player"
  verdict "$dir/client.log" basic "reports: the client held until it reported its world, then played"
  verdict "$dir/solo.log" solo "reports: solo held until its world reported, then played"
  if grep -qE "^SCRIPT ERROR" "$dir"/*.log; then echo "FAIL reports: script errors"; FAILS=$((FAILS + 1)); fi
}

run_fastclock() { # network timeouts run on the real clock: a server whose game time races ahead still admits a far client
  local dir="$OUT/fastclock"
  mkdir -p "$dir"
  local common=(--transport="$TRANSPORT" --mp-port="$PORT")
  gd "$dir/server.log" --fixed-fps 60 -- --dedicated "${common[@]}" --start-seats=1
  local server=$LAST_PID
  sleep 2
  gd "$dir/client.log" -- "${common[@]}" --net-lag-ms=150 --probe-join="127.0.0.1:$PORT" --probe=basic --probe-timeout-s=30
  wait_line "$dir/client.log" "^PROBE basic (PASS|FAIL)" "$LAST_PID" 60
  kill_tree "$server"; wait "$server" 2>/dev/null
  echo "--- fastclock ($TRANSPORT) ---"
  grep -hE "^(FAIL|SCRIPT ERROR)|turned peer" "$dir"/*.log | head -n 8
  verdict "$dir/client.log" basic "fastclock: a client 150 ms away got into a server whose game clock races ahead, and played"
}

run_survive() { # a dedicated with its default seats: three matches in a row, each from a fresh world
  local dir="$OUT/survive"
  mkdir -p "$dir"
  local common=(--transport="$TRANSPORT" --mp-port="$PORT")
  gd "$dir/server.log" -- --dedicated "${common[@]}" --rejoin-grace-s=2 --load-timeout-s=2
  local server=$LAST_PID
  sleep 0.5
  local join=(--probe-join="127.0.0.1:$PORT" --probe=basic --probe-timeout-s=30)
  gd "$dir/winner.log" -- "${common[@]}" "${join[@]}" --probe-win
  wait_line "$dir/winner.log" "^PROBE basic (PASS|FAIL)" "$LAST_PID" 60
  sleep 1
  gd "$dir/second.log" -- "${common[@]}" "${join[@]}"
  wait_line "$dir/second.log" "^PROBE basic (PASS|FAIL)" "$LAST_PID" 60
  ## It quit mid-match: past the 2 s grace nobody is left and the next match opens.
  sleep 4
  gd "$dir/third.log" -- "${common[@]}" "${join[@]}"
  wait_line "$dir/third.log" "^PROBE basic (PASS|FAIL)" "$LAST_PID" 60
  kill_tree "$server"
  wait "$server" 2>/dev/null
  echo "--- survive ($TRANSPORT) ---"
  for r in winner second third; do
    grep -E "^(PASS|FAIL|SCRIPT ERROR)" "$dir/$r.log" | sed "s/^/$r: /" | head -n 12
  done
  verdict "$dir/winner.log" basic "survive: the first player won the match and left"
  verdict "$dir/second.log" basic "survive: after a finished match a new player sat in a fresh world"
  verdict "$dir/third.log" basic "survive: after a match everybody dropped, past the grace, a new player sat in a fresh world"
  if grep -qE "^SCRIPT ERROR" "$dir"/*.log; then echo "FAIL survive: script errors"; FAILS=$((FAILS + 1)); fi
}

for s in $SCENARIOS; do
  case "$s" in
    dedicated) run_scenario dedicated --server ;;
    listen) run_scenario listen --listen-host ;;
    keeppawn) CLIENT_FLAGS=--probe-pawn-kept run_scenario keeppawn --server --probe-keep-pawns ;;
    lag) run_lag ;;
    lossy) LAG_MS=60 JITTER_MS=60 LOSS=0.15 run_lag lossy ;;
    lagshot) run_lagshot ;;
    correct) run_correct ;;
    teleport) run_teleport ;;
    flood) run_flood ;;
    latejoin) run_latejoin ;;
    reports) run_reports ;;
    fastclock) run_fastclock ;;
    survive) run_survive ;;
  esac
done
net_stop
echo "--- verdict ($((SECONDS))s, logs in $OUT) ---"
if [ "$FAILS" = 0 ]; then echo "$TAG PASS"; exit 0; fi
echo "$TAG FAIL: $FAILS"
exit 1
