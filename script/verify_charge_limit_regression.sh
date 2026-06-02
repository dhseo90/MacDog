#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
READ_OUTPUT_FILE=""
EXPECTED_CURRENT=""
ALLOW_UNAVAILABLE=0
SELF_TEST=0

usage() {
  cat <<USAGE
usage: $0 [--read-output-file PATH] [--expected-current PERCENT] [--allow-unavailable] [--self-test]

Check the native Charge Limit regression contract without changing the system
charge limit. Without --read-output-file this runs verify_charge_limit.sh --read,
which launches MacDog in diagnostic mode and only reads the native value.

This script does not open Battery Settings and cannot visually compare the
system UI. It prints that comparison as manual-required.

Options:
  --read-output-file PATH   Parse captured verify_charge_limit.sh --read output.
  --expected-current PERCENT
                            Require the native read value to match this percent.
  --allow-unavailable       Treat charge-limit:error output as a reported state.
  --self-test               Validate parser and mismatch detection with fixtures.
USAGE
}

die() {
  echo "error: $*" >&2
  exit 1
}

require_file() {
  [[ -f "$1" ]] || die "missing required file: $1"
}

parse_read_output() {
  local output_file="$1"
  require_file "$output_file"

  if /usr/bin/grep -q '^charge-limit:error ' "$output_file"; then
    local error_message
    error_message="$(/usr/bin/sed -n 's/^charge-limit:error //p' "$output_file" | /usr/bin/head -n 1)"
    echo "native-charge-limit-regression:unavailable ${error_message:-unknown}"
    echo "battery-settings-comparison:manual-required open Battery Settings and compare the visible Charge Limit value when native support is available"
    [[ "$ALLOW_UNAVAILABLE" == "1" ]] && return 0
    return 1
  fi

  local line
  line="$(/usr/bin/grep -m1 '^charge-limit:read ' "$output_file" || true)"
  [[ -n "$line" ]] || die "missing charge-limit:read line in $output_file"

  local current
  local available
  current="$(/usr/bin/sed -n 's/.* current=\([0-9][0-9]*\).*/\1/p' <<<"$line")"
  available="$(/usr/bin/sed -n 's/.* available=\([^[:space:]]*\).*/\1/p' <<<"$line")"
  [[ "$current" =~ ^(80|85|90|95|100)$ ]] || die "unexpected current charge limit: ${current:-missing}"
  [[ -n "$available" ]] || die "missing available charge limits"

  if [[ -n "$EXPECTED_CURRENT" && "$current" != "$EXPECTED_CURRENT" ]]; then
    echo "native-charge-limit-regression:mismatch expected=$EXPECTED_CURRENT actual=$current available=$available"
    echo "battery-settings-comparison:manual-required Battery Settings visible value must be checked before marking regression verified"
    return 1
  fi

  echo "native-charge-limit-regression:ok current=$current available=$available"
  if [[ -n "$EXPECTED_CURRENT" ]]; then
    echo "native-charge-limit-regression:expected-current-matches $EXPECTED_CURRENT"
  fi
  echo "battery-settings-comparison:manual-required open Battery Settings and confirm the visible Charge Limit equals native current=$current"
  echo "native-charge-limit-regression:read-only no charge limit was changed by this verifier"
}

capture_live_read() {
  local output_file="$1"
  "$ROOT_DIR/script/verify_charge_limit.sh" --read >"$output_file"
}

run_self_test() {
  local temp_dir
  temp_dir="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/macdog-charge-regression.XXXXXX")"
  trap 'rm -rf "$temp_dir"' RETURN

  local ok_fixture="$temp_dir/charge-ok.txt"
  local unavailable_fixture="$temp_dir/charge-unavailable.txt"
  local output_file="$temp_dir/output.txt"

  printf '%s\n' 'charge-limit:read current=90 available=80,85,90,95,100' >"$ok_fixture"
  "$0" --read-output-file "$ok_fixture" --expected-current 90 >"$output_file"
  /usr/bin/grep -Fq 'native-charge-limit-regression:ok current=90 available=80,85,90,95,100' "$output_file" || die "self-test ok parse missing"
  /usr/bin/grep -Fq 'battery-settings-comparison:manual-required' "$output_file" || die "self-test manual Battery Settings boundary missing"
  /usr/bin/grep -Fq 'native-charge-limit-regression:read-only' "$output_file" || die "self-test read-only boundary missing"

  if "$0" --read-output-file "$ok_fixture" --expected-current 95 >"$output_file" 2>&1; then
    die "self-test mismatch unexpectedly passed"
  fi
  /usr/bin/grep -Fq 'native-charge-limit-regression:mismatch expected=95 actual=90' "$output_file" || die "self-test mismatch output missing"

  printf '%s\n' 'charge-limit:error unsupported' >"$unavailable_fixture"
  "$0" --read-output-file "$unavailable_fixture" --allow-unavailable >"$output_file"
  /usr/bin/grep -Fq 'native-charge-limit-regression:unavailable unsupported' "$output_file" || die "self-test unavailable output missing"

  echo "native Charge Limit regression self-test ok"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --read-output-file)
      shift
      [[ $# -gt 0 ]] || die "--read-output-file requires a path"
      READ_OUTPUT_FILE="$1"
      ;;
    --expected-current)
      shift
      [[ $# -gt 0 ]] || die "--expected-current requires a percentage"
      EXPECTED_CURRENT="$1"
      [[ "$EXPECTED_CURRENT" =~ ^(80|85|90|95|100)$ ]] || die "--expected-current requires one of 80,85,90,95,100"
      ;;
    --allow-unavailable) ALLOW_UNAVAILABLE=1 ;;
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

if [[ -n "$READ_OUTPUT_FILE" ]]; then
  parse_read_output "$READ_OUTPUT_FILE"
else
  temp_output="$(/usr/bin/mktemp "${TMPDIR:-/tmp}/macdog-charge-regression-read.XXXXXX")"
  trap 'rm -f "$temp_output"' EXIT
  capture_live_read "$temp_output"
  parse_read_output "$temp_output"
fi
