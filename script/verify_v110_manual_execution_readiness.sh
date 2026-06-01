#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
JSON_REPORT="$ROOT_DIR/Docs/V110ManualEvidence.json"
INSTALL_REPORT=""
INSTALL_EXPLAIN=""
ALLOW_INCOMPLETE=0
SELF_TEST=0
SKIP_SUPPORT_CHECKS=0

usage() {
  cat <<USAGE
usage: $0 [--allow-incomplete] [--self-test] [--json-report PATH]
          [--install-report PATH] [--install-explain PATH] [--skip-support-checks]

Summarize whether each v1.1.0 priority item is ready for real manual/external
execution. This script is read-only: it does not open GUI apps, install or
uninstall helpers, run GitHub Actions, codesign, notarize, staple, run
Gatekeeper assessment, or push.

Options:
  --allow-incomplete   Return success while reporting incomplete/blocked items.
  --self-test          Validate the readiness reporter with temporary fixtures.
  --json-report PATH   Read a custom structured evidence ledger.
  --install-report PATH
                       Read a captured verify_install_state.sh --report output.
  --install-explain PATH
                       Read a captured verify_install_state.sh --explain-current-dist output.
  --skip-support-checks
                       Skip local support verifier calls; used only by self-test fixtures.
USAGE
}

die() {
  echo "error: $*" >&2
  exit 1
}

require_file() {
  [[ -f "$1" ]] || die "missing required file: $1"
}

