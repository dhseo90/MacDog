#!/usr/bin/env bash
set -euo pipefail

MODE="uninstall"
APP_NAME="MacDog"
APP_DEST="$HOME/Applications/$APP_NAME.app"
CLI_DEST="$HOME/bin/codex-usage"
LAUNCH_AGENT_DIR="$HOME/Library/LaunchAgents"
CACHE_LABEL="com.dhseo.macdog.usage-cache"
MONITOR_LABEL="com.dhseo.macdog.monitor"
CACHE_PLIST="$LAUNCH_AGENT_DIR/$CACHE_LABEL.plist"
MONITOR_PLIST="$LAUNCH_AGENT_DIR/$MONITOR_LABEL.plist"
APP_CACHE_DIR="$HOME/Library/Application Support/MacDog"
APP_CACHE_FILE="$APP_CACHE_DIR/usage.json"
SHARED_CACHE_DIR="$HOME/Library/Group Containers/group.com.dhseo.macdog.MacDog"
SHARED_CACHE_FILE="$SHARED_CACHE_DIR/usage.json"
HELPER_LABEL="com.dhseo.macdog.helper"
HELPER_TOOL_DEST="/Library/PrivilegedHelperTools/$HELPER_LABEL"
HELPER_PLIST_DEST="/Library/LaunchDaemons/$HELPER_LABEL.plist"
UID_VALUE="$(id -u)"
WITH_HELPER=0
HELPER_ONLY=0

usage() {
  echo "usage: $0 [--dry-run] [--with-helper] [--helper-only]"
}

run_as_root() {
  if [[ "$(id -u)" == "0" ]]; then
    "$@"
  elif [[ -t 0 ]]; then
    /usr/bin/sudo "$@"
  else
    local command=""
    local arg
    for arg in "$@"; do
      command+=" $(shell_quote "$arg")"
    done
    /usr/bin/osascript -e "do shell script $(apple_script_literal "${command# }") with administrator privileges"
  fi
}

shell_quote() {
  local value="$1"
  printf "'%s'" "${value//\'/\'\\\'\'}"
}

apple_script_literal() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  printf '"%s"' "$value"
}

macdog_owns_sleep_disabled() {
  [[ "$(/usr/bin/defaults read com.dhseo.macdog.MacDog closedLidSleepDisabledByMacDog 2>/dev/null || true)" == "1" ]] || return 1
  /usr/bin/pmset -g live | /usr/bin/grep -q $'SleepDisabled\t\t1'
}

stop_running_app_for_update() {
  if macdog_owns_sleep_disabled; then
    /usr/bin/pkill -9 -x "$APP_NAME" >/dev/null 2>&1 || true
  else
    /usr/bin/pkill -x "$APP_NAME" >/dev/null 2>&1 || true
  fi
}

uninstall_privileged_helper() {
  run_as_root /usr/bin/true
  run_as_root /bin/launchctl bootout system "$HELPER_PLIST_DEST" >/dev/null 2>&1 || true
  run_as_root /bin/rm -f "$HELPER_TOOL_DEST" "$HELPER_PLIST_DEST"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    uninstall) MODE="uninstall" ;;
    --dry-run|dry-run) MODE="dry-run" ;;
    --with-helper) WITH_HELPER=1 ;;
    --helper-only)
      WITH_HELPER=1
      HELPER_ONLY=1
      ;;
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

case "$MODE" in
  uninstall) ;;
  dry-run)
    if [[ "$HELPER_ONLY" == "1" ]]; then
      echo "MacDog helper-only uninstall dry run"
      echo "App uninstall: skipped"
      echo "CLI uninstall: skipped"
      echo "LaunchAgent changes: skipped"
      echo "Running app process: left untouched"
      echo "Privileged helper: opt-in cleanup enabled"
      echo "Would bootout system helper: $HELPER_LABEL"
      echo "Would remove helper tool: $HELPER_TOOL_DEST"
      echo "Would remove helper launch daemon: $HELPER_PLIST_DEST"
      echo "Helper uninstall status: implemented; actual run requires administrator approval"
      exit 0
    fi

    echo "MacDog uninstall dry run"
    echo "Would bootout: gui/$UID_VALUE $CACHE_PLIST"
    echo "Would bootout: gui/$UID_VALUE $MONITOR_PLIST"
    echo "Would stop process: $APP_NAME"
    echo "Would remove: $CACHE_PLIST"
    echo "Would remove: $MONITOR_PLIST"
    echo "Would remove: $CLI_DEST"
    echo "Would remove: $APP_DEST"
    echo "Would remove cache file: $APP_CACHE_FILE"
    echo "Would remove shared cache file: $SHARED_CACHE_FILE"
    echo "Would remove empty cache directories: $APP_CACHE_DIR, $SHARED_CACHE_DIR"
    echo "Would preserve: MacDog UserDefaults preferences"
    echo "Widget extension: removed with $APP_DEST/Contents/PlugIns/MacDogWidgetExtension.appex"
    if [[ "$WITH_HELPER" == "1" ]]; then
      echo "Privileged helper: opt-in cleanup enabled"
      echo "Would bootout system helper: $HELPER_LABEL"
      echo "Would remove helper tool: $HELPER_TOOL_DEST"
      echo "Would remove helper launch daemon: $HELPER_PLIST_DEST"
      echo "Helper uninstall status: implemented; actual run requires administrator approval"
    else
      echo "Privileged helper: skipped; pass --with-helper for dry-run cleanup plan"
    fi
    exit 0
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

if [[ "$HELPER_ONLY" == "1" ]]; then
  uninstall_privileged_helper
  echo "Removed MacDog privileged helper"
  echo "Removed privileged helper: $HELPER_TOOL_DEST"
  echo "Removed LaunchDaemon: $HELPER_PLIST_DEST"
  exit 0
fi

if [[ "$WITH_HELPER" == "1" ]]; then
  uninstall_privileged_helper
fi

/bin/launchctl bootout "gui/$UID_VALUE" "$CACHE_PLIST" >/dev/null 2>&1 || true
/bin/launchctl bootout "gui/$UID_VALUE" "$MONITOR_PLIST" >/dev/null 2>&1 || true
stop_running_app_for_update

rm -f "$CACHE_PLIST" "$MONITOR_PLIST" "$CLI_DEST" "$APP_CACHE_FILE" "$SHARED_CACHE_FILE"
rm -rf "$APP_DEST"
rmdir "$APP_CACHE_DIR" "$SHARED_CACHE_DIR" >/dev/null 2>&1 || true

echo "Uninstalled MacDog"
if [[ "$WITH_HELPER" == "1" ]]; then
  echo "Removed privileged helper: $HELPER_TOOL_DEST"
  echo "Removed LaunchDaemon: $HELPER_PLIST_DEST"
fi
