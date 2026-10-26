#!/usr/bin/env bash
# Instala skills, commands, subagentes (Cursor y/o Claude Code) y/o addons Godot.
#   ./install.sh                      # ~/.cursor/skills, commands, agents
#   ./install.sh --claude             # ~/.claude/skills, commands, agents
#   ./install.sh --all                # los dos
#   ./install.sh --project            # ./.cursor/ (o ./.claude/ con --claude) del cwd
#   ./install.sh --addon GODOT_ROOT   # addons/mp_kit → GODOT_ROOT/addons/mp_kit
# AgentKit se instala desde github.com/Joelnicolass/godot-studio-playtest (este script lo trae, con su módulo
# determinism). example/addons/agent_kit/ de acá es una copia de referencia del mismo módulo, no la fuente de instalación.
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
  godot-mp-kit
  godot-studio-workflow
  godot-testing
  godot-animation
  godot-juicy
  godot-fsm
  godot-platformer-2d
  godot-material-maker
  godot-reverse-engineering
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
Instalador del kit Godot studio (skills + commands + subagentes + addons).

  ./install.sh                      ~/.cursor/skills, commands y agents (Cursor, default)
  ./install.sh --claude             ~/.claude/skills, commands y agents (Claude Code)
  ./install.sh --all                Cursor y Claude Code
  ./install.sh --project            ./.cursor/ del cwd (./.claude/ con --claude; los dos con --all)
  ./install.sh --dest DIR           Skills en DIR (commands y agents al lado)
  ./install.sh --addon GODOT_ROOT [mp_kit|agent_kit|fsm_kit|plat_kit|all]
                                    Copia el addon al proyecto Godot (default: mp_kit)
                                    agent_kit se instala desde godot-studio-playtest
  ./install.sh --addon-only GODOT_ROOT [mp_kit|agent_kit|fsm_kit|plat_kit|all]
                                    Solo el addon
  ./install.sh --agent-addon GODOT_ROOT
                                    Alias de --addon GODOT_ROOT agent_kit
  ./install.sh --no-playtest        No instales skills/command/agente de playtest
  ./install.sh --list               Qué se instalaría
  ./install.sh --pack               Genera dist/godot-studio-skills.zip

  npx skills add Joelnicolass/godot-studio-skills -g -a cursor -y
  npx skills add Joelnicolass/godot-studio-playtest -g -a cursor -y
  npx skills add Joelnicolass/godot-studio-skills -g -a claude-code -y
  npx skills add Joelnicolass/godot-studio-playtest -g -a claude-code -y

AgentKit / playtester: https://github.com/Joelnicolass/godot-studio-playtest
Checkout local (prioridad): ../godot-studio-playtest
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
      DEST="${2:?--dest requiere un directorio}"
      shift 2
      ;;
    --addon)
      GODOT_ROOT="${2:?--addon requiere la raíz del proyecto Godot}"
      shift 2
      if [[ $# -gt 0 && "$1" != -* ]]; then
        ADDON_WHICH="$1"
        shift
      fi
      ;;
    --addon-only)
      GODOT_ROOT="${2:?--addon-only requiere la raíz del proyecto Godot}"
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
      GODOT_ROOT="${2:?--agent-addon requiere la raíz del proyecto Godot}"
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
      echo "Opción desconocida: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ "$DO_SKILLS" -eq 1 && ! -d "$SRC" ]]; then
  echo "No encuentro ${SRC}. ¿Corrés el script desde el zip/repo descomprimido?" >&2
  exit 1
fi

if [[ "$DO_COMMANDS" -eq 1 && ! -d "$CMD_SRC" ]]; then
  echo "No encuentro ${CMD_SRC}." >&2
  exit 1
fi

if [[ "$DO_AGENTS" -eq 1 && ! -d "$AGENT_SRC" ]]; then
  echo "No encuentro ${AGENT_SRC}." >&2
  exit 1
fi

needs_local_addons() {
  case "$ADDON_WHICH" in
    agent_kit) return 1 ;;
    *) return 0 ;;
  esac
}

if [[ -n "$GODOT_ROOT" ]] && needs_local_addons && [[ ! -d "$ADDONS_ROOT" ]]; then
  echo "No encuentro ${ADDONS_ROOT}" >&2
  exit 1
fi

if [[ "$DO_SKILLS" -eq 1 ]]; then
  for name in "${SKILL_NAMES[@]}"; do
    if [[ ! -f "${SRC}/${name}/SKILL.md" ]]; then
      echo "Falta skill: ${SRC}/${name}/SKILL.md" >&2
      exit 1
    fi
  done
fi

# Cursor y Claude Code comparten layout: <base>/{skills,commands,agents}.
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
    echo "GODOT_STUDIO_PLAYTEST=${explicit} no tiene install.sh" >&2
    return 1
  fi
  local sibling
  sibling="$(cd "${ROOT}/.." && pwd)/godot-studio-playtest"
  if [[ -x "${sibling}/install.sh" ]]; then
    echo "playtest  ${sibling} (checkout local)" >&2
    echo "$sibling"
    return 0
  fi
  if ! command -v git >/dev/null 2>&1; then
    echo "Hace falta git para clonar ${PLAYTEST_REPO}" >&2
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
    echo "El clone de playtest no tiene install.sh" >&2
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
    echo "Aviso: no instalé AgentKit/playtester. Cloná https://github.com/Joelnicolass/godot-studio-playtest y corré su ./install.sh" >&2
    return 0
  fi
  echo
  echo "Módulo playtest ($(harness_label "$harness")) → ${PLAYTEST_ROOT}"
  case "${MODE}:${harness}" in
    global:cursor) "${PLAYTEST_ROOT}/install.sh" --global ;;
    project:cursor) "${PLAYTEST_ROOT}/install.sh" --project ;;
    # El instalador de playtest solo conoce ~/.cursor: a Claude Code va por --dest.
    *) "${PLAYTEST_ROOT}/install.sh" --dest "$(resolve_skill_dest "$harness")" ;;
  esac
}

