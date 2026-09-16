#!/usr/bin/env bash
# Install Cursor skills, commands, subagents, and/or Godot addons.
#   ./install.sh                      # ~/.cursor/skills, commands, agents
#   ./install.sh --project            # ./.cursor/skills, commands, agents
#   ./install.sh --addon GODOT_ROOT   # addons/mp_kit → GODOT_ROOT/addons/mp_kit
#   ./install.sh --addon GODOT_ROOT agent_kit|fsm_kit|plat_kit
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="${ROOT}/skills"
CMD_SRC="${ROOT}/commands"
AGENT_SRC="${ROOT}/agents"
ADDONS_ROOT="${ROOT}/addons"
SKILL_NAMES=(
  godot-layered-architecture
  godot-composition-first
  godot-mp-kit
  godot-agent-kit
  godot-studio-workflow
  godot-testing
  godot-animation
  godot-juicy
  godot-fsm
  godot-platformer-2d
  godot-playtest
  godot-visual-qa
  godot-studio-memory
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
CMD_DEST=""
GODOT_ROOT=""
ADDON_WHICH="mp_kit"
DO_SKILLS=1
DO_COMMANDS=1
DO_AGENTS=1

usage() {
  cat <<'EOF'
Godot studio kit installer (skills + commands + subagents + addons).

  ./install.sh                      ~/.cursor/skills, commands, and agents
  ./install.sh --project            ./.cursor/skills, commands, and agents of cwd
  ./install.sh --dest DIR           Skills in DIR (commands and agents alongside)
  ./install.sh --addon GODOT_ROOT [mp_kit|agent_kit|fsm_kit|plat_kit|all]
                                    Copy the addon into the Godot project (default: mp_kit)
  ./install.sh --addon-only GODOT_ROOT [mp_kit|agent_kit|fsm_kit|plat_kit|all]
                                    Addon only
  ./install.sh --agent-addon GODOT_ROOT
                                    Alias of --addon GODOT_ROOT agent_kit
  ./install.sh --list               What would be installed
  ./install.sh --pack               Build dist/godot-studio-skills.zip

  npx skills add Joelnicolass/godot-studio-skills -g -a cursor -y

EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --project)
      MODE="project"
      shift
      ;;
    --global|-g)
      MODE="global"
      shift
      ;;
    --dest)
      MODE="custom"
      DEST="${2:?--dest requires a directory}"
      shift 2
      ;;
    --addon)
      GODOT_ROOT="${2:?--addon requires the Godot project root}"
      shift 2
      if [[ $# -gt 0 && "$1" != -* ]]; then
        ADDON_WHICH="$1"
        shift
      fi
      ;;
    --addon-only)
      GODOT_ROOT="${2:?--addon-only requires the Godot project root}"
      DO_SKILLS=0
      DO_COMMANDS=0
      DO_AGENTS=0
      shift 2
      if [[ $# -gt 0 && "$1" != -* ]]; then
        ADDON_WHICH="$1"
        shift
      fi
      ;;
    --agent-addon)
      GODOT_ROOT="${2:?--agent-addon requires the Godot project root}"
      ADDON_WHICH="agent_kit"
      shift 2
      ;;
    --list)
      MODE="list"
      shift
      ;;
    --pack)
      exec "${ROOT}/pack.sh"
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ "$DO_SKILLS" -eq 1 && ! -d "$SRC" ]]; then
  echo "Cannot find ${SRC}. Run this script from the unzipped zip/repo?" >&2
  exit 1
fi

if [[ "$DO_COMMANDS" -eq 1 && ! -d "$CMD_SRC" ]]; then
  echo "Cannot find ${CMD_SRC}." >&2
  exit 1
fi

if [[ "$DO_AGENTS" -eq 1 && ! -d "$AGENT_SRC" ]]; then
  echo "Cannot find ${AGENT_SRC}." >&2
  exit 1
fi

if [[ -n "$GODOT_ROOT" && ! -d "$ADDONS_ROOT" ]]; then
  echo "Cannot find ${ADDONS_ROOT}" >&2
  exit 1
