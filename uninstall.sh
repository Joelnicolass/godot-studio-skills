#!/usr/bin/env bash
# Remove this kit's skills, commands, and subagents. Leaves other ~/.cursor and ~/.claude files alone.
#   ./uninstall.sh [--cursor | --claude | --all] [--project | --dest DIR]   (default: --cursor)
# Also removes godot-playtest / godot-agent-kit / /agent-kit / studio-playtester
# if this installer copied them from godot-studio-playtest.
set -euo pipefail

SKILL_NAMES=(
  godot-layered-architecture
  godot-composition-first
  godot-code-quality
  godot-mp-kit
  godot-studio-workflow
  godot-testing
  godot-animation
  godot-juicy
  godot-fsm
  godot-platformer-2d
  godot-rts-kit
  godot-prop-kit
  godot-grass-kit
  godot-material-maker
  godot-feature-research
  godot-visual-qa
  godot-studio-memory
  godot-playtest
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
  add-rts-controls.md
  add-props.md
  add-grass.md
  create-material.md
  research-feature.md
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
HARNESS="cursor"
DEST=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project) MODE="project"; shift ;;
    --cursor) HARNESS="cursor"; shift ;;
    --claude) HARNESS="claude"; shift ;;
    --all) HARNESS="all"; shift ;;
    --dest)
      MODE="custom"
      DEST="${2:?--dest requires a directory}"
      shift 2
      ;;
    *)
      echo "Usage: $0 [--cursor | --claude | --all] [--project | --dest DIR]" >&2
      exit 1
      ;;
  esac
done

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

remove_from_base() {
  local base="$1"
  remove_named "${base}/skills" "${SKILL_NAMES[@]}"
  remove_named "${base}/commands" "${COMMAND_FILES[@]}"
  remove_named "${base}/agents" "${AGENT_FILES[@]}"
}

if [[ "$MODE" == "custom" ]]; then
  parent="$(cd "$(dirname "$DEST")" && pwd)"
  remove_named "$DEST" "${SKILL_NAMES[@]}"
  remove_named "${parent}/commands" "${COMMAND_FILES[@]}"
  remove_named "${parent}/agents" "${AGENT_FILES[@]}"
  exit 0
fi

case "$HARNESS" in
  all) HARNESSES="cursor claude" ;;
  *) HARNESSES="$HARNESS" ;;
esac

for harness in $HARNESSES; do
  case "$MODE" in
    global) remove_from_base "${HOME}/.${harness}" ;;
    project) remove_from_base "$(pwd)/.${harness}" ;;
  esac
done
