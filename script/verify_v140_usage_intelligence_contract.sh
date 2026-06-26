#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HISTORY_SOURCE="$ROOT_DIR/Sources/CodexUsageCore/Cache/CodexUsageResetWindowHistory.swift"
OVERLAY_SOURCE="$ROOT_DIR/Sources/CodexUsageCore/Cache/CodexUsageResetWindowOverlay.swift"
PACE_SOURCE="$ROOT_DIR/Sources/CodexUsageCore/Usage/CodexUsagePaceProjection.swift"
GRAPH_EXPORT_SOURCE="$ROOT_DIR/Sources/MacDog/Popover/CodexUsageGraphImageExporter.swift"
USAGE_STATE_SOURCE="$ROOT_DIR/Sources/MacDog/UsageMonitorState.swift"
SCREENSHOT_RENDERER_TEST="$ROOT_DIR/Tests/MacDogTests/PopoverScreenshotRendererTests.swift"
FIXTURE="$ROOT_DIR/Tests/CodexUsageCoreTests/Fixtures/v140_reset_window_history.json"
RUN_TESTS=1

usage() {
  cat <<USAGE
usage: $0 [--self-test] [--skip-tests]

Verify the v1.4.0 usage intelligence cache/privacy/history contract.
This script is read-only: it does not read Codex auth files, call the live
app-server, open GUI apps, install LaunchAgents, or push.

Options:
  --self-test   Run the same contract checks.
  --skip-tests  Check source and fixture contracts without running swift test.
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

verify_fixture() {
  require_file "$FIXTURE"
  /usr/bin/ruby -rjson -e '
    path = ARGV.fetch(0)
    data = JSON.parse(File.read(path))
    records = data["records"]
    abort("fixture records must be an array") unless records.is_a?(Array) && records.length >= 2

    sources = records.map { |record| record["source"] }.uniq
    abort("fixture must include live-cache source") unless sources.include?("live-cache")
    abort("fixture must include backfill source") unless sources.include?("backfill")

    forbidden = /(access[_-]?token|refresh[_-]?token|session|authorization|cookie|raw(Log|Response)?|\/Users\/)/i
    text = JSON.dump(data)
    abort("fixture contains forbidden sensitive/raw metadata") if text.match?(forbidden)

    records.each do |record|
      required = %w[
        schemaVersion generatedAt limitId windowDurationMins resetStartAt resetsAt
        dailyEndSamples finalUsedPercent finalRemainingPercent sampleCount source
      ]
      missing = required.reject { |key| record.key?(key) }
      abort("history record missing keys: #{missing.join(", ")}") unless missing.empty?
      samples = record["dailyEndSamples"]
      abort("dailyEndSamples must be an array") unless samples.is_a?(Array)
      samples.each do |sample|
        sample_required = %w[dayIndex recordedAt usedPercent remainingPercent]
        sample_missing = sample_required.reject { |key| sample.key?(key) }
        abort("daily sample missing keys: #{sample_missing.join(", ")}") unless sample_missing.empty?
      end
    end
  ' "$FIXTURE"
}

verify_sources() {
  require_file "$HISTORY_SOURCE"
  require_file "$OVERLAY_SOURCE"
  require_file "$PACE_SOURCE"
  require_file "$GRAPH_EXPORT_SOURCE"
  require_file "$USAGE_STATE_SOURCE"
  require_file "$SCREENSHOT_RENDERER_TEST"

  require_match 'usage-reset-window-history\.json' "$HISTORY_SOURCE" "reset window history file contract"
  require_match 'CodexUsageResetWindowBackfillSummary' "$HISTORY_SOURCE" "summary-only backfill boundary"
  require_match 'source: \.backfill' "$HISTORY_SOURCE" "backfill source marker"
  require_match 'CodexUsagePaceProjectionState' "$PACE_SOURCE" "pace state model"
  require_match 'waitingForSamples' "$PACE_SOURCE" "sample shortage pace state"
  require_match 'CodexUsageResetWindowOverlayBuilder' "$OVERLAY_SOURCE" "overlay model builder"
  require_match 'timelineEndDay: 7' "$OVERLAY_SOURCE" "0-7 day overlay timeline"
  require_match 'CodexUsageGraphImageExporter' "$GRAPH_EXPORT_SOURCE" "graph PNG export/copy support"
  require_match 'representation\(using: \.png, properties: \[:\]\)' "$GRAPH_EXPORT_SOURCE" "PNG export without metadata properties"
  require_match 'resetWindowHistory' "$USAGE_STATE_SOURCE" "UI reads generated reset-window records"
  require_match 'MacDogDemoData\.state' "$SCREENSHOT_RENDERER_TEST" "README screenshot renderer uses demo state"
  require_match 'CodexUsageResetWindowHistoryStore\(\)\.read\(\)' "$SCREENSHOT_RENDERER_TEST" "live screenshot renderer reads reset-window history"
}

run_focused_tests() {
  DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}" \
    /usr/bin/xcrun swift test \
      --filter UsageResetWindowHistoryTests \
      --filter UsagePaceProjectionTests \
      --filter ResetWindowOverlayModelTests \
      --filter CodexUsageGraphImageExporterTests
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
verify_fixture

if [[ "$RUN_TESTS" == "1" ]]; then
  run_focused_tests
fi

echo "v1.4.0 usage intelligence contract ok"
