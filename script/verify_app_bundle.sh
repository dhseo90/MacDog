#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="${1:-$ROOT_DIR/dist/MacDog.app}"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/MacDog"
INFO_PLIST="$APP_BUNDLE/Contents/Info.plist"
WIDGET_APPEX="$APP_BUNDLE/Contents/PlugIns/MacDogWidgetExtension.appex"
WIDGET_BINARY="$WIDGET_APPEX/Contents/MacOS/MacDogWidgetExtension"
WIDGET_INFO_PLIST="$WIDGET_APPEX/Contents/Info.plist"

die() {
  echo "error: $*" >&2
  exit 1
}

plist_value() {
  /usr/libexec/PlistBuddy -c "Print $1" "$2"
}

[[ -d "$APP_BUNDLE" ]] || die "app bundle not found: $APP_BUNDLE"
[[ -x "$APP_BINARY" ]] || die "app binary missing or not executable: $APP_BINARY"
[[ -f "$INFO_PLIST" ]] || die "Info.plist missing: $INFO_PLIST"

[[ "$(plist_value ':CFBundleExecutable' "$INFO_PLIST")" == "MacDog" ]] || die "unexpected app executable"
[[ "$(plist_value ':CFBundleIdentifier' "$INFO_PLIST")" == "com.dhseo.macdog.MacDog" ]] || die "unexpected app bundle id"
[[ "$(plist_value ':CFBundleURLTypes:0:CFBundleURLSchemes:0' "$INFO_PLIST")" == "macdog" ]] || die "missing macdog URL scheme"
[[ "$(plist_value ':CFBundleURLTypes:0:CFBundleURLSchemes:1' "$INFO_PLIST")" == "codexusage" ]] || die "missing codexusage compatibility URL scheme"

[[ -d "$WIDGET_APPEX" ]] || die "widget extension not found: $WIDGET_APPEX"
[[ -x "$WIDGET_BINARY" ]] || die "widget binary missing or not executable: $WIDGET_BINARY"
[[ -f "$WIDGET_INFO_PLIST" ]] || die "widget Info.plist missing: $WIDGET_INFO_PLIST"
[[ "$(plist_value ':NSExtension:NSExtensionPointIdentifier' "$WIDGET_INFO_PLIST")" == "com.apple.widgetkit-extension" ]] || die "unexpected widget extension point"

verify_parent="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/macdog-app-bundle.XXXXXX")"
trap 'rm -rf "$verify_parent"' EXIT
verify_bundle="$verify_parent/$(basename "$APP_BUNDLE")"
/usr/bin/ditto --norsrc --noextattr "$APP_BUNDLE" "$verify_bundle"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$verify_bundle" >/dev/null

echo "App bundle verification ok: $APP_BUNDLE"
