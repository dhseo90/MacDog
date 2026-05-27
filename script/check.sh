#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
XCRUN="/usr/bin/xcrun"

usage() {
  cat <<USAGE
usage: $0 [--no-run|--help]

Run the standard local verification for a new checkout.

Checks:
  1. Required macOS/Xcode tools are available.
  2. Runner PNG assets have the expected count and size.
  3. Swift tests pass.
  4. Cache schema and privacy contract checks pass.
  5. Install/uninstall dry-run output is stable.
  6. Restart/login autostart contract preserves app preferences.
  7. The menu bar app builds.
  8. The generated app bundle contains the WidgetKit extension.
  9. WidgetKit host/extension packaging builds an embedded .appex.
  10. The current install state can be reported without changing the system.
  11. Unless --no-run is passed, the app launches and its process is detected.

Options:
  --no-run   Build the app bundle without launching it.
  --help     Show this help.
USAGE
}

die() {
  echo "error: $*" >&2
  exit 1
}

require_tool() {
  command -v "$1" >/dev/null 2>&1 || die "required tool not found: $1"
}

MODE="${1:-verify}"
case "$MODE" in
  verify|--verify) ;;
  --no-run|no-run) ;;
  -h|--help|help)
    usage
    exit 0
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

[[ -x "$XCRUN" ]] || die "xcrun not found at $XCRUN"
require_tool sips
require_tool pgrep
require_tool pkill
require_tool git
"$XCRUN" --find swift >/dev/null || die "Swift toolchain unavailable through xcrun"

cd "$ROOT_DIR"

echo "==> Verifying runner assets"
./script/verify_runner_baseline.sh

echo "==> Running Swift tests"
"$XCRUN" swift test --no-parallel

echo "==> Checking diff whitespace"
git diff --check

echo "==> Verifying cache contract"
./script/verify_cache_contract.sh

echo "==> Verifying install dry-run output"
./script/verify_install_dry_run.sh

echo "==> Verifying autostart contract"
./script/verify_autostart_contract.sh

if [[ "$MODE" == "--no-run" || "$MODE" == "no-run" ]]; then
  echo "==> Building app bundle without launch"
  ./script/build_and_run.sh --no-run
else
  echo "==> Building and launching app"
  ./script/build_and_run.sh --verify
fi

echo "==> Verifying generated app bundle"
./script/verify_app_bundle.sh

echo "==> Verifying WidgetKit packaging"
./script/verify_widget_packaging.sh

echo "==> Reporting install state"
./script/verify_install_state.sh --report

echo "Local verification ok"
