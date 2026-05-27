#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-uninstall}"
APP_NAME="MacDog"
APP_DEST="$HOME/Applications/$APP_NAME.app"
CLI_DEST="$HOME/bin/codex-usage"
LAUNCH_AGENT_DIR="$HOME/Library/LaunchAgents"
CACHE_LABEL="com.dhseo.macdog.usage-cache"
MONITOR_LABEL="com.dhseo.macdog.monitor"
CACHE_PLIST="$LAUNCH_AGENT_DIR/$CACHE_LABEL.plist"
MONITOR_PLIST="$LAUNCH_AGENT_DIR/$MONITOR_LABEL.plist"
UID_VALUE="$(id -u)"

case "$MODE" in
  uninstall) ;;
  --dry-run|dry-run)
    echo "MacDog uninstall dry run"
    echo "Would bootout: gui/$UID_VALUE $CACHE_PLIST"
    echo "Would bootout: gui/$UID_VALUE $MONITOR_PLIST"
    echo "Would stop process: $APP_NAME"
    echo "Would remove: $CACHE_PLIST"
    echo "Would remove: $MONITOR_PLIST"
    echo "Would remove: $CLI_DEST"
    echo "Would remove: $APP_DEST"
    echo "Widget extension: removed with $APP_DEST/Contents/PlugIns/MacDogWidgetExtension.appex"
    exit 0
    ;;
  -h|--help|help)
    echo "usage: $0 [--dry-run]"
    exit 0
    ;;
  *)
    echo "usage: $0 [--dry-run]" >&2
    exit 2
    ;;
esac

/bin/launchctl bootout "gui/$UID_VALUE" "$CACHE_PLIST" >/dev/null 2>&1 || true
/bin/launchctl bootout "gui/$UID_VALUE" "$MONITOR_PLIST" >/dev/null 2>&1 || true
pkill -x "$APP_NAME" >/dev/null 2>&1 || true

rm -f "$CACHE_PLIST" "$MONITOR_PLIST" "$CLI_DEST"
rm -rf "$APP_DEST"

echo "Uninstalled MacDog"
