#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
JSON_REPORT="$ROOT_DIR/Docs/V110ManualEvidence.json"
MARKDOWN_REPORT="$ROOT_DIR/Docs/V110ManualEvidence.md"
ITEM_ID=""
STATUS=""
DRY_RUN=0
SELF_TEST=0
LIST_ITEMS=0
EVIDENCE_ARGS=()
REMAINING_ARGS=()
RECORD_LOCK_DIR=""

usage() {
  cat <<USAGE
usage: $0 --item ID --status STATUS --evidence TEXT [--evidence TEXT ...] [--remaining TEXT ...]
       $0 --list
       $0 --self-test

Record v1.1.0 manual/external verification evidence in the structured JSON
ledger, then render the Markdown ledger from that JSON. This script only edits
the ledger files. It does not open GUI apps, install or uninstall helpers, run
GitHub Actions, or push. Apple Developer dependent verification is excluded
from v1.1.0.

Status values:
  unverified
  partiallyVerified
  verified

Options:
  --item ID          Evidence item id from Docs/V110ManualEvidence.json.
  --status STATUS   New status.
  --evidence TEXT   Append one current evidence entry. Repeatable.
  --remaining TEXT  Replace remaining verification entries. Repeatable.
                    When STATUS is verified and no --remaining is provided,
                    remainingVerification becomes ["없음"].
  --dry-run         Validate the update and print the updated JSON without writing files.
  --json PATH       Structured evidence JSON path.
  --markdown PATH   Markdown evidence output path.
  --list            Print available item ids.
  --self-test       Validate record/update behavior with temporary files.
USAGE
}

die() {
  echo "error: $*" >&2
  exit 1
}

require_file() {
  [[ -f "$1" ]] || die "missing file: $1"
}

release_record_lock() {
  if [[ -n "$RECORD_LOCK_DIR" ]]; then
    /bin/rmdir "$RECORD_LOCK_DIR" >/dev/null 2>&1 || true
    RECORD_LOCK_DIR=""
  fi
}

acquire_record_lock() {
  local lock_dir="$JSON_REPORT.lock"
  local attempt
  for attempt in $(/usr/bin/seq 1 50); do
    if /bin/mkdir "$lock_dir" >/dev/null 2>&1; then
      RECORD_LOCK_DIR="$lock_dir"
      trap release_record_lock EXIT
      return 0
    fi
    /bin/sleep 0.1
  done

  die "could not acquire evidence ledger lock: $lock_dir"
}

run_ruby_update() {
  local json_path="$1"
  local item_id="$2"
  local status="$3"
  local dry_run="$4"
  shift 4

  /usr/bin/ruby -rjson - "$json_path" "$item_id" "$status" "$dry_run" "$@" <<'RUBY'
json_path = ARGV.shift
item_id = ARGV.shift
status = ARGV.shift
dry_run = ARGV.shift == "1"

evidence = []
remaining = []
mode = nil
ARGV.each do |arg|
  case arg
  when "--evidence"
    mode = :evidence
  when "--remaining"
    mode = :remaining
  else
    abort("unexpected value without mode: #{arg}") if mode.nil?
    (mode == :evidence ? evidence : remaining) << arg
  end
end

allowed_statuses = %w[unverified partiallyVerified verified]
abort("invalid status: #{status}") unless allowed_statuses.include?(status)
abort("--evidence is required when marking an item verified") if status == "verified" && evidence.empty?

label_by_status = {
  "unverified" => "미확인",
  "partiallyVerified" => "부분 확인",
  "verified" => "확인됨"
}

data = JSON.parse(File.read(json_path))
items = data.fetch("items")
item = items.find { |candidate| candidate.fetch("id") == item_id }
abort("unknown item id: #{item_id}") unless item

item["status"] = status
item["statusLabel"] = label_by_status.fetch(status)
item["currentEvidence"] = (item.fetch("currentEvidence") + evidence).uniq

unless remaining.empty?
  item["remainingVerification"] = remaining.uniq
end

if status == "verified" && remaining.empty?
  item["remainingVerification"] = ["없음"]
end

if items.all? { |candidate| candidate.fetch("status") == "verified" }
  data["overallStatus"] = "complete"
else
  data["overallStatus"] = "incomplete"
end

json = JSON.pretty_generate(data) + "\n"
if dry_run
  print json
else
  File.write(json_path, json)
end
RUBY
}

list_items() {
  require_file "$JSON_REPORT"
  /usr/bin/ruby -rjson - "$JSON_REPORT" <<'RUBY'
json_path = ARGV.fetch(0)
JSON.parse(File.read(json_path)).fetch("items").each do |item|
  puts "#{item.fetch("id")}\t#{item.fetch("status")}\t#{item.fetch("title")}"
end
RUBY
}

