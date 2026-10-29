#!/usr/bin/env bash
# Install skills, commands, subagents (Cursor and/or Claude Code), and/or Godot addons.
#   ./install.sh                      # ~/.cursor/skills, commands, agents
#   ./install.sh --claude             # ~/.claude/skills, commands, agents
#   ./install.sh --all                # both
#   ./install.sh --project            # ./.cursor/ (or ./.claude/ with --claude) of cwd
#   ./install.sh --addon GODOT_ROOT   # addons/mp_kit → GODOT_ROOT/addons/mp_kit
# AgentKit is installed from github.com/Joelnicolass/godot-studio-playtest (this script fetches it, including its
# determinism module). example/addons/agent_kit/ here is a reference copy of the same module, not the install source.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="${ROOT}/skills"
CMD_SRC="${ROOT}/commands"
AGENT_SRC="${ROOT}/agents"
ADDONS_ROOT="${ROOT}/addons"
PLAYTEST_REPO="${GODOT_STUDIO_PLAYTEST_REPO:-https://github.com/Joelnicolass/godot-studio-playtest.git}"
PLAYTEST_REF="${GODOT_STUDIO_PLAYTEST_REF:-main}"
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
)
AGENT_FILES=(
  studio-tech-lead.md
  studio-developer.md
  studio-reviewer.md
  studio-tester.md
  studio-visual.md
)

MODE="global"
HARNESS="cursor"
PLAYTEST_ROOT=""
DEST=""
CMD_DEST=""
GODOT_ROOT=""
ADDON_WHICH="mp_kit"
DO_SKILLS=1
DO_COMMANDS=1
DO_AGENTS=1
DO_PLAYTEST=1

usage() {
  cat <<'EOF'
Godot studio kit installer (skills + commands + subagents + addons).

  ./install.sh                      ~/.cursor/skills, commands, and agents (Cursor, default)
  ./install.sh --claude             ~/.claude/skills, commands, and agents (Claude Code)
  ./install.sh --all                Cursor and Claude Code
  ./install.sh --project            ./.cursor/ of cwd (./.claude/ with --claude; both with --all)
  ./install.sh --dest DIR           Skills in DIR (commands and agents alongside)
  ./install.sh --addon GODOT_ROOT [mp_kit|agent_kit|fsm_kit|plat_kit|rts_kit|prop_kit|grass_kit|all]
                                    Copy the addon into the Godot project (default: mp_kit)
                                    agent_kit is installed from godot-studio-playtest
  ./install.sh --addon-only GODOT_ROOT [mp_kit|agent_kit|fsm_kit|plat_kit|rts_kit|prop_kit|grass_kit|all]
                                    Addon only
  ./install.sh --agent-addon GODOT_ROOT
                                    Alias of --addon GODOT_ROOT agent_kit
  ./install.sh --no-playtest        Skip playtest skills/command/agent
  ./install.sh --list               What would be installed
  ./install.sh --pack               Build dist/godot-studio-skills.zip

  npx skills add Joelnicolass/godot-studio-skills -g -a cursor -y
  npx skills add Joelnicolass/godot-studio-playtest -g -a cursor -y
  npx skills add Joelnicolass/godot-studio-skills -g -a claude-code -y
  npx skills add Joelnicolass/godot-studio-playtest -g -a claude-code -y

AgentKit / playtester: https://github.com/Joelnicolass/godot-studio-playtest
Local checkout (preferred): ../godot-studio-playtest
Override: GODOT_STUDIO_PLAYTEST=/path  GODOT_STUDIO_PLAYTEST_REF=main

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
    --cursor)
      HARNESS="cursor"
      shift
      ;;
    --claude)
      HARNESS="claude"
      shift
      ;;
    --all)
      HARNESS="all"
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
    --no-playtest)
      DO_PLAYTEST=0
      shift
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
  echo "Cannot find ${SRC}. Run the script from the unpacked zip/repo?" >&2
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

needs_local_addons() {
  case "$ADDON_WHICH" in
    agent_kit) return 1 ;;
    *) return 0 ;;
  esac
}

if [[ -n "$GODOT_ROOT" ]] && needs_local_addons && [[ ! -d "$ADDONS_ROOT" ]]; then
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

# Cursor and Claude Code share one layout: <base>/{skills,commands,agents}.
harness_list() {
  if [[ "$MODE" == "custom" ]]; then
    echo "custom"
    return
  fi
  case "$HARNESS" in
    all) echo "cursor claude" ;;
    *) echo "$HARNESS" ;;
  esac
}

harness_label() {
  case "$1" in
    cursor) echo "Cursor" ;;
    claude) echo "Claude Code" ;;
    *) echo "$DEST" ;;
  esac
}

