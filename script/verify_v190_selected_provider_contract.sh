#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOC="$ROOT_DIR/Docs/V190GrokUsageAndClaudeHide.md"
SPIKE="$ROOT_DIR/Docs/V190GrokUsageSourceSpike.md"
CONTRACT="$ROOT_DIR/Docs/V190GrokWeeklyOnlyContract.md"
V180_VERIFIER="$ROOT_DIR/script/verify_v180_selected_provider_contract.sh"
MODE_SOURCE="$ROOT_DIR/Sources/MacDog/ClaudeUsagePreviewState.swift"
PREFERENCES_SOURCE="$ROOT_DIR/Sources/MacDog/RunnerPreferences.swift"
STATE_SOURCE="$ROOT_DIR/Sources/MacDog/UsageMonitorState.swift"
CONTROLLER_SOURCE="$ROOT_DIR/Sources/MacDog/MenuBarController.swift"
POPOVER_SOURCE="$ROOT_DIR/Sources/MacDog/UsagePopoverView.swift"
SETTINGS_SOURCE="$ROOT_DIR/Sources/MacDog/Popover/SettingsPanel.swift"
GROK_PANEL_SOURCE="$ROOT_DIR/Sources/MacDog/Popover/GrokUsagePanel.swift"
GROK_CACHE_SOURCE="$ROOT_DIR/Sources/CodexUsageCore/Grok/GrokUsageCache.swift"
GROK_HISTORY_SOURCE="$ROOT_DIR/Sources/CodexUsageCore/Grok/GrokUsageHistory.swift"
GROK_SANITIZER_SOURCE="$ROOT_DIR/Sources/CodexUsageCore/Grok/GrokBillingSanitizer.swift"
GROK_AUTH_SOURCE="$ROOT_DIR/Sources/CodexUsageCore/Grok/GrokLocalAuthTokenProvider.swift"
GROK_FETCH_SOURCE="$ROOT_DIR/Sources/CodexUsageCore/Grok/GrokUsageFetchService.swift"
GROK_CLI_SOURCE="$ROOT_DIR/Sources/GrokUsageCLI/main.swift"
GROK_NOTIFICATION_SOURCE="$ROOT_DIR/Sources/MacDog/GrokUsageNotificationPolicy.swift"
USER_COMPONENT_SOURCE="$ROOT_DIR/Sources/MacDog/UserComponentInstaller.swift"
STATE_TEST="$ROOT_DIR/Tests/MacDogTests/UsageMonitorStateTests.swift"
NOTIFICATION_TEST="$ROOT_DIR/Tests/MacDogTests/UsageNotificationDeliveryTests.swift"
GROK_NOTIFICATION_TEST="$ROOT_DIR/Tests/MacDogTests/GrokUsageNotificationPolicyTests.swift"
GROK_CACHE_TEST="$ROOT_DIR/Tests/CodexUsageCoreTests/GrokUsageCacheTests.swift"
GROK_PRIVACY_TEST="$ROOT_DIR/Tests/CodexUsageCoreTests/GrokUsagePrivacyTests.swift"
GROK_SANITIZER_TEST="$ROOT_DIR/Tests/CodexUsageCoreTests/GrokBillingSanitizerTests.swift"
GROK_AUTH_TEST="$ROOT_DIR/Tests/CodexUsageCoreTests/GrokLocalAuthTokenProviderTests.swift"
GROK_FETCH_TEST="$ROOT_DIR/Tests/CodexUsageCoreTests/GrokUsageFetchServiceTests.swift"
POPOVER_TEST="$ROOT_DIR/Tests/MacDogTests/PopoverScreenshotRendererTests.swift"
USER_COMPONENT_TEST="$ROOT_DIR/Tests/MacDogTests/UserComponentInstallerTests.swift"
REFRESH_TEST="$ROOT_DIR/Tests/MacDogTests/CodexUsageCacheRefreshPolicyTests.swift"
RUN_TESTS=1

