#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CACHE_SOURCE="$ROOT_DIR/Sources/CodexUsageCore/Cache/CodexUsageCache.swift"
APPSERVER_SOURCE="$ROOT_DIR/Sources/CodexUsageCore/AppServer/CodexAppServerClient.swift"
CLI_SOURCE="$ROOT_DIR/Sources/CodexUsageCLI/main.swift"
CACHE_TESTS="$ROOT_DIR/Tests/CodexUsageCoreTests/CodexUsageCacheTests.swift"
APPSERVER_TESTS="$ROOT_DIR/Tests/CodexUsageCoreTests/CodexAppServerClientTests.swift"
WIDGET_TESTS="$ROOT_DIR/Tests/CodexUsageCoreTests/MacDogWidgetPresentationTests.swift"
DEFAULT_CACHE="$HOME/Library/Application Support/MacDog/usage.json"
SENSITIVE_PATTERN='access_token|refresh_token|session_id|authorization|cookie'

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
require_match 'cacheAgentRefreshIntervalSeconds = 60' "$CACHE_SOURCE"
require_match 'defaultWorkingDirectoryURL = URL\(fileURLWithPath: "/tmp"' "$APPSERVER_SOURCE"
require_match 'process\.currentDirectoryURL = workingDirectoryURL' "$APPSERVER_SOURCE"
require_match '"--timeout"' "$CLI_SOURCE"
require_match 'CodexAppServerClient\(timeout: timeout \?\? 15\)' "$CLI_SOURCE"
require_match 'DefaultWorkingDirectoryUsesTemporaryDirectory' "$APPSERVER_TESTS"
require_match 'schemaVersion' "$CACHE_TESTS"
require_match 'DefaultSharedFileURLUsesStableAppGroupFallback' "$CACHE_TESTS"
require_match 'DefaultMirroredFileURLsIncludeDefaultAndSharedCachePaths' "$CACHE_TESTS"
require_match 'writeFailure' "$CACHE_TESTS"
require_match 'redactedErrorMessage' "$CACHE_SOURCE"
require_match 'RedactsSensitiveSessionMaterial' "$CACHE_TESTS"
require_match 'isStale' "$CACHE_TESTS"
require_match '오래된 캐시|캐시 없음|갱신됨' "$WIDGET_TESTS"

if [[ -f "$DEFAULT_CACHE" ]]; then
  /usr/bin/ruby -rjson -e 'JSON.parse(File.read(ARGV.fetch(0)))' "$DEFAULT_CACHE" >/dev/null
  if /usr/bin/grep -Eiq "$SENSITIVE_PATTERN" "$DEFAULT_CACHE"; then
    die "sensitive cache/session material pattern found in $DEFAULT_CACHE"
  fi
fi

echo "Cache contract verification ok"
