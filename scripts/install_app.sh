#!/usr/bin/env bash
set -euo pipefail

SCHEME="SB_Codex"
DESTINATION="${HOME}/Applications/CursorCompanion.app"

build_dir=$(xcodebuild -scheme "${SCHEME}" -showBuildProductsDirectory 2>/dev/null | tail -n1)
if [[ -z "${build_dir}" ]]; then
  echo "Could not determine build products directory. Build the scheme in Xcode first." >&2
  exit 1
fi

source_app="${build_dir}/${SCHEME}.app"
if [[ ! -d "${source_app}" ]]; then
  echo "App bundle not found at ${source_app}. Build the scheme before running this script." >&2
  exit 1
fi

mkdir -p "$(dirname "${DESTINATION}")"
rsync -a --delete "${source_app}/" "${DESTINATION}/"

echo "Installed ${SCHEME}.app to ${DESTINATION}"