usage() {
  cat <<USAGE
usage: $0 [--self-test] [--skip-tests]

Verify the v1.9.0 Grok weekly-only and Claude hide contract.
This script does not read ~/.grok/auth.json, use live billing, run GUI apps,
install components, or push. It keeps the completed v1.8 verifier intact.
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
  for file in "$DOC" "$SPIKE" "$CONTRACT" "$V180_VERIFIER" \
    "$MODE_SOURCE" "$PREFERENCES_SOURCE" "$STATE_SOURCE" "$CONTROLLER_SOURCE" \
    "$POPOVER_SOURCE" "$SETTINGS_SOURCE" "$GROK_PANEL_SOURCE" \
    "$GROK_CACHE_SOURCE" "$GROK_HISTORY_SOURCE" "$GROK_SANITIZER_SOURCE" \
    "$GROK_AUTH_SOURCE" "$GROK_FETCH_SOURCE" "$GROK_CLI_SOURCE" \
    "$GROK_NOTIFICATION_SOURCE" "$USER_COMPONENT_SOURCE" \
    "$STATE_TEST" "$NOTIFICATION_TEST" "$GROK_NOTIFICATION_TEST" \
    "$GROK_CACHE_TEST" "$GROK_PRIVACY_TEST" "$GROK_SANITIZER_TEST" \
    "$GROK_AUTH_TEST" "$GROK_FETCH_TEST" "$POPOVER_TEST" \
    "$USER_COMPONENT_TEST" "$REFRESH_TEST"; do
    require_file "$file"
  done
  [[ -x "$V180_VERIFIER" ]] || die "v1.8 selected-provider verifier is not executable"
  "$V180_VERIFIER" --self-test --skip-tests

  require_match 'Claude hide' "$DOC" "Claude hide milestone"
  require_match 'unofficial-cli-billing' "$CONTRACT" "unofficial source"
  require_match '100 - usedPercent' "$CONTRACT" "remaining calculation"
  require_match '사용자 승인 없이' "$CONTRACT" "auth store approval boundary"
  require_match 'x\.ai/billing' "$SPIKE" "selected unofficial billing path"

  require_match 'case grok' "$MODE_SOURCE" "grok provider case"
  require_match 'visibleCases' "$MODE_SOURCE" "hidden Claude picker cases"
  require_match 'claudeUsageProviderReenabled' "$PREFERENCES_SOURCE" "hidden Claude re-enable"
  require_match 'storedMode == \.claude' "$PREFERENCES_SOURCE" "Claude migration to Codex"
  require_match 'shouldEvaluateCodexCache' "$MODE_SOURCE" "no Codex cache evaluation"
  require_match 'case \.grok:' "$STATE_SOURCE" "Grok runner branch"
  require_match 'case grok' "$ROOT_DIR/Sources/MacDog/UsageNotificationDelivery.swift" \
    "three-way notification route"
  require_match 'grokUsageNotificationDispatcher.dispatch' "$CONTROLLER_SOURCE" \
    "Grok notification dispatch"
  require_match 'grokCacheAgentAction' "$USER_COMPONENT_SOURCE" "Grok LaunchAgent action"
  require_match 'macdog-grok-usage' "$USER_COMPONENT_SOURCE" "Grok writer LaunchAgent"
  require_match 'GrokUsagePanel' "$POPOVER_SOURCE" "Grok usage tab"
  require_match '현재 제공되지 않음' "$GROK_PANEL_SOURCE" "unavailable five-hour copy"
  reject_match '초기화권|reset credit' "$GROK_PANEL_SOURCE" "Grok reset credit UI"
  require_match 'grok-usage\.json' "$GROK_CACHE_SOURCE" "separate Grok cache"
  require_match 'grok-usage-history\.json' "$GROK_HISTORY_SOURCE" "separate Grok history"
  require_match 'creditUsagePercent' "$GROK_SANITIZER_SOURCE" "weekly used percent field"
  reject_match 'XAI_API_KEY' "$GROK_AUTH_SOURCE" "API key weekly pool auth"
  reject_match 'print\(accessToken|Authorization' "$GROK_CLI_SOURCE" "token printing"

  require_match 'testVisibleSettingsModesHideClaudeAndKeepGrok' "$STATE_TEST" \
    "Claude hide regression"
  require_match 'testUsageProviderMigrationKeepsClaudeOnlyWhenHiddenReenableIsOn' \
    "$STATE_TEST" "hidden re-enable migration regression"
  require_match 'testSelectedUsageSourcePolicyDoesNotEvaluateCodexCacheOutsideCodexMode' \
    "$STATE_TEST" "no Codex fallback regression"
  require_match 'testGrokWeeklyCacheDrivesRunnerWithoutCodexFallback' "$STATE_TEST" \
    "Grok runner source regression"
  require_match 'UsageNotificationRoute\(mode: \.grok\), \.grok' "$NOTIFICATION_TEST" \
    "three-way route regression"
  require_match 'testCreatesWeeklyOnlyCandidatesForFreshPreview' "$GROK_NOTIFICATION_TEST" \
    "Grok weekly notification regression"
  require_match 'testEncodedCacheOmitsForbiddenAuthAndBillingKeys' "$GROK_PRIVACY_TEST" \
    "Grok cache privacy regression"
  require_match 'testRejectsMonthlyCycleAndMissingPercent' "$GROK_SANITIZER_TEST" \
    "console credit rejection"
  require_match 'testMissingAuthStoreDoesNotUseXAIAPIKey' "$GROK_AUTH_TEST" \
    "API key rejection"
  require_match 'testSuccessfulFetchWritesSanitizedWeeklySampleWithoutRawPayload' \
    "$GROK_FETCH_TEST" "writer privacy regression"
  require_match 'testGrokModeInstallsGrokAgentAndRemovesCodexAgent' "$USER_COMPONENT_TEST" \
    "Grok LaunchAgent regression"
  require_match 'testGrokRefreshCommandWritesCacheWithoutMirror' "$REFRESH_TEST" \
    "Grok polling command regression"
  require_match 'GrokUsagePanel\(preview: state.grokUsage' "$POPOVER_TEST" \
    "Grok panel wiring regression"

  for file in "$GROK_CACHE_SOURCE" "$GROK_HISTORY_SOURCE" "$GROK_CLI_SOURCE" \
    "$GROK_PANEL_SOURCE" "$CONTRACT"; do
    reject_match 'eyJ[A-Za-z0-9_-]{10,}' "$file" "JWT-like token"
  done
}

run_focused_tests() {
  DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}" \
  CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-/private/tmp/macdog-clang-module-cache}" \
    /usr/bin/xcrun swift test \
      --filter GrokUsageCacheTests \
      --filter GrokUsagePrivacyTests \
      --filter GrokBillingSanitizerTests \
      --filter GrokLocalAuthTokenProviderTests \
      --filter GrokUsageFetchServiceTests \
      --filter GrokUsageNotificationPolicyTests \
      --filter UsageMonitorStateTests \
      --filter UsageNotificationDeliveryTests \
      --filter CodexUsageCacheRefreshPolicyTests \
      --filter PopoverScreenshotRendererTests \
      --filter UserComponentInstallerTests

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

verify_contract
if [[ "$RUN_TESTS" == "1" ]]; then
  run_focused_tests
fi
echo "v1.9.0 selected-provider contract ok"