require_text() {
  local pattern="$1"
  local file="$2"
  local description="$3"

  if /usr/bin/grep -Eq -- "$pattern" "$file"; then
    return 0
  fi

  die "missing readiness text in $file: $description"
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

status_for() {
  local status_file="$1"
  local item_id="$2"
  /usr/bin/awk -F '\t' -v item_id="$item_id" '$1 == item_id { print $2; exit }' "$status_file"
}

label_for() {
  local status_file="$1"
  local item_id="$2"
  /usr/bin/awk -F '\t' -v item_id="$item_id" '$1 == item_id { print $3; exit }' "$status_file"
}

write_status_file() {
  local output="$1"
  require_file "$JSON_REPORT"
  /usr/bin/ruby -rjson - "$JSON_REPORT" "$output" <<'RUBY'
json_path = ARGV.fetch(0)
output_path = ARGV.fetch(1)
data = JSON.parse(File.read(json_path))
File.open(output_path, "w") do |file|
  file.puts "overall\t#{data.fetch("overallStatus")}\t-"
  data.fetch("items").each do |item|
    file.puts [item.fetch("id"), item.fetch("status"), item.fetch("statusLabel")].join("\t")
  end
end
RUBY
}

run_support_checks() {
  [[ "$SKIP_SUPPORT_CHECKS" == "1" ]] && return 0

  "$ROOT_DIR/script/verify_v110_priority_plan.sh" --self-test >/dev/null
  "$ROOT_DIR/script/verify_v110_manual_runbook.sh" --self-test >/dev/null
  "$ROOT_DIR/script/render_v110_manual_evidence.sh" --check >/dev/null
  "$ROOT_DIR/script/verify_v110_manual_evidence.sh" --allow-incomplete --json-report "$JSON_REPORT" >/dev/null
}

print_item() {
  local index="$1"
  local item_id="$2"
  local title="$3"
  local readiness="$4"
  local status_file="$5"
  local reason="$6"
  local next_step="$7"

  local status_label
  status_label="$(label_for "$status_file" "$item_id")"
  echo "$index. $item_id"
  echo "   title: $title"
  echo "   ledger-status: $status_label"
  echo "   readiness: $readiness"
  echo "   reason: $reason"
  echo "   next: $next_step"
}

verify_readiness() {
  require_file "$JSON_REPORT"
  run_support_checks

  local temp_dir
  temp_dir="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/macdog-v110-readiness.XXXXXX")"
  trap 'rm -rf "$temp_dir"' RETURN

  local status_file="$temp_dir/status.tsv"
  local install_report_file="$temp_dir/install-report.txt"
  local install_explain_file="$temp_dir/install-explain.txt"
  write_status_file "$status_file"
  read_file_or_command "$INSTALL_REPORT" "$ROOT_DIR/script/verify_install_state.sh" --report >"$install_report_file"
  read_file_or_command "$INSTALL_EXPLAIN" "$ROOT_DIR/script/verify_install_state.sh" --explain-current-dist >"$install_explain_file"

  local overall_status
  overall_status="$(status_for "$status_file" overall)"

  local install_freshness="unknown"
  local install_reason="install state did not report app freshness"
  if /usr/bin/grep -q '^app-freshness:matches-dist ' "$install_report_file"; then
    install_freshness="matches-dist"
    install_reason="installed app matches dist/MacDog.app"
  elif /usr/bin/grep -q '^app-freshness:differs-from-dist ' "$install_report_file"; then
    install_freshness="differs-from-dist"
    install_reason="$(/usr/bin/grep -m1 '^app-freshness-detail:changed ' "$install_explain_file" || /usr/bin/grep -m1 '^app-freshness:differs-from-dist ' "$install_report_file")"
  elif /usr/bin/grep -q '^app-freshness:missing-dist ' "$install_report_file"; then
    install_freshness="missing-dist"
    install_reason="dist/MacDog.app is missing"
  fi

  echo "==> v1.1.0 manual/external execution readiness"
  echo "This readiness check is read-only: no GUI launch, install, helper change, GitHub Actions run, signing, notarization, stapling, Gatekeeper assessment, or push."
  echo "ledger-overall-status: $overall_status"
  echo "installed-app-freshness: $install_freshness"
  echo "installed-app-detail: $install_reason"
  echo "widgetkit-default-boundary: omitted-from-v1.1.0-default-install"
  echo

  local incomplete_count=0
  local manual_ui_readiness="ready-for-manual-ui"
  local manual_ui_next="perform the runbook item in the actual macOS UI and record evidence"
  local manual_ui_reason="latest installed app matches dist/MacDog.app"
  if [[ "$install_freshness" != "matches-dist" ]]; then
    manual_ui_readiness="blocked"
    manual_ui_reason="$install_reason"
    manual_ui_next="explicitly approve updating the installed MacDog app from dist/MacDog.app before UI verification"
  fi

  local runtime_readiness="ready-for-additional-runtime-sampling"
  local runtime_reason="local runtime contract and read-only sampler are available"
  local runtime_next="explicitly approve long-running or GUI-specific runtime sampling, or record external energy impact evidence"

  print_item 1 helper_button_click "앱 내부 helper 버튼 실제 클릭 검수" "$manual_ui_readiness" "$status_file" "$manual_ui_reason" "$manual_ui_next"
  [[ "$(status_for "$status_file" helper_button_click)" == "verified" ]] || incomplete_count=$((incomplete_count + 1))
  echo

  print_item 2 signed_stable_helper_ux "signed stable DMG 기준 helper 설치 UX 검수" "external-required" "$status_file" "Developer ID signed stable DMG helper approval UI evidence is not recorded" "run signed stable DMG helper UX flow only after explicit approval and record artifact checksum plus approval identity"
  [[ "$(status_for "$status_file" signed_stable_helper_ux)" == "verified" ]] || incomplete_count=$((incomplete_count + 1))
  echo

  print_item 3 clean_drag_and_drop_dmg "깨끗한 drag-and-drop DMG 설치 검수" "external-required" "$status_file" "clean Finder drag-and-drop install evidence is not recorded" "prepare a clean install environment, perform the Finder install flow after explicit approval, and record first-run evidence"
  [[ "$(status_for "$status_file" clean_drag_and_drop_dmg)" == "verified" ]] || incomplete_count=$((incomplete_count + 1))
  echo

  print_item 4 github_actions_release_run "GitHub Actions release workflow 실제 실행 검증" "external-required" "$status_file" "actual GitHub Actions run URLs are not recorded" "explicitly dispatch release candidate, draft release, and stable release workflows, then record run URLs/artifacts/checksums/release URL"
  [[ "$(status_for "$status_file" github_actions_release_run)" == "verified" ]] || incomplete_count=$((incomplete_count + 1))
  echo

  print_item 5 developer_id_distribution_gate "Developer ID signing, notarization, stapling, Gatekeeper 검증" "external-required" "$status_file" "Developer ID signing/notarization/stapling/Gatekeeper success evidence is not recorded" "run signing/notarization/stapling/spctl only after explicit approval and record SHA-256 plus accepted results"
  [[ "$(status_for "$status_file" developer_id_distribution_gate)" == "verified" ]] || incomplete_count=$((incomplete_count + 1))
  echo

  print_item 6 floating_pet_manual_ui "플로팅 펫 실제 동작 검수" "$manual_ui_readiness" "$status_file" "$manual_ui_reason" "$manual_ui_next"
  [[ "$(status_for "$status_file" floating_pet_manual_ui)" == "verified" ]] || incomplete_count=$((incomplete_count + 1))
  echo

  print_item 7 runtime_resource_review "런타임 리소스 최적화 검토" "$runtime_readiness" "$status_file" "$runtime_reason" "$runtime_next"
  [[ "$(status_for "$status_file" runtime_resource_review)" == "verified" ]] || incomplete_count=$((incomplete_count + 1))
  echo

  if [[ "$overall_status" == "complete" && "$incomplete_count" == "0" ]]; then
    echo "v1.1.0 manual/external execution readiness: complete"
    return 0
  fi

  echo "v1.1.0 manual/external execution readiness: incomplete"
  echo "incomplete-or-unverified-count: $incomplete_count"
  if [[ "$ALLOW_INCOMPLETE" == "1" ]]; then
    return 0
  fi

  return 1
}

