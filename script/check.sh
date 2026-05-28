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
  3. Character profile links runner, desktop pet, and tab artwork assets.
  4. Swift tests pass.
  5. Cache schema and privacy contract checks pass.
  6. Install/uninstall dry-run output is stable.
  7. Restart/login autostart contract preserves app preferences.
  8. The privileged helper product builds without installing it.
  9. The menu bar app builds.
  10. The generated app bundle contains the WidgetKit extension.
  11. WidgetKit host/extension packaging builds an embedded .appex.
  12. WidgetKit cache/deep-link readiness guards pass.
  13. The current app/helper install state can be reported without changing the system.
  14. Release packaging dry-run is stable.
  15. GitHub release candidate workflow contains the expected unsigned artifact gates.
  16. Public stable release remains gated behind signing/notarization/Gatekeeper checks.
  17. Privileged helper reinstall test plan is safe to stage before actual approval.
  18. Unless --no-run is passed, the app launches and its process is detected.

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

echo "==> Verifying character profile"
./script/verify_character_profile.sh

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

echo "==> Building privileged helper without install"
"$XCRUN" swift build -c release --product MacDogPrivilegedHelper

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

echo "==> Verifying WidgetKit readiness"
./script/verify_widget_readiness.sh

echo "==> Verifying release packaging dry-run"
./script/verify_release_packaging.sh

echo "==> Verifying release workflow"
./script/verify_release_workflow.sh

echo "==> Verifying distribution gate"
./script/verify_distribution_gate.sh

echo "==> Reporting install state"
./script/verify_install_state.sh --report
./script/verify_privileged_helper_state.sh --allow-missing
if [[ "$MODE" == "--no-run" || "$MODE" == "no-run" ]]; then
  ./script/verify_privileged_helper_xpc.sh --allow-missing --skip-runtime
else
./script/verify_privileged_helper_xpc.sh --allow-missing
fi
./script/verify_privileged_helper_preflight.sh
./script/verify_privileged_helper_reinstall_plan.sh

echo "Local verification ok"