fi

if [[ "$DO_SKILLS" -eq 1 ]]; then
  for name in "${SKILL_NAMES[@]}"; do
    if [[ ! -f "${SRC}/${name}/SKILL.md" ]]; then
      echo "Missing skill: ${SRC}/${name}/SKILL.md" >&2
      exit 1
    fi
  done
fi

resolve_skill_dest() {
  case "$MODE" in
    global) echo "${HOME}/.cursor/skills" ;;
    project) echo "$(pwd)/.cursor/skills" ;;
    custom) echo "$DEST" ;;
    *) echo "" ;;
  esac
}

resolve_command_dest() {
  case "$MODE" in
    global) echo "${HOME}/.cursor/commands" ;;
    project) echo "$(pwd)/.cursor/commands" ;;
    custom)
      local parent
      parent="$(cd "$(dirname "$DEST")" && pwd)"
      echo "${parent}/commands"
      ;;
    *) echo "" ;;
  esac
}

resolve_agent_dest() {
  case "$MODE" in
    global) echo "${HOME}/.cursor/agents" ;;
    project) echo "$(pwd)/.cursor/agents" ;;
    custom)
      local parent
      parent="$(cd "$(dirname "$DEST")" && pwd)"
      echo "${parent}/agents"
      ;;
    *) echo "" ;;
  esac
}

copy_one_addon() {
  local project="$1"
  local name="$2"
  local src="${ADDONS_ROOT}/${name}"
  if [[ ! -d "$src" ]]; then
    echo "Cannot find ${src}" >&2
    exit 1
  fi
  local dest="${project}/addons/${name}"
  mkdir -p "${project}/addons"
  rm -rf "$dest"
  cp -R "$src" "$dest"
  if [[ -f "${dest}/cli.sh" ]]; then
    chmod +x "${dest}/cli.sh"
  fi
  echo "addon  ${dest}"
}

install_addon() {
  local project="$1"
  local which="$2"
  if [[ ! -d "$project" ]]; then
    echo "Godot project does not exist: ${project}" >&2
    exit 1
  fi
  if [[ ! -f "${project}/project.godot" ]]; then
    echo "No project.godot in ${project} — pass the Godot project root." >&2
    exit 1
  fi
  case "$which" in
    mp_kit)
      copy_one_addon "$project" "mp_kit"
      mkdir -p "${project}/.vscode"
      cp "${ADDONS_ROOT}/mp_kit/editor/mpkit.code-snippets" "${project}/.vscode/mpkit.code-snippets"
      echo "snippets  ${project}/.vscode/mpkit.code-snippets"
      echo
      echo "Enable the MpKit plugin (autoload). CI/headless, in project.godot:"
      echo '  MpKit="*res://addons/mp_kit/mp_kit.gd"'
      ;;
    agent_kit)
      copy_one_addon "$project" "agent_kit"
      echo
      echo "Enable the AgentKit plugin (autoload). CI/headless, in project.godot:"
      echo '  AgentKit="*res://addons/agent_kit/agent_kit.gd"'
      echo "CLI: ${project}/addons/agent_kit/cli.sh ${project} capture --out=/tmp/a.png"
      ;;
    fsm_kit)
      copy_one_addon "$project" "fsm_kit"
      echo
      echo "Enable the FsmKit plugin (FsmMachine / FsmState types, no autoload)."
      ;;
    plat_kit)
      copy_one_addon "$project" "plat_kit"
      echo
      echo "Enable the PlatKit plugin (PlatMotor type, no autoload)."
      echo "InputMap: move_left, move_right, jump."
      ;;
    all)
      install_addon "$project" "mp_kit"
      echo
      install_addon "$project" "agent_kit"
      echo
      install_addon "$project" "fsm_kit"
      echo
      install_addon "$project" "plat_kit"
      ;;
    *)
      echo "Unknown addon: ${which} (mp_kit | agent_kit | fsm_kit | plat_kit | all)" >&2
      exit 1
      ;;
  esac
}

