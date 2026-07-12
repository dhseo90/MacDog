#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIVE_HOUR_SOURCE="$ROOT_DIR/Sources/CodexUsageCore/Cache/CodexUsageFiveHourHistory.swift"
SCENARIO_SOURCE="$ROOT_DIR/Sources/CodexUsageCore/Usage/CodexPlanTransitionScenario.swift"
CACHE_SOURCE="$ROOT_DIR/Sources/CodexUsageCore/Cache/CodexUsageCache.swift"
USAGE_REPORT_SOURCE="$ROOT_DIR/Sources/CodexUsageCore/Usage/CodexUsageReport.swift"
USAGE_FORMATTER_SOURCE="$ROOT_DIR/Sources/CodexUsageCore/Usage/CodexUsageFormatter.swift"
USAGE_STATE_SOURCE="$ROOT_DIR/Sources/MacDog/UsageMonitorState.swift"
PANEL_SOURCE="$ROOT_DIR/Sources/MacDog/Popover/CodexUsagePanel.swift"
TRANSITION_VIEW_SOURCE="$ROOT_DIR/Sources/MacDog/Popover/CodexPlanTransitionViews.swift"
SETTINGS_SOURCE="$ROOT_DIR/Sources/MacDog/Popover/SettingsPanel.swift"
HISTORY_TEST="$ROOT_DIR/Tests/CodexUsageCoreTests/CodexUsageFiveHourHistoryTests.swift"
SCENARIO_TEST="$ROOT_DIR/Tests/CodexUsageCoreTests/CodexPlanTransitionScenarioTests.swift"
USAGE_STATE_TEST="$ROOT_DIR/Tests/MacDogTests/UsageMonitorStateTests.swift"
SCREENSHOT_TEST="$ROOT_DIR/Tests/MacDogTests/PopoverScreenshotRendererTests.swift"
ROADMAP="$ROOT_DIR/ROADMAP.md"
README="$ROOT_DIR/README.md"
DESIGN_DOC="$ROOT_DIR/Docs/V170CodexPro100Transition.md"
RUN_TESTS=1
SELF_TEST_REQUESTED=0

usage() {
  cat <<USAGE
usage: $0 --self-test [--skip-tests]

Verify the v1.7.0 Codex Pro \$100 downgrade-readiness contract.
This script is read-only: it does not read Codex auth files, call the live
app-server or network, open GUI apps, install components, or push.

Options:
  --self-test   Run source, test, documentation, privacy, and focused Swift checks.
  --skip-tests  Check static contracts without running swift test.
  --help        Show this help.
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

  /usr/bin/grep -Eq "$pattern" "$file" || die "missing $description in $file"
}

reject_match() {
  local pattern="$1"
  local file="$2"
  local description="$3"

  if /usr/bin/grep -Eiq "$pattern" "$file"; then
    die "unexpected $description in $file"
  fi
}

verify_files() {
  require_file "$FIVE_HOUR_SOURCE"
  require_file "$SCENARIO_SOURCE"
  require_file "$CACHE_SOURCE"
  require_file "$USAGE_REPORT_SOURCE"
  require_file "$USAGE_FORMATTER_SOURCE"
  require_file "$USAGE_STATE_SOURCE"
  require_file "$PANEL_SOURCE"
  require_file "$TRANSITION_VIEW_SOURCE"
  require_file "$SETTINGS_SOURCE"
  require_file "$HISTORY_TEST"
  require_file "$SCENARIO_TEST"
  require_file "$USAGE_STATE_TEST"
  require_file "$SCREENSHOT_TEST"
  require_file "$ROADMAP"
  require_file "$README"
  require_file "$DESIGN_DOC"
}

