#!/usr/bin/env bash
# MpSpawner lab: dedicated + client A (t=1 s) + late client B (t=6 s), headless.
# usage: debug/spawn_lab/run_lab.sh [PORT] [OUTDIR]
#   Runs two scenarios and checks both:
#   rooms   — lobby, late join, every actor kind, static node, two rooms, slot 1 unseated at 9 s
#   rematch — the server reloads the world at 9 s with both clients connected
# Safety: --max-fps 60 (not --fixed-fps: it drops real-time sync and the server quits at once),
# one group of processes, RSS watchdog 2.5 GB, hard stop 30 s. Do not run while other Godot tests run.
set -u
GODOT=${GODOT_REAL:-/Applications/Godot.app/Contents/MacOS/Godot}
HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(cd "$HERE/../.." && pwd)"
PORT=${1:-7795}
ROOT_OUT=${2:-$PROJECT/.godot/spawn_lab}
C=(--headless --max-fps 60 --path "$PROJECT" res://debug/spawn_lab/lab_boot.tscn)

run() { # run MODE SERVER_ARGS A_ARGS
  local mode=$1 server_args=$2 a_args=$3
  local out="$ROOT_OUT/$mode"
  mkdir -p "$out"
  "$GODOT" "${C[@]}" --quit-after 1500 -- --mp-port="$PORT" --lab-role=server --lab-quit-ms=20000 $server_args > "$out/server.log" 2>&1 &
  local ps=$!
  sleep 1
  "$GODOT" "${C[@]}" --quit-after 1200 -- --mp-port="$PORT" --lab-role=client $a_args > "$out/a.log" 2>&1 &
  local pa=$!
  sleep 5
  "$GODOT" "${C[@]}" --quit-after 900 -- --mp-port="$PORT" --lab-role=client --lab-quit-ms=12000 > "$out/b.log" 2>&1 &
  local pb=$!
  watch $ps $pa $pb
  python3 "$HERE/check_lab.py" "$out" "$mode"
}

watch() {
  end=$((SECONDS + 30))
  while :; do
    alive=0
    for p in "$@"; do
      if kill -0 "$p" 2>/dev/null; then
        alive=1
        rss=$(ps -o rss= -p "$p" 2>/dev/null | tr -d ' ')
        if [ -n "$rss" ] && [ "$rss" -gt 2500000 ]; then echo "RSS kill $p ($rss KB)"; kill -9 "$p"; fi
      fi
    done
    [ "$alive" = 0 ] && break
    if [ "$SECONDS" -gt "$end" ]; then echo "timeout: killing"; kill -9 "$@" 2>/dev/null; break; fi
    sleep 0.5
  done
  wait 2>/dev/null
}

status=0
run rooms "--lab-unseat-ms=9000" "--lab-leave-ms=13000 --lab-quit-ms=13500" || status=1
run rematch "--lab-rematch-ms=9000 --lab-kinds=SUL" "--lab-quit-ms=17500" || status=1
exit $status
