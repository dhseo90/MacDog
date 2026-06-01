#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="$ROOT_DIR/dist/MacDog.app"
EXPECT_WIDGET=0
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

usage() {
  echo "usage: $0 [APP_BUNDLE] [--with-widget]"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --with-widget|--expect-widget)
      EXPECT_WIDGET=1
      ;;
    -h|--help|help)
      usage
      exit 0
      ;;
    -*)
      usage >&2
      exit 2
      ;;
    *)
      APP_BUNDLE="$1"
      ;;
  esac
  shift
done

APP_BINARY="$APP_BUNDLE/Contents/MacOS/MacDog"
APP_CLI_BINARY="$APP_BUNDLE/Contents/MacOS/codex-usage"
INFO_PLIST="$APP_BUNDLE/Contents/Info.plist"
APP_ICON="$APP_BUNDLE/Contents/Resources/MacDog.icns"
WIDGET_APPEX="$APP_BUNDLE/Contents/PlugIns/MacDogWidgetExtension.appex"
WIDGET_BINARY="$WIDGET_APPEX/Contents/MacOS/MacDogWidgetExtension"
WIDGET_INFO_PLIST="$WIDGET_APPEX/Contents/Info.plist"
HELPER_BINARY="$APP_BUNDLE/Contents/Library/LaunchServices/MacDogPrivilegedHelper"
HELPER_PLIST="$APP_BUNDLE/Contents/Library/LaunchDaemons/com.dhseo.macdog.helper.plist"

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
cli_entitlements="$(/usr/bin/codesign -d --entitlements :- "$APP_CLI_BINARY" 2>/dev/null || true)"
if [[ "$EXPECT_WIDGET" == "1" ]]; then
  printf '%s' "$cli_entitlements" | /usr/bin/grep -Fq '<string>group.com.dhseo.macdog.MacDog</string>' \
    || die "bundled CLI missing MacDog app group entitlement for WidgetKit cache mirroring"
  [[ -d "$WIDGET_APPEX" ]] || die "widget extension not found: $WIDGET_APPEX"
  [[ -x "$WIDGET_BINARY" ]] || die "widget binary missing or not executable: $WIDGET_BINARY"
  [[ -f "$WIDGET_INFO_PLIST" ]] || die "widget Info.plist missing: $WIDGET_INFO_PLIST"
  [[ "$(plist_value ':NSExtension:NSExtensionPointIdentifier' "$WIDGET_INFO_PLIST")" == "com.apple.widgetkit-extension" ]] || die "unexpected widget extension point"
else
  [[ ! -e "$WIDGET_APPEX" ]] || die "widget extension must be omitted from the default app bundle: $WIDGET_APPEX"
  if printf '%s' "$cli_entitlements" | /usr/bin/grep -Fq '<string>group.com.dhseo.macdog.MacDog</string>'; then
    die "bundled CLI must not carry MacDog App Group entitlement in the default app bundle"
  fi
fi

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
