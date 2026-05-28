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

with_temp_home() {
  local temp_home
  temp_home="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/macdog-release-home.XXXXXX")"
  trap 'rm -rf "$temp_home"' RETURN
  mkdir -p "$temp_home/Applications" "$temp_home/bin" "$temp_home/Library/LaunchAgents"
  /usr/bin/ditto --norsrc --noextattr "$stage/MacDog.app" "$temp_home/Applications/MacDog.app"
  /usr/bin/touch "$temp_home/bin/codex-usage"
  chmod +x "$temp_home/bin/codex-usage"
  /usr/bin/touch \
    "$temp_home/Library/LaunchAgents/com.dhseo.macdog.usage-cache.plist" \
    "$temp_home/Library/LaunchAgents/com.dhseo.macdog.monitor.plist"
  HOME="$temp_home" "$stage/Check Install Status.command" >/dev/null
  rm -rf "$temp_home"
  trap - RETURN
}

output="$("$ROOT_DIR/script/package_release.sh" --dry-run)"
require_contains "$output" "MacDog release package dry run"
require_contains "$output" "Payload:"
require_contains "$output" "MacDog.app"
require_contains "$output" "bin/codex-usage"
require_contains "$output" "Install MacDog.command"
require_contains "$output" "Install Privileged Helper.command"
require_contains "$output" "Uninstall MacDog.command"
require_contains "$output" "Uninstall Privileged Helper.command"
require_contains "$output" "Check Install Status.command"
require_contains "$output" "RELEASE_NOTES_DRAFT.md"
require_contains "$output" "SHA-256 path:"
require_contains "$output" "Double-click install:"
require_contains "$output" "Privileged helper: Install Privileged Helper.command"
require_contains "$output" "Double-click uninstall: Uninstall MacDog.command"
require_contains "$output" "Privileged helper cleanup: Uninstall Privileged Helper.command"
require_contains "$output" "Post-install check: Check Install Status.command"
require_contains "$output" "Developer ID signing and notarization are not performed"
require_contains "$output" "Gatekeeper: unsigned candidates are local validation artifacts"
require_contains "$output" "GitHub Release:"

