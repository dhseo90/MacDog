#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL_SCRIPT="$ROOT_DIR/script/install.sh"
UNINSTALL_SCRIPT="$ROOT_DIR/script/uninstall.sh"
PREFERENCES_SOURCE="$ROOT_DIR/Sources/MacDog/RunnerPreferences.swift"
LOGIN_CONTROLLER_SOURCE="$ROOT_DIR/Sources/MacDog/LoginLaunchController.swift"
CONTROLLER_SOURCE="$ROOT_DIR/Sources/MacDog/MenuBarController.swift"
MAIN_SOURCE="$ROOT_DIR/Sources/MacDog/MacDogMain.swift"

require_contains() {
  local file="$1"
  local expected="$2"
  if ! /usr/bin/grep -Fq -- "$expected" "$file"; then
    echo "missing expected autostart contract text in $file: $expected" >&2
    exit 1
  fi
}

require_absent() {
  local file="$1"
  local unexpected="$2"
  if /usr/bin/grep -Fq -- "$unexpected" "$file"; then
    echo "unexpected autostart contract text in $file: $unexpected" >&2
    exit 1
  fi
}

require_contains "$INSTALL_SCRIPT" "MONITOR_LABEL=\"com.dhseo.macdog.monitor\""
require_contains "$INSTALL_SCRIPT" "LOGIN_LAUNCH_KEY=\"loginLaunchEnabled\""
require_contains "$INSTALL_SCRIPT" "login_launch_enabled()"
require_contains "$INSTALL_SCRIPT" 'rm -f "$MONITOR_PLIST"'
require_contains "$INSTALL_SCRIPT" '/usr/bin/open "$APP_DEST"'
require_absent "$INSTALL_SCRIPT" 'write_monitor_launch_agent_plist'
require_absent "$INSTALL_SCRIPT" '/bin/launchctl bootstrap "gui/$UID_VALUE" "$MONITOR_PLIST"'
require_absent "$INSTALL_SCRIPT" "<string>-n</string>"

require_contains "$LOGIN_CONTROLLER_SOURCE" "SMAppService.mainApp"
require_contains "$LOGIN_CONTROLLER_SOURCE" "removeLegacyLaunchAgent()"
require_contains "$MAIN_SOURCE" "--set-login-item"
require_contains "$MAIN_SOURCE" "--verify-login-item-status"
require_contains "$PREFERENCES_SOURCE" "static let loginLaunchEnabledKey"
require_contains "$PREFERENCES_SOURCE" "static let sleepPreventionPowerAdapterTriggerKey"
require_contains "$PREFERENCES_SOURCE" "static let sleepPreventionCodexAppTriggerKey"
require_contains "$PREFERENCES_SOURCE" "init(defaults: UserDefaults = .standard)"
require_contains "$CONTROLLER_SOURCE" "preferences = RunnerPreferences()"
require_contains "$CONTROLLER_SOURCE" "syncSleepPrevention(systemMetrics:"

require_contains "$UNINSTALL_SCRIPT" "--reset-preferences"
require_contains "$UNINSTALL_SCRIPT" "RESET_PREFERENCES"
require_contains "$UNINSTALL_SCRIPT" "defaults delete com.dhseo.macdog.MacDog"
require_absent "$UNINSTALL_SCRIPT" "removePersistentDomain"

echo "Autostart contract verification ok"
