#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

require_file() {
  [[ -f "$1" ]] || {
    echo "missing required file: $1" >&2
    exit 1
  }
}

require_text() {
  local pattern="$1"
  local file="$2"
  local label="$3"
  if ! /usr/bin/grep -Eq "$pattern" "$file"; then
    echo "missing $label in $file" >&2
    exit 1
  fi
}

reject_text() {
  local pattern="$1"
  local file="$2"
  local label="$3"
  if /usr/bin/grep -Eq "$pattern" "$file"; then
    echo "unexpected $label in $file" >&2
    exit 1
  fi
}

run_swift_test() {
  CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-/private/tmp/macdog-clang-module-cache}" \
  DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}" \
    /usr/bin/xcrun swift test "$@"
}

if [[ "$#" -ne 1 || "${1:-}" != "--self-test" ]]; then
  echo "usage: $0 --self-test" >&2
  exit 2
fi

require_file "Docs/V160CodexRecoveryPlanner.md"
require_file "Docs/V160ReleaseReadiness.md"
require_file "Sources/CodexUsageCore/Models/RateLimitModels.swift"
require_file "Sources/CodexUsageCore/Usage/CodexLocalAuthTokenProvider.swift"
require_file "Sources/CodexUsageCore/Usage/CodexResetCreditDetailsClient.swift"
require_file "Sources/CodexUsageCore/Usage/CodexUsageReport.swift"
require_file "Sources/CodexUsageCore/Usage/CodexUsageFormatter.swift"
require_file "Sources/MacDog/Popover/CodexResetCreditsViews.swift"
require_file "Sources/MacDog/Popover/CodexUsagePanel.swift"
require_file "Tests/CodexUsageCoreTests/CodexLocalAuthTokenProviderTests.swift"
require_file "Tests/CodexUsageCoreTests/CodexResetCreditDetailsClientTests.swift"
require_file "Tests/CodexUsageCoreTests/RateLimitModelsTests.swift"
require_file "Tests/CodexUsageCoreTests/CodexUsageReportTests.swift"
require_file "Tests/MacDogTests/UsageMonitorStateTests.swift"
require_file "Tests/MacDogTests/PopoverScreenshotRendererTests.swift"
require_file "Tests/MacDogTests/UsageNotificationDeliveryTests.swift"
require_file "Tests/MacDogTests/UsageNotificationSettingsTests.swift"

require_text 'status --json.*breaking change' "Docs/V160CodexRecoveryPlanner.md" "JSON boundary"
require_text 'Dashboard 탭' "Docs/V160CodexRecoveryPlanner.md" "Dashboard exclusion"
require_text 'auth token|session material' "Docs/V160CodexRecoveryPlanner.md" "auth redaction boundary"
require_text '초기화권' "Docs/V160CodexRecoveryPlanner.md" "reset credit scope"
require_text 'credits\[\]\.expires_at' "Docs/V160CodexRecoveryPlanner.md" "reset credit expiry source"
require_text 'expiresAt.*status.*resetType' "Docs/V160CodexRecoveryPlanner.md" "sanitized reset credit cache fields"
require_text 'RateLimitResetCreditsSummary' "Sources/CodexUsageCore/Models/RateLimitModels.swift" "reset credit model"
require_text 'rateLimitResetCredits' "Sources/CodexUsageCore/Models/RateLimitModels.swift" "app-server reset credit field"
require_text 'CodexLocalAuthTokenProvider' "Sources/CodexUsageCore/Usage/CodexLocalAuthTokenProvider.swift" "local auth fallback"
require_text 'rate-limit-reset-credits' "Sources/CodexUsageCore/Usage/CodexResetCreditDetailsClient.swift" "backend reset credit detail endpoint"
require_text 'resetCredits' "Sources/CodexUsageCore/Usage/CodexUsageReport.swift" "usage report reset credits"
require_text 'Reset credits:' "Sources/CodexUsageCore/Usage/CodexUsageFormatter.swift" "CLI reset credit text"
require_text 'CodexResetCreditsBlock' "Sources/MacDog/Popover/CodexResetCreditsViews.swift" "reset credit UI"
require_text 'WeeklyRemainingHistoryBlock' "Sources/MacDog/Popover/CodexUsagePanel.swift" "history graph retained in Codex tab"
require_text 'graphActionButtons\(mode: mode' "Sources/MacDog/Popover/WeeklyRemainingHistoryViews.swift" "history graph copy/export actions"
require_text 'selectedPastWindowIDBinding' "Sources/MacDog/Popover/WeeklyRemainingHistoryViews.swift" "history past window picker"
require_text 'func json\(from report: CodexUsageReport\)' "Sources/CodexUsageCore/Usage/CodexUsageFormatter.swift" "formatter JSON entrypoint"
require_text 'testWeeklyHistoryBlockExposesModePickerAndWiresGraphActions' "Tests/MacDogTests/PopoverScreenshotRendererTests.swift" "history controls regression test"
require_text 'testCodexUsagePanelKeepsPrimarySectionsVisibleWithoutDisclosure' "Tests/MacDogTests/PopoverScreenshotRendererTests.swift" "Codex panel section regression test"

reject_text 'CodexUsageResetSchedule|CodexUsageSessionPlan|CodexRecoveryPlannerBlock' "Sources/MacDog/Popover/CodexUsagePanel.swift" "recovery/session planner UI"
reject_text 'Recovery cards:' "Sources/CodexUsageCore/Usage/CodexUsageFormatter.swift" "CLI recovery card text"

echo "==> Running v1.6 focused Swift tests"
run_swift_test --filter RateLimitModelsTests
run_swift_test --filter CodexAppServerRequestFactoryTests
run_swift_test --filter CodexLocalAuthTokenProviderTests
run_swift_test --filter CodexResetCreditDetailsClientTests
run_swift_test --filter CodexUsageReportTests
run_swift_test --filter UsageMonitorStateTests
run_swift_test --filter UsageNotificationPolicyTests
run_swift_test --filter UsageNotificationDeliveryTests
run_swift_test --filter UsageNotificationSettingsTests
run_swift_test --filter PetMenuModelTests
run_swift_test --filter PopoverScreenshotRendererTests
echo "v1.6 codex usage and reset credits contract ok"
