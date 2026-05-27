#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CACHE_SOURCE="$ROOT_DIR/Sources/CodexUsageCore/Cache/CodexUsageCache.swift"
CACHE_TESTS="$ROOT_DIR/Tests/CodexUsageCoreTests/CodexUsageCacheTests.swift"
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
require_match 'cacheAgentRefreshIntervalSeconds = 300' "$CACHE_SOURCE"
require_match 'schemaVersion' "$CACHE_TESTS"
require_match 'writeFailure' "$CACHE_TESTS"
require_match 'isStale' "$CACHE_TESTS"
require_match 'stale cache|no cache|updated' "$WIDGET_TESTS"

if /usr/bin/grep -Eiq "$SENSITIVE_PATTERN" "$CACHE_SOURCE" "$CACHE_TESTS" "$WIDGET_TESTS"; then
  die "sensitive cache/session material pattern found in cache contract files"
fi

if [[ -f "$DEFAULT_CACHE" ]]; then
  /usr/bin/ruby -rjson -e 'JSON.parse(File.read(ARGV.fetch(0)))' "$DEFAULT_CACHE" >/dev/null
  if /usr/bin/grep -Eiq "$SENSITIVE_PATTERN" "$DEFAULT_CACHE"; then
    die "sensitive cache/session material pattern found in $DEFAULT_CACHE"
  fi
fi

echo "Cache contract verification ok"
