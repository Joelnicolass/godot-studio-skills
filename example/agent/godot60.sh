#!/usr/bin/env bash
# GODOT wrapper for cli.sh: same binary, capped to 60 fps.
exec "${GODOT_REAL:-/Applications/Godot.app/Contents/MacOS/Godot}" --max-fps 60 "$@"
