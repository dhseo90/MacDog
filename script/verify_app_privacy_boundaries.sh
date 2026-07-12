#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_SOURCE="$ROOT_DIR/Sources/MacDog"

die() {
  echo "error: $*" >&2
  exit 1
}

reject_text_match() {
  local pattern="$1"
  local path="$2"
  local message="$3"

  if /usr/bin/grep -R -E "$pattern" "$path" >/dev/null; then
    die "$message"
  fi
}

[[ -d "$APP_SOURCE" ]] || die "MacDog app source missing: $APP_SOURCE"

reject_text_match \
  'CodexAppServerClient|CodexUsageService|CodexCLIResolver|account/rateLimits/read|codex app-server' \
  "$APP_SOURCE" \
  "menu bar app must read Codex usage from cache instead of starting live app-server access"

reject_text_match \
  'CodexUsageCacheStore\.defaultSharedFileURL\(\)|CodexUsageCacheStore\.defaultFileURL\(appGroupIdentifier:' \
  "$APP_SOURCE" \
  "menu bar app must read its app-owned cache instead of touching Group Containers directly"

reject_text_match \
  'FileManager\.default\.currentDirectoryPath' \
  "$APP_SOURCE" \
  "menu bar app must not probe the launch working directory for resources"

reject_text_match \
  '/\.claude/|\.claude/settings\.json|transcript_path|ClaudeStatusLineSanitizer|statusLineData|account/chatgptAuthTokens' \
  "$APP_SOURCE" \
  "menu bar app must read only sanitized Claude cache and must not inspect Claude settings, transcripts, raw events, or auth"

/usr/bin/grep -Eq 'ClaudeUsageCacheStore' "$APP_SOURCE/MenuBarController.swift" \
  || die "menu bar app must load Claude usage from the dedicated sanitized cache"

echo "App privacy boundary verification ok"
