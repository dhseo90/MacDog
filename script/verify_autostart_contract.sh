#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL_SCRIPT="$ROOT_DIR/script/install.sh"
UNINSTALL_SCRIPT="$ROOT_DIR/script/uninstall.sh"
PREFERENCES_SOURCE="$ROOT_DIR/Sources/MacDog/RunnerPreferences.swift"
CONTROLLER_SOURCE="$ROOT_DIR/Sources/MacDog/MenuBarController.swift"

require_contains() {
  local file="$1"
  local expected="$2"
  if ! /usr/bin/grep -Fq "$expected" "$file"; then
    echo "missing expected autostart contract text in $file: $expected" >&2
    exit 1
  fi
}

require_absent() {
  local file="$1"
  local unexpected="$2"
  if /usr/bin/grep -Fq "$unexpected" "$file"; then
    echo "unexpected autostart contract text in $file: $unexpected" >&2
    exit 1
  fi
}

require_contains "$INSTALL_SCRIPT" "MONITOR_LABEL=\"com.dhseo.macdog.monitor\""
require_contains "$INSTALL_SCRIPT" "<string>/usr/bin/open</string>"
require_contains "$INSTALL_SCRIPT" "<string>-n</string>"
require_contains "$INSTALL_SCRIPT" '<string>$APP_DEST</string>'
require_contains "$INSTALL_SCRIPT" "<key>RunAtLoad</key>"
require_contains "$INSTALL_SCRIPT" '/bin/launchctl bootstrap "gui/$UID_VALUE" "$MONITOR_PLIST"'

require_contains "$PREFERENCES_SOURCE" "static let sleepPreventionPowerAdapterTriggerKey"
require_contains "$PREFERENCES_SOURCE" "static let sleepPreventionCodexAppTriggerKey"
require_contains "$PREFERENCES_SOURCE" "init(defaults: UserDefaults = .standard)"
require_contains "$CONTROLLER_SOURCE" "preferences = RunnerPreferences()"
require_contains "$CONTROLLER_SOURCE" "syncSleepPrevention(systemMetrics:"

require_absent "$UNINSTALL_SCRIPT" "defaults delete com.dhseo.macdog.MacDog"
require_absent "$UNINSTALL_SCRIPT" "removePersistentDomain"

echo "Autostart contract verification ok"
