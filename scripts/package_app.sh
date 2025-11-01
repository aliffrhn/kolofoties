#!/usr/bin/env bash
set -euo pipefail

CONFIG=${1:-release}
PRODUCT_NAME="SB_Codex"
APP_NAME="CursorCompanion"
BUNDLE_ID="dev.cursorcompanion.app"
APP_DIR="$HOME/Applications/${APP_NAME}.app"

# Build the SwiftPM target unless explicitly skipped (for Xcode post-actions).
if [[ "${SKIP_SWIFT_BUILD:-0}" != "1" ]]; then
  swift build -c "$CONFIG" >/dev/null
fi

if [[ -n "${EXISTING_BINARY_PATH:-}" ]]; then
  BINARY_PATH="${EXISTING_BINARY_PATH}"
else
  BIN_DIR=$(swift build -c "$CONFIG" --show-bin-path)
  BINARY_PATH="${BIN_DIR}/${PRODUCT_NAME}"
fi

if [[ ! -x "${BINARY_PATH}" ]]; then
  echo "Built binary not found at ${BINARY_PATH}" >&2
  exit 1
fi

rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"

cat > "${APP_DIR}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleExecutable</key>
    <string>${PRODUCT_NAME}</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHumanReadableCopyright</key>
    <string>Cursor Companion</string>
    <key>NSMainNibFile</key>
    <string></string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

cp "${BINARY_PATH}" "${APP_DIR}/Contents/MacOS/${PRODUCT_NAME}"
chmod +x "${APP_DIR}/Contents/MacOS/${PRODUCT_NAME}"

codesign --force --deep --sign - "${APP_DIR}" >/dev/null

echo "Packaged app installed to ${APP_DIR}" >&2
