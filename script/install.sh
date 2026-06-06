#!/usr/bin/env bash
set -euo pipefail

MODE="install"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="MacDog"
BUNDLE_ID="com.dhseo.macdog.MacDog"
APP_SOURCE="$ROOT_DIR/dist/$APP_NAME.app"
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
HELPER_LABEL="com.dhseo.macdog.helper"
HELPER_EXECUTABLE="MacDogPrivilegedHelper"
HELPER_MACH_SERVICE="$HELPER_LABEL.xpc"
HELPER_SOURCE="$APP_SOURCE/Contents/Library/LaunchServices/$HELPER_EXECUTABLE"
HELPER_PLIST_SOURCE="$APP_SOURCE/Contents/Library/LaunchDaemons/$HELPER_LABEL.plist"
HELPER_TOOL_DEST="/Library/PrivilegedHelperTools/$HELPER_LABEL"
HELPER_PLIST_DEST="/Library/LaunchDaemons/$HELPER_LABEL.plist"
HELPER_LOG_DIR="/Library/Logs/MacDog"
UID_VALUE="$(id -u)"
CACHE_REQUEST_TIMEOUT_SECONDS=5
CACHE_PRIME_TIMEOUT_SECONDS=12
WITH_HELPER=0
HELPER_ONLY=0
WITH_WIDGET=0
APP_VERSION="${MACDOG_APP_VERSION:-${MACDOG_RELEASE_VERSION:-}}"

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
XCRUN="/usr/bin/xcrun"

usage() {
  echo "usage: $0 [--dry-run] [--with-helper] [--helper-only] [--with-widget]"
  echo "requires MACDOG_APP_VERSION or MACDOG_RELEASE_VERSION"
}

die() {
  echo "error: $*" >&2
  exit 1
}

require_app_version() {
  [[ -n "$APP_VERSION" ]] || die "app version required; set MACDOG_APP_VERSION or MACDOG_RELEASE_VERSION"
}

clean_bundle_xattrs() {
  local bundle="$1"
  /usr/bin/xattr -cr "$bundle" >/dev/null 2>&1 || true
  /usr/bin/find "$bundle" -exec /usr/bin/xattr -d com.apple.FinderInfo {} \; >/dev/null 2>&1 || true
}

