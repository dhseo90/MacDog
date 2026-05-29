#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
POLICY="$ROOT_DIR/config/public_repo_policy.json"

die() {
  echo "error: $*" >&2
  exit 1
}

require_file() {
  local path="$1"
  [[ -f "$ROOT_DIR/$path" ]] || die "required public repo file missing: $path"
}

require_text() {
  local path="$1"
  local text="$2"
  /usr/bin/grep -Fq -- "$text" "$ROOT_DIR/$path" || die "missing '$text' in $path"
}

reject_text() {
  local path="$1"
  local text="$2"
  if /usr/bin/grep -Fq -- "$text" "$ROOT_DIR/$path"; then
    die "forbidden '$text' in $path"
  fi
}

require_file "config/public_repo_policy.json"
require_file "LICENSE"
require_file "README.md"
require_file "CONTRIBUTING.md"
require_file "SECURITY.md"
require_file "AGENTS.md"
require_file ".github/CODEOWNERS"
require_file ".github/pull_request_template.md"
require_file ".github/dependabot.yml"
require_file ".github/workflows/ci.yml"
require_file ".github/workflows/public-repo-guardrails.yml"
require_file "Docs/GitHubReleaseChecklist.md"
require_file "Docs/ReleasePackaging.md"
require_file "script/configure_github_branch_protection.sh"

require_text "LICENSE" "Apache License"
require_text ".github/CODEOWNERS" "* @dhseo90"
require_text ".github/workflows/ci.yml" "name: static-gates"
require_text ".github/workflows/ci.yml" "permissions:"
require_text ".github/workflows/ci.yml" "contents: read"
require_text ".github/workflows/ci.yml" "./script/check.sh --no-run"
require_text ".github/workflows/public-repo-guardrails.yml" "name: guardrails"
require_text ".github/workflows/public-repo-guardrails.yml" "contents: read"
require_text ".github/workflows/public-repo-guardrails.yml" "./script/verify_public_repo_guardrails.sh"
require_text ".github/dependabot.yml" "package-ecosystem: \"github-actions\""
require_text "config/public_repo_policy.json" "\"static-gates\""
require_text "config/public_repo_policy.json" "\"guardrails\""
require_text "config/public_repo_policy.json" "\"defaultWorkflowPermissions\": \"read\""
require_text "config/public_repo_policy.json" "\"canApprovePullRequestReviews\": false"
require_text "Docs/GitHubReleaseChecklist.md" "static-gates"
require_text "Docs/GitHubReleaseChecklist.md" "guardrails"
require_text "script/configure_github_branch_protection.sh" "static-gates"
require_text "script/configure_github_branch_protection.sh" "guardrails"

reject_text ".github/workflows/ci.yml" "contents: write"
reject_text ".github/workflows/public-repo-guardrails.yml" "contents: write"

"$ROOT_DIR/script/verify_readme_screenshots.sh" >/dev/null
"$ROOT_DIR/script/verify_dist_hygiene.sh" >/dev/null

tracked_forbidden="$(
  git -C "$ROOT_DIR" ls-files | /usr/bin/awk '
    /^(Assets\/Generated\/|dist\/|\.build\/|DerivedData\/)/ { print }
  '
)"
if [[ -n "$tracked_forbidden" ]]; then
  echo "$tracked_forbidden" >&2
  die "forbidden generated/build artifact paths are tracked"
fi

bad_images="$(
  git -C "$ROOT_DIR" ls-files | /usr/bin/awk '
    BEGIN { IGNORECASE = 1 }
    /\.(png|jpg|jpeg|gif|webp|heic|tif|tiff|icns)$/ &&
      $0 !~ /^Sources\/MacDog\/Resources\// &&
      $0 !~ /^Docs\/Images\/README\// { print }
  '
)"
if [[ -n "$bad_images" ]]; then
  echo "$bad_images" >&2
  die "tracked image outside allowed resource directories"
fi

large_files="$(
  git -C "$ROOT_DIR" ls-files -z | while IFS= read -r -d '' file; do
    [[ -f "$ROOT_DIR/$file" ]] || continue
    size="$(/usr/bin/stat -f%z "$ROOT_DIR/$file")"
    if [[ "$size" -gt 25000000 ]]; then
      printf '%s %s\n' "$size" "$file"
    fi
  done
)"
if [[ -n "$large_files" ]]; then
  echo "$large_files" >&2
  die "tracked file exceeds public repo artifact size policy"
fi

secret_hits="$(
  git -C "$ROOT_DIR" grep -n -E \
    'BEGIN [A-Z ]*PRIVATE KEY|ghp_[A-Za-z0-9_]+|github_pat_[A-Za-z0-9_]+|sk-[A-Za-z0-9]{20,}|xox[baprs]-[A-Za-z0-9-]+' \
    -- \
    ':!Tests' \
    ':!script/verify_cache_contract.sh' \
    ':!script/write_widget_cache_fixture.sh' \
    ':!script/verify_public_repo_guardrails.sh' || true
)"
if [[ -n "$secret_hits" ]]; then
  echo "$secret_hits" >&2
  die "potential secret pattern found in tracked files"
fi

uses_lines="$(
  git -C "$ROOT_DIR" grep -h 'uses: ' -- '.github/workflows/*.yml' | /usr/bin/sed 's/^[[:space:]]*uses:[[:space:]]*//'
)"
unexpected_uses="$(
  printf '%s\n' "$uses_lines" | /usr/bin/awk '
    NF && $0 != "actions/checkout@v6" && $0 != "actions/upload-artifact@v7" { print }
  '
)"
if [[ -n "$unexpected_uses" ]]; then
  echo "$unexpected_uses" >&2
  die "workflow uses action outside allowlist"
fi

echo "Public repo guardrails ok"
