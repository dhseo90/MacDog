#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPORT="$ROOT_DIR/Docs/V110ManualEvidence.md"
JSON_REPORT="$ROOT_DIR/Docs/V110ManualEvidence.json"
ALLOW_INCOMPLETE=0
SELF_TEST=0

priority_items=(
  "앱 내부 helper 버튼 실제 클릭 검수"
  "signed stable DMG 기준 helper 설치 UX 검수"
  "깨끗한 drag-and-drop DMG 설치 검수"
  "GitHub Actions release workflow 실제 실행 검증"
  "Developer ID signing, notarization, stapling, Gatekeeper 검증"
  "플로팅 펫 실제 동작 검수"
  "런타임 리소스 최적화 검토"
)

usage() {
  cat <<USAGE
usage: $0 [--allow-incomplete] [--self-test] [--report PATH] [--json-report PATH]

Validate the v1.1.0 manual/external evidence ledger. Without
--allow-incomplete, this command fails until every priority item is recorded as
confirmed. It does not open GUI apps, install or uninstall helpers, run GitHub
Actions, codesign, notarize, staple, run Gatekeeper assessment, or push.

Options:
  --allow-incomplete  Verify the ledger exists, honestly records incomplete items,
                      and does not mark weakly evidenced items as verified.
  --self-test         Validate the verifier with temporary complete/incomplete ledgers.
  --report PATH       Read a custom evidence ledger.
  --json-report PATH  Read a custom structured evidence ledger.
USAGE
}

die() {
  echo "error: $*" >&2
  exit 1
}

require_file() {
  [[ -f "$1" ]] || die "missing evidence ledger: $1"
}

require_text() {
  local pattern="$1"
  local file="$2"
  local description="$3"

  if /usr/bin/grep -Eq -- "$pattern" "$file"; then
    return 0
  fi

  die "missing evidence ledger text in $file: $description"
}

