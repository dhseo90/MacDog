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

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
XCRUN="/usr/bin/xcrun"

usage() {
  cat <<USAGE
usage: $0 [--dry-run] [--skip-build] [--no-dmg] [--version VERSION]

Build a local GitHub Release candidate payload.
The generated DMG is not notarized and is intended for local validation.
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
  - Check Install Status.command
  - README_FIRST.txt
  - RELEASE_NOTES_DRAFT.md
Double-click install: Install MacDog.command copies app/CLI, writes user LaunchAgents, and opens MacDog.
Privileged helper: Install Privileged Helper.command installs the bundled helper after explicit administrator approval.
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
6. This local release candidate is intended for local unsigned validation.
7. Uninstall support remains available from the source checkout via script/uninstall.sh.
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

- Source checkout uninstall path: \`./script/uninstall.sh --with-helper\`
- Release-package uninstall UX is still a follow-up item for public distribution.
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

[[ -d "$APP_SOURCE" ]] || die "missing app bundle: $APP_SOURCE"
[[ -x "$HELPER_SOURCE" ]] || die "missing helper executable: $HELPER_SOURCE"
/usr/bin/codesign --verify --strict --verbose=2 "$HELPER_SOURCE" >/dev/null

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

cat >"$temp_plist" <<PLIST
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
  <key>EnvironmentVariables</key>
  <dict>
    <key>MACDOG_HELPER_ALLOW_ADHOC_HOST</key>
    <string>1</string>
  </dict>
  <key>RunAtLoad</key>
  <true/>
  <key>StandardOutPath</key>
  <string>$HELPER_LOG_DIR/helper.out.log</string>
  <key>StandardErrorPath</key>
  <string>$HELPER_LOG_DIR/helper.err.log</string>
</dict>
</plist>
PLIST
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
chmod +x "$STAGE_DIR/Install Privileged Helper.command"

cat >"$STAGE_DIR/Check Install Status.command" <<'STATUS'
#!/usr/bin/env bash
set -u

APP_NAME="MacDog"
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

echo "MacDog install status"
echo

if [[ -x "$APP_DEST/Contents/MacOS/$APP_NAME" ]]; then
  ok "app installed: $APP_DEST"
else
  missing_required "app executable: $APP_DEST/Contents/MacOS/$APP_NAME"
fi

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
