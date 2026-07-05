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

if [[ "${1:-}" != "--self-test" ]]; then
  echo "usage: $0 --self-test" >&2
  exit 2
fi

require_file "Docs/V160CodexRecoveryPlanner.md"
require_file "Docs/V160ReleaseReadiness.md"
require_file "Sources/CodexUsageCore/Usage/CodexUsageResetSchedule.swift"
require_file "Sources/CodexUsageCore/Usage/CodexUsageSessionPlan.swift"
require_file "Sources/MacDog/Popover/CodexRecoveryPlannerViews.swift"
require_file "Tests/CodexUsageCoreTests/CodexUsageResetScheduleTests.swift"
require_file "Tests/CodexUsageCoreTests/CodexUsageSessionPlanTests.swift"

require_text 'status --json.*breaking change' "Docs/V160CodexRecoveryPlanner.md" "JSON boundary"
require_text 'Dashboard 탭' "Docs/V160CodexRecoveryPlanner.md" "Dashboard exclusion"
require_text 'auth token|session material' "Docs/V160CodexRecoveryPlanner.md" "auth redaction boundary"
require_text 'CodexUsageResetSchedule' "Sources/CodexUsageCore/Usage/CodexUsageResetSchedule.swift" "reset schedule model"
require_text 'CodexUsageSessionPlan' "Sources/CodexUsageCore/Usage/CodexUsageSessionPlan.swift" "session plan model"
require_text 'status --json' "Sources/CodexUsageCore/Usage/CodexUsageFormatter.swift" "formatter JSON boundary note"

echo "v1.6 recovery planner contract ok"