harness_base() {
  case "$MODE" in
    global) echo "${HOME}/.$1" ;;
    project) echo "$(pwd)/.$1" ;;
    custom) (cd "$(dirname "$DEST")" && pwd) ;;
    *) echo "" ;;
  esac
}

resolve_skill_dest() {
  if [[ "$MODE" == "custom" ]]; then
    echo "$DEST"
  else
    echo "$(harness_base "$1")/skills"
  fi
}

resolve_command_dest() {
  echo "$(harness_base "$1")/commands"
}

resolve_agent_dest() {
  echo "$(harness_base "$1")/agents"
}

ensure_playtest() {
  local explicit="${GODOT_STUDIO_PLAYTEST:-}"
  if [[ -n "$explicit" ]]; then
    if [[ -x "${explicit}/install.sh" ]]; then
      echo "$explicit"
      return 0
    fi
    echo "GODOT_STUDIO_PLAYTEST=${explicit} has no install.sh" >&2
    return 1
  fi
  local sibling
  sibling="$(cd "${ROOT}/.." && pwd)/godot-studio-playtest"
  if [[ -x "${sibling}/install.sh" ]]; then
    echo "playtest  ${sibling} (local checkout)" >&2
    echo "$sibling"
    return 0
  fi
  if ! command -v git >/dev/null 2>&1; then
    echo "git is required to clone ${PLAYTEST_REPO}" >&2
    return 1
  fi
  local cache="${XDG_CACHE_HOME:-${HOME}/.cache}/godot-studio-playtest"
  if [[ -d "${cache}/.git" ]]; then
    echo "playtest  fetch ${PLAYTEST_REF} → ${cache}" >&2
    git -C "$cache" fetch --depth 1 origin "$PLAYTEST_REF" >&2
    git -C "$cache" checkout -q --detach FETCH_HEAD
  else
    mkdir -p "$(dirname "$cache")"
    rm -rf "$cache"
    echo "playtest  clone ${PLAYTEST_REPO} (${PLAYTEST_REF})" >&2
    git clone --depth 1 --branch "$PLAYTEST_REF" "$PLAYTEST_REPO" "$cache" >&2
  fi
  if [[ ! -x "${cache}/install.sh" ]]; then
    echo "Playtest clone has no install.sh" >&2
    return 1
  fi
  echo "$cache"
}

install_playtest_harness() {
  local harness="$1"
  [[ "$DO_PLAYTEST" -eq 1 ]] || return 0
  [[ "$DO_SKILLS" -eq 1 || "$DO_COMMANDS" -eq 1 || "$DO_AGENTS" -eq 1 ]] || return 0
  if [[ -z "$PLAYTEST_ROOT" ]] && ! PLAYTEST_ROOT="$(ensure_playtest)"; then
    PLAYTEST_ROOT=""
    echo "Warning: AgentKit/playtester was not installed. Clone https://github.com/Joelnicolass/godot-studio-playtest and run its ./install.sh" >&2
    return 0
  fi
  echo
  echo "Playtest module ($(harness_label "$harness")) → ${PLAYTEST_ROOT}"
  case "${MODE}:${harness}" in
    global:cursor) "${PLAYTEST_ROOT}/install.sh" --global ;;
    project:cursor) "${PLAYTEST_ROOT}/install.sh" --project ;;
    # The playtest installer only knows ~/.cursor: Claude Code goes through --dest.
    *) "${PLAYTEST_ROOT}/install.sh" --dest "$(resolve_skill_dest "$harness")" ;;
  esac
}

