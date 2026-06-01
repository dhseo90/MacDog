#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CACHE_SOURCE="$ROOT_DIR/Sources/CodexUsageCore/Cache/CodexUsageCache.swift"
HISTORY_SOURCE="$ROOT_DIR/Sources/CodexUsageCore/Cache/CodexUsageWeeklyHistory.swift"
APPSERVER_SOURCE="$ROOT_DIR/Sources/CodexUsageCore/AppServer/CodexAppServerClient.swift"
CLI_SOURCE="$ROOT_DIR/Sources/CodexUsageCLI/main.swift"
CACHE_TESTS="$ROOT_DIR/Tests/CodexUsageCoreTests/CodexUsageCacheTests.swift"
APPSERVER_TESTS="$ROOT_DIR/Tests/CodexUsageCoreTests/CodexAppServerClientTests.swift"
WIDGET_TESTS="$ROOT_DIR/Tests/CodexUsageCoreTests/MacDogWidgetPresentationTests.swift"
DEFAULT_CACHE="$HOME/Library/Application Support/MacDog/usage.json"
DEFAULT_HISTORY="$HOME/Library/Application Support/MacDog/usage-weekly-history.json"
SENSITIVE_PATTERN='access[_-]?token|refresh[_-]?token|session[_-]?id|id[_-]?token|auth[_-]?token|api[_-]?key|client[_-]?secret|authorization|cookie'

die() {
  echo "error: $*" >&2
  exit 1
}

require_match() {
  local pattern="$1"
  local path="$2"
  /usr/bin/grep -Eq "$pattern" "$path" || die "missing expected cache contract pattern '$pattern' in $path"
}

require_match 'currentSchemaVersion = 1' "$CACHE_SOURCE"
require_match 'defaultAppGroupIdentifier = "group\.com\.dhseo\.macdog\.MacDog"' "$CACHE_SOURCE"
require_match 'defaultSharedFileURL' "$CACHE_SOURCE"
require_match 'defaultMirroredFileURLs' "$CACHE_SOURCE"
require_match 'defaultApplicationSupportDirectoryURL' "$CACHE_SOURCE"
require_match 'cacheAgentRefreshIntervalSeconds = 60' "$CACHE_SOURCE"
require_match 'usage-weekly-history\.json' "$HISTORY_SOURCE"
require_match 'minimumSampleIntervalSeconds = 5 \* 60' "$HISTORY_SOURCE"
require_match 'minimumRemainingPercentDelta = 0\.25' "$HISTORY_SOURCE"
require_match 'defaultRetentionSeconds = 8 \* 24 \* 60 \* 60' "$HISTORY_SOURCE"
require_match 'CodexUsageWeeklyHistorySample\(report:' "$CACHE_SOURCE"
require_match 'defaultWorkingDirectoryURL = URL\(fileURLWithPath: "/tmp"' "$APPSERVER_SOURCE"
require_match 'process\.currentDirectoryURL = workingDirectoryURL' "$APPSERVER_SOURCE"
require_match '"--timeout"' "$CLI_SOURCE"
require_match 'CodexAppServerClient\(timeout: timeout \?\? 15\)' "$CLI_SOURCE"
require_match 'DefaultWorkingDirectoryUsesTemporaryDirectory' "$APPSERVER_TESTS"
require_match 'schemaVersion' "$CACHE_TESTS"
require_match 'DefaultSharedFileURLUsesStableAppGroupFallback' "$CACHE_TESTS"
require_match 'DefaultMirroredFileURLsIncludeDefaultAndAvailableSharedCachePaths' "$CACHE_TESTS"
require_match 'writeFailure' "$CACHE_TESTS"
require_match 'redactedErrorMessage' "$CACHE_SOURCE"
require_match 'RedactsSensitiveSessionMaterial' "$CACHE_TESTS"
require_match 'accessToken|refreshToken|sessionId|apiKey|clientSecret|Authorization: Basic|Cookie:' "$CACHE_TESTS"
require_match 'isStale' "$CACHE_TESTS"
require_match 'WriteSuccessAppendsWeeklyHistoryNextToCacheFile' "$CACHE_TESTS"
require_match 'WeeklyHistorySkipsDenseUnchangedSamples' "$CACHE_TESTS"
require_match '오래된 캐시|캐시 없음|갱신됨' "$WIDGET_TESTS"

if [[ -f "$DEFAULT_CACHE" ]]; then
  /usr/bin/ruby -rjson -e 'JSON.parse(File.read(ARGV.fetch(0)))' "$DEFAULT_CACHE" >/dev/null
  if /usr/bin/grep -Eiq "$SENSITIVE_PATTERN" "$DEFAULT_CACHE"; then
    die "sensitive cache/session material pattern found in $DEFAULT_CACHE"
  fi
fi

if [[ -f "$DEFAULT_HISTORY" ]]; then
  /usr/bin/ruby -rjson -e 'JSON.parse(File.read(ARGV.fetch(0)))' "$DEFAULT_HISTORY" >/dev/null
  if /usr/bin/grep -Eiq "$SENSITIVE_PATTERN" "$DEFAULT_HISTORY"; then
    die "sensitive cache/session material pattern found in $DEFAULT_HISTORY"
  fi
fi

echo "Cache contract verification ok"
