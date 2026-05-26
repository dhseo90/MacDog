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

install_output="$("$ROOT_DIR/script/install.sh" --dry-run)"
require_contains "$install_output" "Codex Usage Monitor install dry run"
require_contains "$install_output" "App destination:"
require_contains "$install_output" "CLI destination:"
require_contains "$install_output" "LaunchAgent cache plist:"
require_contains "$install_output" "LaunchAgent monitor plist:"
require_contains "$install_output" "Widget extension: not installed by this script"

uninstall_output="$("$ROOT_DIR/script/uninstall.sh" --dry-run)"
require_contains "$uninstall_output" "Codex Usage Monitor uninstall dry run"
require_contains "$uninstall_output" "Would bootout:"
require_contains "$uninstall_output" "Would remove:"
require_contains "$uninstall_output" "Widget extension: not managed by this script"

echo "Install dry-run verification ok"
