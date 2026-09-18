#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOC="$ROOT_DIR/Docs/V192MenuBarGlancePolish.md"
README="$ROOT_DIR/README.md"
ROADMAP="$ROOT_DIR/ROADMAP.md"
ONBOARDING="$ROOT_DIR/Docs/Onboarding/README.md"
DEV_ENV="$ROOT_DIR/Docs/Onboarding/DevelopmentEnvironment.md"
SCRIPTS_DOC="$ROOT_DIR/Docs/Scripts.md"
CHECK_SCRIPT="$ROOT_DIR/script/check.sh"
V191_VERIFIER="$ROOT_DIR/script/verify_v191_multi_provider_contract.sh"
UNINSTALL="$ROOT_DIR/script/uninstall.sh"
INSTALL_DRY_RUN="$ROOT_DIR/script/verify_install_dry_run.sh"
LABEL_SOURCE="$ROOT_DIR/Sources/MacDog/MenuBarWeeklyRemainingLabel.swift"
CONTROLLER_SOURCE="$ROOT_DIR/Sources/MacDog/MenuBarController.swift"
LABEL_TEST="$ROOT_DIR/Tests/MacDogTests/MenuBarWeeklyRemainingLabelTests.swift"
POPOVER_TEST="$ROOT_DIR/Tests/MacDogTests/PopoverScreenshotRendererTests.swift"
RUN_TESTS=1

usage() {
  cat <<USAGE
usage: $0 [--self-test] [--skip-tests]

Verify the v1.9.2 menu bar glance polish and uninstall history contract.
This script does not read ~/.grok/auth.json, use live billing, run GUI apps,
install components, uninstall for real, or push. It keeps the completed
v1.9.1 verifier intact.
USAGE
}

die() {
  echo "error: $*" >&2
  exit 1
}

require_file() {
  [[ -f "$1" ]] || die "missing required file: $1"
}

require_match() {
  local pattern="$1"
  local file="$2"
  local description="$3"
  /usr/bin/grep -Eq -- "$pattern" "$file" || die "missing $description in $file"
}

reject_match() {
  local pattern="$1"
  local file="$2"
  local description="$3"
  if /usr/bin/grep -Eiq -- "$pattern" "$file"; then
    die "unexpected $description in $file"
  fi
}

