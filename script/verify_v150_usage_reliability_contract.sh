#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HEALTH_SOURCE="$ROOT_DIR/Sources/CodexUsageCore/Usage/CodexUsageHealth.swift"
DOCTOR_FORMATTER_SOURCE="$ROOT_DIR/Sources/CodexUsageCore/Usage/CodexUsageDoctorFormatter.swift"
CLI_SOURCE="$ROOT_DIR/Sources/CodexUsageCLI/main.swift"
FAILURE_GUIDE_SOURCE="$ROOT_DIR/Sources/CodexUsageCore/Usage/CodexUsageFailureGuide.swift"
HISTORY_SOURCE="$ROOT_DIR/Sources/CodexUsageCore/Cache/CodexUsageResetWindowHistory.swift"
OVERLAY_SOURCE="$ROOT_DIR/Sources/CodexUsageCore/Cache/CodexUsageResetWindowOverlay.swift"
CACHE_SOURCE="$ROOT_DIR/Sources/CodexUsageCore/Cache/CodexUsageCache.swift"
USAGE_STATE_SOURCE="$ROOT_DIR/Sources/MacDog/UsageMonitorState.swift"
CODEX_PANEL_SOURCE="$ROOT_DIR/Sources/MacDog/Popover/CodexUsagePanel.swift"
USAGE_FETCH_SMOKE="$ROOT_DIR/script/verify_usage_fetch_cache_contract.sh"
CACHE_TESTS="$ROOT_DIR/Tests/CodexUsageCoreTests/CodexUsageCacheTests.swift"
DOCTOR_TESTS="$ROOT_DIR/Tests/CodexUsageCoreTests/CodexUsageDoctorFormatterTests.swift"
HISTORY_TESTS="$ROOT_DIR/Tests/CodexUsageCoreTests/UsageResetWindowHistoryTests.swift"
STATE_TESTS="$ROOT_DIR/Tests/MacDogTests/UsageMonitorStateTests.swift"
README="$ROOT_DIR/README.md"
ROADMAP="$ROOT_DIR/ROADMAP.md"
RUN_TESTS=1

