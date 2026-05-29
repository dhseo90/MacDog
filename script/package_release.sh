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
CACHE_REQUEST_TIMEOUT_SECONDS=5
CACHE_PRIME_TIMEOUT_SECONDS=12

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

usage() {
  cat <<USAGE
usage: $0 [--dry-run] [--skip-build] [--no-dmg] [--version VERSION]

Build a local GitHub Release candidate payload.
The generated DMG is not notarized and is intended for local validation.
The DMG is staged as a drag-and-drop app installer. Optional helper management
is handled inside MacDog Settings so macOS approval prompts are owned by MacDog.
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
  - MacDog.app (includes bundled codex-usage)
  - Applications symlink
  - Install MacDog.command
  - Uninstall MacDog.command
  - Check Install Status.command
  - README_FIRST.txt
  - RELEASE_NOTES_DRAFT.md
Drag install: drag MacDog.app to Applications, then launch MacDog.
Optional full local install: Install MacDog.command copies the app to ~/Applications, creates a terminal CLI symlink, writes user LaunchAgents, and opens MacDog.
Privileged helper: install or remove from the MacDog Settings tab after launching the app.
Double-click uninstall: Uninstall MacDog.command removes the local command-installed app, CLI symlink, user LaunchAgents, and cache files.
Privileged helper cleanup: remove the optional helper from the MacDog Settings tab before uninstalling the app.
Post-install check: Check Install Status.command verifies app, bundled CLI, terminal symlink, user LaunchAgents, optional helper state, and app freshness.
Signing: local ad-hoc build only; Developer ID signing and notarization are not performed.
Gatekeeper: unsigned candidates are local validation artifacts and must not be published as public stable releases.
GitHub Release: upload DMG only after signing/notarization gate is satisfied for public distribution.
Cache request timeout: $CACHE_REQUEST_TIMEOUT_SECONDS seconds
Cache prime timeout: $CACHE_PRIME_TIMEOUT_SECONDS seconds
DRYRUN
  exit 0
fi

cd "$ROOT_DIR"

if [[ "$SKIP_BUILD" != "1" ]]; then
  ./script/build_and_run.sh --no-run >/dev/null
fi

./script/verify_app_bundle.sh "$APP_BUNDLE" >/dev/null

rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR"
if [[ "$CREATE_DMG" == "1" ]]; then
  cleanup_release_stage() {
    rm -rf "$STAGE_DIR"
  }
  trap cleanup_release_stage EXIT
fi
/usr/bin/ditto --norsrc --noextattr "$APP_BUNDLE" "$STAGE_DIR/$APP_NAME.app"
/usr/bin/xattr -cr "$STAGE_DIR/$APP_NAME.app" >/dev/null 2>&1 || true
ln -s /Applications "$STAGE_DIR/Applications"

cat >"$STAGE_DIR/README_FIRST.txt" <<README
MacDog $VERSION

1. Drag "MacDog.app" to "Applications", then open MacDog.
2. This local release candidate is unsigned and not notarized. macOS Gatekeeper may block first launch.
3. If you want the terminal codex-usage symlink and user LaunchAgents for local validation, double-click "Install MacDog.command" instead.
4. Install or remove the optional privileged helper from MacDog Settings after launching the app.
5. Double-click "Check Install Status.command" after installation to verify app, bundled CLI, terminal symlink, LaunchAgents, and optional helper state.
6. Double-click "Uninstall MacDog.command" to remove the app, CLI symlink, user LaunchAgents, and cache files.
7. Remove the optional privileged helper from MacDog Settings before uninstalling the app if you installed it.
8. This local release candidate is intended for local unsigned validation.
README

cat >"$STAGE_DIR/RELEASE_NOTES_DRAFT.md" <<NOTES
# MacDog $VERSION Release Notes Draft

Status: unsigned local release candidate.

## Install

- Open the DMG.
- Drag \`MacDog.app\` to \`Applications\`, then launch MacDog.
- For local validation with terminal CLI symlink and user LaunchAgents, double-click \`Install MacDog.command\`.
- Install or remove the optional privileged helper from the MacDog Settings tab.
- Double-click \`Check Install Status.command\` after installation.

## Security And Gatekeeper

- This candidate is ad-hoc signed for local validation and is not notarized.
- Do not publish it as a public stable release until Developer ID signing, hardened runtime, notarization, stapling, and Gatekeeper checks pass.
- The optional privileged helper changes \`/Library/PrivilegedHelperTools/com.dhseo.macdog.helper\` and \`/Library/LaunchDaemons/com.dhseo.macdog.helper.plist\` only after explicit approval from the MacDog app.

## Supported Scope

- Codex usage popover and CLI.
- Mac resource, sleep-prevention, and native Charge Limit UI.
- Native Charge Limit requires Apple silicon and macOS 26.4 or later.

## Uninstall

- Double-click \`Uninstall MacDog.command\` to remove the app, CLI symlink, user LaunchAgents, and cache files.
- Remove the optional helper from MacDog Settings before uninstalling the app if you installed it.
- Source checkout uninstall path remains available: \`./script/uninstall.sh --with-helper\`
NOTES

cat >"$STAGE_DIR/Install MacDog.command" <<'INSTALL'
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="MacDog"
BUNDLE_ID="com.dhseo.macdog.MacDog"
APP_SOURCE="$SCRIPT_DIR/$APP_NAME.app"
APP_DEST="$HOME/Applications/$APP_NAME.app"
BIN_DIR="$HOME/bin"
CLI_DEST="$BIN_DIR/codex-usage"
APP_CLI_DEST="$APP_DEST/Contents/MacOS/codex-usage"
LAUNCH_AGENT_DIR="$HOME/Library/LaunchAgents"
LOG_DIR="$HOME/Library/Logs/MacDog"
CACHE_LABEL="com.dhseo.macdog.usage-cache"
MONITOR_LABEL="com.dhseo.macdog.monitor"
CACHE_PLIST="$LAUNCH_AGENT_DIR/$CACHE_LABEL.plist"
MONITOR_PLIST="$LAUNCH_AGENT_DIR/$MONITOR_LABEL.plist"
LOGIN_LAUNCH_KEY="loginLaunchEnabled"
UID_VALUE="$(id -u)"
CACHE_REQUEST_TIMEOUT_SECONDS=5
CACHE_PRIME_TIMEOUT_SECONDS=12

die() {
  echo "error: $*" >&2
  exit 1
}

run_with_timeout() {
  local timeout_seconds="$1"
  shift

  "$@" &
  local command_pid="$!"

  (
    sleep "$timeout_seconds"
    if kill -0 "$command_pid" >/dev/null 2>&1; then
      kill "$command_pid" >/dev/null 2>&1 || true
    fi
  ) &
  local watchdog_pid="$!"

  local status=0
  wait "$command_pid" 2>/dev/null || status="$?"
  kill "$watchdog_pid" >/dev/null 2>&1 || true
  wait "$watchdog_pid" >/dev/null 2>&1 || true
  return "$status"
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

login_launch_enabled() {
  local value
  value="$(/usr/bin/defaults read "$BUNDLE_ID" "$LOGIN_LAUNCH_KEY" 2>/dev/null || true)"
  [[ -z "$value" || "$value" == "1" || "$value" == "true" || "$value" == "TRUE" || "$value" == "YES" ]]
}

[[ -d "$APP_SOURCE" ]] || die "missing app bundle: $APP_SOURCE"

mkdir -p "$HOME/Applications" "$BIN_DIR" "$LAUNCH_AGENT_DIR" "$LOG_DIR"
/bin/launchctl bootout "gui/$UID_VALUE" "$CACHE_PLIST" >/dev/null 2>&1 || true
/bin/launchctl bootout "gui/$UID_VALUE" "$MONITOR_PLIST" >/dev/null 2>&1 || true
stop_running_app_for_update

rm -rf "$APP_DEST"
/usr/bin/ditto --norsrc --noextattr "$APP_SOURCE" "$APP_DEST"
/usr/bin/xattr -cr "$APP_DEST" >/dev/null 2>&1 || true
/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_DEST" >/dev/null

[[ -x "$APP_CLI_DEST" ]] || die "missing bundled CLI binary: $APP_CLI_DEST"
rm -f "$CLI_DEST"
ln -s "$APP_CLI_DEST" "$CLI_DEST"

cat >"$CACHE_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$CACHE_LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>$APP_CLI_DEST</string>
    <string>status</string>
    <string>--write-cache</string>
    <string>--timeout</string>
    <string>$CACHE_REQUEST_TIMEOUT_SECONDS</string>
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

if login_launch_enabled; then
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
else
  rm -f "$MONITOR_PLIST"
fi

run_with_timeout "$CACHE_PRIME_TIMEOUT_SECONDS" "$APP_CLI_DEST" status --write-cache --timeout "$CACHE_REQUEST_TIMEOUT_SECONDS" >/dev/null || true
/bin/launchctl bootstrap "gui/$UID_VALUE" "$CACHE_PLIST"
if login_launch_enabled; then
  /bin/launchctl bootstrap "gui/$UID_VALUE" "$MONITOR_PLIST"
fi
/usr/bin/open "$APP_DEST"

echo "Installed MacDog"
echo "App: $APP_DEST"
echo "CLI: $CLI_DEST -> $APP_CLI_DEST"
if login_launch_enabled; then
  echo "LaunchAgents: $CACHE_PLIST, $MONITOR_PLIST"
else
  echo "LaunchAgents: $CACHE_PLIST (monitor disabled by preference)"
fi
echo "For full closed-lid sleep prevention, open MacDog Settings and install the 권한 도우미."
echo "Then run Check Install Status.command to verify the install."
INSTALL
chmod +x "$STAGE_DIR/Install MacDog.command"

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
privileged helper. Remove the helper from MacDog Settings before uninstalling if needed.
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

cat >"$STAGE_DIR/Check Install Status.command" <<'STATUS'
#!/usr/bin/env bash
set -u

APP_NAME="MacDog"
BUNDLE_ID="com.dhseo.macdog.MacDog"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_SOURCE="$SCRIPT_DIR/$APP_NAME.app"
COMMAND_APP_DEST="$HOME/Applications/$APP_NAME.app"
DRAG_APP_DEST="/Applications/$APP_NAME.app"
APP_DEST="${MACDOG_STATUS_APP_DEST:-}"
if [[ -z "$APP_DEST" ]]; then
  if [[ -x "$DRAG_APP_DEST/Contents/MacOS/$APP_NAME" ]]; then
    APP_DEST="$DRAG_APP_DEST"
  else
    APP_DEST="$COMMAND_APP_DEST"
  fi
fi
APP_CLI_DEST="$APP_DEST/Contents/MacOS/codex-usage"
CLI_DEST="$HOME/bin/codex-usage"
UID_VALUE="$(id -u)"
CACHE_LABEL="com.dhseo.macdog.usage-cache"
MONITOR_LABEL="com.dhseo.macdog.monitor"
CACHE_PLIST="$HOME/Library/LaunchAgents/$CACHE_LABEL.plist"
MONITOR_PLIST="$HOME/Library/LaunchAgents/$MONITOR_LABEL.plist"
LOGIN_LAUNCH_KEY="loginLaunchEnabled"
HELPER_LABEL="com.dhseo.macdog.helper"
HELPER_TOOL_DEST="/Library/PrivilegedHelperTools/$HELPER_LABEL"
HELPER_PLIST_DEST="/Library/LaunchDaemons/$HELPER_LABEL.plist"
required_failures=0
command_install=0
if [[ "$APP_DEST" == "$COMMAND_APP_DEST" ]]; then
  command_install=1
fi

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

plist_value() {
  /usr/libexec/PlistBuddy -c "Print $1" "$2" 2>/dev/null
}

login_launch_enabled() {
  local value
  value="$(/usr/bin/defaults read "$BUNDLE_ID" "$LOGIN_LAUNCH_KEY" 2>/dev/null || true)"
  [[ -z "$value" || "$value" == "1" || "$value" == "true" || "$value" == "TRUE" || "$value" == "YES" ]]
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

if [[ -x "$APP_CLI_DEST" ]]; then
  ok "bundled CLI installed: $APP_CLI_DEST"
else
  missing_required "bundled CLI executable: $APP_CLI_DEST"
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
  ok "terminal CLI available: $CLI_DEST"
else
  if [[ "$command_install" == "1" ]]; then
    missing_required "CLI executable: $CLI_DEST"
  else
    warn "terminal CLI symlink is optional for drag install: $CLI_DEST"
  fi
fi
if [[ -L "$CLI_DEST" ]]; then
  cli_target="$(readlink "$CLI_DEST")"
  if [[ "$cli_target" == "$APP_CLI_DEST" ]]; then
    ok "terminal CLI points to bundled CLI"
  else
    if [[ "$command_install" == "1" ]]; then
      missing_required "terminal CLI symlink target: expected $APP_CLI_DEST, got $cli_target"
    else
      warn "terminal CLI points to another app path: expected $APP_CLI_DEST, got $cli_target"
    fi
  fi
else
  if [[ "$command_install" == "1" ]]; then
    missing_required "terminal CLI symlink: $CLI_DEST"
  else
    warn "terminal CLI symlink not installed for drag install: $CLI_DEST"
  fi
fi

if [[ -f "$CACHE_PLIST" ]]; then
  ok "cache LaunchAgent plist: $CACHE_PLIST"
  cache_executable="$(plist_value ':ProgramArguments:0' "$CACHE_PLIST" || true)"
  if [[ "$cache_executable" == "$APP_CLI_DEST" ]]; then
    ok "cache LaunchAgent runs bundled CLI"
  else
    if [[ "$command_install" == "1" ]]; then
      missing_required "cache LaunchAgent executable: expected $APP_CLI_DEST, got $cache_executable"
    else
      warn "cache LaunchAgent points to another app path: expected $APP_CLI_DEST, got $cache_executable"
    fi
  fi
else
  if [[ "$command_install" == "1" ]]; then
    missing_required "cache LaunchAgent plist: $CACHE_PLIST"
  else
    warn "cache LaunchAgent not installed for drag install: $CACHE_PLIST"
  fi
fi

if login_launch_enabled; then
  if [[ -f "$MONITOR_PLIST" ]]; then
    ok "monitor LaunchAgent plist: $MONITOR_PLIST"
  else
    if [[ "$command_install" == "1" ]]; then
      missing_required "monitor LaunchAgent plist: $MONITOR_PLIST"
    else
      warn "monitor LaunchAgent not installed for drag install: $MONITOR_PLIST"
    fi
  fi
else
  if [[ -f "$MONITOR_PLIST" ]]; then
    warn "monitor LaunchAgent exists while login launch is disabled: $MONITOR_PLIST"
  else
    ok "monitor LaunchAgent disabled by preference"
  fi
fi

if /bin/launchctl print "gui/$UID_VALUE/$CACHE_LABEL" >/dev/null 2>&1; then
  ok "cache LaunchAgent loaded"
else
  warn "cache LaunchAgent is not loaded"
fi

if login_launch_enabled; then
  if /bin/launchctl print "gui/$UID_VALUE/$MONITOR_LABEL" >/dev/null 2>&1; then
    ok "monitor LaunchAgent loaded"
  else
    warn "monitor LaunchAgent is not loaded"
  fi
else
  ok "monitor LaunchAgent load skipped by preference"
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
