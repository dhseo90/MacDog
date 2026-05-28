#!/usr/bin/env bash
set -euo pipefail

BUILD=0
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="$ROOT_DIR/dist/MacDog.app"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/MacDog"
APP_INFO_PLIST="$APP_BUNDLE/Contents/Info.plist"
APP_BUNDLE_ID="com.dhseo.macdog.MacDog"
HELPER_BINARY="$APP_BUNDLE/Contents/Library/LaunchServices/MacDogPrivilegedHelper"
HELPER_PLIST="$APP_BUNDLE/Contents/Library/LaunchDaemons/com.dhseo.macdog.helper.plist"
HELPER_LABEL="com.dhseo.macdog.helper"
HELPER_MACH_SERVICE="$HELPER_LABEL.xpc"
HELPER_TOOL_DEST="/Library/PrivilegedHelperTools/$HELPER_LABEL"

usage() {
  echo "usage: $0 [--build]"
}

die() {
  echo "error: $*" >&2
  exit 1
}

plist_value() {
  /usr/libexec/PlistBuddy -c "Print $1" "$2"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --build) BUILD=1 ;;
    -h|--help|help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
  shift
done

cd "$ROOT_DIR"

if [[ "$BUILD" == "1" ]]; then
  ./script/build_and_run.sh --no-run >/dev/null
fi

echo "==> Checking helper-only install dry-run"
./script/install.sh --dry-run --helper-only >/dev/null

echo "==> Checking generated app bundle"
[[ -d "$APP_BUNDLE" ]] || die "app bundle missing: $APP_BUNDLE"
[[ -x "$APP_BINARY" ]] || die "app binary missing or not executable: $APP_BINARY"
[[ -f "$APP_INFO_PLIST" ]] || die "app Info.plist missing: $APP_INFO_PLIST"
[[ "$(plist_value ':CFBundleIdentifier' "$APP_INFO_PLIST")" == "$APP_BUNDLE_ID" ]] || die "unexpected app bundle id"
[[ -x "$HELPER_BINARY" ]] || die "embedded helper missing or not executable: $HELPER_BINARY"
[[ -f "$HELPER_PLIST" ]] || die "embedded helper LaunchDaemon plist missing: $HELPER_PLIST"
/usr/bin/plutil -lint "$HELPER_PLIST" >/dev/null
[[ "$(plist_value ':Label' "$HELPER_PLIST")" == "$HELPER_LABEL" ]] || die "unexpected helper label"
[[ "$(plist_value ':ProgramArguments:0' "$HELPER_PLIST")" == "$HELPER_TOOL_DEST" ]] || die "unexpected helper executable path"
[[ "$(plist_value ':ProgramArguments:1' "$HELPER_PLIST")" == "--run-xpc-service" ]] || die "unexpected helper launch argument"
[[ "$(plist_value ":MachServices:$HELPER_MACH_SERVICE" "$HELPER_PLIST")" == "true" ]] || die "missing helper mach service"
/usr/bin/codesign --verify --strict --verbose=2 "$HELPER_BINARY" >/dev/null

echo "==> Checking current helper state"
./script/verify_privileged_helper_state.sh --allow-missing

echo "==> Checking helper XPC diagnostic path"
./script/verify_privileged_helper_xpc.sh --allow-missing

cat <<NEXT
Privileged helper preflight ok.

Next approved install sequence:
  ./script/install.sh --helper-only
  ./script/verify_privileged_helper_state.sh --expect-installed
  ./script/verify_privileged_helper_xpc.sh --expect-installed
NEXT
