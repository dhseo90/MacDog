#!/usr/bin/env bash
set -euo pipefail

MODE="allow-missing"
HELPER_LABEL="com.dhseo.macdog.helper"
HELPER_MACH_SERVICE="$HELPER_LABEL.xpc"
HELPER_TOOL_DEST="/Library/PrivilegedHelperTools/$HELPER_LABEL"
HELPER_PLIST_DEST="/Library/LaunchDaemons/$HELPER_LABEL.plist"

usage() {
  echo "usage: $0 [--allow-missing|--expect-installed|--expect-missing]"
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
    --allow-missing) MODE="allow-missing" ;;
    --expect-installed) MODE="expect-installed" ;;
    --expect-missing) MODE="expect-missing" ;;
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

tool_exists=0
plist_exists=0
[[ -x "$HELPER_TOOL_DEST" ]] && tool_exists=1
[[ -f "$HELPER_PLIST_DEST" ]] && plist_exists=1

case "$MODE" in
  expect-installed)
    [[ "$tool_exists" == "1" ]] || die "helper tool missing: $HELPER_TOOL_DEST"
    [[ "$plist_exists" == "1" ]] || die "helper LaunchDaemon plist missing: $HELPER_PLIST_DEST"
    ;;
  expect-missing)
    [[ "$tool_exists" == "0" ]] || die "helper tool exists unexpectedly: $HELPER_TOOL_DEST"
    [[ "$plist_exists" == "0" ]] || die "helper LaunchDaemon plist exists unexpectedly: $HELPER_PLIST_DEST"
    ;;
  allow-missing) ;;
  *)
    usage >&2
    exit 2
    ;;
esac

if [[ "$tool_exists" == "0" && "$plist_exists" == "0" ]]; then
  echo "helper:missing"
  exit 0
fi

[[ "$tool_exists" == "1" ]] || die "partial helper install: tool missing"
[[ "$plist_exists" == "1" ]] || die "partial helper install: LaunchDaemon plist missing"

[[ "$(plist_value ':Label' "$HELPER_PLIST_DEST")" == "$HELPER_LABEL" ]] || die "unexpected helper label"
[[ "$(plist_value ':ProgramArguments:0' "$HELPER_PLIST_DEST")" == "$HELPER_TOOL_DEST" ]] || die "unexpected helper executable path"
[[ "$(plist_value ':ProgramArguments:1' "$HELPER_PLIST_DEST")" == "--run-xpc-service" ]] || die "unexpected helper launch argument"
[[ "$(plist_value ":MachServices:$HELPER_MACH_SERVICE" "$HELPER_PLIST_DEST")" == "true" ]] || die "missing helper mach service"

/usr/bin/plutil -lint "$HELPER_PLIST_DEST" >/dev/null
/usr/bin/codesign --verify --strict --verbose=2 "$HELPER_TOOL_DEST" >/dev/null

if /bin/launchctl print "system/$HELPER_LABEL" >/dev/null 2>&1; then
  echo "helper:installed launchd:loaded"
else
  echo "helper:installed launchd:not-loaded"
  [[ "$MODE" != "expect-installed" ]] || die "helper LaunchDaemon is not loaded"
fi
