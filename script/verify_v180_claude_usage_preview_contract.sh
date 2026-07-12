#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SNAPSHOT_SOURCE="$ROOT_DIR/Sources/CodexUsageCore/Claude/ClaudeStatusLineSnapshot.swift"
CACHE_SOURCE="$ROOT_DIR/Sources/CodexUsageCore/Claude/ClaudeUsageCache.swift"
HISTORY_SOURCE="$ROOT_DIR/Sources/CodexUsageCore/Claude/ClaudeUsageHistory.swift"
BRIDGE_SOURCE="$ROOT_DIR/Sources/ClaudeUsageBridgeCLI/main.swift"
PREVIEW_STATE_SOURCE="$ROOT_DIR/Sources/MacDog/ClaudeUsagePreviewState.swift"
PREVIEW_PANEL_SOURCE="$ROOT_DIR/Sources/MacDog/Popover/ClaudeUsagePreviewPanel.swift"
SETTINGS_SOURCE="$ROOT_DIR/Sources/MacDog/Popover/SettingsPanel.swift"
RUNNER_SOURCE="$ROOT_DIR/Sources/MacDog/UsageMonitorState.swift"
NOTIFICATION_SOURCE="$ROOT_DIR/Sources/MacDog/ClaudeUsageNotificationPolicy.swift"
PACKAGE_MANIFEST="$ROOT_DIR/Package.swift"
BUILD_SCRIPT="$ROOT_DIR/script/build_and_run.sh"
APP_BUNDLE_VERIFIER="$ROOT_DIR/script/verify_app_bundle.sh"
RELEASE_WORKFLOW="$ROOT_DIR/.github/workflows/release-stable.yml"
SNAPSHOT_TEST="$ROOT_DIR/Tests/CodexUsageCoreTests/ClaudeStatusLineSnapshotTests.swift"
CACHE_TEST="$ROOT_DIR/Tests/CodexUsageCoreTests/ClaudeUsageCacheTests.swift"
PRIVACY_TEST="$ROOT_DIR/Tests/CodexUsageCoreTests/ClaudeUsagePrivacyTests.swift"
STATE_TEST="$ROOT_DIR/Tests/MacDogTests/UsageMonitorStateTests.swift"
SCREENSHOT_TEST="$ROOT_DIR/Tests/MacDogTests/PopoverScreenshotRendererTests.swift"
DESIGN_DOC="$ROOT_DIR/Docs/V180ClaudeUsageParityPreview.md"
ROADMAP="$ROOT_DIR/ROADMAP.md"
README="$ROOT_DIR/README.md"
RUN_TESTS=1
SELF_TEST_REQUESTED=0

