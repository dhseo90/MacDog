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

require_not_contains() {
  local output="$1"
  local unexpected="$2"
  if [[ "$output" == *"$unexpected"* ]]; then
    die "unexpected release packaging text: $unexpected"
  fi
}

require_line_count() {
  local file="$1"
  local pattern="$2"
  local expected="$3"
  local count
  count="$(/usr/bin/grep -Ec -- "$pattern" "$file" || true)"
  [[ "$count" == "$expected" ]] || die "unexpected line count in $file for pattern $pattern: expected $expected, got $count"
}

with_temp_home() {
  local temp_home
  temp_home="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/macdog-release-home.XXXXXX")"
  trap 'rm -rf "$temp_home"' RETURN
  mkdir -p "$temp_home/Applications" "$temp_home/bin" "$temp_home/Library/LaunchAgents"
  /usr/bin/ditto --norsrc --noextattr "$stage/MacDog.app" "$temp_home/Applications/MacDog.app"
  ln -s "$temp_home/Applications/MacDog.app/Contents/MacOS/codex-usage" "$temp_home/bin/codex-usage"
  cat >"$temp_home/Library/LaunchAgents/com.dhseo.macdog.usage-cache.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.dhseo.macdog.usage-cache</string>
  <key>ProgramArguments</key>
  <array>
    <string>$temp_home/Applications/MacDog.app/Contents/MacOS/codex-usage</string>
    <string>status</string>
  </array>
</dict>
</plist>
PLIST
  /usr/bin/touch "$temp_home/Library/LaunchAgents/com.dhseo.macdog.monitor.plist"
  MACDOG_STATUS_APP_DEST="$temp_home/Applications/MacDog.app" HOME="$temp_home" "$stage/Check Install Status.command" >/dev/null
  rm -rf "$temp_home"
  trap - RETURN
}

output="$("$ROOT_DIR/script/package_release.sh" --dry-run)"
require_contains "$output" "MacDog release package dry run"
require_contains "$output" "Payload:"
require_contains "$output" "MacDog.app"
require_contains "$output" "MacDog.app (includes bundled codex-usage)"
require_contains "$output" "Applications symlink"
require_not_contains "$output" "  - bin/codex-usage"
require_contains "$output" "Install MacDog.command"
require_contains "$output" "Uninstall MacDog.command"
require_contains "$output" "Check Install Status.command"
require_contains "$output" "RELEASE_NOTES_DRAFT.md"
require_contains "$output" "SHA-256 path:"
require_contains "$output" "Drag install:"
require_contains "$output" "Optional full local install:"
require_contains "$output" "Privileged helper: install or remove from the MacDog Settings tab"
require_contains "$output" "Double-click uninstall: Uninstall MacDog.command removes the local command-installed app, CLI symlink, user LaunchAgents, and cache files."
require_contains "$output" "Privileged helper cleanup: remove the optional helper from the MacDog Settings tab"
require_contains "$output" "Post-install check: Check Install Status.command"
require_not_contains "$output" "Install Privileged Helper.command"
require_not_contains "$output" "Uninstall Privileged Helper.command"
require_contains "$output" "Developer ID signing and notarization are not performed"
require_contains "$output" "Gatekeeper: unsigned candidates are local validation artifacts"
require_contains "$output" "GitHub Release:"
require_contains "$output" "Cache request timeout: 5 seconds"
require_contains "$output" "Cache prime timeout: 12 seconds"