run_as_root() {
  if [[ "$(id -u)" == "0" ]]; then
    "$@"
  elif [[ -t 0 ]]; then
    /usr/bin/sudo "$@"
  else
    if [[ "${MACDOG_ALLOW_OSASCRIPT_ADMIN:-0}" != "1" ]]; then
      die "administrator approval requires Terminal sudo or the MacDog Settings helper button; refusing osascript approval fallback"
    fi
    local command=""
    local arg
    for arg in "$@"; do
      command+=" $(shell_quote "$arg")"
    done
    /usr/bin/osascript -e "do shell script $(apple_script_literal "${command# }") with administrator privileges"
  fi
}

run_script_as_root() {
  local script_path="$1"
  run_as_root /bin/bash "$script_path"
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

xml_escape() {
  local value="$1"
  value="${value//&/&amp;}"
  value="${value//</&lt;}"
  value="${value//>/&gt;}"
  value="${value//\"/&quot;}"
  value="${value//\'/&apos;}"
  printf '%s' "$value"
}

shell_quote() {
  local value="$1"
  printf "'%s'" "${value//\'/\'\\\'\'}"
}

apple_script_literal() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  printf '"%s"' "$value"
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

detect_host_designated_requirement() {
  local bundle_path="$1"
  local output
  output="$(/usr/bin/codesign -dr - "$bundle_path" 2>&1 || true)"
  printf '%s\n' "$output" | awk '
    {
      line = $0
      sub(/^[[:space:]]*#[[:space:]]*/, "", line)
      if (line ~ /^designated =>[[:space:]]*/) {
        sub(/^designated =>[[:space:]]*/, "", line)
        if (length(line) > 0) {
          print line
          exit
        }
      }
    }
  '
}

write_helper_launch_daemon_plist() {
  local target="$1"
  local host_team_id="$2"
  local host_requirement="$3"

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

  if [[ -n "$host_team_id" || -n "$host_requirement" ]]; then
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
    if [[ -n "$host_requirement" ]]; then
      cat >>"$target" <<PLIST
    <key>MACDOG_HELPER_HOST_REQUIREMENT</key>
    <string>$(xml_escape "$host_requirement")</string>
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

install_privileged_helper() {
  local host_bundle_path="${1:-$APP_DEST}"

  [[ -x "$HELPER_SOURCE" ]] || die "privileged helper executable missing: $HELPER_SOURCE"
  [[ -f "$HELPER_PLIST_SOURCE" ]] || die "privileged helper launch daemon plist missing: $HELPER_PLIST_SOURCE"
  [[ -d "$host_bundle_path" ]] || die "host app bundle missing: $host_bundle_path"
  /usr/bin/codesign --verify --strict --verbose=2 "$HELPER_SOURCE" >/dev/null
  /usr/bin/plutil -lint "$HELPER_PLIST_SOURCE" >/dev/null

  local host_team_id
  host_team_id="${MACDOG_HELPER_HOST_TEAM_ID:-$(detect_host_team_identifier "$host_bundle_path")}"
  local host_requirement="${MACDOG_HELPER_HOST_REQUIREMENT:-}"
  if [[ -z "$host_team_id" ]]; then
    host_requirement="${host_requirement:-$(detect_host_designated_requirement "$host_bundle_path")}"
    [[ -n "$host_requirement" ]] || die "could not detect host designated requirement for ad-hoc helper authorization"
  fi

  local temp_plist
  temp_plist="$(/usr/bin/mktemp "${TMPDIR:-/tmp}/macdog-helper.XXXXXX")"
  write_helper_launch_daemon_plist "$temp_plist" "$host_team_id" "$host_requirement"
  /usr/bin/plutil -lint "$temp_plist" >/dev/null

  local temp_script
  temp_script="$(/usr/bin/mktemp "${TMPDIR:-/tmp}/macdog-helper-install.XXXXXX")"
  cat >"$temp_script" <<SCRIPT
#!/bin/bash
set -euo pipefail

/bin/launchctl bootout system $(shell_quote "$HELPER_PLIST_DEST") >/dev/null 2>&1 || true
/bin/mkdir -p /Library/PrivilegedHelperTools /Library/LaunchDaemons $(shell_quote "$HELPER_LOG_DIR")
/usr/bin/install -o root -g wheel -m 755 $(shell_quote "$HELPER_SOURCE") $(shell_quote "$HELPER_TOOL_DEST")
/usr/bin/install -o root -g wheel -m 644 $(shell_quote "$temp_plist") $(shell_quote "$HELPER_PLIST_DEST")
/bin/launchctl bootstrap system $(shell_quote "$HELPER_PLIST_DEST")
/bin/launchctl print $(shell_quote "system/$HELPER_LABEL") >/dev/null
SCRIPT
  chmod 700 "$temp_script"
  local status=0
  run_script_as_root "$temp_script" || status="$?"
  rm -f "$temp_plist" "$temp_script"
  [[ "$status" == "0" ]] || return "$status"

  /usr/bin/codesign --verify --strict --verbose=2 "$HELPER_TOOL_DEST" >/dev/null
}

print_helper_install_dry_run() {
  echo "Privileged helper: opt-in enabled"
  echo "Helper label: $HELPER_LABEL"
  echo "Helper executable source: $HELPER_SOURCE"
  echo "Helper host app source: $APP_SOURCE"
  echo "Helper launch daemon source: $HELPER_PLIST_SOURCE"
  echo "Helper tool destination: $HELPER_TOOL_DEST"
  echo "Helper launch daemon destination: $HELPER_PLIST_DEST"
  echo "Helper mach service: $HELPER_MACH_SERVICE"
  echo "Helper commands: read SleepDisabled, set SleepDisabled 0/1, read screenLock, set screenLock off/immediate/seconds only"
  echo "Helper install status: implemented; actual run requires administrator approval"
  echo "Helper approval UX: terminal sudo when interactive, or MacDog Settings helper button; non-interactive osascript fallback is disabled unless MACDOG_ALLOW_OSASCRIPT_ADMIN=1"
  echo "Helper host requirement: team id when signed, local ad-hoc allowance for unsigned development builds"
  temp_plist="$(/usr/bin/mktemp "${TMPDIR:-/tmp}/macdog-helper-dry-run.XXXXXX")"
  write_helper_launch_daemon_plist "$temp_plist" "" "1"
  /usr/bin/plutil -lint "$temp_plist" >/dev/null
  rm -f "$temp_plist"
  echo "Helper launch daemon plist validation: ok"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    install) MODE="install" ;;
    --dry-run|dry-run) MODE="dry-run" ;;
    --with-helper) WITH_HELPER=1 ;;
    --with-widget) WITH_WIDGET=1 ;;
    --helper-only)
      WITH_HELPER=1
      HELPER_ONLY=1
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

