#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-report}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="MacDog"
DIST_APP="$ROOT_DIR/dist/$APP_NAME.app"
APP_DEST="$HOME/Applications/$APP_NAME.app"
APP_BINARY="$APP_DEST/Contents/MacOS/$APP_NAME"
WIDGET_APPEX="$APP_DEST/Contents/PlugIns/MacDogWidgetExtension.appex"
WIDGET_BINARY="$WIDGET_APPEX/Contents/MacOS/MacDogWidgetExtension"
CLI_DEST="$HOME/bin/codex-usage"
CACHE_PLIST="$HOME/Library/LaunchAgents/com.dhseo.macdog.usage-cache.plist"
MONITOR_PLIST="$HOME/Library/LaunchAgents/com.dhseo.macdog.monitor.plist"

case "$MODE" in
  report|--report) ;;
  --expect-installed|expect-installed) ;;
  --expect-uninstalled|expect-uninstalled) ;;
  --expect-current-dist|expect-current-dist) ;;
  -h|--help|help)
    echo "usage: $0 [--report|--expect-installed|--expect-uninstalled|--expect-current-dist]"
    exit 0
    ;;
  *)
    echo "usage: $0 [--report|--expect-installed|--expect-uninstalled|--expect-current-dist]" >&2
    exit 2
    ;;
esac

present() {
  [[ -e "$1" ]]
}

executable() {
  [[ -x "$1" ]]
}

bundle_manifest() {
  local bundle="$1"
  (
    cd "$bundle"
    /usr/bin/find . -type f \
      ! -path '*/_CodeSignature/*' \
      ! -name '.DS_Store' \
      -print0 |
      while IFS= read -r -d '' file; do
        local path="${file#./}"
        local hash
        hash="$(/usr/bin/shasum -a 256 "$file" | /usr/bin/awk '{print $1}')"
        printf '%s  %s\n' "$hash" "$path"
      done |
      /usr/bin/sort
  )
}

compare_app_bundles() {
  local expected="$1"
  local actual="$2"
  local label="$3"
  local verbosity="${4:-verbose}"

  [[ -d "$expected" ]] || { echo "$label:missing-source $expected" >&2; return 1; }
  [[ -d "$actual" ]] || { echo "$label:missing-installed $actual" >&2; return 1; }

  local expected_manifest
  local actual_manifest
  expected_manifest="$(/usr/bin/mktemp "${TMPDIR:-/tmp}/macdog-expected.XXXXXX")"
  actual_manifest="$(/usr/bin/mktemp "${TMPDIR:-/tmp}/macdog-actual.XXXXXX")"
  bundle_manifest "$expected" >"$expected_manifest"
  bundle_manifest "$actual" >"$actual_manifest"

  if /usr/bin/cmp -s "$expected_manifest" "$actual_manifest"; then
    rm -f "$expected_manifest" "$actual_manifest"
    [[ "$verbosity" == "quiet" ]] || echo "$label:matches-dist $actual"
    return 0
  fi

  if [[ "$verbosity" != "quiet" ]]; then
    echo "$label:differs-from-dist expected:$expected actual:$actual" >&2
    /usr/bin/diff -u "$expected_manifest" "$actual_manifest" | /usr/bin/sed -n '1,80p' >&2 || true
  fi
  rm -f "$expected_manifest" "$actual_manifest"
  return 1
}

print_process_state() {
  local output
  local status
  output="$(pgrep -x "$APP_NAME" 2>&1)" || status=$?
  status="${status:-0}"

  if [[ "$status" == "0" ]]; then
    local count
    count="$(printf '%s\n' "$output" | /usr/bin/grep -Ec '^[0-9]+$' || true)"
    echo "process:running $APP_NAME count:$count"
    while IFS= read -r pid; do
      [[ "$pid" =~ ^[0-9]+$ ]] || continue
      local command_path
      command_path="$(/bin/ps -p "$pid" -o comm= 2>/dev/null | /usr/bin/sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
      if [[ -z "$command_path" ]]; then
        echo "process-path:$pid unknown"
      else
        echo "process-path:$pid $command_path"
        if [[ "$command_path" == "$APP_BINARY" ]]; then
          echo "process-freshness:$pid installed-app-binary"
        else
          echo "process-freshness:$pid different-binary expected:$APP_BINARY actual:$command_path"
        fi
      fi
    done <<<"$output"
  elif [[ "$status" == "1" ]]; then
    echo "process:not-running $APP_NAME"
  else
    echo "process:unknown $APP_NAME ($output)"
  fi
}

