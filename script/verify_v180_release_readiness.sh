#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOC="$ROOT_DIR/Docs/V180ReleaseReadiness.md"
PRODUCT_DOC="$ROOT_DIR/Docs/V180ClaudeUsageParityPreview.md"
README="$ROOT_DIR/README.md"
ROADMAP="$ROOT_DIR/ROADMAP.md"
AGENTS="$ROOT_DIR/AGENTS.md"
SCRIPTS_DOC="$ROOT_DIR/Docs/Scripts.md"
CHECK_SCRIPT="$ROOT_DIR/script/check.sh"
PACKAGE_SCRIPT="$ROOT_DIR/script/package_release.sh"
DRAFT_WORKFLOW="$ROOT_DIR/.github/workflows/release-draft.yml"

usage() {
  cat <<USAGE
usage: $0 [--self-test]

Verify the offline v1.8.0 release-readiness execution contract.
This script does not use the network, run GUI apps, install components,
start workflows, create tags, publish releases, or read Claude private data.
USAGE
}

die() {
  echo "error: $*" >&2
  exit 1
}

require_file() {
  [[ -f "$1" ]] || die "missing required file: $1"
}

require_match() {
  local pattern="$1"
  local file="$2"
  local description="$3"
  /usr/bin/grep -Eq -- "$pattern" "$file" || die "missing $description in $file"
}

require_absent_match() {
  local pattern="$1"
  local file="$2"
  local description="$3"
  ! /usr/bin/grep -Eq -- "$pattern" "$file" || die "found $description in $file"
}

verify_contract() {
  local file
  for file in "$DOC" "$PRODUCT_DOC" "$README" "$ROADMAP" "$AGENTS" "$SCRIPTS_DOC" \
    "$CHECK_SCRIPT" "$PACKAGE_SCRIPT" "$DRAFT_WORKFLOW"; do
    require_file "$file"
  done
  [[ -x "$ROOT_DIR/script/verify_v180_release_readiness.sh" ]] || \
    die "v1.8 release-readiness verifier is not executable"

  require_match '상태: 로컬 개발 자동 검증 통과.*PR·CI·review.*미수행' "$DOC" "honest pending status"
  require_match 'MACDOG_APP_VERSION=1\.8\.0 \./script/check\.sh --no-run' "$DOC" "versioned check gate"
  require_match '승인 1회.*Code Owners review.*branch 최신화' "$DOC" "review and up-to-date branch gate"
  require_match '필수 CI.*static-gates' "$DOC" "required static gate"
  require_match 'guardrails.*unresolved conversation 0개' "$DOC" "guardrails and conversation gate"
  require_match '최신 `origin/main` SHA.*release head' "$DOC" "release head rule"
  require_match 'signed annotated `v1\.8\.0` tag' "$DOC" "signed tag rule"
  require_match 'GitHub tag verification.*`Verified`' "$DOC" "GitHub verified tag rule"
  require_match 'Release Candidate' "$DOC" "release candidate step"
  require_match 'MacDog-1\.8\.0\.dmg.*MacDog-1\.8\.0\.dmg\.sha256' "$DOC" "artifact pair"
  require_match 'isDraft=true.*isPrerelease=false.*targetCommitish' "$DOC" "draft state gate"
  require_match 'rate_limits\.five_hour.*seven_day' "$DOC" "live Claude rate limits"
  require_match 'Claude settings, auth store, Keychain, transcript.*읽거나 저장하지' "$DOC" \
    "live privacy boundary"
  require_match 'Finder에서 published DMG.*`MacDog\.app`.*`Applications`' "$DOC" \
    "Finder installation boundary"
  require_match 'drag-and-drop' "$DOC" "actual drag-and-drop boundary"
  require_match '사용량 mode.*plan transition.*Claude Preview UI' "$DOC" "settings GUI smoke"
  require_match 'verify_release_final_state\.sh --version 1\.8\.0' "$DOC" "final-state gate"
  require_match '릴리즈 증거 기록' "$DOC" "evidence ledger"
  require_match '실제 Claude live smoke \| 미수행' "$DOC" "honest live evidence"
  require_match '`Stable Release` workflow' "$DOC" "stable workflow scope"
  require_match '승인되지 않았으므로 실행하지 않습니다' "$DOC" "stable workflow exclusion"

  require_match 'V180ReleaseReadiness\.md' "$README" "README release document link"
  require_match 'V180ReleaseReadiness\.md' "$ROADMAP" "ROADMAP release document link"
  require_match 'verify_v180_release_readiness\.sh --self-test' "$SCRIPTS_DOC" "Scripts gate entry"
  require_match 'verify_v180_release_readiness\.sh --self-test' "$CHECK_SCRIPT" "check.sh gate"
  require_match 'verify_v180_selected_provider_contract\.sh --self-test' "$CHECK_SCRIPT" \
    "product gate ordering"
  require_match '1\.8\.0\)' "$PACKAGE_SCRIPT" "v1.8 release notes"
  require_match 'Codex/Claude 선택 mode' "$PACKAGE_SCRIPT" "selected-provider release support"
  require_match '`codex-usage` CLI는 Codex 전용' "$PACKAGE_SCRIPT" "Codex-only CLI support"
  require_match '`macdog-claude-statusline` bridge' "$PACKAGE_SCRIPT" "Claude bridge support"
  require_match '--verify-tag' "$DRAFT_WORKFLOW" "pre-existing release tag gate"
  require_match 'verification\.verified' "$DRAFT_WORKFLOW" "draft tag verification gate"
  require_match 'MACDOG_TAG.*!=.*v\$MACDOG_VERSION' "$DRAFT_WORKFLOW" "version and tag identity gate"
  require_match '--target "\$GITHUB_SHA"' "$DRAFT_WORKFLOW" "draft target identity"
  require_match 'target_commitish' "$DRAFT_WORKFLOW" "draft target readback"
  require_match 'asset_names' "$DRAFT_WORKFLOW" "draft asset readback"
  require_match 'is_draft.*true.*is_prerelease.*false' "$DRAFT_WORKFLOW" "draft state readback"
  require_match 'unsigned/ad-hoc 배포' "$PACKAGE_SCRIPT" "publish-safe unsigned release note"
  require_absent_match '릴리즈 후보' "$PACKAGE_SCRIPT" "stale release candidate copy"

  echo "v1.8.0 release readiness ok"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --self-test) ;;
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
verify_contract