install_playtest_addon() {
  local project="$1"
  local root
  if ! root="$(ensure_playtest)"; then
    echo "No pude obtener godot-studio-playtest para instalar AgentKit." >&2
    echo "  git clone ${PLAYTEST_REPO}" >&2
    echo "  ./install.sh --addon ${project}" >&2
    exit 1
  fi
  echo "Módulo playtest (addon) → ${root}"
  "${root}/install.sh" --addon-only "$project"
}

copy_one_addon() {
  local project="$1"
  local name="$2"
  local src="${ADDONS_ROOT}/${name}"
  if [[ ! -d "$src" ]]; then
    echo "No encuentro ${src}" >&2
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
    echo "No existe el proyecto Godot: ${project}" >&2
    exit 1
  fi
  if [[ ! -f "${project}/project.godot" ]]; then
    echo "No hay project.godot en ${project} — pasá la raíz del proyecto Godot." >&2
    exit 1
  fi
  case "$which" in
    mp_kit)
      copy_one_addon "$project" "mp_kit"
      mkdir -p "${project}/.vscode"
      cp "${ADDONS_ROOT}/mp_kit/editor/mpkit.code-snippets" "${project}/.vscode/mpkit.code-snippets"
      echo "snippets  ${project}/.vscode/mpkit.code-snippets"
      echo
      echo "Habilitá el plugin MpKit (autoload). CI/headless, en project.godot:"
      echo '  MpKit="*res://addons/mp_kit/mp_kit.gd"'
      ;;
    agent_kit)
      install_playtest_addon "$project"
      ;;
    fsm_kit)
      copy_one_addon "$project" "fsm_kit"
      echo
      echo "Habilitá el plugin FsmKit (tipos FsmMachine / FsmState, sin autoload)."
      ;;
    plat_kit)
      copy_one_addon "$project" "plat_kit"
      echo
      echo "Habilitá el plugin PlatKit (tipo PlatMotor, sin autoload)."
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
      echo "Addon desconocido: ${which} (mp_kit | agent_kit | fsm_kit | plat_kit | all)" >&2
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
  echo "Commands (producto / PRD / RFC):"
  for f in "${CMD_SRC}"/*.md; do
    echo "  - /$(basename "$f" .md)"
  done
  echo
  echo "Subagentes:"
  for name in "${AGENT_FILES[@]}"; do
    echo "  - ${name%.md}"
  done
  echo
  echo "Addons (este repo):"
  echo "  - addons/mp_kit     (./install.sh --addon /path/to/godot-project)"
  echo "  - addons/fsm_kit    (./install.sh --addon /path/to/godot-project fsm_kit)"
  echo "  - addons/plat_kit   (./install.sh --addon /path/to/godot-project plat_kit)"
  echo
  echo "AgentKit / playtester (repo aparte, este instalador lo trae):"
  echo "  https://github.com/Joelnicolass/godot-studio-playtest"
  echo "  ./install.sh --addon /path/to/godot-project agent_kit"
  echo
  echo "Destino Cursor (default):      ${HOME}/.cursor/{skills,commands,agents}"
  echo "Destino Claude Code (--claude): ${HOME}/.claude/{skills,commands,agents}"
  echo "Con --project: $(pwd)/.cursor/ o $(pwd)/.claude/"
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
    echo "Listo (skills). Sesión nueva en ${label} para recargar."
    echo "  capas:        godot-layered-architecture"
    echo "  composición:  godot-composition-first"
    echo "  multiplayer:  godot-mp-kit"
    echo "  orquestador:  godot-studio-workflow"
    echo "  memoria:      godot-studio-memory"
    echo "  visual qa:    godot-visual-qa"
    echo "  tests:        godot-testing"
    echo "  animación:    godot-animation"
    echo "  juicy:        godot-juicy"
    echo "  fsm:          godot-fsm"
    echo "  plataformas:  godot-platformer-2d"
    echo "  materiales:   godot-material-maker"
    echo "  ing. inversa: godot-reverse-engineering"
  fi

  if [[ "$DO_COMMANDS" -eq 1 ]]; then
    CMD_DEST="$(resolve_command_dest "$harness")"
    echo
    install_commands "$CMD_DEST"
    echo
    echo "Listo (commands). En ${label}: /implement-feature, /add-juicy, /add-state-machine, /add-platformer-2d, /create-material, /reverse-engineer, /create-prd, …"
  fi

  if [[ "$DO_AGENTS" -eq 1 ]]; then
    echo
    install_agents "$(resolve_agent_dest "$harness")"
    echo
    echo "Listo (subagentes). Sesión nueva para recargar. El principal orquesta; no implementa el juego entero solo."
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
  echo "Nada que hacer." >&2
  exit 1
fi
