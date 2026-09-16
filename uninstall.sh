#!/usr/bin/env bash
# Quita skills, commands y subagentes de este kit. No toca otras piezas en ~/.cursor.
set -euo pipefail

SKILL_NAMES=(
  godot-layered-architecture
  godot-composition-first
  godot-mp-kit
  godot-studio-workflow
  godot-testing
  godot-animation
  godot-juicy
  godot-fsm
  godot-platformer-2d
  godot-playtest
  godot-visual-qa
  godot-studio-memory
  godot-agent-kit
)
COMMAND_FILES=(
  create-prd.md
  create-visual-guide.md
  extract-features.md
  generate-rfcs.md
  generate-rules.md
  implement-rfc.md
  implement-feature.md
  add-juicy.md
  add-state-machine.md
  add-platformer-2d.md
  manage-changes.md
  new-mp-feature.md
  review-rfc.md
  test-strategy.md
  verify-prd.md
  workflow-status.md
  agent-kit.md
)
AGENT_FILES=(
  studio-tech-lead.md
  studio-developer.md
  studio-reviewer.md
  studio-tester.md
  studio-visual.md
  studio-playtester.md
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
    AGENT_TARGET="${HOME}/.cursor/agents"
    ;;
  project)
    SKILL_TARGET="$(pwd)/.cursor/skills"
    CMD_TARGET="$(pwd)/.cursor/commands"
    AGENT_TARGET="$(pwd)/.cursor/agents"
    ;;
  custom)
    SKILL_TARGET="$DEST"
    parent="$(cd "$(dirname "$DEST")" && pwd)"
    CMD_TARGET="${parent}/commands"
    AGENT_TARGET="${parent}/agents"
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
remove_named "$AGENT_TARGET" "${AGENT_FILES[@]}"
