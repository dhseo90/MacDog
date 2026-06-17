#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-report}"
EXPECT_WIDGET=0
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="MacDog"
BUNDLE_ID="com.dhseo.macdog.MacDog"
DIST_APP="$ROOT_DIR/dist/$APP_NAME.app"
USER_APP_DEST="$HOME/Applications/$APP_NAME.app"
SYSTEM_APP_DEST="/Applications/$APP_NAME.app"
CLI_DEST="$HOME/bin/codex-usage"
CACHE_PLIST="$HOME/Library/LaunchAgents/com.dhseo.macdog.usage-cache.plist"
MONITOR_PLIST="$HOME/Library/LaunchAgents/com.dhseo.macdog.monitor.plist"
LOGIN_LAUNCH_KEY="loginLaunchEnabled"

case "$MODE" in
  report|--report) ;;
  --expect-installed|expect-installed) ;;
  --expect-uninstalled|expect-uninstalled) ;;
  --expect-current-dist|expect-current-dist) ;;
  --expect-installed-with-widget|expect-installed-with-widget)
    EXPECT_WIDGET=1
    MODE="--expect-installed"
    ;;
  --expect-current-dist-with-widget|expect-current-dist-with-widget)
    EXPECT_WIDGET=1
    MODE="--expect-current-dist"
    ;;
  --explain-current-dist|explain-current-dist) ;;
  --self-test|self-test) ;;
  -h|--help|help)
    echo "usage: $0 [--report|--expect-installed|--expect-installed-with-widget|--expect-uninstalled|--expect-current-dist|--expect-current-dist-with-widget|--explain-current-dist|--self-test]"
    exit 0
    ;;
  *)
    echo "usage: $0 [--report|--expect-installed|--expect-installed-with-widget|--expect-uninstalled|--expect-current-dist|--expect-current-dist-with-widget|--explain-current-dist|--self-test]" >&2
    exit 2
    ;;
esac

die() {
  echo "error: $*" >&2
  exit 1
}

present() {
  [[ -e "$1" ]]
}

executable() {
  [[ -x "$1" ]]
}

plist_value() {
  /usr/libexec/PlistBuddy -c "Print $1" "$2"
}

plist_contains_argument() {
  local plist="$1"
  local expected="$2"
  local index=0
  local value
  while value="$(plist_value ":ProgramArguments:$index" "$plist" 2>/dev/null)"; do
    [[ "$value" == "$expected" ]] && return 0
    index=$((index + 1))
  done
  return 1
}

installed_app_dest() {
  if present "$SYSTEM_APP_DEST"; then
    printf '%s' "$SYSTEM_APP_DEST"
    return 0
  fi
  if present "$USER_APP_DEST"; then
    printf '%s' "$USER_APP_DEST"
    return 0
  fi
  printf '%s' "$USER_APP_DEST"
}

app_binary_for() {
  printf '%s/Contents/MacOS/%s' "$1" "$APP_NAME"
}

app_cli_binary_for() {
  printf '%s/Contents/MacOS/codex-usage' "$1"
}

widget_appex_for() {
  printf '%s/Contents/PlugIns/MacDogWidgetExtension.appex' "$1"
}

widget_binary_for() {
  printf '%s/Contents/PlugIns/MacDogWidgetExtension.appex/Contents/MacOS/MacDogWidgetExtension' "$1"
}

installed_app_count() {
  local count=0
  present "$SYSTEM_APP_DEST" && count=$((count + 1))
  present "$USER_APP_DEST" && count=$((count + 1))
  printf '%s' "$count"
}

login_launch_enabled() {
  local value
  value="$(/usr/bin/defaults read "$BUNDLE_ID" "$LOGIN_LAUNCH_KEY" 2>/dev/null || true)"
  [[ -z "$value" || "$value" == "1" || "$value" == "true" || "$value" == "TRUE" || "$value" == "YES" ]]
}

login_item_status_from_output() {
  local output="$1"
  local status
  status="$(printf '%s\n' "$output" | /usr/bin/awk '/^login-item:status / { print $2; exit }')"
  if [[ -n "$status" ]]; then
    printf '%s' "$status"
  else
    printf 'unknown'
  fi
}

login_item_status_for() {
  local app_binary="$1"
  if [[ ! -x "$app_binary" ]]; then
    printf 'unavailable'
    return 0
  fi

  local output
  local status
  set +e
  output="$("$app_binary" --verify-login-item-status 2>&1)"
  status=$?
  set -e
  login_item_status_from_output "$output"
  return 0
}

