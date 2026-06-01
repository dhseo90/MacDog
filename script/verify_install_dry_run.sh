#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

require_contains() {
  local output="$1"
  local expected="$2"
  if [[ "$output" != *"$expected"* ]]; then
    echo "missing expected dry-run text: $expected" >&2
    exit 1
  fi
}

require_not_contains() {
  local output="$1"
  local unexpected="$2"
  if [[ "$output" == *"$unexpected"* ]]; then
    echo "unexpected dry-run text: $unexpected" >&2
    exit 1
  fi
}

install_output="$("$ROOT_DIR/script/install.sh" --dry-run)"
require_contains "$install_output" "MacDog install dry run"
require_contains "$install_output" "App destination:"
require_contains "$install_output" "CLI destination:"
require_contains "$install_output" "Cache agent executable:"
require_contains "$install_output" "LaunchAgent cache plist:"
require_contains "$install_output" "Legacy monitor LaunchAgent cleanup:"
require_contains "$install_output" "Login item: managed by MacDog through macOS Login Items"
require_contains "$install_output" "Cache request timeout: 5 seconds"
require_contains "$install_output" "Cache prime timeout: 12 seconds"
require_contains "$install_output" "Login item preference key: loginLaunchEnabled"
require_contains "$install_output" "Login item enabled by preference:"
require_contains "$install_output" "Preferences: preserved in UserDefaults and restored by MacDog on launch"
require_contains "$install_output" "Widget extension: skipped by default; pass --with-widget to build/install it"
require_contains "$install_output" "Widget cache mirror: disabled"
require_contains "$install_output" "Privileged helper: skipped"

widget_install_output="$("$ROOT_DIR/script/install.sh" --dry-run --with-widget)"
require_contains "$widget_install_output" "Widget extension: opt-in bundled in"
require_contains "$widget_install_output" "Widget cache mirror: enabled"

helper_install_output="$("$ROOT_DIR/script/install.sh" --dry-run --with-helper)"
require_contains "$helper_install_output" "Privileged helper: opt-in enabled"
require_contains "$helper_install_output" "Helper label: com.dhseo.macdog.helper"
require_contains "$helper_install_output" "Helper host app source:"
require_contains "$helper_install_output" "Helper commands: read SleepDisabled, set SleepDisabled 0/1, read screenLock, set screenLock off/immediate/seconds only"
require_contains "$helper_install_output" "Helper install status: implemented"
require_contains "$helper_install_output" "Helper approval UX:"
require_contains "$helper_install_output" "Helper host requirement: team id when signed"
require_contains "$helper_install_output" "Helper launch daemon plist validation: ok"
require_not_contains "$helper_install_output" "not implemented"

helper_only_install_output="$("$ROOT_DIR/script/install.sh" --dry-run --helper-only)"
require_contains "$helper_only_install_output" "MacDog helper-only install dry run"
require_contains "$helper_only_install_output" "App install: skipped"
require_contains "$helper_only_install_output" "Running app process: left untouched"
require_contains "$helper_only_install_output" "Helper host app source:"
require_contains "$helper_only_install_output" "Helper launch daemon plist validation: ok"
require_not_contains "$helper_only_install_output" "not implemented"

uninstall_output="$("$ROOT_DIR/script/uninstall.sh" --dry-run)"
require_contains "$uninstall_output" "MacDog uninstall dry run"
require_contains "$uninstall_output" "Would bootout:"
require_contains "$uninstall_output" "Would unregister macOS login item if app binary is present"
require_contains "$uninstall_output" "Would remove:"
require_contains "$uninstall_output" "Would remove cache file:"
require_contains "$uninstall_output" "Would remove usage history file:"
require_contains "$uninstall_output" "Would remove shared cache file:"
require_contains "$uninstall_output" "Would remove empty cache directories:"
require_contains "$uninstall_output" "Would preserve: MacDog UserDefaults preferences"
require_contains "$uninstall_output" "Widget extension: removed with app bundle if present"
require_contains "$uninstall_output" "Privileged helper: skipped"

helper_uninstall_output="$("$ROOT_DIR/script/uninstall.sh" --dry-run --with-helper)"
require_contains "$helper_uninstall_output" "Privileged helper: opt-in cleanup enabled"
require_contains "$helper_uninstall_output" "Would bootout system helper: com.dhseo.macdog.helper"
require_contains "$helper_uninstall_output" "Would remove helper tool: /Library/PrivilegedHelperTools/com.dhseo.macdog.helper"
require_contains "$helper_uninstall_output" "Helper uninstall status: implemented"
require_not_contains "$helper_uninstall_output" "not implemented"

helper_only_uninstall_output="$("$ROOT_DIR/script/uninstall.sh" --dry-run --helper-only)"
require_contains "$helper_only_uninstall_output" "MacDog helper-only uninstall dry run"
require_contains "$helper_only_uninstall_output" "App uninstall: skipped"
require_contains "$helper_only_uninstall_output" "Running app process: left untouched"
require_contains "$helper_only_uninstall_output" "Helper uninstall status: implemented"
require_not_contains "$helper_only_uninstall_output" "not implemented"

echo "Install dry-run verification ok"
