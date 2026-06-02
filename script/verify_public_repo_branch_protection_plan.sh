#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
POLICY="$ROOT_DIR/config/public_repo_policy.json"
SELF_TEST=0

usage() {
  cat <<USAGE
usage: $0 [--self-test]

Verify repo-local public release and branch protection readiness without
changing GitHub server settings. This runs only local checks and dry-run
payload generation.

Options:
  --self-test  Validate the verifier output and dry-run boundaries.
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

validate_policy() {
  require_file "$POLICY"
  /usr/bin/ruby -rjson - "$POLICY" <<'RUBY'
path = ARGV.fetch(0)
policy = JSON.parse(File.read(path))
abort("repository mismatch") unless policy.fetch("repository") == "dhseo90/MacDog"
abort("visibilityTarget must be public") unless policy.fetch("visibilityTarget") == "public"
abort("defaultBranch must be main") unless policy.fetch("defaultBranch") == "main"
checks = policy.fetch("requiredStatusChecks")
abort("requiredStatusChecks mismatch") unless checks == ["static-gates", "guardrails"]
settings = policy.fetch("githubServerSettings")
actions = settings.fetch("actions")
abort("workflow permissions must be read") unless actions.fetch("defaultWorkflowPermissions") == "read"
abort("PR review approval must be disabled") unless actions.fetch("canApprovePullRequestReviews") == false
branch = settings.fetch("branchProtection")
abort("branch target must be main") unless branch.fetch("target") == "main"
abort("branch protection must require PR") unless branch.fetch("requirePullRequest") == true
abort("branch protection must require code owner review") unless branch.fetch("requireCodeOwnerReview") == true
abort("branch protection must block force pushes") unless branch.fetch("blockForcePushes") == true
abort("branch protection must block deletion") unless branch.fetch("blockBranchDeletion") == true
abort("branch protection must require conversation resolution") unless branch.fetch("requireConversationResolution") == true
puts "public-repo-policy:ok repository=#{policy.fetch("repository")} branch=#{policy.fetch("defaultBranch")} checks=#{checks.join(",")}"
RUBY
}

verify_local_files() {
  require_file "$ROOT_DIR/.github/workflows/ci.yml"
  require_file "$ROOT_DIR/.github/workflows/public-repo-guardrails.yml"
  require_file "$ROOT_DIR/.github/CODEOWNERS"
  require_file "$ROOT_DIR/.github/pull_request_template.md"
  require_file "$ROOT_DIR/.github/dependabot.yml"
  require_file "$ROOT_DIR/Docs/GitHubReleaseChecklist.md"
  require_file "$ROOT_DIR/Docs/ReleasePackaging.md"
  require_executable "$ROOT_DIR/script/configure_github_public_repo_settings.sh"
  require_executable "$ROOT_DIR/script/configure_github_branch_protection.sh"
  require_executable "$ROOT_DIR/script/verify_public_repo_guardrails.sh"

  require_text 'name:[[:space:]]*static-gates' "$ROOT_DIR/.github/workflows/ci.yml" "static-gates workflow name"
  require_text 'name:[[:space:]]*guardrails' "$ROOT_DIR/.github/workflows/public-repo-guardrails.yml" "guardrails workflow name"
  require_text 'contents:[[:space:]]*read' "$ROOT_DIR/.github/workflows/ci.yml" "read-only CI token permission"
  require_text 'contents:[[:space:]]*read' "$ROOT_DIR/.github/workflows/public-repo-guardrails.yml" "read-only guardrails token permission"
  require_text 'static-gates' "$ROOT_DIR/Docs/GitHubReleaseChecklist.md" "required static-gates docs"
  require_text 'guardrails' "$ROOT_DIR/Docs/GitHubReleaseChecklist.md" "required guardrails docs"
  require_text 'public 전환|make-public|public repo' "$ROOT_DIR/Docs/GitHubReleaseChecklist.md" "public transition docs"
  require_text 'branch protection' "$ROOT_DIR/Docs/ReleasePackaging.md" "branch protection release docs"
}

verify_dry_runs() {
  local dry_run_temp_dir
  dry_run_temp_dir="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/macdog-public-repo-plan.XXXXXX")"

  local public_output="$dry_run_temp_dir/public-settings.txt"
  local branch_output="$dry_run_temp_dir/branch-protection.txt"
  "$ROOT_DIR/script/configure_github_public_repo_settings.sh" --dry-run >"$public_output"
  "$ROOT_DIR/script/configure_github_branch_protection.sh" --dry-run >"$branch_output"

  require_text 'No GitHub settings were changed' "$public_output" "public settings dry-run no-change boundary"
  require_text 'Apply branch protection required checks' "$public_output" "public settings branch protection step"
  require_text 'Dry run only' "$branch_output" "branch protection dry-run boundary"
  require_text '"static-gates"' "$branch_output" "static-gates branch payload"
  require_text '"guardrails"' "$branch_output" "guardrails branch payload"
  require_text '"required_conversation_resolution":[[:space:]]*true' "$branch_output" "conversation resolution payload"
  require_text '"allow_force_pushes":[[:space:]]*false' "$branch_output" "force push block payload"
  require_text '"allow_deletions":[[:space:]]*false' "$branch_output" "deletion block payload"
  rm -rf "$dry_run_temp_dir"
}

verify_plan() {
  validate_policy
  verify_local_files
  "$ROOT_DIR/script/verify_public_repo_guardrails.sh" >/dev/null
  verify_dry_runs
  echo "public-repo-branch-protection:repo-local-ready"
  echo "public-repo-branch-protection:server-apply-not-run"
  echo "public-repo-branch-protection:apply-boundary public repo or private branch protection capable plan is required before --apply"
}

run_self_test() {
  local temp_dir
  temp_dir="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/macdog-public-repo-self.XXXXXX")"
  trap 'rm -rf "$temp_dir"' RETURN

  local output_file="$temp_dir/output.txt"
  verify_plan >"$output_file"
  require_text 'public-repo-policy:ok repository=dhseo90/MacDog branch=main checks=static-gates,guardrails' "$output_file" "policy summary"
  require_text 'public-repo-branch-protection:repo-local-ready' "$output_file" "repo local readiness"
  require_text 'public-repo-branch-protection:server-apply-not-run' "$output_file" "server apply boundary"
  require_text 'public repo or private branch protection capable plan' "$output_file" "plan requirement boundary"
  echo "public repo branch protection plan self-test ok"
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