usage() {
  cat <<USAGE
usage: $0 [--self-test] [--skip-tests]

Verify the v1.5.0 usage reliability and diagnostics contract. This script is
read-only: it does not read Codex auth files, call the live app-server, open GUI
apps, install LaunchAgents, or push.

Options:
  --self-test   Run the same contract checks.
  --skip-tests  Check source and document guards without running swift test.
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

require_absent() {
  local pattern="$1"
  local file="$2"
  local description="$3"

  if /usr/bin/grep -Eq "$pattern" "$file"; then
    die "unexpected $description in $file"
  fi
}

verify_sources() {
  require_file "$HEALTH_SOURCE"
  require_file "$DOCTOR_FORMATTER_SOURCE"
  require_file "$CLI_SOURCE"
  require_file "$FAILURE_GUIDE_SOURCE"
  require_file "$HISTORY_SOURCE"
  require_file "$OVERLAY_SOURCE"
  require_file "$CACHE_SOURCE"
  require_file "$USAGE_STATE_SOURCE"
  require_file "$CODEX_PANEL_SOURCE"
  require_file "$USAGE_FETCH_SMOKE"
  require_file "$CACHE_TESTS"
  require_file "$DOCTOR_TESTS"
  require_file "$HISTORY_TESTS"
  require_file "$STATE_TESTS"
  require_file "$README"
  require_file "$ROADMAP"

  require_match 'public enum CodexUsageHealthState' "$HEALTH_SOURCE" "usage health state model"
  require_match 'public enum CodexUsageHealthAppendState' "$HEALTH_SOURCE" "append health state model"
  require_match 'public enum CodexUsageHealthPaceState' "$HEALTH_SOURCE" "pace health state model"
  require_match 'public struct CodexUsageHealthReader' "$HEALTH_SOURCE" "usage health reader"
  require_match 'CodexUsageWeeklyHistoryStore\.defaultFileURL' "$HEALTH_SOURCE" "weekly history adjacency"
  require_match 'CodexUsageResetWindowHistoryStore\.defaultFileURL' "$HEALTH_SOURCE" "reset-window history adjacency"
  require_match 'adjacentToCacheFileURL: cacheFileURL' "$HEALTH_SOURCE" "history paths next to cache"
  require_match 'snapshot\.error != nil' "$HEALTH_SOURCE" "cache error state split"
  require_match 'snapshot\.isStale\(now:' "$HEALTH_SOURCE" "cache stale state split"
  require_match 'weeklyAppendState' "$HEALTH_SOURCE" "weekly append health"
  require_match 'resetWindowRetentionState' "$HEALTH_SOURCE" "reset-window retention health"
  require_match 'CodexUsagePaceProjectionBuilder' "$HEALTH_SOURCE" "pace sample health"
  require_match 'usageHealthLines' "$DOCTOR_FORMATTER_SOURCE" "doctor health formatter"
  require_match 'weeklyAppendState\.rawValue' "$DOCTOR_FORMATTER_SOURCE" "doctor weekly append summary"
  require_match 'resetWindowRetentionState\.rawValue' "$DOCTOR_FORMATTER_SOURCE" "doctor retention summary"
  require_match 'Pace:' "$DOCTOR_FORMATTER_SOURCE" "doctor pace summary"
  require_match 'Next: run `codex-usage status --write-cache`' "$DOCTOR_FORMATTER_SOURCE" "doctor next-step guidance"
  require_match 'CodexUsageHealthReader\(\)\.read\(\)' "$CLI_SOURCE" "doctor CLI health reader wiring"

  require_match 'logicalResetWindowToleranceSeconds' "$HISTORY_SOURCE" "logical weekly reset tolerance"
  require_match 'canonicalized' "$HISTORY_SOURCE" "reset-window dedupe canonicalization"
  require_match 'isSameLogicalResetWindow' "$HISTORY_SOURCE" "logical reset-window matching"
  require_match 'logicalResetWindowToleranceSeconds' "$OVERLAY_SOURCE" "current reset drift exclusion"
  require_match 'CodexUsageDataStatus' "$USAGE_STATE_SOURCE" "Codex tab data status model"
  require_match 'codexDataStatus' "$USAGE_STATE_SOURCE" "Codex tab data status presenter"
  require_match 'CodexUsageDataStatusBlock' "$CODEX_PANEL_SOURCE" "Codex tab data status UI block"
  require_match 'usage-fetch:weekly-history' "$USAGE_FETCH_SMOKE" "weekly history live smoke summary"
  require_match 'usage-fetch:reset-window-history' "$USAGE_FETCH_SMOKE" "reset-window history live smoke summary"
  require_match 'reset window history append: stored' "$USAGE_FETCH_SMOKE" "reset-window append diagnostic live smoke guard"

  require_match 'testUsageHealthReaderReportsCacheAndHistoryCounts' "$CACHE_TESTS" "health reader cache/history test"
  require_match 'testUsageHealthReaderSeparatesMissingAndStaleCache' "$CACHE_TESTS" "health reader missing/stale test"
  require_match 'testUsageHealthReaderReportsResetWindowRetentionOverflow' "$CACHE_TESTS" "health reader retention test"
  require_match 'testFormatsUsageHealthSummaryWithoutRawErrorMessage' "$DOCTOR_TESTS" "doctor health privacy test"
  require_match 'testFormatsUsageHealthNextStepForMissingCache' "$DOCTOR_TESTS" "doctor next-step test"
  require_match 'testStoreMergesRollingResetTimestampSamplesIntoOneLogicalWeeklyWindow' "$HISTORY_TESTS" "reset boundary dedupe test"
  require_match 'testStoreKeepsSameDayObservedResetWindowsApart' "$HISTORY_TESTS" "same-day actual reset split test"
  require_match 'testBackfillSummariesIncludeInterruptedFutureResetWindowsBeforeCurrentWindow' "$HISTORY_TESTS" "interrupted future reset backfill test"
  require_match 'testBackfillSummariesUseResetStartsAndLeaveInterruptedWindowTailEmpty' "$HISTORY_TESTS" "reset-start partial window tail test"
  require_match 'testInterruptedWindowFinalMarkerUsesActualLastSampleDay' "$ROOT_DIR/Tests/CodexUsageCoreTests/ResetWindowOverlayModelTests.swift" "interrupted overlay marker position test"
  require_match 'testCodexHistoryComparisonModelExcludesRollingCurrentResetDuplicates' "$STATE_TESTS" "current reset duplicate exclusion test"
  require_match 'testCodexHistoryComparisonModelUsesLatestResetStartAsCurrentWindow' "$STATE_TESTS" "latest reset-start current window test"
  require_match 'testWeeklyHistoryChartKeepsSamplesWhenResetTimestampRollsWithinSameStartWindow' "$STATE_TESTS" "current reset-start rolling timestamp test"
  require_match 'testCodexDataStatusReportsReadyCacheAndHistory' "$STATE_TESTS" "Codex data status ready test"
  require_match 'testCodexDataStatusReportsHistorySampleWaiting' "$STATE_TESTS" "Codex data status sample waiting test"
  require_match 'testCodexDataStatusSeparatesStaleAndErrorCache' "$STATE_TESTS" "Codex data status stale/error test"
  require_match 'testCodexDataStatusFlagsMissingRequiredWindowsAsProtocolCheck' "$STATE_TESTS" "Codex data status protocol drift test"

  require_match 'Do not paste auth tokens or raw app-server payloads' "$FAILURE_GUIDE_SOURCE" "raw payload redaction guidance"
  require_match 'schema may have changed' "$FAILURE_GUIDE_SOURCE" "schema drift guidance"
  require_match 'protocol may have changed' "$FAILURE_GUIDE_SOURCE" "protocol drift guidance"
  require_match 'CodexUsageCacheSnapshot: Codable, Equatable, Sendable' "$CACHE_SOURCE" "cache schema remains stable"
  require_match 'currentSchemaVersion = 1' "$CACHE_SOURCE" "cache schema version remains v1"
  require_match 'usage-weekly-history\.json' "$README" "README weekly history contract"
  require_match 'usage-reset-window-history\.json' "$README" "README reset-window history contract"
  require_match 'codex-usage doctor' "$README" "README doctor command"
  require_match 'reset boundary 그래프 회귀 수정' "$ROADMAP" "roadmap reset boundary P0 issue"
  require_match 'verify_v150_usage_reliability_contract\.sh --self-test' "$ROADMAP" "roadmap v1.5 verifier"

  require_absent 'auth\.json' "$HEALTH_SOURCE" "direct Codex auth file access"
  require_absent 'rawResponse|raw app-server payload|access[_-]?token|refresh[_-]?token|session material' "$HEALTH_SOURCE" "sensitive health reader material"
}

run_focused_tests() {
  DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}" \
    /usr/bin/xcrun swift test \
      --filter UsageResetWindowHistoryTests \
      --filter ResetWindowOverlayModelTests \
      --filter UsageMonitorStateTests \
      --filter CodexUsageCacheTests \
      --filter CodexUsageDoctorFormatterTests \
      --filter CodexUsageFailureGuideTests \
      --filter CodexUsageReportTests
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --self-test)
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

cd "$ROOT_DIR"
verify_sources

if [[ "$RUN_TESTS" == "1" ]]; then
  run_focused_tests
fi

echo "v1.5.0 usage reliability contract ok"