run_self_test() {
  local temp_dir
  temp_dir="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/macdog-v110-readiness-self.XXXXXX")"
  trap 'rm -rf "$temp_dir"' RETURN

  local json_path="$temp_dir/evidence.json"
  local install_report_path="$temp_dir/install-report.txt"
  local install_explain_path="$temp_dir/install-explain.txt"
  /bin/cp "$JSON_REPORT" "$json_path"
  cat >"$install_report_path" <<'REPORT'
app-freshness:differs-from-dist expected:/tmp/dist/MacDog.app actual:/Applications/MacDog.app
REPORT
  cat >"$install_explain_path" <<'EXPLAIN'
app-freshness-detail:differs-from-dist expected:/tmp/dist/MacDog.app actual:/Applications/MacDog.app
app-freshness-detail:changed-count:1
app-freshness-detail:changed Contents/MacOS/MacDog
app-freshness-detail:removed-count:0
app-freshness-detail:added-count:0
EXPLAIN

  local output_file="$temp_dir/readiness.txt"
  "$ROOT_DIR/script/verify_v110_manual_execution_readiness.sh" \
    --allow-incomplete \
    --skip-support-checks \
    --json-report "$json_path" \
    --install-report "$install_report_path" \
    --install-explain "$install_explain_path" >"$output_file"

  require_text 'read-only: no GUI launch, install, helper change' "$output_file" "read-only boundary"
  require_text 'installed-app-freshness: differs-from-dist' "$output_file" "stale installed app detail"
  require_text 'widgetkit-default-boundary: omitted-from-v1.1.0-default-install' "$output_file" "WidgetKit default boundary"
  require_text 'helper_button_click' "$output_file" "helper item"
  require_text 'signed_stable_helper_ux' "$output_file" "signed stable helper item"
  require_text 'clean_drag_and_drop_dmg' "$output_file" "clean DMG item"
  require_text 'github_actions_release_run' "$output_file" "GitHub Actions item"
  require_text 'developer_id_distribution_gate' "$output_file" "Developer ID item"
  require_text 'floating_pet_manual_ui' "$output_file" "floating pet item"
  require_text 'runtime_resource_review' "$output_file" "runtime item"
  require_text 'readiness: blocked' "$output_file" "manual UI blocked state"
  require_text 'readiness: external-required' "$output_file" "external required state"
  require_text 'readiness: ready-for-additional-runtime-sampling' "$output_file" "runtime ready state"
  require_text 'v1\.1\.0 manual/external execution readiness: incomplete' "$output_file" "incomplete state"

  if "$ROOT_DIR/script/verify_v110_manual_execution_readiness.sh" \
    --skip-support-checks \
    --json-report "$json_path" \
    --install-report "$install_report_path" \
    --install-explain "$install_explain_path" >/dev/null 2>&1; then
    die "incomplete readiness unexpectedly passed without --allow-incomplete"
  fi

  echo "v1.1.0 manual execution readiness self-test ok"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --allow-incomplete) ALLOW_INCOMPLETE=1 ;;
    --self-test) SELF_TEST=1 ;;
    --json-report)
      [[ $# -ge 2 ]] || die "--json-report requires a path"
      JSON_REPORT="$2"
      shift
      ;;
    --install-report)
      [[ $# -ge 2 ]] || die "--install-report requires a path"
      INSTALL_REPORT="$2"
      shift
      ;;
    --install-explain)
      [[ $# -ge 2 ]] || die "--install-explain requires a path"
      INSTALL_EXPLAIN="$2"
      shift
      ;;
    --skip-support-checks) SKIP_SUPPORT_CHECKS=1 ;;
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

verify_readiness