install_playtest_addon() {
  local project="$1"
  local root
  if ! root="$(ensure_playtest)"; then
    echo "Could not obtain godot-studio-playtest to install AgentKit." >&2
    echo "  git clone ${PLAYTEST_REPO}" >&2
    echo "  ./install.sh --addon ${project}" >&2
    exit 1
  fi
  echo "Playtest module (addon) → ${root}"
  "${root}/install.sh" --addon-only "$project"
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
  # A dev checkout may have installed the relay's dependency: the game gets the sources, not node_modules.
  find "$dest" -name node_modules -type d -prune -exec rm -rf {} +
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
      install_playtest_addon "$project"
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
    rts_kit)
      copy_one_addon "$project" "rts_kit"
      echo
      echo "Enable the RtsKit plugin (no autoload). Default keys: Project > Tools > RtsKit: Add default input actions."
      echo "Start from addons/rts_kit/examples/skirmish_3d or skirmish_2d."
      ;;
    prop_kit)
      copy_one_addon "$project" "prop_kit"
      echo
      echo "Enable the PropKit plugin (no autoload). Props cut the navmesh in group prop_obstruction,"
      echo "on a collision layer the navmesh does not parse. Start from addons/prop_kit/examples/forest_3d or grove_2d."
      ;;
    grass_kit)
      copy_one_addon "$project" "grass_kit"
      echo
      echo "Enable the GrassKit plugin (no autoload). Add a GrassField3D (it sets itself up), select it and paint"
      echo "with the brushes on top of the 3D view. Start from addons/grass_kit/examples/grass_3d."
      ;;
    all)
      install_addon "$project" "mp_kit"
      echo
      install_addon "$project" "agent_kit"
      echo
      install_addon "$project" "fsm_kit"
      echo
      install_addon "$project" "plat_kit"
      echo
      install_addon "$project" "rts_kit"
      echo
      install_addon "$project" "prop_kit"
      echo
      install_addon "$project" "grass_kit"
      ;;
    *)
      echo "Unknown addon: ${which} (mp_kit | agent_kit | fsm_kit | plat_kit | rts_kit | prop_kit | grass_kit | all)" >&2
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
  echo "Addons (this repo):"
  echo "  - addons/mp_kit     (./install.sh --addon /path/to/godot-project)"
  echo "  - addons/fsm_kit    (./install.sh --addon /path/to/godot-project fsm_kit)"
  echo "  - addons/plat_kit   (./install.sh --addon /path/to/godot-project plat_kit)"
  echo "  - addons/rts_kit    (./install.sh --addon /path/to/godot-project rts_kit)"
  echo "  - addons/prop_kit   (./install.sh --addon /path/to/godot-project prop_kit)"
  echo "  - addons/grass_kit  (./install.sh --addon /path/to/godot-project grass_kit)"
  echo
  echo "AgentKit / playtester (separate repo, this installer fetches it):"
  echo "  https://github.com/Joelnicolass/godot-studio-playtest"
  echo "  ./install.sh --addon /path/to/godot-project agent_kit"
  echo
  echo "Cursor dest (default):       ${HOME}/.cursor/{skills,commands,agents}"
  echo "Claude Code dest (--claude): ${HOME}/.claude/{skills,commands,agents}"
  echo "With --project: $(pwd)/.cursor/ or $(pwd)/.claude/"
  exit 0
fi

install_harness() {
  local harness="$1"
  local label
  label="$(harness_label "$harness")"
  if [[ "$DO_SKILLS" -eq 1 ]]; then
    TARGET="$(resolve_skill_dest "$harness")"
    mkdir -p "$TARGET"
    echo "Skills → ${TARGET}"
    for name in "${SKILL_NAMES[@]}"; do
      rm -rf "${TARGET}/${name}"
      cp -R "${SRC}/${name}" "${TARGET}/${name}"
      echo "  ok  ${name}"
    done
    echo
    echo "Done (skills). New ${label} session to reload."
    echo "  layers:       godot-layered-architecture"
    echo "  composition:  godot-composition-first"
    echo "  quality:      godot-code-quality"
    echo "  multiplayer:  godot-mp-kit"
    echo "  orchestrator: godot-studio-workflow"
    echo "  memory:       godot-studio-memory"
    echo "  visual qa:    godot-visual-qa"
    echo "  tests:        godot-testing"
    echo "  animation:    godot-animation"
    echo "  juicy:        godot-juicy"
    echo "  fsm:          godot-fsm"
    echo "  platformer:   godot-platformer-2d"
    echo "  rts:          godot-rts-kit"
    echo "  props:        godot-prop-kit"
    echo "  grass:        godot-grass-kit"
    echo "  materials:    godot-material-maker"
    echo "  research:     godot-feature-research"
  fi

  if [[ "$DO_COMMANDS" -eq 1 ]]; then
    CMD_DEST="$(resolve_command_dest "$harness")"
    echo
    install_commands "$CMD_DEST"
    echo
    echo "Done (commands). In ${label}: /implement-feature, /add-juicy, /add-state-machine, /add-platformer-2d, /add-rts-controls, /add-props, /add-grass, /create-material, /research-feature, /create-prd, …"
  fi

  if [[ "$DO_AGENTS" -eq 1 ]]; then
    echo
    install_agents "$(resolve_agent_dest "$harness")"
    echo
    echo "Done (subagents). New session to reload. The main agent orchestrates; it does not implement the whole game alone."
  fi

  install_playtest_harness "$harness"
}

for harness in $(harness_list); do
  install_harness "$harness"
done

if [[ -n "$GODOT_ROOT" ]]; then
  echo
  install_addon "$GODOT_ROOT" "$ADDON_WHICH"
fi

if [[ "$DO_SKILLS" -eq 0 && "$DO_COMMANDS" -eq 0 && "$DO_AGENTS" -eq 0 && -z "$GODOT_ROOT" ]]; then
  echo "Nothing to do." >&2
  exit 1
fi