verify_contract() {
  local file
  for file in "$DOC" "$README" "$ROADMAP" "$ONBOARDING" "$DEV_ENV" "$SCRIPTS_DOC" \
    "$CHECK_SCRIPT" "$V191_VERIFIER" "$UNINSTALL" "$INSTALL_DRY_RUN" \
    "$LABEL_SOURCE" "$CONTROLLER_SOURCE" "$LABEL_TEST" "$POPOVER_TEST"; do
    require_file "$file"
  done
  [[ -x "$ROOT_DIR/script/verify_v192_menu_bar_glance_contract.sh" ]] || \
    die "v1.9.2 glance verifier is not executable"
  [[ -x "$V191_VERIFIER" ]] || die "v1.9.1 verifier is not executable"
  "$V191_VERIFIER" --self-test --skip-tests
  reject_match 'v1\.9\.2' "$V191_VERIFIER" "v1.9.1 verifier mentioning v1.9.2"

  require_match '메뉴바 glance polish와 uninstall history 정리' "$DOC" "v1.9.2 title"
  require_match '숫자 폰트는 11pt' "$DOC" "11pt font contract"
  require_match '레이아웃 폭은 `100%`' "$DOC" "reserved 100% width"
  require_match '2pt' "$DOC" "two-point trailing gap"
  require_match 'usage-five-hour-history.json' "$DOC" "five-hour uninstall"
  require_match 'usage-reset-window-history.json' "$DOC" "reset-window uninstall"
  require_match 'cache 로그 rotation' "$DOC" "log rotation stays out of scope"
  require_match '보조 provider `%`를 붙이지 않는다' "$DOC" "no auxiliary percent"

  require_match 'V192MenuBarGlancePolish\.md' "$README" "README design document link"
  require_match '메뉴바 glance polish와 uninstall history 정리' "$ROADMAP" \
    "ROADMAP v1.9.2 section"
  require_match 'verify_v192_menu_bar_glance_contract\.sh --self-test' "$ROADMAP" \
    "ROADMAP v1.9.2 verifier"
  require_match 'v1\.9\.2 glance' "$ONBOARDING" "onboarding v1.9.2 term"

  require_match 'static let fontSize: CGFloat = 11' "$LABEL_SOURCE" "11pt font size"
  require_match 'static let trailingGap: CGFloat = 2' "$LABEL_SOURCE" "2pt trailing gap"
  require_match 'monospacedDigitSystemFont' "$LABEL_SOURCE" "tabular digits"
  require_match 'NSAttributedString\(string: "100%"' "$LABEL_SOURCE" "100% width template"
  require_match 'func apply\(to button: NSStatusBarButton\)' "$LABEL_SOURCE" \
    "status item apply helper"
  require_match 'button.imagePosition = .imageTrailing' "$LABEL_SOURCE" \
    "percent then runner"
  require_match 'imageHugsTitle = true' "$LABEL_SOURCE" "tight title hugging"
  require_match 'apply\(to: button\)' "$CONTROLLER_SOURCE" "controller uses apply"
  reject_match 'button\.title = text' "$CONTROLLER_SOURCE" "plain system title"

  require_match 'testGlanceAttributedTitleUsesElevenPointMonospacedDigits' \
    "$LABEL_TEST" "font focused test"
  require_match 'testNinePercentAndOneHundredPercentShareReservedWidth' \
    "$LABEL_TEST" "fixed width focused test"
  require_match 'testHiddenLabelHasZeroReservedWidthAndNoAttributedTitle' \
    "$LABEL_TEST" "hidden width focused test"
  require_match 'testAttributedTitleReservesTwoPointTrailingGap' \
    "$LABEL_TEST" "trailing gap focused test"
  require_match 'testApplyUsesAttributedGlanceTitleOnStatusItemButton' \
    "$LABEL_TEST" "status item apply focused test"
  require_match '\.apply\(to: button\)' "$POPOVER_TEST" "screenshot controller apply"

  require_match 'APP_FIVE_HOUR_HISTORY_FILE=' "$UNINSTALL" "five-hour history path"
  require_match 'APP_RESET_WINDOW_HISTORY_FILE=' "$UNINSTALL" "reset-window history path"
  require_match 'Would remove five-hour history file:' "$UNINSTALL" \
    "five-hour dry-run"
  require_match 'Would remove reset-window history file:' "$UNINSTALL" \
    "reset-window dry-run"
  require_match '\$APP_FIVE_HOUR_HISTORY_FILE' "$UNINSTALL" "five-hour rm"
  require_match '\$APP_RESET_WINDOW_HISTORY_FILE' "$UNINSTALL" "reset-window rm"
  require_match 'Would remove five-hour history file:' "$INSTALL_DRY_RUN" \
    "install dry-run five-hour"
  require_match 'Would remove reset-window history file:' "$INSTALL_DRY_RUN" \
    "install dry-run reset-window"

  require_match 'usage-five-hour-history.json' "$SCRIPTS_DOC" \
    "Scripts.md five-hour history"
  require_match 'usage-reset-window-history.json' "$SCRIPTS_DOC" \
    "Scripts.md reset-window history"
  reject_match '현재 5시간/reset history와 cache logs는 남을 수 있습니다' \
    "$SCRIPTS_DOC" "stale uninstall remainder"
  require_match 'usage-five-hour-history.json' "$DEV_ENV" \
    "DevelopmentEnvironment five-hour history"
  reject_match '현재 구현상 `usage-five-hour-history.json`' "$DEV_ENV" \
    "stale leftover history note"

  require_match 'verify_v192_menu_bar_glance_contract\.sh --self-test' \
    "$SCRIPTS_DOC" "Scripts.md v1.9.2 verifier"
  require_match 'verify_v192_menu_bar_glance_contract\.sh --self-test' \
    "$CHECK_SCRIPT" "check.sh v1.9.2 gate"

  reject_match 'usedPercent \+ ' "$LABEL_SOURCE" "summed used percent"
  reject_match 'auxiliary|보조 provider' "$LABEL_SOURCE" "auxiliary provider percent"

  echo "v1.9.2 menu bar glance contract ok"
}

run_focused_tests() {
  DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}" \
  CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-/private/tmp/macdog-clang-module-cache}" \
    /usr/bin/xcrun swift test \
      --filter MenuBarWeeklyRemainingLabelTests \
      --filter PopoverScreenshotRendererTests
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --self-test) ;;
    --skip-tests) RUN_TESTS=0 ;;
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
verify_contract
if [[ "$RUN_TESTS" == "1" ]]; then
  run_focused_tests
fi
echo "v1.9.2 menu bar glance contract ok"