usage() {
  cat <<USAGE
usage: $0 --self-test [--skip-tests]

Verify the offline v1.8.0 Claude Usage Preview contract.
This script does not read Claude settings, auth stores, Keychain, transcripts,
or live subscription data. It does not use the network, open GUI apps, install
components, register LaunchAgents, sign artifacts, or push.

Options:
  --self-test   Run static contracts, focused Swift tests, and a synthetic bridge fixture.
  --skip-tests  Run static contracts only.
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

verify_files() {
  local file
  for file in \
    "$SNAPSHOT_SOURCE" "$CACHE_SOURCE" "$HISTORY_SOURCE" "$BRIDGE_SOURCE" \
    "$PREVIEW_STATE_SOURCE" "$PREVIEW_PANEL_SOURCE" "$SETTINGS_SOURCE" \
    "$RUNNER_SOURCE" "$NOTIFICATION_SOURCE" "$PACKAGE_MANIFEST" \
    "$BUILD_SCRIPT" "$APP_BUNDLE_VERIFIER" "$SNAPSHOT_TEST" "$CACHE_TEST" \
    "$PRIVACY_TEST" "$STATE_TEST" "$SCREENSHOT_TEST" "$DESIGN_DOC" \
    "$ROADMAP" "$README"; do
    require_file "$file"
  done

  local fixture
  for fixture in full five_hour_only seven_day_only missing_rate_limits null_unknown sensitive; do
    require_file "$ROOT_DIR/Tests/CodexUsageCoreTests/Fixtures/claude_status_line_${fixture}.json"
  done
}

verify_input_and_privacy_contract() {
  require_match 'rateLimits = "rate_limits"' "$SNAPSHOT_SOURCE" "rate_limits coding key"
  require_match 'fiveHour = "five_hour"' "$SNAPSHOT_SOURCE" "five-hour coding key"
  require_match 'sevenDay = "seven_day"' "$SNAPSHOT_SOURCE" "seven-day coding key"
  require_match 'usedPercentage = "used_percentage"' "$SNAPSHOT_SOURCE" "usage percentage coding key"
  require_match 'resetsAt = "resets_at"' "$SNAPSHOT_SOURCE" "reset timestamp coding key"
  require_match 'providerID = "claude"' "$SNAPSHOT_SOURCE" "constant provider identifier"
  require_match 'maximumStatusLineBytes' "$CACHE_SOURCE" "bounded status line input"
  require_match 'status_line_decode_failed' "$SNAPSHOT_SOURCE" "sanitized decode error code"
  require_match 'status_line_too_large' "$CACHE_SOURCE" "oversized input error code"
  require_match 'return "unknown_error"' "$CACHE_SOURCE" "closed cache issue code allowlist"
  require_match 'readBoundedStatusLineInput' "$BRIDGE_SOURCE" "complete bounded stdin reader"
  require_match '--test-cache-directory' "$BRIDGE_SOURCE" "temp-contained test cache option"

  reject_match 'session[_-]?id|prompt[_-]?id|transcript[_-]?path|current[_-]?dir|repository|access[_-]?token|refresh[_-]?token|authorization|cookie' \
    "$SNAPSHOT_SOURCE" "forbidden persisted status line field"
  reject_match 'print\(.*error|localizedDescription|debugDescription|NSLog|os_log' \
    "$BRIDGE_SOURCE" "raw or detailed bridge error logging"
  reject_match 'Process\(|/bin/zsh|--existing-command|MACDOG_CLAUDE_CACHE_PATH|MACDOG_CLAUDE_HISTORY_PATH' \
    "$BRIDGE_SOURCE" "raw passthrough or production cache path override"
  require_match 'session-secret-123' "$PRIVACY_TEST" "synthetic session privacy sentinel"
  require_match 'refresh-token-secret' "$PRIVACY_TEST" "synthetic token privacy sentinel"
  require_match 'XCTAssertFalse' "$PRIVACY_TEST" "privacy exclusion assertions"
}

verify_cache_history_contract() {
  require_match 'claude-usage\.json' "$CACHE_SOURCE" "separate Claude cache filename"
  require_match 'claude-usage-history\.json' "$HISTORY_SOURCE" "separate Claude history filename"
  require_match 'claude-usage\.lock' "$CACHE_SOURCE" "Claude ingestion lock"
  require_match 'lastEventAt' "$CACHE_SOURCE" "last event timestamp"
  require_match 'lastUsageObservedAt' "$CACHE_SOURCE" "last usage timestamp"
  require_match '\[\.atomic\]' "$CACHE_SOURCE" "atomic cache write"
  require_match '\[\.atomic\]' "$HISTORY_SOURCE" "atomic history write"
  require_match 'F_SETLKW' "$CACHE_SOURCE" "cross-process write lock"
  require_match 'F_RDLCK' "$CACHE_SOURCE" "cross-process read lock"
  require_match 'readState\(\)' "$CACHE_SOURCE" "single-lock cache and history read"
  require_match '0o700' "$CACHE_SOURCE" "private cache directory permissions"
  require_match '0o600' "$CACHE_SOURCE" "private cache file permissions"
  require_match 'fchmod' "$CACHE_SOURCE" "private lock file permissions"
  require_match 'maximumSampleCount' "$HISTORY_SOURCE" "bounded history retention"
  require_match 'ClaudeUsagePaceProjectionBuilder' "$HISTORY_SOURCE" "Claude pace projection"
  reject_match 'usage-weekly-history\.json|usage-reset-window-history\.json|usage-five-hour-history\.json|usage-plan-transition\.json' \
    "$CACHE_SOURCE" "reuse of Codex history filename"
  reject_match 'usage-weekly-history\.json|usage-reset-window-history\.json|usage-five-hour-history\.json|usage-plan-transition\.json' \
    "$HISTORY_SOURCE" "reuse of Codex history filename"
}

verify_product_contract() {
  require_match 'macdog-claude-statusline' "$PACKAGE_MANIFEST" "bridge SwiftPM product"
  require_match 'macdog-claude-statusline' "$BUILD_SCRIPT" "bridge app bundle copy"
  require_match 'APP_CLAUDE_BRIDGE_BINARY' "$APP_BUNDLE_VERIFIER" "bridge bundle verification"
  require_match 'defaultClaudeUsagePreviewEnabled = false' "$ROOT_DIR/Sources/MacDog/RunnerPreferences.swift" "Preview default-off setting"
  require_match 'Claude Preview' "$PREVIEW_PANEL_SOURCE" "provider Preview label"
  require_match '5시간|fiveHour' "$PREVIEW_PANEL_SOURCE" "five-hour presentation"
  require_match '7일|sevenDay' "$PREVIEW_PANEL_SOURCE" "seven-day presentation"
  require_match 'current|현재' "$PREVIEW_PANEL_SOURCE" "current history mode"
  require_match 'past|지난' "$PREVIEW_PANEL_SOURCE" "past history mode"
  require_match 'compare|비교' "$PREVIEW_PANEL_SOURCE" "comparison history mode"
  require_match 'macdog-claude-usage-' "$PREVIEW_PANEL_SOURCE" "provider-labeled PNG filename"
  require_match 'claudeRunnerPreviewEnabled' "$RUNNER_SOURCE" "Preview-gated runner input"
  require_match 'runnerUsedPercent' "$RUNNER_SOURCE" "Preview runner adapter"
  require_match 'freshMaxUsedPercent' "$PREVIEW_STATE_SOURCE" "fresh-only runner input"
  require_match 'freshWindow' "$NOTIFICATION_SOURCE" "fresh-only notification input"
  require_match 'pace 일시 중지' "$PREVIEW_PANEL_SOURCE" "stale and error pace suppression"
  require_match 'claude\.usage\.' "$NOTIFICATION_SOURCE" "provider-separated notification dedupe"
  reject_match 'CodexResetCreditsBlock|resetCredits' "$PREVIEW_PANEL_SOURCE" "Claude reset credit UI"
  require_match '기존 Claude statusLine 설정과 auth store를 읽거나 덮어쓰지 않습니다' "$SETTINGS_SOURCE" "manual connection boundary"
  require_match '감사된 stdin fan-out wrapper 필요' "$PREVIEW_STATE_SOURCE" "non-executable merge guidance"
  require_match 'preserve Claude statusLine settings' "$ROOT_DIR/script/uninstall.sh" "manual statusLine uninstall recovery boundary"
  require_match 'Contents/MacOS/macdog-claude-statusline' "$RELEASE_WORKFLOW" "stable workflow bridge signing"
}

verify_documentation_contract() {
  require_match 'claude-usage\.json' "$DESIGN_DOC" "documented Claude cache filename"
  require_match 'claude-usage-history\.json' "$DESIGN_DOC" "documented Claude history filename"
  require_match '15분|900' "$DESIGN_DOC" "documented event stale threshold"
  require_match '기본.*꺼짐|기본 OFF' "$DESIGN_DOC" "Preview default-off boundary"
  require_match '자동.*덮어쓰지' "$DESIGN_DOC" "no automatic statusLine overwrite"
  require_match 'live Claude 구독 검수 미수행' "$DESIGN_DOC" "live validation boundary"
  require_match 'Claude Usage Preview' "$README" "README Preview documentation"
  require_match '자동 검증.*live.*미수행|live.*미수행' "$ROADMAP" "roadmap automatic/live separation"
}

run_focused_tests() {
  CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-/private/tmp/macdog-clang-module-cache}" \
  DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}" \
    /usr/bin/xcrun swift test \
      --filter ClaudeStatusLineSnapshotTests \
      --filter ClaudeUsageCacheTests \
      --filter ClaudeUsagePrivacyTests \
      --filter ClaudeUsageNotificationPolicyTests \
      --filter UsageMonitorStateTests \
      --filter PopoverScreenshotRendererTests
}

