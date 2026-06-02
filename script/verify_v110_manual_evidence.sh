#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPORT="$ROOT_DIR/Docs/V110ManualEvidence.md"
JSON_REPORT="$ROOT_DIR/Docs/V110ManualEvidence.json"
ALLOW_INCOMPLETE=0
SELF_TEST=0

priority_items=(
  "요일별 주간 잔여량 그래프 마무리와 실제 UI 검수"
  "깨끗한 drag-and-drop DMG 설치 검수"
  "앱 내부 helper 버튼 실제 클릭 검수"
  "플로팅 펫 실제 동작 검수"
  "런타임 리소스 최적화 검토"
  "unsigned GitHub Actions release workflow 실제 실행 검증"
)

usage() {
  cat <<USAGE
usage: $0 [--allow-incomplete] [--self-test] [--report PATH] [--json-report PATH]

Validate the v1.1.0 manual/external evidence ledger. Without
--allow-incomplete, this command fails until every priority item is recorded as
confirmed. It does not open GUI apps, install or uninstall helpers, run GitHub
Actions, or push. Apple Developer dependent verification is excluded from
v1.1.0.

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
  "weekly_usage_graph" => [
    [/요일별.*그래프|weekday.*graph/i, "weekday graph"],
    [/reset.*요일|시작 요일|reset weekday/i, "reset weekday"],
    [/100%.*50%.*0%|0%.*50%.*100%/, "axis labels"],
    [/현재.*퍼센트|current percent/i, "current percent"],
    [/hover|tooltip|툴팁/i, "hover tooltip"]
  ],
  "clean_drag_and_drop_dmg" => [
    [/clean|깨끗/i, "clean environment"],
    [/MacDog\.app/, "MacDog.app in DMG"],
    [/Applications/, "Applications symlink"],
    [/Finder.*drag-and-drop|drag-and-drop.*Finder|실제.*드래그|실제.*drag/i, "actual Finder drag-and-drop"],
    [/첫 실행|first[- ]?run/i, "first-run user component finish"]
  ],
  "helper_button_click" => [
    [/helper.*설치.*(클릭|확인)|helper install/i, "helper install button click"],
    [/helper.*제거.*(클릭|확인)|helper remove/i, "helper remove button click"],
    [/상태.*(전환|확인)|state/i, "helper state transition"],
    [/승인창|approval|관리자/i, "administrator approval identity"]
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
  ],
  "unsigned_release_workflow_run" => [
    [%r{release candidate.*https://github\.com/[^[:space:]]+/actions/runs/[0-9]+}i, "release candidate workflow run URL"],
    [%r{unsigned draft.*https://github\.com/[^[:space:]]+/actions/runs/[0-9]+|draft.*https://github\.com/[^[:space:]]+/actions/runs/[0-9]+}i, "unsigned draft workflow run URL"],
    [/artifact.*MacDog.*\.dmg/i, "workflow DMG artifact"],
    [/checksum.*\.sha256/i, "workflow checksum artifact"],
    [%r{GitHub.*draft.*https://github\.com/[^[:space:]]+/releases/|GitHub Release.*https://github\.com/[^[:space:]]+/releases/}i, "GitHub draft release result"]
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
  require_text 'Apple Developer Program.*제외' "$report" "Apple Developer exclusion boundary"
}

require_supporting_evidence_terms() {
  local report="$1"
  require_text '요일별 주간 잔여량 그래프' "$report" "weekly graph evidence"
  require_text 'hover tooltip' "$report" "weekly graph hover evidence"
  require_text 'Applications.*symlink|Applications.*심볼릭|Applications.*링크' "$report" "drag-and-drop Applications symlink evidence"
  require_text '실제 drag-and-drop|실제 드래그|Finder.*drag' "$report" "actual Finder drag evidence"
  require_text 'helper 설치 버튼' "$report" "helper install button evidence"
  require_text 'helper 제거 버튼' "$report" "helper remove button evidence"
  require_text '드래그.*위치 저장' "$report" "floating pet drag evidence"
  require_text '우클릭 메뉴' "$report" "floating pet context menu evidence"
  require_text 'CPU.*RSS.*energy impact|CPU, RSS, energy impact|CPU.*RSS.*에너지' "$report" "runtime resource evidence"
  require_text 'system metrics sampling' "$report" "system metrics review evidence"
  require_text 'release candidate workflow run URL' "$report" "release candidate run URL evidence"
  require_text 'unsigned draft release workflow run URL' "$report" "unsigned draft run URL evidence"
  require_text 'signed stable.*제외|signed stable.*완료 조건.*아니' "$report" "signed stable exclusion evidence"
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

  require_text '요일별.*그래프.*확인' "$report" "confirmed weekly graph evidence"
  require_text 'drag-and-drop.*확인|드래그.*설치.*확인' "$report" "confirmed clean DMG install evidence"
  require_text 'helper.*설치.*확인' "$report" "confirmed helper install click evidence"
  require_text 'helper.*제거.*확인' "$report" "confirmed helper remove click evidence"
  require_text '플로팅 펫.*드래그.*확인' "$report" "confirmed floating pet drag evidence"
  require_text 'runtime.*CPU.*RSS.*확인|런타임.*CPU.*RSS.*확인' "$report" "confirmed runtime resource evidence"
  require_text 'release candidate.*run URL.*(확인|success|Accepted)' "$report" "confirmed release candidate workflow evidence"
  require_text 'unsigned draft.*run URL.*(확인|success|Accepted)|draft.*run URL.*(확인|success|Accepted)' "$report" "confirmed unsigned draft workflow evidence"
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
  /bin/cp "$JSON_REPORT" "$json_path"
  /usr/bin/ruby -rjson - "$json_path" <<'RUBY'
json_path = ARGV.fetch(0)
data = JSON.parse(File.read(json_path))
item = data.fetch("items").find { |candidate| candidate.fetch("id") == "unsigned_release_workflow_run" }
item["status"] = "unverified"
item["statusLabel"] = "미확인"
item["currentEvidence"] = [
  "self-test release workflow weak baseline",
  "signed stable workflow는 Apple Developer 의존 항목이라 v1.1.0 완료 조건에서 제외"
]
item["remainingVerification"] = [
  "release candidate workflow 실제 dispatch",
  "unsigned draft release workflow 실제 dispatch",
  "artifact, checksum, draft release 결과 확인"
]
data["overallStatus"] = "incomplete"
File.write(json_path, JSON.pretty_generate(data) + "\n")
RUBY
  "$ROOT_DIR/script/render_v110_manual_evidence.sh" --write --json "$json_path" --output "$markdown_path" >/dev/null
}

write_complete_fixture() {
  local markdown_path="$1"
  local json_path="$2"
  /usr/bin/ruby -rjson - "$JSON_REPORT" "$json_path" <<'RUBY'
source_path, output_path = ARGV
data = JSON.parse(File.read(source_path))
data["overallStatus"] = "complete"
extra_evidence = {
  "weekly_usage_graph" => ["요일별 주간 잔여량 그래프 확인", "reset 시작 요일 확인", "100% 50% 0% 라벨 확인", "현재 퍼센트 확인", "hover tooltip 확인"],
  "clean_drag_and_drop_dmg" => ["clean 환경 MacDog.app Applications symlink Finder 실제 drag-and-drop 첫 실행 user component finish 확인", "Finder drag-and-drop 확인", "실제 드래그 설치 확인"],
  "helper_button_click" => ["helper 설치 버튼 클릭 확인", "helper 제거 버튼 클릭 확인", "helper 상태 전환 확인", "관리자 승인창 MacDog 주체 확인"],
  "floating_pet_manual_ui" => ["플로팅 펫 드래그 위치 저장 확인", "우클릭 메뉴 확인", "화면 밖 보정 확인", "메뉴바 action 차이 확인"],
  "runtime_resource_review" => ["runtime CPU RSS 확인", "런타임 CPU RSS 확인", "energy impact 확인", "Popover refresh review 확인", "system metrics sampling 확인", "optimization 최적화 결정 확인"],
  "unsigned_release_workflow_run" => [
    "release candidate workflow run URL https://github.com/dhseo90/MacDog/actions/runs/1001 success",
    "unsigned draft release workflow run URL https://github.com/dhseo90/MacDog/actions/runs/1002 success",
    "artifact MacDog-1.1.0.dmg uploaded",
    "checksum MacDog-1.1.0.dmg.sha256 verified",
    "GitHub draft release https://github.com/dhseo90/MacDog/releases/tag/v1.1.0 created"
  ]
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

  local weak_unsigned_json="$temp_dir/weak-unsigned.json"
  local weak_unsigned_report="$temp_dir/weak-unsigned.md"
  /bin/cp "$complete_json" "$weak_unsigned_json"
  /usr/bin/ruby -rjson - "$weak_unsigned_json" <<'RUBY'
json_path = ARGV.fetch(0)
data = JSON.parse(File.read(json_path))
item = data.fetch("items").find { |candidate| candidate.fetch("id") == "unsigned_release_workflow_run" }
item["currentEvidence"] = ["release candidate workflow run URL 확인", "unsigned draft release workflow run URL 확인", "artifact checksum GitHub draft release 결과 확인"]
File.write(json_path, JSON.pretty_generate(data) + "\n")
RUBY
  "$ROOT_DIR/script/render_v110_manual_evidence.sh" --write --json "$weak_unsigned_json" --output "$weak_unsigned_report" >/dev/null
  if "$ROOT_DIR/script/verify_v110_manual_evidence.sh" --report "$weak_unsigned_report" --json-report "$weak_unsigned_json" >/dev/null 2>&1; then
    die "weak unsigned GitHub Actions evidence unexpectedly passed complete verification"
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
