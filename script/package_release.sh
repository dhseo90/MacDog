#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="MacDog"
VERSION="${MACDOG_RELEASE_VERSION:-0.1.0}"
APP_BUNDLE="$ROOT_DIR/dist/$APP_NAME.app"
RELEASE_ROOT="$ROOT_DIR/dist/release"
STAGE_DIR="$RELEASE_ROOT/$APP_NAME-$VERSION"
DMG_PATH="$RELEASE_ROOT/$APP_NAME-$VERSION.dmg"
CHECKSUM_PATH="$DMG_PATH.sha256"
DRY_RUN=0
SKIP_BUILD=0
CREATE_DMG=1
REQUIRE_SIGNED_HELPER_HOST="${MACDOG_REQUIRE_SIGNED_HELPER_HOST:-0}"

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
XCRUN="/usr/bin/xcrun"

usage() {
  cat <<USAGE
usage: $0 [--dry-run] [--skip-build] [--no-dmg] [--version VERSION]

Build a local GitHub Release candidate payload.
The generated DMG is not notarized and is intended for local validation.
Set MACDOG_REQUIRE_SIGNED_HELPER_HOST=1 for public stable payloads so the
privileged helper installer refuses unsigned/ad-hoc host apps.
USAGE
}

die() {
  echo "error: $*" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --skip-build) SKIP_BUILD=1 ;;
    --no-dmg) CREATE_DMG=0 ;;
    --version)
      shift
      [[ $# -gt 0 ]] || die "--version requires a value"
      VERSION="$1"
      STAGE_DIR="$RELEASE_ROOT/$APP_NAME-$VERSION"
      DMG_PATH="$RELEASE_ROOT/$APP_NAME-$VERSION.dmg"
      CHECKSUM_PATH="$DMG_PATH.sha256"
      ;;
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

if [[ "$DRY_RUN" == "1" ]]; then
  cat <<DRYRUN
MacDog release package dry run
Version: $VERSION
Build app bundle: $([[ "$SKIP_BUILD" == "1" ]] && echo "skipped" || echo "$ROOT_DIR/script/build_and_run.sh --no-run")
App source: $APP_BUNDLE
Stage directory: $STAGE_DIR
DMG path: $DMG_PATH
SHA-256 path: $CHECKSUM_PATH
Payload:
  - MacDog.app
  - bin/codex-usage
  - Install MacDog.command
  - Install Privileged Helper.command
  - Uninstall MacDog.command
  - Uninstall Privileged Helper.command
  - Check Install Status.command
  - README_FIRST.txt
  - RELEASE_NOTES_DRAFT.md
Double-click install: Install MacDog.command copies app/CLI, writes user LaunchAgents, and opens MacDog.
Privileged helper: Install Privileged Helper.command installs the bundled helper after explicit administrator approval.
Helper host requirement: $([[ "$REQUIRE_SIGNED_HELPER_HOST" == "1" ]] && echo "Developer ID signed host required" || echo "signed host preferred; local ad-hoc host allowed for validation")
Double-click uninstall: Uninstall MacDog.command removes the app, CLI, user LaunchAgents, and cache files.
Privileged helper cleanup: Uninstall Privileged Helper.command removes the optional helper after administrator approval.
Post-install check: Check Install Status.command verifies app, CLI, user LaunchAgents, and optional helper state.
Signing: local ad-hoc build only; Developer ID signing and notarization are not performed.
Gatekeeper: unsigned candidates are local validation artifacts and must not be published as public stable releases.
GitHub Release: upload DMG only after signing/notarization gate is satisfied for public distribution.
DRYRUN
  exit 0
fi

cd "$ROOT_DIR"

if [[ "$SKIP_BUILD" != "1" ]]; then
  ./script/build_and_run.sh --no-run >/dev/null
fi

./script/verify_app_bundle.sh "$APP_BUNDLE" >/dev/null

build_bin="$("$XCRUN" swift build -c release --show-bin-path)"
CLI_BINARY="$build_bin/codex-usage"
[[ -x "$CLI_BINARY" ]] || die "codex-usage release binary missing: $CLI_BINARY"

rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR/bin"
/usr/bin/ditto --norsrc --noextattr "$APP_BUNDLE" "$STAGE_DIR/$APP_NAME.app"
/usr/bin/xattr -cr "$STAGE_DIR/$APP_NAME.app" >/dev/null 2>&1 || true
cp "$CLI_BINARY" "$STAGE_DIR/bin/codex-usage"
chmod +x "$STAGE_DIR/bin/codex-usage"

cat >"$STAGE_DIR/README_FIRST.txt" <<README
MacDog $VERSION

1. Double-click "Install MacDog.command" to install MacDog.app, codex-usage, and user LaunchAgents.
2. This local release candidate is unsigned and not notarized. macOS Gatekeeper may block first launch.
3. Double-click "Install Privileged Helper.command" to install the helper for full closed-lid sleep prevention.
4. The helper installer explains the system locations it changes before asking for administrator approval.
5. Double-click "Check Install Status.command" after installation to verify app, CLI, LaunchAgents, and optional helper state.
6. Double-click "Uninstall MacDog.command" to remove the app, CLI, user LaunchAgents, and cache files.
7. Double-click "Uninstall Privileged Helper.command" only if you installed the optional helper and want to remove it.
8. This local release candidate is intended for local unsigned validation.
README

cat >"$STAGE_DIR/RELEASE_NOTES_DRAFT.md" <<NOTES
# MacDog $VERSION Release Notes Draft

Status: unsigned local release candidate.

## Install

- Open the DMG.
- Double-click \`Install MacDog.command\` to install the app, CLI, and user LaunchAgents.
- Double-click \`Install Privileged Helper.command\` only if you need closed-lid sleep prevention without repeated password prompts.
- Double-click \`Check Install Status.command\` after installation.

## Security And Gatekeeper

- This candidate is ad-hoc signed for local validation and is not notarized.
- Do not publish it as a public stable release until Developer ID signing, hardened runtime, notarization, stapling, and Gatekeeper checks pass.
- The privileged helper installer changes \`/Library/PrivilegedHelperTools/com.dhseo.macdog.helper\` and \`/Library/LaunchDaemons/com.dhseo.macdog.helper.plist\` after administrator approval.

## Supported Scope

- Codex usage popover and CLI.
- Mac resource, sleep-prevention, and native Charge Limit UI.
- Native Charge Limit requires Apple silicon and macOS 26.4 or later.

## Uninstall

- Double-click \`Uninstall MacDog.command\` to remove the app, CLI, user LaunchAgents, and cache files.
- Double-click \`Uninstall Privileged Helper.command\` to remove the optional helper after administrator approval.
- Source checkout uninstall path remains available: \`./script/uninstall.sh --with-helper\`
NOTES

cat >"$STAGE_DIR/Install MacDog.command" <<'INSTALL'
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="MacDog"
BUNDLE_ID="com.dhseo.macdog.MacDog"
APP_SOURCE="$SCRIPT_DIR/$APP_NAME.app"
CLI_SOURCE="$SCRIPT_DIR/bin/codex-usage"
APP_DEST="$HOME/Applications/$APP_NAME.app"
BIN_DIR="$HOME/bin"
CLI_DEST="$BIN_DIR/codex-usage"
LAUNCH_AGENT_DIR="$HOME/Library/LaunchAgents"
LOG_DIR="$HOME/Library/Logs/MacDog"
CACHE_LABEL="com.dhseo.macdog.usage-cache"
MONITOR_LABEL="com.dhseo.macdog.monitor"
CACHE_PLIST="$LAUNCH_AGENT_DIR/$CACHE_LABEL.plist"
MONITOR_PLIST="$LAUNCH_AGENT_DIR/$MONITOR_LABEL.plist"
UID_VALUE="$(id -u)"

die() {
  echo "error: $*" >&2
  exit 1
}

macdog_owns_sleep_disabled() {
  [[ "$(/usr/bin/defaults read "$BUNDLE_ID" closedLidSleepDisabledByMacDog 2>/dev/null || true)" == "1" ]] || return 1
  /usr/bin/pmset -g live | /usr/bin/grep -q $'SleepDisabled\t\t1'
}

stop_running_app_for_update() {
  if macdog_owns_sleep_disabled; then
    /usr/bin/pkill -9 -x "$APP_NAME" >/dev/null 2>&1 || true
  else
    /usr/bin/pkill -x "$APP_NAME" >/dev/null 2>&1 || true
  fi
}

[[ -d "$APP_SOURCE" ]] || die "missing app bundle: $APP_SOURCE"
[[ -x "$CLI_SOURCE" ]] || die "missing CLI binary: $CLI_SOURCE"

mkdir -p "$HOME/Applications" "$BIN_DIR" "$LAUNCH_AGENT_DIR" "$LOG_DIR"
/bin/launchctl bootout "gui/$UID_VALUE" "$CACHE_PLIST" >/dev/null 2>&1 || true
/bin/launchctl bootout "gui/$UID_VALUE" "$MONITOR_PLIST" >/dev/null 2>&1 || true
stop_running_app_for_update

rm -rf "$APP_DEST"
/usr/bin/ditto --norsrc --noextattr "$APP_SOURCE" "$APP_DEST"
/usr/bin/xattr -cr "$APP_DEST" >/dev/null 2>&1 || true
/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_DEST" >/dev/null

cp "$CLI_SOURCE" "$CLI_DEST"
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

"$CLI_DEST" status --write-cache >/dev/null || true
/bin/launchctl bootstrap "gui/$UID_VALUE" "$CACHE_PLIST"
/bin/launchctl bootstrap "gui/$UID_VALUE" "$MONITOR_PLIST"
/usr/bin/open "$APP_DEST"

echo "Installed MacDog"
echo "App: $APP_DEST"
echo "CLI: $CLI_DEST"
echo "LaunchAgents: $CACHE_PLIST, $MONITOR_PLIST"
echo "For full closed-lid sleep prevention, run Install Privileged Helper.command."
echo "Then run Check Install Status.command to verify the install."
INSTALL
chmod +x "$STAGE_DIR/Install MacDog.command"

cat >"$STAGE_DIR/Install Privileged Helper.command" <<'HELPER'
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_SOURCE="$SCRIPT_DIR/MacDog.app"
HELPER_LABEL="com.dhseo.macdog.helper"
HELPER_EXECUTABLE="MacDogPrivilegedHelper"
HELPER_MACH_SERVICE="$HELPER_LABEL.xpc"
HELPER_SOURCE="$APP_SOURCE/Contents/Library/LaunchServices/$HELPER_EXECUTABLE"
HELPER_TOOL_DEST="/Library/PrivilegedHelperTools/$HELPER_LABEL"
HELPER_PLIST_DEST="/Library/LaunchDaemons/$HELPER_LABEL.plist"
HELPER_LOG_DIR="/Library/Logs/MacDog"
REQUIRE_SIGNED_HELPER_HOST="__MACDOG_REQUIRE_SIGNED_HELPER_HOST__"

die() {
  echo "error: $*" >&2
  exit 1
}

bash_quote() {
  printf '%q' "$1"
}

apple_script_literal() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  printf '"%s"' "$value"
}

xml_escape() {
  local value="$1"
  value="${value//&/&amp;}"
  value="${value//\"/&quot;}"
  value="${value//\'/&apos;}"
  value="${value//</&lt;}"
  value="${value//>/&gt;}"
  printf '%s' "$value"
}

detect_host_team_identifier() {
  local bundle_path="$1"
  local output
  output="$(/usr/bin/codesign -dv "$bundle_path" 2>&1 || true)"
  local team_id
  team_id="$(printf '%s\n' "$output" | awk -F= '/^TeamIdentifier=/{print $2; exit}')"
  if [[ -n "$team_id" && "$team_id" != "not set" ]]; then
    printf '%s' "$team_id"
  fi
}

write_helper_launch_daemon_plist() {
  local target="$1"
  local host_team_id="$2"
  local allow_adhoc_host="$3"

  cat >"$target" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$HELPER_LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>$HELPER_TOOL_DEST</string>
    <string>--run-xpc-service</string>
  </array>
  <key>MachServices</key>
  <dict>
    <key>$HELPER_MACH_SERVICE</key>
    <true/>
  </dict>
PLIST

  if [[ -n "$host_team_id" || "$allow_adhoc_host" == "1" ]]; then
    cat >>"$target" <<PLIST
  <key>EnvironmentVariables</key>
  <dict>
PLIST
    if [[ -n "$host_team_id" ]]; then
      cat >>"$target" <<PLIST
    <key>MACDOG_HELPER_HOST_TEAM_ID</key>
    <string>$(xml_escape "$host_team_id")</string>
PLIST
    fi
    if [[ "$allow_adhoc_host" == "1" ]]; then
      cat >>"$target" <<PLIST
    <key>MACDOG_HELPER_ALLOW_ADHOC_HOST</key>
    <string>1</string>
PLIST
    fi
    cat >>"$target" <<PLIST
  </dict>
PLIST
  fi

  cat >>"$target" <<PLIST
  <key>RunAtLoad</key>
  <true/>
  <key>StandardOutPath</key>
  <string>$HELPER_LOG_DIR/helper.out.log</string>
  <key>StandardErrorPath</key>
  <string>$HELPER_LOG_DIR/helper.err.log</string>
</dict>
</plist>
PLIST
}

[[ -d "$APP_SOURCE" ]] || die "missing app bundle: $APP_SOURCE"
[[ -x "$HELPER_SOURCE" ]] || die "missing helper executable: $HELPER_SOURCE"
/usr/bin/codesign --verify --strict --verbose=2 "$HELPER_SOURCE" >/dev/null

host_team_id="${MACDOG_HELPER_HOST_TEAM_ID:-$(detect_host_team_identifier "$APP_SOURCE")}"
allow_adhoc_host=0
if [[ -z "$host_team_id" ]]; then
  if [[ "$REQUIRE_SIGNED_HELPER_HOST" == "1" ]]; then
    die "public stable helper install requires a Developer ID signed MacDog.app with TeamIdentifier"
  fi
  allow_adhoc_host=1
fi

cat <<NOTICE
MacDog privileged helper installer

This installs an opt-in LaunchDaemon used only for closed-lid sleep prevention.
It changes these system locations:
  - $HELPER_TOOL_DEST
  - $HELPER_PLIST_DEST
  - $HELPER_LOG_DIR

After this one administrator approval, MacDog can change SleepDisabled through XPC
without asking for your password on every sleep-prevention setting change.
NOTICE

if [[ -n "$host_team_id" ]]; then
  echo "Helper host requirement: TeamIdentifier $host_team_id"
else
  echo "Helper host requirement: local unsigned/ad-hoc MacDog.app"
fi

printf "Continue with privileged helper install? [y/N] "
read -r confirm
case "$confirm" in
  y|Y|yes|YES) ;;
  *)
    echo "Cancelled privileged helper install."
    exit 0
    ;;
esac

temp_plist="$(/usr/bin/mktemp "${TMPDIR:-/tmp}/macdog-helper.XXXXXX")"
root_script="$(/usr/bin/mktemp "${TMPDIR:-/tmp}/macdog-helper-install.XXXXXX")"
trap 'rm -f "$temp_plist" "$root_script"' EXIT

write_helper_launch_daemon_plist "$temp_plist" "$host_team_id" "$allow_adhoc_host"
/usr/bin/plutil -lint "$temp_plist" >/dev/null

cat >"$root_script" <<ROOT
#!/usr/bin/env bash
set -euo pipefail
/bin/launchctl bootout system $(bash_quote "$HELPER_PLIST_DEST") >/dev/null 2>&1 || true
/bin/mkdir -p /Library/PrivilegedHelperTools /Library/LaunchDaemons $(bash_quote "$HELPER_LOG_DIR")
/usr/bin/install -o root -g wheel -m 755 $(bash_quote "$HELPER_SOURCE") $(bash_quote "$HELPER_TOOL_DEST")
/usr/bin/install -o root -g wheel -m 644 $(bash_quote "$temp_plist") $(bash_quote "$HELPER_PLIST_DEST")
/bin/launchctl bootstrap system $(bash_quote "$HELPER_PLIST_DEST")
/bin/launchctl print system/$HELPER_LABEL >/dev/null
/usr/bin/codesign --verify --strict --verbose=2 $(bash_quote "$HELPER_TOOL_DEST") >/dev/null
ROOT
chmod +x "$root_script"

/usr/bin/osascript -e "do shell script $(apple_script_literal "$root_script") with administrator privileges"

echo "Installed MacDog privileged helper"
echo "Privileged helper: $HELPER_TOOL_DEST"
echo "LaunchDaemon: $HELPER_PLIST_DEST"
echo "Run Check Install Status.command to verify the helper state."
HELPER
/usr/bin/perl -0pi -e "s/__MACDOG_REQUIRE_SIGNED_HELPER_HOST__/$REQUIRE_SIGNED_HELPER_HOST/g" "$STAGE_DIR/Install Privileged Helper.command"
chmod +x "$STAGE_DIR/Install Privileged Helper.command"

cat >"$STAGE_DIR/Uninstall MacDog.command" <<'UNINSTALL'
#!/usr/bin/env bash
set -euo pipefail

APP_NAME="MacDog"
BUNDLE_ID="com.dhseo.macdog.MacDog"
APP_DEST="$HOME/Applications/$APP_NAME.app"
CLI_DEST="$HOME/bin/codex-usage"
UID_VALUE="$(id -u)"
LAUNCH_AGENT_DIR="$HOME/Library/LaunchAgents"
CACHE_LABEL="com.dhseo.macdog.usage-cache"
MONITOR_LABEL="com.dhseo.macdog.monitor"
CACHE_PLIST="$LAUNCH_AGENT_DIR/$CACHE_LABEL.plist"
MONITOR_PLIST="$LAUNCH_AGENT_DIR/$MONITOR_LABEL.plist"
APP_CACHE_DIR="$HOME/Library/Application Support/MacDog"
APP_CACHE_FILE="$APP_CACHE_DIR/usage.json"
SHARED_CACHE_DIR="$HOME/Library/Group Containers/group.com.dhseo.macdog.MacDog"
SHARED_CACHE_FILE="$SHARED_CACHE_DIR/usage.json"

macdog_owns_sleep_disabled() {
  [[ "$(/usr/bin/defaults read "$BUNDLE_ID" closedLidSleepDisabledByMacDog 2>/dev/null || true)" == "1" ]] || return 1
  /usr/bin/pmset -g live | /usr/bin/grep -q $'SleepDisabled\t\t1'
}

stop_running_app_for_update() {
  if macdog_owns_sleep_disabled; then
    /usr/bin/pkill -9 -x "$APP_NAME" >/dev/null 2>&1 || true
  else
    /usr/bin/pkill -x "$APP_NAME" >/dev/null 2>&1 || true
  fi
}

cat <<NOTICE
MacDog user uninstall

This removes:
  - $APP_DEST
  - $CLI_DEST
  - $CACHE_PLIST
  - $MONITOR_PLIST
  - $APP_CACHE_FILE
  - $SHARED_CACHE_FILE

It preserves MacDog UserDefaults preferences and does not remove the optional
privileged helper. Run Uninstall Privileged Helper.command separately if needed.
NOTICE

printf "Continue with MacDog uninstall? [y/N] "
read -r confirm
case "$confirm" in
  y|Y|yes|YES) ;;
  *)
    echo "Cancelled MacDog uninstall."
    exit 0
    ;;
esac

/bin/launchctl bootout "gui/$UID_VALUE" "$CACHE_PLIST" >/dev/null 2>&1 || true
/bin/launchctl bootout "gui/$UID_VALUE" "$MONITOR_PLIST" >/dev/null 2>&1 || true
stop_running_app_for_update

rm -f "$CACHE_PLIST" "$MONITOR_PLIST" "$CLI_DEST" "$APP_CACHE_FILE" "$SHARED_CACHE_FILE"
rm -rf "$APP_DEST"
rmdir "$APP_CACHE_DIR" "$SHARED_CACHE_DIR" >/dev/null 2>&1 || true

echo "Uninstalled MacDog user components"
echo "Optional helper was not changed."
echo "Run Check Install Status.command to verify the remaining state."
UNINSTALL
chmod +x "$STAGE_DIR/Uninstall MacDog.command"

cat >"$STAGE_DIR/Uninstall Privileged Helper.command" <<'UNHELPER'
#!/usr/bin/env bash
set -euo pipefail

HELPER_LABEL="com.dhseo.macdog.helper"
HELPER_TOOL_DEST="/Library/PrivilegedHelperTools/$HELPER_LABEL"
HELPER_PLIST_DEST="/Library/LaunchDaemons/$HELPER_LABEL.plist"

apple_script_literal() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  printf '"%s"' "$value"
}

bash_quote() {
  printf '%q' "$1"
}

cat <<NOTICE
MacDog privileged helper uninstall

This removes the optional helper from these system locations:
  - $HELPER_TOOL_DEST
  - $HELPER_PLIST_DEST

Administrator approval is required. The MacDog app, CLI, and user LaunchAgents
are not removed by this command.
NOTICE

printf "Continue with privileged helper uninstall? [y/N] "
read -r confirm
case "$confirm" in
  y|Y|yes|YES) ;;
  *)
    echo "Cancelled privileged helper uninstall."
    exit 0
    ;;
esac

root_script="$(/usr/bin/mktemp "${TMPDIR:-/tmp}/macdog-helper-uninstall.XXXXXX")"
trap 'rm -f "$root_script"' EXIT

cat >"$root_script" <<ROOT
#!/usr/bin/env bash
set -euo pipefail
/bin/launchctl bootout system $(bash_quote "$HELPER_PLIST_DEST") >/dev/null 2>&1 || true
/bin/rm -f $(bash_quote "$HELPER_TOOL_DEST") $(bash_quote "$HELPER_PLIST_DEST")
ROOT
chmod +x "$root_script"

/usr/bin/osascript -e "do shell script $(apple_script_literal "$root_script") with administrator privileges"

echo "Removed MacDog privileged helper"
echo "Privileged helper: $HELPER_TOOL_DEST"
echo "LaunchDaemon: $HELPER_PLIST_DEST"
echo "Run Check Install Status.command to verify the remaining state."
UNHELPER
chmod +x "$STAGE_DIR/Uninstall Privileged Helper.command"

cat >"$STAGE_DIR/Check Install Status.command" <<'STATUS'
#!/usr/bin/env bash
set -u

APP_NAME="MacDog"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_SOURCE="$SCRIPT_DIR/$APP_NAME.app"
APP_DEST="$HOME/Applications/$APP_NAME.app"
CLI_DEST="$HOME/bin/codex-usage"
UID_VALUE="$(id -u)"
CACHE_LABEL="com.dhseo.macdog.usage-cache"
MONITOR_LABEL="com.dhseo.macdog.monitor"
CACHE_PLIST="$HOME/Library/LaunchAgents/$CACHE_LABEL.plist"
MONITOR_PLIST="$HOME/Library/LaunchAgents/$MONITOR_LABEL.plist"
HELPER_LABEL="com.dhseo.macdog.helper"
HELPER_TOOL_DEST="/Library/PrivilegedHelperTools/$HELPER_LABEL"
HELPER_PLIST_DEST="/Library/LaunchDaemons/$HELPER_LABEL.plist"
required_failures=0

ok() {
  printf "OK      %s\n" "$1"
}

warn() {
  printf "WARN    %s\n" "$1"
}

missing_required() {
  printf "MISSING %s\n" "$1"
  required_failures=$((required_failures + 1))
}

bundle_manifest() {
  local bundle="$1"
  (
    cd "$bundle" || exit 1
    /usr/bin/find . -type f \
      ! -path '*/_CodeSignature/*' \
      ! -name '.DS_Store' \
      -print0 |
      while IFS= read -r -d '' file; do
        local path="${file#./}"
        local hash
        hash="$(/usr/bin/shasum -a 256 "$file" | /usr/bin/awk '{print $1}')"
        printf '%s  %s\n' "$hash" "$path"
      done |
      /usr/bin/sort
  )
}

app_payload_matches_source() {
  local expected_manifest
  local actual_manifest
  expected_manifest="$(/usr/bin/mktemp "${TMPDIR:-/tmp}/macdog-expected.XXXXXX")"
  actual_manifest="$(/usr/bin/mktemp "${TMPDIR:-/tmp}/macdog-actual.XXXXXX")"
  bundle_manifest "$APP_SOURCE" >"$expected_manifest"
  bundle_manifest "$APP_DEST" >"$actual_manifest"

  if /usr/bin/cmp -s "$expected_manifest" "$actual_manifest"; then
    rm -f "$expected_manifest" "$actual_manifest"
    return 0
  fi

  rm -f "$expected_manifest" "$actual_manifest"
  return 1
}

print_running_app_state() {
  local output
  local status
  output="$(pgrep -x "$APP_NAME" 2>&1)" || status=$?
  status="${status:-0}"

  if [[ "$status" == "0" ]]; then
    local count
    count="$(printf '%s\n' "$output" | /usr/bin/grep -Ec '^[0-9]+$' || true)"
    ok "running MacDog process count: $count"
    while IFS= read -r pid; do
      [[ "$pid" =~ ^[0-9]+$ ]] || continue
      local command_path
      command_path="$(/bin/ps -p "$pid" -o comm= 2>/dev/null | /usr/bin/sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
      if [[ -z "$command_path" ]]; then
        warn "running MacDog process path unknown: pid $pid"
      elif [[ "$command_path" == "$APP_DEST/Contents/MacOS/$APP_NAME" ]]; then
        ok "running MacDog uses installed app binary: pid $pid"
      else
        warn "running MacDog uses a different binary: pid $pid actual $command_path"
      fi
    done <<<"$output"
  elif [[ "$status" == "1" ]]; then
    warn "MacDog is not currently running"
  else
    warn "MacDog process state unknown: $output"
  fi
}

echo "MacDog install status"
echo

if [[ -x "$APP_DEST/Contents/MacOS/$APP_NAME" ]]; then
  ok "app installed: $APP_DEST"
else
  missing_required "app executable: $APP_DEST/Contents/MacOS/$APP_NAME"
fi

if [[ -d "$APP_SOURCE" && -d "$APP_DEST" ]]; then
  if app_payload_matches_source; then
    ok "installed app matches bundled release payload"
  else
    missing_required "installed app differs from bundled release payload"
  fi
else
  warn "release payload app is not available for freshness check: $APP_SOURCE"
fi

print_running_app_state

if [[ -x "$CLI_DEST" ]]; then
  ok "CLI installed: $CLI_DEST"
else
  missing_required "CLI executable: $CLI_DEST"
fi

if [[ -f "$CACHE_PLIST" ]]; then
  ok "cache LaunchAgent plist: $CACHE_PLIST"
else
  missing_required "cache LaunchAgent plist: $CACHE_PLIST"
fi

if [[ -f "$MONITOR_PLIST" ]]; then
  ok "monitor LaunchAgent plist: $MONITOR_PLIST"
else
  missing_required "monitor LaunchAgent plist: $MONITOR_PLIST"
fi

if /bin/launchctl print "gui/$UID_VALUE/$CACHE_LABEL" >/dev/null 2>&1; then
  ok "cache LaunchAgent loaded"
else
  warn "cache LaunchAgent is not loaded"
fi

if /bin/launchctl print "gui/$UID_VALUE/$MONITOR_LABEL" >/dev/null 2>&1; then
  ok "monitor LaunchAgent loaded"
else
  warn "monitor LaunchAgent is not loaded"
fi

if [[ -x "$HELPER_TOOL_DEST" && -f "$HELPER_PLIST_DEST" ]]; then
  ok "privileged helper files installed"
  if /bin/launchctl print "system/$HELPER_LABEL" >/dev/null 2>&1; then
    ok "privileged helper loaded"
  else
    warn "privileged helper files exist but LaunchDaemon is not loaded"
  fi
else
  warn "privileged helper is optional and not installed"
fi

echo
if [[ "$required_failures" -eq 0 ]]; then
  echo "MacDog required install checks passed."
  exit 0
fi

echo "MacDog required install checks failed: $required_failures"
exit 1
STATUS
chmod +x "$STAGE_DIR/Check Install Status.command"

if [[ "$CREATE_DMG" == "1" ]]; then
  mkdir -p "$RELEASE_ROOT"
  rm -f "$DMG_PATH"
  rm -f "$CHECKSUM_PATH"
  /usr/bin/hdiutil create \
    -volname "$APP_NAME $VERSION" \
    -srcfolder "$STAGE_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH" >/dev/null
  /usr/bin/shasum -a 256 "$DMG_PATH" >"$CHECKSUM_PATH"
  echo "$DMG_PATH"
  echo "$CHECKSUM_PATH"
else
  echo "$STAGE_DIR"
fi
