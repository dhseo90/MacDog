#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROADMAP="$ROOT_DIR/ROADMAP.md"
DOC="$ROOT_DIR/Docs/V170CodexPro100Transition.md"
RELEASE_DOC="$ROOT_DIR/Docs/V170ReleaseReadiness.md"
FIVE_HOUR_SOURCE="$ROOT_DIR/Sources/CodexUsageCore/Cache/CodexUsageFiveHourHistory.swift"
WEEKLY_SOURCE="$ROOT_DIR/Sources/CodexUsageCore/Cache/CodexUsageWeeklyHistory.swift"
RESET_SOURCE="$ROOT_DIR/Sources/CodexUsageCore/Cache/CodexUsageResetWindowHistory.swift"
FIVE_HOUR_TEST="$ROOT_DIR/Tests/CodexUsageCoreTests/CodexUsageFiveHourHistoryTests.swift"
RESET_TEST="$ROOT_DIR/Tests/CodexUsageCoreTests/UsageResetWindowHistoryTests.swift"
RUN_TESTS=1

usage() {
  cat <<USAGE
usage: $0 [--self-test] [--skip-tests]

Verify the v1.7.0 Codex weekly pacemaker and v1.8.0 migration boundary.
This script does not access live usage, run GUI apps, install components, or push.
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

verify_contract() {
  local file
  for file in "$ROADMAP" "$DOC" "$RELEASE_DOC" "$FIVE_HOUR_SOURCE" "$WEEKLY_SOURCE" \
    "$RESET_SOURCE" "$FIVE_HOUR_TEST" "$RESET_TEST"; do
    require_file "$file"
  done
  [[ -x "$ROOT_DIR/script/verify_v170_codex_pacemaker_contract.sh" ]] || \
    die "v1.7 pacemaker verifier is not executable"

  require_match 'Codex 주간 잔여량 페이스메이커' "$ROADMAP" "roadmap pacemaker scope"
  require_match '전체 한도의 `1/7`.*14\.3%' "$DOC" "daily allocation contract"
  require_match 'resetsAt - windowDurationMins' "$DOC" "reset-anchored day slot contract"
  require_match '오늘 기준 계산 중' "$DOC" "insufficient sample boundary"
  require_match 'usage-five-hour-history\.json.*계속 사용' "$DOC" "five-hour history retention"
  require_match '`planEpochID`.*제거' "$DOC" "plan epoch removal target"
  require_match 'usage-plan-transition\.json.*자동 삭제하지' "$DOC" "legacy file preservation"
  require_match 'published v1\.7\.0' "$RELEASE_DOC" "published release boundary"
  require_match '역사적 기록' "$RELEASE_DOC" "historical release boundary"

  require_match 'defaultRetentionSeconds' "$FIVE_HOUR_SOURCE" "five-hour retention"
  require_match '\[\.atomic\]' "$FIVE_HOUR_SOURCE" "five-hour atomic write"
  require_match 'logicalWindowTimestampToleranceSeconds' "$FIVE_HOUR_SOURCE" "logical window dedupe"
  require_match 'CodexUsageWeeklyHistory' "$WEEKLY_SOURCE" "weekly history"
  require_match 'dailyEndSamples' "$RESET_SOURCE" "daily reset samples"
  require_match 'dayIndex' "$RESET_SOURCE" "window-anchored day index"
  require_match 'CodexUsageFiveHourHistoryStore' "$FIVE_HOUR_TEST" "five-hour history tests"
  require_match 'dailyEndSamples' "$RESET_TEST" "daily marker tests"
}

run_focused_tests() {
  DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}" \
  CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-/private/tmp/macdog-clang-module-cache}" \
    /usr/bin/xcrun swift test \
      --filter CodexUsageFiveHourHistoryTests \
      --filter UsageResetWindowHistoryTests \
      --filter UsagePaceProjectionTests
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
echo "v1.7.0 Codex pacemaker contract ok"
