#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOC="$ROOT_DIR/Docs/V140ReleaseReadiness.md"
README="$ROOT_DIR/README.md"
ROADMAP="$ROOT_DIR/ROADMAP.md"
SCRIPTS_DOC="$ROOT_DIR/Docs/Scripts.md"
CHECK_SCRIPT="$ROOT_DIR/script/check.sh"
PACKAGE_SCRIPT="$ROOT_DIR/script/package_release.sh"

usage() {
  cat <<USAGE
usage: $0 [--self-test]

Verify the v1.4.0 release-readiness checklist and release-step boundary.
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
  require_file "$README"
  require_file "$ROADMAP"
  require_file "$SCRIPTS_DOC"
  require_file "$CHECK_SCRIPT"
  require_file "$PACKAGE_SCRIPT"
  require_executable "$ROOT_DIR/script/verify_v140_release_readiness.sh"

  require_text '릴리즈 잔여 이슈' "$DOC" "remaining release issue section"
  require_text 'direct push bypass' "$DOC" "direct push bypass audit item"
  require_text 'required checks 2개 통과' "$DOC" "required checks evidence"
  require_text 'MacDog-1\.4\.0\.dmg' "$DOC" "v1.4.0 DMG artifact"
  require_text 'MacDog-1\.4\.0\.dmg\.sha256' "$DOC" "v1.4.0 checksum artifact"
  require_text 'Release Candidate' "$DOC" "release candidate workflow step"
  require_text 'Draft Release' "$DOC" "draft release workflow step"
  require_text 'UNSIGNED-DRAFT' "$DOC" "unsigned draft release gate"
  require_text 'Finder에서 published DMG를 열고 보이는 `MacDog\.app`을 `Applications`로 실제 drag-and-drop' "$DOC" "Finder drag-and-drop install boundary"
  require_text '현재/과거/오버레이' "$DOC" "v1.4.0 Codex tab UI smoke"
  require_text 'PNG copy/export' "$DOC" "graph copy/export UI smoke"
  require_text 'verify_usage_fetch_cache_contract\.sh --cli /Applications/MacDog\.app/Contents/MacOS/codex-usage' "$DOC" "installed CLI cache contract"
  require_text 'usage-reset-window-history\.json' "$DOC" "reset window history live smoke"
  require_text 'verify_release_final_state\.sh --version 1\.4\.0' "$DOC" "release final-state step"
  require_text 'branch 정리.*별도 승인' "$DOC" "branch cleanup approval boundary"
  require_text 'Apple Developer Program.*제외' "$DOC" "developer-account exclusion boundary"
  require_text 'WidgetKit.*기본 앱/DMG.*제외' "$DOC" "WidgetKit default exclusion boundary"
  require_text 'UI 확인 미수행' "$DOC" "UI unverified reporting boundary"
  require_text '가격 tier.*추정' "$DOC" "plan tier no-inference boundary"

  require_text 'V140ReleaseReadiness\.md' "$README" "README release readiness doc link"
  require_text 'V140ReleaseReadiness\.md' "$ROADMAP" "ROADMAP release readiness doc link"
  require_text 'verify_v140_release_readiness\.sh --self-test' "$SCRIPTS_DOC" "Scripts doc reference"
  require_text 'verify_v140_release_readiness\.sh --self-test' "$CHECK_SCRIPT" "check.sh release readiness gate"
  require_text 'verify_v140_usage_intelligence_contract\.sh --self-test' "$CHECK_SCRIPT" "check.sh v1.4 usage contract gate"
  require_text 'Codex Usage Intelligence' "$PACKAGE_SCRIPT" "v1.4 release note highlights"
  require_text '현재/과거/오버레이 그래프' "$PACKAGE_SCRIPT" "v1.4 graph overlay release note"
  require_text 'usage-reset-window-history\.json' "$PACKAGE_SCRIPT" "v1.4 history file release note"
  require_text '플랜 가격 tier는 추정하지' "$PACKAGE_SCRIPT" "v1.4 plan tier release note boundary"

  echo "v1.4.0 release readiness ok"
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
