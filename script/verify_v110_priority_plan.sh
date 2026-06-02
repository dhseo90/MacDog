#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROADMAP="$ROOT_DIR/ROADMAP.md"
DOC="$ROOT_DIR/Docs/V110PriorityVerification.md"
SELF_TEST=0

priority_items=(
  "요일별 주간 잔여량 그래프 마무리와 실제 UI 검수"
  "깨끗한 drag-and-drop DMG 설치 검수"
  "앱 내부 helper 버튼 실제 클릭 검수"
  "플로팅 펫 실제 동작 검수"
  "런타임 리소스 최적화 검토"
  "unsigned GitHub Actions release workflow 실제 실행 검증"
)

excluded_terms=(
  "Apple Developer Program"
  "Developer ID"
  "notarization"
  "App Group provisioning"
  "signed stable"
)

usage() {
  cat <<USAGE
usage: $0 [--self-test]

Verify that the v1.1.0 priority item list is present, mapped to local
read-only support checks, and excludes Apple Developer dependent work.
This script does not open GUI apps, install MacDog, register LaunchAgents, run
GitHub workflows, or push.

Options:
  --self-test  Validate the plan output and local support mapping.
USAGE
}

die() {
  echo "error: $*" >&2
  exit 1
}

require_file() {
  [[ -f "$1" ]] || die "missing required file: $1"
}

require_executable() {
  [[ -x "$1" ]] || die "missing required executable: $1"
}

require_text() {
  local pattern="$1"
  local file="$2"
  local description="$3"

  if /usr/bin/grep -Eq -- "$pattern" "$file"; then
    return 0
  fi

  die "missing v1.1.0 priority evidence in $file: $description"
}

verify_roadmap_list() {
  require_file "$ROADMAP"
  require_text 'v1\.1\.0.*우선 항목' "$ROADMAP" "v1.1.0 priority section"
  require_text 'Apple Developer Program.*v1\.1\.0.*제외|v1\.1\.0.*Apple Developer Program.*제외' "$ROADMAP" "Apple Developer exclusion"

  local item
  for item in "${priority_items[@]}"; do
    require_text "$item" "$ROADMAP" "$item"
  done

  require_text 'WidgetKit.*보존.*확인.*source|WidgetKit.*source.*확인.*미확인' "$ROADMAP" "WidgetKit retained-but-unverified boundary"
}

verify_supporting_files() {
  require_file "$DOC"
  require_executable "$ROOT_DIR/script/render_v110_manual_evidence.sh"
  require_executable "$ROOT_DIR/script/record_v110_manual_evidence.sh"
  require_executable "$ROOT_DIR/script/verify_v110_manual_evidence.sh"
  require_executable "$ROOT_DIR/script/verify_v110_manual_execution_readiness.sh"
  require_executable "$ROOT_DIR/script/verify_v110_manual_runbook.sh"
  require_executable "$ROOT_DIR/script/verify_manual_ui_prerequisites.sh"
  require_executable "$ROOT_DIR/script/verify_privileged_helper_preflight.sh"
  require_executable "$ROOT_DIR/script/verify_privileged_helper_reinstall_plan.sh"
  require_executable "$ROOT_DIR/script/verify_release_packaging.sh"
  require_executable "$ROOT_DIR/script/verify_release_workflow.sh"
  require_executable "$ROOT_DIR/script/verify_runtime_contract.sh"
  require_executable "$ROOT_DIR/script/sample_existing_runtime_resources.sh"
  require_file "$ROOT_DIR/.github/workflows/release-candidate.yml"
  require_file "$ROOT_DIR/.github/workflows/release-draft.yml"
  require_file "$ROOT_DIR/Docs/WidgetPackaging.md"
  require_file "$ROOT_DIR/Docs/PrivilegedHelperPlan.md"
  require_file "$ROOT_DIR/Docs/ReleasePackaging.md"
  require_file "$ROOT_DIR/Docs/GitHubReleaseChecklist.md"
  require_file "$ROOT_DIR/Docs/RuntimeVerification.md"
  require_file "$ROOT_DIR/Docs/V110ManualEvidence.md"
  require_file "$ROOT_DIR/Docs/V110ManualEvidence.json"
  require_file "$ROOT_DIR/Docs/V110ManualRunbook.md"
}

