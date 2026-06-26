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
  2. Menu bar character source frames have the expected count and size.
  3. Character profile links menu bar image, desktop pet, and tab artwork assets.
  4. README generated screenshot artifacts are absent and committed screenshots match the renderer.
  5. Ignored dist output does not contain stale app bundle copies.
  6. Runtime CPU/RSS sampling commands and documentation stay wired.
  7. The read-only existing-process runtime sampler is self-tested.
  8. The menu bar app keeps live Codex app-server access out of the UI process.
  9. Swift tests pass.
  10. Cache schema and privacy contract checks pass.
  11. Install/uninstall dry-run output is stable.
  12. Restart/login autostart contract preserves app preferences.
  13. The privileged helper product builds without installing it.
  14. The menu bar app builds.
  15. The generated app bundle omits the WidgetKit extension by default.
  16. WidgetKit source and opt-in packaging boundary guards pass.
  17. WidgetKit App Group signing classifier is self-tested.
  18. v1.3.0 local notification scope excludes developer-account-only planning items.
  19. v1.3.0 release readiness separates implementation closure from manual release smoke.
  20. v1.4.0 usage intelligence cache/privacy/history contract is self-tested.
  21. v1.4.0 release readiness separates implementation closure from manual release smoke.
  22. Optional WidgetKit manual UI verification plan is self-tested without touching live cache.
  23. Optional WidgetKit manual cache fixture writer is tested without touching live cache.
  24. Shortcuts Charge Limit fallback parser is tested with a local fixture.
  25. Shortcuts Charge Limit fallback availability is probed without changing settings.
  26. Release/app scripts reject missing version metadata.
  27. The current app/helper install state and dist freshness delta can be reported without changing the system.
  28. Install freshness delta reporting is self-tested with local fixtures.
  29. Release packaging, version metadata, and release smoke cleanup guardrails are stable.
  30. Public repository guardrails are present and consistent.
  31. GitHub release candidate workflow contains the expected unsigned artifact gates.
  32. Public stable release remains gated behind signing/notarization/Gatekeeper checks.
  33. Privileged helper reinstall test plan is safe to stage before actual approval.
  34. Unless --no-run is passed, the app launches and its process is detected.

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

APP_VERSION="${MACDOG_APP_VERSION:-${MACDOG_RELEASE_VERSION:-}}"
[[ -n "$APP_VERSION" ]] || die "app/release version required; set MACDOG_RELEASE_VERSION or MACDOG_APP_VERSION before running check.sh"

[[ -x "$XCRUN" ]] || die "xcrun not found at $XCRUN"
require_tool sips
require_tool pgrep
require_tool pkill
require_tool git
"$XCRUN" --find swift >/dev/null || die "Swift toolchain unavailable through xcrun"

cd "$ROOT_DIR"

echo "==> Verifying menu bar character"
./script/verify_menu_bar_character.sh

echo "==> Verifying character profile"
./script/verify_character_profile.sh

echo "==> Verifying README generated image hygiene and freshness"
./script/verify_readme_screenshots.sh

echo "==> Verifying dist hygiene"
./script/verify_dist_hygiene.sh

echo "==> Verifying runtime sampling contract"
./script/verify_runtime_contract.sh

echo "==> Verifying existing-process runtime sampler"
./script/sample_existing_runtime_resources.sh --self-test

echo "==> Verifying app privacy boundaries"
./script/verify_app_privacy_boundaries.sh

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

echo "==> Verifying WidgetKit opt-in boundary"
./script/verify_widget_readiness.sh

echo "==> Verifying WidgetKit App Group signing classifier"
./script/verify_widget_app_group_signing.sh --self-test

echo "==> Verifying v1.3.0 local notification boundary"
./script/verify_v130_local_notification_boundary.sh --self-test

echo "==> Verifying v1.3.0 release readiness"
./script/verify_v130_release_readiness.sh --self-test

echo "==> Verifying v1.4.0 usage intelligence contract"
./script/verify_v140_usage_intelligence_contract.sh --self-test

echo "==> Verifying v1.4.0 release readiness"
./script/verify_v140_release_readiness.sh --self-test

echo "==> Verifying WidgetKit manual UI plan"
./script/verify_widget_manual_ui_plan.sh --self-test

echo "==> Verifying WidgetKit cache fixture writer"
./script/write_widget_cache_fixture.sh --self-test

echo "==> Verifying Shortcuts Charge Limit parser"
./script/verify_shortcuts_charge_limit.sh --self-test

echo "==> Probing Shortcuts Charge Limit fallback"
./script/verify_shortcuts_charge_limit.sh --allow-unavailable

echo "==> Verifying explicit version contract"
./script/verify_explicit_version_contract.sh

echo "==> Verifying release packaging dry-run"
./script/verify_release_packaging.sh

echo "==> Verifying public repo guardrails"
./script/verify_public_repo_guardrails.sh

echo "==> Verifying release workflow"
./script/verify_release_workflow.sh

echo "==> Verifying distribution gate"
./script/verify_distribution_gate.sh

echo "==> Reporting install state"
./script/verify_install_state.sh --report
./script/verify_install_state.sh --explain-current-dist
./script/verify_install_state.sh --self-test
./script/verify_privileged_helper_state.sh --allow-missing
if [[ "$MODE" == "--no-run" || "$MODE" == "no-run" ]]; then
  ./script/verify_privileged_helper_xpc.sh --allow-missing --skip-runtime
else
./script/verify_privileged_helper_xpc.sh --allow-missing
fi
./script/verify_privileged_helper_preflight.sh
./script/verify_privileged_helper_reinstall_plan.sh

echo "Local verification ok"
