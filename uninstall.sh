#!/usr/bin/env bash
# Remove these skills and product commands. Leaves other files in ~/.cursor alone.
set -euo pipefail

SKILL_NAMES=(
  godot-layered-architecture
  godot-composition-first
  godot-mp-kit
)
COMMAND_FILES=(
  create-prd.md
  extract-features.md
  generate-rfcs.md
  generate-rules.md
  implement-rfc.md
  manage-changes.md
  review-rfc.md
  test-strategy.md
  verify-prd.md
  workflow-status.md
)

MODE="global"
DEST=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project) MODE="project"; shift ;;
    --dest)
      MODE="custom"
      DEST="${2:?--dest requires a directory}"
      shift 2
      ;;
    *)
      echo "Usage: $0 [--project | --dest DIR]" >&2
      exit 1
      ;;
  esac
done

case "$MODE" in
  global)
    SKILL_TARGET="${HOME}/.cursor/skills"
    CMD_TARGET="${HOME}/.cursor/commands"
    ;;
  project)
    SKILL_TARGET="$(pwd)/.cursor/skills"
    CMD_TARGET="$(pwd)/.cursor/commands"
    ;;
  custom)
    SKILL_TARGET="$DEST"
    CMD_TARGET="$(cd "$(dirname "$DEST")" && pwd)/commands"
    ;;
esac

remove_named() {
  local target="$1"
  shift
  if [[ ! -d "$target" ]]; then
    echo "missing  ${target}"
    return
  fi
  local name
  for name in "$@"; do
    if [[ -e "${target}/${name}" ]]; then
      rm -rf "${target}/${name}"
      echo "removed  ${name}"
    else
      echo "missing  ${name}"
    fi
  done
}

remove_named "$SKILL_TARGET" "${SKILL_NAMES[@]}"
remove_named "$CMD_TARGET" "${COMMAND_FILES[@]}"
