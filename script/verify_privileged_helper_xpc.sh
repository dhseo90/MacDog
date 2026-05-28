#!/usr/bin/env bash
set -euo pipefail

MODE="allow-missing"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_APP_BINARY="$ROOT_DIR/dist/MacDog.app/Contents/MacOS/MacDog"
INSTALLED_APP_BINARY="$HOME/Applications/MacDog.app/Contents/MacOS/MacDog"
APP_BINARY="${MACDOG_XPC_VERIFY_APP_BINARY:-}"
HELPER_LABEL="com.dhseo.macdog.helper"
HELPER_TOOL_DEST="/Library/PrivilegedHelperTools/$HELPER_LABEL"
HELPER_PLIST_DEST="/Library/LaunchDaemons/$HELPER_LABEL.plist"

usage() {
  echo "usage: $0 [--allow-missing|--expect-installed]"
}

die() {
  echo "error: $*" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --allow-missing) MODE="allow-missing" ;;
    --expect-installed) MODE="expect-installed" ;;
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

if [[ ! -x "$HELPER_TOOL_DEST" && ! -f "$HELPER_PLIST_DEST" ]]; then
  echo "helper-xpc:skipped helper:missing"
  [[ "$MODE" == "allow-missing" ]] || exit 1
  exit 0
fi

"$(dirname "$0")/verify_privileged_helper_state.sh" --expect-installed >/dev/null
if [[ -z "$APP_BINARY" ]]; then
  if [[ -x "$DIST_APP_BINARY" ]]; then
    APP_BINARY="$DIST_APP_BINARY"
  else
    APP_BINARY="$INSTALLED_APP_BINARY"
  fi
fi
[[ -x "$APP_BINARY" ]] || die "MacDog app binary missing or not executable: $APP_BINARY"

"$APP_BINARY" --verify-privileged-helper-xpc-read
