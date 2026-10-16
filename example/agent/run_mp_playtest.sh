#!/usr/bin/env bash
# MpKit demo playtest with AgentKit (windows): 1P 2D/3D, listen host + client,
# dedicated + client A + late client B (2D and 3D), then the headless spawn lab.
# usage: agent/run_mp_playtest.sh [PORT]     (needs ./install.sh --addon example agent_kit)
# One group of Godot processes at a time; 60 fps cap; RSS watchdog 2.5 GB; hard stop per case.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(cd "$HERE/.." && pwd)"
PORT=${1:-7795}
OUT="$PROJECT/agent/out/mp"
GODOT_REAL=${GODOT_REAL:-/Applications/Godot.app/Contents/MacOS/Godot}
export GODOT="$HERE/godot60.sh" GODOT_REAL
CLI="$PROJECT/addons/agent_kit/cli.sh"
mkdir -p "$OUT"
RESULTS=()
"$GODOT_REAL" --headless --path "$PROJECT" --import --quit > "$OUT/import.log" 2>&1

watch() { # watch LIMIT_S PID... — waits; kills on RSS > 2.5 GB or after LIMIT_S
  local limit=$1; shift
  local end=$((SECONDS + limit))
  while :; do
    local alive=0
    for p in "$@"; do
      if kill -0 "$p" 2>/dev/null; then
        alive=1
        for c in $p $(pgrep -P "$p"); do
          local rss; rss=$(ps -o rss= -p "$c" 2>/dev/null | tr -d ' ')
          if [ -n "$rss" ] && [ "$rss" -gt 2500000 ]; then echo "RSS kill $c"; kill -9 "$c"; fi
        done
      fi
    done
    [ "$alive" = 0 ] && return 0
    if [ "$SECONDS" -gt "$end" ]; then
      echo "timeout: killing $*"
      for p in "$@"; do pkill -9 -P "$p" 2>/dev/null; kill -9 "$p" 2>/dev/null; done
      return 1
    fi
    sleep 0.5
  done
}

flow() { # flow NAME LOG — starts the flow in the background; its pid goes to FLOW_PID.
  # Launch the command itself with `&`, never the whole function: a backgrounded
  # function left the Godot window without output and stuck (macOS, no tty).
  # `script` gives Godot a pty: line-buffered log, so a killed run still shows its last step.
  script -q "$OUT/$2.log" "$CLI" "$PROJECT" flow --flow="$1.json" --out=res://agent/out/mp --fail-on-error --mp-port="$PORT" > /dev/null 2>&1 &
  FLOW_PID=$!
}

verdict() { # verdict LABEL LOG...
  local label=$1; shift
  local ok=PASS
  for log in "$@"; do grep -q "AGENT_OK" "$OUT/$log.log" || ok=FAIL; done
  RESULTS+=("$ok $label")
}

server() { # server LOG [args]
  local log=$1; shift
  "$GODOT_REAL" --headless --max-fps 60 --path "$PROJECT" -- --dedicated --mp-port="$PORT" "$@" > "$OUT/$log.log" 2>&1 &
  SERVER=$!
  sleep 2
}

server_clean() { # server_clean LOG — no ERROR / SCRIPT ERROR on the dedicated
  if grep -qE "^(ERROR|SCRIPT ERROR)" "$OUT/$1.log"; then RESULTS+=("FAIL $1 (server errors)"); else RESULTS+=("PASS $1 (server clean)"); fi
}

for kind in 2d 3d; do
  flow "mp_solo_$kind" "solo_$kind"; watch 60 $FLOW_PID; verdict "1P $kind" "solo_$kind"
done

flow mp_listen_host listen_host; PH=$FLOW_PID
sleep 4
flow mp_listen_client listen_client; PC=$FLOW_PID
watch 60 $PH $PC; verdict "listen host + client" listen_host listen_client

for kind in 2d 3d; do
  server "ded_${kind}_server" --world="$kind"
  flow "mp_ded_${kind}_a" "ded_${kind}_a"; PA=$FLOW_PID
  sleep 8
  flow "mp_ded_${kind}_b" "ded_${kind}_b"; PB=$FLOW_PID
  watch 80 $PA $PB
  kill "$SERVER" 2>/dev/null; wait "$SERVER" 2>/dev/null
  verdict "dedicated $kind + A + late B" "ded_${kind}_a" "ded_${kind}_b"
  server_clean "ded_${kind}_server"
done

if "$PROJECT/debug/spawn_lab/run_lab.sh" "$PORT" "$OUT/lab" > "$OUT/lab.log" 2>&1; then RESULTS+=("PASS spawn lab"); else RESULTS+=("FAIL spawn lab"); fi

printf '%s\n' "${RESULTS[@]}"
printf '%s\n' "${RESULTS[@]}" | grep -q "^FAIL" && exit 1 || exit 0
