#!/usr/bin/env bash
# Instala skills Cursor y/o el addon Godot MpKit.
#   ./install.sh                      # skills → ~/.cursor/skills/
#   ./install.sh --project            # skills → ./.cursor/skills/
#   ./install.sh --addon GODOT_ROOT   # addons/mp_kit → GODOT_ROOT/addons/mp_kit
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="${ROOT}/skills"
ADDON_SRC="${ROOT}/addons/mp_kit"
SKILL_NAMES=(
  godot-layered-architecture
  godot-composition-first
  godot-mp-kit
)

MODE="global"
DEST=""
GODOT_ROOT=""
DO_SKILLS=1

usage() {
  cat <<'EOF'
Instalador del kit Godot studio (skills Cursor + addon MpKit).

  ./install.sh                      Skills en ~/.cursor/skills/
  ./install.sh --project            Skills en ./.cursor/skills/
  ./install.sh --dest DIR           Skills en DIR
  ./install.sh --addon GODOT_ROOT   Copia addons/mp_kit al proyecto Godot
  ./install.sh --addon-only GODOT_ROOT
                                    Solo el addon, sin skills
  ./install.sh --list               Qué se instalaría
  ./install.sh --pack               Genera dist/godot-studio-skills.zip

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
      DEST="${2:?--dest requiere un directorio}"
      shift 2
      ;;
    --addon)
      GODOT_ROOT="${2:?--addon requiere la raíz del proyecto Godot}"
      shift 2
      ;;
    --addon-only)
      GODOT_ROOT="${2:?--addon-only requiere la raíz del proyecto Godot}"
      DO_SKILLS=0
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

if [[ -n "$GODOT_ROOT" && ! -d "$ADDON_SRC" ]]; then
  echo "No encuentro ${ADDON_SRC}" >&2
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

resolve_dest() {
  case "$MODE" in
    global) echo "${HOME}/.cursor/skills" ;;
    project) echo "$(pwd)/.cursor/skills" ;;
    custom) echo "$DEST" ;;
    *) echo "" ;;
  esac
}

install_addon() {
  local project="$1"
  if [[ ! -d "$project" ]]; then
    echo "No existe el proyecto Godot: ${project}" >&2
    exit 1
  fi
  if [[ ! -f "${project}/project.godot" ]]; then
    echo "No hay project.godot en ${project} — pasá la raíz del proyecto Godot." >&2
    exit 1
  fi
  local dest="${project}/addons/mp_kit"
  mkdir -p "${project}/addons"
  rm -rf "$dest"
  cp -R "$ADDON_SRC" "$dest"
  echo "addon  ${dest}"
  echo
  echo "En project.godot, autoload (antes del glue):"
  echo '  MpKit="*res://addons/mp_kit/mp_kit.gd"'
}

if [[ "$MODE" == "list" ]]; then
  echo "Skills:"
  for name in "${SKILL_NAMES[@]}"; do
    echo "  - ${name}"
  done
  echo
  echo "Addon:"
  echo "  - addons/mp_kit  (./install.sh --addon /path/to/godot-project)"
  echo
  echo "Destino skills (global): ${HOME}/.cursor/skills"
  echo "Destino skills (--project): $(pwd)/.cursor/skills"
  exit 0
fi

if [[ "$DO_SKILLS" -eq 1 ]]; then
  TARGET="$(resolve_dest)"
  mkdir -p "$TARGET"
  echo "Skills → ${TARGET}"
  for name in "${SKILL_NAMES[@]}"; do
    rm -rf "${TARGET}/${name}"
    cp -R "${SRC}/${name}" "${TARGET}/${name}"
    echo "  ok  ${name}"
  done
  echo
  echo "Listo (skills). Chat nuevo en Cursor para recargar."
  echo "  capas:        godot-layered-architecture"
  echo "  composición:  godot-composition-first"
  echo "  multiplayer:  godot-mp-kit"
fi

if [[ -n "$GODOT_ROOT" ]]; then
  echo
  install_addon "$GODOT_ROOT"
fi

if [[ "$DO_SKILLS" -eq 0 && -z "$GODOT_ROOT" ]]; then
  echo "Nada que hacer." >&2
  exit 1
fi
