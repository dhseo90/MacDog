#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROADMAP="$ROOT_DIR/ROADMAP.md"
DOC="$ROOT_DIR/Docs/V180ClaudeUsageParityPreview.md"
SNAPSHOT_SOURCE="$ROOT_DIR/Sources/CodexUsageCore/Claude/ClaudeStatusLineSnapshot.swift"
CACHE_SOURCE="$ROOT_DIR/Sources/CodexUsageCore/Claude/ClaudeUsageCache.swift"
HISTORY_SOURCE="$ROOT_DIR/Sources/CodexUsageCore/Claude/ClaudeUsageHistory.swift"
BRIDGE_SOURCE="$ROOT_DIR/Sources/ClaudeUsageBridgeCLI/main.swift"
CLAUDE_PANEL_SOURCE="$ROOT_DIR/Sources/MacDog/Popover/ClaudeUsagePreviewPanel.swift"
PRIVACY_TEST="$ROOT_DIR/Tests/CodexUsageCoreTests/ClaudeUsagePrivacyTests.swift"
PREFERENCES_SOURCE="$ROOT_DIR/Sources/MacDog/RunnerPreferences.swift"
STATE_SOURCE="$ROOT_DIR/Sources/MacDog/UsageMonitorState.swift"
CONTROLLER_SOURCE="$ROOT_DIR/Sources/MacDog/MenuBarController.swift"
POPOVER_SOURCE="$ROOT_DIR/Sources/MacDog/UsagePopoverView.swift"
SETTINGS_SOURCE="$ROOT_DIR/Sources/MacDog/Popover/SettingsPanel.swift"
REFRESH_SOURCE="$ROOT_DIR/Sources/MacDog/CodexUsageCacheRefreshPolicy.swift"
USER_COMPONENT_SOURCE="$ROOT_DIR/Sources/MacDog/UserComponentInstaller.swift"
STATE_TEST="$ROOT_DIR/Tests/MacDogTests/UsageMonitorStateTests.swift"
REFRESH_TEST="$ROOT_DIR/Tests/MacDogTests/CodexUsageCacheRefreshPolicyTests.swift"
NOTIFICATION_TEST="$ROOT_DIR/Tests/MacDogTests/UsageNotificationDeliveryTests.swift"
POPOVER_TEST="$ROOT_DIR/Tests/MacDogTests/PopoverScreenshotRendererTests.swift"
USER_COMPONENT_TEST="$ROOT_DIR/Tests/MacDogTests/UserComponentInstallerTests.swift"
INSTALL_VERIFIER="$ROOT_DIR/script/verify_install_state.sh"
FINAL_STATE_VERIFIER="$ROOT_DIR/script/verify_release_final_state.sh"
PACKAGING_VERIFIER="$ROOT_DIR/script/verify_release_packaging.sh"
RUN_TESTS=1