if [[ -d "$APP_BUNDLE" ]]; then
  version="verify"
  stage="$ROOT_DIR/dist/release/MacDog-$version"
  dmg_path="$ROOT_DIR/dist/release/MacDog-$version.dmg"
  checksum_path="$dmg_path.sha256"
  trap 'rm -rf "$stage"; rm -f "$dmg_path" "$checksum_path"' EXIT
  stage_output="$(MACDOG_RELEASE_VERSION="$version" "$ROOT_DIR/script/package_release.sh" --skip-build --no-dmg)"

  require_contains "$stage_output" "$stage"
  [[ -d "$stage/MacDog.app" ]] || die "staged app bundle missing: $stage/MacDog.app"
  [[ -L "$stage/Applications" ]] || die "staged Applications symlink missing"
  [[ "$(readlink "$stage/Applications")" == "/Applications" ]] || die "staged Applications symlink must point to /Applications"
  [[ -x "$stage/MacDog.app/Contents/MacOS/codex-usage" ]] || die "bundled CLI missing or not executable: $stage/MacDog.app/Contents/MacOS/codex-usage"
  [[ ! -e "$stage/bin/codex-usage" ]] || die "staged standalone CLI must not exist: $stage/bin/codex-usage"
  [[ -x "$stage/Install MacDog.command" ]] || die "staged installer command missing or not executable"
  [[ -x "$stage/Uninstall MacDog.command" ]] || die "staged uninstall command missing or not executable"
  [[ -x "$stage/Check Install Status.command" ]] || die "staged install status command missing or not executable"
  [[ ! -e "$stage/Install Privileged Helper.command" ]] || die "staged helper installer command must not exist"
  [[ ! -e "$stage/Uninstall Privileged Helper.command" ]] || die "staged helper uninstaller command must not exist"
  [[ -f "$stage/README_FIRST.txt" ]] || die "staged README missing"
  [[ -f "$stage/RELEASE_NOTES_DRAFT.md" ]] || die "staged release notes draft missing"

  /usr/bin/grep -Fq "Drag \"MacDog.app\" to \"Applications\"" "$stage/README_FIRST.txt" || die "staged README drag install copy missing"
  /usr/bin/grep -Fq "MacDog Settings" "$stage/README_FIRST.txt" || die "staged README helper settings copy missing"
  /usr/bin/grep -Fq "Uninstall MacDog.command" "$stage/README_FIRST.txt" || die "staged README uninstall command missing"
  /usr/bin/grep -Fq "cache files" "$stage/README_FIRST.txt" || die "staged README cache cleanup copy missing"
  if /usr/bin/grep -Fq "Privileged Helper.command" "$stage/README_FIRST.txt"; then
    die "staged README must not reference helper command files"
  fi
  /usr/bin/grep -Fq "Check Install Status.command" "$stage/README_FIRST.txt" || die "staged README status checker missing"
  /usr/bin/grep -Fq "Gatekeeper may block first launch" "$stage/README_FIRST.txt" || die "staged README Gatekeeper warning missing"
  /usr/bin/grep -Fq "notarization" "$stage/RELEASE_NOTES_DRAFT.md" || die "release notes notarization gate missing"
  /usr/bin/grep -Fq "Drag \`MacDog.app\` to \`Applications\`" "$stage/RELEASE_NOTES_DRAFT.md" || die "release notes drag install copy missing"
  /usr/bin/grep -Fq "MacDog Settings" "$stage/RELEASE_NOTES_DRAFT.md" || die "release notes helper settings copy missing"
  /usr/bin/grep -Fq "Check Install Status.command" "$stage/RELEASE_NOTES_DRAFT.md" || die "release notes status checker missing"
  /usr/bin/grep -Fq "Uninstall MacDog.command" "$stage/RELEASE_NOTES_DRAFT.md" || die "release notes uninstall command missing"
  /usr/bin/grep -Fq "cache files" "$stage/RELEASE_NOTES_DRAFT.md" || die "release notes cache cleanup copy missing"
  if /usr/bin/grep -Fq "Privileged Helper.command" "$stage/RELEASE_NOTES_DRAFT.md"; then
    die "release notes must not reference helper command files"
  fi
  /usr/bin/grep -Fq "MacDog Settings" "$stage/Install MacDog.command" || die "installer helper settings handoff missing"
  /usr/bin/grep -Fq "Check Install Status.command" "$stage/Install MacDog.command" || die "installer status handoff missing"
  /usr/bin/grep -Fq 'LOGIN_LAUNCH_KEY="loginLaunchEnabled"' "$stage/Install MacDog.command" || die "installer login launch preference key missing"
  /usr/bin/grep -Fq 'login_launch_enabled()' "$stage/Install MacDog.command" || die "installer login launch preference reader missing"
  /usr/bin/grep -Fq 'launchctl bootstrap "gui/$UID_VALUE"' "$stage/Install MacDog.command" || die "installer LaunchAgent bootstrap missing"
  /usr/bin/grep -Fq 'pkill -9 -x "$APP_NAME"' "$stage/Install MacDog.command" || die "installer sleep-safe app restart step missing"
  /usr/bin/grep -Fq '<string>--timeout</string>' "$stage/Install MacDog.command" || die "installer cache agent timeout argument missing"
  /usr/bin/grep -Fq 'ln -s "$APP_CLI_DEST" "$CLI_DEST"' "$stage/Install MacDog.command" || die "installer CLI symlink step missing"
  /usr/bin/grep -Fq '<string>$APP_CLI_DEST</string>' "$stage/Install MacDog.command" || die "installer cache agent bundled CLI path missing"
  /usr/bin/grep -Fq 'run_with_timeout "$CACHE_PRIME_TIMEOUT_SECONDS" "$APP_CLI_DEST" status --write-cache --timeout "$CACHE_REQUEST_TIMEOUT_SECONDS"' "$stage/Install MacDog.command" || die "installer cache prime timeout wrapper missing"
  /usr/bin/grep -Fq 'Continue with MacDog uninstall?' "$stage/Uninstall MacDog.command" || die "uninstaller confirmation prompt missing"
  /usr/bin/grep -Fq 'Application Support/MacDog' "$stage/Uninstall MacDog.command" || die "uninstaller Application Support cache cleanup missing"
  /usr/bin/grep -Fq 'Group Containers/group.com.dhseo.macdog.MacDog' "$stage/Uninstall MacDog.command" || die "uninstaller shared cache cleanup missing"
  /usr/bin/grep -Fq 'rmdir "$APP_CACHE_DIR" "$SHARED_CACHE_DIR"' "$stage/Uninstall MacDog.command" || die "uninstaller empty cache directory cleanup missing"
  /usr/bin/grep -Fq 'Optional helper was not changed.' "$stage/Uninstall MacDog.command" || die "user uninstaller helper boundary missing"
  /usr/bin/grep -Fq 'MacDog install status' "$stage/Check Install Status.command" || die "status checker title missing"
  /usr/bin/grep -Fq 'bundled CLI installed' "$stage/Check Install Status.command" || die "status checker bundled CLI check missing"
  /usr/bin/grep -Fq 'terminal CLI points to bundled CLI' "$stage/Check Install Status.command" || die "status checker CLI symlink check missing"
  /usr/bin/grep -Fq 'cache LaunchAgent runs bundled CLI' "$stage/Check Install Status.command" || die "status checker cache executable check missing"
  /usr/bin/grep -Fq 'privileged helper is optional' "$stage/Check Install Status.command" || die "status checker optional helper copy missing"
  /usr/bin/grep -Fq 'installed app matches bundled release payload' "$stage/Check Install Status.command" || die "status checker freshness success copy missing"
  /usr/bin/grep -Fq 'installed app differs from bundled release payload' "$stage/Check Install Status.command" || die "status checker freshness failure copy missing"
  /usr/bin/grep -Fq 'running MacDog process count' "$stage/Check Install Status.command" || die "status checker running process count missing"
  /usr/bin/grep -Fq 'running MacDog uses a different binary' "$stage/Check Install Status.command" || die "status checker running process freshness warning missing"
  /usr/bin/grep -Fq 'bundle_manifest' "$stage/Check Install Status.command" || die "status checker app payload comparison missing"
  require_line_count "$stage/Install MacDog.command" '^<plist version="1\.0">$' 2
  bash -n "$stage/Install MacDog.command"
  bash -n "$stage/Uninstall MacDog.command"
  bash -n "$stage/Check Install Status.command"
  with_temp_home

  if /usr/bin/grep -Eq 'PrivilegedHelperTools|LaunchDaemons|SMJobBless|sudo ' "$stage/Install MacDog.command"; then
    die "installer command unexpectedly contains privileged helper installation material"
  fi
  if /usr/bin/grep -Eq 'PrivilegedHelperTools|LaunchDaemons|SMJobBless|sudo ' "$stage/Uninstall MacDog.command"; then
    die "uninstaller command unexpectedly contains privileged helper cleanup material"
  fi
  if find "$stage" -maxdepth 1 -type f -name '*.command' -print0 | xargs -0 /usr/bin/grep -Fq '/usr/bin/osascript'; then
    die "release command files must not launch osascript approval prompts"
  fi

  rm -f "$dmg_path" "$checksum_path"
  MACDOG_RELEASE_VERSION="$version" "$ROOT_DIR/script/package_release.sh" --skip-build >/dev/null
  [[ -f "$dmg_path" ]] || die "release DMG missing after package generation"
  [[ -f "$checksum_path" ]] || die "release checksum missing after package generation"
  checksum_line="$(cat "$checksum_path")"
  [[ "$checksum_line" == *"  MacDog-$version.dmg" ]] || die "checksum file must use DMG basename"
  [[ "$checksum_line" != *"$ROOT_DIR"* ]] || die "checksum file must not contain build-machine absolute path"
  (
    cd "$ROOT_DIR/dist/release"
    /usr/bin/shasum -a 256 -c "$(basename "$checksum_path")" >/dev/null
  )
  rm -f "$dmg_path" "$checksum_path"
else
  echo "Release packaging stage verification skipped: dist/MacDog.app missing"
fi

echo "Release packaging verification ok"
