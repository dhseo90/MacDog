#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOC="$ROOT_DIR/Docs/V191MultiProviderUsage.md"
README="$ROOT_DIR/README.md"
ROADMAP="$ROOT_DIR/ROADMAP.md"
AGENTS="$ROOT_DIR/AGENTS.md"
ONBOARDING="$ROOT_DIR/Docs/Onboarding/README.md"
SCRIPTS_DOC="$ROOT_DIR/Docs/Scripts.md"
CHECK_SCRIPT="$ROOT_DIR/script/check.sh"
V190_VERIFIER="$ROOT_DIR/script/verify_v190_selected_provider_contract.sh"
SELECTION_SOURCE="$ROOT_DIR/Sources/MacDog/UsageProviderSelection.swift"
PREFERENCES_SOURCE="$ROOT_DIR/Sources/MacDog/RunnerPreferences.swift"
WORK_DIFF_SOURCE="$ROOT_DIR/Sources/MacDog/UsageProviderWorkDiff.swift"
GAUGES_SOURCE="$ROOT_DIR/Sources/MacDog/CombinedUsageGauges.swift"
LABEL_SOURCE="$ROOT_DIR/Sources/MacDog/MenuBarWeeklyRemainingLabel.swift"
CONTROLLER_SOURCE="$ROOT_DIR/Sources/MacDog/MenuBarController.swift"
POPOVER_SOURCE="$ROOT_DIR/Sources/MacDog/UsagePopoverView.swift"
SETTINGS_SOURCE="$ROOT_DIR/Sources/MacDog/Popover/SettingsPanel.swift"
CODEX_PANEL_SOURCE="$ROOT_DIR/Sources/MacDog/Popover/CodexUsagePanel.swift"
GROK_PANEL_SOURCE="$ROOT_DIR/Sources/MacDog/Popover/GrokUsagePanel.swift"
DEMO_SOURCE="$ROOT_DIR/Sources/MacDog/MacDogDemoData.swift"
SELECTION_TEST="$ROOT_DIR/Tests/MacDogTests/UsageProviderSelectionTests.swift"
WORK_DIFF_TEST="$ROOT_DIR/Tests/MacDogTests/UsageProviderWorkDiffTests.swift"
GAUGES_TEST="$ROOT_DIR/Tests/MacDogTests/CombinedUsageGaugesTests.swift"
LABEL_TEST="$ROOT_DIR/Tests/MacDogTests/MenuBarWeeklyRemainingLabelTests.swift"
POPOVER_TEST="$ROOT_DIR/Tests/MacDogTests/PopoverScreenshotRendererTests.swift"
USER_COMPONENT_TEST="$ROOT_DIR/Tests/MacDogTests/UserComponentInstallerTests.swift"
STATE_TEST="$ROOT_DIR/Tests/MacDogTests/UsageMonitorStateTests.swift"
RUN_TESTS=1

