#!/usr/bin/env bash
set -euo pipefail

REPOSITORY="${MACDOG_GITHUB_REPOSITORY:-dhseo90/MacDog}"
BRANCH="${MACDOG_GITHUB_BRANCH:-main}"
STATUS_CONTEXT="${MACDOG_REQUIRED_STATUS_CONTEXT:-verify}"
MODE="dry-run"

usage() {
  cat <<USAGE
Usage: $0 [--dry-run|--apply]

Configures GitHub branch protection for MacDog.

Environment:
  MACDOG_GITHUB_REPOSITORY       owner/repo target. Default: dhseo90/MacDog
  MACDOG_GITHUB_BRANCH           protected branch. Default: main
  MACDOG_REQUIRED_STATUS_CONTEXT required CI status context. Default: verify

Notes:
  - GitHub Free only allows branch protection on public repositories.
  - Private repositories need GitHub Pro/Team or must be made public first.
  - Run after the CI workflow has appeared at least once on GitHub.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      MODE="dry-run"
      shift
      ;;
    --apply)
      MODE="apply"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

body="$(cat <<JSON
{
  "required_status_checks": {
    "strict": true,
    "contexts": ["$STATUS_CONTEXT"]
  },
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": true,
    "required_approving_review_count": 1
  },
  "restrictions": null,
  "required_linear_history": false,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "block_creations": false,
  "required_conversation_resolution": true,
  "lock_branch": false,
  "allow_fork_syncing": true
}
JSON
)"

if [[ "$MODE" == "dry-run" ]]; then
  echo "Target repository: $REPOSITORY"
  echo "Target branch: $BRANCH"
  echo "Required status context: $STATUS_CONTEXT"
  echo
  echo "Branch protection payload:"
  printf '%s\n' "$body"
  echo
  echo "Dry run only. Use --apply after the repository is public or has branch protection available for private repositories."
  exit 0
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "error: gh CLI is required." >&2
  exit 1
fi

visibility="$(gh repo view "$REPOSITORY" --json visibility --jq '.visibility')"
if [[ "$visibility" == "PRIVATE" ]]; then
  echo "Repository is private. Applying anyway; GitHub will accept this only on plans that support private branch protection." >&2
fi

set +e
output="$(printf '%s\n' "$body" | gh api \
  -X PUT \
  -H "Accept: application/vnd.github+json" \
  "repos/$REPOSITORY/branches/$BRANCH/protection" \
  --input - 2>&1)"
status=$?
set -e

if [[ $status -ne 0 ]]; then
  if [[ "$output" == *"Upgrade to GitHub Pro or make this repository public"* ]]; then
    cat >&2 <<MESSAGE
error: GitHub rejected branch protection for $REPOSITORY while it is private.

Make the repository public first or enable a GitHub plan that supports branch protection on private repositories, then rerun:

  $0 --apply
MESSAGE
    exit 3
  fi

  printf '%s\n' "$output" >&2
  exit "$status"
fi

printf '%s\n' "$output"

echo "Branch protection configured for $REPOSITORY:$BRANCH"
