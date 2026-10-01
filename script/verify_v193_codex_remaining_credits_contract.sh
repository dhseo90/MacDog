#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOC="$ROOT_DIR/Docs/V193CodexRemainingCredits.md"
README="$ROOT_DIR/README.md"
ROADMAP="$ROOT_DIR/ROADMAP.md"
ONBOARDING="$ROOT_DIR/Docs/Onboarding/README.md"
ARCHITECTURE="$ROOT_DIR/Docs/Onboarding/Architecture.md"
SCRIPTS_DOC="$ROOT_DIR/Docs/Scripts.md"
CHECK_SCRIPT="$ROOT_DIR/script/check.sh"
V192_RELEASE_VERIFIER="$ROOT_DIR/script/verify_v192_release_readiness.sh"
PANEL="$ROOT_DIR/Sources/MacDog/Popover/CodexUsagePanel.swift"
LAYOUT="$ROOT_DIR/Sources/MacDog/Popover/MacDogPopoverModule.swift"
CREDITS="$ROOT_DIR/Sources/MacDog/Popover/CodexResetCreditsViews.swift"
POPOVER_TEST="$ROOT_DIR/Tests/MacDogTests/PopoverScreenshotRendererTests.swift"
RUN_TESTS=1

usage() {
  cat <<USAGE
usage: $0 [--self-test] [--skip-tests]

Verify the v1.9.3 Codex remaining-credit contract. This script does not read
auth stores, call billing, run the menu bar app, install components, or push.
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
  if /usr/bin/grep -Eq -- "$pattern" "$file"; then
    die "unexpected $description in $file"
  fi
}

verify_contract() {
  local file
  for file in "$DOC" "$README" "$ROADMAP" "$ONBOARDING" "$ARCHITECTURE" \
    "$SCRIPTS_DOC" "$CHECK_SCRIPT" "$V192_RELEASE_VERIFIER" "$PANEL" \
    "$LAYOUT" "$CREDITS" "$POPOVER_TEST"; do
    require_file "$file"
  done
  [[ -x "$ROOT_DIR/script/verify_v193_codex_remaining_credits_contract.sh" ]] || \
    die "v1.9.3 contract verifier is not executable"
  reject_match 'v1\.9\.3' "$V192_RELEASE_VERIFIER" "v1.9.2 release verifier mentioning v1.9.3"

  require_match '잔여 크레딧과 초기화권은 다른 값이다' "$DOC" "credits stay separate"
  require_match 'balance`를 초기화권 장수로 쓰지 않는다' "$DOC" "balance is not a reset count"
  require_match '소수점은 반올림하지 않고 버린다' "$DOC" "truncate toward zero"
  require_match '없는 항목은 칸을 남기지 않고 숨긴다' "$DOC" "hide empty rows"
  require_match 'Grok 주간 그래프 높이는 89로 유지한다' "$DOC" "Grok plot stays fixed"
  require_match '상하좌우에 닿아 잘리면 안 된다' "$DOC" "screenshot margin"
  require_match 'weeklyGraphHeightWithRemainingCredit' "$LAYOUT" "shorter plot when both rows show"
  require_match 'detailStatusSpacing' "$PANEL" "gap above the data status"
  require_match 'fiveHourIsAvailable: state\.codexLimit\?\.fiveHour != nil' "$PANEL" \
    "graph height follows the real five-hour window"
  require_match 'roundingMode = \.down' "$CREDITS" "truncate without rounding"
  require_match 'static let readmePopoverMargin: CGFloat = 12' "$POPOVER_TEST" \
    "README canvas margin"
  require_match 'testReadmePopoverScreenshotKeepsMarginOnEverySide' "$POPOVER_TEST" \
    "margin test"
  require_match 'testCodexTabFitsOnOnePageWithoutScrollingWhenCreditsArePresent' \
    "$POPOVER_TEST" "one-page fit test"
  require_match 'testGrokWeeklyGraphStaysAtTheFixedPlotHeight' "$POPOVER_TEST" \
    "fixed Grok plot test"

  require_match 'V193CodexRemainingCredits\.md' "$README" "README contract link"
  require_match 'releases/tag/v1\.9\.3' "$README" "README links v1.9.3"
  require_match '잔여 크레딧' "$README" "README credit copy"
  require_match 'v1\.9\.3: Codex 잔여 크레딧' "$ROADMAP" "ROADMAP section"
  require_match 'verify_v193_codex_remaining_credits_contract\.sh --self-test' \
    "$ROADMAP" "ROADMAP verifier"
  require_match 'GitHub Release publish·Finder 재설치·그래프 보존 완료' "$ROADMAP" \
    "v1.9.2 published phrase stays"
  require_match 'v1\.9\.3 잔여 크레딧' "$ONBOARDING" "onboarding term"
  require_match 'balance를 초기화권 장수로 쓰지 않습니다' "$ARCHITECTURE" \
    "architecture keeps the two credit concepts apart"
  require_match 'verify_v193_codex_remaining_credits_contract\.sh --self-test' \
    "$SCRIPTS_DOC" "Scripts.md entry"
  require_match 'verify_v193_codex_remaining_credits_contract\.sh --self-test' \
    "$CHECK_SCRIPT" "check.sh gate"

  echo "v1.9.3 Codex remaining credits contract ok"
}

run_focused_tests() {
  DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}" \
  CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-/private/tmp/macdog-clang-module-cache}" \
    /usr/bin/xcrun swift test \
      --filter testReadmePopoverScreenshotKeepsMarginOnEverySide \
      --filter testCodexTabFitsOnOnePageWithoutScrollingWhenCreditsArePresent \
      --filter testGrokWeeklyGraphStaysAtTheFixedPlotHeight \
      --filter testCodexPageShowsRemainingCreditUnderResetCreditsOnlyWhenPresent
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
echo "v1.9.3 Codex remaining credits contract ok"