verify_json_report() {
  local json_report="$1"
  local markdown_report="$2"
  require_file "$json_report"

  /usr/bin/ruby -rjson - "$json_report" "$markdown_report" "${priority_items[@]}" <<'RUBY'
json_path = ARGV.shift
markdown_path = ARGV.shift
expected_titles = ARGV

data = JSON.parse(File.read(json_path))
markdown = File.read(markdown_path)

abort("JSON version must be v1.1.0") unless data["version"] == "v1.1.0"
abort("JSON overallStatus must be incomplete or complete") unless %w[incomplete complete].include?(data["overallStatus"])

items = data["items"]
abort("JSON items must be an array") unless items.is_a?(Array)
abort("JSON item count mismatch") unless items.length == expected_titles.length

titles = items.map { |item| item["title"] }
abort("JSON titles mismatch") unless titles == expected_titles

allowed_statuses = %w[unverified partiallyVerified verified]
label_by_status = {
  "unverified" => "미확인",
  "partiallyVerified" => "부분 확인",
  "verified" => "확인됨"
}

verified_requirements = {
  "helper_button_click" => [
    [/helper.*설치.*(클릭|확인)|helper install/i, "helper install button click"],
    [/helper.*제거.*(클릭|확인)|helper remove/i, "helper remove button click"],
    [/상태.*(전환|확인)|state/i, "helper state transition"],
    [/승인창|approval|관리자/i, "administrator approval identity"]
  ],
  "signed_stable_helper_ux" => [
    [/signed stable DMG/i, "signed stable DMG artifact"],
    [/[a-f0-9]{64}.*checksum|checksum.*[a-f0-9]{64}/i, "artifact checksum"],
    [/승인창|approval/i, "helper approval dialog"],
    [/MacDog/, "MacDog approval identity"]
  ],
  "clean_drag_and_drop_dmg" => [
    [/clean|깨끗/i, "clean environment"],
    [/MacDog\.app/, "MacDog.app in DMG"],
    [/Applications/, "Applications symlink"],
    [/Finder.*drag-and-drop|drag-and-drop.*Finder|실제.*드래그|실제.*drag/i, "actual Finder drag-and-drop"],
    [/첫 실행|first[- ]?run/i, "first-run user component finish"]
  ],
  "github_actions_release_run" => [
    [%r{release candidate.*https://github\.com/[^[:space:]]+/actions/runs/[0-9]+}i, "release candidate workflow run URL"],
    [%r{draft.*https://github\.com/[^[:space:]]+/actions/runs/[0-9]+}i, "draft release workflow run URL"],
    [%r{stable.*https://github\.com/[^[:space:]]+/actions/runs/[0-9]+}i, "stable release workflow run URL"],
    [/artifact.*MacDog.*\.dmg/i, "workflow DMG artifact"],
    [/checksum.*\.sha256/i, "workflow checksum artifact"],
    [%r{GitHub Release.*https://github\.com/[^[:space:]]+/releases/}i, "GitHub Release result"]
  ],
  "developer_id_distribution_gate" => [
    [/Developer ID.*MacDog.*\.dmg.*[a-f0-9]{64}/i, "Developer ID signed DMG artifact and checksum"],
    [/notarytool submit.*(Accepted|성공|success)|notarization.*(Accepted|성공|success)/i, "notarization success"],
    [/stapler staple.*(worked|성공|success)|stapling.*(worked|성공|success)/i, "stapling success"],
    [/stapler validate.*(accepted|worked|성공|success)/i, "stapler validation success"],
    [/spctl --assess.*(accepted|성공|success|Notarized Developer ID)|Gatekeeper.*(accepted|성공|success|Notarized Developer ID)/i, "Gatekeeper success"]
  ],
  "floating_pet_manual_ui" => [
    [/드래그.*위치.*(저장|확인)/, "drag position save"],
    [/우클릭 메뉴/, "right-click menu"],
    [/화면 밖.*보정/, "offscreen correction"],
    [/메뉴바.*action|action 차이/i, "menu bar action comparison"]
  ],
  "runtime_resource_review" => [
    [/CPU/, "CPU measurement"],
    [/RSS/, "RSS measurement"],
    [/energy impact|Energy Impact|에너지/i, "energy impact measurement"],
    [/Popover|popover/, "popover refresh review"],
    [/system metrics/i, "system metrics sampling review"],
    [/최적화|optimization/i, "optimization decision"]
  ]
}

items.each do |item|
  id = item["id"].to_s
  abort("JSON item id missing for #{item["title"]}") if id.empty?

  status = item["status"]
  abort("invalid status #{status.inspect} for #{item["title"]}") unless allowed_statuses.include?(status)

  expected_label = label_by_status.fetch(status)
  abort("statusLabel mismatch for #{item["title"]}") unless item["statusLabel"] == expected_label

  %w[requiredEvidence currentEvidence remainingVerification].each do |key|
    value = item[key]
    abort("#{key} must be a non-empty array for #{item["title"]}") unless value.is_a?(Array) && !value.empty?
  end

  abort("Markdown missing title #{item["title"]}") unless markdown.include?(item["title"])
  abort("Markdown missing status #{item["statusLabel"]}") unless markdown.include?("상태: #{item["statusLabel"]}")

  if status == "verified"
    abort("verified item must have remainingVerification [\"없음\"] for #{item["title"]}") unless item["remainingVerification"] == ["없음"]

    evidence_text = item["currentEvidence"].join("\n")
    requirements = verified_requirements.fetch(id) do
      abort("missing verified evidence requirements for #{item["title"]}")
    end
    requirements.each do |pattern, description|
      abort("verified item #{item["title"]} lacks evidence for #{description}") unless evidence_text.match?(pattern)
    end
  end
end

if data["overallStatus"] == "complete"
  incomplete = items.reject { |item| item["status"] == "verified" }
  abort("complete JSON has incomplete items") unless incomplete.empty?
else
  incomplete = items.select { |item| item["status"] != "verified" }
  abort("incomplete JSON must include incomplete items") if incomplete.empty?
end
RUBY
}

require_item_list() {
  local report="$1"
  local item
  for item in "${priority_items[@]}"; do
    require_text "$item" "$report" "$item"
  done
}

require_evidence_boundaries() {
  local report="$1"
  require_text '상태: 미완료|상태: 완료' "$report" "overall status"
  require_text '실제로 보지 않은 화면|실제.*완료로 볼 수 있는 증거' "$report" "no overclaiming boundary"
  require_text '자동 검증.*대체하지 않습니다' "$report" "manual/external evidence boundary"
}

require_supporting_evidence_terms() {
  local report="$1"
  require_text 'helper 설치 버튼' "$report" "helper install button evidence"
  require_text 'helper 제거 버튼' "$report" "helper remove button evidence"
  require_text 'signed stable DMG' "$report" "signed stable DMG evidence"
  require_text 'Applications.*symlink|Applications.*심볼릭|Applications.*링크' "$report" "drag-and-drop Applications symlink evidence"
  require_text 'workflow run URL' "$report" "GitHub Actions run URL evidence"
  require_text 'notarytool submit' "$report" "notarization evidence"
  require_text 'stapler staple' "$report" "stapling evidence"
  require_text 'spctl' "$report" "Gatekeeper evidence"
  require_text '드래그.*위치 저장' "$report" "floating pet drag evidence"
  require_text '우클릭 메뉴' "$report" "floating pet context menu evidence"
  require_text 'CPU.*RSS.*energy impact|CPU, RSS, energy impact' "$report" "runtime resource evidence"
  require_text 'system metrics sampling' "$report" "system metrics review evidence"
}

ledger_has_incomplete_status() {
  local report="$1"
  /usr/bin/grep -Eq '상태: (미완료|미확인|부분 확인|미수행)' "$report"
}

require_all_confirmed() {
  local report="$1"
  if ledger_has_incomplete_status "$report"; then
    die "v1.1.0 evidence is incomplete; rerun with --allow-incomplete for an honesty check"
  fi

  local confirmed_count
  confirmed_count="$(/usr/bin/grep -Ec '^상태: 확인됨$' "$report" || true)"
  [[ "$confirmed_count" -ge "${#priority_items[@]}" ]] || die "expected at least ${#priority_items[@]} confirmed item statuses, found $confirmed_count"

  require_text 'helper.*설치.*확인' "$report" "confirmed helper install click evidence"
  require_text 'helper.*제거.*확인' "$report" "confirmed helper remove click evidence"
  require_text 'signed stable DMG.*확인' "$report" "confirmed signed stable DMG evidence"
  require_text 'drag-and-drop.*확인|드래그.*설치.*확인' "$report" "confirmed clean DMG install evidence"
  require_text 'release candidate.*run URL.*(확인|success|Accepted)' "$report" "confirmed release candidate workflow evidence"
  require_text 'stable release.*run URL.*(확인|success|Accepted)' "$report" "confirmed stable workflow evidence"
  require_text 'notarytool submit.*(성공|success|Accepted)' "$report" "confirmed notarization success"
  require_text 'stapler staple.*(성공|success|worked)' "$report" "confirmed stapling success"
  require_text 'spctl.*(성공|success|accepted|Notarized Developer ID)' "$report" "confirmed Gatekeeper success"
  require_text '플로팅 펫.*드래그.*확인' "$report" "confirmed floating pet drag evidence"
  require_text 'runtime.*CPU.*RSS.*확인|런타임.*CPU.*RSS.*확인' "$report" "confirmed runtime resource evidence"
}

verify_report() {
  local report="$1"
  local json_report="$2"
  require_file "$report"
  "$ROOT_DIR/script/render_v110_manual_evidence.sh" --check --json "$json_report" --output "$report" >/dev/null
  require_item_list "$report"
  require_evidence_boundaries "$report"
  require_supporting_evidence_terms "$report"
  verify_json_report "$json_report" "$report"

  if [[ "$ALLOW_INCOMPLETE" == "1" ]]; then
    if ledger_has_incomplete_status "$report"; then
      echo "v1.1.0 manual evidence ledger ok: incomplete items are explicitly recorded"
    else
      echo "v1.1.0 manual evidence ledger ok: no incomplete status markers found"
    fi
    return 0
  fi

  require_all_confirmed "$report"
  echo "v1.1.0 manual evidence complete"
}

write_incomplete_fixture() {
  local markdown_path="$1"
  local json_path="$2"
  /bin/cp "$REPORT" "$markdown_path"
  /bin/cp "$JSON_REPORT" "$json_path"
}

write_complete_fixture() {
  local markdown_path="$1"
  local json_path="$2"
  /usr/bin/ruby -rjson - "$JSON_REPORT" "$json_path" <<'RUBY'
source_path, output_path = ARGV
data = JSON.parse(File.read(source_path))
data["overallStatus"] = "complete"
extra_evidence = {
  "helper_button_click" => ["helper 설치 버튼 클릭 확인", "helper 제거 버튼 클릭 확인", "helper 상태 전환 확인", "관리자 승인창 MacDog 주체 확인"],
  "signed_stable_helper_ux" => ["signed stable DMG dist/release/MacDog-1.1.0.dmg checksum 0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef MacDog helper 승인창 approval 확인"],
  "clean_drag_and_drop_dmg" => ["clean 환경 MacDog.app Applications symlink Finder 실제 drag-and-drop 첫 실행 user component finish 확인", "Finder drag-and-drop 확인", "실제 드래그 설치 확인"],
  "github_actions_release_run" => [
    "release candidate workflow run URL https://github.com/dhseo90/MacDog/actions/runs/1001 success",
    "draft release workflow run URL https://github.com/dhseo90/MacDog/actions/runs/1002 success",
    "stable release workflow run URL https://github.com/dhseo90/MacDog/actions/runs/1003 success",
    "artifact MacDog-1.1.0.dmg uploaded",
    "checksum MacDog-1.1.0.dmg.sha256 verified",
    "GitHub Release https://github.com/dhseo90/MacDog/releases/tag/v1.1.0 created"
  ],
  "developer_id_distribution_gate" => [
    "Developer ID signed MacDog-1.1.0.dmg checksum 0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
    "notarytool submit Accepted success",
    "stapler staple worked success",
    "stapler validate accepted success",
    "spctl --assess accepted source=Notarized Developer ID success",
    "Gatekeeper accepted"
  ],
  "floating_pet_manual_ui" => ["플로팅 펫 드래그 위치 저장 확인", "우클릭 메뉴 확인", "화면 밖 보정 확인", "메뉴바 action 차이 확인"],
  "runtime_resource_review" => ["runtime CPU RSS 확인", "런타임 CPU RSS 확인", "energy impact 확인", "Popover refresh review 확인", "system metrics sampling 확인", "optimization 최적화 결정 확인"]
}
data["items"].each do |item|
  item["status"] = "verified"
  item["statusLabel"] = "확인됨"
  item["currentEvidence"] = (item["currentEvidence"] + item["requiredEvidence"] + extra_evidence.fetch(item.fetch("id"), [])).uniq
  item["remainingVerification"] = ["없음"]
end
File.write(output_path, JSON.pretty_generate(data) + "\n")
RUBY
  "$ROOT_DIR/script/render_v110_manual_evidence.sh" --write --json "$json_path" --output "$markdown_path" >/dev/null
}

run_self_test() {
  require_file "$REPORT"

  local temp_dir
  temp_dir="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/macdog-v110-evidence.XXXXXX")"
  trap 'rm -rf "$temp_dir"' RETURN

  local incomplete_report="$temp_dir/incomplete.md"
  local incomplete_json="$temp_dir/incomplete.json"
  local complete_report="$temp_dir/complete.md"
  local complete_json="$temp_dir/complete.json"
  write_incomplete_fixture "$incomplete_report" "$incomplete_json"
  write_complete_fixture "$complete_report" "$complete_json"

  ALLOW_INCOMPLETE=1 verify_report "$incomplete_report" "$incomplete_json" >/dev/null

  if "$ROOT_DIR/script/verify_v110_manual_evidence.sh" --report "$incomplete_report" --json-report "$incomplete_json" >/dev/null 2>&1; then
    die "incomplete fixture unexpectedly passed complete verification"
  fi

  "$ROOT_DIR/script/verify_v110_manual_evidence.sh" --report "$complete_report" --json-report "$complete_json" >/dev/null

  local weak_github_json="$temp_dir/weak-github.json"
  local weak_github_report="$temp_dir/weak-github.md"
  /bin/cp "$complete_json" "$weak_github_json"
  /usr/bin/ruby -rjson - "$weak_github_json" <<'RUBY'
json_path = ARGV.fetch(0)
data = JSON.parse(File.read(json_path))
item = data.fetch("items").find { |candidate| candidate.fetch("id") == "github_actions_release_run" }
item["currentEvidence"] = ["release candidate workflow run URL 확인", "draft release workflow run URL 확인", "stable release workflow run URL 확인", "artifact checksum GitHub Release 결과 확인"]
File.write(json_path, JSON.pretty_generate(data) + "\n")
RUBY
  "$ROOT_DIR/script/render_v110_manual_evidence.sh" --write --json "$weak_github_json" --output "$weak_github_report" >/dev/null
  if "$ROOT_DIR/script/verify_v110_manual_evidence.sh" --report "$weak_github_report" --json-report "$weak_github_json" >/dev/null 2>&1; then
    die "weak GitHub Actions evidence unexpectedly passed complete verification"
  fi

  local weak_distribution_json="$temp_dir/weak-distribution.json"
  local weak_distribution_report="$temp_dir/weak-distribution.md"
  /bin/cp "$complete_json" "$weak_distribution_json"
  /usr/bin/ruby -rjson - "$weak_distribution_json" <<'RUBY'
json_path = ARGV.fetch(0)
data = JSON.parse(File.read(json_path))
item = data.fetch("items").find { |candidate| candidate.fetch("id") == "developer_id_distribution_gate" }
item["currentEvidence"] = ["Developer ID signing 확인", "notarytool submit 성공", "stapler staple 성공", "spctl 성공", "Gatekeeper 성공"]
File.write(json_path, JSON.pretty_generate(data) + "\n")
RUBY
  "$ROOT_DIR/script/render_v110_manual_evidence.sh" --write --json "$weak_distribution_json" --output "$weak_distribution_report" >/dev/null
  if "$ROOT_DIR/script/verify_v110_manual_evidence.sh" --report "$weak_distribution_report" --json-report "$weak_distribution_json" >/dev/null 2>&1; then
    die "weak Developer ID distribution evidence unexpectedly passed complete verification"
  fi

  echo "v1.1.0 manual evidence verifier self-test ok"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --allow-incomplete) ALLOW_INCOMPLETE=1 ;;
    --self-test) SELF_TEST=1 ;;
    --report)
      [[ $# -ge 2 ]] || die "--report requires a path"
      REPORT="$2"
      shift
      ;;
    --json-report)
      [[ $# -ge 2 ]] || die "--json-report requires a path"
      JSON_REPORT="$2"
      shift
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

cd "$ROOT_DIR"

if [[ "$SELF_TEST" == "1" ]]; then
  run_self_test
  exit 0
fi

verify_report "$REPORT" "$JSON_REPORT"
