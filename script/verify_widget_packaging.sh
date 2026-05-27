#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXT_DIR="$ROOT_DIR/Apps/MacDogWidgetExtension"
HOST_DIR="$ROOT_DIR/Apps/MacDogWidgetHost"
XCODE_PROJECT="$ROOT_DIR/MacDog.xcodeproj"
DERIVED_DATA="$ROOT_DIR/.build/xcode-widget"
HOST_APP="$DERIVED_DATA/Build/Products/Debug/MacDogWidgetHost.app"
EMBEDDED_APPEX="$HOST_APP/Contents/PlugIns/MacDogWidgetExtension.appex"
PLIST="$EXT_DIR/Info.plist"
ENTITLEMENTS="$EXT_DIR/MacDogWidgetExtension.entitlements"
ENTRYPOINT="$EXT_DIR/MacDogWidgetExtension.swift"
HOST_ENTRYPOINT="$HOST_DIR/MacDogWidgetHost.swift"
HOST_PLIST="$HOST_DIR/Info.plist"
HOST_ENTITLEMENTS="$HOST_DIR/MacDogWidgetHost.entitlements"

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
XCODEBUILD="/usr/bin/xcodebuild"
PLISTBUDDY="/usr/libexec/PlistBuddy"

require_file() {
  [[ -f "$1" ]] || {
    echo "missing required widget packaging file: $1" >&2
    exit 1
  }
}

require_dir() {
  [[ -d "$1" ]] || {
    echo "missing required widget packaging directory: $1" >&2
    exit 1
  }
}

require_plist_value() {
  local file="$1"
  local key="$2"
  local expected="$3"
  local actual
  actual="$($PLISTBUDDY -c "Print :$key" "$file")"
  [[ "$actual" == "$expected" ]] || {
    echo "unexpected plist value for $key: $actual, expected $expected" >&2
    exit 1
  }
}

require_text_match() {
  local pattern="$1"
  local file="$2"

  if command -v rg >/dev/null 2>&1; then
    rg -q "$pattern" "$file"
  else
    /usr/bin/grep -Eq "$pattern" "$file"
  fi
}

require_file "$ENTRYPOINT"
require_file "$PLIST"
require_file "$ENTITLEMENTS"
require_file "$HOST_ENTRYPOINT"
require_file "$HOST_PLIST"
require_file "$HOST_ENTITLEMENTS"
require_dir "$XCODE_PROJECT"

require_text_match 'import SwiftUI' "$ENTRYPOINT"
require_text_match 'MacDogStatusWidget\(appGroupIdentifier: "group\.com\.dhseo\.macdog\.MacDog"\)' "$ENTRYPOINT"
require_plist_value "$PLIST" "CFBundleIdentifier" "com.dhseo.macdog.MacDog.WidgetExtension"
require_plist_value "$PLIST" "NSExtension:NSExtensionPointIdentifier" "com.apple.widgetkit-extension"
require_plist_value "$ENTITLEMENTS" "com.apple.security.application-groups:0" "group.com.dhseo.macdog.MacDog"
require_plist_value "$HOST_ENTITLEMENTS" "com.apple.security.application-groups:0" "group.com.dhseo.macdog.MacDog"

if [[ ! -x "$XCODEBUILD" ]]; then
  echo "xcodebuild not found at $XCODEBUILD" >&2
  exit 1
fi

DEVELOPER_DIR="$DEVELOPER_DIR" "$XCODEBUILD" \
  -project "$XCODE_PROJECT" \
  -scheme MacDogWidgetHost \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGNING_ALLOWED=NO \
  build >/dev/null

require_dir "$HOST_APP"
require_dir "$EMBEDDED_APPEX"
require_file "$EMBEDDED_APPEX/Contents/Info.plist"
require_file "$EMBEDDED_APPEX/Contents/MacOS/MacDogWidgetExtension"
require_plist_value "$HOST_APP/Contents/Info.plist" "CFBundleIdentifier" "com.dhseo.macdog.MacDog"
require_plist_value "$EMBEDDED_APPEX/Contents/Info.plist" "CFBundleIdentifier" "com.dhseo.macdog.MacDog.WidgetExtension"
require_plist_value "$EMBEDDED_APPEX/Contents/Info.plist" "CFBundleExecutable" "MacDogWidgetExtension"
require_plist_value "$EMBEDDED_APPEX/Contents/Info.plist" "NSExtension:NSExtensionPointIdentifier" "com.apple.widgetkit-extension"

echo "Widget packaging ok: $EMBEDDED_APPEX"
