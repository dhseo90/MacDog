#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="${1:-$ROOT_DIR/dist/MacDog.app}"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/MacDog"
APP_CLI_BINARY="$APP_BUNDLE/Contents/MacOS/codex-usage"
INFO_PLIST="$APP_BUNDLE/Contents/Info.plist"
APP_ICON="$APP_BUNDLE/Contents/Resources/MacDog.icns"
WIDGET_APPEX="$APP_BUNDLE/Contents/PlugIns/MacDogWidgetExtension.appex"
WIDGET_BINARY="$WIDGET_APPEX/Contents/MacOS/MacDogWidgetExtension"
WIDGET_INFO_PLIST="$WIDGET_APPEX/Contents/Info.plist"
HELPER_BINARY="$APP_BUNDLE/Contents/Library/LaunchServices/MacDogPrivilegedHelper"
HELPER_PLIST="$APP_BUNDLE/Contents/Library/LaunchDaemons/com.dhseo.macdog.helper.plist"

die() {
  echo "error: $*" >&2
  exit 1
}

plist_value() {
  /usr/libexec/PlistBuddy -c "Print $1" "$2"
}

[[ -d "$APP_BUNDLE" ]] || die "app bundle not found: $APP_BUNDLE"
[[ -x "$APP_BINARY" ]] || die "app binary missing or not executable: $APP_BINARY"
[[ -x "$APP_CLI_BINARY" ]] || die "bundled CLI missing or not executable: $APP_CLI_BINARY"
[[ -f "$INFO_PLIST" ]] || die "Info.plist missing: $INFO_PLIST"

[[ "$(plist_value ':CFBundleExecutable' "$INFO_PLIST")" == "MacDog" ]] || die "unexpected app executable"
[[ "$(plist_value ':CFBundleIdentifier' "$INFO_PLIST")" == "com.dhseo.macdog.MacDog" ]] || die "unexpected app bundle id"
[[ "$(plist_value ':CFBundleIconFile' "$INFO_PLIST")" == "MacDog" ]] || die "missing app icon declaration"
[[ "$(plist_value ':CFBundleURLTypes:0:CFBundleURLSchemes:0' "$INFO_PLIST")" == "macdog" ]] || die "missing macdog URL scheme"
[[ "$(plist_value ':CFBundleURLTypes:0:CFBundleURLSchemes:1' "$INFO_PLIST")" == "codexusage" ]] || die "missing codexusage compatibility URL scheme"
[[ -f "$APP_ICON" ]] || die "app icon missing: $APP_ICON"
[[ "$(/usr/bin/sips -g format "$APP_ICON" 2>/dev/null | /usr/bin/awk '/format:/{print $2; exit}')" == "icns" ]] || die "app icon must be an icns file"
/usr/bin/codesign --verify --strict --verbose=2 "$APP_CLI_BINARY" >/dev/null

[[ -d "$WIDGET_APPEX" ]] || die "widget extension not found: $WIDGET_APPEX"
[[ -x "$WIDGET_BINARY" ]] || die "widget binary missing or not executable: $WIDGET_BINARY"
[[ -f "$WIDGET_INFO_PLIST" ]] || die "widget Info.plist missing: $WIDGET_INFO_PLIST"
[[ "$(plist_value ':NSExtension:NSExtensionPointIdentifier' "$WIDGET_INFO_PLIST")" == "com.apple.widgetkit-extension" ]] || die "unexpected widget extension point"

[[ -x "$HELPER_BINARY" ]] || die "privileged helper missing or not executable: $HELPER_BINARY"
[[ -f "$HELPER_PLIST" ]] || die "privileged helper LaunchDaemon plist missing: $HELPER_PLIST"
[[ "$(plist_value ':Label' "$HELPER_PLIST")" == "com.dhseo.macdog.helper" ]] || die "unexpected helper label"
[[ "$(plist_value ':ProgramArguments:0' "$HELPER_PLIST")" == "/Library/PrivilegedHelperTools/com.dhseo.macdog.helper" ]] || die "unexpected helper destination"
[[ "$(plist_value ':ProgramArguments:1' "$HELPER_PLIST")" == "--run-xpc-service" ]] || die "unexpected helper launch argument"
[[ "$(plist_value ':MachServices:com.dhseo.macdog.helper.xpc' "$HELPER_PLIST")" == "true" ]] || die "missing helper mach service"
/usr/bin/codesign --verify --strict --verbose=2 "$HELPER_BINARY" >/dev/null

verify_parent="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/macdog-app-bundle.XXXXXX")"
trap 'rm -rf "$verify_parent"' EXIT
verify_bundle="$verify_parent/$(basename "$APP_BUNDLE")"
/usr/bin/ditto --norsrc --noextattr "$APP_BUNDLE" "$verify_bundle"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$verify_bundle" >/dev/null

echo "App bundle verification ok: $APP_BUNDLE"