record_evidence() {
  require_file "$JSON_REPORT"
  [[ -n "$ITEM_ID" ]] || die "--item is required"
  [[ -n "$STATUS" ]] || die "--status is required"

  local args=()
  local entry
  if [[ "${#EVIDENCE_ARGS[@]}" -gt 0 ]]; then
    for entry in "${EVIDENCE_ARGS[@]}"; do
      args+=(--evidence "$entry")
    done
  fi
  if [[ "${#REMAINING_ARGS[@]}" -gt 0 ]]; then
    for entry in "${REMAINING_ARGS[@]}"; do
      args+=(--remaining "$entry")
    done
  fi

  local temp_dir
  local temp_json
  local temp_markdown
  local status

  if [[ "$DRY_RUN" != "1" ]]; then
    acquire_record_lock
  fi

  temp_dir="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/macdog-v110-record-candidate.XXXXXX")"
  temp_json="$temp_dir/evidence.json"
  temp_markdown="$temp_dir/evidence.md"
  /bin/cp "$JSON_REPORT" "$temp_json"

  set +e
  run_ruby_update "$temp_json" "$ITEM_ID" "$STATUS" "0" "${args[@]}" &&
    "$ROOT_DIR/script/render_v110_manual_evidence.sh" --write --json "$temp_json" --output "$temp_markdown" >/dev/null &&
    "$ROOT_DIR/script/verify_v110_manual_evidence.sh" --allow-incomplete --json-report "$temp_json" --report "$temp_markdown" >/dev/null
  status=$?
  set -e

  if [[ "$status" -ne 0 ]]; then
    /bin/rm -rf "$temp_dir"
    return "$status"
  fi

  if [[ "$DRY_RUN" == "1" ]]; then
    /bin/cat "$temp_json"
    /bin/rm -rf "$temp_dir"
    return 0
  fi

  /bin/mv "$temp_json" "$JSON_REPORT"
  /bin/mv "$temp_markdown" "$MARKDOWN_REPORT"
  /bin/rm -rf "$temp_dir"
  echo "recorded v1.1.0 evidence for $ITEM_ID"
}

run_self_test() {
  local temp_dir
  temp_dir="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/macdog-v110-record.XXXXXX")"
  trap 'rm -rf "$temp_dir"' RETURN

  local json_path="$temp_dir/evidence.json"
  local markdown_path="$temp_dir/evidence.md"
  /bin/cp "$JSON_REPORT" "$json_path"

  "$ROOT_DIR/script/render_v110_manual_evidence.sh" --write --json "$json_path" --output "$markdown_path" >/dev/null

  "$ROOT_DIR/script/record_v110_manual_evidence.sh" \
    --json "$json_path" \
    --markdown "$markdown_path" \
    --item helper_button_click \
    --status partiallyVerified \
    --evidence "self-test helper install button recorded" \
    --remaining "self-test helper remove UI still pending" >/dev/null

  /usr/bin/ruby -rjson - "$json_path" <<'RUBY'
json_path = ARGV.fetch(0)
item = JSON.parse(File.read(json_path)).fetch("items").find { |candidate| candidate.fetch("id") == "helper_button_click" }
abort("self-test status not recorded") unless item.fetch("status") == "partiallyVerified"
abort("self-test evidence missing") unless item.fetch("currentEvidence").include?("self-test helper install button recorded")
abort("self-test remaining missing") unless item.fetch("remainingVerification") == ["self-test helper remove UI still pending"]
RUBY

  "$ROOT_DIR/script/render_v110_manual_evidence.sh" --check --json "$json_path" --output "$markdown_path"
  "$ROOT_DIR/script/verify_v110_manual_evidence.sh" --allow-incomplete --json-report "$json_path" --report "$markdown_path" >/dev/null

  "$ROOT_DIR/script/record_v110_manual_evidence.sh" \
    --json "$json_path" \
    --markdown "$markdown_path" \
    --item unsigned_release_workflow_run \
    --status unverified \
    --evidence "self-test evidence-only blocker recorded" >/dev/null

  /usr/bin/ruby -rjson - "$json_path" <<'RUBY'
