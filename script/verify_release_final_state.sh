#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="MacDog"
VERSION=""
SELF_TEST=0
SELF_TEST_TMP=""

APPLICATIONS_DIR="${MACDOG_RELEASE_FINAL_APPLICATIONS_DIR:-/Applications}"
USER_APPLICATIONS_DIR="${MACDOG_RELEASE_FINAL_USER_APPLICATIONS_DIR:-$HOME/Applications}"
DIST_DIR="${MACDOG_RELEASE_FINAL_DIST_DIR:-$ROOT_DIR/dist}"
VOLUMES_DIR="${MACDOG_RELEASE_FINAL_VOLUMES_DIR:-/Volumes}"
BIN_DIR="${MACDOG_RELEASE_FINAL_BIN_DIR:-$HOME/bin}"
LAUNCH_AGENTS_DIR="${MACDOG_RELEASE_FINAL_LAUNCH_AGENTS_DIR:-$HOME/Library/LaunchAgents}"
CACHE_LABEL="com.dhseo.macdog.usage-cache"
CACHE_PLIST_NAME="com.dhseo.macdog.usage-cache.plist"
LAUNCHCTL="${MACDOG_RELEASE_FINAL_LAUNCHCTL:-/bin/launchctl}"
USER_ID="${MACDOG_RELEASE_FINAL_USER_ID:-$(id -u)}"

usage() {
  cat <<USAGE
usage: $0 --version VERSION
       $0 --self-test

Verify the local machine is clean after release smoke:
  - only /Applications/MacDog.app remains in user-visible app locations
  - no MacDog DMG volumes remain mounted
  - dist/MacDog.app was cleaned up after packaging smoke
  - installed app CFBundleShortVersionString matches VERSION
  - usage cache LaunchAgent plist and loaded job are absent or point at an executable installed app CLI
USAGE
}