bundle_manifest() {
  local bundle="$1"
  (
    cd "$bundle"
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

compare_app_bundles() {
  local expected="$1"
  local actual="$2"
  local label="$3"
  local verbosity="${4:-verbose}"

  [[ -d "$expected" ]] || { echo "$label:missing-source $expected" >&2; return 1; }
  [[ -d "$actual" ]] || { echo "$label:missing-installed $actual" >&2; return 1; }

  local expected_manifest
  local actual_manifest
  expected_manifest="$(/usr/bin/mktemp "${TMPDIR:-/tmp}/macdog-expected.XXXXXX")"
  actual_manifest="$(/usr/bin/mktemp "${TMPDIR:-/tmp}/macdog-actual.XXXXXX")"
  bundle_manifest "$expected" >"$expected_manifest"
  bundle_manifest "$actual" >"$actual_manifest"

  if /usr/bin/cmp -s "$expected_manifest" "$actual_manifest"; then
    rm -f "$expected_manifest" "$actual_manifest"
    [[ "$verbosity" == "quiet" ]] || echo "$label:matches-dist $actual"
    return 0
  fi

  if [[ "$verbosity" != "quiet" ]]; then
    echo "$label:differs-from-dist expected:$expected actual:$actual" >&2
    /usr/bin/diff -u "$expected_manifest" "$actual_manifest" | /usr/bin/sed -n '1,80p' >&2 || true
  fi
  rm -f "$expected_manifest" "$actual_manifest"
  return 1
}

explain_app_bundle_difference() {
  local expected="$1"
  local actual="$2"
  local label="$3"

  [[ -d "$expected" ]] || { echo "$label:missing-source $expected"; return 0; }
  [[ -d "$actual" ]] || { echo "$label:missing-installed $actual"; return 0; }

  local expected_manifest
  local actual_manifest
  expected_manifest="$(/usr/bin/mktemp "${TMPDIR:-/tmp}/macdog-expected.XXXXXX")"
  actual_manifest="$(/usr/bin/mktemp "${TMPDIR:-/tmp}/macdog-actual.XXXXXX")"
  bundle_manifest "$expected" >"$expected_manifest"
  bundle_manifest "$actual" >"$actual_manifest"

  if /usr/bin/cmp -s "$expected_manifest" "$actual_manifest"; then
    echo "$label:matches-dist $actual"
    rm -f "$expected_manifest" "$actual_manifest"
    return 0
  fi

  echo "$label:differs-from-dist expected:$expected actual:$actual"
  /usr/bin/ruby - "$expected_manifest" "$actual_manifest" "$label" <<'RUBY'
expected_path = ARGV.fetch(0)
actual_path = ARGV.fetch(1)
label = ARGV.fetch(2)

def read_manifest(path)
  File.readlines(path, chomp: true).each_with_object({}) do |line, entries|
    hash, payload_path = line.split(/\s{2}/, 2)
    next if hash.to_s.empty? || payload_path.to_s.empty?
    entries[payload_path] = hash
  end
end

expected = read_manifest(expected_path)
actual = read_manifest(actual_path)
expected_paths = expected.keys
actual_paths = actual.keys

changed = (expected_paths & actual_paths).select { |path| expected.fetch(path) != actual.fetch(path) }.sort
removed = (expected_paths - actual_paths).sort
added = (actual_paths - expected_paths).sort

puts "#{label}:changed-count:#{changed.length}"
changed.each { |path| puts "#{label}:changed #{path}" }
puts "#{label}:removed-count:#{removed.length}"
removed.each { |path| puts "#{label}:removed #{path}" }
puts "#{label}:added-count:#{added.length}"
added.each { |path| puts "#{label}:added #{path}" }
RUBY
  rm -f "$expected_manifest" "$actual_manifest"
}

print_process_state() {
  local app_dest
  local app_binary
  app_dest="$(installed_app_dest)"
  app_binary="$(app_binary_for "$app_dest")"
  local output
  local status
  output="$(pgrep -x "$APP_NAME" 2>&1)" || status=$?
  status="${status:-0}"

  if [[ "$status" == "0" ]]; then
    local count
    count="$(printf '%s\n' "$output" | /usr/bin/grep -Ec '^[0-9]+$' || true)"
    echo "process:running $APP_NAME count:$count"
    while IFS= read -r pid; do
      [[ "$pid" =~ ^[0-9]+$ ]] || continue
      local command_path
      command_path="$(/bin/ps -p "$pid" -o comm= 2>/dev/null | /usr/bin/sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
      if [[ -z "$command_path" ]]; then
        echo "process-path:$pid unknown"
      else
        echo "process-path:$pid $command_path"
        if [[ "$command_path" == "$app_binary" ]]; then
          echo "process-freshness:$pid installed-app-binary"
        else
          echo "process-freshness:$pid different-binary expected:$app_binary actual:$command_path"
        fi
      fi
    done <<<"$output"
  elif [[ "$status" == "1" ]]; then
    echo "process:not-running $APP_NAME"
  else
    echo "process:unknown $APP_NAME ($output)"
  fi
}

expect_running_process_current_if_known() {
  local app_dest
  local app_binary
  app_dest="$(installed_app_dest)"
  app_binary="$(app_binary_for "$app_dest")"
  local output
  local status
  output="$(pgrep -x "$APP_NAME" 2>&1)" || status=$?
  status="${status:-0}"

  [[ "$status" == "0" ]] || return 0

  while IFS= read -r pid; do
    [[ "$pid" =~ ^[0-9]+$ ]] || continue
    local command_path
    command_path="$(/bin/ps -p "$pid" -o comm= 2>/dev/null | /usr/bin/sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [[ -n "$command_path" ]] || continue
    [[ "$command_path" == "$app_binary" ]] || {
      echo "running MacDog process uses a different binary: pid=$pid expected:$app_binary actual:$command_path" >&2
      return 1
    }
  done <<<"$output"
}

print_state() {
  local app_dest
  local app_binary
  local app_cli_binary
  local widget_appex
  local widget_binary
  app_dest="$(installed_app_dest)"
  app_binary="$(app_binary_for "$app_dest")"
  app_cli_binary="$(app_cli_binary_for "$app_dest")"
  widget_appex="$(widget_appex_for "$app_dest")"
  widget_binary="$(widget_binary_for "$app_dest")"

  if present "$SYSTEM_APP_DEST"; then echo "system-app:present $SYSTEM_APP_DEST"; else echo "system-app:absent $SYSTEM_APP_DEST"; fi
  if present "$USER_APP_DEST"; then echo "user-app:present $USER_APP_DEST"; else echo "user-app:absent $USER_APP_DEST"; fi
  echo "active-app:$app_dest"
  if executable "$app_binary"; then echo "app-binary:executable $app_binary"; else echo "app-binary:missing-or-not-executable $app_binary"; fi
  if executable "$app_cli_binary"; then echo "app-cli:executable $app_cli_binary"; else echo "app-cli:missing-or-not-executable $app_cli_binary"; fi
  if present "$widget_appex"; then echo "widget-appex:present $widget_appex"; else echo "widget-appex:absent $widget_appex"; fi
  if executable "$widget_binary"; then echo "widget-binary:executable $widget_binary"; else echo "widget-binary:missing-or-not-executable $widget_binary"; fi
  if executable "$CLI_DEST"; then echo "cli:executable $CLI_DEST"; else echo "cli:missing-or-not-executable $CLI_DEST"; fi
  if [[ -L "$CLI_DEST" ]]; then echo "cli-link:$(/bin/ls -l "$CLI_DEST" | /usr/bin/sed 's/^.* -> //')"; fi
  if present "$CACHE_PLIST"; then echo "cache-plist:present $CACHE_PLIST"; else echo "cache-plist:absent $CACHE_PLIST"; fi
  if present "$CACHE_PLIST"; then echo "cache-executable:$(plist_value ':ProgramArguments:0' "$CACHE_PLIST")"; fi
  if present "$CACHE_PLIST"; then
    if plist_contains_argument "$CACHE_PLIST" "--mirror-cache"; then
      echo "cache-widget-mirror:enabled"
    else
      echo "cache-widget-mirror:disabled"
    fi
  fi
  if login_launch_enabled; then echo "login-launch-enabled:true"; else echo "login-launch-enabled:false"; fi
  echo "login-item-status:$(login_item_status_for "$app_binary")"
  if present "$MONITOR_PLIST"; then echo "legacy-monitor-plist:present $MONITOR_PLIST"; else echo "legacy-monitor-plist:absent $MONITOR_PLIST"; fi
  if [[ -d "$DIST_APP" && -d "$app_dest" ]]; then
    if compare_app_bundles "$DIST_APP" "$app_dest" "app-freshness" quiet; then
      echo "app-freshness:matches-dist $app_dest"
    else
      echo "app-freshness:differs-from-dist expected:$DIST_APP actual:$app_dest"
    fi
  elif [[ -d "$DIST_APP" ]]; then
    echo "app-freshness:installed-app-missing $app_dest"
  else
    echo "app-freshness:dist-app-missing $DIST_APP"
  fi
  print_process_state
}

expect_installed() {
  local app_dest
  local app_binary
  local app_cli_binary
  local widget_appex
  local widget_binary
  app_dest="$(installed_app_dest)"
  app_binary="$(app_binary_for "$app_dest")"
  app_cli_binary="$(app_cli_binary_for "$app_dest")"
  widget_appex="$(widget_appex_for "$app_dest")"
  widget_binary="$(widget_binary_for "$app_dest")"

  [[ "$(installed_app_count)" == "1" ]] || {
    echo "expected exactly one MacDog app install; found system=$([[ -d "$SYSTEM_APP_DEST" ]] && echo present || echo absent) user=$([[ -d "$USER_APP_DEST" ]] && echo present || echo absent)" >&2
    return 1
  }
  executable "$app_binary" || { echo "expected installed app binary: $app_binary" >&2; return 1; }
  executable "$app_cli_binary" || { echo "expected bundled CLI: $app_cli_binary" >&2; return 1; }
  executable "$CLI_DEST" || { echo "expected installed CLI: $CLI_DEST" >&2; return 1; }
  [[ -L "$CLI_DEST" ]] || { echo "expected installed CLI to be a symlink: $CLI_DEST" >&2; return 1; }
  [[ "$(readlink "$CLI_DEST")" == "$app_cli_binary" ]] || {
    echo "expected CLI symlink to target bundled CLI: $CLI_DEST -> $app_cli_binary" >&2
    return 1
  }
  if [[ "$EXPECT_WIDGET" == "1" ]]; then
    present "$widget_appex" || { echo "expected installed widget extension: $widget_appex" >&2; return 1; }
    executable "$widget_binary" || { echo "expected installed widget binary: $widget_binary" >&2; return 1; }
  else
    ! present "$widget_appex" || { echo "expected default install to omit widget extension: $widget_appex" >&2; return 1; }
  fi
  present "$CACHE_PLIST" || { echo "expected cache LaunchAgent plist: $CACHE_PLIST" >&2; return 1; }
  [[ "$(plist_value ':ProgramArguments:0' "$CACHE_PLIST")" == "$app_cli_binary" ]] || {
    echo "expected cache LaunchAgent to run bundled CLI: $app_cli_binary" >&2
    return 1
  }
  [[ "$(plist_value ':StartInterval' "$CACHE_PLIST" 2>/dev/null || true)" == "60" ]] || {
    echo "expected cache LaunchAgent StartInterval to be 60 seconds" >&2
    return 1
  }
  ! plist_contains_argument "$CACHE_PLIST" "--watch" || {
    echo "expected cache LaunchAgent to run one-shot writer without --watch" >&2
    return 1
  }
  if [[ "$EXPECT_WIDGET" == "1" ]]; then
    plist_contains_argument "$CACHE_PLIST" "--mirror-cache" || {
      echo "expected cache LaunchAgent to mirror cache for WidgetKit" >&2
      return 1
    }
  else
    ! plist_contains_argument "$CACHE_PLIST" "--mirror-cache" || {
      echo "expected default cache LaunchAgent to omit WidgetKit mirror argument" >&2
      return 1
    }
  fi
  if login_launch_enabled; then
    local login_item_status
    login_item_status="$(login_item_status_for "$app_binary")"
    [[ "$login_item_status" == "enabled" ]] || {
      echo "expected login item status enabled because $LOGIN_LAUNCH_KEY is true: got $login_item_status" >&2
      return 1
    }
  fi
  ! present "$MONITOR_PLIST" || { echo "expected legacy monitor plist to be absent: $MONITOR_PLIST" >&2; return 1; }
}

expect_uninstalled() {
  ! present "$SYSTEM_APP_DEST" || { echo "expected app to be absent: $SYSTEM_APP_DEST" >&2; return 1; }
  ! present "$USER_APP_DEST" || { echo "expected app to be absent: $USER_APP_DEST" >&2; return 1; }
  ! present "$CLI_DEST" || { echo "expected CLI to be absent: $CLI_DEST" >&2; return 1; }
  ! present "$CACHE_PLIST" || { echo "expected cache plist to be absent: $CACHE_PLIST" >&2; return 1; }
  ! present "$MONITOR_PLIST" || { echo "expected legacy monitor plist to be absent: $MONITOR_PLIST" >&2; return 1; }
}

expect_current_dist() {
  local app_dest
  app_dest="$(installed_app_dest)"
  expect_installed
  compare_app_bundles "$DIST_APP" "$app_dest" "app-freshness"
  expect_running_process_current_if_known
}

explain_current_dist() {
  local app_dest
  app_dest="$(installed_app_dest)"
  explain_app_bundle_difference "$DIST_APP" "$app_dest" "app-freshness-detail"
}

run_self_test() {
  local temp_dir
  temp_dir="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/macdog-install-state.XXXXXX")"
  trap 'rm -rf "$temp_dir"' RETURN

  local expected="$temp_dir/expected/MacDog.app"
  local actual="$temp_dir/actual/MacDog.app"
  /bin/mkdir -p "$expected/Contents/MacOS" "$expected/Contents/Resources" "$actual/Contents/MacOS" "$actual/Contents/Resources"

  printf 'new app binary\n' >"$expected/Contents/MacOS/MacDog"
  printf 'old app binary\n' >"$actual/Contents/MacOS/MacDog"
  printf 'same resource\n' >"$expected/Contents/Resources/Shared.txt"
  printf 'same resource\n' >"$actual/Contents/Resources/Shared.txt"
  printf 'removed resource\n' >"$expected/Contents/Resources/Removed.txt"
  printf 'added resource\n' >"$actual/Contents/Resources/Added.txt"

  local output
  output="$(explain_app_bundle_difference "$expected" "$actual" "self-test")"
  printf '%s\n' "$output" | /usr/bin/grep -Fq 'self-test:differs-from-dist' || die "self-test missing differs output"
  printf '%s\n' "$output" | /usr/bin/grep -Fq 'self-test:changed-count:1' || die "self-test missing changed count"
  printf '%s\n' "$output" | /usr/bin/grep -Fq 'self-test:changed Contents/MacOS/MacDog' || die "self-test missing changed app binary"
  printf '%s\n' "$output" | /usr/bin/grep -Fq 'self-test:removed-count:1' || die "self-test missing removed count"
  printf '%s\n' "$output" | /usr/bin/grep -Fq 'self-test:removed Contents/Resources/Removed.txt' || die "self-test missing removed resource"
  printf '%s\n' "$output" | /usr/bin/grep -Fq 'self-test:added-count:1' || die "self-test missing added count"
  printf '%s\n' "$output" | /usr/bin/grep -Fq 'self-test:added Contents/Resources/Added.txt' || die "self-test missing added resource"

  /bin/rm -rf "$actual"
  /usr/bin/ditto --norsrc --noextattr "$expected" "$actual"
  output="$(explain_app_bundle_difference "$expected" "$actual" "self-test")"
  printf '%s\n' "$output" | /usr/bin/grep -Fq 'self-test:matches-dist' || die "self-test missing matches output"

  output="$(explain_app_bundle_difference "$temp_dir/missing/MacDog.app" "$actual" "self-test")"
  printf '%s\n' "$output" | /usr/bin/grep -Fq 'self-test:missing-source' || die "self-test missing source output"

  output="$(explain_app_bundle_difference "$expected" "$temp_dir/missing/MacDog.app" "self-test")"
  printf '%s\n' "$output" | /usr/bin/grep -Fq 'self-test:missing-installed' || die "self-test missing installed output"

  output="$(login_item_status_from_output $'noise\nlogin-item:status enabled\n')"
  [[ "$output" == "enabled" ]] || die "self-test missing login item enabled status parser"

  output="$(login_item_status_from_output $'login-item:status requiresApproval\n')"
  [[ "$output" == "requiresApproval" ]] || die "self-test missing login item requiresApproval status parser"

  output="$(login_item_status_from_output 'login-item:error unavailable')"
  [[ "$output" == "unknown" ]] || die "self-test missing login item unknown fallback"

  local login_probe="$temp_dir/login-probe"
  cat >"$login_probe" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "--verify-login-item-status" ]]; then
  echo "login-item:status enabled"
  exit 0
fi
exit 64
SCRIPT
  chmod +x "$login_probe"
  output="$(login_item_status_for "$login_probe")"
  [[ "$output" == "enabled" ]] || die "self-test missing login item status probe"

  output="$(login_item_status_for "$temp_dir/missing-probe")"
  [[ "$output" == "unavailable" ]] || die "self-test missing unavailable login item status"

  echo "Install state freshness detail self-test ok"
}

if [[ "$MODE" == "--self-test" || "$MODE" == "self-test" ]]; then
  run_self_test
  exit 0
fi

if [[ "$MODE" != "--explain-current-dist" && "$MODE" != "explain-current-dist" ]]; then
  print_state
fi
case "$MODE" in
  --expect-installed|expect-installed)
    expect_installed
    echo "Install state ok: installed"
    ;;
  --expect-uninstalled|expect-uninstalled)
    expect_uninstalled
    echo "Install state ok: uninstalled"
    ;;
  --expect-current-dist|expect-current-dist)
    expect_current_dist
    echo "Install state ok: current-dist"
    ;;
  --explain-current-dist|explain-current-dist)
    explain_current_dist
    ;;
esac
