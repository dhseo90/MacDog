#!/usr/bin/env bash
set -euo pipefail

APP_NAME="CodexUsageMonitor"
APP_DEST="$HOME/Applications/$APP_NAME.app"
CLI_DEST="$HOME/bin/codex-usage"
LAUNCH_AGENT_DIR="$HOME/Library/LaunchAgents"
CACHE_LABEL="com.dhseo.mycodex.usage-cache"
MONITOR_LABEL="com.dhseo.mycodex.monitor"
CACHE_PLIST="$LAUNCH_AGENT_DIR/$CACHE_LABEL.plist"
MONITOR_PLIST="$LAUNCH_AGENT_DIR/$MONITOR_LABEL.plist"
UID_VALUE="$(id -u)"

/bin/launchctl bootout "gui/$UID_VALUE" "$CACHE_PLIST" >/dev/null 2>&1 || true
/bin/launchctl bootout "gui/$UID_VALUE" "$MONITOR_PLIST" >/dev/null 2>&1 || true
pkill -x "$APP_NAME" >/dev/null 2>&1 || true

rm -f "$CACHE_PLIST" "$MONITOR_PLIST" "$CLI_DEST"
rm -rf "$APP_DEST"

echo "Uninstalled Codex Usage Monitor"
