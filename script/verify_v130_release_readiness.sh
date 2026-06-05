#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOC="$ROOT_DIR/Docs/V130ReleaseReadiness.md"
README="$ROOT_DIR/README.md"
ROADMAP="$ROOT_DIR/ROADMAP.md"
SCRIPTS_DOC="$ROOT_DIR/Docs/Scripts.md"
CHECK_SCRIPT="$ROOT_DIR/script/check.sh"
SELF_TEST=0

usage() {
  cat <<USAGE
usage: $0 [--self-test]

Verify the v1.3.0 release-readiness audit and release-step boundary.
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

require_absent() {
  local pattern="$1"
  local file="$2"
  local description="$3"

  if /usr/bin/grep -En -- "$pattern" "$file" >/tmp/macdog-v130-release-readiness-grep.txt; then
    echo "error: forbidden v1.3.0 release-readiness term found: $description" >&2
    /bin/cat /tmp/macdog-v130-release-readiness-grep.txt >&2
    /bin/rm -f /tmp/macdog-v130-release-readiness-grep.txt
    exit 1
  fi

  /bin/rm -f /tmp/macdog-v130-release-readiness-grep.txt
}

verify_release_readiness() {
  require_file "$DOC"
  require_file "$README"
  require_file "$ROADMAP"
  require_file "$SCRIPTS_DOC"
  require_file "$CHECK_SCRIPT"
  require_executable "$ROOT_DIR/script/verify_v130_release_readiness.sh"

  require_text '자동검증 기준 제품 구현 잔여 이슈: 없음' "$DOC" "product implementation remainder closure"
  require_text '릴리즈 smoke 증거로 남김' "$DOC" "manual release smoke classification"
  require_text '실제 앱을 열지 않았다면 `UI 확인 미수행`' "$DOC" "UI unverified reporting boundary"
  require_text 'Notification Center 표시' "$DOC" "notification center manual evidence boundary"
  require_text 'Finder에서 실제 drag-and-drop' "$DOC" "Finder drag-and-drop install boundary"
  require_text '릴리즈 실행 스텝' "$DOC" "release steps section"
  require_text 'MACDOG_RELEASE_VERSION|1\.3\.0' "$DOC" "v1.3.0 release version reference"
  require_text '\./script/check\.sh --no-run' "$DOC" "no-GUI local gate"
  require_text 'PopoverTabSummaryTests' "$DOC" "popover tab summary focused test"
  require_text 'screenshot renderer는 opt-in 증거' "$DOC" "screenshot renderer evidence boundary"
  require_text 'Release Candidate' "$DOC" "release candidate workflow step"
  require_text 'Draft Release' "$DOC" "draft release workflow step"
  require_text 'verify_usage_fetch_cache_contract\.sh --cli' "$DOC" "installed CLI cache contract step"
  require_text 'verify_release_final_state\.sh --version 1\.3\.0' "$DOC" "release final-state step"
  require_text 'branch 정리.*별도 승인' "$DOC" "branch cleanup approval boundary"
  require_text 'Apple Developer 계정 의존.*제외' "$DOC" "developer-account exclusion boundary"
  require_text 'WidgetKit.*기본 앱/DMG에서 제외' "$DOC" "WidgetKit default exclusion boundary"

  require_absent 'Developer ID|notarization|App Group|App Store Connect|Stable Release|APNs|push token|provisioning profile' "$DOC" "$DOC"

  require_text 'V130ReleaseReadiness\.md' "$README" "README release readiness doc link"
  require_text 'V130ReleaseReadiness\.md' "$ROADMAP" "ROADMAP release readiness doc link"
  require_text 'verify_v130_release_readiness\.sh --self-test' "$SCRIPTS_DOC" "Scripts doc reference"
  require_text 'verify_v130_release_readiness\.sh --self-test' "$CHECK_SCRIPT" "check.sh release readiness gate"

  echo "v1.3.0 release readiness ok"
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
  verify_release_readiness
  exit 0
fi

verify_release_readiness
