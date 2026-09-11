#!/usr/bin/env bash
# Instala las skills Godot (capas, composición, MpKit) en Cursor.
# Uso:
#   ./install.sh              # global: ~/.cursor/skills/
#   ./install.sh --project    # este repo: ./.cursor/skills/
#   ./install.sh --dest DIR   # carpeta arbitraria
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="${ROOT}/skills"
SKILL_NAMES=(
  godot-layered-architecture
  godot-composition-first
  godot-mp-kit
)

MODE="global"
DEST=""

usage() {
  cat <<'EOF'
Instalador de skills Godot para Cursor.

  ./install.sh              Instala en ~/.cursor/skills/ (todos tus proyectos)
  ./install.sh --project    Instala en ./.cursor/skills/ (solo este working copy)
  ./install.sh --dest DIR   Copia las tres skills a DIR
  ./install.sh --list       Muestra qué se instalaría
  ./install.sh --pack       Genera dist/godot-studio-skills.zip y sale

Tras clonar el repo (cuando exista el remoto):

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

if [[ ! -d "$SRC" ]]; then
  echo "No encuentro ${SRC}. ¿Corrés el script desde el zip/repo descomprimido?" >&2
  exit 1
fi

for name in "${SKILL_NAMES[@]}"; do
  if [[ ! -f "${SRC}/${name}/SKILL.md" ]]; then
    echo "Falta skill: ${SRC}/${name}/SKILL.md" >&2
    exit 1
  fi
done

resolve_dest() {
  case "$MODE" in
    global) echo "${HOME}/.cursor/skills" ;;
    project) echo "$(pwd)/.cursor/skills" ;;
    custom) echo "$DEST" ;;
    *) echo "" ;;
  esac
}

if [[ "$MODE" == "list" ]]; then
  echo "Skills:"
  for name in "${SKILL_NAMES[@]}"; do
    echo "  - ${name}"
  done
  echo
  echo "Destino por defecto (global): ${HOME}/.cursor/skills"
  echo "Destino --project:            $(pwd)/.cursor/skills"
  exit 0
fi

TARGET="$(resolve_dest)"
mkdir -p "$TARGET"

echo "Instalando en ${TARGET}"
for name in "${SKILL_NAMES[@]}"; do
  rm -rf "${TARGET}/${name}"
  cp -R "${SRC}/${name}" "${TARGET}/${name}"
  echo "  ok  ${name}"
done

echo
echo "Listo. Abrí un chat nuevo en Cursor para que cargue las skills."
echo "  capas:        godot-layered-architecture"
echo "  composición:  godot-composition-first"
echo "  multiplayer:  godot-mp-kit"
