#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="MacDog"
APPLY=0
SELF_TEST=0
SELF_TEST_TMP=""

APPLICATIONS_DIR="${MACDOG_RELEASE_CLEANUP_APPLICATIONS_DIR:-/Applications}"
USER_APPLICATIONS_DIR="${MACDOG_RELEASE_CLEANUP_USER_APPLICATIONS_DIR:-$HOME/Applications}"
DIST_DIR="${MACDOG_RELEASE_CLEANUP_DIST_DIR:-$ROOT_DIR/dist}"
VOLUMES_DIR="${MACDOG_RELEASE_CLEANUP_VOLUMES_DIR:-/Volumes}"
BIN_DIR="${MACDOG_RELEASE_CLEANUP_BIN_DIR:-$HOME/bin}"
LAUNCH_AGENTS_DIR="${MACDOG_RELEASE_CLEANUP_LAUNCH_AGENTS_DIR:-$HOME/Library/LaunchAgents}"
CACHE_LABEL="com.dhseo.macdog.usage-cache"
CACHE_PLIST_NAME="com.dhseo.macdog.usage-cache.plist"
LAUNCHCTL="${MACDOG_RELEASE_CLEANUP_LAUNCHCTL:-/bin/launchctl}"
USER_ID="${MACDOG_RELEASE_CLEANUP_USER_ID:-$(id -u)}"
QUARANTINE_ROOT="${MACDOG_RELEASE_CLEANUP_QUARANTINE_ROOT:-/private/tmp/macdog-duplicate-app-cleanup}"
HDIUTIL="${MACDOG_RELEASE_CLEANUP_HDIUTIL:-/usr/bin/hdiutil}"

usage() {
  cat <<USAGE
usage: $0 [--apply]
       $0 --self-test

Clean release smoke leftovers. Without --apply, prints the actions only.

Actions:
  - eject mounted MacDog installer volumes
  - move ~/Applications/MacDog.app to a quarantine directory
  - move stale usage cache LaunchAgent plist to a quarantine directory
  - unload stale usage cache LaunchAgent jobs that still point at old app paths
  - move dist/MacDog.app to a quarantine directory

The installed /Applications/MacDog.app is never moved by this script.
USAGE
}

die() {
  echo "error: $*" >&2
  exit 1
}

log_action() {
  printf '%s\n' "$1"
}

unique_destination() {
  local base="$1"
  local destination="$base"
  local index=1
  while [[ -e "$destination" ]]; do
    destination="$base-$index"
    index=$((index + 1))
  done
  printf '%s\n' "$destination"
}

quarantine_app() {
  local source="$1"
  local label="$2"
  local run_dir="$3"
  local destination

  [[ -d "$source" ]] || return 0
  destination="$(unique_destination "$run_dir/$label")"
  if [[ "$APPLY" == "1" ]]; then
    mkdir -p "$run_dir"
    /bin/mv "$source" "$destination"
    log_action "moved: $source -> $destination"
  else
    log_action "would move: $source -> $destination"
  fi
}

quarantine_path() {
  local source="$1"
  local label="$2"
  local run_dir="$3"
  local destination

  [[ -e "$source" || -L "$source" ]] || return 0
  destination="$(unique_destination "$run_dir/$label")"
  if [[ "$APPLY" == "1" ]]; then
    mkdir -p "$run_dir"
    /bin/mv "$source" "$destination"
    log_action "moved: $source -> $destination"
  else
    log_action "would move: $source -> $destination"
  fi
}

plist_value() {
  local plist="$1"
  local key="$2"
  /usr/libexec/PlistBuddy -c "Print :$key" "$plist" 2>/dev/null
}

loaded_cache_executable() {
  "$LAUNCHCTL" print "gui/$USER_ID/$CACHE_LABEL" 2>/dev/null | /usr/bin/awk '
    /^[[:space:]]*program = / {
      sub(/^[[:space:]]*program = /, "")
      print
      exit
    }
  '
}

cache_executable_is_stale() {
  local executable="$1"
  [[ -z "$executable" || "$executable" == "$USER_APPLICATIONS_DIR/$APP_NAME.app/"* || ! -x "$executable" ]]
}