print_plan() {
  cat <<'PLAN'
==> v1.1.0 priority development list
Source: ROADMAP.md `v1.1.0` 우선 항목.
Boundary: Apple Developer Program, Developer ID, notarization, App Group provisioning, and signed stable release work are excluded from v1.1.0.

1. 요일별 주간 잔여량 그래프 마무리와 실제 UI 검수
   Completion evidence: latest installed app popover shows weekday weekly remaining graph, reset weekday, current percent, historical day dots, and hover tooltip.
   Local support: cache/history Swift tests and ./script/verify_cache_contract.sh
   Current evidence: verified in Docs/V110ManualEvidence.md when the ledger overallStatus is complete.

2. 깨끗한 drag-and-drop DMG 설치 검수
   Completion evidence: clean environment, DMG contains only MacDog.app and Applications symlink, actual Finder drag-and-drop install, first-run user component finish observed.
   Local support: ./script/verify_release_packaging.sh
   Current evidence: verified in Docs/V110ManualEvidence.md when the ledger overallStatus is complete.

3. 앱 내부 helper 버튼 실제 클릭 검수
   Completion evidence: latest installed app UI click on helper install/remove buttons, state transition copy observed, no unreported password prompt behavior.
   Local support: ./script/verify_manual_ui_prerequisites.sh and helper preflight scripts.
   Current evidence: verified in Docs/V110ManualEvidence.md when the ledger overallStatus is complete.

4. 플로팅 펫 실제 동작 검수
   Completion evidence: drag position save, right-click menu, offscreen correction, and menu bar action differences observed in the desktop UI.
   Local support: FloatingPetMotionBoundsTests, PetMenuModelTests, ./script/verify_runtime_contract.sh
   Current evidence: verified in Docs/V110ManualEvidence.md when the ledger overallStatus is complete.

5. 런타임 리소스 최적화 검토
   Completion evidence: CPU/RSS/energy impact measured while app is running, menu bar runner, floating pet, popover refresh, cache polling, and system metrics sampling reviewed.
   Local support: ./script/verify_runtime_contract.sh and ./script/sample_existing_runtime_resources.sh --self-test
   Current evidence: verified in Docs/V110ManualEvidence.md when the ledger overallStatus is complete.

6. unsigned GitHub Actions release workflow 실제 실행 검증
   Completion evidence: actual GitHub workflow run URLs/results for release candidate and unsigned draft release paths, artifact, checksum, and draft release URL.
   Local support: ./script/verify_release_workflow.sh
   Current evidence: verified in Docs/V110ManualEvidence.md when the ledger overallStatus is complete; signed stable workflow is excluded from v1.1.0.
PLAN
}

run_self_test() {
  verify_roadmap_list
  verify_supporting_files

  local temp_dir
  temp_dir="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/macdog-v110-priority.XXXXXX")"
  trap 'rm -rf "$temp_dir"' RETURN

  local output_file="$temp_dir/v110-priority.txt"
  print_plan >"$output_file"

  local item
  for item in "${priority_items[@]}"; do
    require_text "$item" "$output_file" "$item plan output"
    require_text "$item" "$DOC" "$item documentation"
  done

  local term
  for term in "${excluded_terms[@]}"; do
    require_text "$term.*제외|제외.*$term|excluded.*$term|$term.*excluded" "$DOC" "$term exclusion documentation"
  done

  require_text '자동화 가능한 검증은 수동 검수를 대체하지 않습니다|수동 UI 증거' "$DOC" "manual evidence boundary"
  require_text 'Docs/V110ManualEvidence\.md' "$DOC" "manual evidence ledger documentation"
  require_text 'Docs/V110ManualEvidence\.json' "$DOC" "structured manual evidence ledger documentation"
  require_text 'Docs/V110ManualRunbook\.md' "$DOC" "manual runbook documentation"
  require_text 'verify_v110_manual_evidence\.sh --allow-incomplete' "$DOC" "manual evidence ledger verifier documentation"
  require_text 'verify_v110_manual_execution_readiness\.sh --allow-incomplete' "$DOC" "manual execution readiness documentation"
  require_text 'verify_v110_manual_runbook\.sh --self-test' "$DOC" "manual runbook verifier documentation"
  require_text 'unsigned GitHub Actions.*실제 실행' "$DOC" "unsigned GitHub Actions evidence boundary"
  require_text 'sample_existing_runtime_resources\.sh' "$DOC" "existing runtime sampler documentation"

  echo "v1.1.0 priority plan self-test ok"
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

verify_roadmap_list
verify_supporting_files
print_plan
