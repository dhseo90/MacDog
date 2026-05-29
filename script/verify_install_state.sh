#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-report}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="MacDog"
BUNDLE_ID="com.dhseo.macdog.MacDog"
DIST_APP="$ROOT_DIR/dist/$APP_NAME.app"
USER_APP_DEST="$HOME/Applications/$APP_NAME.app"
SYSTEM_APP_DEST="/Applications/$APP_NAME.app"
CLI_DEST="$HOME/bin/codex-usage"
CACHE_PLIST="$HOME/Library/LaunchAgents/com.dhseo.macdog.usage-cache.plist"
MONITOR_PLIST="$HOME/Library/LaunchAgents/com.dhseo.macdog.monitor.plist"
LOGIN_LAUNCH_KEY="loginLaunchEnabled"

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

plist_value() {
  /usr/libexec/PlistBuddy -c "Print $1" "$2"
}

installed_app_dest() {
  if present "$SYSTEM_APP_DEST"; then
    printf '%s' "$SYSTEM_APP_DEST"
    return 0
  fi
  if present "$USER_APP_DEST"; then
    printf '%s' "$USER_APP_DEST"
    return 0
  fi
  printf '%s' "$USER_APP_DEST"
}

app_binary_for() {
  printf '%s/Contents/MacOS/%s' "$1" "$APP_NAME"
}

app_cli_binary_for() {
  printf '%s/Contents/MacOS/codex-usage' "$1"
}

widget_appex_for() {
  printf '%s/Contents/PlugIns/MacDogWidgetExtension.appex' "$1"
}

widget_binary_for() {
  printf '%s/Contents/PlugIns/MacDogWidgetExtension.appex/Contents/MacOS/MacDogWidgetExtension' "$1"
}

installed_app_count() {
  local count=0
  present "$SYSTEM_APP_DEST" && count=$((count + 1))
  present "$USER_APP_DEST" && count=$((count + 1))
  printf '%s' "$count"
}

login_launch_enabled() {
  local value
  value="$(/usr/bin/defaults read "$BUNDLE_ID" "$LOGIN_LAUNCH_KEY" 2>/dev/null || true)"
  [[ -z "$value" || "$value" == "1" || "$value" == "true" || "$value" == "TRUE" || "$value" == "YES" ]]
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
  local app_dest
  local app_binary
  app_dest="$(installed_app_dest)"
  app_binary="$(app_binary_for "$app_dest")"
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
        if [[ "$command_path" == "$app_binary" ]]; then
          echo "process-freshness:$pid installed-app-binary"
        else
          echo "process-freshness:$pid different-binary expected:$app_binary actual:$command_path"
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
  local app_dest
  local app_binary
  app_dest="$(installed_app_dest)"
  app_binary="$(app_binary_for "$app_dest")"
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
    [[ "$command_path" == "$app_binary" ]] || {
      echo "running MacDog process uses a different binary: pid=$pid expected:$app_binary actual:$command_path" >&2
      return 1
    }
  done <<<"$output"
}

print_state() {
  local app_dest
  local app_binary
  local app_cli_binary
  local widget_appex
  local widget_binary
  app_dest="$(installed_app_dest)"
  app_binary="$(app_binary_for "$app_dest")"
  app_cli_binary="$(app_cli_binary_for "$app_dest")"
  widget_appex="$(widget_appex_for "$app_dest")"
  widget_binary="$(widget_binary_for "$app_dest")"

  if present "$SYSTEM_APP_DEST"; then echo "system-app:present $SYSTEM_APP_DEST"; else echo "system-app:absent $SYSTEM_APP_DEST"; fi
  if present "$USER_APP_DEST"; then echo "user-app:present $USER_APP_DEST"; else echo "user-app:absent $USER_APP_DEST"; fi
  echo "active-app:$app_dest"
  if executable "$app_binary"; then echo "app-binary:executable $app_binary"; else echo "app-binary:missing-or-not-executable $app_binary"; fi
  if executable "$app_cli_binary"; then echo "app-cli:executable $app_cli_binary"; else echo "app-cli:missing-or-not-executable $app_cli_binary"; fi
  if present "$widget_appex"; then echo "widget-appex:present $widget_appex"; else echo "widget-appex:absent $widget_appex"; fi
  if executable "$widget_binary"; then echo "widget-binary:executable $widget_binary"; else echo "widget-binary:missing-or-not-executable $widget_binary"; fi
  if executable "$CLI_DEST"; then echo "cli:executable $CLI_DEST"; else echo "cli:missing-or-not-executable $CLI_DEST"; fi
  if [[ -L "$CLI_DEST" ]]; then echo "cli-link:$(/bin/ls -l "$CLI_DEST" | /usr/bin/sed 's/^.* -> //')"; fi
  if present "$CACHE_PLIST"; then echo "cache-plist:present $CACHE_PLIST"; else echo "cache-plist:absent $CACHE_PLIST"; fi
  if present "$CACHE_PLIST"; then echo "cache-executable:$(plist_value ':ProgramArguments:0' "$CACHE_PLIST")"; fi
  if login_launch_enabled; then echo "login-launch-enabled:true"; else echo "login-launch-enabled:false"; fi
  if present "$MONITOR_PLIST"; then echo "legacy-monitor-plist:present $MONITOR_PLIST"; else echo "legacy-monitor-plist:absent $MONITOR_PLIST"; fi
  if [[ -d "$DIST_APP" && -d "$app_dest" ]]; then
    if compare_app_bundles "$DIST_APP" "$app_dest" "app-freshness" quiet; then
      echo "app-freshness:matches-dist $app_dest"
    else
      echo "app-freshness:differs-from-dist expected:$DIST_APP actual:$app_dest"
    fi
  elif [[ -d "$DIST_APP" ]]; then
    echo "app-freshness:installed-app-missing $app_dest"
  else
    echo "app-freshness:dist-app-missing $DIST_APP"
  fi
  print_process_state
}