install_commands() {
  local target="$1"
  mkdir -p "$target"
  echo "Commands → ${target}"
  local f
  for f in "${CMD_SRC}"/*.md; do
    cp "$f" "${target}/$(basename "$f")"
    echo "  ok  $(basename "$f" .md)"
  done
}

install_agents() {
  local target="$1"
  mkdir -p "$target"
  echo "Agents → ${target}"
  local name
  for name in "${AGENT_FILES[@]}"; do
    cp "${AGENT_SRC}/${name}" "${target}/${name}"
    echo "  ok  ${name%.md}"
  done
}

if [[ "$MODE" == "list" ]]; then
  echo "Skills:"
  for name in "${SKILL_NAMES[@]}"; do
    echo "  - ${name}"
  done
  echo
  echo "Commands (product / PRD / RFC):"
  for f in "${CMD_SRC}"/*.md; do
    echo "  - /$(basename "$f" .md)"
  done
  echo
  echo "Subagents:"
  for name in "${AGENT_FILES[@]}"; do
    echo "  - ${name%.md}"
  done
  echo
  echo "Addons:"
  echo "  - addons/mp_kit     (./install.sh --addon /path/to/godot-project)"
  echo "  - addons/agent_kit  (./install.sh --addon /path/to/godot-project agent_kit)"
  echo "  - addons/fsm_kit    (./install.sh --addon /path/to/godot-project fsm_kit)"
  echo "  - addons/plat_kit   (./install.sh --addon /path/to/godot-project plat_kit)"
  echo
  echo "Skills dest (global): ${HOME}/.cursor/skills"
  echo "Commands dest (global): ${HOME}/.cursor/commands"
  echo "Agents dest (global): ${HOME}/.cursor/agents"
  echo "Dest (--project): $(pwd)/.cursor/{skills,commands,agents}"
  exit 0
fi

if [[ "$DO_SKILLS" -eq 1 ]]; then
  TARGET="$(resolve_skill_dest)"
  mkdir -p "$TARGET"
  echo "Skills → ${TARGET}"
  for name in "${SKILL_NAMES[@]}"; do
    rm -rf "${TARGET}/${name}"
    cp -R "${SRC}/${name}" "${TARGET}/${name}"
    echo "  ok  ${name}"
  done
  echo
  echo "Done (skills). Open a new Cursor chat to reload."
  echo "  layers:       godot-layered-architecture"
  echo "  composition:  godot-composition-first"
  echo "  multiplayer:  godot-mp-kit"
  echo "  orchestrator: godot-studio-workflow"
  echo "  memory:       godot-studio-memory"
  echo "  playtest:     godot-playtest"
  echo "  agent kit:    godot-agent-kit"
  echo "  visual qa:    godot-visual-qa"
  echo "  tests:        godot-testing"
  echo "  animation:    godot-animation"
  echo "  juicy:        godot-juicy"
  echo "  fsm:          godot-fsm"
  echo "  platformer:   godot-platformer-2d"
fi

if [[ "$DO_COMMANDS" -eq 1 ]]; then
  CMD_DEST="$(resolve_command_dest)"
  echo
  install_commands "$CMD_DEST"
  echo
  echo "Done (commands). In Cursor: /implement-feature, /add-juicy, /add-state-machine, /add-platformer-2d, /create-prd, …"
fi

if [[ "$DO_AGENTS" -eq 1 ]]; then
  echo
  install_agents "$(resolve_agent_dest)"
  echo
  echo "Done (subagents). New chat to reload. The main agent orchestrates; it does not implement the whole game alone."
fi

if [[ -n "$GODOT_ROOT" ]]; then
  echo
  install_addon "$GODOT_ROOT" "$ADDON_WHICH"
fi

if [[ "$DO_SKILLS" -eq 0 && "$DO_COMMANDS" -eq 0 && "$DO_AGENTS" -eq 0 && -z "$GODOT_ROOT" ]]; then
  echo "Nothing to do." >&2
  exit 1
fi