case "$MODE" in
  install) ;;
  dry-run)
    require_app_version
    if [[ "$HELPER_ONLY" == "1" ]]; then
      echo "MacDog helper-only install dry run"
      echo "App version: $APP_VERSION"
      echo "Build script: MACDOG_APP_VERSION=$APP_VERSION $ROOT_DIR/script/build_and_run.sh --no-run"
      echo "App source: $APP_SOURCE"
      echo "App install: skipped"
      echo "CLI install: skipped"
      echo "LaunchAgent changes: skipped"
      echo "Running app process: left untouched"
      print_helper_install_dry_run
      exit 0
    fi

    echo "MacDog install dry run"
    echo "App version: $APP_VERSION"
    if [[ "$WITH_WIDGET" == "1" ]]; then
      echo "Build script: MACDOG_APP_VERSION=$APP_VERSION $ROOT_DIR/script/build_and_run.sh --no-run --with-widget"
    else
      echo "Build script: MACDOG_APP_VERSION=$APP_VERSION $ROOT_DIR/script/build_and_run.sh --no-run"
    fi
    echo "App source: $APP_SOURCE"
    echo "App destination: $APP_DEST"
    echo "CLI destination: $CLI_DEST -> $APP_CLI_DEST"
    echo "Cache agent executable: $APP_CLI_DEST"
    echo "Log directory: $LOG_DIR"
    echo "LaunchAgent cache plist: $CACHE_PLIST"
    echo "Legacy monitor LaunchAgent cleanup: $MONITOR_PLIST"
    echo "Login item: managed by MacDog through macOS Login Items"
    echo "Cache agent interval: 60 seconds"
    echo "Cache request timeout: $CACHE_REQUEST_TIMEOUT_SECONDS seconds"
    echo "Cache prime timeout: $CACHE_PRIME_TIMEOUT_SECONDS seconds"
    echo "Login item preference key: $LOGIN_LAUNCH_KEY"
    if login_launch_enabled; then
      echo "Login item enabled by preference: true"
    else
      echo "Login item enabled by preference: false"
    fi
    echo "Preferences: preserved in UserDefaults and restored by MacDog on launch"
    if [[ "$WITH_WIDGET" == "1" ]]; then
      echo "Widget extension: opt-in bundled in $APP_SOURCE/Contents/PlugIns/MacDogWidgetExtension.appex"
      echo "Widget cache mirror: enabled"
    else
      echo "Widget extension: skipped by default; pass --with-widget to build/install it"
      echo "Widget cache mirror: disabled"
    fi
    if [[ "$WITH_HELPER" == "1" ]]; then
      print_helper_install_dry_run
    else
      echo "Privileged helper: skipped; pass --with-helper for dry-run plan"
    fi
    exit 0
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