verify_separate_store_contract() {
  require_match 'CodexUsageFiveHourHistory' "$FIVE_HOUR_SOURCE" "five-hour history model"
  require_match 'CodexUsageFiveHourHistoryStore' "$FIVE_HOUR_SOURCE" "five-hour history store"
  require_match 'usage-five-hour-history\.json' "$FIVE_HOUR_SOURCE" "separate five-hour history filename"
  require_match 'windowDurationMins' "$FIVE_HOUR_SOURCE" "five-hour window duration field"
  require_match 'usedPercent' "$FIVE_HOUR_SOURCE" "five-hour usage field"
  require_match 'resetsAt' "$FIVE_HOUR_SOURCE" "five-hour reset boundary field"
  require_match 'planEpochID' "$FIVE_HOUR_SOURCE" "plan epoch field"
  require_match 'reassignPlanEpoch' "$FIVE_HOUR_SOURCE" "backdated transition epoch migration"
  require_match 'dataWriter' "$FIVE_HOUR_SOURCE" "injectable history writer"
  require_match '\[\.atomic\]' "$FIVE_HOUR_SOURCE" "atomic history write"

  require_match 'CodexPlanTransitionConfiguration' "$SCENARIO_SOURCE" "plan transition configuration"
  require_match 'CodexPlanTransitionScenario' "$SCENARIO_SOURCE" "plan transition scenario"
  require_match 'usage-plan-transition\.json' "$SCENARIO_SOURCE" "separate plan transition filename"
  require_match 'P50|p50' "$SCENARIO_SOURCE" "P50 peak calculation"
  require_match 'P90|p90' "$SCENARIO_SOURCE" "P90 peak calculation"
  require_match 'reserve' "$SCENARIO_SOURCE" "reserve calculation"
  require_match 'insufficient|관측 부족' "$SCENARIO_SOURCE" "insufficient observation state"
  require_match 'targetFiveHour' "$SCENARIO_SOURCE" "post-transition actual observation model"
  require_match 'targetObservationCutoff' "$SCENARIO_SOURCE" "first seven-day target observation boundary"
  require_match 'fiveHourP90DeltaPercent' "$SCENARIO_SOURCE" "projected versus actual delta"
  require_match '사용자 설정 기반 예상' "$SCENARIO_SOURCE" "scenario basis disclaimer"

  require_match 'usage-five-hour-history\.json' "$DESIGN_DOC" "documented five-hour history filename"
  require_match 'usage-plan-transition\.json' "$DESIGN_DOC" "documented plan transition filename"
  require_match 'CodexUsageFiveHourHistory' "$HISTORY_TEST" "five-hour history focused tests"
  require_match 'CodexPlanTransitionScenario' "$SCENARIO_TEST" "plan transition scenario focused tests"
  require_match 'CodexUsageFiveHourHistoryStore' "$CACHE_SOURCE" "five-hour history cache writer integration"
  require_match 'CodexPlanTransitionConfigurationStore' "$CACHE_SOURCE" "plan epoch configuration cache integration"
  reject_match 'try\?.*CodexPlanTransitionConfigurationStore' "$CACHE_SOURCE" "silenced plan configuration read failure"

  reject_match 'usage-weekly-history\.json|usage-reset-window-history\.json|usage\.json' \
    "$FIVE_HOUR_SOURCE" "reuse of an existing cache/history filename"
  reject_match 'usage-weekly-history\.json|usage-reset-window-history\.json|usage\.json' \
    "$SCENARIO_SOURCE" "reuse of an existing cache/history filename"
}