die() {
  echo "error: $*" >&2
  exit 1
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

validate_cache_executable() {
  local source="$1"
  local executable="$2"
  local expected_cache_executable="$installed_app/Contents/MacOS/codex-usage"

  if [[ -z "$executable" ]]; then
    failures+=("usage cache LaunchAgent executable missing: $source")
  elif [[ "$executable" == "$USER_APPLICATIONS_DIR/$APP_NAME.app/"* ]]; then
    failures+=("stale usage cache LaunchAgent points to duplicate user app: $source -> $executable")
  elif [[ "$executable" != "$expected_cache_executable" ]]; then
    failures+=("usage cache LaunchAgent executable mismatch: expected $expected_cache_executable, got $executable")
  elif [[ ! -x "$executable" ]]; then
    failures+=("usage cache LaunchAgent executable is not runnable: $executable")
  fi
}

resource_name_is_allowed() {
  case "$1" in
    CharacterProfiles|DesktopPet|MacDog.icns|PopoverTabs)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

validate_installed_resources() {
  local resources_dir="$1"
  local resource
  local resource_name
  local required
  local index

  if [[ ! -d "$resources_dir" ]]; then
    failures+=("installed app resources missing: $resources_dir")
    return
  fi

  while IFS= read -r resource; do
    resource_name="${resource##*/}"
    if ! resource_name_is_allowed "$resource_name"; then
      failures+=("unexpected installed app resource remains: $resource")
    fi
  done < <(/usr/bin/find "$resources_dir" -mindepth 1 -maxdepth 1 -print | /usr/bin/sort)

  for required in \
    "CharacterProfiles/codex-pup-tab-art.json" \
    "MacDog.icns" \
    "PopoverTabs/codex-tab.png" \
    "PopoverTabs/mac-tab.png" \
    "PopoverTabs/sleep-tab.png" \
    "PopoverTabs/battery-tab.png" \
    "PopoverTabs/settings-tab.png"
  do
    if [[ ! -e "$resources_dir/$required" ]]; then
      failures+=("installed app current resource missing: $resources_dir/$required")
    fi
  done

  for index in 0 1 2 3 4 5 6 7; do
    required="DesktopPet/pup-run-right-$index.png"
    if [[ ! -e "$resources_dir/$required" ]]; then
      failures+=("installed app current resource missing: $resources_dir/$required")
    fi
  done
}

write_fixture_app() {
  local app="$1"
  local version="$2"
  mkdir -p "$app/Contents/MacOS"
  mkdir -p "$app/Contents/Resources/CharacterProfiles" "$app/Contents/Resources/DesktopPet" "$app/Contents/Resources/PopoverTabs"
  cat >"$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleShortVersionString</key>
  <string>$version</string>
</dict>
</plist>
PLIST
  printf '#!/usr/bin/env bash\nexit 0\n' >"$app/Contents/MacOS/codex-usage"
  chmod +x "$app/Contents/MacOS/codex-usage"
  printf '{}\n' >"$app/Contents/Resources/CharacterProfiles/codex-pup-tab-art.json"
  printf 'icon\n' >"$app/Contents/Resources/MacDog.icns"
  for tab in codex mac sleep battery settings; do
    printf 'tab\n' >"$app/Contents/Resources/PopoverTabs/$tab-tab.png"
  done
  for index in 0 1 2 3 4 5 6 7; do
    printf 'pet\n' >"$app/Contents/Resources/DesktopPet/pup-run-right-$index.png"
  done
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
  local mode="$2"
  local program="$3"
  cat >"$launchctl" <<SCRIPT
#!/usr/bin/env bash
set -euo pipefail
if [[ "\${1:-}" != "print" ]]; then
  exit 64
fi
if [[ "$mode" == "missing" ]]; then
  echo 'Bad request.' >&2
  exit 113
fi
cat <<OUTPUT
gui/501/$CACHE_LABEL = {
  program = $program
}
OUTPUT
SCRIPT
  chmod +x "$launchctl"
}

expect_success() {
  "$@" >/dev/null
}

expect_failure() {
  if "$@" >/dev/null 2>&1; then
    die "self-test expected failure but command succeeded: $*"
  fi
}

run_self_test() {
  local tmp
  SELF_TEST_TMP="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/macdog-final-state-test.XXXXXX")"
  tmp="$SELF_TEST_TMP"
  trap 'rm -rf "$SELF_TEST_TMP"' EXIT

  mkdir -p "$tmp/Applications" "$tmp/UserApplications" "$tmp/dist" "$tmp/Volumes" "$tmp/bin" "$tmp/LaunchAgents"
  write_fixture_app "$tmp/Applications/$APP_NAME.app" "9.9.9"
  write_fixture_cache_plist "$tmp/LaunchAgents/$CACHE_PLIST_NAME" "$tmp/Applications/$APP_NAME.app/Contents/MacOS/codex-usage"
  write_fixture_launchctl "$tmp/launchctl" "missing" "$tmp/Applications/$APP_NAME.app/Contents/MacOS/codex-usage"

  env \
    MACDOG_RELEASE_FINAL_APPLICATIONS_DIR="$tmp/Applications" \
    MACDOG_RELEASE_FINAL_USER_APPLICATIONS_DIR="$tmp/UserApplications" \
    MACDOG_RELEASE_FINAL_DIST_DIR="$tmp/dist" \
    MACDOG_RELEASE_FINAL_VOLUMES_DIR="$tmp/Volumes" \
    MACDOG_RELEASE_FINAL_BIN_DIR="$tmp/bin" \
    MACDOG_RELEASE_FINAL_LAUNCH_AGENTS_DIR="$tmp/LaunchAgents" \
    MACDOG_RELEASE_FINAL_LAUNCHCTL="$tmp/launchctl" \
    MACDOG_RELEASE_FINAL_USER_ID=501 \
    "$0" --version 9.9.9 >/dev/null

  write_fixture_app "$tmp/UserApplications/$APP_NAME.app" "9.9.9"
  expect_failure env \
    MACDOG_RELEASE_FINAL_APPLICATIONS_DIR="$tmp/Applications" \
    MACDOG_RELEASE_FINAL_USER_APPLICATIONS_DIR="$tmp/UserApplications" \
    MACDOG_RELEASE_FINAL_DIST_DIR="$tmp/dist" \
    MACDOG_RELEASE_FINAL_VOLUMES_DIR="$tmp/Volumes" \
    MACDOG_RELEASE_FINAL_BIN_DIR="$tmp/bin" \
    MACDOG_RELEASE_FINAL_LAUNCH_AGENTS_DIR="$tmp/LaunchAgents" \
    "$0" --version 9.9.9
  rm -rf "$tmp/UserApplications/$APP_NAME.app"

  write_fixture_app "$tmp/UserApplications/$APP_NAME.app" "9.9.9"
  ln -s "$tmp/UserApplications/$APP_NAME.app/Contents/MacOS/codex-usage" "$tmp/bin/codex-usage"
  rm -rf "$tmp/UserApplications/$APP_NAME.app"
  expect_failure env \
    MACDOG_RELEASE_FINAL_APPLICATIONS_DIR="$tmp/Applications" \
    MACDOG_RELEASE_FINAL_USER_APPLICATIONS_DIR="$tmp/UserApplications" \
    MACDOG_RELEASE_FINAL_DIST_DIR="$tmp/dist" \
    MACDOG_RELEASE_FINAL_VOLUMES_DIR="$tmp/Volumes" \
    MACDOG_RELEASE_FINAL_BIN_DIR="$tmp/bin" \
    MACDOG_RELEASE_FINAL_LAUNCH_AGENTS_DIR="$tmp/LaunchAgents" \
    "$0" --version 9.9.9
  rm -rf "$tmp/UserApplications/$APP_NAME.app"
  rm -f "$tmp/bin/codex-usage"

  write_fixture_app "$tmp/UserApplications/$APP_NAME.app" "9.9.9"
  write_fixture_cache_plist "$tmp/LaunchAgents/$CACHE_PLIST_NAME" "$tmp/UserApplications/$APP_NAME.app/Contents/MacOS/codex-usage"
  rm -rf "$tmp/UserApplications/$APP_NAME.app"
  expect_failure env \
    MACDOG_RELEASE_FINAL_APPLICATIONS_DIR="$tmp/Applications" \
    MACDOG_RELEASE_FINAL_USER_APPLICATIONS_DIR="$tmp/UserApplications" \
    MACDOG_RELEASE_FINAL_DIST_DIR="$tmp/dist" \
    MACDOG_RELEASE_FINAL_VOLUMES_DIR="$tmp/Volumes" \
    MACDOG_RELEASE_FINAL_BIN_DIR="$tmp/bin" \
    MACDOG_RELEASE_FINAL_LAUNCH_AGENTS_DIR="$tmp/LaunchAgents" \
    "$0" --version 9.9.9
  write_fixture_cache_plist "$tmp/LaunchAgents/$CACHE_PLIST_NAME" "$tmp/Applications/$APP_NAME.app/Contents/MacOS/codex-usage"

  mkdir -p "$tmp/Applications/$APP_NAME.app/Contents/Resources/Unexpected"
  expect_failure env \
    MACDOG_RELEASE_FINAL_APPLICATIONS_DIR="$tmp/Applications" \
    MACDOG_RELEASE_FINAL_USER_APPLICATIONS_DIR="$tmp/UserApplications" \
    MACDOG_RELEASE_FINAL_DIST_DIR="$tmp/dist" \
    MACDOG_RELEASE_FINAL_VOLUMES_DIR="$tmp/Volumes" \
    MACDOG_RELEASE_FINAL_BIN_DIR="$tmp/bin" \
    MACDOG_RELEASE_FINAL_LAUNCH_AGENTS_DIR="$tmp/LaunchAgents" \
    "$0" --version 9.9.9
  rm -rf "$tmp/Applications/$APP_NAME.app/Contents/Resources/Unexpected"

  write_fixture_launchctl "$tmp/launchctl" "stale" "$tmp/UserApplications/$APP_NAME.app/Contents/MacOS/codex-usage"
  expect_failure env \
    MACDOG_RELEASE_FINAL_APPLICATIONS_DIR="$tmp/Applications" \
    MACDOG_RELEASE_FINAL_USER_APPLICATIONS_DIR="$tmp/UserApplications" \
    MACDOG_RELEASE_FINAL_DIST_DIR="$tmp/dist" \
    MACDOG_RELEASE_FINAL_VOLUMES_DIR="$tmp/Volumes" \
    MACDOG_RELEASE_FINAL_BIN_DIR="$tmp/bin" \
    MACDOG_RELEASE_FINAL_LAUNCH_AGENTS_DIR="$tmp/LaunchAgents" \
    MACDOG_RELEASE_FINAL_LAUNCHCTL="$tmp/launchctl" \
    MACDOG_RELEASE_FINAL_USER_ID=501 \
    "$0" --version 9.9.9
  write_fixture_launchctl "$tmp/launchctl" "missing" "$tmp/UserApplications/$APP_NAME.app/Contents/MacOS/codex-usage"

  write_fixture_app "$tmp/dist/$APP_NAME.app" "9.9.9"
  expect_failure env \
    MACDOG_RELEASE_FINAL_APPLICATIONS_DIR="$tmp/Applications" \
    MACDOG_RELEASE_FINAL_USER_APPLICATIONS_DIR="$tmp/UserApplications" \
    MACDOG_RELEASE_FINAL_DIST_DIR="$tmp/dist" \
    MACDOG_RELEASE_FINAL_VOLUMES_DIR="$tmp/Volumes" \
    MACDOG_RELEASE_FINAL_BIN_DIR="$tmp/bin" \
    MACDOG_RELEASE_FINAL_LAUNCH_AGENTS_DIR="$tmp/LaunchAgents" \
    MACDOG_RELEASE_FINAL_LAUNCHCTL="$tmp/launchctl" \
    MACDOG_RELEASE_FINAL_USER_ID=501 \
    "$0" --version 9.9.9
  rm -rf "$tmp/dist/$APP_NAME.app"

  mkdir -p "$tmp/Volumes/$APP_NAME 9.9.9"
  expect_failure env \
    MACDOG_RELEASE_FINAL_APPLICATIONS_DIR="$tmp/Applications" \
    MACDOG_RELEASE_FINAL_USER_APPLICATIONS_DIR="$tmp/UserApplications" \
    MACDOG_RELEASE_FINAL_DIST_DIR="$tmp/dist" \
    MACDOG_RELEASE_FINAL_VOLUMES_DIR="$tmp/Volumes" \
    MACDOG_RELEASE_FINAL_BIN_DIR="$tmp/bin" \
    MACDOG_RELEASE_FINAL_LAUNCH_AGENTS_DIR="$tmp/LaunchAgents" \
    MACDOG_RELEASE_FINAL_LAUNCHCTL="$tmp/launchctl" \
    MACDOG_RELEASE_FINAL_USER_ID=501 \
    "$0" --version 9.9.9
  rm -rf "$tmp/Volumes/$APP_NAME 9.9.9"

  expect_failure env \
    MACDOG_RELEASE_FINAL_APPLICATIONS_DIR="$tmp/Applications" \
    MACDOG_RELEASE_FINAL_USER_APPLICATIONS_DIR="$tmp/UserApplications" \
    MACDOG_RELEASE_FINAL_DIST_DIR="$tmp/dist" \
    MACDOG_RELEASE_FINAL_VOLUMES_DIR="$tmp/Volumes" \
    MACDOG_RELEASE_FINAL_BIN_DIR="$tmp/bin" \
    MACDOG_RELEASE_FINAL_LAUNCH_AGENTS_DIR="$tmp/LaunchAgents" \
    MACDOG_RELEASE_FINAL_LAUNCHCTL="$tmp/launchctl" \
    MACDOG_RELEASE_FINAL_USER_ID=501 \
    "$0" --version 9.9.8

  echo "Release final state self-test ok"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      shift
      [[ $# -gt 0 ]] || die "--version requires a value"
      VERSION="$1"
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

[[ -n "$VERSION" ]] || die "--version is required"

installed_app="$APPLICATIONS_DIR/$APP_NAME.app"
installed_plist="$installed_app/Contents/Info.plist"
failures=()

if [[ ! -d "$installed_app" ]]; then
  failures+=("installed app missing: $installed_app")
elif [[ ! -f "$installed_plist" ]]; then
  failures+=("installed app Info.plist missing: $installed_plist")
else
  actual_version="$(plist_value "$installed_plist" CFBundleShortVersionString || true)"
  if [[ "$actual_version" != "$VERSION" ]]; then
    failures+=("installed app version mismatch: expected $VERSION, got ${actual_version:-missing}")
  fi
  validate_installed_resources "$installed_app/Contents/Resources"
fi

if [[ "$USER_APPLICATIONS_DIR" != "$APPLICATIONS_DIR" && -d "$USER_APPLICATIONS_DIR/$APP_NAME.app" ]]; then
  failures+=("duplicate user app remains: $USER_APPLICATIONS_DIR/$APP_NAME.app")
fi

if [[ -d "$DIST_DIR/$APP_NAME.app" ]]; then
  failures+=("release build artifact remains: $DIST_DIR/$APP_NAME.app")
fi

cli_link="$BIN_DIR/codex-usage"
if [[ -L "$cli_link" ]]; then
  cli_target="$(/usr/bin/readlink "$cli_link")"
  if [[ "$cli_target" == "$USER_APPLICATIONS_DIR/$APP_NAME.app/"* ]]; then
    failures+=("stale CLI symlink points to duplicate user app: $cli_link -> $cli_target")
  elif [[ ! -x "$cli_link" ]]; then
    failures+=("CLI symlink target is not executable: $cli_link -> $cli_target")
  fi
elif [[ -e "$cli_link" ]]; then
  failures+=("CLI path exists but is not a symlink: $cli_link")
fi

cache_plist="$LAUNCH_AGENTS_DIR/$CACHE_PLIST_NAME"
if [[ -f "$cache_plist" ]]; then
  cache_executable="$(plist_value "$cache_plist" ProgramArguments:0 || true)"
  validate_cache_executable "$cache_plist" "$cache_executable"
elif [[ -e "$cache_plist" ]]; then
  failures+=("usage cache LaunchAgent path exists but is not a regular plist: $cache_plist")
fi

loaded_executable="$(loaded_cache_executable || true)"
if [[ -n "$loaded_executable" ]]; then
  validate_cache_executable "loaded launchd job $CACHE_LABEL" "$loaded_executable"
fi

if [[ -d "$VOLUMES_DIR" ]]; then
  while IFS= read -r volume; do
    failures+=("MacDog installer volume remains mounted: $volume")
  done < <(/usr/bin/find "$VOLUMES_DIR" -maxdepth 1 -type d -name "$APP_NAME*" -print | /usr/bin/sort)
fi

if (( ${#failures[@]} > 0 )); then
  echo "error: release final state is not clean" >&2
  for failure in "${failures[@]}"; do
    echo "  - $failure" >&2
  done
  exit 1
fi

echo "Release final state ok"