expect_installed() {
  local app_dest
  local app_binary
  local app_cli_binary
  local widget_appex
  local widget_binary
  app_dest="$(installed_app_dest)"
  app_binary="$(app_binary_for "$app_dest")"
  app_cli_binary="$(app_cli_binary_for "$app_dest")"
  widget_appex="$(widget_appex_for "$app_dest")"
  widget_binary="$(widget_binary_for "$app_dest")"

  [[ "$(installed_app_count)" == "1" ]] || {
    echo "expected exactly one MacDog app install; found system=$([[ -d "$SYSTEM_APP_DEST" ]] && echo present || echo absent) user=$([[ -d "$USER_APP_DEST" ]] && echo present || echo absent)" >&2
    return 1
  }
  executable "$app_binary" || { echo "expected installed app binary: $app_binary" >&2; return 1; }
  executable "$app_cli_binary" || { echo "expected bundled CLI: $app_cli_binary" >&2; return 1; }
  executable "$CLI_DEST" || { echo "expected installed CLI: $CLI_DEST" >&2; return 1; }
  [[ -L "$CLI_DEST" ]] || { echo "expected installed CLI to be a symlink: $CLI_DEST" >&2; return 1; }
  [[ "$(readlink "$CLI_DEST")" == "$app_cli_binary" ]] || {
    echo "expected CLI symlink to target bundled CLI: $CLI_DEST -> $app_cli_binary" >&2
    return 1
  }
  present "$widget_appex" || { echo "expected installed widget extension: $widget_appex" >&2; return 1; }
  executable "$widget_binary" || { echo "expected installed widget binary: $widget_binary" >&2; return 1; }
  present "$CACHE_PLIST" || { echo "expected cache LaunchAgent plist: $CACHE_PLIST" >&2; return 1; }
  [[ "$(plist_value ':ProgramArguments:0' "$CACHE_PLIST")" == "$app_cli_binary" ]] || {
    echo "expected cache LaunchAgent to run bundled CLI: $app_cli_binary" >&2
    return 1
  }
  ! present "$MONITOR_PLIST" || { echo "expected legacy monitor plist to be absent: $MONITOR_PLIST" >&2; return 1; }
}

expect_uninstalled() {
  ! present "$SYSTEM_APP_DEST" || { echo "expected app to be absent: $SYSTEM_APP_DEST" >&2; return 1; }
  ! present "$USER_APP_DEST" || { echo "expected app to be absent: $USER_APP_DEST" >&2; return 1; }
  ! present "$CLI_DEST" || { echo "expected CLI to be absent: $CLI_DEST" >&2; return 1; }
  ! present "$CACHE_PLIST" || { echo "expected cache plist to be absent: $CACHE_PLIST" >&2; return 1; }
  ! present "$MONITOR_PLIST" || { echo "expected legacy monitor plist to be absent: $MONITOR_PLIST" >&2; return 1; }
}

expect_current_dist() {
  local app_dest
  app_dest="$(installed_app_dest)"
  expect_installed
  compare_app_bundles "$DIST_APP" "$app_dest" "app-freshness"
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
