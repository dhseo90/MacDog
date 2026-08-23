#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOC="$ROOT_DIR/Docs/V190GrokUsageAndClaudeHide.md"
SPIKE="$ROOT_DIR/Docs/V190GrokUsageSourceSpike.md"
CONTRACT="$ROOT_DIR/Docs/V190GrokWeeklyOnlyContract.md"
READINESS="$ROOT_DIR/Docs/V190ReleaseReadiness.md"
README="$ROOT_DIR/README.md"
ROADMAP="$ROOT_DIR/ROADMAP.md"
AGENTS="$ROOT_DIR/AGENTS.md"
ONBOARDING="$ROOT_DIR/Docs/Onboarding/README.md"
V180_VERIFIER="$ROOT_DIR/script/verify_v180_selected_provider_contract.sh"
MODE_SOURCE="$ROOT_DIR/Sources/MacDog/ClaudeUsagePreviewState.swift"
PREFERENCES_SOURCE="$ROOT_DIR/Sources/MacDog/RunnerPreferences.swift"
STATE_SOURCE="$ROOT_DIR/Sources/MacDog/UsageMonitorState.swift"
CONTROLLER_SOURCE="$ROOT_DIR/Sources/MacDog/MenuBarController.swift"
POPOVER_SOURCE="$ROOT_DIR/Sources/MacDog/UsagePopoverView.swift"
SETTINGS_SOURCE="$ROOT_DIR/Sources/MacDog/Popover/SettingsPanel.swift"
PET_MENU_SOURCE="$ROOT_DIR/Sources/MacDog/PetMenuModel.swift"
PET_MENU_TEST="$ROOT_DIR/Tests/MacDogTests/PetMenuModelTests.swift"
SLEEP_PANEL_SOURCE="$ROOT_DIR/Sources/MacDog/Popover/SleepPreventionPanel.swift"
UNINSTALL_SOURCE="$ROOT_DIR/script/uninstall.sh"
DATE_BASELINE_SOURCE="$ROOT_DIR/Sources/MacDog/UsageGraphDateBaseline.swift"
GROK_PANEL_SOURCE="$ROOT_DIR/Sources/MacDog/Popover/GrokUsagePanel.swift"
GROK_ADAPTER_SOURCE="$ROOT_DIR/Sources/MacDog/Popover/GrokWeeklyRemainingHistoryAdapter.swift"
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
  for file in "$DOC" "$SPIKE" "$CONTRACT" "$READINESS" "$README" "$ROADMAP" \
    "$AGENTS" "$ONBOARDING" "$V180_VERIFIER" \
    "$MODE_SOURCE" "$PREFERENCES_SOURCE" "$STATE_SOURCE" "$CONTROLLER_SOURCE" \
    "$POPOVER_SOURCE" "$SETTINGS_SOURCE" "$DATE_BASELINE_SOURCE" \
    "$PET_MENU_SOURCE" "$PET_MENU_TEST" "$SLEEP_PANEL_SOURCE" \
    "$UNINSTALL_SOURCE" \
    "$GROK_PANEL_SOURCE" "$GROK_ADAPTER_SOURCE" \
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
  reject_match 'v1\.9\.0' "$V180_VERIFIER" "v1.8 verifier mentioning v1.9.0"

  require_match 'Claude hide' "$DOC" "Claude hide milestone"
  require_match 'unofficial-cli-billing' "$CONTRACT" "unofficial source"
  require_match '100 - usedPercent' "$CONTRACT" "remaining calculation"
  require_match '사용자 승인 없이' "$CONTRACT" "auth store approval boundary"
  require_match 'auth.json.lock' "$CONTRACT" "sibling auth lock"
  require_match 'atomic merge write' "$CONTRACT" "sibling auth write"
  require_match 'x\.ai/billing' "$SPIKE" "selected unofficial billing path"
  require_match '`1\.9\.0` 제품의 설정 visible mode는 `Codex`와 `Grok`' \
    "$README" "README visible Codex/Grok product"
  require_match '현재 GitHub Release는 \[v1\.9\.0\]' "$README" \
    "README published v1.9.0"
  require_match 'MacDog-1\.9\.0\.dmg' "$README" "README current installer"
  require_match 'b7072003830798bb1603768c4efb0b41409100f6' "$README" \
    "README published release head"
  require_match '선택형 Codex/Grok 사용량 mode와 Claude hide' "$ROADMAP" \
    "ROADMAP v1.9.0 section"
  require_match 'GUI·live Grok billing·Finder drag 관찰 미수행' "$ROADMAP" \
    "ROADMAP honest smoke status"
  require_match 'macdog-grok-usage' "$AGENTS" "AGENTS Grok writer"
  require_match '~/\.grok/auth\.json' "$AGENTS" "AGENTS Grok auth exception"
  require_match '100 - usedPercent' "$AGENTS" "AGENTS Grok remaining rule"
  require_match '설정 visible mode는' "$ONBOARDING" "onboarding visible mode"
  require_match 'Codex` 또는 `Grok' "$ONBOARDING" "onboarding Codex/Grok selection"
  require_match '실제 Grok live smoke \| 미수행' "$READINESS" \
    "release readiness pending live smoke"
  require_match 'published GitHub Release는 \[v1\.9\.0\]' "$READINESS" \
    "readiness published v1.9.0"
  require_match 'Finder drag-and-drop와 GUI smoke \| 미수행' "$READINESS" \
    "readiness pending GUI confirmation"
  require_match 'cleanup / final-state \| 통과' "$READINESS" \
    "readiness completed final-state"
  reject_match '`v1\.9\.0` tag와 published DMG는 없습니다' "$READINESS" \
    "stale unpublished v1.9.0 claim"

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
  require_match 'Picker\("날짜 기준"' "$SETTINGS_SOURCE" "shared graph date baseline picker"
  require_match 'return "자정"' "$DATE_BASELINE_SOURCE" "midnight option label"
  reject_match 'return "00:00"' "$DATE_BASELINE_SOURCE" "numeric midnight option label"
  require_match 'calendarMidnight' "$DATE_BASELINE_SOURCE" "calendar midnight baseline"
  require_match 'resetWindow' "$DATE_BASELINE_SOURCE" "reset-window baseline option"
  require_match 'testCalendarMidnightBaselineMovesHoverToSundayAfterLocalMidnight' \
    "$STATE_TEST" "calendar midnight hover regression"
  require_match 'dateBaseline' \
    "$ROOT_DIR/Sources/MacDog/Popover/ClaudeUsagePreviewPanel.swift" \
    "Claude graph uses shared date baseline"
  reject_match '5시간' "$GROK_PANEL_SOURCE" "Grok five-hour card"
  require_match 'WeeklyRemainingHistoryBlock' "$GROK_PANEL_SOURCE" "shared weekly graph"
  reject_match 'GrokUsageGraphSnapshotView' "$GROK_PANEL_SOURCE" "Grok-only graph view"
  require_match 'GrokWeeklyRemainingHistoryAdapter' "$GROK_ADAPTER_SOURCE" \
    "Grok weekly adapter"
  require_match 'testGrokWeeklyHistoryMapsToSharedRemainingChartWithHoverLabels' \
    "$STATE_TEST" "shared hover mapping regression"
  require_match 'grok login' "$GROK_PANEL_SOURCE" "Grok login command"
  require_match '터미널에서 로그인' "$GROK_PANEL_SOURCE" "Grok login terminal action"
  require_match 'Grok 로그인 필요' "$MODE_SOURCE" "Grok login empty state"
  require_match 'Grok 세션 갱신 실패' "$MODE_SOURCE" "Grok session refresh empty state"
  require_match 'Grok 조회 오류' "$MODE_SOURCE" "Grok lookup error empty state"
  require_match 'showsLoginActions' "$GROK_PANEL_SOURCE" "login actions gated"
  reject_match '초기화권|reset credit' "$GROK_PANEL_SOURCE" "Grok reset credit UI"
  require_match 'grok-usage\.json' "$GROK_CACHE_SOURCE" "separate Grok cache"
  require_match 'grok-usage\.json' "$UNINSTALL_SOURCE" "uninstall Grok cache"
  require_match 'grok-usage-history\.json' "$UNINSTALL_SOURCE" "uninstall Grok history"
  require_match 'grok-usage\.lock' "$UNINSTALL_SOURCE" "uninstall Grok lock"
  require_match 'com\.dhseo\.macdog\.grok-usage-cache' "$UNINSTALL_SOURCE" \
    "uninstall Grok LaunchAgent"
  require_match 'grok-usage-history\.json' "$GROK_HISTORY_SOURCE" "separate Grok history"
  require_match 'creditUsagePercent' "$GROK_SANITIZER_SOURCE" "weekly used percent field"
  require_match 'object\["config"\]' "$GROK_SANITIZER_SOURCE" "config wrapper unwrap"
  require_match 'testExtractsWeeklyPercentFromConfigWrapperAndISOReset' "$GROK_SANITIZER_TEST" \
    "config wrapper weekly regression"
  reject_match 'XAI_API_KEY' "$GROK_AUTH_SOURCE" "API key weekly pool auth"
  require_match 'https://auth\.x\.ai' "$GROK_AUTH_SOURCE" "current grok.com issuer key"
  reject_match 'print\(accessToken|Authorization' "$GROK_CLI_SOURCE" "token printing"

  require_match 'petTitle' "$MODE_SOURCE" "selected provider pet title"
  require_match 'usageProviderMode.petTitle' "$PET_MENU_SOURCE" "pet menu uses selected provider"
  reject_match '코덱스 펫' "$PET_MENU_SOURCE" "hardcoded Codex pet menu title"
  reject_match '코덱스 사용량 종료' "$PET_MENU_SOURCE" "hardcoded Codex quit title"
  require_match 'runningTriggerTitle' "$SLEEP_PANEL_SOURCE" "sleep tab uses selected provider"
  require_match 'testMenuCopyUsesSelectedGrokProviderWithoutCodexFallback' \
    "$PET_MENU_TEST" "Grok pet menu copy regression"
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
  require_match 'testReadsAuthXAIIssuerEntryKeyWithoutUsingRefreshToken' "$GROK_AUTH_TEST" \
    "current issuer entry token"
  require_match 'testExpiredIssuerEntryRefreshesAndMergesWithoutDroppingOtherFields' \
    "$GROK_AUTH_TEST" "sibling refresh merge"
  require_match 'testLockUnavailableRereadsDiskWithoutCallingRefresher' "$GROK_AUTH_TEST" \
    "lock miss reread"
  require_match 'testSuccessfulFetchWritesSanitizedWeeklySampleWithoutRawPayload' \
    "$GROK_FETCH_TEST" "writer privacy regression"
  require_match 'testUnauthorizedRetriesOnceAfterForcedRefresh' "$GROK_FETCH_TEST" \
    "billing 401 single refresh"
  require_match 'testSecondUnauthorizedDoesNotRefreshAgain' "$GROK_FETCH_TEST" \
    "billing 401 no second refresh"
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
