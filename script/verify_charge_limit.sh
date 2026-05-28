#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="MacDog"
APP_BUNDLE="${MACDOG_CHARGE_VERIFY_APP_BUNDLE:-$ROOT_DIR/dist/$APP_NAME.app}"
MODE="read"
TARGET=""
RESTORE=0

usage() {
  echo "usage: $0 [--read|--set PERCENT] [--restore]"
}

die() {
  echo "error: $*" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --read) MODE="read" ;;
    --set)
      shift
      [[ $# -gt 0 ]] || die "--set requires a percentage"
      MODE="set"
      TARGET="$1"
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

[[ -d "$APP_BUNDLE" ]] || die "MacDog app bundle missing: $APP_BUNDLE"
[[ -x "$APP_BUNDLE/Contents/MacOS/$APP_NAME" ]] || die "MacDog app binary missing or not executable: $APP_BUNDLE/Contents/MacOS/$APP_NAME"

runtime_parent="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/macdog-charge-limit-app.XXXXXX")"
runtime_app="$runtime_parent/$(basename "$APP_BUNDLE")"
/usr/bin/ditto --norsrc --noextattr "$APP_BUNDLE" "$runtime_app"
/usr/bin/xattr -cr "$runtime_app" >/dev/null 2>&1 || true
/usr/bin/codesign --verify --deep --strict --verbose=2 "$runtime_app" >/dev/null

result_file="$(/usr/bin/mktemp "${TMPDIR:-/tmp}/macdog-charge-limit.XXXXXX")"
rm -f "$result_file"
trap 'rm -f "$result_file"; rm -rf "$runtime_parent"' EXIT

app_args=(--verify-charge-limit-read --result-file "$result_file")
if [[ "$MODE" == "set" ]]; then
  [[ "$TARGET" =~ ^(80|85|90|95|100)$ ]] || die "--set requires one of 80,85,90,95,100"
  app_args=(--verify-charge-limit-set "$TARGET" --result-file "$result_file")
  if [[ "$RESTORE" == "1" ]]; then
    app_args+=(--restore)
  fi
fi

/usr/bin/open -n "$runtime_app" --args "${app_args[@]}" >/dev/null

for _ in {1..80}; do
  if [[ -s "$result_file" ]]; then
    cat "$result_file"
    if [[ "$MODE" == "set" ]]; then
      grep -q '^charge-limit:set ' "$result_file"
    else
      grep -q '^charge-limit:read ' "$result_file"
    fi
    exit $?
  fi
  sleep 0.1
done

die "timed out waiting for charge limit diagnostic result: $result_file"
