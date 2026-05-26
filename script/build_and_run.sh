#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="CodexUsageMonitor"
BUNDLE_ID="com.dhseo.mycodex.CodexUsageMonitor"
MIN_SYSTEM_VERSION="14.0"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
XCRUN="/usr/bin/xcrun"

build_bundle() {
  "$XCRUN" swift build -c release --product "$APP_NAME"
  "$XCRUN" swift build -c release --product codex-usage
  local build_bin
  build_bin="$("$XCRUN" swift build -c release --show-bin-path)"

  rm -rf "$APP_BUNDLE"
  mkdir -p "$APP_MACOS" "$APP_RESOURCES"
  cp "$build_bin/$APP_NAME" "$APP_BINARY"
  chmod +x "$APP_BINARY"
  if [[ -d "$ROOT_DIR/Sources/CodexUsageMonitor/Resources/Runner" ]]; then
    /usr/bin/ditto --noextattr "$ROOT_DIR/Sources/CodexUsageMonitor/Resources/Runner" "$APP_RESOURCES/Runner"
  fi

  cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>Codex Usage</string>
  <key>CFBundleDisplayName</key>
  <string>Codex Usage</string>
  <key>CFBundleURLTypes</key>
  <array>
    <dict>
      <key>CFBundleURLName</key>
      <string>$BUNDLE_ID</string>
      <key>CFBundleURLSchemes</key>
      <array>
        <string>codexusage</string>
      </array>
    </dict>
  </array>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

  /usr/bin/xattr -cr "$APP_BUNDLE" >/dev/null 2>&1 || true
  /usr/bin/codesign --force --sign - "$APP_BUNDLE" >/dev/null
  /usr/bin/xattr -c "$APP_BUNDLE" >/dev/null 2>&1 || true
}

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

verify_app() {
  open_app
  sleep 2
  pgrep -x "$APP_NAME" >/dev/null
}

case "$MODE" in
  run)
    pkill -x "$APP_NAME" >/dev/null 2>&1 || true
    build_bundle
    open_app
    ;;
  --no-run|no-run)
    build_bundle
    echo "$APP_BUNDLE"
    ;;
  --verify|verify)
    pkill -x "$APP_NAME" >/dev/null 2>&1 || true
    build_bundle
    verify_app
    ;;
  --logs|logs)
    pkill -x "$APP_NAME" >/dev/null 2>&1 || true
    build_bundle
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    pkill -x "$APP_NAME" >/dev/null 2>&1 || true
    build_bundle
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --debug|debug)
    build_bundle
    /usr/bin/lldb -- "$APP_BINARY"
    ;;
  *)
    echo "usage: $0 [run|--no-run|--verify|--logs|--telemetry|--debug]" >&2
    exit 2
    ;;
esac