usage() {
  cat <<USAGE
usage: $0 [--self-test] [--skip-tests]

Verify the v1.9.1 multi-provider selection contract.
This script does not read ~/.grok/auth.json, use live billing, run GUI apps,
install components, or push. It keeps the completed v1.9.0 verifier intact.
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
  for file in "$DOC" "$README" "$ROADMAP" "$AGENTS" "$ONBOARDING" "$SCRIPTS_DOC" \
    "$CHECK_SCRIPT" "$V190_VERIFIER" \
    "$SELECTION_SOURCE" "$PREFERENCES_SOURCE" "$WORK_DIFF_SOURCE" "$GAUGES_SOURCE" \
    "$LABEL_SOURCE" \
    "$CONTROLLER_SOURCE" "$POPOVER_SOURCE" "$SETTINGS_SOURCE" \
    "$CODEX_PANEL_SOURCE" "$GROK_PANEL_SOURCE" "$DEMO_SOURCE" \
    "$SELECTION_TEST" "$WORK_DIFF_TEST" "$GAUGES_TEST" "$LABEL_TEST" \
    "$POPOVER_TEST" "$USER_COMPONENT_TEST" "$STATE_TEST"; do
    require_file "$file"
  done
  [[ -x "$V190_VERIFIER" ]] || die "v1.9.0 selected-provider verifier is not executable"
  "$V190_VERIFIER" --self-test --skip-tests
  reject_match 'v1\.9\.1' "$V190_VERIFIER" "v1.9.0 verifier mentioning v1.9.1"

  require_match '복수 provider와 메인 provider' "$DOC" "v1.9.1 contract title"
  require_match '활성 provider는 최소 하나' "$DOC" "minimum enabled provider"
  require_match '메인 provider는 항상 활성' "$DOC" "main stays enabled"
  require_match '합산하거나 하나의 수치로 비교하지 않는다' "$DOC" "no summing"
  require_match 'provider 자동 failover' "$DOC" "no failover boundary"
  require_match '메뉴바 앱의 Grok auth store 접근' "$DOC" "menu bar auth boundary"
  require_match 'testUsagePopoverRendersSingleCodexMainDualGrokMainDualAndGraphHiddenStates' \
    "$DOC" "screenshot renderer completion"

  require_match '`1\.9\.0` 제품의 설정 visible mode는 `Codex`와 `Grok`' \
    "$README" "README published 1.9.0 visible modes"
  require_match '현재 GitHub Release는 \[v1\.9\.0\]' "$README" \
    "README published v1.9.0"
  require_match 'MacDog-1\.9\.0\.dmg' "$README" "README current installer"
  require_match 'b7072003830798bb1603768c4efb0b41409100f6' "$README" \
    "README published release head"
  require_match 'v1\.9\.1 개발' "$README" "README development line"
  reject_match '현재 GitHub Release는 \[v1\.9\.1\]' "$README" \
    "unpublished 1.9.1 claimed as current GitHub Release"
  reject_match 'MacDog-1\.9\.1\.dmg' "$README" "unpublished 1.9.1 installer"

  require_match 'Codex/Grok 복수 활성화와 메인 provider UI' "$ROADMAP" \
    "ROADMAP v1.9.1 section"
  require_match 'verify_v191_multi_provider_contract\.sh --self-test' "$ROADMAP" \
    "ROADMAP v1.9.1 verifier"
  require_match 'UI 확인 미수행' "$ROADMAP" "honest UI status"

  require_match 'macdog-grok-usage' "$AGENTS" "AGENTS Grok writer"
  require_match 'usageEnabledProviderMask' "$DOC" "mask preference key"
  require_match 'usageDetailGraphVisible' "$DOC" "graph visibility key"

  require_match '설정 visible mode는' "$ONBOARDING" "onboarding visible mode"
  require_match 'Codex` 또는 `Grok' "$ONBOARDING" "onboarding Codex/Grok selection"
  require_match 'v1\.9\.1 selection' "$ONBOARDING" "onboarding v1.9.1 selection"

  require_match 'verify_v191_multi_provider_contract\.sh --self-test' \
    "$SCRIPTS_DOC" "Scripts.md v1.9.1 verifier"
  require_match 'verify_v191_multi_provider_contract\.sh --self-test' \
    "$CHECK_SCRIPT" "check.sh v1.9.1 gate"

  require_match 'usageEnabledProviderMask' "$PREFERENCES_SOURCE" "mask preference key"
  require_match 'usageDetailGraphVisible' "$PREFERENCES_SOURCE" "graph visibility preference key"
  require_match 'struct UsageProviderSelection' "$SELECTION_SOURCE" "selection model"
  require_match 'detailGraphVisible' "$SELECTION_SOURCE" "graph visibility field"
  require_match 'struct UsageProviderWorkDiff' "$WORK_DIFF_SOURCE" "work diff model"
  require_match 'synchronizeCacheAgents' "$WORK_DIFF_SOURCE" "LaunchAgent diff"
  require_match 'cancelCodexRefresh' "$WORK_DIFF_SOURCE" "Codex task diff"
  require_match 'cancelGrokRefresh' "$WORK_DIFF_SOURCE" "Grok task diff"
  require_match 'UsageProviderWorkDiff.make' "$CONTROLLER_SOURCE" "controller uses work diff"
  require_match 'CombinedUsageGaugesView' "$POPOVER_SOURCE" "pinned combined gauges"
  require_match 'pinsCombinedUsageGauges' "$POPOVER_SOURCE" "gauges stay above scroll"
  require_match 'struct MenuBarWeeklyRemainingLabel' "$LABEL_SOURCE" "menu bar weekly remaining label"
  require_match 'NSStatusItem.variableLength' "$CONTROLLER_SOURCE" "variable status item length"
  require_match 'MenuBarWeeklyRemainingLabel.make' "$CONTROLLER_SOURCE" "status item uses weekly remaining"
  require_match 'showsMainWeeklyGraph' "$CODEX_PANEL_SOURCE" "Codex graph gate"
  require_match 'showsWeeklyGraph' "$GROK_PANEL_SOURCE" "Grok graph gate"
  require_match 'selection: UsageProviderSelection' "$DEMO_SOURCE" \
    "demo state from selection"
  require_match '활성 provider' "$SETTINGS_SOURCE" "settings enabled provider checkboxes"
  require_match 'Picker\("메인 provider"' "$SETTINGS_SOURCE" "settings main picker"
  require_match '상세 그래프 표시' "$SETTINGS_SOURCE" "settings graph checkbox"
  require_match '메뉴바에 주간 잔여율 표시' "$SETTINGS_SOURCE" "settings menu bar remaining toggle"
  require_match 'usageMenuBarWeeklyRemainingVisible' "$PREFERENCES_SOURCE" "menu bar remaining preference"
  require_match 'isOnlyEnabled' "$SETTINGS_SOURCE" "last provider stays enabled"
  require_match 'setUsageProviderSelection' "$SETTINGS_SOURCE" "settings persist selection"
  require_match 'Claude debug 사용 중' "$SETTINGS_SOURCE" "Claude stays off visible checkboxes"
  reject_match 'Picker\("사용량 mode"' "$SETTINGS_SOURCE" "legacy exclusive mode picker"

  reject_match 'Picker\("사용량 provider"' "$POPOVER_SOURCE" "usage provider sub-tab picker"
  reject_match '\.pickerStyle\(\.segmented\)' "$POPOVER_SOURCE" "segmented provider tabs"
  reject_match 'TabView' "$POPOVER_SOURCE" "SwiftUI TabView provider tabs"
  reject_match 'usedPercent \+ ' "$GAUGES_SOURCE" "summed used percent"
  reject_match 'remainingPercent \+ ' "$GAUGES_SOURCE" "summed remaining percent"
  reject_match 'average|평균' "$GAUGES_SOURCE" "averaged provider usage"
  reject_match 'GrokLocalAuthTokenProvider' "$CONTROLLER_SOURCE" "menu bar Grok auth"
  reject_match '~/\.grok/auth\.json' "$CONTROLLER_SOURCE" "menu bar grok auth path"
  reject_match '~/\.grok/auth\.json' "$POPOVER_SOURCE" "popover grok auth path"
  reject_match '~/\.grok/auth\.json' "$SETTINGS_SOURCE" "settings grok auth path"
  reject_match 'XAI_API_KEY' "$CONTROLLER_SOURCE" "menu bar API key"

  require_match 'testDisablingCodexCancelsOnlyCodexRefreshAndSyncsAgents' \
    "$WORK_DIFF_TEST" "Codex disable keeps Grok task"
  require_match 'testDisablingGrokCancelsOnlyGrokRefreshAndKeepsCodexTask' \
    "$WORK_DIFF_TEST" "Grok disable keeps Codex task"
  require_match 'testSwitchingMainWhileBothEnabledCancelsNotificationsWithoutTouchingRefresh' \
    "$WORK_DIFF_TEST" "main switch keeps both refresh tasks"
  require_match 'testGraphVisibilityOnlyDoesNotCancelWorkOrSyncAgents' \
    "$WORK_DIFF_TEST" "graph toggle does not cancel work"
  require_match 'testDualCodexMainShowsCodexWindowsThenGrokWeekly' \
    "$GAUGES_TEST" "Codex-main dual gauges"
  require_match 'testDualGrokMainShowsGrokWeeklyThenCodexWeeklyWithoutFiveHour' \
    "$GAUGES_TEST" "Grok-main dual gauges"
  require_match 'testCombinedGaugesStayWhenDetailGraphIsHidden' \
    "$GAUGES_TEST" "hidden graph keeps gauges"
  require_match 'testCodexMainShowsWeeklyRemainingIgnoringFiveHour' \
    "$LABEL_TEST" "menu bar uses weekly remaining not five-hour"
  require_match 'testDualGrokMainIgnoresAuxiliaryCodexWeekly' \
    "$LABEL_TEST" "menu bar ignores auxiliary weekly"
  require_match 'testMissingWeeklyHidesLabelWithoutSynthesis' \
    "$LABEL_TEST" "menu bar hides missing weekly"
  require_match 'testHiddenPreferenceHidesLabelWhenWeeklyIsReady' \
    "$LABEL_TEST" "menu bar remaining toggle hides label"
  require_match 'testMenuBarWeeklyRemainingPreferenceDefaultsOnAndCanBeTurnedOff' \
    "$LABEL_TEST" "menu bar remaining defaults on"
  require_match 'testEnabledProviderSetInstallsMatchingCacheAgentsIndependently' \
    "$USER_COMPONENT_TEST" "independent writer install"
  require_match 'testSelectedUsageSourcePolicyLoadsBothVisibleCachesWithoutFallback' \
    "$STATE_TEST" "no cache fallback"
  require_match 'testUsagePopoverRendersSingleCodexMainDualGrokMainDualAndGraphHiddenStates' \
    "$POPOVER_TEST" "screenshot renderer states"
  require_match 'UsageProviderWorkDiff.make' "$POPOVER_TEST" "screenshot controller guard"
  require_match 'testSettingsPanelRendersVisibleProviderCheckboxesWithoutSubTabs' \
    "$POPOVER_TEST" "settings checkbox renderer"
  require_match 'testOnlyEnabledProviderCannotBeTurnedOffAndMainPickerShowsForDual' \
    "$SELECTION_TEST" "last checkbox disable rejected"
}

run_focused_tests() {
  DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}" \
  CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-/private/tmp/macdog-clang-module-cache}" \
    /usr/bin/xcrun swift test \
      --filter UsageProviderSelectionTests \
      --filter UsageProviderWorkDiffTests \
      --filter CombinedUsageGaugesTests \
      --filter MenuBarWeeklyRemainingLabelTests \
      --filter UserComponentInstallerTests \
      --filter UsageMonitorStateTests \
      --filter UsageNotificationDeliveryTests \
      --filter CodexUsageCacheRefreshPolicyTests \
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

verify_contract
if [[ "$RUN_TESTS" == "1" ]]; then
  run_focused_tests
fi
echo "v1.9.1 multi-provider contract ok"
