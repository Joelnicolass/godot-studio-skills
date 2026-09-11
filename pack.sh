#!/usr/bin/env bash
# Arma dist/godot-studio-skills.zip (instalable con unzip + ./install.sh).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIST="${ROOT}/dist"
NAME="godot-studio-skills"
STAMP="$(date +%Y%m%d)"
ZIP="${DIST}/${NAME}-${STAMP}.zip"
LATEST="${DIST}/${NAME}.zip"

mkdir -p "$DIST"
rm -f "$ZIP" "$LATEST"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

STAGE="${TMP}/${NAME}"
mkdir -p "$STAGE"
cp -R "${ROOT}/skills" "$STAGE/"
cp "${ROOT}/install.sh" "${ROOT}/uninstall.sh" "${ROOT}/pack.sh" \
  "${ROOT}/README.md" "${ROOT}/publish.env.example" "$STAGE/"
# .gitignore es opcional en el zip; el usuario instala, no clona desde ahí.

(
  cd "$TMP"
  zip -rq "$ZIP" "$NAME"
)

cp "$ZIP" "$LATEST"
echo "zip  ${ZIP}"
echo "zip  ${LATEST}"
echo
echo "Instalar desde el zip:"
echo "  unzip ${LATEST} && cd ${NAME} && ./install.sh"