verify_product_boundary() {
  require_match 'CodexUsageFiveHourHistory|fiveHourHistory' "$USAGE_STATE_SOURCE" "five-hour history UI state"
  require_match 'CodexPlanTransitionConfiguration|planTransitionConfiguration' "$USAGE_STATE_SOURCE" "plan transition configuration UI state"
  require_match 'CodexPlanTransitionScenario|planTransitionScenario' "$USAGE_STATE_SOURCE" "plan transition scenario UI state"
  require_match 'CodexPlanTransitionReadinessBlock' "$PANEL_SOURCE" "transition readiness panel wiring"
  require_match '플랜 전환 준비' "$TRANSITION_VIEW_SOURCE" "compact transition readiness section"
  require_match 'basisLabel|사용자 설정 기반 예상' "$TRANSITION_VIEW_SOURCE" "scenario disclaimer presentation"
  require_match 'CodexPlanTransitionSettingsEditor' "$SETTINGS_SOURCE" "plan transition settings wiring"
  require_match '현재 플랜' "$TRANSITION_VIEW_SOURCE" "current plan setting"
  require_match '목표 플랜' "$TRANSITION_VIEW_SOURCE" "target plan setting"
  require_match '상대 용량|relativeCapacity' "$TRANSITION_VIEW_SOURCE" "relative capacity setting"
  require_match 'reserve|여유' "$TRANSITION_VIEW_SOURCE" "reserve setting"
  require_match '전환' "$TRANSITION_VIEW_SOURCE" "transition date setting"
  require_match 'reconcile' "$TRANSITION_VIEW_SOURCE" "idempotent backdated epoch reconciliation"

  require_match 'codex-usage status --json' \
    "$DESIGN_DOC" "stable status JSON boundary"
  require_match 'usage\.json' "$DESIGN_DOC" "stable existing cache boundary"
  require_match 'usage-weekly-history\.json' "$DESIGN_DOC" "stable weekly history boundary"
  require_match 'usage-reset-window-history\.json' "$DESIGN_DOC" "stable reset-window history boundary"
  require_match 'breaking change 없이 유지' "$DESIGN_DOC" "non-breaking schema boundary"
  require_match '자동.*추정하지 않습니다|가격 tier.*자동.*추정' "$DESIGN_DOC" "no automatic price-tier inference boundary"

  reject_match 'planType|pricingTierLabel|infer[A-Za-z]*(Price|Pricing|Tier)|auto[A-Za-z]*(Price|Pricing|Tier)' \
    "$SCENARIO_SOURCE" "automatic price-tier inference"
  reject_match 'planType|pricingTierLabel|infer[A-Za-z]*(Price|Pricing|Tier)|auto[A-Za-z]*(Price|Pricing|Tier)' \
    "$FIVE_HOUR_SOURCE" "automatic price-tier inference"
}

verify_privacy_boundary() {
  local forbidden='access[_-]?token|refresh[_-]?token|auth(orization)?[_-]?(header|token)?|cookie|session([_-]?(id|token|material))?|raw[_-]?(response|log|payload)'

  require_match 'raw app-server response.*raw log.*auth token.*cookie.*session material.*auth header' \
    "$DESIGN_DOC" "raw/auth/session privacy boundary"
  reject_match "$forbidden" "$FIVE_HOUR_SOURCE" "auth/raw/session persistence field"
  reject_match "$forbidden" "$SCENARIO_SOURCE" "auth/raw/session persistence field"

  require_match 'test.*(Sensitive|Privacy|Auth|Raw|Session)|민감' \
    "$HISTORY_TEST" "five-hour history privacy regression test"
  require_match 'func json\(from report: CodexUsageReport\)' \
    "$USAGE_FORMATTER_SOURCE" "unchanged report-only JSON formatter"
  require_match 'CodexUsageCacheSnapshot' "$CACHE_SOURCE" "existing cache snapshot boundary"
  require_match 'public struct CodexUsageReport' "$USAGE_REPORT_SOURCE" "existing usage report boundary"
}

run_focused_tests() {
  CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-/private/tmp/macdog-clang-module-cache}" \
  DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}" \
    /usr/bin/xcrun swift test \
      --filter CodexUsageFiveHourHistoryTests \
      --filter CodexPlanTransitionScenarioTests \
      --filter CodexUsageCacheTests \
      --filter UsageMonitorStateTests \
      --filter PopoverScreenshotRendererTests
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --self-test)
      SELF_TEST_REQUESTED=1
      ;;
    --skip-tests)
      RUN_TESTS=0
      ;;
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

[[ "$SELF_TEST_REQUESTED" == "1" ]] || {
  usage >&2
  exit 2
}

cd "$ROOT_DIR"
verify_files
verify_separate_store_contract
verify_product_boundary
verify_privacy_boundary

if [[ "$RUN_TESTS" == "1" ]]; then
  echo "==> Running v1.7.0 focused Swift tests"
  run_focused_tests
fi

echo "v1.7.0 Codex Pro \$100 transition contract ok"
