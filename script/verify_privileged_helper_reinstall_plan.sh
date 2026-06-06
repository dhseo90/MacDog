#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

die() {
  echo "error: $*" >&2
  exit 1
}

require_contains() {
  local output="$1"
  local expected="$2"
  if [[ "$output" != *"$expected"* ]]; then
    die "missing expected helper reinstall plan text: $expected"
  fi
}

install_output="$(MACDOG_APP_VERSION=9.9.9 "$ROOT_DIR/script/install.sh" --dry-run --helper-only)"
require_contains "$install_output" "MacDog helper-only install dry run"
require_contains "$install_output" "Running app process: left untouched"
require_contains "$install_output" "Helper install status: implemented"

uninstall_output="$("$ROOT_DIR/script/uninstall.sh" --dry-run --helper-only)"
require_contains "$uninstall_output" "MacDog helper-only uninstall dry run"
require_contains "$uninstall_output" "Running app process: left untouched"
require_contains "$uninstall_output" "Helper uninstall status: implemented"

state_output="$("$ROOT_DIR/script/verify_privileged_helper_state.sh" --allow-missing)"
"$ROOT_DIR/script/verify_privileged_helper_xpc.sh" --allow-missing --skip-runtime >/dev/null

cat <<PLAN
Privileged helper reinstall plan verification ok.

Current state:
  $state_output

Approved manual sequence for a real reinstall test:
  ./script/uninstall.sh --helper-only
  ./script/verify_privileged_helper_state.sh --expect-missing
  MACDOG_APP_VERSION=<version> ./script/install.sh --helper-only
  ./script/verify_privileged_helper_state.sh --expect-installed
  ./script/verify_privileged_helper_xpc.sh --expect-installed --set 0 --restore

This verifier did not uninstall, install, unload, load, or change SleepDisabled.
PLAN
