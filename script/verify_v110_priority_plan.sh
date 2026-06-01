#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROADMAP="$ROOT_DIR/ROADMAP.md"
DOC="$ROOT_DIR/Docs/V110PriorityVerification.md"
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
usage: $0 [--self-test]

Verify that the v1.1.0 priority item list is present, mapped to local
read-only support checks, and clearly separated from manual/external evidence.
This script does not open GUI apps, install MacDog, register LaunchAgents, run
GitHub workflows, codesign, notarize, staple, run Gatekeeper assessment, or push.

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

  local item
  for item in "${priority_items[@]}"; do
    require_text "$item" "$ROADMAP" "$item"
  done
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
  require_executable "$ROOT_DIR/script/verify_distribution_gate.sh"
  require_executable "$ROOT_DIR/script/verify_runtime_contract.sh"
  require_executable "$ROOT_DIR/script/sample_existing_runtime_resources.sh"
  require_file "$ROOT_DIR/.github/workflows/release-candidate.yml"
  require_file "$ROOT_DIR/.github/workflows/release-draft.yml"
  require_file "$ROOT_DIR/.github/workflows/release-stable.yml"
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

1. 앱 내부 helper 버튼 실제 클릭 검수
   Completion evidence: latest installed app UI click on helper install/remove buttons, state transition copy observed, no unreported password prompt behavior.
   Local support: ./script/verify_manual_ui_prerequisites.sh and helper preflight scripts.
   Status boundary: GUI click and helper install/remove approval are still required.

2. signed stable DMG 기준 helper 설치 UX 검수
   Completion evidence: signed stable DMG build, helper approval dialog identity shown as MacDog, install/remove path observed.
   Local support: ./script/verify_distribution_gate.sh and ./script/verify_release_workflow.sh
   Status boundary: Developer ID signed stable artifact and UI evidence are still required.

3. 깨끗한 drag-and-drop DMG 설치 검수
   Completion evidence: clean environment, DMG contains only MacDog.app and Applications symlink, first-run user component finish observed.
   Local support: ./script/verify_release_packaging.sh
   Status boundary: clean install environment and Finder UI evidence are still required.

4. GitHub Actions release workflow 실제 실행 검증
   Completion evidence: actual GitHub workflow run URLs/results for release candidate, draft release, and stable release paths.
   Local support: ./script/verify_release_workflow.sh
   Status boundary: real GitHub Actions execution is still required.

5. Developer ID signing, notarization, stapling, Gatekeeper 검증
   Completion evidence: signed/notarized DMG, stapler success, spctl Gatekeeper assessment success.
   Local support: ./script/verify_distribution_gate.sh
   Status boundary: Apple Developer ID credentials and signing/notarization execution are still required.

6. 플로팅 펫 실제 동작 검수
   Completion evidence: drag position save, right-click menu, offscreen correction, and menu bar action differences observed in the desktop UI.
   Local support: FloatingPetMotionBoundsTests, PetMenuModelTests, ./script/verify_runtime_contract.sh
   Status boundary: actual desktop UI evidence is still required.

7. 런타임 리소스 최적화 검토
   Completion evidence: CPU/RSS/energy impact measured while app is running, menu bar runner, floating pet, popover refresh, cache polling, and system metrics sampling reviewed.
   Local support: ./script/verify_runtime_contract.sh and ./script/sample_existing_runtime_resources.sh --self-test
   Status boundary: app runtime sampling and optimization review are still required.
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

  require_text '자동화 가능한 검증은 수동 검수를 대체하지 않습니다|수동 UI 증거' "$DOC" "manual evidence boundary"
  require_text 'Docs/V110ManualEvidence\.md' "$DOC" "manual evidence ledger documentation"
  require_text 'Docs/V110ManualEvidence\.json' "$DOC" "structured manual evidence ledger documentation"
  require_text 'Docs/V110ManualRunbook\.md' "$DOC" "manual runbook documentation"
  require_text 'verify_v110_manual_evidence\.sh --allow-incomplete' "$DOC" "manual evidence ledger verifier documentation"
  require_text 'verify_v110_manual_execution_readiness\.sh --allow-incomplete' "$DOC" "manual execution readiness documentation"
  require_text 'verify_v110_manual_runbook\.sh --self-test' "$DOC" "manual runbook verifier documentation"
  require_text 'GitHub Actions.*실제 실행' "$DOC" "GitHub Actions evidence boundary"
  require_text 'Developer ID signing' "$DOC" "Developer ID evidence boundary"
  require_text 'notarization' "$DOC" "notarization evidence boundary"
  require_text 'Gatekeeper' "$DOC" "Gatekeeper evidence boundary"
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
