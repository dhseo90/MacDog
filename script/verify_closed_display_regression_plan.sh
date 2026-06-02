#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PMSET_LIVE_FILE=""
HELPER_STATE_FILE=""
SELF_TEST=0

usage() {
  cat <<USAGE
usage: $0 [--pmset-live-file PATH] [--helper-state-file PATH] [--self-test]

Read the local closed-display regression preflight state. This script does not
change SleepDisabled, install or uninstall helpers, close the display, wait for
a long run, or mark closed-display verification complete.

Options:
  --pmset-live-file PATH     Parse captured 'pmset -g live' output.
  --helper-state-file PATH   Parse captured verify_privileged_helper_state.sh output.
  --self-test                Validate parser output with local fixtures.
USAGE
}

die() {
  echo "error: $*" >&2
  exit 1
}

require_file() {
  [[ -f "$1" ]] || die "missing required file: $1"
}

read_file_or_command() {
  local file="$1"
  shift

  if [[ -n "$file" ]]; then
    require_file "$file"
    /bin/cat "$file"
  else
    "$@"
  fi
}

sleep_disabled_value() {
  local file="$1"
  /usr/bin/awk '
    /SleepDisabled/ {
      for (i = NF; i >= 1; i--) {
        if ($i == "0" || $i == "1") {
          print $i
          exit
        }
      }
    }
  ' "$file"
}

helper_summary() {
  local file="$1"
  if /usr/bin/grep -q '^helper:installed launchd:loaded' "$file"; then
    echo "installed-loaded"
  elif /usr/bin/grep -q '^helper:installed launchd:not-loaded' "$file"; then
    echo "installed-not-loaded"
  elif /usr/bin/grep -q '^helper:missing' "$file"; then
    echo "missing"
  else
    echo "unknown"
  fi
}

verify_preflight() {
  local temp_dir
  temp_dir="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/macdog-closed-display.XXXXXX")"
  trap 'rm -rf "$temp_dir"' RETURN

  local pmset_file="$temp_dir/pmset-live.txt"
  local helper_file="$temp_dir/helper-state.txt"
  read_file_or_command "$PMSET_LIVE_FILE" /usr/bin/pmset -g live >"$pmset_file"
  read_file_or_command "$HELPER_STATE_FILE" "$ROOT_DIR/script/verify_privileged_helper_state.sh" --allow-missing >"$helper_file"

  local sleep_disabled
  local helper
  sleep_disabled="$(sleep_disabled_value "$pmset_file")"
  helper="$(helper_summary "$helper_file")"
  [[ -n "$sleep_disabled" ]] || sleep_disabled="unknown"

  echo "closed-display-regression:read-only-preflight"
  echo "sleep-disabled-current: $sleep_disabled"
  echo "helper-state: $helper"
  echo "closed-display-regression:does-not-change SleepDisabled helper install state or screen lock state"
  echo "closed-display-regression:long-run-required yes"
  echo "closed-display-regression:manual-evidence-required close display after macOS update/helper reinstall/public install change and record duration, power state, SleepDisabled before/after, lock/sleep result"

  case "$sleep_disabled:$helper" in
    1:installed-loaded)
      echo "closed-display-regression:readiness ready-for-approved-long-run"
      ;;
    1:*)
      echo "closed-display-regression:readiness helper-review-before-long-run"
      ;;
    0:*|unknown:*)
      echo "closed-display-regression:readiness enable-through-approved-ui-or-helper-before-long-run"
      ;;
  esac
}

run_self_test() {
  local temp_dir
  temp_dir="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/macdog-closed-display-self.XXXXXX")"
  trap 'rm -rf "$temp_dir"' RETURN

  local pmset_file="$temp_dir/pmset-live.txt"
  local helper_file="$temp_dir/helper-state.txt"
  local output_file="$temp_dir/output.txt"

  cat >"$pmset_file" <<'PMSET'
System-wide power settings:
 SleepDisabled		1
PMSET
  printf '%s\n' 'helper:installed launchd:loaded' >"$helper_file"

  "$0" --pmset-live-file "$pmset_file" --helper-state-file "$helper_file" >"$output_file"
  /usr/bin/grep -Fq 'closed-display-regression:read-only-preflight' "$output_file" || die "self-test preflight marker missing"
  /usr/bin/grep -Fq 'sleep-disabled-current: 1' "$output_file" || die "self-test SleepDisabled parse missing"
  /usr/bin/grep -Fq 'helper-state: installed-loaded' "$output_file" || die "self-test helper parse missing"
  /usr/bin/grep -Fq 'closed-display-regression:long-run-required yes' "$output_file" || die "self-test long-run boundary missing"
  /usr/bin/grep -Fq 'closed-display-regression:readiness ready-for-approved-long-run' "$output_file" || die "self-test readiness missing"

  printf '%s\n' ' SleepDisabled 0' >"$pmset_file"
  printf '%s\n' 'helper:missing' >"$helper_file"
  "$0" --pmset-live-file "$pmset_file" --helper-state-file "$helper_file" >"$output_file"
  /usr/bin/grep -Fq 'closed-display-regression:readiness enable-through-approved-ui-or-helper-before-long-run' "$output_file" || die "self-test disabled readiness missing"

  echo "closed-display regression preflight self-test ok"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --pmset-live-file)
      shift
      [[ $# -gt 0 ]] || die "--pmset-live-file requires a path"
      PMSET_LIVE_FILE="$1"
      ;;
    --helper-state-file)
      shift
      [[ $# -gt 0 ]] || die "--helper-state-file requires a path"
      HELPER_STATE_FILE="$1"
      ;;
    --self-test) SELF_TEST=1 ;;
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

cd "$ROOT_DIR"

if [[ "$SELF_TEST" == "1" ]]; then
  run_self_test
  exit 0
fi

verify_preflight
