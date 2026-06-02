#!/usr/bin/env bash
set -euo pipefail

ALLOW_UNAVAILABLE=0
TIMEOUT_SECONDS=8
LIST_FILE=""
CONTRACT_FILE=""
SELF_TEST=0

usage() {
  cat <<USAGE
usage: $0 [--allow-unavailable] [--list-file PATH] [--contract-file PATH] [--self-test]

Read-only probe for the macOS Shortcuts CLI. This does not create, run, or
modify shortcuts and does not change Charge Limit settings.

Options:
  --allow-unavailable  Report Shortcuts CLI/helper failures without failing.
  --list-file PATH     Parse a captured 'shortcuts list' output instead of
                       calling the Shortcuts CLI. This is parser-only.
  --contract-file PATH  Validate a manually captured Charge Limit shortcut
                       action/input contract JSON. This is parser-only and
                       does not run the shortcut.
  --self-test          Verify candidate parsing with a local fixture only.
USAGE
}

die() {
  echo "error: $*" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --allow-unavailable) ALLOW_UNAVAILABLE=1 ;;
    --self-test) SELF_TEST=1 ;;
    --list-file)
      shift
      [[ $# -gt 0 ]] || die "--list-file requires a path"
      LIST_FILE="$1"
      ;;
    --contract-file)
      shift
      [[ $# -gt 0 ]] || die "--contract-file requires a path"
      CONTRACT_FILE="$1"
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

validate_contract_file() {
  local contract_file="$1"
  [[ -f "$contract_file" ]] || die "contract file not found: $contract_file"

  /usr/bin/ruby -rjson - "$contract_file" <<'RUBY'
path = ARGV.fetch(0)
data = JSON.parse(File.read(path))

action_name = data.fetch("actionName")
input = data.fetch("input")
type = input.fetch("type")
transport = input.fetch("transport")
allowed_values = input.fetch("allowedValues")

unless action_name.is_a?(String) && !action_name.strip.empty?
  abort("error: actionName must be a non-empty string")
end

unless ["integer", "number"].include?(type)
  abort("error: input.type must be integer or number")
end

expected_values = [80, 85, 90, 95, 100]
unless allowed_values == expected_values
  abort("error: input.allowedValues must be #{expected_values.inspect}")
end

unless transport.is_a?(String) && !transport.strip.empty?
  abort("error: input.transport must describe how the value is supplied")
end

confirmed_by = data["confirmedBy"] || "unrecorded"
confirmed_at = data["confirmedAt"] || "unrecorded"
puts "charge-limit-shortcuts:input-contract verified action=#{action_name.inspect} type=#{type} allowedValues=#{allowed_values.join(",")} transport=#{transport.inspect} confirmedBy=#{confirmed_by.inspect} confirmedAt=#{confirmed_at.inspect}"
RUBY
}

run_self_test() {
  local fixture_file
  local contract_file
  local output_file
  fixture_file="$(/usr/bin/mktemp "${TMPDIR:-/tmp}/macdog-shortcuts-fixture.XXXXXX")"
  contract_file="$(/usr/bin/mktemp "${TMPDIR:-/tmp}/macdog-shortcuts-contract.XXXXXX")"
  output_file="$(/usr/bin/mktemp "${TMPDIR:-/tmp}/macdog-shortcuts-self-test.XXXXXX")"
  trap 'rm -f "$fixture_file" "$contract_file" "$output_file"' RETURN

  cat >"$fixture_file" <<'FIXTURE'
Open Notes
Charge Limit 90
배터리 충전 한도
Focus Timer
FIXTURE

  cat >"$contract_file" <<'CONTRACT'
{
  "actionName": "Charge Limit 90",
  "confirmedBy": "fixture",
  "confirmedAt": "2026-06-02T00:00:00Z",
  "input": {
    "type": "integer",
    "transport": "shortcuts run --input-path",
    "allowedValues": [80, 85, 90, 95, 100]
  }
}
CONTRACT

  "$0" --list-file "$fixture_file" --contract-file "$contract_file" >"$output_file"
  /usr/bin/grep -Fq 'shortcuts:available count=4' "$output_file" || die "self-test shortcut count mismatch"
  /usr/bin/grep -Fq 'charge-limit-shortcuts:candidates count=2' "$output_file" || die "self-test candidate count mismatch"
  /usr/bin/grep -Fq 'charge-limit-shortcuts:candidate Charge Limit 90' "$output_file" || die "self-test English candidate missing"
  /usr/bin/grep -Fq 'charge-limit-shortcuts:candidate 배터리 충전 한도' "$output_file" || die "self-test Korean candidate missing"
  /usr/bin/grep -Fq 'charge-limit-shortcuts:input-contract verified action="Charge Limit 90" type=integer allowedValues=80,85,90,95,100' "$output_file" || die "self-test input contract missing"
  /usr/bin/grep -Fq 'charge-limit-shortcuts:read-only-probe-ok no shortcuts were created, run, or modified' "$output_file" || die "self-test read-only guarantee missing"

  echo "Shortcuts Charge Limit parser and contract self-test ok"
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

if [[ "$SELF_TEST" == "1" ]]; then
  run_self_test
  exit 0
fi

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
if [[ -n "$CONTRACT_FILE" ]]; then
  validate_contract_file "$CONTRACT_FILE"
else
  echo "charge-limit-shortcuts:input-contract unverified; capture actionName and integer allowedValues 80,85,90,95,100 on a helper-working Shortcuts environment"
fi
echo "charge-limit-shortcuts:contract-boundary shortcut actions were not run or modified"
echo "charge-limit-shortcuts:read-only-probe-ok no shortcuts were created, run, or modified"