json_path = ARGV.fetch(0)
item = JSON.parse(File.read(json_path)).fetch("items").find { |candidate| candidate.fetch("id") == "unsigned_release_workflow_run" }
abort("self-test evidence-only status changed") unless item.fetch("status") == "unverified"
abort("self-test evidence-only entry missing") unless item.fetch("currentEvidence").include?("self-test evidence-only blocker recorded")
abort("self-test evidence-only remaining changed") unless item.fetch("remainingVerification").include?("release candidate workflow 실제 dispatch")
RUBY

  "$ROOT_DIR/script/render_v110_manual_evidence.sh" --check --json "$json_path" --output "$markdown_path"
  "$ROOT_DIR/script/verify_v110_manual_evidence.sh" --allow-incomplete --json-report "$json_path" --report "$markdown_path" >/dev/null

  /bin/cp "$JSON_REPORT" "$json_path"
  "$ROOT_DIR/script/render_v110_manual_evidence.sh" --write --json "$json_path" --output "$markdown_path" >/dev/null
  "$ROOT_DIR/script/record_v110_manual_evidence.sh" \
    --json "$json_path" \
    --markdown "$markdown_path" \
    --item floating_pet_manual_ui \
    --status unverified \
    --evidence "self-test concurrent floating evidence" >/dev/null &
  local first_pid="$!"
  "$ROOT_DIR/script/record_v110_manual_evidence.sh" \
    --json "$json_path" \
    --markdown "$markdown_path" \
    --item helper_button_click \
    --status unverified \
    --evidence "self-test concurrent helper evidence" >/dev/null &
  local second_pid="$!"
  wait "$first_pid"
  wait "$second_pid"

  /usr/bin/ruby -rjson - "$json_path" <<'RUBY'
json_path = ARGV.fetch(0)
items = JSON.parse(File.read(json_path)).fetch("items")
floating = items.find { |candidate| candidate.fetch("id") == "floating_pet_manual_ui" }
helper = items.find { |candidate| candidate.fetch("id") == "helper_button_click" }
abort("self-test concurrent floating evidence missing") unless floating.fetch("currentEvidence").include?("self-test concurrent floating evidence")
abort("self-test concurrent helper evidence missing") unless helper.fetch("currentEvidence").include?("self-test concurrent helper evidence")
RUBY

  "$ROOT_DIR/script/render_v110_manual_evidence.sh" --check --json "$json_path" --output "$markdown_path"
  "$ROOT_DIR/script/verify_v110_manual_evidence.sh" --allow-incomplete --json-report "$json_path" --report "$markdown_path" >/dev/null

  if "$ROOT_DIR/script/record_v110_manual_evidence.sh" \
    --json "$json_path" \
    --markdown "$markdown_path" \
    --item helper_button_click \
    --status verified >/dev/null 2>&1; then
    die "self-test verified update unexpectedly passed without evidence"
  fi

  /bin/cp "$JSON_REPORT" "$json_path"
  /usr/bin/ruby -rjson - "$json_path" <<'RUBY'
json_path = ARGV.fetch(0)
data = JSON.parse(File.read(json_path))
item = data.fetch("items").find { |candidate| candidate.fetch("id") == "helper_button_click" }
item["status"] = "unverified"
item["statusLabel"] = "미확인"
item["currentEvidence"] = ["self-test helper weak baseline"]
item["remainingVerification"] = ["self-test helper verification pending"]
data["overallStatus"] = "incomplete"
File.write(json_path, JSON.pretty_generate(data) + "\n")
RUBY
  "$ROOT_DIR/script/render_v110_manual_evidence.sh" --write --json "$json_path" --output "$markdown_path" >/dev/null
  if "$ROOT_DIR/script/record_v110_manual_evidence.sh" \
    --json "$json_path" \
    --markdown "$markdown_path" \
    --item helper_button_click \
    --status verified \
    --evidence "self-test generic checked" >/dev/null 2>&1; then
    die "self-test verified update unexpectedly passed with weak evidence"
  fi

  /usr/bin/ruby -rjson - "$json_path" <<'RUBY'
json_path = ARGV.fetch(0)
item = JSON.parse(File.read(json_path)).fetch("items").find { |candidate| candidate.fetch("id") == "helper_button_click" }
abort("weak verified failure changed status") unless item.fetch("status") == "unverified"
abort("weak verified failure left evidence behind") if item.fetch("currentEvidence").include?("self-test generic checked")
RUBY
  "$ROOT_DIR/script/render_v110_manual_evidence.sh" --check --json "$json_path" --output "$markdown_path"

  echo "v1.1.0 manual evidence recorder self-test ok"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --item)
      [[ $# -ge 2 ]] || die "--item requires a value"
      ITEM_ID="$2"
      shift
      ;;
    --status)
      [[ $# -ge 2 ]] || die "--status requires a value"
      STATUS="$2"
      shift
      ;;
    --evidence)
      [[ $# -ge 2 ]] || die "--evidence requires a value"
      EVIDENCE_ARGS+=("$2")
      shift
      ;;
    --remaining)
      [[ $# -ge 2 ]] || die "--remaining requires a value"
      REMAINING_ARGS+=("$2")
      shift
      ;;
    --dry-run) DRY_RUN=1 ;;
    --json)
      [[ $# -ge 2 ]] || die "--json requires a path"
      JSON_REPORT="$2"
      shift
      ;;
    --markdown)
      [[ $# -ge 2 ]] || die "--markdown requires a path"
      MARKDOWN_REPORT="$2"
      shift
      ;;
    --list) LIST_ITEMS=1 ;;
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

if [[ "$LIST_ITEMS" == "1" ]]; then
  list_items
  exit 0
fi

record_evidence