bootout_cache_agent() {
  local domain="gui/$USER_ID/$CACHE_LABEL"
  if [[ "$APPLY" == "1" ]]; then
    "$LAUNCHCTL" bootout "$domain" >/dev/null
    log_action "unloaded: $domain"
  else
    log_action "would unload: $domain"
  fi
}

detach_volume() {
  local volume="$1"
  if [[ "$APPLY" == "1" ]]; then
    if [[ "$VOLUMES_DIR" == "/Volumes" ]]; then
      "$HDIUTIL" detach "$volume" >/dev/null
      log_action "ejected: $volume"
    else
      rm -rf "$volume"
      log_action "removed fixture volume: $volume"
    fi
  else
    log_action "would eject: $volume"
  fi
}

cleanup_state() {
  local stamp
  local run_dir
  stamp="$(/bin/date +%Y%m%d-%H%M%S)"
  run_dir="$QUARANTINE_ROOT/$stamp"

  if [[ -d "$VOLUMES_DIR" ]]; then
    while IFS= read -r volume; do
      detach_volume "$volume"
    done < <(/usr/bin/find "$VOLUMES_DIR" -maxdepth 1 -type d -name "$APP_NAME*" -print | /usr/bin/sort)
  fi

  if [[ "$USER_APPLICATIONS_DIR" != "$APPLICATIONS_DIR" ]]; then
    quarantine_app "$USER_APPLICATIONS_DIR/$APP_NAME.app" "UserApplications-$APP_NAME.app" "$run_dir"
  fi
  cli_link="$BIN_DIR/codex-usage"
  if [[ -L "$cli_link" ]]; then
    cli_target="$(/usr/bin/readlink "$cli_link")"
    if [[ "$cli_target" == "$USER_APPLICATIONS_DIR/$APP_NAME.app/"* || ! -e "$cli_link" ]]; then
      quarantine_path "$cli_link" "codex-usage" "$run_dir"
    fi
  fi
  cache_plist="$LAUNCH_AGENTS_DIR/$CACHE_PLIST_NAME"
  if [[ -f "$cache_plist" ]]; then
    cache_executable="$(plist_value "$cache_plist" ProgramArguments:0 || true)"
    if cache_executable_is_stale "$cache_executable"; then
      quarantine_path "$cache_plist" "$CACHE_PLIST_NAME" "$run_dir"
    fi
  fi
  loaded_executable="$(loaded_cache_executable || true)"
  if [[ -n "$loaded_executable" ]] && cache_executable_is_stale "$loaded_executable"; then
    bootout_cache_agent
  fi
  quarantine_app "$DIST_DIR/$APP_NAME.app" "Dist-$APP_NAME.app" "$run_dir"

  log_action "release smoke cleanup finished"
}

write_fixture_app() {
  local app="$1"
  mkdir -p "$app/Contents/MacOS"
  cat >"$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleShortVersionString</key>
  <string>9.9.9</string>
</dict>
</plist>
PLIST
  printf '#!/usr/bin/env bash\nexit 0\n' >"$app/Contents/MacOS/codex-usage"
  chmod +x "$app/Contents/MacOS/codex-usage"
}

write_fixture_cache_plist() {
  local plist="$1"
  local executable="$2"
  mkdir -p "$(dirname "$plist")"
  cat >"$plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>ProgramArguments</key>
  <array>
    <string>$executable</string>
    <string>status</string>
    <string>--write-cache</string>
  </array>
</dict>
</plist>
PLIST
}

write_fixture_launchctl() {
  local launchctl="$1"
  local log="$2"
  local program="$3"
  cat >"$launchctl" <<SCRIPT
#!/usr/bin/env bash
set -euo pipefail
case "\${1:-}" in
  print)
    cat <<OUTPUT
gui/501/$CACHE_LABEL = {
  program = $program
}
OUTPUT
    ;;
  bootout)
    printf '%s\n' "\${2:-}" >>"$log"
    ;;
  *)
    exit 64
    ;;
esac
SCRIPT
  chmod +x "$launchctl"
}

