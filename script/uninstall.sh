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
HELPER_LABEL="com.dhseo.macdog.helper"
HELPER_TOOL_DEST="/Library/PrivilegedHelperTools/$HELPER_LABEL"
HELPER_PLIST_DEST="/Library/LaunchDaemons/$HELPER_LABEL.plist"
UID_VALUE="$(id -u)"
WITH_HELPER=0

usage() {
  echo "usage: $0 [--dry-run] [--with-helper]"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    uninstall) MODE="uninstall" ;;
    --dry-run|dry-run) MODE="dry-run" ;;
    --with-helper) WITH_HELPER=1 ;;
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
    echo "MacDog uninstall dry run"
    echo "Would bootout: gui/$UID_VALUE $CACHE_PLIST"
    echo "Would bootout: gui/$UID_VALUE $MONITOR_PLIST"
    echo "Would stop process: $APP_NAME"
    echo "Would remove: $CACHE_PLIST"
    echo "Would remove: $MONITOR_PLIST"
    echo "Would remove: $CLI_DEST"
    echo "Would remove: $APP_DEST"
    echo "Would preserve: MacDog UserDefaults preferences"
    echo "Widget extension: removed with $APP_DEST/Contents/PlugIns/MacDogWidgetExtension.appex"
    if [[ "$WITH_HELPER" == "1" ]]; then
      echo "Privileged helper: opt-in cleanup enabled"
      echo "Would bootout system helper: $HELPER_LABEL"
      echo "Would remove helper tool: $HELPER_TOOL_DEST"
      echo "Would remove helper launch daemon: $HELPER_PLIST_DEST"
      echo "Helper uninstall status: dry-run only; actual privileged uninstall not implemented yet"
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

if [[ "$WITH_HELPER" == "1" ]]; then
  echo "error: privileged helper uninstall is not implemented yet; use --dry-run --with-helper" >&2
  exit 2
fi

/bin/launchctl bootout "gui/$UID_VALUE" "$CACHE_PLIST" >/dev/null 2>&1 || true
/bin/launchctl bootout "gui/$UID_VALUE" "$MONITOR_PLIST" >/dev/null 2>&1 || true
pkill -x "$APP_NAME" >/dev/null 2>&1 || true

rm -f "$CACHE_PLIST" "$MONITOR_PLIST" "$CLI_DEST"
rm -rf "$APP_DEST"

echo "Uninstalled MacDog"