if [[ "$HELPER_ONLY" == "1" ]]; then
  require_app_version
  "$ROOT_DIR/script/build_and_run.sh" --no-run >/dev/null
  install_privileged_helper "$APP_SOURCE"
  echo "Installed MacDog privileged helper"
  echo "Privileged helper: $HELPER_TOOL_DEST"
  echo "LaunchDaemon: $HELPER_PLIST_DEST"
  exit 0
fi

require_app_version
if [[ "$WITH_WIDGET" == "1" ]]; then
  "$ROOT_DIR/script/build_and_run.sh" --no-run --with-widget >/dev/null
else
  "$ROOT_DIR/script/build_and_run.sh" --no-run >/dev/null
fi

mkdir -p "$HOME/Applications" "$BIN_DIR" "$LAUNCH_AGENT_DIR" "$LOG_DIR"
/bin/launchctl bootout "gui/$UID_VALUE" "$CACHE_PLIST" >/dev/null 2>&1 || true
/bin/launchctl bootout "gui/$UID_VALUE" "$MONITOR_PLIST" >/dev/null 2>&1 || true
stop_running_app_for_update

rm -rf "$APP_DEST"
/usr/bin/ditto --norsrc --noextattr "$APP_SOURCE" "$APP_DEST"
clean_bundle_xattrs "$APP_DEST"
/usr/bin/codesign --force --sign - "$APP_DEST" >/dev/null
/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_DEST" >/dev/null
[[ -x "$APP_CLI_DEST" ]] || die "bundled CLI missing: $APP_CLI_DEST"
rm -f "$CLI_DEST"
ln -s "$APP_CLI_DEST" "$CLI_DEST"

if [[ "$WITH_HELPER" == "1" ]]; then
  install_privileged_helper "$APP_DEST"
fi

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
PLIST
if [[ "$WITH_WIDGET" == "1" ]]; then
  cat >>"$CACHE_PLIST" <<PLIST
    <string>--mirror-cache</string>
PLIST
fi
cat >>"$CACHE_PLIST" <<PLIST
    <string>--timeout</string>
    <string>$CACHE_REQUEST_TIMEOUT_SECONDS</string>
    <string>--watch</string>
    <string>60</string>
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

rm -f "$MONITOR_PLIST"

if [[ "$WITH_WIDGET" == "1" ]]; then
  if ! run_with_timeout "$CACHE_PRIME_TIMEOUT_SECONDS" "$APP_CLI_DEST" status --write-cache --mirror-cache --timeout "$CACHE_REQUEST_TIMEOUT_SECONDS" >/dev/null; then
    echo "Warning: failed to prime usage cache; LaunchAgent will retry." >&2
  fi
else
  if ! run_with_timeout "$CACHE_PRIME_TIMEOUT_SECONDS" "$APP_CLI_DEST" status --write-cache --timeout "$CACHE_REQUEST_TIMEOUT_SECONDS" >/dev/null; then
    echo "Warning: failed to prime usage cache; LaunchAgent will retry." >&2
  fi
fi

/bin/launchctl bootstrap "gui/$UID_VALUE" "$CACHE_PLIST"
/usr/bin/open "$APP_DEST"

sleep 2
pgrep -x "$APP_NAME" >/dev/null

echo "Installed MacDog"
echo "App: $APP_DEST"
echo "CLI: $CLI_DEST -> $APP_CLI_DEST"
echo "LaunchAgents: $CACHE_PLIST"
if login_launch_enabled; then
  echo "Login item: managed by MacDog through macOS Login Items"
else
  echo "Login item: disabled by preference"
fi
if [[ "$WITH_HELPER" == "1" ]]; then
  echo "Privileged helper: $HELPER_TOOL_DEST"
  echo "LaunchDaemon: $HELPER_PLIST_DEST"
fi
if [[ "$WITH_WIDGET" == "1" ]]; then
  echo "Widget extension: installed opt-in"
else
  echo "Widget extension: not installed"
fi