usage() {
  cat <<USAGE
usage: $0 [--self-test] [--skip-tests]

Verify the reusable Claude backend and selected-provider v1.8.0 product contract.
This script does not read Claude settings, auth stores, Keychain, or transcripts,
use the network, run GUI apps, install components, or push.
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
  for file in "$ROADMAP" "$DOC" "$SNAPSHOT_SOURCE" "$CACHE_SOURCE" "$HISTORY_SOURCE" \
    "$BRIDGE_SOURCE" "$PRIVACY_TEST" "$PREFERENCES_SOURCE" "$STATE_SOURCE" \
    "$CONTROLLER_SOURCE" "$POPOVER_SOURCE" "$SETTINGS_SOURCE" "$REFRESH_SOURCE" \
    "$STATE_TEST" "$REFRESH_TEST" "$NOTIFICATION_TEST" "$POPOVER_TEST" \
    "$USER_COMPONENT_SOURCE" "$USER_COMPONENT_TEST" \
    "$CLAUDE_PANEL_SOURCE" "$INSTALL_VERIFIER" "$FINAL_STATE_VERIFIER" \
    "$PACKAGING_VERIFIER"; do
    require_file "$file"
  done
  [[ -x "$ROOT_DIR/script/verify_v180_selected_provider_contract.sh" ]] || \
    die "v1.8 selected-provider verifier is not executable"

  require_match '선택형 Codex/Claude 사용량 mode와 안정화' "$ROADMAP" "selected-provider roadmap"
  reject_match 'v1\.8\.1|v1\.9\.0' "$ROADMAP" "removed future milestone"
  require_match '두 provider 동시 사용' "$DOC" "single-provider boundary"
  require_match '합산·비교.*구현하지 않습니다' "$DOC" "no combined usage boundary"
  require_match '사용량 mode.*Codex' "$DOC" "single mode setting"
  require_match '다른 provider로 자동 fallback하지' "$DOC" "no fallback boundary"
  require_match 'context_window' "$DOC" "context token input"
  require_match '현재 대화 context' "$DOC" "context token distinction"
  require_match 'reset credit.*합성하지' "$DOC" "no synthetic reset credit"
  require_match '5시간 history.*planEpochID' "$DOC" "five-hour history reuse"
  require_match 'live·설치·GUI.*검증' "$DOC" "integrated stabilization scope"

  require_match 'rateLimits = "rate_limits"' "$SNAPSHOT_SOURCE" "rate limit coding key"
  require_match 'fiveHour = "five_hour"' "$SNAPSHOT_SOURCE" "five-hour coding key"
  require_match 'sevenDay = "seven_day"' "$SNAPSHOT_SOURCE" "seven-day coding key"
  require_match 'usedPercentage = "used_percentage"' "$SNAPSHOT_SOURCE" "usage coding key"
  require_match 'resetsAt = "resets_at"' "$SNAPSHOT_SOURCE" "reset coding key"
  require_match 'maximumStatusLineBytes' "$CACHE_SOURCE" "bounded input"
  require_match 'claude-usage\.json' "$CACHE_SOURCE" "separate cache"
  require_match 'claude-usage-history\.json' "$HISTORY_SOURCE" "separate history"
  require_match 'F_SETLKW' "$CACHE_SOURCE" "cross-process lock"
  require_match 'readBoundedStatusLineInput' "$BRIDGE_SOURCE" "complete stdin reader"
  reject_match 'Process\(|/bin/zsh|--existing-command|MACDOG_CLAUDE_CACHE_PATH' "$BRIDGE_SOURCE" \
    "raw passthrough or production path override"
  require_match 'session-secret-123' "$PRIVACY_TEST" "privacy sentinel"
  require_match 'testSanitizedSnapshotDropsUnusedModelValuesIncludingSensitiveLookingText' \
    "$PRIVACY_TEST" "unused model privacy regression"
  require_match 'testLegacySanitizedCacheModelKeyDecodesButNewEncodingOmitsIt' \
    "$ROOT_DIR/Tests/CodexUsageCoreTests/ClaudeStatusLineSnapshotTests.swift" \
    "legacy model cache decode regression"
  reject_match 'ClaudeStatusLineModel|case model|let model' "$SNAPSHOT_SOURCE" \
    "unused model persistence"
  require_match '% 사용 · .*% 남음' "$CLAUDE_PANEL_SOURCE" "used and remaining usage summary"
  require_match 'Claude 연결 필요' "$CLAUDE_PANEL_SOURCE" "missing cache empty state"
  require_match '연결 명령 복사' "$CLAUDE_PANEL_SOURCE" "manual connection action"
  require_match 'connectionGuide\.standaloneCommand' "$CLAUDE_PANEL_SOURCE" \
    "bounded manual connection command"
  require_match 'preview\.currentWindow' "$CLAUDE_PANEL_SOURCE" "fresh per-window display source"
  require_match 'window 만료 · 새 event 대기' "$CLAUDE_PANEL_SOURCE" "expired window state"
  reject_match '"[^"]*(Claude Preview|PREVIEW)' "$CLAUDE_PANEL_SOURCE" "preview product copy"
  reject_match '"[^"]*(Claude Preview|PREVIEW)' "$BRIDGE_SOURCE" "preview bridge copy"
  require_match 'macdog-claude-statusline' "$INSTALL_VERIFIER" "installed bridge gate"
  require_match 'usage_provider_mode' "$INSTALL_VERIFIER" "mode-aware install verification"
  require_match 'installed Claude status line bridge is not runnable' "$FINAL_STATE_VERIFIER" \
    "release final-state bridge gate"
  require_match 'macdog-claude-statusline bridge' "$PACKAGING_VERIFIER" \
    "release packaging bridge contract"

  require_match 'usageProviderModeKey' "$PREFERENCES_SOURCE" "single provider preference key"
  require_match 'migrateUsageProviderMode' "$PREFERENCES_SOURCE" "provider preference migration"
  require_match 'cacheAgentAction\(for mode: UsageProviderMode\)' "$USER_COMPONENT_SOURCE" \
    "mode-aware cache agent action"
  require_match 'case \.remove:' "$USER_COMPONENT_SOURCE" "Claude cache agent removal"
  require_match 'synchronizeInstalledUsageCacheAgentIfNeeded' "$CONTROLLER_SOURCE" \
    "provider change cache agent synchronization"
  require_match 'enum UsageProviderMode' "$ROOT_DIR/Sources/MacDog/ClaudeUsagePreviewState.swift" \
    "canonical provider mode"
  require_match 'switch usageProviderMode' "$STATE_SOURCE" "selected runner source"
  require_match 'case \.claude:' "$STATE_SOURCE" "Claude runner state"
  require_match 'return \.calm' "$STATE_SOURCE" "no fallback runner state"
  require_match 'UsageNotificationRoute\(mode: loadedState\.usageProviderMode\)' "$CONTROLLER_SOURCE" \
    "selected notification route"
  require_match 'shouldRunLiveRefresh\(for mode: UsageProviderMode\)' "$REFRESH_SOURCE" \
    "selected refresh policy"
  require_match 'Picker\("사용량 mode"' "$SETTINGS_SOURCE" "single settings mode picker"
  require_match 'state\.usageProviderMode == \.claude' "$POPOVER_SOURCE" "selected usage tab"

  require_match 'testUsageProviderMigrationDefaultsExistingUsersToCodexAndRemovesLegacyKeys' \
    "$STATE_TEST" "migration regression test"
  require_match 'testSelectedProviderModeIsTheOnlyRunnerSourceAndNeverFallsBack' \
    "$STATE_TEST" "no fallback regression test"
  require_match 'testClaudeCurrentWindowExcludesExpiredWindowWhileKeepingFreshPartialWindow' \
    "$STATE_TEST" "expired window display regression test"
  require_match 'testLiveCodexRefreshRunsOnlyInCodexMode' "$REFRESH_TEST" \
    "refresh routing regression test"
  require_match 'testNotificationRouteSelectsExactlyOneProvider' "$NOTIFICATION_TEST" \
    "notification routing regression test"
  require_match 'testSelectedProviderUIUsesOnlySettingsModePicker' "$POPOVER_TEST" \
    "single picker regression test"
  require_match 'testUsageCacheLaunchAgentRunsOnlyInCodexMode' "$USER_COMPONENT_TEST" \
    "mode-aware cache agent regression test"
  require_match 'testClaudeModeRemovesCodexCacheLaunchAgentWithoutTouchingUsageCache' \
    "$USER_COMPONENT_TEST" "Claude cache agent removal regression test"
  require_match 'testCodexModeCreatesCacheLaunchAgentAfterClaudeMode' "$USER_COMPONENT_TEST" \
    "Codex cache agent restore regression test"

  for file in "$STATE_SOURCE" "$CONTROLLER_SOURCE" "$POPOVER_SOURCE" "$SETTINGS_SOURCE"; do
    reject_match 'claudeUsagePreviewEnabled|usagePreviewProvider|claudeRunnerPreviewEnabled|claudeUsageNotificationsEnabled' \
      "$file" "legacy provider preference use"
    reject_match 'Claude Usage Preview|Claude Preview 사용|러너 반영|Claude 알림|Picker\("사용량 provider"' \
      "$file" "removed preview UI"
  done

  "$ROOT_DIR/script/verify_v170_codex_pacemaker_contract.sh" --skip-tests
}