verify_synthetic_bridge() {
  local bridge="$ROOT_DIR/.build/debug/macdog-claude-statusline"
  [[ -x "$bridge" ]] || die "focused tests did not build bridge executable: $bridge"
  local temp_dir
  temp_dir="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/macdog-v180-bridge.XXXXXX")"
  trap "rm -rf '$temp_dir'" EXIT
  local output="$temp_dir/status-line.txt"
  "$bridge" --test-cache-directory "$temp_dir" \
    <"$ROOT_DIR/Tests/CodexUsageCoreTests/Fixtures/claude_status_line_sensitive.json" \
    >"$output"
  require_match '^Claude · 5시간 34% · 7일 44%$' "$output" "sanitized bridge output"

  local chunked_dir="$temp_dir/chunked"
  /bin/mkdir -p "$chunked_dir"
  /bin/dd if="$ROOT_DIR/Tests/CodexUsageCoreTests/Fixtures/claude_status_line_sensitive.json" bs=7 2>/dev/null \
    | "$bridge" --test-cache-directory "$chunked_dir" >"$temp_dir/chunked-status-line.txt"
  require_match '^Claude · 5시간 34% · 7일 44%$' "$temp_dir/chunked-status-line.txt" "chunked pipe bridge output"

  local rejected_output="$temp_dir/rejected-status-line.txt"
  "$bridge" --test-cache-directory "$ROOT_DIR" \
    <"$ROOT_DIR/Tests/CodexUsageCoreTests/Fixtures/claude_status_line_full.json" \
    >"$rejected_output"
  require_match '^Claude Preview · 설정 오류$' "$rejected_output" "out-of-temp test path rejection"
  [[ ! -e "$ROOT_DIR/claude-usage.json" && ! -e "$ROOT_DIR/claude-usage-history.json" ]] || \
    die "rejected bridge test path wrote into the repository"
  if /usr/bin/grep -R -E 'session-secret|prompt-secret|transcript-private|private-project|private-repository|secret-token|refresh-token-secret|cookie-secret' "$temp_dir" >/dev/null; then
    die "synthetic privacy sentinel leaked into bridge output/cache/history"
  fi
  trap - EXIT
  rm -rf "$temp_dir"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --self-test) SELF_TEST_REQUESTED=1 ;;
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

[[ "$SELF_TEST_REQUESTED" == "1" ]] || {
  usage >&2
  exit 2
}

cd "$ROOT_DIR"
verify_files
verify_input_and_privacy_contract
verify_cache_history_contract
verify_product_contract
verify_documentation_contract

if [[ "$RUN_TESTS" == "1" ]]; then
  echo "==> Running v1.8.0 focused Swift tests"
  run_focused_tests
  echo "==> Running synthetic sanitized bridge fixture"
  verify_synthetic_bridge
fi

echo "v1.8.0 Claude Usage Preview contract ok"