run_self_test() {
  local tmp
  SELF_TEST_TMP="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/macdog-cleanup-test.XXXXXX")"
  tmp="$SELF_TEST_TMP"
  trap 'rm -rf "$SELF_TEST_TMP"' EXIT

  mkdir -p "$tmp/Applications" "$tmp/UserApplications" "$tmp/dist" "$tmp/Volumes" "$tmp/bin" "$tmp/LaunchAgents" "$tmp/quarantine"
  write_fixture_app "$tmp/Applications/$APP_NAME.app"
  write_fixture_app "$tmp/UserApplications/$APP_NAME.app"
  write_fixture_app "$tmp/dist/$APP_NAME.app"
  ln -s "$tmp/UserApplications/$APP_NAME.app/Contents/MacOS/codex-usage" "$tmp/bin/codex-usage"
  write_fixture_cache_plist "$tmp/LaunchAgents/$CACHE_PLIST_NAME" "$tmp/UserApplications/$APP_NAME.app/Contents/MacOS/codex-usage"
  write_fixture_launchctl "$tmp/launchctl" "$tmp/launchctl.log" "$tmp/UserApplications/$APP_NAME.app/Contents/MacOS/codex-usage"
  mkdir -p "$tmp/Volumes/$APP_NAME 9.9.9"

  env \
    MACDOG_RELEASE_CLEANUP_APPLICATIONS_DIR="$tmp/Applications" \
    MACDOG_RELEASE_CLEANUP_USER_APPLICATIONS_DIR="$tmp/UserApplications" \
    MACDOG_RELEASE_CLEANUP_DIST_DIR="$tmp/dist" \
    MACDOG_RELEASE_CLEANUP_VOLUMES_DIR="$tmp/Volumes" \
    MACDOG_RELEASE_CLEANUP_BIN_DIR="$tmp/bin" \
    MACDOG_RELEASE_CLEANUP_LAUNCH_AGENTS_DIR="$tmp/LaunchAgents" \
    MACDOG_RELEASE_CLEANUP_LAUNCHCTL="$tmp/launchctl" \
    MACDOG_RELEASE_CLEANUP_USER_ID=501 \
    MACDOG_RELEASE_CLEANUP_QUARANTINE_ROOT="$tmp/quarantine" \
    "$0" --apply >/dev/null

  [[ -d "$tmp/Applications/$APP_NAME.app" ]] || die "self-test installed app should remain"
  [[ ! -e "$tmp/UserApplications/$APP_NAME.app" ]] || die "self-test user duplicate should be moved"
  [[ ! -e "$tmp/dist/$APP_NAME.app" ]] || die "self-test dist app should be moved"
  [[ ! -e "$tmp/bin/codex-usage" ]] || die "self-test stale CLI symlink should be moved"
  [[ ! -e "$tmp/LaunchAgents/$CACHE_PLIST_NAME" ]] || die "self-test stale cache LaunchAgent should be moved"
  [[ ! -e "$tmp/Volumes/$APP_NAME 9.9.9" ]] || die "self-test fixture volume should be removed"
  if ! /usr/bin/find "$tmp/quarantine" -maxdepth 3 -type d -name "UserApplications-$APP_NAME.app" -print -quit | /usr/bin/grep -q .; then
    die "self-test user duplicate quarantine missing"
  fi
  if ! /usr/bin/find "$tmp/quarantine" -maxdepth 3 -type d -name "Dist-$APP_NAME.app" -print -quit | /usr/bin/grep -q .; then
    die "self-test dist quarantine missing"
  fi
  if ! /usr/bin/find "$tmp/quarantine" -maxdepth 3 -type l -name "codex-usage" -print -quit | /usr/bin/grep -q .; then
    die "self-test stale CLI symlink quarantine missing"
  fi
  if ! /usr/bin/find "$tmp/quarantine" -maxdepth 3 -type f -name "$CACHE_PLIST_NAME" -print -quit | /usr/bin/grep -q .; then
    die "self-test stale cache LaunchAgent quarantine missing"
  fi
  /usr/bin/grep -Fq "gui/501/$CACHE_LABEL" "$tmp/launchctl.log" || die "self-test stale loaded LaunchAgent should be booted out"

  echo "Release smoke cleanup self-test ok"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply)
      APPLY=1
      ;;
    --self-test)
      SELF_TEST=1
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

if [[ "$SELF_TEST" == "1" ]]; then
  run_self_test
  exit 0
fi

cleanup_state
