#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKFLOW="$ROOT_DIR/.github/workflows/release-candidate.yml"
DRAFT_WORKFLOW="$ROOT_DIR/.github/workflows/release-draft.yml"
STABLE_WORKFLOW="$ROOT_DIR/.github/workflows/release-stable.yml"
CI_WORKFLOW="$ROOT_DIR/.github/workflows/ci.yml"
GUARDRAILS_WORKFLOW="$ROOT_DIR/.github/workflows/public-repo-guardrails.yml"
CODEOWNERS="$ROOT_DIR/.github/CODEOWNERS"
BRANCH_PROTECTION_SCRIPT="$ROOT_DIR/script/configure_github_branch_protection.sh"

die() {
  echo "error: $*" >&2
  exit 1
}

require_match() {
  local pattern="$1"
  /usr/bin/grep -Eq -- "$pattern" "$WORKFLOW" || die "missing expected release workflow pattern: $pattern"
}

require_draft_match() {
  local pattern="$1"
  /usr/bin/grep -Eq -- "$pattern" "$DRAFT_WORKFLOW" || die "missing expected draft release workflow pattern: $pattern"
}

require_stable_match() {
  local pattern="$1"
  /usr/bin/grep -Eq -- "$pattern" "$STABLE_WORKFLOW" || die "missing expected stable release workflow pattern: $pattern"
}

require_ci_match() {
  local pattern="$1"
  /usr/bin/grep -Eq -- "$pattern" "$CI_WORKFLOW" || die "missing expected ci workflow pattern: $pattern"
}

require_guardrails_match() {
  local pattern="$1"
  /usr/bin/grep -Eq -- "$pattern" "$GUARDRAILS_WORKFLOW" || die "missing expected guardrails workflow pattern: $pattern"
}

[[ -f "$WORKFLOW" ]] || die "release candidate workflow missing: $WORKFLOW"
[[ -f "$DRAFT_WORKFLOW" ]] || die "draft release workflow missing: $DRAFT_WORKFLOW"
[[ -f "$CI_WORKFLOW" ]] || die "ci workflow missing: $CI_WORKFLOW"
[[ -f "$GUARDRAILS_WORKFLOW" ]] || die "guardrails workflow missing: $GUARDRAILS_WORKFLOW"
[[ -f "$CODEOWNERS" ]] || die "CODEOWNERS missing: $CODEOWNERS"
[[ -x "$BRANCH_PROTECTION_SCRIPT" ]] || die "branch protection script missing or not executable: $BRANCH_PROTECTION_SCRIPT"

require_ci_match 'pull_request'
require_ci_match 'branches:'
require_ci_match 'main'
require_ci_match 'runs-on: macos-latest'
require_ci_match './script/check\.sh --no-run'
require_ci_match 'name: static-gates'
require_guardrails_match 'pull_request'
require_guardrails_match 'branches:'
require_guardrails_match 'main'
require_guardrails_match 'runs-on: macos-latest'
require_guardrails_match './script/verify_public_repo_guardrails\.sh'
require_guardrails_match 'name: guardrails'
/usr/bin/grep -Fq -- '@dhseo90' "$CODEOWNERS" || die "CODEOWNERS must include @dhseo90"
/usr/bin/grep -Fq -- 'required_pull_request_reviews' "$BRANCH_PROTECTION_SCRIPT" || die "branch protection script missing PR review rule"
/usr/bin/grep -Fq -- 'require_code_owner_reviews' "$BRANCH_PROTECTION_SCRIPT" || die "branch protection script missing code owner review rule"
/usr/bin/grep -Fq -- 'required_status_checks' "$BRANCH_PROTECTION_SCRIPT" || die "branch protection script missing required status checks"
/usr/bin/grep -Fq -- 'static-gates' "$BRANCH_PROTECTION_SCRIPT" || die "branch protection script missing static-gates check"
/usr/bin/grep -Fq -- 'guardrails' "$BRANCH_PROTECTION_SCRIPT" || die "branch protection script missing guardrails check"

require_match 'workflow_dispatch'
require_match 'MACDOG_RELEASE_VERSION'
require_match './script/check\.sh --no-run'
require_match './script/package_release\.sh --skip-build'
require_match 'hdiutil verify'
require_match 'shasum -a 256 -c'
require_match 'actions/upload-artifact@v7'
require_match 'unsigned-release-candidate'
require_match '\.dmg\.sha256'

require_draft_match 'workflow_dispatch'
require_draft_match 'contents: write'
require_draft_match 'UNSIGNED-DRAFT'
require_draft_match './script/check\.sh --no-run'
require_draft_match './script/package_release\.sh --skip-build'
require_draft_match 'hdiutil verify'
require_draft_match 'shasum -a 256 -c'
require_draft_match 'gh "\$\{args\[@\]\}"'
require_draft_match '--draft'
require_draft_match '--notes-file'
require_draft_match '\.dmg\.sha256'

if [[ -f "$STABLE_WORKFLOW" ]]; then
  require_stable_match 'workflow_dispatch'
  require_stable_match 'contents: write'
  require_stable_match 'SIGNED-STABLE'
  require_stable_match 'public-stable-release'
  require_stable_match './script/check\.sh --no-run'
  require_stable_match './script/build_and_run\.sh --no-run'
  require_stable_match 'codesign.+--options[ =]runtime|--options[ =]runtime.+codesign'
  require_stable_match 'Contents/MacOS/codex-usage'
  require_stable_match 'notarytool submit'
  require_stable_match 'stapler staple'
  require_stable_match 'spctl --assess'
  require_stable_match 'shasum -a 256 -c'
  require_stable_match 'gh release create'
  require_stable_match '--latest'
fi

"$ROOT_DIR/script/verify_distribution_gate.sh" >/dev/null

echo "Release workflow verification ok"
