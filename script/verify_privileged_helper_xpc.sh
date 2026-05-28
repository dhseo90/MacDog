#!/usr/bin/env bash
set -euo pipefail

MODE="allow-missing"
SKIP_RUNTIME=0
SET_VALUE=""
RESTORE=0
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_APP_BUNDLE="$ROOT_DIR/dist/MacDog.app"
INSTALLED_APP_BUNDLE="$HOME/Applications/MacDog.app"
APP_BUNDLE="${MACDOG_XPC_VERIFY_APP_BUNDLE:-}"
HELPER_LABEL="com.dhseo.macdog.helper"
HELPER_TOOL_DEST="/Library/PrivilegedHelperTools/$HELPER_LABEL"
HELPER_PLIST_DEST="/Library/LaunchDaemons/$HELPER_LABEL.plist"

usage() {
  echo "usage: $0 [--allow-missing|--expect-installed] [--skip-runtime] [--set 0|1] [--restore]"
}

die() {
  echo "error: $*" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --allow-missing) MODE="allow-missing" ;;
    --expect-installed) MODE="expect-installed" ;;
    --skip-runtime) SKIP_RUNTIME=1 ;;
    --set)
      shift
      [[ $# -gt 0 ]] || die "--set requires 0 or 1"
      case "$1" in
        0|1) SET_VALUE="$1" ;;
        *) die "--set requires 0 or 1" ;;
      esac
      ;;
    --restore) RESTORE=1 ;;
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
if [[ "$SKIP_RUNTIME" == "1" ]]; then
  echo "helper-xpc:skipped mode:skip-runtime helper:installed"
  exit 0
fi

if [[ -z "$APP_BUNDLE" ]]; then
  if [[ -d "$DIST_APP_BUNDLE" ]]; then
    APP_BUNDLE="$DIST_APP_BUNDLE"
  else
    APP_BUNDLE="$INSTALLED_APP_BUNDLE"
  fi
fi
[[ -d "$APP_BUNDLE" ]] || die "MacDog app bundle missing: $APP_BUNDLE"
[[ -x "$APP_BUNDLE/Contents/MacOS/MacDog" ]] || die "MacDog app binary missing or not executable: $APP_BUNDLE/Contents/MacOS/MacDog"

runtime_parent="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/macdog-helper-xpc-app.XXXXXX")"
runtime_app="$runtime_parent/$(basename "$APP_BUNDLE")"
/usr/bin/ditto --norsrc --noextattr "$APP_BUNDLE" "$runtime_app"
/usr/bin/xattr -cr "$runtime_app" >/dev/null 2>&1 || true
/usr/bin/codesign --verify --deep --strict --verbose=2 "$runtime_app" >/dev/null
APP_BUNDLE="$runtime_app"

result_file="$(/usr/bin/mktemp "${TMPDIR:-/tmp}/macdog-helper-xpc.XXXXXX")"
rm -f "$result_file"
trap 'rm -f "$result_file"; rm -rf "$runtime_parent"' EXIT

app_args=(--verify-privileged-helper-xpc-read --result-file "$result_file")
if [[ -n "$SET_VALUE" ]]; then
  app_args=(--verify-privileged-helper-xpc-set "$SET_VALUE" --result-file "$result_file")
  if [[ "$RESTORE" == "1" ]]; then
    app_args+=(--restore)
  fi
fi

/usr/bin/open -n "$APP_BUNDLE" --args "${app_args[@]}" >/dev/null

for _ in {1..50}; do
  if [[ -s "$result_file" ]]; then
    cat "$result_file"
    if [[ -n "$SET_VALUE" ]]; then
      grep -q '^helper-xpc:set SleepDisabled=' "$result_file"
    else
      grep -q '^helper-xpc:read SleepDisabled=' "$result_file"
    fi
    exit $?
  fi
  sleep 0.1
done

die "timed out waiting for helper XPC diagnostic result: $result_file"