run_focused_tests() {
  DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}" \
  CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-/private/tmp/macdog-clang-module-cache}" \
    /usr/bin/xcrun swift test \
      --filter ClaudeStatusLineSnapshotTests \
      --filter ClaudeUsageCacheTests \
      --filter ClaudeUsagePrivacyTests \
      --filter UsageMonitorStateTests \
      --filter CodexUsageCacheRefreshPolicyTests \
      --filter UsageNotificationDeliveryTests \
      --filter UsageNotificationSettingsTests \
      --filter PopoverScreenshotRendererTests \
      --filter UserComponentInstallerTests

  "$INSTALL_VERIFIER" --self-test
  "$FINAL_STATE_VERIFIER" --self-test
  "$ROOT_DIR/script/verify_app_privacy_boundaries.sh"
  "$PACKAGING_VERIFIER"
}

verify_synthetic_bridge() {
  local bridge="$ROOT_DIR/.build/debug/macdog-claude-statusline"
  [[ -x "$bridge" ]] || die "focused tests did not build bridge executable: $bridge"
  local temp_dir
  temp_dir="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/macdog-v180-selected.XXXXXX")"
  trap 'rm -rf "$temp_dir"' EXIT
  "$bridge" --test-cache-directory "$temp_dir" \
    <"$ROOT_DIR/Tests/CodexUsageCoreTests/Fixtures/claude_status_line_sensitive.json" \
    >"$temp_dir/output.txt"
  require_match '^Claude · 5시간 34% · 7일 44%$' "$temp_dir/output.txt" "sanitized bridge output"
  "$bridge" --test-cache-directory "$temp_dir" </dev/null >"$temp_dir/waiting.txt"
  require_match '^Claude · 입력 대기$' "$temp_dir/waiting.txt" "non-preview waiting output"
  if /usr/bin/grep -R -E 'session-secret|transcript-private|secret-token|refresh-token-secret|cookie-secret' \
    "$temp_dir" >/dev/null; then
    die "privacy sentinel leaked into bridge output/cache/history"
  fi
  trap - EXIT
  rm -rf "$temp_dir"
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
  verify_synthetic_bridge
fi
echo "v1.8.0 selected-provider contract ok"
