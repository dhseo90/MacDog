#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOC="$ROOT_DIR/Docs/V150ReleaseReadiness.md"
USAGE_DOC="$ROOT_DIR/Docs/V150UsageReliability.md"
README="$ROOT_DIR/README.md"
ROADMAP="$ROOT_DIR/ROADMAP.md"
SCRIPTS_DOC="$ROOT_DIR/Docs/Scripts.md"
CHECK_SCRIPT="$ROOT_DIR/script/check.sh"
USAGE_FETCH_SMOKE="$ROOT_DIR/script/verify_usage_fetch_cache_contract.sh"
RELEASE_DRAFT_WORKFLOW="$ROOT_DIR/.github/workflows/release-draft.yml"
RELEASE_STABLE_WORKFLOW="$ROOT_DIR/.github/workflows/release-stable.yml"

usage() {
  cat <<USAGE
usage: $0 [--self-test]

Verify the v1.5.0 release-readiness checklist and release-step boundary.
This script is read-only and does not run GUI apps, install LaunchAgents,
start release workflows, publish releases, or touch live Codex auth data.

Options:
  --self-test  Run the same read-only checks.
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

verify_release_readiness() {
  require_file "$DOC"
  require_file "$USAGE_DOC"
  require_file "$README"
  require_file "$ROADMAP"
  require_file "$SCRIPTS_DOC"
  require_file "$CHECK_SCRIPT"
  require_file "$USAGE_FETCH_SMOKE"
  require_file "$RELEASE_DRAFT_WORKFLOW"
  require_file "$RELEASE_STABLE_WORKFLOW"
  require_executable "$ROOT_DIR/script/verify_v150_release_readiness.sh"

  require_text '릴리즈 잔여 이슈' "$DOC" "remaining release issue section"
  require_text 'Step 9.*Codex 탭 데이터 상태 UI' "$DOC" "Step 9 release readiness item"
  require_text 'Step 10.*live fetch/cache smoke 진단' "$DOC" "Step 10 release readiness item"
  require_text 'Step 11.*운영 회귀 guard' "$DOC" "Step 11 release readiness item"
  require_text 'Step 12.*release readiness 문서화' "$DOC" "Step 12 release readiness item"
  require_text 'Step 13.*README/ROADMAP/Docs' "$DOC" "Step 13 release readiness item"
  require_text 'Codex 탭 데이터 상태 UI' "$DOC" "Codex tab data status UI evidence"
  require_text 'usage-fetch:weekly-history' "$DOC" "weekly history live smoke summary"
  require_text 'usage-fetch:reset-window-history' "$DOC" "reset-window history live smoke summary"
  require_text 'verify_usage_fetch_cache_contract\.sh --cli' "$DOC" "live cache smoke command"
  require_text 'sample_existing_runtime_resources\.sh' "$DOC" "runtime sampler guard"
  require_text 'verify_privileged_helper_state\.sh --allow-missing' "$DOC" "helper state guard"
  require_text 'verify_charge_limit\.sh --read' "$DOC" "Charge Limit read-only guard"
  require_text 'verify_release_final_state\.sh --version 1\.5\.0' "$DOC" "release final-state guard"
  require_text 'Finder에서 published DMG를 열고 보이는 `MacDog\.app`을 `Applications`로 실제 drag-and-drop' "$DOC" "Finder drag-and-drop install boundary"
  require_text 'Apple Developer Program.*제외' "$DOC" "developer-account exclusion boundary"
  require_text 'WidgetKit.*기본 앱/DMG.*제외' "$DOC" "WidgetKit default exclusion boundary"
  require_text 'signed annotated tag' "$DOC" "signed annotated tag boundary"
  require_text 'Verified' "$DOC" "GitHub Verified tag boundary"
  require_text 'UI smoke' "$DOC" "manual UI smoke boundary"
  require_text 'live fetch smoke' "$DOC" "live fetch smoke boundary"
  require_text 'published DMG smoke' "$DOC" "published DMG smoke boundary"
  require_text 'MACDOG_RELEASE_VERSION=1\.5\.0 \./script/check\.sh --no-run' "$DOC" "v1.5 check command"

  require_text '상태: P0-P2 구현 완료 / reset boundary 실제 UI smoke 수행 / 릴리즈 smoke 미수행' "$USAGE_DOC" "v1.5 usage reliability status"
  require_text 'Codex 탭 데이터 상태 UI' "$USAGE_DOC" "usage reliability UI status scope"
  require_text 'usage-fetch:weekly-history' "$USAGE_FETCH_SMOKE" "weekly history live smoke output"
  require_text 'usage-fetch:reset-window-history' "$USAGE_FETCH_SMOKE" "reset-window history live smoke output"
  require_text 'V150ReleaseReadiness\.md' "$README" "README release readiness doc link"
  require_text 'V150ReleaseReadiness\.md' "$ROADMAP" "ROADMAP release readiness doc link"
  require_text 'verify_v150_release_readiness\.sh --self-test' "$SCRIPTS_DOC" "Scripts doc reference"
  require_text 'verify_v150_release_readiness\.sh --self-test' "$CHECK_SCRIPT" "check.sh release readiness gate"
  require_text 'verify_v150_usage_reliability_contract\.sh --self-test' "$CHECK_SCRIPT" "check.sh v1.5 usage contract gate"
  require_text '--verify-tag' "$RELEASE_DRAFT_WORKFLOW" "draft release pre-existing tag gate"
  require_text 'verification\.verified' "$RELEASE_DRAFT_WORKFLOW" "draft release GitHub tag verification"
  require_text '--verify-tag' "$RELEASE_STABLE_WORKFLOW" "stable release pre-existing tag gate"
  require_text 'verification\.verified' "$RELEASE_STABLE_WORKFLOW" "stable release GitHub tag verification"

  echo "v1.5.0 release readiness ok"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --self-test)
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
verify_release_readiness
