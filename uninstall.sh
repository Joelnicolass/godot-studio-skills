#!/usr/bin/env bash
# Quita estas skills y commands de producto. No toca otras en ~/.cursor.
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
      DEST="${2:?--dest requiere un directorio}"
      shift 2
      ;;
    *)
      echo "Uso: $0 [--project | --dest DIR]" >&2
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
    echo "ausente  ${target}"
    return
  fi
  local name
  for name in "$@"; do
    if [[ -e "${target}/${name}" ]]; then
      rm -rf "${target}/${name}"
      echo "quitado  ${name}"
    else
      echo "ausente  ${name}"
    fi
  done
}

remove_named "$SKILL_TARGET" "${SKILL_NAMES[@]}"
remove_named "$CMD_TARGET" "${COMMAND_FILES[@]}"