expect_running_process_current_if_known() {
  local output
  local status
  output="$(pgrep -x "$APP_NAME" 2>&1)" || status=$?
  status="${status:-0}"

  [[ "$status" == "0" ]] || return 0

  while IFS= read -r pid; do
    [[ "$pid" =~ ^[0-9]+$ ]] || continue
    local command_path
    command_path="$(/bin/ps -p "$pid" -o comm= 2>/dev/null | /usr/bin/sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [[ -n "$command_path" ]] || continue
    [[ "$command_path" == "$APP_BINARY" ]] || {
      echo "running MacDog process uses a different binary: pid=$pid expected:$APP_BINARY actual:$command_path" >&2
      return 1
    }
  done <<<"$output"
}

print_state() {
  if present "$APP_DEST"; then echo "app:present $APP_DEST"; else echo "app:absent $APP_DEST"; fi
  if executable "$APP_BINARY"; then echo "app-binary:executable $APP_BINARY"; else echo "app-binary:missing-or-not-executable $APP_BINARY"; fi
  if present "$WIDGET_APPEX"; then echo "widget-appex:present $WIDGET_APPEX"; else echo "widget-appex:absent $WIDGET_APPEX"; fi
  if executable "$WIDGET_BINARY"; then echo "widget-binary:executable $WIDGET_BINARY"; else echo "widget-binary:missing-or-not-executable $WIDGET_BINARY"; fi
  if executable "$CLI_DEST"; then echo "cli:executable $CLI_DEST"; else echo "cli:missing-or-not-executable $CLI_DEST"; fi
  if present "$CACHE_PLIST"; then echo "cache-plist:present $CACHE_PLIST"; else echo "cache-plist:absent $CACHE_PLIST"; fi
  if present "$MONITOR_PLIST"; then echo "monitor-plist:present $MONITOR_PLIST"; else echo "monitor-plist:absent $MONITOR_PLIST"; fi
  if [[ -d "$DIST_APP" && -d "$APP_DEST" ]]; then
    if compare_app_bundles "$DIST_APP" "$APP_DEST" "app-freshness" quiet; then
      echo "app-freshness:matches-dist $APP_DEST"
    else
      echo "app-freshness:differs-from-dist expected:$DIST_APP actual:$APP_DEST"
    fi
  elif [[ -d "$DIST_APP" ]]; then
    echo "app-freshness:installed-app-missing $APP_DEST"
  else
    echo "app-freshness:dist-app-missing $DIST_APP"
  fi
  print_process_state
}

expect_installed() {
  executable "$APP_BINARY" || { echo "expected installed app binary: $APP_BINARY" >&2; return 1; }
  executable "$CLI_DEST" || { echo "expected installed CLI: $CLI_DEST" >&2; return 1; }
  present "$WIDGET_APPEX" || { echo "expected installed widget extension: $WIDGET_APPEX" >&2; return 1; }
  executable "$WIDGET_BINARY" || { echo "expected installed widget binary: $WIDGET_BINARY" >&2; return 1; }
  present "$CACHE_PLIST" || { echo "expected cache LaunchAgent plist: $CACHE_PLIST" >&2; return 1; }
  present "$MONITOR_PLIST" || { echo "expected monitor LaunchAgent plist: $MONITOR_PLIST" >&2; return 1; }
}

expect_uninstalled() {
  ! present "$APP_DEST" || { echo "expected app to be absent: $APP_DEST" >&2; return 1; }
  ! present "$CLI_DEST" || { echo "expected CLI to be absent: $CLI_DEST" >&2; return 1; }
  ! present "$WIDGET_APPEX" || { echo "expected widget extension to be absent: $WIDGET_APPEX" >&2; return 1; }
  ! present "$CACHE_PLIST" || { echo "expected cache plist to be absent: $CACHE_PLIST" >&2; return 1; }
  ! present "$MONITOR_PLIST" || { echo "expected monitor plist to be absent: $MONITOR_PLIST" >&2; return 1; }
}

expect_current_dist() {
  expect_installed
  compare_app_bundles "$DIST_APP" "$APP_DEST" "app-freshness"
  expect_running_process_current_if_known
}

print_state
case "$MODE" in
  --expect-installed|expect-installed)
    expect_installed
    echo "Install state ok: installed"
    ;;
  --expect-uninstalled|expect-uninstalled)
    expect_uninstalled
    echo "Install state ok: uninstalled"
    ;;
  --expect-current-dist|expect-current-dist)
    expect_current_dist
    echo "Install state ok: current-dist"
    ;;
esac
