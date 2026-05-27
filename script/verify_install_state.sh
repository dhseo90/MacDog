#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-report}"
APP_NAME="MacDog"
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
  -h|--help|help)
    echo "usage: $0 [--report|--expect-installed|--expect-uninstalled]"
    exit 0
    ;;
  *)
    echo "usage: $0 [--report|--expect-installed|--expect-uninstalled]" >&2
    exit 2
    ;;
esac

present() {
  [[ -e "$1" ]]
}

executable() {
  [[ -x "$1" ]]
}

print_state() {
  if present "$APP_DEST"; then echo "app:present $APP_DEST"; else echo "app:absent $APP_DEST"; fi
  if executable "$APP_BINARY"; then echo "app-binary:executable $APP_BINARY"; else echo "app-binary:missing-or-not-executable $APP_BINARY"; fi
  if present "$WIDGET_APPEX"; then echo "widget-appex:present $WIDGET_APPEX"; else echo "widget-appex:absent $WIDGET_APPEX"; fi
  if executable "$WIDGET_BINARY"; then echo "widget-binary:executable $WIDGET_BINARY"; else echo "widget-binary:missing-or-not-executable $WIDGET_BINARY"; fi
  if executable "$CLI_DEST"; then echo "cli:executable $CLI_DEST"; else echo "cli:missing-or-not-executable $CLI_DEST"; fi
  if present "$CACHE_PLIST"; then echo "cache-plist:present $CACHE_PLIST"; else echo "cache-plist:absent $CACHE_PLIST"; fi
  if present "$MONITOR_PLIST"; then echo "monitor-plist:present $MONITOR_PLIST"; else echo "monitor-plist:absent $MONITOR_PLIST"; fi
  if pgrep -x "$APP_NAME" >/dev/null 2>&1; then echo "process:running $APP_NAME"; else echo "process:not-running $APP_NAME"; fi
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
esac
