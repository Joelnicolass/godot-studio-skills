#!/usr/bin/env bash
# Quita solo estas tres skills. No toca otras en ~/.cursor/skills.
set -euo pipefail

SKILL_NAMES=(
  godot-layered-architecture
  godot-composition-first
  godot-mp-kit
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
  global) TARGET="${HOME}/.cursor/skills" ;;
  project) TARGET="$(pwd)/.cursor/skills" ;;
  custom) TARGET="$DEST" ;;
esac

if [[ ! -d "$TARGET" ]]; then
  echo "No existe ${TARGET}" >&2
  exit 1
fi

for name in "${SKILL_NAMES[@]}"; do
  if [[ -d "${TARGET}/${name}" ]]; then
    rm -rf "${TARGET}/${name}"
    echo "quitado  ${name}"
  else
    echo "ausente  ${name}"
  fi
done
