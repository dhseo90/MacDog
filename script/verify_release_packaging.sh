#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="$ROOT_DIR/dist/MacDog.app"

die() {
  echo "error: $*" >&2
  exit 1
}

require_contains() {
  local output="$1"
  local expected="$2"
  if [[ "$output" != *"$expected"* ]]; then
    die "missing expected release packaging text: $expected"
  fi
}

output="$("$ROOT_DIR/script/package_release.sh" --dry-run)"
require_contains "$output" "MacDog release package dry run"
require_contains "$output" "Payload:"
require_contains "$output" "MacDog.app"
require_contains "$output" "bin/codex-usage"
require_contains "$output" "Install MacDog.command"
require_contains "$output" "Double-click install:"
require_contains "$output" "Privileged helper: not installed by this release command"
require_contains "$output" "Developer ID signing and notarization are not performed"
require_contains "$output" "GitHub Release:"

if [[ -d "$APP_BUNDLE" ]]; then
  version="verify"
  stage="$ROOT_DIR/dist/release/MacDog-$version"
  stage_output="$(MACDOG_RELEASE_VERSION="$version" "$ROOT_DIR/script/package_release.sh" --skip-build --no-dmg)"

  require_contains "$stage_output" "$stage"
  [[ -d "$stage/MacDog.app" ]] || die "staged app bundle missing: $stage/MacDog.app"
  [[ -x "$stage/bin/codex-usage" ]] || die "staged CLI missing or not executable: $stage/bin/codex-usage"
  [[ -x "$stage/Install MacDog.command" ]] || die "staged installer command missing or not executable"
  [[ -f "$stage/README_FIRST.txt" ]] || die "staged README missing"

  /usr/bin/grep -Fq "Privileged helper installation is not performed" "$stage/README_FIRST.txt" || die "staged README helper boundary missing"
  /usr/bin/grep -Fq "Privileged helper is not installed by this command yet." "$stage/Install MacDog.command" || die "installer helper boundary missing"
  /usr/bin/grep -Fq 'launchctl bootstrap "gui/$UID_VALUE"' "$stage/Install MacDog.command" || die "installer LaunchAgent bootstrap missing"
  /usr/bin/grep -Fq 'pkill -x "$APP_NAME"' "$stage/Install MacDog.command" || die "installer app restart step missing"
  bash -n "$stage/Install MacDog.command"

  if /usr/bin/grep -Eq 'PrivilegedHelperTools|LaunchDaemons|SMJobBless|sudo ' "$stage/Install MacDog.command"; then
    die "installer command unexpectedly contains privileged helper installation material"
  fi
else
  echo "Release packaging stage verification skipped: dist/MacDog.app missing"
fi

echo "Release packaging verification ok"
