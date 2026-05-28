#!/usr/bin/env bash
set -euo pipefail

ALLOW_UNAVAILABLE=0
TIMEOUT_SECONDS=8

usage() {
  cat <<USAGE
usage: $0 [--allow-unavailable]

Read-only probe for the macOS Shortcuts CLI. This does not create, run, or
modify shortcuts and does not change Charge Limit settings.

Options:
  --allow-unavailable  Report Shortcuts CLI/helper failures without failing.
USAGE
}

die() {
  echo "error: $*" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --allow-unavailable) ALLOW_UNAVAILABLE=1 ;;
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

finish_unavailable() {
  local message="$1"
  echo "shortcuts:unavailable $message"
  echo "charge-limit-shortcuts:skipped native Charge Limit remains the primary implementation"
  if [[ "$ALLOW_UNAVAILABLE" == "1" ]]; then
    exit 0
  fi
  exit 1
}

run_shortcuts_list() {
  local output_file="$1"
  local error_file="$2"
  /usr/bin/shortcuts list >"$output_file" 2>"$error_file" &
  local pid=$!

  for _ in $(seq 1 "$TIMEOUT_SECONDS"); do
    if ! kill -0 "$pid" >/dev/null 2>&1; then
      wait "$pid"
      return $?
    fi
    sleep 1
  done

  kill "$pid" >/dev/null 2>&1 || true
  wait "$pid" >/dev/null 2>&1 || true
  return 124
}

if [[ ! -x /usr/bin/shortcuts ]]; then
  finish_unavailable "cli-missing"
fi

output_file="$(/usr/bin/mktemp "${TMPDIR:-/tmp}/macdog-shortcuts-list.XXXXXX")"
error_file="$(/usr/bin/mktemp "${TMPDIR:-/tmp}/macdog-shortcuts-error.XXXXXX")"
trap 'rm -f "$output_file" "$error_file"' EXIT

set +e
run_shortcuts_list "$output_file" "$error_file"
status=$?
set -e

if [[ "$status" == "124" ]]; then
  finish_unavailable "list-timeout"
fi

if [[ "$status" != "0" ]]; then
  error_message="$(tr '\n' ' ' <"$error_file" | sed 's/[[:space:]]*$//')"
  finish_unavailable "${error_message:-list-failed}"
fi

shortcut_count="$(grep -cve '^[[:space:]]*$' "$output_file" || true)"
echo "shortcuts:available count=$shortcut_count"
echo "charge-limit-shortcuts:read-only-probe-ok no shortcuts were created, run, or modified"
