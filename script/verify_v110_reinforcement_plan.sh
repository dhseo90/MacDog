#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOC="$ROOT_DIR/Docs/V110ReinforcementVerification.md"
SELF_TEST=0

reinforcement_items=(
  "Shortcuts Charge Limit 입력 계약 확인"
  "native Charge Limit 회귀 진단 강화"
  "closed-display 장시간 회귀 검증"
  "public repo와 branch protection 적용 준비"
  "Codex app-server protocol drift 대응"
  "캐릭터 asset polish 점검"
)

usage() {
  cat <<USAGE
usage: $0 [--self-test]

Verify v1.1.0 reinforcement item coverage and local read-only/self-test
support. This verifier does not run GUI apps, close the display, change charge
limits, install helpers, call live Codex app-server, apply GitHub settings, run
GitHub Actions, push, or perform Apple Developer dependent work.

Options:
  --self-test  Run all local reinforcement support self-tests.
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
  /usr/bin/grep -Eq -- "$pattern" "$file" || die "missing $description in $file"
}

verify_documentation() {
  require_file "$DOC"
  require_text 'v1\.1\.0 보강 항목 검증' "$DOC" "reinforcement doc title"
  require_text 'GUI 앱 실행.*수행하지 않습니다|수행하지 않았다고 보고' "$DOC" "GUI no-run boundary"
  require_text '장시간 덮개 닫힘.*자동.*수행하지 않습니다|long-run.*manual-required' "$DOC" "closed-display long-run boundary"
  require_text 'GitHub 서버 설정.*변경하지 않습니다|server-apply-not-run' "$DOC" "GitHub server apply boundary"
  require_text 'live app-server.*호출하지 않습니다|live-call-not-run' "$DOC" "live app-server boundary"
  require_text 'Apple Developer Program.*제외' "$DOC" "Apple Developer exclusion"

  local item
  for item in "${reinforcement_items[@]}"; do
    require_text "$item" "$ROOT_DIR/ROADMAP.md" "$item roadmap entry"
    require_text "$item" "$DOC" "$item reinforcement documentation"
  done

  require_text 'Docs/V110ReinforcementVerification\.md' "$ROOT_DIR/README.md" "README reinforcement doc link"
  require_text 'verify_v110_reinforcement_plan\.sh --self-test' "$ROOT_DIR/Docs/Scripts.md" "Scripts reinforcement verifier reference"
  require_text 'verify_shortcuts_charge_limit\.sh' "$DOC" "Shortcuts verifier reference"
  require_text 'verify_charge_limit_regression\.sh' "$DOC" "native Charge Limit verifier reference"
  require_text 'verify_closed_display_regression_plan\.sh' "$DOC" "closed-display verifier reference"
  require_text 'verify_public_repo_branch_protection_plan\.sh' "$DOC" "public repo verifier reference"
  require_text 'verify_codex_app_server_protocol_drift\.sh' "$DOC" "protocol drift verifier reference"
  require_text 'verify_character_asset_polish\.sh' "$DOC" "character polish verifier reference"
}

verify_supporting_scripts() {
  require_executable "$ROOT_DIR/script/verify_shortcuts_charge_limit.sh"
  require_executable "$ROOT_DIR/script/verify_charge_limit_regression.sh"
  require_executable "$ROOT_DIR/script/verify_closed_display_regression_plan.sh"
  require_executable "$ROOT_DIR/script/verify_public_repo_branch_protection_plan.sh"
  require_executable "$ROOT_DIR/script/verify_codex_app_server_protocol_drift.sh"
  require_executable "$ROOT_DIR/script/verify_character_asset_polish.sh"
}

run_support_self_tests() {
  "$ROOT_DIR/script/verify_shortcuts_charge_limit.sh" --self-test >/dev/null
  "$ROOT_DIR/script/verify_charge_limit_regression.sh" --self-test >/dev/null
  "$ROOT_DIR/script/verify_closed_display_regression_plan.sh" --self-test >/dev/null
  "$ROOT_DIR/script/verify_public_repo_branch_protection_plan.sh" --self-test >/dev/null
  "$ROOT_DIR/script/verify_codex_app_server_protocol_drift.sh" --self-test >/dev/null
  "$ROOT_DIR/script/verify_character_asset_polish.sh" --self-test >/dev/null
}

verify_plan() {
  verify_documentation
  verify_supporting_scripts
  echo "v1.1.0-reinforcement:documentation-ok"
  echo "v1.1.0-reinforcement:supporting-scripts-ok"
  echo "v1.1.0-reinforcement:external-boundary-kept this verifier did not perform GUI long-run GitHub apply live app-server or Apple Developer work"
}

run_self_test() {
  verify_plan >/dev/null
  run_support_self_tests
  echo "v1.1.0 reinforcement plan self-test ok"
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

verify_plan
