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
LIVE_CACHE_VERIFIER="$ROOT_DIR/script/verify_usage_fetch_cache_contract.sh"

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
  require_file "$LIVE_CACHE_VERIFIER"
  [[ -x "$ROOT_DIR/script/verify_v180_release_readiness.sh" ]] || \
    die "v1.8 release-readiness verifier is not executable"

  require_match '^상태: v1\.8\.0 GitHub Release publish' "$DOC" "published release status"
  require_match 'published DMG Finder 설치.*final-state 확인' "$DOC" \
    "published install and final-state status"
  require_match '실제 Claude 구독 live smoke 미수행' "$DOC" "honest live status"
  require_match 'MACDOG_APP_VERSION=1\.8\.0 \./script/check\.sh --no-run' "$DOC" "versioned check gate"
  require_match '승인 1회.*Code Owners review.*branch 최신화' "$DOC" "review and up-to-date branch gate"
  require_match '필수 CI.*static-gates' "$DOC" "required static gate"
  require_match 'guardrails.*unresolved conversation 0개' "$DOC" "guardrails and conversation gate"
  require_match '최신 `origin/main` SHA.*release head' "$DOC" "release head rule"
  require_match 'signed annotated `v1\.8\.0` tag' "$DOC" "signed tag rule"
  require_match 'GitHub tag verification.*`Verified`' "$DOC" "GitHub verified tag rule"
  require_match 'Release Candidate' "$DOC" "release candidate step"
  require_match 'MacDog-1\.8\.0\.dmg.*MacDog-1\.8\.0\.dmg\.sha256' "$DOC" "artifact pair"
  require_match 'isDraft=true.*isPrerelease=false.*signed tag target SHA' "$DOC" "draft state gate"
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
  require_match '14d716a88ea10a77344a4f9aa3651c23b1160f8c' "$DOC" "published release head evidence"
  require_match '1d9748753761f0dfeca1b2f3c4aeebccd2389aba' "$DOC" "signed tag object evidence"
  require_match '29253650552' "$DOC" "release candidate run evidence"
  require_match '29254330686' "$DOC" "draft release run evidence"
  require_match '353177762' "$DOC" "published release id evidence"
  require_match '056926bd16668c288d132fab7ff8efb545f00d8eefb8f222440e3f389338a3af' \
    "$DOC" "published DMG checksum evidence"
  require_match '4526329e79f5cebfd5897830ac3d8037948589ece6c7f9af5529b41da50c910b' \
    "$DOC" "published and installed executable checksum evidence"
  require_match 'Release Candidate.*Draft Release.*별도 build' "$DOC" \
    "separate workflow build identity boundary"
  require_match 'bit-for-bit 동등성 통과로 기록하지 않습니다' "$DOC" \
    "non-reproducible build evidence boundary"
  require_match '설치본 UI 직접 1번 탭 compact layout.*설정 불필요 UI 제거.*Claude empty state 확인' "$DOC" \
    "installed UI confirmation evidence"
  require_match 'Codex → Claude.*LaunchAgent plist/job 제거' "$DOC" \
    "Claude mode cache agent removal evidence"
  require_match 'Claude → Codex.*LaunchAgent 설치본 CLI 복구' "$DOC" \
    "Codex mode cache agent recovery evidence"
  require_match 'verify_release_final_state\.sh --version 1\.8\.0.*통과' "$DOC" \
    "completed final-state evidence"
  require_match 'Finder `응용 프로그램` 범위 `MacDog` 1개 확인' "$DOC" \
    "Finder single installed app evidence"
  require_absent_match 'PR, CI, review \| 미수행|최종 `origin/main` release head \| 미기록|signed annotated `v1\.8\.0` tag / GitHub `Verified` \| 미수행|Published release와 재다운로드 검증 \| 미수행|cleanup / final-state \| 미수행' \
    "$DOC" "stale release execution evidence"
  require_match 'weekly-only.*partial success' "$DOC" "Codex weekly-only release scope"
  require_match '5시간 현재 제공되지 않음' "$DOC" "weekly-only GUI smoke"
  require_match '5시간 window 복구 시' "$DOC" "five-hour recovery smoke"
  require_match '자동 재개되는지도 확인' "$DOC" "five-hour recovery completion"
  require_match '`Stable Release` workflow' "$DOC" "stable workflow scope"
  require_match '승인되지 않았으므로 실행하지 않습니다' "$DOC" "stable workflow exclusion"

  require_match 'V180ReleaseReadiness\.md' "$README" "README release document link"
  require_match 'V180ReleaseReadiness\.md' "$ROADMAP" "ROADMAP release document link"
  require_match '현재 GitHub Release는 \[v1\.8\.0\]' "$README" "README current release"
  require_match 'MacDog-1\.8\.0\.dmg' "$README" "README current installer"
  require_match '14d716a88ea10a77344a4f9aa3651c23b1160f8c' "$README" \
    "README published release head"
  require_match 'v1\.8\.0.*릴리즈 완료' "$ROADMAP" "ROADMAP completed release status"
  require_match 'v1\.8\.0 publish.*Finder 설치.*final-state 완료' "$PRODUCT_DOC" \
    "product release completion status"
  require_match 'weekly-only.*partial' "$PRODUCT_DOC" "weekly-only product contract"
  require_match 'weekly-only' "$README" "weekly-only README contract"
  require_match '정상 partial success' "$README" "weekly-only success semantics"
  require_match 'weekly-only.*partial success' "$AGENTS" "weekly-only agent data rule"
  require_match '5-hour window is optional' "$LIVE_CACHE_VERIFIER" \
    "weekly-required live cache verifier"
  require_match '"weekly-only"' "$LIVE_CACHE_VERIFIER" "weekly-only live mode"
  require_match 'usage-fetch:success windows=#\{mode\}' "$LIVE_CACHE_VERIFIER" \
    "weekly-only live result marker"
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
  require_match 'id: create_draft' "$DRAFT_WORKFLOW" "draft creation step identity"
  require_match 'echo "url=\$draft_url" >> "\$GITHUB_OUTPUT"' "$DRAFT_WORKFLOW" \
    "created draft URL output"
  require_match 'DRAFT_RELEASE_URL: \$\{\{ steps\.create_draft\.outputs\.url \}\}' \
    "$DRAFT_WORKFLOW" "created draft URL readback"
  require_match 'DRAFT_RELEASE_LOOKUP_ATTEMPTS=10' \
    "$DRAFT_WORKFLOW" "eventually consistent draft lookup attempts"
  require_match 'DRAFT_RELEASE_LOOKUP_DELAY_SECONDS=2' \
    "$DRAFT_WORKFLOW" "eventually consistent draft lookup delay"
  require_match 'releases\?per_page=100' "$DRAFT_WORKFLOW" "draft release list lookup"
  require_match '\[\.id, \.html_url\] \| @tsv' "$DRAFT_WORKFLOW" \
    "created draft URL to release ID lookup"
  require_match 'Created draft release is not visible yet; retrying readback' \
    "$DRAFT_WORKFLOW" "eventually consistent draft readback retry"
  require_match 'sleep "\$DRAFT_RELEASE_LOOKUP_DELAY_SECONDS"' \
    "$DRAFT_WORKFLOW" "eventually consistent draft readback backoff"
  require_match 'gh api --method DELETE "repos/\$GITHUB_REPOSITORY/releases/\$release_id"' \
    "$DRAFT_WORKFLOW" "failed draft cleanup by release ID"
  require_match 'releases/\$release_id' "$DRAFT_WORKFLOW" "draft readback by release ID"
  require_match 'target_sha.*GITHUB_SHA' "$DRAFT_WORKFLOW" "signed tag target identity readback"
  require_match 'target_commitish.*informational' "$DRAFT_WORKFLOW" "informational target metadata readback"
  require_match 'asset_names' "$DRAFT_WORKFLOW" "draft asset readback"
  require_match 'is_draft.*true.*is_prerelease.*false' "$DRAFT_WORKFLOW" "draft state readback"
  require_match 'verification_complete=1' "$DRAFT_WORKFLOW" "successful draft verification marker"
  require_absent_match '--target "\$GITHUB_SHA"|target_commitish="\$GITHUB_SHA"|gh api --method PATCH' \
    "$DRAFT_WORKFLOW" "unsupported existing-tag target metadata mutation"
  require_absent_match 'releases/tags/\$MACDOG_TAG|gh release delete "\$MACDOG_TAG"' \
    "$DRAFT_WORKFLOW" "draft tag endpoint lookup or tag-based draft cleanup"
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
