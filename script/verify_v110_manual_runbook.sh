#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNBOOK="$ROOT_DIR/Docs/V110ManualRunbook.md"
EVIDENCE_JSON="$ROOT_DIR/Docs/V110ManualEvidence.json"
SELF_TEST=0

usage() {
  cat <<USAGE
usage: $0 [--self-test]

Validate the v1.1.0 manual/external verification runbook. This script is
read-only and does not open GUI apps, install or uninstall helpers, run GitHub
Actions, or push. Apple Developer dependent verification is excluded from
v1.1.0.

Options:
  --self-test  Validate required runbook coverage and evidence ids.
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

  die "missing runbook text in $file: $description"
}

verify_evidence_ids() {
  require_file "$RUNBOOK"
  require_file "$EVIDENCE_JSON"

  /usr/bin/ruby -rjson - "$EVIDENCE_JSON" "$RUNBOOK" <<'RUBY'
json_path = ARGV.fetch(0)
runbook_path = ARGV.fetch(1)
data = JSON.parse(File.read(json_path))
runbook = File.read(runbook_path)

expected = [
  ["weekly_usage_graph", "요일별 주간 잔여량 그래프 마무리와 실제 UI 검수"],
  ["clean_drag_and_drop_dmg", "깨끗한 drag-and-drop DMG 설치 검수"],
  ["helper_button_click", "앱 내부 helper 버튼 실제 클릭 검수"],
  ["floating_pet_manual_ui", "플로팅 펫 실제 동작 검수"],
  ["runtime_resource_review", "런타임 리소스 최적화 검토"],
  ["unsigned_release_workflow_run", "unsigned GitHub Actions release workflow 실제 실행 검증"]
]

items = data.fetch("items").map { |item| [item.fetch("id"), item.fetch("title")] }
abort("evidence id/title order mismatch") unless items == expected

expected.each do |id, title|
  abort("runbook missing evidence id #{id}") unless runbook.include?("Evidence id: `#{id}`")
  abort("runbook missing title #{title}") unless runbook.include?(title)
  abort("runbook missing record command for #{id}") unless runbook.include?("--item #{id}")
end
RUBY
}

verify_runbook_text() {
  require_text '상태: Apple Developer 의존 항목 제외 / 절차 고정 / 실제 수동 검수 미완료' "$RUNBOOK" "status boundary"
  require_text '자동 검증, dry-run, self-test.*대체하지 않습니다' "$RUNBOOK" "automation does not replace manual evidence"
  require_text 'script/record_v110_manual_evidence\.sh --item <id>' "$RUNBOOK" "record command"
  require_text './script/check\.sh --no-run' "$RUNBOOK" "common no-run preflight"
  require_text './script/verify_v110_manual_execution_readiness\.sh --allow-incomplete' "$RUNBOOK" "manual execution readiness preflight"
  require_text 'ready-for-manual-ui.*blocked.*external-required.*ready-for-additional-runtime-sampling' "$RUNBOOK" "manual readiness states"
  require_text 'app-freshness:differs-from-dist' "$RUNBOOK" "installed freshness warning"
  require_text 'Apple Developer Program.*v1\.1\.0.*제외|v1\.1\.0.*Apple Developer Program.*제외' "$RUNBOOK" "Apple Developer exclusion boundary"
  require_text 'WidgetKit.*v1\.1\.0.*제외|v1\.1\.0.*WidgetKit.*제외' "$RUNBOOK" "WidgetKit v1.1.0 exclusion boundary"
  require_text '그 이후 단계.*실제 위젯 UI.*확인하지 못했습니다' "$RUNBOOK" "WidgetKit unverified-after boundary"
  require_text './script/verify_cache_contract\.sh' "$RUNBOOK" "weekly graph cache preflight"
  require_text '요일별 주간 잔여량 그래프' "$RUNBOOK" "weekly graph item"
  require_text 'hover tooltip' "$RUNBOOK" "weekly graph hover tooltip"
  require_text './script/verify_release_packaging\.sh' "$RUNBOOK" "release packaging preflight"
  require_text '최종 DMG.*Finder.*실제 drag-and-drop' "$RUNBOOK" "real Finder drag-and-drop install requirement"
  require_text 'script/install\.sh.*대체 검수.*사용할 수 없습니다' "$RUNBOOK" "install script cannot replace user install verification"
  require_text '실제 drag-and-drop 제스처.*수행하거나 관찰할 수 없으면.*미수행' "$RUNBOOK" "drag gesture unavailable means unverified"
  require_text './script/verify_privileged_helper_preflight\.sh' "$RUNBOOK" "helper preflight"
  require_text 'helper 설치 버튼' "$RUNBOOK" "helper install button"
  require_text 'helper 제거 버튼' "$RUNBOOK" "helper remove button"
  require_text './script/sample_existing_runtime_resources\.sh --samples 5 --interval 1' "$RUNBOOK" "runtime sampler"
  require_text 'energy impact' "$RUNBOOK" "energy impact evidence"
  require_text './script/verify_release_workflow\.sh' "$RUNBOOK" "release workflow preflight"
  require_text 'release candidate workflow run URL' "$RUNBOOK" "release candidate run URL"
  require_text 'unsigned draft release workflow run URL' "$RUNBOOK" "unsigned draft run URL"
  require_text 'signed stable workflow.*v1\.1\.0.*완료 조건.*아니' "$RUNBOOK" "signed stable excluded"
  require_text '이 runbook 자체는 수동/외부 검수를 완료하지 않습니다' "$RUNBOOK" "runbook not completion boundary"
  require_text '자동 검증만으로 .*overallStatus.*complete.*바꾸지 않습니다' "$RUNBOOK" "overall status completion boundary"
}

run_self_test() {
  verify_evidence_ids
  verify_runbook_text
  echo "v1.1.0 manual runbook self-test ok"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
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

verify_evidence_ids
verify_runbook_text
echo "v1.1.0 manual runbook ok"
