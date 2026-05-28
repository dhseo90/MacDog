#!/usr/bin/env bash
set -euo pipefail

MODE="install"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="MacDog"
APP_SOURCE="$ROOT_DIR/dist/$APP_NAME.app"
APP_DEST="$HOME/Applications/$APP_NAME.app"
BIN_DIR="$HOME/bin"
CLI_DEST="$BIN_DIR/codex-usage"
LAUNCH_AGENT_DIR="$HOME/Library/LaunchAgents"
LOG_DIR="$HOME/Library/Logs/MacDog"
CACHE_LABEL="com.dhseo.macdog.usage-cache"
MONITOR_LABEL="com.dhseo.macdog.monitor"
CACHE_PLIST="$LAUNCH_AGENT_DIR/$CACHE_LABEL.plist"
MONITOR_PLIST="$LAUNCH_AGENT_DIR/$MONITOR_LABEL.plist"
HELPER_LABEL="com.dhseo.macdog.helper"
HELPER_EXECUTABLE="MacDogPrivilegedHelper"
HELPER_MACH_SERVICE="$HELPER_LABEL.xpc"
HELPER_SOURCE="$APP_SOURCE/Contents/Library/LaunchServices/$HELPER_EXECUTABLE"
HELPER_PLIST_SOURCE="$APP_SOURCE/Contents/Library/LaunchDaemons/$HELPER_LABEL.plist"
HELPER_TOOL_DEST="/Library/PrivilegedHelperTools/$HELPER_LABEL"
HELPER_PLIST_DEST="/Library/LaunchDaemons/$HELPER_LABEL.plist"
UID_VALUE="$(id -u)"
WITH_HELPER=0

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
XCRUN="/usr/bin/xcrun"

usage() {
  echo "usage: $0 [--dry-run] [--with-helper]"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    install) MODE="install" ;;
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
  install) ;;
  dry-run)
    echo "MacDog install dry run"
    echo "Build script: $ROOT_DIR/script/build_and_run.sh --no-run"
    echo "App source: $APP_SOURCE"
    echo "App destination: $APP_DEST"
    echo "CLI destination: $CLI_DEST"
    echo "Log directory: $LOG_DIR"
    echo "LaunchAgent cache plist: $CACHE_PLIST"
    echo "LaunchAgent monitor plist: $MONITOR_PLIST"
    echo "Cache agent interval: 300 seconds"
    echo "Monitor agent RunAtLoad: true"
    echo "Preferences: preserved in UserDefaults and restored by MacDog on launch"
    echo "Widget extension: bundled in $APP_SOURCE/Contents/PlugIns/MacDogWidgetExtension.appex"
    if [[ "$WITH_HELPER" == "1" ]]; then
      echo "Privileged helper: opt-in enabled"
      echo "Helper label: $HELPER_LABEL"
      echo "Helper executable source: $HELPER_SOURCE"
      echo "Helper launch daemon source: $HELPER_PLIST_SOURCE"
      echo "Helper tool destination: $HELPER_TOOL_DEST"
      echo "Helper launch daemon destination: $HELPER_PLIST_DEST"
      echo "Helper mach service: $HELPER_MACH_SERVICE"
      echo "Helper commands: read SleepDisabled, set SleepDisabled 0/1 only"
      echo "Helper install status: dry-run only; actual privileged install not implemented yet"
    else
      echo "Privileged helper: skipped; pass --with-helper for dry-run plan"
    fi
    exit 0
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

if [[ "$WITH_HELPER" == "1" ]]; then
  echo "error: privileged helper install is not implemented yet; use --dry-run --with-helper" >&2
  exit 2
fi

"$ROOT_DIR/script/build_and_run.sh" --no-run >/dev/null
build_bin="$("$XCRUN" swift build -c release --show-bin-path)"

mkdir -p "$HOME/Applications" "$BIN_DIR" "$LAUNCH_AGENT_DIR" "$LOG_DIR"
/bin/launchctl bootout "gui/$UID_VALUE" "$CACHE_PLIST" >/dev/null 2>&1 || true
/bin/launchctl bootout "gui/$UID_VALUE" "$MONITOR_PLIST" >/dev/null 2>&1 || true
pkill -x "$APP_NAME" >/dev/null 2>&1 || true

rm -rf "$APP_DEST"
/usr/bin/ditto --norsrc --noextattr "$APP_SOURCE" "$APP_DEST"
/usr/bin/xattr -cr "$APP_DEST" >/dev/null 2>&1 || true
/usr/bin/codesign --force --sign - "$APP_DEST" >/dev/null
/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_DEST" >/dev/null
cp "$build_bin/codex-usage" "$CLI_DEST"
chmod +x "$CLI_DEST"

cat >"$CACHE_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$CACHE_LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>$CLI_DEST</string>
    <string>status</string>
    <string>--write-cache</string>
    <string>--watch</string>
    <string>300</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardOutPath</key>
  <string>$LOG_DIR/cache.out.log</string>
  <key>StandardErrorPath</key>
  <string>$LOG_DIR/cache.err.log</string>
</dict>
</plist>
PLIST

cat >"$MONITOR_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$MONITOR_LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/bin/open</string>
    <string>$APP_DEST</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>StandardOutPath</key>
  <string>$LOG_DIR/monitor.out.log</string>
  <key>StandardErrorPath</key>
  <string>$LOG_DIR/monitor.err.log</string>
</dict>
</plist>
PLIST

if ! "$CLI_DEST" status --write-cache >/dev/null; then
  echo "Warning: failed to prime usage cache; LaunchAgent will retry." >&2
fi

/bin/launchctl bootstrap "gui/$UID_VALUE" "$CACHE_PLIST"
/bin/launchctl bootstrap "gui/$UID_VALUE" "$MONITOR_PLIST"

sleep 2
pgrep -x "$APP_NAME" >/dev/null

echo "Installed MacDog"
echo "App: $APP_DEST"
echo "CLI: $CLI_DEST"
echo "LaunchAgents: $CACHE_PLIST, $MONITOR_PLIST"
