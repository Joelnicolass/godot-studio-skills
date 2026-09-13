#!/usr/bin/env bash
# Build dist/godot-studio-skills.zip (installable with unzip + ./install.sh).
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
cp -R "${ROOT}/commands" "$STAGE/"
cp -R "${ROOT}/addons" "$STAGE/"
cp "${ROOT}/install.sh" "${ROOT}/uninstall.sh" "${ROOT}/pack.sh" \
  "${ROOT}/README.md" "${ROOT}/publish.env.example" "$STAGE/"
# .gitignore is optional in the zip; the user installs, they do not clone from there.

(
  cd "$TMP"
  zip -rq "$ZIP" "$NAME"
)

cp "$ZIP" "$LATEST"
echo "zip  ${ZIP}"
echo "zip  ${LATEST}"
echo
echo "Install from the zip:"
echo "  unzip ${LATEST} && cd ${NAME} && ./install.sh"
echo "  ./install.sh --addon /path/to/godot-project"
