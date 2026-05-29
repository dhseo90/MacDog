#!/usr/bin/env bash
set -euo pipefail

ALLOW_UNAVAILABLE=0
TIMEOUT_SECONDS=8
LIST_FILE=""

usage() {
  cat <<USAGE
usage: $0 [--allow-unavailable] [--list-file PATH]

Read-only probe for the macOS Shortcuts CLI. This does not create, run, or
modify shortcuts and does not change Charge Limit settings.

Options:
  --allow-unavailable  Report Shortcuts CLI/helper failures without failing.
  --list-file PATH     Parse a captured 'shortcuts list' output instead of
                       calling the Shortcuts CLI. This is parser-only.
USAGE
}

die() {
  echo "error: $*" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --allow-unavailable) ALLOW_UNAVAILABLE=1 ;;
    --list-file)
      shift
      [[ $# -gt 0 ]] || die "--list-file requires a path"
      LIST_FILE="$1"
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

emit_candidate_summary() {
  local output_file="$1"
  local candidate_file
  local candidate_count
  candidate_file="$(/usr/bin/mktemp "${TMPDIR:-/tmp}/macdog-shortcuts-candidates.XXXXXX")"
  /usr/bin/grep -Ei 'charge|battery|limit|충전|배터리|한도' "$output_file" >"$candidate_file" || true
  candidate_count="$(/usr/bin/grep -cve '^[[:space:]]*$' "$candidate_file" || true)"

  echo "charge-limit-shortcuts:candidates count=$candidate_count"
  if [[ "$candidate_count" != "0" ]]; then
    while IFS= read -r shortcut_name; do
      [[ -n "${shortcut_name//[[:space:]]/}" ]] || continue
      echo "charge-limit-shortcuts:candidate $shortcut_name"
    done <"$candidate_file"
  fi
  rm -f "$candidate_file"
}

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

if [[ -z "$LIST_FILE" && ! -x /usr/bin/shortcuts ]]; then
  finish_unavailable "cli-missing"
fi

output_file="$(/usr/bin/mktemp "${TMPDIR:-/tmp}/macdog-shortcuts-list.XXXXXX")"
error_file="$(/usr/bin/mktemp "${TMPDIR:-/tmp}/macdog-shortcuts-error.XXXXXX")"
trap 'rm -f "$output_file" "$error_file"' EXIT

if [[ -n "$LIST_FILE" ]]; then
  [[ -f "$LIST_FILE" ]] || die "list file not found: $LIST_FILE"
  /bin/cp "$LIST_FILE" "$output_file"
else
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
fi

shortcut_count="$(grep -cve '^[[:space:]]*$' "$output_file" || true)"
echo "shortcuts:available count=$shortcut_count"
emit_candidate_summary "$output_file"
echo "charge-limit-shortcuts:contract-unverified shortcut actions were not run or modified"
echo "charge-limit-shortcuts:read-only-probe-ok no shortcuts were created, run, or modified"