if [[ -d "$APP_BUNDLE" ]]; then
  version="verify"
  stage="$ROOT_DIR/dist/release/MacDog-$version"
  stage_output="$(MACDOG_RELEASE_VERSION="$version" "$ROOT_DIR/script/package_release.sh" --skip-build --no-dmg)"

  require_contains "$stage_output" "$stage"
  [[ -d "$stage/MacDog.app" ]] || die "staged app bundle missing: $stage/MacDog.app"
  [[ -x "$stage/bin/codex-usage" ]] || die "staged CLI missing or not executable: $stage/bin/codex-usage"
  [[ -x "$stage/Install MacDog.command" ]] || die "staged installer command missing or not executable"
  [[ -x "$stage/Install Privileged Helper.command" ]] || die "staged helper installer command missing or not executable"
  [[ -x "$stage/Uninstall MacDog.command" ]] || die "staged uninstall command missing or not executable"
  [[ -x "$stage/Uninstall Privileged Helper.command" ]] || die "staged helper uninstall command missing or not executable"
  [[ -x "$stage/Check Install Status.command" ]] || die "staged install status command missing or not executable"
  [[ -f "$stage/README_FIRST.txt" ]] || die "staged README missing"
  [[ -f "$stage/RELEASE_NOTES_DRAFT.md" ]] || die "staged release notes draft missing"

  /usr/bin/grep -Fq "Install Privileged Helper.command" "$stage/README_FIRST.txt" || die "staged README helper installer missing"
  /usr/bin/grep -Fq "Uninstall MacDog.command" "$stage/README_FIRST.txt" || die "staged README uninstall command missing"
  /usr/bin/grep -Fq "Uninstall Privileged Helper.command" "$stage/README_FIRST.txt" || die "staged README helper uninstall command missing"
  /usr/bin/grep -Fq "Check Install Status.command" "$stage/README_FIRST.txt" || die "staged README status checker missing"
  /usr/bin/grep -Fq "Gatekeeper may block first launch" "$stage/README_FIRST.txt" || die "staged README Gatekeeper warning missing"
  /usr/bin/grep -Fq "notarization" "$stage/RELEASE_NOTES_DRAFT.md" || die "release notes notarization gate missing"
  /usr/bin/grep -Fq "Check Install Status.command" "$stage/RELEASE_NOTES_DRAFT.md" || die "release notes status checker missing"
  /usr/bin/grep -Fq "Uninstall MacDog.command" "$stage/RELEASE_NOTES_DRAFT.md" || die "release notes uninstall command missing"
  /usr/bin/grep -Fq "Uninstall Privileged Helper.command" "$stage/RELEASE_NOTES_DRAFT.md" || die "release notes helper uninstall command missing"
  /usr/bin/grep -Fq "Install Privileged Helper.command" "$stage/Install MacDog.command" || die "installer helper handoff missing"
  /usr/bin/grep -Fq "Check Install Status.command" "$stage/Install MacDog.command" || die "installer status handoff missing"
  /usr/bin/grep -Fq 'launchctl bootstrap "gui/$UID_VALUE"' "$stage/Install MacDog.command" || die "installer LaunchAgent bootstrap missing"
  /usr/bin/grep -Fq 'pkill -9 -x "$APP_NAME"' "$stage/Install MacDog.command" || die "installer sleep-safe app restart step missing"
  /usr/bin/grep -Fq 'MACDOG_HELPER_ALLOW_ADHOC_HOST' "$stage/Install Privileged Helper.command" || die "helper installer local ad-hoc host gate missing"
  /usr/bin/grep -Fq 'with administrator privileges' "$stage/Install Privileged Helper.command" || die "helper installer administrator approval missing"
  /usr/bin/grep -Fq 'Continue with privileged helper install?' "$stage/Install Privileged Helper.command" || die "helper installer confirmation prompt missing"
  /usr/bin/grep -Fq 'Continue with MacDog uninstall?' "$stage/Uninstall MacDog.command" || die "uninstaller confirmation prompt missing"
  /usr/bin/grep -Fq 'Optional helper was not changed.' "$stage/Uninstall MacDog.command" || die "user uninstaller helper boundary missing"
  /usr/bin/grep -Fq 'Continue with privileged helper uninstall?' "$stage/Uninstall Privileged Helper.command" || die "helper uninstaller confirmation prompt missing"
  /usr/bin/grep -Fq 'with administrator privileges' "$stage/Uninstall Privileged Helper.command" || die "helper uninstaller administrator approval missing"
  /usr/bin/grep -Fq 'LaunchDaemons' "$stage/Uninstall Privileged Helper.command" || die "helper uninstaller system location warning missing"
  /usr/bin/grep -Fq 'MacDog install status' "$stage/Check Install Status.command" || die "status checker title missing"
  /usr/bin/grep -Fq 'privileged helper is optional' "$stage/Check Install Status.command" || die "status checker optional helper copy missing"
  /usr/bin/grep -Fq 'installed app matches bundled release payload' "$stage/Check Install Status.command" || die "status checker freshness success copy missing"
  /usr/bin/grep -Fq 'installed app differs from bundled release payload' "$stage/Check Install Status.command" || die "status checker freshness failure copy missing"
  /usr/bin/grep -Fq 'bundle_manifest' "$stage/Check Install Status.command" || die "status checker app payload comparison missing"
  bash -n "$stage/Install MacDog.command"
  bash -n "$stage/Install Privileged Helper.command"
  bash -n "$stage/Uninstall MacDog.command"
  bash -n "$stage/Uninstall Privileged Helper.command"
  bash -n "$stage/Check Install Status.command"
  with_temp_home

  if /usr/bin/grep -Eq 'PrivilegedHelperTools|LaunchDaemons|SMJobBless|sudo ' "$stage/Install MacDog.command"; then
    die "installer command unexpectedly contains privileged helper installation material"
  fi
  if /usr/bin/grep -Eq 'PrivilegedHelperTools|LaunchDaemons|SMJobBless|sudo ' "$stage/Uninstall MacDog.command"; then
    die "uninstaller command unexpectedly contains privileged helper cleanup material"
  fi
else
  echo "Release packaging stage verification skipped: dist/MacDog.app missing"
fi

echo "Release packaging verification ok"
