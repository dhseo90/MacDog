#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPOSITORY="${MACDOG_GITHUB_REPOSITORY:-dhseo90/MacDog}"
BRANCH_PROTECTION_SCRIPT="${MACDOG_BRANCH_PROTECTION_SCRIPT:-$ROOT_DIR/script/configure_github_branch_protection.sh}"
MODE="dry-run"
MAKE_PUBLIC=0

usage() {
  cat <<USAGE
Usage: $0 [--dry-run|--check|--apply] [--make-public]

Prepares GitHub server-side settings for MacDog public release.

Default mode is --dry-run. Actual repository visibility changes require both:

  $0 --apply --make-public
  MACDOG_CONFIRM_PUBLIC=MAKE-MACDOG-PUBLIC

Settings applied by --apply:
  - GitHub Actions enabled with allowed_actions=all
  - workflow token default permissions set to read
  - Actions PR review approval permission disabled
  - vulnerability alerts enabled where the account/visibility allows it
  - Dependabot security updates enabled where the account/visibility allows it
  - public fork PR workflow approval set to first_time_contributors after public conversion
  - branch protection applied through configure_github_branch_protection.sh

Environment:
  MACDOG_GITHUB_REPOSITORY       owner/repo target. Default: dhseo90/MacDog
  MACDOG_BRANCH_PROTECTION_SCRIPT branch protection helper path.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      MODE="dry-run"
      shift
      ;;
    --check)
      MODE="check"
      shift
      ;;
    --apply)
      MODE="apply"
      shift
      ;;
    --make-public)
      MAKE_PUBLIC=1
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

require_gh() {
  command -v gh >/dev/null 2>&1 || {
    echo "error: gh CLI is required." >&2
    exit 1
  }
}

repo_visibility() {
  gh repo view "$REPOSITORY" --json visibility --jq '.visibility'
}

print_current_state() {
  echo "Repository: $REPOSITORY"
  echo "Visibility: $(repo_visibility)"
  echo "Actions permissions:"
  gh api "repos/$REPOSITORY/actions/permissions" --jq '{enabled, allowed_actions, sha_pinning_required}'
  echo "Workflow permissions:"
  gh api "repos/$REPOSITORY/actions/permissions/workflow" --jq '{default_workflow_permissions, can_approve_pull_request_reviews}'

  local alerts_output
  alerts_output="$(/usr/bin/mktemp -t macdog-vulnerability-alerts.XXXXXX)"
  if gh api -i "repos/$REPOSITORY/vulnerability-alerts" >"$alerts_output" 2>&1; then
    echo "Vulnerability alerts: enabled"
  else
    if /usr/bin/grep -Fq "Vulnerability alerts are disabled" "$alerts_output"; then
      echo "Vulnerability alerts: disabled"
    else
      echo "Vulnerability alerts: unavailable"
    fi
  fi
  rm -f "$alerts_output"

  echo "Dependabot security updates:"
  gh api "repos/$REPOSITORY/automated-security-fixes" --jq '{enabled, paused}'

  if [[ "$(repo_visibility)" == "PUBLIC" ]]; then
    echo "Fork PR approval:"
    gh api "repos/$REPOSITORY/actions/permissions/fork-pr-contributor-approval" --jq '{approval_policy}'
  else
    echo "Fork PR approval: skipped until public"
  fi
}

try_setting() {
  local label="$1"
  shift
  echo "==> $label"
  if "$@"; then
    echo "ok: $label"
  else
    echo "warning: failed: $label" >&2
    return 0
  fi
}

apply_required_setting() {
  local label="$1"
  shift
  echo "==> $label"
  "$@"
  echo "ok: $label"
}

if [[ "$MODE" == "dry-run" ]]; then
  cat <<PLAN
Repository: $REPOSITORY
Mode: dry-run

Planned apply sequence:
  1. Set Actions repository permissions to enabled/all.
  2. Set workflow token permissions to read and PR review approval to false.
  3. Enable vulnerability alerts.
  4. Enable Dependabot security updates.
  5. If --make-public is provided with MACDOG_CONFIRM_PUBLIC=MAKE-MACDOG-PUBLIC, make the repo public.
  6. If public, set fork PR workflow approval to first_time_contributors.
  7. Apply branch protection required checks through:
     $BRANCH_PROTECTION_SCRIPT --apply

No GitHub settings were changed.
PLAN
  exit 0
fi

require_gh

if [[ "$MODE" == "check" ]]; then
  print_current_state
  exit 0
fi

if [[ "$MODE" != "apply" ]]; then
  echo "error: unsupported mode: $MODE" >&2
  exit 2
fi

apply_required_setting "Actions enabled and allowed_actions=all" \
  gh api -X PUT "repos/$REPOSITORY/actions/permissions" \
    -F enabled=true \
    -f allowed_actions=all \
    -F sha_pinning_required=false \
    --silent

apply_required_setting "Workflow token read-only and PR review approval disabled" \
  gh api -X PUT "repos/$REPOSITORY/actions/permissions/workflow" \
    -f default_workflow_permissions=read \
    -F can_approve_pull_request_reviews=false \
    --silent

try_setting "Vulnerability alerts enabled" \
  gh api -X PUT "repos/$REPOSITORY/vulnerability-alerts" --silent

try_setting "Dependabot security updates enabled" \
  gh api -X PUT "repos/$REPOSITORY/automated-security-fixes" --silent

if [[ "$MAKE_PUBLIC" == "1" ]]; then
  if [[ "${MACDOG_CONFIRM_PUBLIC:-}" != "MAKE-MACDOG-PUBLIC" ]]; then
    cat >&2 <<MESSAGE
error: refusing to make $REPOSITORY public without explicit confirmation.

Rerun with:

  MACDOG_CONFIRM_PUBLIC=MAKE-MACDOG-PUBLIC $0 --apply --make-public
MESSAGE
    exit 3
  fi

  apply_required_setting "Repository visibility public" \
    gh repo edit "$REPOSITORY" \
      --visibility public \
      --accept-visibility-change-consequences
fi

visibility="$(repo_visibility)"
if [[ "$visibility" == "PUBLIC" ]]; then
  try_setting "Fork PR workflow approval for first-time contributors" \
    gh api -X PUT "repos/$REPOSITORY/actions/permissions/fork-pr-contributor-approval" \
      -f approval_policy=first_time_contributors \
      --silent

  apply_required_setting "Branch protection" \
    "$BRANCH_PROTECTION_SCRIPT" --apply
else
  echo "Repository is $visibility; branch protection and public fork PR approval remain pending."
fi

print_current_state
